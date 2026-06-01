# Tincta — Drink Builder Asset Prompt Pack

A single-source spec for generating the 41 illustrations that the drink
visualiser slots into. Built so you can paste one prompt into ChatGPT-4o
image / Midjourney / nano-banana / SDXL and get back a drop-in PNG.

> The app re-tints every asset at runtime with
> `.renderingMode(.template) + .foregroundStyle(tint)` — so **only the
> alpha channel matters**. Whatever colour the source PNG ships with gets
> replaced by Tincta's tone-on-tone tint when the card renders. This is
> the single most important spec — get it wrong and every asset will look
> washed out or invisible.

---

## TL;DR — how to use this pack

1. Copy the **Global Style Header** below into your image-gen tool *once*
   per session (Midjourney users: save as a `--style` ref; ChatGPT users:
   paste at the top of a fresh conversation).
2. For each missing asset, paste the **Per-Asset Brief** below the
   header and generate.
3. Save the result as `<asset_name>.png` (exact name from the table).
4. Drop the PNG into `Tincta/Assets.xcassets/<asset_name>.imageset/`
   alongside a `Contents.json` (template provided at bottom). Build —
   the slot system picks it up automatically.

---

## Global Style Header — paste once per session

```
STYLE: Editorial line-art illustration, single colour silhouette. Solid
opaque black shapes (#000000) on a fully transparent background (alpha 0
outside the subject). NO gradients, NO drop shadows, NO ambient occlusion,
NO colour fills beyond pure black, NO outline glow, NO halftone, NO
texture, NO photographic detail. Think modern editorial pictogram in the
spirit of Phosphor Icons Duotone or Noun Project — clean, confident,
geometric, with a touch of hand-drawn character.

FORM: Strict side-elevation view (orthographic, NOT isometric, NOT 3/4).
Subject horizontally centered, vertically grounded with a small (≤4%)
breathing margin from the bottom edge. Single object only — no
backgrounds, props, surfaces, ice cubes inside vessels, or contents
unless the brief explicitly asks. Stroke weight roughly 12–18 px at
1024×1024 (i.e. ~1.5% of canvas) — heavy enough to read at 80px on a
phone, thin enough to feel refined.

LIGHTING: None. Flat silhouette. If a hollow form needs depth (e.g. a
glass cup), use a single thin black outline + one thin interior contour
line at the rim — no shading, no highlights.

CONSISTENCY: Every asset in this pack must look like it came from the
same illustrator on the same afternoon. Reuse stroke weight, corner
radii, and proportions across siblings (e.g. all glasses share the same
rim thickness; all citrus share the same peel curl convention).

OUTPUT: 1024×1024 PNG. Transparent background (NOT white, NOT
checkerboard-baked, NOT off-white). Subject must occupy 75–90% of the
canvas height. Centered horizontally to within ±2%.
```

---

## Output spec — non-negotiables

| Property         | Value                                                    |
| ---------------- | -------------------------------------------------------- |
| Format           | `.png` (24-bit RGBA)                                     |
| Dimensions       | 1024 × 1024                                              |
| Background       | Fully transparent (alpha = 0 outside subject)            |
| Foreground       | Solid `#000000`, alpha = 255 inside subject              |
| View angle       | Strict side elevation                                    |
| Subject coverage | 75–90% canvas height, centered ±2% horizontally          |
| Margin           | ≥4% safe area from every edge                            |
| Style            | Line-art / silhouette, no shading, no gradients          |
| Anti-aliasing    | OK at edges — Lanczos-quality, no fringing               |

**Why these rules:** the SwiftUI loader applies
`.renderingMode(.template)`, which throws away all colour info and uses
alpha as a mask. White backgrounds, baked colour, gradients, or shadows
will all look like dark blobs once tinted. Side-elevation matters because
the drink builder composites vessel + ice + citrus + garnish + extras as
stacked layers on the same vertical axis — any perspective skew will
break alignment.

---

## How prompts are structured

Each row below has:
- **Filename** — exact name; do not rename
- **Brief** — paste *under* the Global Style Header

For ChatGPT image / nano-banana / Sora image: paste header + brief, generate, export as PNG.
For Midjourney v6+: append `--ar 1:1 --style raw --no background, color, gradient, shadow, fill, perspective` after the brief.
For SDXL / Flux: use the brief as positive prompt, paste the global "NO" list as negative prompt.

---

## 1 — Vessels (13)

