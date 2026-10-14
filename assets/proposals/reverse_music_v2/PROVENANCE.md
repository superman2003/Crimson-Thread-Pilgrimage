# Provenance — reverse_music_v2

- Creation: 2026-10-14, Crimson Thread Pilgrimage resource proposal.
- Method: original event-based composition, deterministic offline additive/modal synthesis, circular stereo reflections, NumPy/SciPy signal processing, FFmpeg libvorbis encoding.
- No sampled/recorded instruments, voices, external recordings, soundfonts, downloaded music, or neural music generation. Synthetic “voice”, “horn”, “bow”, “flute” and other names identify timbral intentions, not claims of real performance.
- Project references: six chapter identities in `godot/data/campaign_chapters.json`; project-owned Silent Toll and Crimson Thread motif definitions in `docs/spec/20260726160400000_音效与音乐设计规格.md`. New regional answering phrases, score events and arrangements are supplied in the generator; existing audio is neither copied nor remixed.
- This is a resource-only proposal. No runtime wiring or final human listening approval is claimed.
- Rights: all newly authored score events, synthesis code, generated audio and documentation in this proposal are dedicated under CC0-1.0, to the extent rights exist and may be waived. No third-party asset attribution is required for these newly generated files.

## Sound recipes

All pitched signals use A4=440 Hz / equal temperament. Shared instrument envelopes use sin-squared attacks and smooth local releases; event tails wrap across the loop. Equal-power panning creates stereo from separately positioned parts. Circular reflections at 71/113/179/293/431/683/947 ms provide width. These delays are quieter than the dry sound, with no external impulse response.

| Timbre | Synthesis recipe |
|---|---|
| Bronze | Modal sine ratios 1, 2.01, 2.76, 4.07, 5.43, independent exponential decays, 14 ms softened attack. |
| Glass | Sines 1, 2, 3.01, 4.02, lightly inharmonic high partials, 9 ms attack. |
| Celesta | Ratios 1, 2, 3.98, 5.02 with progressively shorter decays. |
| Pluck / harpsi | Five/six harmonic sines with faster upper-partial decay; no physical string recording. |
| Bow | Six harmonics with 160 ms attack and deterministic vibrato. |
| Horn | Six weighted harmonics, 85 ms attack and deterministic vibrato. |
| Organ | Fundamental, octave, twelfth and suboctave; 80 ms attack. |
| Synthetic vowel | Six weighted partials and slow amplitude arch; 380 ms attack. No words, performer or voice clone. |
| Flute | Fundamental plus weak second/third partials and 110 ms attack. |
| Thump | Low sine with short exponential pitch relaxation and fast decay. |
| Brush | Seeded white noise filtered to a narrow 850 Hz-centered band, soft 12 ms onset, fast decay, low mix level. |

Per-file seed, every note, source code, dependency versions, decoded measurements and audio hashes are included in the companion proposal directories. Original generated audio has no source recording to attribute.
