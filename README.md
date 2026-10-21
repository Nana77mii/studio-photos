# Echoes In Pixels

> *Nana77mii's Memory Cabin — a random collection of moments captured in time.*
>
> https://nana77mii.github.io/studio-photos/

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
├── photos/
│   ├── index.json      # photo metadata (the gallery manifest)
│   ├── opt/            # served renditions: <id>-{thumb,frame,full}.webp
│   ├── <id>.jpg        # master negatives (archive only — never served)
│   ├── hero.jpg        # hero master (served via opt/hero-2400.webp)
│   └── bgm.mp3         # background track
└── tools/
    └── optimize-photos.py   # rebuilds opt/ and migrates the manifest
```

### Image pipeline

Nothing in the browsing path touches a master negative or a third-party resize proxy.

| Tier | Long edge | Typical weight | Used by |
|---|---|---|---|
| `thumb` | 600 px | ~25 KB | admin gallery |
| `frame` | 1600 px | ~100 KB | contact-sheet cards |
| `full` | 3000 px | ~400 KB | detail view, lightbox, zoom |

Every manifest row carries the three URLs (`src.thumb` / `src.frame` / `src.full`) as
**relative paths**, so the same JSON works on the project Pages URL and on
`localhost`. Rendering picks a tier with `srcset` + `sizes`; the browser chooses by
viewport and DPR. Rows without `src` (anything older) still fall back to the
`wsrv.nl` proxy, and every `<img>` keeps an `onerror` fallback to `url`.

The heroes are pre-rendered too (`photos/opt/hero-2400.webp`, ~116 KB, preloaded in
`<head>`), so the LCP never waits on the 10.5 MB original.

**Regenerating renditions** (after adding masters by hand, or to retune quality):

```bash
python3 tools/optimize-photos.py --all --write-index          # everything
python3 tools/optimize-photos.py --ids mrad3lj9te64 --no-index  # just one, don't touch JSON
```

The script honors EXIF orientation, writes `photos/opt/*.webp`, and stamps
`src` + corrected `w`/`h` back onto each row.

### `settings.json`

Site name, hero lines, hero subtitle, hero background URL, music (URL / title / artist / volume / per-year tracks), and a `typography` block. Each typography key (`heroTitle`, `siteName`, `navLinks`, …) can override font + size; **left empty, the Darkroom defaults apply** — keep them empty unless you deliberately want to override the design.

### `photos/index.json`

An array of frame objects — the gallery manifest:

```json
{
  "id": "mrad3lj9te64",
  "url": "https://raw.githubusercontent.com/Nana77mii/studio-photos/main/photos/opt/mrad3lj9te64-full.webp",
  "src": {
    "thumb": "photos/opt/mrad3lj9te64-thumb.webp",
    "frame": "photos/opt/mrad3lj9te64-frame.webp",
    "full":  "photos/opt/mrad3lj9te64-full.webp"
  },
  "location": "Prince Kung's Mansion",
  "date": "2026-06-21", "year": "2026", "month": "06",
  "category": "STREET",
  "camera": "CANON EOS 80D",
  "lens": "EF-S18-135mm f/3.5-5.6 IS USM | 35mm f/7.1 1/160s ISO 125 EV -1.33",
  "title": "Cat on the palace wall",
  "caption": "", "w": 6000, "h": 4000,
  "artist": "SHIBO", "whiteBalance": "Auto"
}
```

Frames are grouped by `year` / `location` (the "roll") and numbered within each roll; the EXIF fields feed the detail view's **Developer's Log**.

## Admin (the Darkroom)

Open the site, go to **Darkroom**, and sign in. Uploading a photo or editing settings commits the change straight to this repo through the GitHub API, so the public site updates on the next load. Editing is gated by a GitHub token you paste in the dashboard (stored only in your browser).

**Uploads transcode in the browser.** Picking files does not send masters: the
dashboard decodes each photo, encodes the three WebP tiers, and pushes them with a
single commit per batch (Git Data API: blobs → tree → commit → ref). A ten-photo
batch is one commit and one Pages build, where it used to be twenty of each.
Flip `UPLOAD_NEGATIVE = true` at the top of the upload section if you want the
original archived too — it costs 8–19 MB per frame, so it is off by default.

### Token scoping

The dashboard token needs **Contents: Read and write** on this repository only.
Prefer a fine-grained token limited to `studio-photos`; a classic token with repo
write access is a much bigger blast radius if the page is ever compromised, since
the token lives in `localStorage`. Rotate it if it is ever pasted somewhere
private-ish (a chat, an issue, a screenshot).

## Local development

No toolchain — just serve the folder statically:

```bash
python3 -m http.server 8790 --directory .
```

Then open <http://localhost:8790>. Content still loads from the live `main` branch, so what you see locally matches production.

## Deploy

`main` is the published branch (Pages source: `main` / root). Merge changes into `main` and the site follows. Because the live page reads `settings.json` from `main` at load time, always ship `index.html` and `settings.json` together so the design and its typography stay in sync.

## Repository size

The masters in `photos/*.jpg` are 400 MB+ of the repo's history, which is what makes
a fresh clone slow — the site itself never requests them. They are kept as the
archive copy; `photos/opt/` is what actually ships to visitors (~16 MB for all 33
frames).

If clone weight ever becomes a problem, the fix is deleting the masters and
rewriting history (`git filter-repo --path photos/ --invert-paths` style, then a
force-push **and** a GitHub support request to garbage-collect the unreachable
objects — a force-push alone does not shrink the repo). Back the negatives up
somewhere outside the repo first; that step is irreversible.
