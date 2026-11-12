# Follow the Omarchy language: implementation plan

This plan moves the panel's strings into per-language catalogs that follow the Omarchy language, adds all 50 languages, and opens the upstream pull request (PR).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The QEMU panel shows the language set in `~/.config/omarchy/language`, switches live, and ships a catalog for each of the 50 Omarchy language codes.

**Architecture:** `Panel.qml` drops its own language state and string table and uses the shell's `Translations` type (`qs.Commons`) pointed at `i18n/`. The shell resolves each string from the current language, then its base language, then `en.json`. A bash check script makes sure the catalogs and `Panel.qml` stay in sync.

**Tech Stack:** QML (Quickshell, Omarchy shell `qs.Commons`), JSON catalogs, bash with `jq`.

**Spec:** [2026-11-12-system-language-design.md](../specs/2026-11-12-system-language-design.md)

## 📏 Global Constraints

- The language comes only from the shell (`Translations.language`, which reads `~/.config/omarchy/language`). The plugin keeps no language state of its own.
- The catalog files are exactly the 50 codes in `/usr/share/omarchy/default/i18n/locales.json`, named `<code>.json`. Spanish is `es-MX.json`.
- Catalogs are flat JSON. A value is a string, or, for counted strings, an object of CLDR (Common Locale Data Repository) plural forms that always includes `other`.
- `scripts/set-language` and every reference to `~/.local/state/dix.qemu/lang` are removed.
- Every `Text` in `Panel.qml` keeps `textFormat: Text.PlainText`, and `scripts/test-plaintext` must still pass.
- The `docs/superpowers/` files stay out of the upstream PR.

## 🔍 Review Focus

1. **Plural header for counts 0, 1, 2 and 5:** when no VM is running, the header shows "All stopped". With 1 of 2 running, Arabic, Polish and Russian pick the correct plural form, and both `%1` and `%2` appear. `test-i18n` checks that every form keeps both placeholders.
2. **A translation that drops a placeholder:** `%1` or `%2` missing from a string would silently hide a number. `test-i18n` checks that each value's placeholders match `en.json`.
3. **Keys used in `Panel.qml` but missing from `en.json`:** the raw key would show in the panel. `test-i18n` checks both directions: every key used exists, and no catalog key goes unused.
4. **A right-to-left language (`ar`, `fa`, `he`, `ur`):** the panel should not break. It inherits the shell's layout direction; Task 3 checks it live.
5. **An unknown libvirt state** (for example `pmsuspended`): `Panel.qml:391` shows `vm.state` as it comes. That is data, not a string to translate, so it is left as is.

---

### Task 1: Catalog check script

**Files:**
- Create: `scripts/test-i18n`

**Interfaces:**
- Produces: `scripts/test-i18n`, which exits 0 and prints `✓ …` lines when everything matches. Otherwise it prints `✗ <reason>` lines and exits 1.

- [ ] **Step 1: Write `scripts/test-i18n`.** Use the same style as `scripts/test-plaintext`: resolve `DIR` from `$0`, use `jq`, and print `✓` or `✗` per check. Checks:
  1. The set of `i18n/*.json` basenames equals the keys of `/usr/share/omarchy/default/i18n/locales.json`. If that file is missing, fall back to the hard-coded list of 50 codes from the spec.
  2. Each file parses with `jq` and its key set equals the key set of `en.json`.
  3. Each value is a non-empty string, or an object whose values are non-empty strings and that has `other`.
  4. In each value or plural form, the sorted list of `%N` placeholders equals that of the `en.json` `other` (or string) value for the same key.
  5. The keys used in `Panel.qml` (regex `tr\.tn?\("([a-zA-Z.]+)"`) equal the keys of `en.json`.
  6. `Panel.qml`, `README.md` and `scripts/` contain no `set-language` and no `dix.qemu/lang`.
- [ ] **Step 2: Run it and watch it fail**

  Run: `bash scripts/test-i18n`
  Expected: exit 1, with `✗` on checks 1, 5 and 6 (there is no `i18n/` yet, and `set-language` still exists).
- [ ] **Step 3: Commit**

  ```bash
  git add scripts/test-i18n
  git commit -m "test: add i18n catalog consistency check"
  ```

### Task 2: Panel follows the Omarchy language (en and es-MX)

**Files:**
- Create: `i18n/en.json`, `i18n/es-MX.json`
- Modify: `Panel.qml:14-70` (language state and string table), `Panel.qml:165-166` (header), every `root.t(` call
- Modify: `README.md` (both "Language" and "Idioma" sections, and `README.md:128`)
- Delete: `scripts/set-language`

