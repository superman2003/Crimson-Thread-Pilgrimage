# Audio-bus topology race hardening

## Observed failure

After #96 merged, main `d36a2ff8e06a9c3566a8f33a54c6d0dd8a41d36d`
failed the unchanged room-rims GPU check in
[integration run 38940645112](https://github.com/superman2003/Crimson-Thread-Pilgrimage/actions/runs/38940645112/job/117107100445).
This main tree is identical to the previously green #96 head; the new run
exposed a crash, not a newly introduced merge-only code difference.

The exact official Godot 4.6.1 binary maps address `0x3a1ebed` to
`AudioServer::_mix_step`, dereferencing `send->index_cache`. The lower frames
are the Dummy audio driver's mixing thread. The `/root` thread violation
printed before the signal heading is the crash handler's notification on
that crashing thread, not evidence that the World JSON worker touched nodes.
This fixture uses synchronous `Main.tscn`, not World's background reader.

The same engine revision reads the bus's send route while mixing, whereas
`add_bus` and `set_bus_send` do not acquire the driver lock. Project
initialization previously rewrote every send route, even when the default
layout was already complete. `StringName` reassignment can temporarily clear
its stored pointer. This is a strong race hypothesis consistent with the
crashing instruction; the historical concurrent write was not captured, so
the unique trigger is not claimed proven.

Primary engine source:
- [Mixer read and dereference](https://github.com/godotengine/godot/blob/14d19694e0c88a3f9e82d899a0400f27a24c176e/servers/audio/audio_server.cpp#L587-L600)
- [Bus creation](https://github.com/godotengine/godot/blob/14d19694e0c88a3f9e82d899a0400f27a24c176e/servers/audio/audio_server.cpp#L862-L916)
- [Send assignment](https://github.com/godotengine/godot/blob/14d19694e0c88a3f9e82d899a0400f27a24c176e/servers/audio/audio_server.cpp#L1034-L1042)
- [StringName assignment](https://github.com/godotengine/godot/blob/14d19694e0c88a3f9e82d899a0400f27a24c176e/core/string/string_name.cpp#L180-L191)
- [Crash notification](https://github.com/godotengine/godot/blob/14d19694e0c88a3f9e82d899a0400f27a24c176e/platform/linuxbsd/crash_handler_linuxbsd.cpp#L66-L82)

## Bounded fix

- `AudioDirector._ensure_bus` uses one non-yielding driver-lock transaction
  for missing-bus creation, naming, target lookup, and actual route changes.
  Same-value send assignments are skipped. The mutex is recursive, so the
  existing internal lock in `set_bus_name` is compatible.
- Main's existing missing-base-bus fallback delegates to that transaction.
  Volume, reverb, limiter, user settings and Master behavior are unchanged.
- A narrow topology contract is called by the existing audio-retirement
  suite. All prior retirement assertions and 37 user-volume checks remain.
  It verifies the complete 13-bus layout, actual generator consumption by
  the Dummy mixer, 32 live missing-layout rebuilds, target fallback, route
  changes, idempotence, repeated director lifecycle and resource retirement.
  Static lock-scope checks complement the live test; they do not replace it.

No audio assets, loader behavior, frame budgets, workflow gates or original
GPU fixture changed. The fix was prepared on the latest upgrade-chain tip
`952175a5` and applied as the exact four-file patch to #97's `1db1b497` base,
without importing later feature changes into #97.

## Local evidence and remaining gates

Godot `4.6.1.stable.official.14d19694e`, unchanged 180-second limits:

- Latest-chain candidate `043206fb`: audio topology 21 checks / 32 live
  rebuilds, original user-volume 37 and WAV/Ogg retirement all pass.
- Same candidate: original room-rims 12 probes pass on real software GL;
  original input-settings 96 checks pass. Each ran once. No Godot ERROR or
  ObjectDB warning; GPU log retains the usual unsupported V-Sync warning.
- #97 combination: audio-retirement and input-settings both pass after the
  exact patch. Its local input-settings log also contains the environment's
  Fontconfig writable-cache warning; this is not represented as a clean log.

The new #97 and downstream published SHAs still require their own complete
CI, GPU and Linux/Windows packaged checks. Old green heads are historical
evidence only. No infinite rerun/select-green, timeout extension, warning
filter or weakened success marker is introduced. Existing broader ObjectDB
warnings and natural-campaign acceptance remain separate open work.
