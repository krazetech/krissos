# KrissOS site audit (Sungai Petani rework)

> **Status 2026-11-25:** every finding is fixed on both the English and Malay pages, including the design-hook ones (M2 contrast, M3 finale wash, L2 and L3 were checked and dismissed or fixed). The Malay pages now carry the same H5 story as English: release `110` is Sungai Petani, today's download is its nightly preview, and `kriss migrate` is Done on the roadmap (it was still "Akan datang" in `ms/roadmap.html`). Also ported to Malay: `og:url` on index, download, install, roadmap and shell; the "Before you boot" heading (L8); the `&nbsp;` before "GB" (L8); and `og-sp.jpg` with a Malay `og:image:alt` on every Malay page (L4). `sitemap.xml` already lists the help and hardware pages in both languages.
>
> Checked on 2026-11-25: all 22 pages (11 EN, 11 MS) at 1440px and 390px with an in-page script: no sideways scroll, no unnamed links or buttons, no broken images, and all 45 local URLs return 200. Screenshots checked for the Malay home, roadmap, hardware and help pages.
>
> **Still open:**
> - L9: check ko-fi.com and sourceforge.net by hand (they block curl).
> - L5: self-hosting the two font files (optional).
> - The help and hardware pages are new since this audit. They passed the checks above but have not had a full design review.

Date: 2026-11-20 · Branch `kz/site-sungai-petani` (uncommitted working tree) · Scope: `site/*.html` (EN), `site/style.css`, `site/home.js`. `site/ms/*` was not reviewed.

How this was checked: every EN page was rendered in headless Chrome over CDP at 1440×900 and 390×844 (mobile emulation), in dark and light colour schemes, with screenshots at several scroll points (including three points through the sticky "Your desktop follows the sun" section). An in-page script checked for horizontal overflow, heading order, image load and alt text, link names and loaded fonts. Contrast ratios were calculated from the CSS tokens (WCAG 2.x formula). All local and external links were fetched with curl. LunariaOS's `script.js` and `style.css` were read to compare its motion.

Already fine: no page scrolls sideways at 390px or 1440px. All local links and images resolve. Heading order has no skipped levels on any page. Every content image has an alt; decorative ones use `alt=""`. All image dimensions are set. Reduced motion is respected by the CSS animations. The light theme tokens all pass AA.

---

## High

### H1. Hero title is mostly hidden on phones
- **Page/element:** `index.html` `.sp-title` + `.sp-cut` (style.css `.sp-title`, `.sp-hero > img`)
- **Evidence:** At 390px the title wraps to two lines and the cut-out tower covers the middle of both. It reads "Sungai P…tani", and the small "KRISSOS" label shows as "K   SOS" because the flag cuts through it. Desktop (1440px) only loses "ng" in "Sungai", which still reads.
- **Fix:** In the ≤560px range, place the title so it clears the tower. For example: `top: 9%`, a smaller `font-size`, and `object-position` moved so the tower sits right of centre (≈ `62% 35%`). Or keep the effect on desktop only and hide `.sp-cut` on narrow screens. Put the small "KrissOS" label above the flag line.

### H2. Logo and Ko-fi links have no accessible name on phones
- **Page/element:** all pages, `.nav .brand`, `.nav li.kofi a`, and the footer `.brand` (style.css `@media (max-width:560px)`: `.brand span{display:none}`, `.nav li.kofi span{display:none}`)
- **Evidence:** At 390px the in-page check found three links with no name on every page. The logo `<img>` has `alt=""` and its text `<span>` is `display:none`. The Ko-fi heart SVG is `aria-hidden`. Screen readers announce "link" only. The footer rule also hides the word "KrissOS" visually, so the footer shows a bare logo.
- **Fix:** Hide those spans visually with a `.sr-only`-style clip instead of `display:none`, or add `aria-label="KrissOS home"` and `aria-label="Support KrissOS on Ko-fi"`. Scope the brand rule to `.nav .brand span` so the footer keeps its wordmark.

### H3. The "Skip to content" link appears under the nav
- **Page/element:** all pages, `.skip:focus` (z-index 10) vs `.nav` (fixed, z-index 20, top 10px)
- **Evidence:** The skip link shows at `top:12px; left:16px`, which is exactly where the fixed nav sits, and the nav stacks above it. Keyboard users tab to an invisible link.
- **Fix:** `.skip:focus { z-index: 30; position: fixed; }`

### H4. Broken alt attribute on the shell launcher screenshot
- **Page/element:** `shell.html`, `<img src="shots/launcher.webp" alt="The launcher with "fi" typed …">`
- **Evidence:** The unescaped quotes end the attribute early. The rendered alt is just "The launcher with ", and `fi"` plus the rest are parsed as junk attributes. (index.html escapes them correctly with `&quot;`.)
- **Fix:** Use `&quot;fi&quot;` or curly quotes “fi”.

