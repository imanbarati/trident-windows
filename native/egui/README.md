# Trident GUI (egui)

Native picker for the same stack as the web companion, built with [emilk/egui](https://github.com/emilk/egui) / eframe.

- **Windows:** Install launches the official PowerShell one-liner.
- **Android:** copies the Termux `install.sh` command. An APK cannot install Termux packages; paste the command in Termux from F-Droid.

## Desktop

```sh
cd native/egui
cargo run --release
```

## Android APK

Needs the Android SDK + NDK, then:

```sh
rustup target add aarch64-linux-android
cargo install cargo-apk
cargo apk build --release
```

See egui’s `examples/hello_android` if `android_app` on `NativeOptions` moves between eframe versions.

The live web companion is the supported preview. This crate is the native shell.