> **Shared anatomy**: every glass is hollow — drawn as a thin black
> outline of the silhouette plus a single inner contour at the rim. No
> liquid, no ice, no condensation, no logos. The vessel sits empty on an
> invisible baseline.

| # | Filename                  | Brief                                                                                                                                                                                                                                                                                                                                                                                            |
| - | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | `vessel_rocks.png`        | An empty rocks (old-fashioned) glass, side view. Thick straight cylindrical walls with a heavy chunky base ~25% of the height. Mouth slightly wider than base (5–8°). Wall thickness implied by a thin inner rim line. Squat proportions: width ≈ 70% of height.                                                                                                                                |
| 2 | `vessel_collins.png`      | An empty Collins highball glass, side view. Tall straight-walled cylinder, mouth equal to base. Tall proportions: width ≈ 35% of height. Thin walls. Faint inner rim contour line at the top.                                                                                                                                                                                                  |
| 3 | `vessel_highball.png`     | An empty highball glass, side view. Same family as Collins but slightly squatter — width ≈ 42% of height. Straight walls, equal mouth and base, thin inner rim line.                                                                                                                                                                                                                            |
| 4 | `vessel_snifter.png`      | An empty brandy snifter, side view. Short rounded bulb sitting on a short stubby stem and small round foot. Mouth narrower than belly, opening tapers in. Belly width ≈ 60% of total height. Single thin contour for the bowl, single inner rim line.                                                                                                                                          |
| 5 | `vessel_coupe.png`        | An empty coupe glass, side view. Shallow saucer-shaped bowl on a long delicate stem with a round flat foot. Bowl is wider than deep (3:1 aspect). Stem is roughly half the total height. Crisp thin lines throughout.                                                                                                                                                                          |
| 6 | `vessel_martini.png`      | An empty classic martini glass, side view. Inverted equilateral triangle bowl, sharp V-shape, on a long thin stem with a round flat foot. Bowl edges form straight diagonals — no curve. Stem ~50% of total height.                                                                                                                                                                            |
| 7 | `vessel_nick_and_nora.png`| An empty Nick & Nora glass, side view. Tulip-shaped bowl (gently rounded, slight inward taper toward the rim) on a tall slim stem and round foot. Smaller and more bell-curved than a coupe; mouth narrower than belly.                                                                                                                                                                       |
| 8 | `vessel_hurricane.png`    | An empty hurricane glass, side view. Tall curvy lamp-chimney silhouette — pinched waist about 1/3 from the bottom, flaring outward at top and bottom. Sits on a small round flat foot. Tall: width ≈ 45% of height at the widest point.                                                                                                                                                       |
| 9 | `vessel_copper_mug.png`   | An empty copper-style mug (Moscow Mule), side view. Straight cylindrical walls, slightly squatter than a Collins, with a prominent ear-shaped handle on the right side. Handle is a thick D-loop. Flat base, no foot. Width ≈ 60% of height.                                                                                                                                                  |
| 10| `vessel_wine.png`         | An empty all-purpose wine glass, side view. Egg-shaped bowl that gently tapers toward the rim, on a long thin stem with a round foot. Bowl is taller than wide. Refined, modern proportions.                                                                                                                                                                                                  |
| 11| `vessel_flute.png`        | An empty champagne flute, side view. Very tall, very narrow cylindrical bowl that subtly tapers inward at the top, on a long thin stem and round foot. Bowl width ≈ 18% of height. Elegant and slender.                                                                                                                                                                                       |
| 12| `vessel_shot.png`         | An empty shot glass, side view. Very small heavy cylinder with a thick base (~30% of the height). Slight outward taper from base to mouth. Walls noticeably thick — implied by inner rim line. Width ≈ 80% of height (almost square).                                                                                                                                                         |
| 13| `vessel_tiki.png`         | An empty ceramic tiki mug, side view. Stylised carved-face vessel: cylindrical body with a Polynesian-style face etched into the front (deep brow ridge, almond eyes, broad nose, downturned mouth — drawn with thin black lines, no fills). Flat base. Width ≈ 65% of height. The face is integral to the silhouette but rendered as line detail, not negative space.                       |

---

## 2 — Ice (4)

> **Shared anatomy**: ice illustrations are drawn as if they would sit
> *inside* one of the vessels above. Render them roughly the size of a
> rocks-glass interior (~60% canvas width, ~50% canvas height), centered.
> The drink builder scales and clips them to fit any vessel.

