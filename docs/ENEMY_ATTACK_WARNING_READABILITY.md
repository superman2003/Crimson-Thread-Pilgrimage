# Enemy attack warning readability

Enemy windup warnings retain their existing hitbox outlines, colors, and timing. A small warm line inside each warning now identifies the authored attack shape: melee slash, lunge chevron, area diamond, wave zigzag, retreat hatches, or feint V. Supported `shockwave` commands use a low double ridge; no current chapter command uses that type, so its validation fixture is synthesized from a real command dictionary.

The marker is constrained to the existing warning bounds and does not alter damage, hitboxes, or attack timing. Both the normal warning line and the original-visual warning arc share the type marker and are removed when an attack is interrupted, including hit, trip, respawn, and death cleanup.

The `enemy_visibility` regression starts representative commands from chapter JSON through `_begin_attack`, checks that the marker geometry stays inside the displayed hitbox and differs by type, exercises the supported shockwave branch, and verifies cleanup. The focused workflow also runs the registered `audio_retirement` suite and `obsidian_experience` for the parent PR's Obsidian helper. The older `audio_visual_validation.gd` references `original_map/moss_cavern` images that are absent from both `main` and the CH05 branch, so it cannot run successfully from a repository checkout; warning geometry is covered directly by `enemy_visibility`.