### H5. Release copy contradicts itself across pages
- **Pages:** index, download, roadmap
- **Evidence:**
  - Home lists `kriss migrate` as **Live**. Roadmap phase 7 lists it as **Coming**.
  - Home: "Introducing the first major release … Sungai Petani". Roadmap: the first tagged release is `110` ("KrissOS 1.0 · Goal"). Download: "Releases are tagged by codename: `110`, `115`". So is the codename Sungai Petani or 110, and is Sungai Petani released or still a preview? The hero CTA says "Download the preview".
- **Fix:** Pick one story, for example "Sungai Petani is the name of release 110; today you can try the nightly preview of it". Then update the download "Releases" row, roadmap h1/lede and the 110 row to match. Set `kriss migrate` to the same status on both pages.

## Medium

### M1. Scroll motion is not like LunariaOS (your request) — DONE: `site/reveal.js` + end of style.css, EN pages
How LunariaOS does it (`lunariaos.com/script.js`, `style.css`):
1. Each section is a full-height panel with `data-reveal`. An `IntersectionObserver` (thresholds 0 / 0.25 / 0.7) adds `.is-visible` once ≥25% of the section shows. It **removes it once the section is fully off screen** (`ratio === 0`), so the animation **plays again every time** you scroll back to it.
2. Children with `.reveal` start at `opacity:0; transform:translateY(~2.6u)`; media also use `scale(.93)`. On `.is-visible` they transition with `opacity .9s ease, transform 1.1s cubic-bezier(.22,1,.36,1)`. A per-element `--delay` staggers them: title, then text, then the media.
3. The hidden state only applies under `.js` (set by the script), so there is no blank page without JS. Under `prefers-reduced-motion` everything is just shown.
4. With a mouse and full motion, wheel and arrow keys glide one panel at a time (900 ms ease-in-out). They only do this when every panel fits the viewport.

What we have: CSS scroll-driven animations (`animation-timeline: view()`), **scrubbed** to the scroll position, not timed. Evidence:
- They only run in Chromium and recent Safari. Firefox shows no motion at all.
- Because they are scrubbed, an element sits half-faded if you stop scrolling mid-way. They don't "play" the way LunariaOS's do.
- On the home page only cells and screenshot frames have `.reveal`. Section heads (label, h2, lede), the stats sheet and the finale don't animate at all.

**Suggested fix:** Replace the `@supports (animation-timeline: view())` reveal block with a ~15-line `IntersectionObserver` in a shared script that toggles `.is-visible` on each `section` (add at ≥0.25, remove at 0). Add `.js .reveal{opacity:0;transform:translateY(28px)}` and `.js .is-visible .reveal{…transition…; transition-delay:var(--delay)}`. Tag the label, h2, lede and media in each section with `.reveal` and a stepped `--delay` (0, .08s, .16s, .26s). Keep the reduced-motion override. **Skip the panel-snapping:** our sections are taller than the screen (features grid, 300vh sun story), so snapping would fight the reader. Scroll-jacking also works against the "familiar" goal.

### M2. Low-contrast text (design-hook claim: confirmed in four places)
| Where | Measured | Note |
|---|---|---|
| index `.say .w` (words not yet lit) | 1.48:1 | Also stays dim for reduced-motion users. home.js runs regardless. |
| index `.sun-steps li` (inactive steps, black at 45% on cyan) | 2.79:1 | Real content, not decoration |
| index `.finale .label` "TRY IT" (cyan on the sky photo) | ≈2.4:1 | Estimated against the sky behind it |
| `.foot-cols p`, `.tag.plan`, sponsor label (`--muted` on black) | 4.53:1 | Passes, but only just. Fails (4.2:1) wherever `--muted` sits on `--surface`. |

Everything else passes: `--soft` 9.3:1, link 8.5:1, buttons 8.5:1, all light tokens ≥5.2:1.
**Fix:** Raise the inactive sun steps to opacity .7 (≈5:1). Start `.say` words at opacity .35 and light them all under `prefers-reduced-motion: reduce` (check `matchMedia` in home.js). Make the finale label `#fff` or `--fg`. Nudge `--muted` to ≈`#7C8790`.

### M3. Finale photo is buried under a wash (design-hook claim: confirmed on index, dismissed on download)
- **index.html `.finale > img`:** `opacity:.55` over black plus a black gradient. The day photo renders as a flat grey-blue (screenshot at 1440). It reads muddy rather than "by day", and the lede sits on a busy mid-grey (≈4.6:1).
- **download.html:** has no raster image at all, so that claim doesn't apply.
- **Fix:** Show the photo at full opacity. Use a gradient only where the text sits (a radial or bottom-weighted `rgba(0,0,0,.55)` behind the centre column). Or use `tower-dim.webp` there and keep the day photo for the sun story.

### M4. Lock screenshot has the wrong height attribute
- **Page/element:** index `<img src="sp/lock.webp" width="1920" height="788">`
- **Evidence:** The file is 1920×1080. The browser reserves a 2.4:1 box, then the image loads at 16:9 and the layout jumps (CLS) inside the `.duo` row.
- **Fix:** `height="1080"`. If the intended crop is a panorama, re-export at 1920×788 instead.

