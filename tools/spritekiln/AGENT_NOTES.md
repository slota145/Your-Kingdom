# SpriteKiln cheat sheet for agents (Your Kingdom, SpriteKiln 0.3.0)

Dense notes for AI agents making art with SpriteKiln here. Project history, decisions and lessons
(Polish) are in `docs/ART_SPEC.md` §10.20; this file does not repeat them at length.

## 1. Where the full docs live
Author's guides, version 0.3.0, identical to upstream `docs/agent/`: `tools/spritekiln/.spritekiln/agent/`.
| file | read when |
|---|---|
| `workflow.md` | always first: commands, the loop, outputs, cost |
| `spec.md` | before editing any YAML: every key, primitive, modifier, paint, animation, socket |
| `modeling.md` | shaping: "which shape for what" table, 8 tested recipes (sword, hood, cape...), kits table, heads |
| `animation.md` | characters: frame counts/ms table, anticipation/strike/overlap, events, QA meanings |
| `art-direction.md` | reviewing: `review` numbers and the order to judge things in |
| `style.md` | the `[style]` interview; what each style answer means for modeling |
| `splash-to-model.md` | working from a reference image (brief, palette, IoU targets, pitfalls) |
| `recipe.md` | multi-agent pipeline modeler -> director -> animator, cost control |
Upstream (reachable 2026-11-09): https://github.com/LucasJRamos/spritekiln. Worth knowing there:
`docs/format.md` (atlas/JSON contract, pivot, `ground_k`, sockets), `docs/engines/godot.md`
(`KilnSprite2D`), `specs/characters/*` (gargoyle, knight, templar, huntress...) and `specs/props/*`
(crates, gas_lamp, mine, training_dummy) as examples, `specs/kits/*.yaml` (kit sources),
`spritekiln/data/spec.schema.json` (the authoritative key list), `CHANGELOG.md`.

## 2. Our setup (do not change without the owner)
- `tools/spritekiln/spritekiln.toml`: specs in `art/specs`, palette `kingdom` (`art/specs/palettes/kingdom.yaml`,
  also `town.yaml`), style recorded 2026-11-09 (34 px character, frame 64, 8 dirs, no mirror, selective
  outline, soft shading, light `top`, face minimal, fluid). Folder has `.gdignore`; `out/`, `.kilncache/`,
  `*_ref/` are git-ignored. Commands must run inside `tools/spritekiln/` (they look up for the toml).
- **Camera for everything: `pitch: 30`** (sin 30 = 0.5 = our 2:1 iso), **`scale: 0.05176`** (shared density;
  1 tile = 2.343 units, 2x2 plot = 4.69). Never change scale per asset; a bigger thing gets a bigger `size`
  and a moved `camera.center`. Known exception: goods icons use pitch 35 (32x32, ART_SPEC §10.20).
- Buildings/props: `kind: prop`, `directions: [se]` (yaw 45 turns a square footprint into the 2:1 diamond),
  `shadow: null`, plus `render: {outline: dark, lines: depth+normal, light: classic, shading: toon}` (the
  PixelLab-matching look). `spritekiln style` lists these as deviations: expected, they are on purpose.
- Ships: `kind: prop`, `directions: 8`, 4 rocking frames via channels; frame size and `camera.center` chosen
  so SpriteKiln's pivot lands exactly on the game's pivot (`export_ship.py` checks it).
- Pivot: SpriteKiln's pivot = ground point under the model origin (JSON `spritekiln.pivot`). Ours for
  buildings is the plot's front corner, 32 px lower (for 2x2); for 64 px characters ours is (32, 58) vs
  SpriteKiln's (32, ~48). Export scripts shift/crop; engine `export`/`godot` are not used yet.
- Generators write specs (`gen_*.py`), the CLI renders them, `compose_*.py` makes comparison sheets,
  `export_*.py` copies into `assets/`. Edit the generator, not the generated YAML, for generated families.

