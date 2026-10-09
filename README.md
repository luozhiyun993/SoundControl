<p align="center">
  <img src="Resources/AppIcon.png" width="128" alt="SoundControl icon">
</p>

<h1 align="center">SoundControl</h1>

<p align="center">Per-app volume control, right in the macOS menu bar.</p>

<p align="center">English | <a href="README.zh-CN.md">简体中文</a></p>

---

macOS has a single system volume for everything. SoundControl lets you turn Chrome down to 30%, keep your music player at 100%, and leave notification sounds alone — one slider per app, each independent of the others.

## Features

- **Per-app volume**: a slider (0–100%) and an independent mute toggle for every controlled app
- **Add any app**: pick from apps that are currently playing audio, or add apps from the Applications folder in advance, even if they're not running
- **System volume**: adjust the current output device's volume from the top of the panel
- **Follows your setup**: settings keep working when you switch output devices (speakers / AirPods / displays), and apps are picked up again automatically when relaunched
- **Hands off everything else**: apps you haven't added are never touched
- **Launch at login**
- Works with apps that play audio from helper processes, such as Chrome and Safari

> **App volume is relative**: actual loudness = system volume × app volume. With the system at 50% and an app at 50%, you hear that app at 25%.

## Requirements

- macOS 14.2 or later (uses Core Audio Process Taps)
- Xcode Command Line Tools (`xcode-select --install`). **Full Xcode is not required.**

## Installation

```bash
git clone https://github.com/luozhiyun993/SoundControl.git
cd SoundControl

# 1. Create a local self-signed code-signing certificate (one time only)
./scripts/create-signing-cert.sh

# 2. Build, install to ~/Applications, and launch
./scripts/install.sh
```

The first time you sign, Keychain asks whether `codesign` may use the certificate's private key. Enter your login password and click **Always Allow**.

The first time an app is taken over, macOS asks for **System Audio Recording** permission. Allow it. If you denied it by mistake, click "Open System Settings" in the panel to grant it.

> Why a certificate? With ad-hoc signing, macOS treats every rebuild as a new app and asks for permission again.

## Usage

1. Click the speaker icon in the menu bar to open the panel
2. Click **＋** in the top-right corner and choose an app that's playing audio, or choose one from the Applications folder
3. Drag a slider to change that app's volume, click its speaker icon to mute it, or click ⓧ to remove it (its original volume comes back right away)

## How it works

SoundControl uses [Core Audio Process Taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps), introduced in macOS 14.2:

1. Find all audio processes that belong to a controlled app, including helpers such as Chrome Helper and Safari's WebKit.GPU process
2. Create a process tap for them and mute the original output (`mutedWhenTapped`)
3. Multiply the tapped audio by the app volume and play it through a private aggregate device on the current default output device

Because the audio still goes through the output device, app volume can only be a fraction of the system volume. If SoundControl quits or crashes, the taps go away and every app goes back to its original volume.

## Development

```bash
./scripts/build-app.sh && open build/SoundControl.app   # build and bundle only, don't install
swift scripts/make-icon.swift Resources/AppIcon.png       # regenerate the app icon
```

There is no Xcode project. Swift Package Manager does the build, and the scripts bundle the result into a `.app`.

```
Sources/SoundControl/
├── Audio/                     # Core Audio
│   ├── AppVolumeTap.swift     # Taps a set of processes and replays them with gain
│   ├── AudioProcess.swift     # Lists audio processes and works out which app they belong to
│   ├── SystemVolume.swift     # Reads and writes the default output device's volume
│   ├── AudioCapturePermission.swift
│   └── CoreAudioHelpers.swift
├── Model/
│   ├── ControlledApp.swift    # A controlled app, plus saving and loading the list
│   └── SoundController.swift  # Keeps one process tap per running controlled app
└── UI/
    ├── SoundControlApp.swift  # Menu bar entry point
    ├── MenuPanel.swift        # The popup panel
    └── AddAppMenu.swift       # The "＋" menu
```

- [`CONTEXT.md`](CONTEXT.md): project glossary (in Chinese)
- [`docs/adr/`](docs/adr/): architecture decision records (in Chinese)

## Known limitations

- Control is per app; individual Chrome tabs can't be controlled separately
- No boost above 100%
- Tapped audio is assumed to be stereo Float32, so a few unusual output devices may not work correctly
- Checking the audio-recording permission and finding which app a helper process belongs to both rely on private system APIs, which may need updating after future macOS releases