| #  | Filename            | Brief                                                                                                                                                                                                                                                                                                                                                          |
| -- | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 14 | `ice_huge.png`      | A single large clear-ice cube, side view. Roughly square silhouette with crisp 90° corners (not rounded, not melted). Drawn as a thin black outline + one inner diagonal facet line suggesting transparency. No interior fill, no highlights. Cube occupies ~70% of canvas.                                                                                  |
| 15 | `ice_cubes.png`     | A loose pile of 4–5 small square ice cubes stacked irregularly in roughly a pyramidal heap. Each cube rendered as a thin black square outline with one diagonal facet line. Cubes overlap convincingly — front cubes occlude back cubes. No interior fill anywhere.                                                                                          |
| 16 | `ice_crushed.png`   | A mound of finely crushed ice — many small irregular polygonal flakes piled in a soft dome. Each flake is a thin black outline (3–6 sides, angular, no curves). Some flakes overlap, some stand free. Reads as fluffy snow-like texture from a distance, but every flake is individually drawn. Mound width ≈ 80% canvas, height ≈ 40% canvas.              |
| 17 | `ice_none.png`      | Empty transparent 1024×1024 PNG. Zero opaque pixels anywhere. This is the placeholder for "no ice" — the loader still asks for it, so an empty PNG is the right answer. (Generate by exporting a blank canvas, or skip generation and create the file in any editor.)                                                                                          |

---

## 3 — Citrus (11)

> **Shared anatomy**: citrus pieces sit on the *rim* of the vessel in the
> composite. Draw each piece centered on the canvas, oriented as if it's
> hanging off the right side of a glass rim. Twists and peels should curl
> gently. Wedges and wheels are drawn from straight-on as if facing the
> viewer.
>
> Keep proportions consistent across the citrus family: a lime wedge and
> a lemon wedge should be the same size, only the silhouette differs
> (lime slightly rounder/smaller than lemon). Peels and twists likewise.

| #  | Filename                   | Brief                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| -- | -------------------------- | -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 18 | `citrus_lemon_twist.png`   | A long thin spiral curl of lemon peel — a single ribbon making one and a half loose loops, like a corkscrew. Outer edge curves smoothly, inner edge follows in parallel ~2% canvas apart. No pith dots, no surface texture. Reads unmistakably as a twist.                                                                                                                                                                                                                                                                |
| 19 | `citrus_lemon_wedge.png`   | A lemon wedge, face-on. Pointed quarter-circle silhouette — the cut face of a lemon segment. Draw 4–5 radial lines emanating from the apex to suggest pulp segments. Add a thin outer arc separated by a small gap from the inner segment body to suggest the rind. Slightly elongated/pointed compared to a lime.                                                                                                                                                                                                            |
| 20 | `citrus_lemon_peel.png`    | A flat strip of lemon peel — a long curved rectangular ribbon with gently rounded corners, oriented diagonally. Single outline silhouette, one inner contour line ~10% in from the long edges to suggest the pith/zest boundary. Less curl than a twist (just a gentle arc).                                                                                                                                                                                                                                                |
| 21 | `citrus_lemon_wheel.png`   | A full lemon wheel — a circle (~70% canvas diameter) viewed face-on. Inside: a slightly smaller concentric circle for the rind boundary, then 8 radial divider lines from center to rind, with a small almond-shape "pulp" between each pair of dividers. No colour, just clean line work. Lemon proportions: very round.                                                                                                                                                                                                  |
| 22 | `citrus_lime_twist.png`    | A long thin spiral curl of lime peel — same construction as the lemon twist (one and a half loose loops, corkscrew), but slightly thinner ribbon (~15% narrower) and a hair shorter overall. Same drawing convention, same line weight.                                                                                                                                                                                                                                                                                       |
| 23 | `citrus_lime_wedge.png`    | A lime wedge, face-on. Same construction as the lemon wedge — pointed quarter-circle with radial pulp lines and an outer rind arc — but rounder overall and slightly smaller. Lime wedges read as more compact and chubby than lemon wedges.                                                                                                                                                                                                                                                                                  |
| 24 | `citrus_lime_wheel.png`    | A full lime wheel — same construction as the lemon wheel (concentric rind circle + 8 radial pulp dividers), but with the outer circle slightly smaller and the proportions a touch rounder. Otherwise identical line conventions.                                                                                                                                                                                                                                                                                              |
| 25 | `citrus_orange_twist.png`  | A long thin spiral curl of orange peel — same construction as lemon/lime twists, but the ribbon is noticeably thicker (~25% wider than the lemon twist). Reads as the heavier, fleshier peel of an orange. Same loose corkscrew, same line weight on the outline.                                                                                                                                                                                                                                                            |
| 26 | `citrus_orange_peel.png`   | A flat strip of orange peel — long curved rectangular ribbon, oriented diagonally, with a gentle arc. Thicker than the lemon peel strip (~25% wider). Single outline + one inner contour line suggesting the pith/zest boundary.                                                                                                                                                                                                                                                                                              |
| 27 | `citrus_orange_wheel.png`  | (Already shipped — only regenerate if you want a fresh-style match.) A full orange wheel — concentric rind circle + 8–10 radial pulp dividers + small almond pulp shapes. Larger and slightly rounder than the lemon wheel.                                                                                                                                                                                                                                                                                                   |
| 28 | `citrus_grapefruit_peel.png` | A flat strip of grapefruit peel — same construction as orange/lemon peel strips, but the widest and longest of the family (~40% wider than lemon peel). Gentle diagonal arc, single outline + one inner pith/zest contour line.                                                                                                                                                                                                                                                                                              |