## 3. The loop and commands
```
spritekiln style                                  # once per session; style is recorded, do not re-interview
spritekiln validate <spec>                        # after EVERY edit; warnings matter (unknown key = silently ignored)
spritekiln validate --strict <spec>               # warnings as errors (good in generator self-checks)
spritekiln spec outline <spec>                    # map of a long spec with line ranges (read this, not the file)
spritekiln spec show <spec> parts.roof animations.walk.keys[2] [--resolved]   # just the blocks you edit
spritekiln pose <spec> --dirs all [--draft]       # preview PNG; --draft = 1 ray/px, ~6x faster, rough edges
spritekiln pose <spec> --anim chop --frame 3 --dirs s,se,e,n
spritekiln pose <spec> --focus head --dirs all    # 12x close-up of a bone (or parts by name: --focus roof)
spritekiln pose <spec> --bg grass.png [--tint 0.9,0.9,1.0] [--no-crop]   # over a game floor capture, 1px=1px
spritekiln render <spec> [--anims idle,walk] [--dirs s,e] [--draft] [--jobs N] [--force] [--size 96]
spritekiln review <spec> --bg <floor.png> [--against <other spec>] [--ref <img> --ref-dir se] [--anims walk]
spritekiln style preview <spec> --dir se [--field outline --field shading]   # look choices side by side
spritekiln palette ramp "#8a5a30" --steps 6 [--hue-shift X] | palette extract <img> --k 6 -o <yaml>
spritekiln kits [<name>]                          # list kits / a kit's params with comments
spritekiln cache info|prune --max-mb 500|clear [paths]
```
- Speed: `pip install numba` (separately; `[fast]` extra not needed). Log says `renderer: numba`. First run
  compiles ~10 s. Force with `--backend numba|numpy` or env `SPRITEKILN_BACKEND`.
- **`--jobs` with numba:** default is 1 process using every core (numba threads). `--jobs N>1` splits cores
  (`NUMBA_NUM_THREADS = cores/N`). Running several `spritekiln render` processes in parallel by hand
  oversubscribes cores; set `NUMBA_NUM_THREADS` per process (e.g. 4 renders on 4 cores -> 1 each) or run
  one at a time. Without numba, workers are sized from free memory; `--jobs 1` is always safe.
- Render cache (`.kilncache/`) keeps per-pixel geometry: changing ramps, materials, `ambient`,
  `rim_strength`, outline/shading/lines/dither re-renders in seconds. Changing geometry, `light.dir`, or a
  light preset that moves the light re-traces. `--force` ignores the cache; interrupted renders resume.
- `render --anims X` writes an atlas with only those clips: finish with a full `render` (cached, fast).
- `render --draft` writes only `preview-draft/` GIFs/contact sheets: motion check only, never exportable.
- Big frames are slow: `camera.supersample` (default 3, i.e. 9 rays/px) and `camera.coverage` (default 4
  of 9 samples to fill a pixel) are spec keys. `--size >= 128` drops them to 2/2 automatically, but a spec
  that is natively 192-370 px keeps 3/4. Untested idea for draft-quality big props: `supersample: 2`,
  `coverage: 2` (check thin parts afterwards). Fewer polygon points also renders faster.
- Outputs `out/<name>/`: `<name>.png` atlas (row per anim x dir, never trimmed), `.json` (Aseprite hash +
  `spritekiln` block: pivot, camera, durations, events, sockets), `_normal.png`, `_emissive.png`,
  `preview/<anim>_8dir.gif`, `preview/contact_<anim>.png`, `qa.json`. Never edit outputs.
- QA errors (clipped at the edge, empty frame, timing target missed) block an asset. Keep >= 2 px margin.
- Variants side by side: copy the spec under another `name:`; delete its `out/` and `.kilncache/` after.

## 4. Spec essentials that are easy to get wrong
- Axes: +Y up (ground y=0), **+Z = model front** (faces camera in `s`), **+X = model's left** (screen right
  in `s`). Dirs s,se,e,ne,n,nw,w,sw = yaw 0,45,90,135,180,-135,-90,-45. Light fixed in world, model turns.
  With `[se]`: +z = game +x (lower-right wall), +x = game -y (see `gen_townhouses.py` docstring).
- Units: 1 px = `scale` units horizontally; heights shrink by cos(pitch) on screen (`height_k`), ground
  depth by sin(pitch) (`ground_k` = 0.5 for us). Details < ~2 px vanish; radius < ~0.025 breaks into dots.
- `rot` is Euler radians `[x,y,z]` applied Ry*Rz*Rx. Bones: `pos` in parent space, `scale` scalar/vector,
  `inherit_rot/inherit_scale: false`, `at: <frame>` takes origin from another frame.
- Local frames of `ellipsoid/box/torus/extrude/revolve`: `align: [p0,p1]` points local **z** p0->p1, then `rot`.
  - `extrude`: 2D profile in local x-y, `depth` along local z, centred on `c`. `rot: [1.5708,0,0]` lays it
    flat (profile on the ground, y forward, depth vertical). To run a profile ALONG an aligned line add
    `rot: [1.5708,0,0]` after `align`.
  - `revolve`: section turned about local **y**; profile is the whole cross-section (x = radius, closed
    outline), `offset` for rings, `angle: [a0,a1]` partial. Only round things; asymmetric brim = extrudes.
  - Profiles: `circle`, `rect` (+`chamfer`/`round`), `polygon` (+`round`), `bezier` [P0,C0,P1,C1...]
    (quadratic, does NOT pass through C; straight segment = C at midpoint; closes back to P0).
  - `tube`: passes through the first and last points only; inner points pull (push them outwards for curls).
