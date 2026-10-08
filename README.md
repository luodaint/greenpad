# Greenpad

A lightweight, native Mac text editor inspired by the everyday workflow of Notepad++. Written in Swift and AppKit, with no third-party runtime dependencies.

Greenpad is an independent project by Luodaint. It is not an official Notepad++ port and contains no Notepad++ source code or artwork.

## First version

- Multiple tabs with unsaved-change indicators and confirmation before closing or quitting.
- Native open/save dialogs, multiple-file opening, and duplicate-file detection.
- Line numbers, automatic indentation, four-space Tab insertion, and go to line.
- Syntax colors for JavaScript, TypeScript, Python, Swift, C/C++, JSON, HTML, CSS, Shell, and Markdown.
- Find next/previous, wraparound search, match case, regular expressions, replace, and replace all with undo.
- Regex replacement groups use `$1`, `$2`, etc. Regex syntax is Foundation/ICU; it does not exactly match Notepad++'s regex engine.
- Light, dark, and system appearance, adjustable monospaced font, and optional word wrap.
- UTF-8 (with or without BOM) and UTF-16 LE/BE (with BOM), with the detected newline convention retained when saving.
- Warns before overwriting an opened file that changed on disk.
- Local editing only: no telemetry, networking, updater, or plugin execution.

## Build and run

Requires macOS 13 or newer and Xcode Command Line Tools with a Swift compiler. The build produces a universal Apple Silicon / Intel app.

```sh
bash build.sh
open build/Greenpad.app
```

You can copy the app to your Applications folder. Local builds are ad-hoc signed. Developer ID signing and Apple notarization are needed before a public binary release. The GitHub repository provides source; do not bypass Gatekeeper warnings to run third-party downloads.

## Verify

```sh
bash build.sh
build/Greenpad.app/Contents/MacOS/Greenpad --self-test
build/Greenpad.app/Contents/MacOS/Greenpad --ui-test
```

The UI test briefly opens a window, tests native editing/search/undo and file round trips in a temporary directory, and exits. Do not run it against an already running copy of Greenpad.

## Shortcuts

| Shortcut | Action |
| --- | --- |
| ⌘N / ⌘O | New tab / open files |
| ⌘S / ⇧⌘S | Save / save as |
| ⌘W | Close tab |
| ⌘F / Escape | Open / close find panel |
| ⌘G / ⇧⌘G | Find next / previous |
| ⌘E | Use selected text as search query |
| ⌘L | Go to line |
| ⌥⌘W | Toggle word wrap |
| ⇧⌘] / ⇧⌘[ | Next / previous tab |
| ⌘+ / ⌘− / ⌘0 | Increase / decrease / reset font |

## Current limits

This is a first usable version, not full Notepad++ compatibility. Plugins, macros, code folding, multiple cursors, directory search, and session/crash recovery are not implemented. Save documents before leaving the app; scratch tabs are not restored after exit or a crash.

Files are limited to 20 MB. Syntax highlighting is disabled above 1,000,000 UTF-16 code units. Syntax colors use lightweight regular expressions rather than a compiler parser. Files with mixed newline styles are normalized to their predominant style when saved. Legacy encodings and BOM-less UTF-16 are not supported.

## Contribute

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and [GOVERNANCE.md](GOVERNANCE.md). The project is licensed under [MIT](LICENSE).

Project domain: [greenpad.app](https://greenpad.app) (website launch pending).
