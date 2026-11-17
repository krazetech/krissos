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
use cosmic_config::{Config, CosmicConfigEntry};
use cosmic_theme::{
    DARK_THEME_BUILDER_ID, DARK_THEME_ID, LIGHT_THEME_BUILDER_ID, LIGHT_THEME_ID, Theme,
    ThemeBuilder,
};

fn main() {
    for (mut builder, builder_id, theme_id) in [
        (ThemeBuilder::dark(), DARK_THEME_BUILDER_ID, DARK_THEME_ID),
        (ThemeBuilder::light(), LIGHT_THEME_BUILDER_ID, LIGHT_THEME_ID),
    ] {
        let config = Config::new(builder_id, ThemeBuilder::VERSION).unwrap();
        let dir = config.user_path().unwrap().to_owned();
        let keys: Vec<String> = std::fs::read_dir(&dir)
            .unwrap_or_else(|e| panic!("{}: {e}", dir.display()))
            .map(|e| e.unwrap().file_name().into_string().unwrap())
            .collect();
        let (errors, changed) = builder.update_keys(&config, &keys);
        assert!(errors.is_empty(), "{builder_id}: {errors:?}");
        builder.write_entry(&config).unwrap();
        let theme = builder.build();
        theme.write_entry(&Config::new(theme_id, Theme::VERSION).unwrap()).unwrap();
        println!("{theme_id}: changed {changed:?}");
    }
}