- Modifiers on single primitives: `shell` (centred on the surface: outside grows by shell/2; shrink radii
  by half to keep the outer surface), `elongate` (stretch the middle), `twist`, `bend` (curves the outline
  of an extrude, cannot curl a plate: use revolve or shell).
- `cut:` subtracts primitives (any type, incl. `extrude`/`revolve`); `plane` only under `cut` (`n` + `at`
  or `c`; removes the side `n` points to). Cuts are a union (you cannot intersect two cutters).
  `cut_blend` default 0.01; `{mode: groove, depth, width}` engraves a line instead of removing volume.
- Joins: `blend: 0.05` smooth, or `{mode: chamfer|round|stairs, k, n}` (pays on flat-faced prims only).
- `paint:` layers (later wins) recolour the surface, no geometry: `prims` (volume must enclose the surface),
  `stripes` (axis, width, period/offset or `at`), `rings`, `grid` (rivets), `spots` (scale, density, seed),
  `checker`; `edge: true` adds a 1 px line. Paint keeps the part's lighting, cannot change silhouette, and
  is cheaper than parts/cuts. Paint follows the part's `space`.
- Thin parts: a pixel fills when >= `coverage` of its 9 samples hit; the part with most samples wins.
  `min_cover: 1|2` for thin details outside the silhouette, `priority: 2-3` for thin things in front of
  the body (staff, rope, mast stays). Never on big parts (they fatten).
- Inner lines only where two **parts** meet (or folds with `crease: true` material). A visible edge (shingle
  course, plank) needs its own part. `line: false` on a material removes its inner lines (half-timbering).
- Materials: `ramp` (index 0 = outline tone), `bands: [lo,hi]`, `finish: matte|soft|metal|glossy`,
  `highlight`, `rim`, `thresholds` (hard steps), `gamma` (default 1.05; <1 lifts darks), `emissive` +
  `band` + `glow`, `two_sided` (sails, membranes), `outline: false`, `line_color`, `line_band`, `crease`,
  `edge_highlight` (lights convex bevels: try on stone blocks, beams), `dither`. Top-level `ramps:` adds
  spec-local ramps; `palette:` can be a list (later wins).
- `render:` per spec overrides the style: `outline` (selective|dark|colored|none), `outline_color`,
  `shading` (soft|flat|toon), `lines` (depth|depth+normal|none), `highlights`, `dither` (bayer2/4),
  `light` (classic|top|dramatic|soft|flat), `snap`, `crease_angle` (50), `min_run` (2). Record why in `brief`.
- Mirroring: write only `_L` items (+x side); `_R` twins are automatic (x negated, rot -> (rx,-ry,-rz)),
  channels too, with the same sign convention (+x = away from body). Never use global asymmetric channels
  (twist, head_yaw) inside `_L` expressions: put them on a central parent bone. One-sided things: no `_L`.
  `sx` = -1 inside an `_R` twin: write cheats as `pulse(yaw*sx, 90, 50)`.
- Expressions: any number/vector may be a string; vars = channels, `p` (0..2pi), `t`, `f`, `n`, `yaw`,
  `dir`, `sx`; funcs `sin cos abs min max clamp lerp/mix smoothstep pulse(x,c,w) pos neg roty rotx rotz
  v() radians floor sign exp noise(x,seed)`, `pi tau`, `@`. Lists are numpy vectors. Frame count may not
  depend on direction. Points: `[x,y,z]`, `"@frame"`, `{at: frame, off: [...]}`, `{between: [...], t}`.
- `extends`/`remove`/`use`: lists (prims, cut, keys) are replaced, not merged. Kit items are named
  `<as>_<name>`; change them by overriding keys in the spec, never edit kit files. Project kits go in
  `art/specs/kits/` (a kit wins over a built-in of the same name): worth it when a piece repeats (window,
  chimney, barrel, crate).
- `shadow: {rx, ry, alpha, color, offset}` or `null`. `light: {dir, rim, rim_strength, ambient, shadows,
  ao, mode}` overrides the preset.
- YAML: edit as text, keep the compact `{...}` style; never round-trip specs through a YAML dumper
  (our generators write text on purpose).

