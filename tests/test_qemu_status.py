import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / 'scripts/vm-status'
loader = importlib.machinery.SourceFileLoader('vm_status', str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
vm = importlib.util.module_from_spec(spec)
loader.exec_module(vm)


class StatusTests(unittest.TestCase):
    def test_memory_units(self):
        for value, expected in [('2048', 2048), ('2G', 2048), ('size=2G,maxmem=4G', 2048), ('bad', '')]:
            self.assertEqual(vm.memory_mb(value), expected)

    def test_daemonized_vm_and_forwarding(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            proc = root / 'proc'
            entry = proc / '123'
            (entry / 'fd').mkdir(parents=True)
            disk = root / 'VM with spaces/disk.qcow2'
            disk.parent.mkdir()
            disk.write_bytes(b'example')
            (entry / 'fd/13').symlink_to(disk)
            (entry / 'cwd').symlink_to('/')
            args = ['qemu-system-x86_64', '-m', '2G', '-drive', 'file=disk.qcow2',
                    '-netdev', 'user,id=n,hostfwd=tcp::2222-:22', '-device', 'virtio-net-pci',
                    '-monitor', 'unix:mon.sock,server=on']
            (entry / 'cmdline').write_bytes(('\0'.join(args) + '\0').encode())
            (entry / 'status').write_text('VmRSS:\t1048576 kB\n')
            with patch.object(vm, 'monitor_status', return_value='paused') as monitor:
                rows = vm.standalone(proc)
            self.assertEqual(len(rows), 1)
            row = rows[0]
            self.assertEqual(row['name'], 'VM with spaces')
            self.assertEqual(row['network'], 'tcp::2222-:22')
            self.assertEqual((row['ram'], row['ramTotal']), (1024, 2048))
            self.assertEqual(row['state'], 'paused')
            monitor.assert_called_once_with(disk.parent / 'mon.sock')
            # No monitor response must preserve the detected VM.
            with patch.object(vm, 'monitor_status', return_value=''):
                self.assertEqual(vm.standalone(proc)[0]['state'], 'process running')
            # Avoid duplicate entries for a libvirt QEMU process.
            (entry / 'cmdline').write_bytes(('\0'.join(args + ['-name', 'guest=test,debug-threads=on']) + '\0').encode())
            self.assertEqual(vm.standalone(proc), [])

    def test_missing_virsh_is_not_an_error(self):
        with patch.object(vm.shutil, 'which', return_value=None):
            self.assertEqual(vm.libvirt(), ([], ''))

    def test_monitor_unavailable(self):
        self.assertEqual(vm.monitor_status('/nonexistent-qemu-monitor.sock'), '')

    def test_libvirt_names_with_spaces(self):
        check = vm.subprocess.CompletedProcess([], 0, '', '')
        data = vm.subprocess.CompletedProcess([], 0, 'vm My VM running\nvm_ram My VM 1048576 2097152\nvm_ip My VM 192.0.2.1\n', '')
        with patch.object(vm.shutil, 'which', return_value='/usr/bin/virsh'), patch.object(vm.subprocess, 'run', side_effect=[check, data]):
            rows, warning = vm.libvirt()
        self.assertEqual(warning, '')
        self.assertEqual(rows[0]['name'], 'My VM')
        self.assertEqual(rows[0]['ram'], 1024)
        self.assertEqual(rows[0]['ip'], '192.0.2.1')

    def test_libvirt_failure_is_visible(self):
        failure = vm.subprocess.CompletedProcess([], 1, '', 'permission denied')
        with patch.object(vm.shutil, 'which', return_value='/usr/bin/virsh'), patch.object(vm.subprocess, 'run', return_value=failure):
            rows, warning = vm.libvirt()
        self.assertEqual(rows, [])
        self.assertIn('unavailable', warning)


if __name__ == '__main__':
    unittest.main()
