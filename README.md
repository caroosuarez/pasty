# Pasty (my personal clipboard app)

A tiny clipboard manager for macOS.
Made in Swift. Inspired by Paste + Maccy, but this one is mine.

Now other people can install it too.

=================================

## Quick install (for anyone)

If someone just wants the app from terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/caroosuarez/pasty/main/scripts/install-latest.sh | bash
```

If your repo ever changes, they can override it like this:

```bash
PASTY_REPO="caroosuarez/pasty" curl -fsSL https://raw.githubusercontent.com/caroosuarez/pasty/main/scripts/install-latest.sh | bash
```

What this does:
- Downloads latest release zip
- Installs `Pasty.app` into `/Applications`
- Opens the app

=================================

## Download manually

From GitHub Releases, download one of these:
- `Pasty-macOS.zip`
- `Pasty-macOS.dmg`

Then move `Pasty.app` to `/Applications`.

=================================

## For developers

### 1. Clone

```bash
git clone https://github.com/caroosuarez/pasty.git
cd pasty
```

### 2. Run in dev mode

```bash
swift run Pasty
```

=================================

## Build the app bundle

```bash
./scripts/build-app.sh
```

Install locally:

```bash
ditto dist/Pasty.app /Applications/Pasty.app
open /Applications/Pasty.app
```

=================================

## Create release files (zip + dmg)

```bash
./scripts/make-release.sh
```

This creates:
- `release/Pasty-macOS.zip`
- `release/Pasty-macOS.dmg`

If you only want zip:

```bash
./scripts/make-release.sh --no-dmg
```

Upload those files to a GitHub Release.

=================================

## What Pasty has right now

- Bottom popup UI (Paste-style)
- Search bar + tabs (`Clipboard`, `Useful Links`, `Important Notes`, `Images`, `Pinned`)
- Text and image clipboard history
- Source app icon + app name
- Header colors that try to match the source app icon
- Arc special gradient accent
- Hover effect on cards (slight wobble + highlight)
- Pin / unpin items
- Persistent history on disk
- Retention setting (default is 7 days)

=================================

## Keyboard shortcuts

- `Shift + Command + V` -> open/close Pasty popup
- `Return` -> copy selected item
- `Esc` -> close popup
- `Left/Right` -> move between cards
- `Command + F` -> focus search
- `Command + P` -> pin/unpin selected card

=================================

## If something breaks

Try this:

```bash
rm -rf .build
swift build
```

Then run again:

```bash
swift run Pasty
```

=================================

## Tech used

- Swift
- AppKit
- Swift Package Manager
- NSStatusBar / NSPanel / NSCollectionView