## 5. Reference workflow
- `ref prep <img> [--tol 4..15] [--pitch 30]` -> `<img>_ref/`: `cutout.png` (background flood from the border),
  `cutout_pitch30.png`, `palette.yaml` (hue-shifted ramps `fam1..`, rename them), `ref.json` (proportions).
  `--pitch` (default 38!) only affects that preview cutout.
- `ref compare <spec> <img> --dir <d> [--anim A --frame i] [-o folder]` -> `out/compare_<d>.png/.json`:
  reference | sprite | overlay (red = only ref, blue = only ours) | 8 dirs | palettes, IoU and band hints
  ("at 40-50% height too wide"). Correction uses the **spec's** camera pitch (squashes ref height by
  cos(pitch)); `--no-pitch-correction` for raw. Each silhouette is normalised to its own bounding box, so a
  mast tip or flag moves the whole score: read the overlay, not only the number.
- Targets: corrected IoU >= 0.65 good; do not chase > 0.85. Raw IoU tops out ~0.56.
- Pitfalls: angled photos (3/4 ship models) give low IoU for nothing; use a true side/front elevation or
  match `--dir`. Cropped references (no feet/keel) make IoU meaningless. Dynamic poses: compare against an
  animation frame. A weapon/bowsprit bigger than the body: note it, keep it out of judgement.
- `review --ref <img> --ref-dir <d>` gives the same IoU inside the review report.

## 6. Review numbers (`review.json`, `review.png`)
- L* median/p90 under `--tint`; contrast = sprite median minus floor median (negative = sinks into grass);
  pixels per material per direction (does the accent survive?); bands per material; colour count (QA warns
  above palette size + 12); `--against` area ratio and L* deltas vs an approved asset.
- Put recurring targets in the spec: `review: {min_lstar: 20, background: grass.png, tint: [..],
  materials: {tunic: {min_px: 30}}}` -> every render's QA warns. Not used by us yet.

## 7. Animation essentials (for future characters)
- Cycles: `frames` + `channels` as functions of `p`; loop only with periodic terms (never `t` in a loop).
  Actions: `loop: false`, `keys` (one key = one frame, `ms`, `set`, `event`, `tween: n`, `ease`, `carry: true`
  to inherit instead of resetting to defaults). `ms` can be a list or an expression.
- Timing at 64 px: idle 4-8 x 120-180 ms; walk 8 x 90-110; run 6-8 x 70-90; light attack 5-7 (antic.
  100-170, strike 40-60, recovery 100-130); hit 3-4 x 60-90; death 6-10, last 400+ ms. Style = fluid: walk 8,
  idle 6-8, tweens on actions.
- Amplitude: 1 px = 0.05176 units. Idle bob ~0.05; < 0.5 px flickers. `snap: [root, torso_rot]` rounds body
  motion to whole pixels; QA `info.boil` measures blinking shading (> 4 % warns).
- Walk: feet `[x, lift*pos(-sin(p)), z0 + stride*cos(p)]`, `bob` in cos(2p), cycles in place.
- Work animations must be hand-built (kits only bring sword-like attacks). Kit `cheat` params turn weapons to
  the camera per direction: drive them from a channel and zero them where the tool must follow the facing.
- Events (`windup`, `hit`, `release`, `step_l/r`, our own e.g. `chop`) fire when that frame becomes visible.
  `timing: {chop: {hit: 300ms, total: 9f}}` (60 fps, +-1 frame) makes validate/QA enforce gameplay timing.
- **Sockets** `{bone, offset, when}` export `[x, y, depth]` per anim/dir/frame relative to the pivot
  (depth > 0 in front of the body). This is the route to our carried-goods anchor maps (ART_SPEC §4.5):
  put a socket at the centre of the carried load / held tool.
- Check key frames in s, e, n and a diagonal; `n` and diagonals are where strikes vanish behind the body.
- Kits (20, CC0): weapons `sword axe mace hammer spear staff bow pistol rifle shield`; headwear `helmet hood
  hat`; body `cape belt pouch`; head `head hair ponytail bun`. Templates: `humanoid`, `side_humanoid`
  (`spritekiln new <n> --extends` writes a short spec over the template; heads/hair come from kits, decide
  them in `brief.head`). Missing for us: tools (pick, hoe, sickle, saw, hammer as tool), sacks, baskets,
  carts: candidates for project kits.

