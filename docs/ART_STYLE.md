# Art style guide

Every picture in the book is painted in one style, taken from the painted Patch
(`assets/art/dark/patch.png`), the Soggy (`assets/art/dark/sogg.png`) and Drizzle
(`assets/art/dark/characters/drizzle.png`). Anything new must look like it was painted
by the same hand on the same night. Nothing new uses the old bright papercraft art in
`assets/art/characters`, `assets/art/props` or `assets/art/backgrounds`.

## The look in one line

Ink-wash and watercolour over hard black ink lines, on layered scraps of torn, soaked
paper. Dark, worn and a little menacing, never cute.

## Palette

| Role | Colours | Notes |
|---|---|---|
| Paper | sepia `#b89a70`, ochre `#a06a32`, parchment `#d8c8a8` | The base of every character and prop. Always stained, never clean white. |
| Ink | near-black `#141010`, wet sheen `#3a3a44` | Outlines, drips, the flood. The darkest value on screen. |
| Shadow | charcoal `#2a2624`, cold slate `#3c4450` | Cast shadows and backgrounds lean cold. |
| Accent | Patch's bandana red `#9a2a20`, lamp gold `#e0a850`, rust `#7a3a1e` | Used sparingly: one accent per character. |
| Tell colours | white glint `#ffffff`, red glow (modulate `1.8, 0.45, 0.4`) | Reserved. No sprite or backdrop uses pure white or a saturated red large enough to be mistaken for a tell. |

Saturation stays low everywhere except the accents and the tells.

## Light

- The key light comes from the **upper left**, warm (lamp gold). Tops and left edges of
  forms are lit; the lower right falls into cold shadow.
- Characters carry a thin, soft **rim light** on the lit side so they separate from dark
  backgrounds.
- In game, lamps add local light through `PointLight2D`; paintings must not bake in a
  second strong light source from another direction.

## Edges and paper texture

- Every form is built from **torn paper scraps** with frayed, fibrous edges, layered like
  papier-mâché. Seams show stitches or ink stains.
- Outer silhouettes have a **hard black ink line**, broken in places where the paper
  frays. Inner detail uses thinner, looser ink.
- Wet areas darken and run: ink drips hang from lower edges, never from upper ones.
- Cut-outs keep a 1–2 px soft alpha edge (see `tools/art/dark_drizzle.py`); no halo of
  the grey painting background may remain.

## Sizes on screen

Sizes are measured in game pixels, feet to top of head, with Patch as the yardstick.
Check every new character next to Patch in a screenshot before committing it.

| Kind | Height | Examples |
|---|---|---|
| Patch | 150 px (`DarkRig.display_height`) | |
| Small threat | 0.15–0.5 × Patch (22–75 px) | ink blobs, drips, Paper Moth |
| Regular enemy | 0.65–0.85 × Patch (100–130 px) | Soggy, Ink Spitter |
| Large enemy | 1.0–1.3 × Patch (150–195 px) | Tack Knight, elites |
| Friend | 0.3–1.6 × Patch (45–240 px) | Dot is a small floating blot; Bindwell and the Lamplighter sisters tower |
| Boss | 2.5 × Patch or more, often larger than the screen | Millwheel, Kraken, the Sogg |

The smoke test checks each enemy's and friend's painted height against these bands.

## Readability

Gameplay reads first.

- **Value separation.** Enemies sit in the middle of the value range with a dark ink
  outline; backgrounds sit lower and colder (darker, bluer, softer) and are slightly
  blurred. A character must stand out from its backdrop in a greyscale screenshot.
- **Silhouette.** Each enemy kind has a silhouette you can name at a glance: the Soggy is
  a hunched slump, the Ink Spitter a squat toad with a glass throat, the Tack Knight a
  tall figure with a round shield and a long pin.
- **Eyes.** Enemies have pale, pupil-less glaring eyes. They are the brightest spot on the
  enemy but stay below pure white so they're never confused with the parry glint.
- **Tells stay clear.** The white glint (parry) is the only pure white on screen. The red
  glow (dodge) multiplies the sprite's colour, so an enemy's body must keep enough
  mid-tone paper (not solid black ink) for the red to show. The combat test measures the
  glow's contrast against each tileset.
- **Safe ground is pale paper**, hazards are black ink or cold red. Tiles keep their pale
  lit lip (`tools/art/dark_tileset.py`).

## How art is made

1. Paint the concept with an image model on a **flat plain light grey background**, side
   view facing left, whole figure with margin, light from the upper left, using the
   prompt wording below.
2. Save the raw painting in `tools/art/source/<name>_raw.png` so the art can be rebuilt.
3. Cut it out and size it with a script in `tools/art/` (`dark_enemies.py`,
   `dark_bosses.py`, `dark_friends.py`, `dark_drizzle.py`, `dark_assets.py`), writing to `assets/art/dark/`.
4. Keep each sprite's origin and frame layout compatible with its scene, or change the
   collision and hurtbox shapes in the same commit so hitboxes match what's drawn.

Prompt wording shared by every painting:

> Dark mature storybook style: loose ink-wash and watercolour painting with hard black ink
> linework, layered torn paper scraps with frayed edges, desaturated sepia, ochre and
> charcoal palette with deep black ink, light from the upper left with a soft rim light,
> not cute. Isolated on a flat plain light grey background, no ground shadow, no text.
