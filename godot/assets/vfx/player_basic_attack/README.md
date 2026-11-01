# Player basic attack VFX

These effects were rendered with the Scenario Pixel VFX Forge local renderer.
The recipes are the source of truth; the PNG frames and sprite sheets are the
Godot runtime outputs.

Six Forge recipes cover horizontal left/right, ground up/down and air up/down.
The runtime uses a texture sector from each Forge render as a material on a
blade ribbon. It never plays the independently sweeping sprite animation.

`player_basic_attack_vfx.gd` reads measured root/tip anchors from the displayed
character cel and its preceding cel. The ribbon interpolates both grip and
blade angle, with its leading edge ending exactly at the current steel tip.
Only cutting cels 2/3 can emit. A held pose fades its last tail in 55 ms; the
next cutting cel supplies the next measured sweep. Left-facing, sprite offsets
and pogo scaling use the character's real transforms. Recovery, interruption,
missing blade anchors and region handoffs cancel the effect.

The effect is presentation only. Hit detection and timing remain in
`scripts/player_controller.gd`.

Rebuild with Node 18+ and the separately downloaded renderer:

    node tools/build_player_basic_vfx.mjs /path/to/scenario-pixel-vfx/scripts/render.mjs

Run the focused acceptance suite:

    node tools/run_python_tool.mjs tools/run_godot_regressions.py --suite player_basic_attack_vfx

`artifacts/player_basic_vfx/` contains isolated Godot GL captures and previews.

The original downloadable Forge bundle did not include a license file. Keep
the renderer outside the repository and commit generated assets plus recipes
only until Scenario publishes an explicit license for this bundle.
