# Pasty

`Pasty` is a lightweight macOS clipboard history app inspired by [Maccy](https://github.com/p0deje/Maccy), built as a personal project.

## Features

- Menu bar clipboard manager
- Tracks text and image clipboard entries
- Click an item to copy it back to clipboard
- `Settings...` window with:
  - history size
  - number of menu items shown
  - polling interval
  - image capture toggle
  - whitespace-trimming toggle
  - launch-at-login toggle

## Run in development

```bash
swift run Pasty
```

## Generate icon assets

```bash
./scripts/generate-icon.sh
```

This generates:

```bash
assets/Pasty.icns
assets/pasty-icon-1024.png
```

## Build a clickable app bundle

```bash
./scripts/build-app.sh
```

This creates:

```bash
dist/Pasty.app
```

You can launch it by double-clicking `dist/Pasty.app`.

## Install like a normal app

```bash
ditto dist/Pasty.app /Applications/Pasty.app
open /Applications/Pasty.app
```

After that, use `Pasty > Settings... > Launch at login` to start automatically after login.
