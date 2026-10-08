use eframe::egui::{self, Color32, RichText, Stroke, Vec2};

#[cfg(target_os = "android")]
use jni::{jni_sig, jni_str, objects::{JObject, JString}, JValue};
#[cfg(target_os = "android")]
use winit::platform::android::activity::AndroidApp;

const RAW_PS1: &str = "https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.ps1";
const RAW_SH: &str = "https://raw.githubusercontent.com/imanbarati/trident-windows/main/install.sh";

#[derive(Clone, Copy, PartialEq, Eq)]
enum Platform {
    Windows,
    Android,
}

struct Pkg {
    flag: &'static str,
    name: &'static str,
    maker: &'static str,
    windows: bool,
    android: bool,
    win_on: bool,
    droid_on: bool,
}

pub struct TridentApp {
    platform: Platform,
    packages: Vec<Pkg>,
    status: String,
    #[cfg(target_os = "android")]
    android_app: Option<AndroidApp>,
}

impl Default for TridentApp {
    fn default() -> Self {
        Self {
            platform: if cfg!(target_os = "android") {
                Platform::Android
            } else {
                Platform::Windows
            },
            status: String::new(),
            #[cfg(target_os = "android")]
            android_app: None,
            packages: vec![
                Pkg { flag: "hermes", name: "Hermes Agent", maker: "Nous Research", windows: true, android: true, win_on: true, droid_on: true },
                Pkg { flag: "hermes-ide", name: "Hermes IDE", maker: "hermes-hq", windows: true, android: false, win_on: true, droid_on: false },
                Pkg { flag: "zcode", name: "ZCode", maker: "Z.AI", windows: true, android: false, win_on: true, droid_on: false },
                Pkg { flag: "antigravity", name: "Antigravity", maker: "Google", windows: true, android: false, win_on: true, droid_on: false },
                Pkg { flag: "antigravity-cli", name: "Antigravity CLI", maker: "Google", windows: true, android: false, win_on: true, droid_on: false },
                Pkg { flag: "claude", name: "Claude Code", maker: "Anthropic", windows: true, android: true, win_on: true, droid_on: false },
                Pkg { flag: "zeroclaw", name: "ZeroClaw", maker: "zeroclaw-labs", windows: true, android: true, win_on: true, droid_on: true },
            ],
        }
    }
}

impl TridentApp {
    fn chosen_flags(&self) -> Vec<&'static str> {
        self.packages
            .iter()
            .filter(|p| match self.platform {
                Platform::Windows => p.windows && p.win_on,
                Platform::Android => p.android && p.droid_on,
            })
            .map(|p| p.flag)
            .collect()
    }

    fn command(&self) -> String {
        let flags = self.chosen_flags();
        if flags.is_empty() {
            return "# tick at least one package".into();
        }
        let list = flags.join(",");
        match self.platform {
            Platform::Windows => format!(
                "& ([scriptblock]::Create((irm '{RAW_PS1}'))) -Only {list}"
            ),
            Platform::Android => {
                format!("curl -fsSL {RAW_SH} | bash -s -- --only {list}")
            }
        }
    }

    fn run_or_copy(&mut self) {
        let cmd = self.command();
        if cmd.starts_with('#') {
            self.status = "Select at least one package.".into();
            return;
        }
        #[cfg(windows)]
        {
            if self.platform == Platform::Windows {
                let _ = std::process::Command::new("powershell")
                    .args([
                        "-NoProfile",
                        "-ExecutionPolicy",
                        "Bypass",
                        "-Command",
                        &cmd,
                    ])
                    .spawn();
                self.status = "Launched PowerShell installer.".into();
                return;
            }
        }
        self.status = format!("Copy into Termux:\n{cmd}");
    }
}

