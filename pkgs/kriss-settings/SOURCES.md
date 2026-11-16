# kriss-settings sources

Everything here is written for KrissOS. Ideas borrowed from elsewhere:

- **Limine boot menu** (`kriss-limine-update`): the layout (an OS directory holding
  versioned kernel entries and a Snapshots submenu, kept in sync with snapper) and the
  Secure Boot flow (hashed paths, `limine enroll-config`, then signing) follow CachyOS's
  `limine-entry-tool`, `limine-mkinitcpio-hook` and `limine-snapper-sync` (AUR, GPL-3.0).
  No code was copied: those tools are AUR-only, so KrissOS keeps its own small script
  ("minimum AUR").