## 8. Art-direction checklist (order matters)
1. Silhouette at 1x in every rendered direction (diagonals and `n` break first; thin edge-on parts become sticks).
2. Head/face up close (`--focus head`): no bump under 2 px, eyes on the surface, head not a ball, hair in parts.
3. Fidelity to reference (`must_keep` traits, IoU/hints, palette).
4. Pixel art: banding noise, value contrast between materials (beats hue), outline, colour count, < 2 px
   details; value against the game floor (`review --bg`).
5. Animation: arcs, anticipation, impact frame, follow-through, loops seamless, ms timing, all directions.
6. Project style (and that `render:` exceptions are recorded in `brief`).
7. QA errors/warnings. Director output: verdict + max 8 fixes with concrete spec changes.
Never call something visual good without looking at the PNG (or reading `review` numbers).

## 9. Pitfalls and limits from the docs/help we have not hit yet
- Unknown keys only warn and are ignored: a typo (`pitc:`) silently does nothing. Read validate warnings.
- A part's `blend` swallows features smaller than it (a sphere r 0.025 in `blend: 0.05` becomes a lump).
- `mirror: true` swaps hands of asymmetric props and flips the light side: keep it off (style says no).
- A tip stays on the silhouette only if its sides are steeper than the pitch (for us 30 deg): very flat
  roof ridges/spires can vanish from behind. Check back views of 8-direction props.
- A hood/hat/roof must cover the corners of what is under it or they poke through in back views.
- `crease: true` on soft organic blends draws noise; use it on plates, stone, beams.
- `validate` warns about shells/extrusions/tubes/profiles thinner than 1 px and self-crossing polygons:
  treat those as errors.
- `light.mode: flat` / style `light flat` exists for normal-map lighting in the engine (`export --lit`,
  CanvasTexture) - possible future night/torch lighting; we bake light now.
- `render --size` rescales frame and scale together (same framing), not density: not a way to change
  character height. Shadow ellipse scales with it.
- The engine runtime (`spritekiln godot`, `KilnSprite2D`, `--install-addon`) would add `addons/spritekiln/`
  to the game: do not run it without the owner's decision; our own export scripts are the current route.
- `spritekiln update` / `init --force` rewrite project AI files; don't run casually (style is kept).
- MCP server (`spritekiln mcp`, tools return images) exists; not registered in this project.
- Upstream roadmap (not in 0.3): `kind: tile`, dual-grid floor tilesets, modular walls, VFX primitives,
  `spritekiln watch`. Terrain tiles are not a SpriteKiln job yet.

## 10. Our own lessons (details: ART_SPEC §10.20, "Lekcje")
- pitch 30 + scale 0.05176 for everything; tile 2.343 units; door ~1.5, ground-floor wall ~2.2-2.4.
- With `shading: toon`, a dark line material needs `bands: [0, 1]` (a `band: 0` turns light).
- `extrude` polygon with two identical consecutive points -> SpriteKiln cuts a huge circle. Round, then dedupe.
- `stripes` on sloped roofs get lost: separate parts / thin dark rods per course instead.
- Hollow interiors (hull, crate): cut one upward-elongated ellipsoid with a flat floor, not two crossing cuts.
- Ships: hull = side-profile `extrude` clipped by top-view `extrude`s; waterline cut moves with the hull bone;
  foam = thin `shell` in world space so it stays on the water while rocking; billowed sail = front cap of a
  big ellipsoid `shell` cut by planes. QA "idle slides" on rocking props is fine.
- Kit cheats in work/attack animations: wire `with: {cheat: <channel>}` and zero it per key; direction-dependent
  angles via `pulse(yaw, c, w)` so weapons never point straight at the camera.
- Long weapons in a 64 px frame clip in thrusts (about 1 unit of reach each side). Never change `camera.scale`;
  give the character a bigger square frame instead (`size: 96`, `camera.center [0, 2.51, 0]`: feet at (48, 90));
  the game reads the frame size from the sheet height (CharacterSheet.frame_side), export_character.py checks the pivot.
- A kit's bone rotation can be overridden from the spec (`bones: {bow: {rot: "[bow_x, 0, bow_z]"}}`): a rotation
  about the hand's x alone cannot raise a weapon upright with the arm stretched out. Find angles numerically:
  `rig.Ctx(spec, env).frame('<bone>')` + `rig.socket_points` per frame (`anim.frames_of`), e.g. the bow's
  string (socket `bow_nock`) must be nearer the torso than the grip in every frame (owner 2026-11-10).
- Export scripts handle pivot offsets and symmetric cropping (game mirrors houses about the image width).
- After `tools/generate_art.gd`, restore SpriteKiln/PixelLab buildings: `git checkout assets/buildings/hut/` etc.