### M5. Light mode: the dark nav sits on white with a heavy shadow
- **Pages:** shell, download, install, roadmap in light mode
- **Evidence:** The nav is forced dark (`rgba(16,19,22,.82)`) with `box-shadow: 0 12px 40px rgba(0,0,0,.45)`. On white the shadow is a grey smudge under the bar.
- **Fix:** In light mode, either soften the shadow (`0 8px 24px rgba(0,0,0,.12)`) or give the taskbar its light style (the shell has one, see `shots/quick-light.webp`).

### M6. Sticky "follows the sun" section on phones
- **Page/element:** index `.sun-stage` at ≤860px
- **Evidence:** It works: the clock runs 07:30 → 19:30, the steps highlight and the night image fades in. But the photo box is only ~315px wide inside a ~330px-tall dotted black area, so most of the sticky screen is empty. The nav clears the stage (nav bottom 66px, stage top 82px) at both widths.
- **Fix:** On phones, drop the `.sun-view` padding and dot area so the photo fills the panel width, or let the photo sit full-bleed behind the text block.

### M7. Stats tiles: the numbers don't line up
- **Page/element:** index `.qt b` (`margin-top:auto`)
- **Evidence:** Captions wrap to different line counts, so the big numbers sit at different heights: at 1440, "0" and "1" are ~20px higher than "2" and "5"; at 390, "5" is ~40px lower than "2".
- **Fix:** Put the number directly under the icon (drop `margin-top:auto`) and let the caption take the rest, or give the caption a fixed `min-height`.

## Low

- **L1. Footer padding left over from the bottom nav.** `footer { padding: 80px 0 120px }`. The 120px bottom padding was for the old bottom taskbar, so there's now ~120px of empty black under the sponsor row. Use `80px 0 64px`.
- **L2. Tight line-height (design-hook claim: dismissed).** h1/h2 at 1.08 and `.say` at 1.08 are normal for display type, and no lines collide. `.sp-title` at .82 only wraps on phones, where "Sungai/Petani" touch but don't overlap. Body copy is 1.6. No change needed. If H1 is fixed by shrinking the phone title, check the gap again.
- **L3. Cramped padding (design-hook claim: mostly dismissed).** Sections use 80–160px padding, which is generous, not cramped. The only tight spot is `.cell.list { padding-block: 8px }` on the "Coming from Windows?" list, where the first row sits close to the cell's top border. Use 16px.
- **L4. SEO meta.**
  - No `<link rel="canonical">` or `og:url` on any page.
  - No `hreflang="x-default"`.
  - No `robots.txt` or `sitemap.xml`.
  - `og.jpg` is still the old logo-on-wallpaper image; NOTES.md already lists a Sungai Petani og image as wanted.
  - The live site (krazetech.github.io/krissos) still serves the old title until this branch ships.
  - Fix: add canonical + `og:url` per page, `x-default` → EN, and a 10-line sitemap.
- **L5. Fonts.**
  - Google Fonts loads Figtree 400/500/600/700(/800) and JetBrains Mono 400/500/600. On the pages checked, Figtree 500 never loads, so drop it from the URL.
  - Home is the only page that loads 800, which is correct.
  - Consider self-hosting the two WOFF2 variable files: it saves two cross-origin connections and fits the offline/self-reliant pitch.
- **L6. Image sizes.**
  - All images are small (largest 45 KB). But the 2400px tower images ship to 390px phones with no `srcset`.
  - Only `tower-dim.webp` is preloaded. `tower-dim-cut.webp` is also above the fold and part of the LCP, so preload it too or give it `fetchpriority="high"`.
- **L7. Small link target.** The footer link "GPL-3.0-or-later" is 104×17px, and "README" on install.html is 68×20px, below the 24px minimum target size. Add `padding-block: 4px` to inline footer links.
- **L8. Copy nits.**
  - Mixed UK/US spelling: "centred" and "Colours" vs "Minimize", "maximize" and "colors". Pick one; UK fits MY English.
  - Download "Two settings, then boot." lists three items (the third isn't a setting). Either "Two settings, then boot" with 2 items, or "Before you boot".
  - "1.6 GB" can wrap between number and unit (seen at 390px). Use `&nbsp;` in the JS template (`${size} GB`).
  - Roadmap at 390px: the 64px number column wastes width, and `kriss-meta-gaming` breaks mid-word. Shrink the column to 40px on phones.
- **L9. External links not verifiable by script.** ko-fi.com and sourceforge.net return 403 to curl (bot protection), so check them once by hand. Everything else returned 200, including the keyring `.gpg` and `repo-x86_64/kriss.db`.

---

## Suggested order
1. H2, H3, H4: tiny CSS/HTML fixes with a big accessibility payoff.
2. H5: copy decision, which needs your call on naming.
3. H1 + M1: phone hero and LunariaOS-style reveal (one design pass on the home page).
4. M2–M7, then the Lows.
