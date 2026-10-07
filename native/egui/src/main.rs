fn main() -> eframe::Result {
    trident_gui::run()
}

#[cfg(target_os = "android")]
#[no_mangle]
fn android_main(app: winit::platform::android::activity::AndroidApp) {
    let mut options = trident_gui::native_options();
    options.android_app = Some(app);
    let _ = eframe::run_native(
        "Trident Setup",
        options,
        Box::new(|_cc| Ok(Box::new(trident_gui::TridentApp::default()))),
    );
}