---

## 4 — Garnish (10)

> Garnishes either sit on top of the drink, perch on the rim, or float in
> the liquid. Draw each centered, side-elevation, as a single isolated
> object. The compositor handles placement.

| #  | Filename                  | Brief                                                                                                                                                                                                                                                                                                                                                                                                                       |
| -- | ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 29 | `garnish_cherry.png`      | (Already shipped — only regenerate for style match.) A single maraschino cherry with its stem, side view. Round body (~40% canvas diameter), thin curved stem rising from a small attachment dimple at the top, ending in a small kink. Stem is ~70% of canvas height. Clean line silhouette, no leaf, no shading.                                                                                                          |
| 30 | `garnish_olive.png`       | A single martini olive on a thin cocktail pick, side view. The olive is an oval (~30% canvas wide, ~22% tall), pierced vertically through the center by a thin straight stick that protrudes ~20% canvas above the olive and ~25% below. Olive is solid silhouette (no pimento). Stick is a thin line.                                                                                                                       |
| 31 | `garnish_mint_sprig.png`  | (Already shipped — only regenerate for style match.) A mint sprig: a single thin vertical stem with 4–6 paired opposing leaves branching off symmetrically. Leaves are pointed ovals (lanceolate), ~12% canvas wide each, with a faint central vein line. The top of the sprig has a slightly larger cluster of 3 small leaves. Tall and narrow overall.                                                                  |
| 32 | `garnish_rosemary.png`    | A rosemary sprig: single vertical stem with many short thin needle leaves projecting outward in opposing pairs along the entire length (12–20 per side). Needles are simple short straight lines, ~8% canvas long. Top tapers to a small cluster. Tall and narrow — width ≈ 18% of height.                                                                                                                                  |
| 33 | `garnish_cinnamon_stick.png` | A cinnamon stick (quill), side view. Long rolled-bark cylinder, oriented diagonally across the canvas (lower-left to upper-right). Roughly 70% canvas long, 10% wide. Show 2–3 thin lines running along its length suggesting the rolled layers. Both ends slightly ragged/uneven. No spirals or end-on detail — pure side profile.                                                                                       |
| 34 | `garnish_star_anise.png`  | A single star anise pod, top-down view (this is the one exception to side-elevation — star anise is always shown from above). 8-pointed star silhouette where each point is a small almond-shaped pod radiating from a central hub. ~70% canvas diameter. Each pod has a thin inner contour line showing the seam where it splits open.                                                                                  |
| 35 | `garnish_cucumber.png`    | A single thin slice of cucumber, face-on. Round circle (~55% canvas diameter) with a thin inner concentric circle ~12% smaller (the skin/flesh boundary). Inside: a small cluster of 6–8 tiny oval seeds in the very center (10–12% canvas), arranged symmetrically. Otherwise clean and minimal.                                                                                                                          |
| 36 | `garnish_edible_flower.png`| (Already shipped — only regenerate for style match.) A single five-petal flower viewed face-on (pansy-style). Five rounded petals radiating from a small central dot. ~60% canvas diameter. Petals overlap slightly at the base. Each petal has a faint central vein line. No leaves, no stem.                                                                                                                            |
| 37 | `garnish_sugar_rim.png`   | A horizontal band/arc representing a sugar-frosted glass rim. Draw as a slight downward-curving arc (~80% canvas wide, ~12% canvas tall) at the vertical middle of the canvas. Fill the arc with many small irregular dots/granules of varying sizes (3–8 px each) suggesting sugar crystals. Top edge of the arc is a clean line; bottom edge is irregular and granular.                                                |
| 38 | `garnish_salt_rim.png`    | Same construction as the sugar rim arc, but the granules are slightly larger (5–12 px) and more angular/crystalline (small irregular polygons rather than dots). Sparser overall — coarse rock-salt look. Same arc shape and proportions.                                                                                                                                                                                   |

