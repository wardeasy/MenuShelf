# MenuShelf

**A small, scrollable shelf for your Mac's menu bar apps.**

Too many menu bar icons, too little space? MenuShelf puts the menu bar items that macOS exposes into a scrollable popover. Click its menu bar icon, find an app, and open its menu.

Built with Swift and AppKit. No third-party runtime dependencies, accounts, or subscriptions.

> MenuShelf opens a separate popover. It does not make the system menu bar itself scrollable, move other apps' icons, or guarantee access to every item hidden behind a display notch.

## Features

- **Menu bar popover:** opens directly beneath MenuShelf's icon, without a separate app window or Dock icon.
- **Scrollable list:** shows application names and app icons, with item labels when available.
- **Native menu actions:** asks the selected item to open through macOS Accessibility.
- **Less system clutter:** excludes Control Center and its repeated entries.
- **Automatic permission detection:** checks Accessibility access every 1.5 seconds and reloads when permission changes.
- **Manual refresh:** rescans running applications when you open the popover or press **Refresh**.
- **Optional launch at login:** starts quietly, without showing the popover.
- **Local processing:** no analytics, network requests, screenshot capture, or remote service.

## Requirements

- macOS 13 Ventura or later.
- Apple Silicon or Intel Mac. The build script targets the architecture of the Mac running it; it does not create a universal binary.
- Xcode Command Line Tools, including Swift, for building from source.
- Accessibility permission for MenuShelf.
- Python 3 for the optional launch-at-login helper; available with current Xcode Command Line Tools installations.

The app has been used locally on macOS 26.6.2 on Apple Silicon. Other supported system versions and Intel builds have not been manually verified.

## Build and install

Download this repository's source or clone it, then open a terminal in the project directory.

If needed, install Apple's developer tools:

```sh
xcode-select --install
```

### Quick development build

```sh
bash build.sh --ad-hoc
bash scripts/install.sh
```

The installer copies the app to `~/Applications/MenuShelf.app` and opens it. It replaces an existing installation there after stopping MenuShelf. It does not reset Accessibility permissions or change login settings.

**Ad-hoc signing is for development:** rebuilding changes the app's signing identity and can invalidate its previous Accessibility approval. For an app you will keep updating, use a persistent signing certificate instead.

### Builds with a persistent signing identity

List the code-signing identities in your keychain:

```sh
security find-identity -p codesigning
```

Build with the same identity for each update:

```sh
bash build.sh --sign "Your Code Signing Identity"
bash scripts/install.sh
```

A valid Apple Developer signing identity can be used. For personal local use, you can also create a self-signed **Code Signing** certificate through **Keychain Access → Certificate Assistant → Create a Certificate**, then select it by name. This repository does not create a certificate, export a private key, or change certificate trust settings. A local certificate does not make the app Apple-notarized.

Keep the signing certificate, bundle identifier (`local.menushelf.app`), and installation path consistent. The designated requirement printed after a build should remain consistent across updates. Check it independently with:

```sh
codesign -d -r- "$HOME/Applications/MenuShelf.app"
```

Do not share signing private keys, keychains, passwords, or exported `.p12` files. None are required in this repository.

## First launch and Accessibility

1. Open MenuShelf. It requests Accessibility access if permission is missing.
2. Open **System Settings → Privacy & Security → Accessibility**.
3. Enable **MenuShelf**. If it is absent, add `~/Applications/MenuShelf.app` using **+**.
4. Click MenuShelf's list icon in the menu bar. The list refreshes automatically after access is granted.

Accessibility lets MenuShelf inspect menu bar elements and ask them to perform their standard press action. It is a broad system permission; grant it only to a build you trust.

Screen Recording and Full Disk Access are not required. macOS may separately ask for confirmation when opening a locally built app. The project does not provide an Apple-notarized release.

## Everyday use

- **Open or close:** click MenuShelf's menu bar icon.
- **Scroll:** use the trackpad, mouse wheel, or scrollbar inside the list.
- **Open an item:** click its row. MenuShelf closes its popover before invoking the item's native action.
- **Dismiss:** click outside the popover.
- **Refresh:** click **Refresh** to rescan.
- **Permissions:** click **Access…** to open Accessibility settings.
- **Quit:** click **Quit** in the popover.
- **Reposition:** hold **Command** and drag MenuShelf's icon. macOS controls the final order and available positions.

Each row uses the owning application's icon, not a screenshot or exact copy of its live status icon. An application may expose several items. Labels come from Accessibility; unnamed elements appear as **Untitled item**.

## Launch at login

After installing in `~/Applications`:

```sh
python3 scripts/login-item.py enable
```

This creates a per-user LaunchAgent at:

```text
~/Library/LaunchAgents/local.menushelf.login.plist
```

