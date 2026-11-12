# Follow the Omarchy language

The QEMU panel will show the language picked in Omarchy, switch when it changes, and cover all 50 Omarchy languages.

## 🎯 Why

The panel starts in Spanish and ignores the language picked under Setup › Language. People expect it to match the rest of the shell.

## ✅ Goals

- The panel's language comes only from `~/.config/omarchy/language`, through the shell.
- Each of the 50 codes in `/usr/share/omarchy/default/i18n/locales.json` has a translation file.
- Changing the language updates the panel without restarting the shell.

## 🚫 Non-goals

- A separate language setting for the plugin. `scripts/set-language` and `~/.local/state/dix.qemu/lang` are removed.
- Translating VM names, IP addresses or other data that comes from libvirt.

## 🧭 Approaches

1. **`Commons.Translations` with `i18n/<code>.json` (chosen).** The shell provides this for plugins that ship their own translations. It follows the shell language live, and a missing string falls back from `pt-BR` to `pt`, then to `en`, then to the key. The hyprmoncfg plugin already works this way.
2. **Extend the `strings` table in `Panel.qml` and read the language file by hand (rejected).** It would put 50 tables in one QML file and rebuild language watching and fallback that the shell already provides.

## 🛠️ Design

- Add an `i18n/` folder with one JSON file per Omarchy language code: `en.json`, `es-MX.json`, `fr.json`, and the rest. Omarchy's Spanish is `es-MX`, so the current Spanish strings go there.
- In `Panel.qml`, remove the `lang` property, the language-file `FileView` and `Process`, the `strings` table and `t()`. Use `Translations { id: tr; directory: Qt.resolvedUrl("i18n") }` instead, and call `tr.t("key")`.
- The header now builds "1 of 2 running" from separate words. Replace that with one plural-aware string, `tr.tn("header.running", runningCount)`, with `%1` for running VMs and `%2` for the total.
  - Plural forms use the CLDR (Common Locale Data Repository) categories such as `one` and `other`.
  - Numbers go through `I18n.formatNumber`.
- Delete `scripts/set-language`. In both language sections of the README, say the panel follows the Omarchy language.
- Write the 48 new translations by machine. The pull request (PR) says so, so native speakers can correct them.
- Open the PR from `JonathanPitre/omarchy-qemu-plugin` to `master` on `pacman-vzla/omarchy-qemu-plugin`.

## 📦 Left to the builder

- Key names. Keep the current keys unless a rename makes them clearer.
- A small script in `scripts/` that checks every file is valid JSON with the same keys as `en.json`.
- Keep this spec out of the upstream PR.