---

## 5 — Extras (3)

| #  | Filename             | Brief                                                                                                                                                                                                                                                                                                                                                                                                                |
| -- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 39 | `extra_straw.png`    | A single bent (gooseneck) drinking straw, side view, oriented diagonally. Long thin tube (~5% canvas wide, ~85% canvas tall) with a bendy concertina section about 25% from the top. Top of straw flares slightly. No stripes, no patterns — clean solid silhouette of just the straw tube outline.                                                                                                                |
| 40 | `extra_umbrella.png` | (Already shipped — only regenerate for style match.) A small paper cocktail parasol, open, side view. Round canopy (~70% canvas wide) with 8 radial spokes visible, atop a thin straight wooden pick that extends ~30% of canvas below the canopy. Pick has a small bead/cap at the top of the canopy peak.                                                                                                       |
| 41 | `extra_stirrer.png`  | A thin straight cocktail stirrer/swizzle stick, oriented vertically. Long thin rod (~3% canvas wide, ~90% canvas tall). The top has a small decorative finial — a tiny solid ball or 4-leaf clover shape ~10% canvas wide. The bottom is plain and straight. Minimal and refined.                                                                                                                                  |

---

## How to drop a generated PNG into the project

1. Save the file as `<asset_name>.png` (exact name from the table, no caps).
2. In Finder, navigate to
   `Tincta/Assets.xcassets/`.
3. Create a folder named `<asset_name>.imageset` (e.g. `vessel_rocks.imageset`).
4. Put the PNG inside.
5. Create a file inside the imageset folder called `Contents.json` with
   this exact content (this matches what xcodegen / the existing assets use):

```json
{
  "images" : [
    { "filename" : "<asset_name>.png", "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : {
    "template-rendering-intent" : "template"
  }
}
```

(Replace `<asset_name>.png` with the actual filename.)

6. Run `xcodegen` (or just open Xcode) — the asset is picked up
   automatically by `DrinkAssetSlots.hasAsset(named:)` and overrides the
   procedural fallback. No code change needed.

---

## QA checklist before you trust an asset

- [ ] Opened the PNG in Preview — background is the checkerboard
  (transparent), not white.
- [ ] Subject is roughly centered, fills 75–90% of canvas height.
- [ ] No gradient, no shadow, no shading, no second colour anywhere.
- [ ] Strokes are solid `#000000` (not dark grey).
- [ ] At 80×80 thumbnail size, the subject is still recognisable.
- [ ] Sibling assets (e.g. lemon wedge vs lime wedge) look like they
  came from the same hand.
- [ ] Dropped into the imageset, rebuilt the app, opened the drink
  builder — the asset renders in Tincta's tint colour, not its source
  colour, and at multiple vessel sizes it scales without clipping.

---

## Generation order (recommended)

Don't generate alphabetically. Generate one full **family** at a time so
you can iterate on style consistency within the family before moving on:

1. **All 13 vessels** first — establishes the visual language.
2. **All 11 citrus** — reuse the stroke weight from vessels.
3. **All 10 garnishes** — match the line refinement from citrus.
4. **All 4 ice** — last, since they need to feel consistent with both
   vessels (they sit inside) and garnishes (they share a canvas).
5. **All 3 extras** — quick clean-up batch.

If your image-gen tool drifts in style between sessions, re-paste the
**Global Style Header** at the top of every new conversation.

---

## What to do if a slot ends up unfilled

The drink builder is designed to degrade gracefully:
- **Vessels** with no asset fall back to the SF Symbol (`wineglass`,
  `mug`, `cup.and.saucer` for `wine`, `copperMug`, `tiki`) or to a
  procedural `VesselShape` stroke.
- **Ice / citrus / garnish** with no asset fall back to procedural
  SwiftUI shapes (`IceLayerView`, `CitrusView`, `GarnishView`).
- **Extras** with no asset render as `EmptyView` — so for `straw` and
  `stirrer`, the missing asset means the extra silently doesn't appear.
  Prioritise generating these two if you care about extras showing up.

So you can ship any subset of this pack at any time and nothing breaks.
