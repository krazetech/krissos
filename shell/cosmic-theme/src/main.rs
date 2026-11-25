// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Kraze Tech
//! Builds the KrissOS COSMIC theme with libcosmic's own ThemeBuilder, the same code
//! COSMIC Settings runs when you change the accent, so every derived colour (hover,
//! pressed, dividers, text on accent) is exactly what COSMIC would compute.
//!
//! usage: XDG_CONFIG_HOME=DIR kriss-cosmic-theme
//! Starts from COSMIC's dark and light builders, applies the keys found in
//! DIR/cosmic/com.system76.CosmicTheme.{Dark,Light}.Builder/v2 (rendered from
//! theme/tokens.json), then writes the full builder and the theme built from it
//! back under DIR/cosmic.
//!
//! usage: kriss-cosmic-theme --accent '#RRGGBB'
//! What the shell runs when the accent changes. In both builders it sets `accent`, and
//! `window_hint` when that was following the old accent, rebuilds both themes and writes
//! only the theme keys whose value changed, so COSMIC apps repaint and nothing else moves.
//!
//! usage: kriss-cosmic-theme --rebuild
//! What the shell runs after it writes builder keys itself (the corners and the focused
//! window's border, from Settings > Personalise > Windows): rebuilds both themes from the
//! builders and writes only the theme keys that changed.
use cosmic_config::{Config, CosmicConfigEntry};
use cosmic_theme::{
    DARK_THEME_BUILDER_ID, DARK_THEME_ID, LIGHT_THEME_BUILDER_ID, LIGHT_THEME_ID, Theme,
    ThemeBuilder,
    palette::Srgb,
};
use std::{fs, path::Path};

fn user_keys(config: &Config) -> Vec<String> {
    let dir = config.user_path().unwrap();
    fs::read_dir(dir)
        .unwrap_or_else(|e| panic!("{}: {e}", dir.display()))
        .map(|e| e.unwrap().file_name().into_string().unwrap())
        .collect()
}

fn parse_hex(s: &str) -> Option<Srgb> {
    let h = s.strip_prefix('#')?;
    if h.len() != 6 || !h.bytes().all(|b| b.is_ascii_hexdigit()) {
        return None;
    }
    let ch = |i: usize| u8::from_str_radix(&h[i..i + 2], 16).unwrap() as f32 / 255.0;
    Some(Srgb::new(ch(0), ch(2), ch(4)))
}

// Writes `theme` key by key, skipping every key whose file would not change.
fn write_changed(theme: &Theme, theme_id: &str) {
    let live = Config::new(theme_id, Theme::VERSION).unwrap();
    let live_dir = live.user_path().unwrap().to_owned();
    let scratch = std::env::temp_dir().join(format!("kriss-cosmic-theme-{}", std::process::id()));
    theme
        .write_entry(&Config::with_custom_path(theme_id, Theme::VERSION, scratch.clone()).unwrap())
        .unwrap();
    let built = scratch.join("cosmic").join(Config::id_v(theme_id, Theme::VERSION).unwrap());
    for e in fs::read_dir(&built).unwrap() {
        let name = e.unwrap().file_name();
        let new = fs::read(built.join(&name)).unwrap();
        let dst = live_dir.join(&name);
        if fs::read(&dst).ok().as_deref() != Some(&new[..]) {
            // Same directory, so the rename is atomic and apps never read half a file.
            let tmp = live_dir.join(Path::new(".kriss-tmp"));
            fs::write(&tmp, &new).unwrap();
            fs::rename(&tmp, &dst).unwrap();
            println!("{theme_id}/{}", name.to_string_lossy());
        }
    }
    let _ = fs::remove_dir_all(scratch);
}

fn set_accent(accent: Srgb) {
    for (mut builder, builder_id, theme_id) in [
        (ThemeBuilder::dark(), DARK_THEME_BUILDER_ID, DARK_THEME_ID),
        (ThemeBuilder::light(), LIGHT_THEME_BUILDER_ID, LIGHT_THEME_ID),
    ] {
        let config = Config::new(builder_id, ThemeBuilder::VERSION).unwrap();
        builder.update_keys(&config, &user_keys(&config));
        if builder.window_hint.is_some() && builder.window_hint == builder.accent {
            builder.set_window_hint(&config, Some(accent)).unwrap();
        }
        builder.set_accent(&config, Some(accent)).unwrap();
        write_changed(&builder.build(), theme_id);
    }
}

fn rebuild() {
    for (mut builder, builder_id, theme_id) in [
        (ThemeBuilder::dark(), DARK_THEME_BUILDER_ID, DARK_THEME_ID),
        (ThemeBuilder::light(), LIGHT_THEME_BUILDER_ID, LIGHT_THEME_ID),
    ] {
        let config = Config::new(builder_id, ThemeBuilder::VERSION).unwrap();
        builder.update_keys(&config, &user_keys(&config));
        write_changed(&builder.build(), theme_id);
    }
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args == ["--rebuild"] {
        return rebuild();
    }
    if let [flag, hex] = &args[..] {
        if flag == "--accent" {
            match parse_hex(hex) {
                Some(c) => return set_accent(c),
                None => {
                    eprintln!("kriss-cosmic-theme: not a #RRGGBB colour: {hex}");
                    std::process::exit(2);
                }
            }
        }
    }
    for (mut builder, builder_id, theme_id) in [
        (ThemeBuilder::dark(), DARK_THEME_BUILDER_ID, DARK_THEME_ID),
        (ThemeBuilder::light(), LIGHT_THEME_BUILDER_ID, LIGHT_THEME_ID),
    ] {
        let config = Config::new(builder_id, ThemeBuilder::VERSION).unwrap();
        let (errors, changed) = builder.update_keys(&config, &user_keys(&config));
        assert!(errors.is_empty(), "{builder_id}: {errors:?}");
        builder.write_entry(&config).unwrap();
        let theme = builder.build();
        theme.write_entry(&Config::new(theme_id, Theme::VERSION).unwrap()).unwrap();
        println!("{theme_id}: changed {changed:?}");
    }
}
