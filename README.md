# Echoes In Pixels

> *Nana77mii's Memory Cabin — a random collection of moments captured in time.*

A personal photography site built as a **contact sheet from a darkroom**: frames are numbered, grouped by roll, and read like a field notebook. The photos are the only color on the page.

**Live:** served from `main` via GitHub Pages · Shot on Canon EOS 80D

---

## Design — "Darkroom · Contact Sheet / Field Log"

- **Palette:** ink `#15141A`, matboard `#201E28`, rule `#35323F`, silver `#CFCDD6`, dust `#7C7987`. No chromatic accent — the images carry all the color.
- **Type:** [Instrument Serif](https://fonts.google.com/specimen/Instrument+Serif) for display / place-names / prose, [Space Mono](https://fonts.google.com/specimen/Space+Mono) for nav, EXIF, labels and frame numbers.
- **Layout:** left-aligned grid. The hero is a roll label + first frame + a vertical exposure readout (not a big centered title).
- **Sections:** *Contact Sheet* (frame-numbered gallery grouped by roll/trip), *Field Notes*, *About*, and a *Darkroom* admin entry.
- **Motion:** one "develop" moment on load, plus a print-lift on hover.

## Architecture

The whole site is a **single static file** — [`index.html`](index.html) — with no build step:

- Tailwind (CDN) + an inline `tailwind.config` + an inline `<style>` of design tokens + an inline `<script>`.
- **GitHub is the CMS.** The public page reads content at runtime from `raw.githubusercontent.com` on the `main` branch; the built-in admin dashboard writes back through the GitHub Contents API using a personal access token kept in `localStorage`.

```
studio-photos/
├── index.html          # the entire site + admin dashboard
├── settings.json       # site config (name, hero text, typography, music)
└── photos/
    ├── index.json      # photo metadata (the gallery manifest)
    ├── <id>.jpg        # image files
    ├── hero.jpg        # hero background
    └── bgm.mp3         # background track
```

### `settings.json`

Site name, hero lines, hero subtitle, hero background URL, music (URL / title / artist / volume / per-year tracks), and a `typography` block. Each typography key (`heroTitle`, `siteName`, `navLinks`, …) can override font + size; **left empty, the Darkroom defaults apply** — keep them empty unless you deliberately want to override the design.

### `photos/index.json`

An array of frame objects — the gallery manifest:

```json
{
  "id": "mrad3lj9te64",
  "url": "https://raw.githubusercontent.com/Nana77mii/studio-photos/main/photos/mrad3lj9te64.jpg",
  "location": "Prince Kung's Mansion",
  "date": "2026-06-21", "year": "2026", "month": "06",
  "category": "STREET",
  "camera": "CANON EOS 80D",
  "lens": "EF-S18-135mm f/3.5-5.6 IS USM | 35mm f/7.1 1/160s ISO 125 EV -1.33",
  "caption": "", "w": 6000, "h": 4000,
  "artist": "SHIBO", "whiteBalance": "Auto"
}
```

Frames are grouped by `year` / `location` (the "roll") and numbered within each roll; the EXIF fields feed the detail view's **Developer's Log**.

## Admin (the Darkroom)

Open the site, go to **Darkroom**, and sign in. Uploading a photo or editing settings commits the change straight to this repo through the GitHub API, so the public site updates on the next load. Editing is gated by a GitHub token you paste in the dashboard (stored only in your browser).

## Local development

No toolchain — just serve the folder statically:

```bash
python3 -m http.server 8790 --directory .
```

Then open <http://localhost:8790>. Content still loads from the live `main` branch, so what you see locally matches production.

## Deploy

`main` is the published branch. Merge changes into `main` and the site follows. Because the live page reads `settings.json` from `main` at load time, always ship `index.html` and `settings.json` together so the design and its typography stay in sync.
