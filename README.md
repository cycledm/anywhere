# Anywhere

**English** / [简体中文](README.zh-CN.md)

Anywhere is a location simulation app for iPhone and iPad, based on [ChrisMack32/Locus](https://github.com/ChrisMack32/Locus). It sets the location reported by iOS and iPadOS through Apple's developer location service.

This fork adds Shortcuts actions, SideStore pairing import, Simplified Chinese localization, and Amap coordinate correction for mainland China. It uses a loopback connection that you can set up with a compatible network app.

## Features

- Tap the map or search for a place to set a simulated location.
- Move with the joystick, follow a walking or driving route, draw a path, or import and export GPX.
- Save favorites and revisit recent locations.
- Start a simulation from a Shortcuts location or a supported Apple Maps, Amap, or Baidu Maps link. Both start actions accept an optional random offset in meters. A separate action stops the simulation.
- Reuse a compatible SideStore pairing, import an RPPairing file, or pair on the device where supported.

## Setup

Anywhere requires iOS 18 or iPadOS 18 or later. Before starting a simulation, complete device pairing and configure the local loopback connection. See the [setup guide](SETUP.md) for pairing options, network configuration, and Shortcuts setup.

## Build locally

On macOS, install Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen). From the repository root, generate and open the project.

```bash
xcodegen generate
open Anywhere.xcodeproj
```

Select the **Anywhere** target and choose your Apple Developer team in **Signing & Capabilities**. Select a connected device to build and run. To build a signed device build from the command line, replace `YOUR_TEAM_ID` with your Apple Developer team ID.

```bash
xcodebuild -project Anywhere.xcodeproj -scheme Anywhere -configuration Release \
  -destination 'generic/platform=iOS' DEVELOPMENT_TEAM=YOUR_TEAM_ID build
```

The default bundle identifier is `dev.cycledm.anywhere`.

## License

Anywhere is available under the [MIT License](LICENSE). The bundled [idevice](https://github.com/jkcoxson/idevice) library is also MIT-licensed. The license file includes attribution for the coordinate conversion code adapted from coordtransform.
