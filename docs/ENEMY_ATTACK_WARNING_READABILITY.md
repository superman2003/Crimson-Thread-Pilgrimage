# Enemy attack warning readability

Enemy windup warnings retain their existing hitbox outlines, colors, and timing. A small warm line inside each warning now identifies the authored attack shape: melee slash, lunge chevron, area diamond, wave zigzag, retreat hatches, or feint V. Supported `shockwave` commands use a low double ridge; no current chapter command uses that type, so its validation fixture is synthesized from a real command dictionary.

The marker is constrained to the existing warning bounds and does not alter damage, hitboxes, or attack timing. Both the normal warning line and the original-visual warning arc share the type marker and are removed when an attack is interrupted, including hit, trip, respawn, and death cleanup.

The `enemy_visibility` regression starts representative commands from chapter JSON through `_begin_attack`, checks that the marker geometry stays inside the displayed hitbox and differs by type, exercises the supported shockwave branch, and verifies cleanup. The focused workflow also runs `audio_visual` and `obsidian_experience` to catch neighboring rendering regressions and validate the parent PR's Obsidian helper.
