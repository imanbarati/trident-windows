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

GitHub Action [`.github/workflows/apk-release.yml`](../../.github/workflows/apk-release.yml) builds an arm64 release APK and publishes it.

- Manual: Actions → **Android APK release** → Run workflow. Tag defaults to `apk-v` plus the version in `Cargo.toml`.
- Automatic: push a tag `v*` or `apk-v*`.

The APK is the picker only. It cannot install Termux packages. Copy the command it shows into Termux (F-Droid).

Local build (Android SDK + NDK):

```sh
rustup target add aarch64-linux-android
cargo install cargo-apk --locked --version 0.10.0
cargo apk build --release
```

The APK is written under `target/release/apk/`. See egui’s `examples/hello_android` if `android_app` on `NativeOptions` moves between eframe versions.


The live web companion is the supported preview. This crate is the native shell.