It opens the installed app with `--background` at login, keeping the popover closed. Enabling it also invokes the agent immediately; if MenuShelf is already running, macOS may activate the existing instance.

Check or disable it:

```sh
python3 scripts/login-item.py status
python3 scripts/login-item.py disable
```

Disabling login launch does not quit an already running app. The helper needs no administrator privileges and does not manage other apps' login items.

## Updating

1. Build the new source with the **same signing identity**.
2. Run `bash scripts/install.sh`.
3. Open the popover and confirm the list loads.

Switching signing certificates, or switching between an ad-hoc and certificate-signed build, may require a new Accessibility approval. Ordinary updates should not need a permission reset when the signing identity and app identity remain consistent, but system policy can still require reapproval.

## Troubleshooting

### Accessibility is enabled, but MenuShelf still requests access

Check that you launched the installed copy in `~/Applications`, rather than a second copy in `build/` or a download folder. If you rebuilt with a different identity, the old permission entry may no longer match.

Remove **only MenuShelf** from the Accessibility list, add the installed app again, and enable it. MenuShelf monitors permission changes automatically. If macOS still reports the old state, quit and reopen it.

Avoid resetting all apps' Accessibility permissions. Do not disable macOS security features to run MenuShelf.

### An app or hidden icon is missing

MenuShelf lists only elements exposed by running apps through Accessibility. Some apps, macOS components, overflow states, and notch-hidden items are unavailable. Control Center is deliberately excluded. MenuShelf does not bypass these restrictions.

### A row says “Untitled item”

The app did not provide a usable title, description, or help label. Its app name is still shown; multiple unnamed items may belong to the same process.

### Clicking a row does not open its menu

The element may have disappeared, its app may not implement `AXPress`, or macOS may reject the action. Refresh and try again. MenuShelf reports the Accessibility error code when an action fails. It does not fall back to coordinate clicks or screenshot automation.

### No menu bar icon is visible

Quit duplicate copies, open the installed app, and check the available space in your menu bar. Other menu bar managers and display settings may affect visibility. MenuShelf cannot guarantee that its own icon remains visible on a crowded menu bar.

### Local diagnostics

A smoke test verifies the executable and reports the permission state for that invocation:

```sh
build/MenuShelf.app/Contents/MacOS/MenuShelf --self-test
```

A shell-launched test does not prove the installed GUI app has permission. While the app runs, it stores these diagnostic values in its own preferences:

```sh
defaults read local.menushelf.app RunningVersion
defaults read local.menushelf.app AccessibilityTrusted
defaults read local.menushelf.app DiscoveredItemCount
```

The count reflects the last completed scan and can be stale. Preferences also retain the menu bar position. No item names or screenshots are written to these diagnostics.

## How it works

MenuShelf enumerates running apps using `NSWorkspace`, reads their `AXExtrasMenuBar` children, and additionally checks SystemUIServer's menu bar. It gathers labels, removes duplicate elements, sorts by app name, and presents an AppKit `NSPopover` containing an `NSScrollView`.

Selecting a row calls `AXUIElementPerformAction` with `AXPress`. The popover closes before that action so the target app can show its menu. Accessibility requests use a short per-process messaging timeout. The scan is asynchronous, although unresponsive apps can still delay results.

The app has no app sandbox entitlement and requires macOS Accessibility approval. It uses Apple's accessibility interfaces, including the string-named `AXExtrasMenuBar` attribute; behavior can vary across macOS versions and does not guarantee complete menu bar enumeration.

## Project layout

```text
Sources/main.swift             AppKit interface and Accessibility logic
Resources/Info.plist           App identity and bundle metadata
build.sh                       Native build and explicit signing selection
scripts/install.sh             Install or update the local app
scripts/login-item.py          Optional per-user login launch
.github/workflows/build.yml    Development build, checks, and artifact packaging
```

The GitHub Actions artifact is an ad-hoc-signed development build for the runner's architecture. It is not a notarized release and does not preserve a personal signing identity across CI builds.

## Uninstall

Disable login launch, quit MenuShelf from its popover, then move `~/Applications/MenuShelf.app` to the Trash. You can also remove MenuShelf from the Accessibility list. The preference domain is `local.menushelf.app` if you want to remove saved diagnostics and menu bar position separately.

## Contributing

Issues and pull requests are welcome. Include your macOS version, processor architecture, signing method, and affected app when reporting a problem. Do not include private keys, tokens, full environment dumps, or screenshots containing private information.

For a change, run `bash build.sh --ad-hoc`, the executable's `--self-test`, and helper-script syntax checks. UI and Accessibility changes also need a manual check with the installed app and permission enabled. A successful build alone does not prove that a third-party menu bar item opens correctly.

## License

[MIT](LICENSE).