**Interfaces:**
- Consumes: `Translations` from `qs.Commons`, with `t(key, fallback)`, `tn(key, count, fallback)` and `directory`. Also `I18n.formatNumber(value, decimals)`.
- Produces: `Translations { id: tr; directory: Qt.resolvedUrl("i18n") }` in `Panel.qml`, and the catalog key set that Task 3 copies.

- [ ] **Step 1: Write `i18n/en.json` and `i18n/es-MX.json`** from the current `en` and `es` tables, using only keys that are actually used. Replace `of` and `running` with one plural key:

  ```json
  "header.running": { "one": "%1 of %2 running", "other": "%1 of %2 running" }
  ```

  `es-MX`: `{ "one": "%1 de %2 en ejecución", "other": "%1 de %2 en ejecución" }`. Drop any key that `Panel.qml` never uses, such as `force` if no call site reads it. Keep the other key names as they are.
- [ ] **Step 2: Edit `Panel.qml`.**
  - Delete `langFile`, `lang`, the `langView` `FileView`, the `createLang` `Process`, `strings` and `t()`.
  - Add `Translations { id: tr; directory: Qt.resolvedUrl("i18n") }`.
  - Replace every `root.t("x")` with `tr.t("x")`.
  - Header: `tr.tn("header.running", service.runningCount).arg(I18n.formatNumber(service.runningCount)).arg(I18n.formatNumber(service.vms.length))`. Use `tr.t("allStopped")` when the count is 0.
  - Remove `import Quickshell.Io` only if nothing else in the file uses it.
- [ ] **Step 3: Delete `scripts/set-language`.** In the README, replace both language sections with one sentence each saying the panel follows Setup › Language. Fix `README.md:128` to match.
- [ ] **Step 4: Run the checks**

  Run: `bash scripts/test-i18n; bash scripts/test-plaintext`
  Expected: `test-i18n` fails only check 1 (48 files missing). `test-plaintext` prints `✓`.
- [ ] **Step 5: Check the panel live in the installed copy.** Copy `Panel.qml`, `i18n/` and the README to `~/.config/omarchy/plugins/dix.qemu/`, then delete `scripts/set-language` there. Open the panel.
  - Expected: English, with the header reading "0 OF 2 RUNNING" or "ALL STOPPED".
  - `journalctl --user --since -1min | grep dix.qemu` shows no new `Unable to assign` or `ReferenceError` lines.
- [ ] **Step 6: Commit**

  ```bash
  git add -A Panel.qml i18n README.md scripts/set-language
  git commit -m "feat: follow the Omarchy display language"
  ```

### Task 3: The other 48 languages

**Files:**
- Create: `i18n/<code>.json` for each code in `locales.json` other than `en` and `es-MX`

**Interfaces:**
- Consumes: the key set and placeholders of `i18n/en.json` from Task 2.

- [ ] **Step 1: Write the 48 catalogs.** Translate from `en.json`. Use the plural categories each language uses: `ar` uses `zero`, `one`, `two`, `few`, `many` and `other`; `pl`, `ru`, `uk`, `cs`, `sk`, `hr`, `sr`, `sl`, `lt` and `lv` use their own sets; `ja`, `ko`, `zh-CN`, `zh-TW`, `th`, `vi`, `id` and `ms` use `other` only. Keep product names (`CPU`, `RAM`, `IP`, `virt-manager`) as they are.
- [ ] **Step 2: Run the checks**

  Run: `bash scripts/test-i18n; bash scripts/test-plaintext`
  Expected: every line is `✓` and both scripts exit 0.
- [ ] **Step 3: Check the panel live in two languages.**
  - Save `~/.config/omarchy/language`.
  - Write `fr` to it and open the panel: it shows French. Do the same with `ar`: the panel shows Arabic and the layout is intact.
  - Restore the saved file and confirm the panel is back in English.
- [ ] **Step 4: Commit**

  ```bash
  git add i18n
  git commit -m "feat: add translations for all Omarchy languages"
  ```

### Task 4: Upstream PR

- [ ] **Step 1: Confirm the branch.** Tasks 1–3 run on the branch `i18n-system-language`, created from `master` before Task 1. `docs/superpowers/` is never committed. Run `git diff master --stat` and confirm the diff has no `docs/` paths.
- [ ] **Step 2: Push and open the PR.** Run `git push -u origin i18n-system-language`, then `gh pr create --repo pacman-vzla/omarchy-qemu-plugin --base master --head JonathanPitre:i18n-system-language`. Title: `Follow the Omarchy language and add all 50 translations`. The body says:
  - why: the panel defaulted to Spanish and ignored Setup › Language;
  - what changed;
  - that `set-language` was removed;
  - that 48 catalogs are machine translations, with an invitation to native speakers to correct them;
  - which test commands to run.
- [ ] **Step 3: Link the PR** (`link_pull_request`) and report its URL.
