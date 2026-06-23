# FaceCam Overlay

FaceCam Overlay is a tiny native macOS app that keeps your camera in a movable
circle above every other window—handy for screen recordings, walkthroughs, and
presentations.

## Install

1. Download the latest `FaceCam-Overlay.dmg` from
   [Releases](https://github.com/augustoFranke/facecam-overlay/releases/latest).
2. Open the DMG and drag **FaceCam Overlay** into **Applications**.
3. Launch the app and allow Camera access when macOS asks.

The app lives in the menu bar. Drag the camera circle anywhere on screen, then
record normally with `Command-Shift-5`, QuickTime, OBS, or another recorder.

> The first release is signed but not notarized. If macOS blocks the first
> launch, Control-click the app in Applications, choose **Open**, then confirm.

## Features

- Always-on-top circular camera preview
- Small, medium, and large sizes
- Mirrored preview toggle
- Camera selection, including Continuity Camera
- Visible across Spaces and full-screen apps
- Native Swift app with no runtime or account required

## Build from source

Users only need the DMG. Developers can build locally on macOS 13 or newer:

```sh
make app
make dmg
```

## License

[MIT](LICENSE)