impl eframe::App for TridentApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        let bg = Color32::from_rgb(9, 9, 11);
        let surface = Color32::from_rgb(18, 18, 22);
        let fg = Color32::from_rgb(242, 242, 244);
        let muted = Color32::from_rgb(142, 142, 152);
        let vis = ctx.style().visuals.clone();
        let mut visuals = vis;
        visuals.panel_fill = bg;
        visuals.window_fill = surface;
        visuals.override_text_color = Some(fg);
        visuals.widgets.inactive.bg_fill = Color32::from_rgb(26, 26, 31);
        visuals.selection.bg_fill = Color32::from_rgb(216, 220, 227);
        visuals.selection.stroke = Stroke::new(1.0, fg);
        ctx.set_visuals(visuals);

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.add_space(8.0);
            ui.label(RichText::new("Trident").size(28.0).color(fg));
            ui.label(RichText::new("Selective setup · official sources").size(13.0).color(muted));
            ui.add_space(12.0);

            ui.horizontal(|ui| {
                if ui.selectable_label(self.platform == Platform::Windows, "Windows").clicked() {
                    self.platform = Platform::Windows;
                }
                if ui.selectable_label(self.platform == Platform::Android, "Android").clicked() {
                    self.platform = Platform::Android;
                }
            });
            ui.add_space(8.0);

            for pkg in &mut self.packages {
                let supported = match self.platform {
                    Platform::Windows => pkg.windows,
                    Platform::Android => pkg.android,
                };
                ui.add_enabled_ui(supported, |ui| {
                    let on = match self.platform {
                        Platform::Windows => &mut pkg.win_on,
                        Platform::Android => &mut pkg.droid_on,
                    };
                    ui.horizontal(|ui| {
                        ui.checkbox(on, "");
                        ui.vertical(|ui| {
                            ui.label(RichText::new(pkg.name).color(fg));
                            let sub = if supported {
                                pkg.maker
                            } else {
                                "Windows only"
                            };
                            ui.label(RichText::new(sub).size(12.0).color(muted));
                        });
                    });
                });
                ui.add_space(4.0);
            }

            ui.add_space(8.0);
            let cmd = self.command();
            ui.label(RichText::new(cmd.clone()).monospace().size(12.0).color(fg));
            ui.add_space(8.0);
            ui.horizontal(|ui| {
                if ui.button(RichText::new("Copy command").color(bg)).clicked() {
                    #[cfg(target_os = "android")]
                    {
                        if let Some(app) = self.android_app.clone() {
                            let text = cmd.clone();
                            let java_app = app.clone();
                            app.run_on_java_main_thread(Box::new(move || {
                                let result = (|| -> jni::errors::Result<()> {
                                    let vm = unsafe { jni::JavaVM::from_raw(java_app.vm_as_ptr().cast()) };
                                    vm.attach_current_thread(|env| {
                                        let raw_activity = java_app.activity_as_ptr() as jni::sys::jobject;
                                        let activity_global = unsafe {
                                            env.as_cast_raw::<jni::refs::Global<JObject>>(&raw_activity)?
                                        };
                                        let activity = env.new_local_ref(&*activity_global)?;
                                        let service_name = JString::from_str(env, "clipboard")?;
                                        let clipboard = env.call_method(
                                            &activity,
                                            jni_str!("getSystemService"),
                                            jni_sig!("(Ljava/lang/String;)Ljava/lang/Object;"),
                                            &[JValue::Object(&service_name)],
                                        )?.l()?;
                                        let label = JString::from_str(env, "Trident")?;
                                        let clip_text = JString::from_str(env, &text)?;
                                        let clip = env.call_static_method(
                                            jni_str!("android/content/ClipData"),
                                            jni_str!("newPlainText"),
                                            jni_sig!("(Ljava/lang/CharSequence;Ljava/lang/CharSequence;)Landroid/content/ClipData;"),
                                            &[JValue::Object(&label), JValue::Object(&clip_text)],
                                        )?.l()?;
                                        env.call_method(
                                            &clipboard,
                                            jni_str!("setPrimaryClip"),
                                            jni_sig!("(Landroid/content/ClipData;)V"),
                                            &[JValue::Object(&clip)],
                                        )?;
                                        Ok(())
                                    })
                                })();
                                if let Err(err) = result {
                                    eprintln!("Android clipboard error: {err:?}");
                                }
                            }));
                            self.status = "Copied to Android clipboard.".into();
                        } else {
                            self.status = "Android clipboard is not ready.".into();
                        }
                    }
                    #[cfg(not(target_os = "android"))]
                    {
                        ui.ctx().copy_text(cmd.clone());
                        self.status = "Copied.".into();
                    }
                }
                if ui
                    .add_sized(Vec2::new(140.0, 28.0), egui::Button::new("Install"))
                    .clicked()
                {
                    self.run_or_copy();
                }
            });
            if !self.status.is_empty() {
                ui.add_space(8.0);
                ui.label(RichText::new(&self.status).size(12.0).color(muted));
            }
        });
    }
}

pub fn native_options() -> eframe::NativeOptions {
    eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([420.0, 720.0])
            .with_title("Trident Setup"),
        ..Default::default()
    }
}

pub fn run() -> eframe::Result {
    eframe::run_native(
        "Trident Setup",
        native_options(),
        Box::new(|_cc| Ok(Box::new(TridentApp::default()))),
    )
}

/// cargo-apk packages the cdylib, so the Android entry has to live in this crate.
#[cfg(target_os = "android")]
#[no_mangle]
fn android_main(app: winit::platform::android::activity::AndroidApp) {
    let mut options = native_options();
    options.android_app = Some(app.clone());
    let _ = eframe::run_native(
        "Trident Setup",
        options,
        Box::new(move |_cc| {
            let mut state = TridentApp::default();
            state.android_app = Some(app.clone());
            Ok(Box::new(state))
        }),
    );
}

