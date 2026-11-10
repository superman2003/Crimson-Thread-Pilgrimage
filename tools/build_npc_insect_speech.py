"""Render the original NPC insect language offline; runtime only plays short WAVs."""
from __future__ import annotations
import argparse
from hashlib import sha256
import io
import json
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DESIGN = ROOT / 'art_requests/npc_insect_language_v1/design.json'
AUDIO = ROOT / 'godot/assets/audio/npc_insect_language_v1'
CATALOGUE = ROOT / 'godot/data/npc_insect_language.json'


def seed(text):
    return int.from_bytes(sha256(text.encode()).digest()[:8], 'little')


def shaped_noise(rng, size, rate, centre=2400, width=1700):
    noise = rng.standard_normal(size)
    frequencies = np.fft.rfftfreq(size, 1 / rate)
    shape = np.exp(-0.5 * ((frequencies - centre) / width) ** 2)
    shape *= 1 / (1 + (frequencies / 5800) ** 8)
    result = np.fft.irfft(np.fft.rfft(noise) * shape, n=size)
    return result / max(1e-9, float(np.sqrt(np.mean(result * result))))


def syllable(token, voice, duration, pitch, rng, design):
    rate = design['sample_rate']
    count = max(128, round(duration * rate))
    t = np.arange(count) / rate
    progress = np.linspace(0, 1, count)
    vowel = next(c for c in reversed(token) if c in design['vowels'])
    formants = np.array(design['vowels'][vowel]) * voice['formant']
    vibrato = 0.014 * np.sin(2 * np.pi * 5.3 * t + rng.uniform(0, 6.28))
    grain = voice['rasp'] * 0.014 * np.sin(2 * np.pi * 31 * t)
    frequency = pitch * (1 + vibrato + grain + 0.013 * np.sin(np.pi * progress))
    phase = 2 * np.pi * np.cumsum(frequency) / rate
    sound = np.zeros(count)
    for harmonic in range(1, min(45, int(rate / 2 / frequency.max()))):
        hz = harmonic * frequency
        weights = (0.13 + np.exp(-0.5 * ((hz - formants[0]) / 120) ** 2)
                   + 0.62 * np.exp(-0.5 * ((hz - formants[1]) / 180) ** 2)
                   + 0.23 * np.exp(-0.5 * ((hz - formants[2]) / 260) ** 2))
        sound += weights * np.sin(harmonic * phase + 0.14 * harmonic) / harmonic ** 0.8
    sound /= max(1e-9, float(np.sqrt(np.mean(sound * sound))))
    air = shaped_noise(rng, count, rate, float(formants[1]), 1800)
    sound = sound * (1 - voice['breath']) + air * voice['breath'] * 0.35
    onset = min(count // 3, round(rate * (0.045 if token.startswith('sh') else 0.026)))
    consonant = shaped_noise(rng, onset, rate, 2800, 1300)
    strength = 0.32 if token.startswith(('k', 't')) else 0.20 if token.startswith('sh') else 0.05
    sound[:onset] += strength * consonant * np.sin(np.linspace(0, np.pi, onset)) ** 2
    if token.startswith(('tr', 'kr', 'r')):
        sound *= 0.84 + 0.16 * np.sin(2 * np.pi * 24 * t) ** 2
    attack = np.minimum(1, progress / 0.10)
    release = np.minimum(1, (1 - progress) / 0.20)
    envelope = np.sin(attack * np.pi / 2) ** 2 * np.sin(release * np.pi / 2) ** 2
    return sound * envelope


def render(actor, phrase_id, voice, phrase, design):
    rate = design['sample_rate']
    rng = np.random.default_rng(seed(actor + '/' + phrase_id))
    lengths = [rng.uniform(0.135, 0.205) * voice['pace'] for _ in phrase['syllables']]
    if phrase_id == 'reassure':
        lengths = [v * 1.12 for v in lengths]
    total = sum(lengths) + sum(phrase['pauses']) * voice['pace']
    pieces = [np.zeros(round(0.04 * rate))]
    cues = []
    elapsed = 0.04
    for index, (token, length, pause) in enumerate(zip(phrase['syllables'], lengths, phrase['pauses'])):
        position = (elapsed + length * 0.5) / max(total, 0.1)
        contour = np.interp(position, [0, 0.5, 1], phrase['contour'])
        pitch = voice['pitch'] * contour * rng.uniform(0.975, 1.025)
        sound = syllable(token, voice, length, pitch, rng, design)
        cues.append({'start': round(elapsed, 6), 'end': round(elapsed + len(sound) / rate, 6), 'phoneme': token})
        pieces.append(sound)
        silence = round(pause * voice['pace'] * rate)
        pieces.append(np.zeros(silence))
        elapsed += (len(sound) + silence) / rate
    sound = np.concatenate(pieces)
    voiced_until = len(sound) / rate
    sound = np.pad(sound, (0, round((0.18 if voice.get('echo') else 0.12) * rate)))
    if voice.get('echo'):
        dry = sound.copy()
        for delay, gain in [(0.065, voice['echo']), (0.125, voice['echo'] * 0.45)]:
            offset = round(delay * rate)
            sound[offset:] += dry[:-offset] * gain
    sound *= 0.105 / max(1e-9, float(np.sqrt(np.mean(sound * sound))))
    sound = np.tanh(sound * 1.15) / 1.15
    sound *= min(1.0, 0.72 / max(1e-9, float(np.abs(sound).max())))
    pcm = np.rint(sound * 32767).astype('<i2')
    output = io.BytesIO()
    with wave.open(output, 'wb') as file:
        file.setnchannels(1); file.setsampwidth(2); file.setframerate(rate); file.writeframes(pcm.tobytes())
    data = output.getvalue()
    return data, {'duration': round(len(sound) / rate, 6), 'voiced_until': round(voiced_until, 6), 'cues': cues,
                  'sha256': sha256(data).hexdigest(), 'samples': len(sound), 'peak': round(float(np.abs(pcm.astype(float)).max()) / 32768, 6),
                  'rms': round(float(np.sqrt(np.mean(pcm.astype(float) ** 2))) / 32768, 6)}


def build(check=False):
    design = json.loads(DESIGN.read_text(encoding='utf-8'))
    characters = json.loads((ROOT / 'godot/data/original_world_art_designs.json').read_text(encoding='utf-8'))['npcs']
    assert set(design['voices']) == {r['id'] for r in characters}
    catalogue = {'schema': 1, 'language': design['language'], 'sample_rate': design['sample_rate'],
                 'design_sha256': sha256(DESIGN.read_bytes()).hexdigest(), 'actors': {}}
    outputs = {}
    for actor in characters:
        actor_id = actor['id']
        clips = {}
        for phrase_id, phrase in design['phrases'].items():
            data, metrics = render(actor_id, phrase_id, design['voices'][actor_id], phrase, design)
            path = AUDIO / actor_id / (phrase_id + '.wav')
            outputs[path] = data
            clips[phrase_id] = dict(path='res://' + path.relative_to(ROOT / 'godot').as_posix(),
                                    intent=phrase['intent'], phonetic=phrase['text'], **metrics)
        catalogue['actors'][actor_id] = {'name': actor['name'], 'voice': design['voices'][actor_id], 'clips': clips}
    outputs[CATALOGUE] = (json.dumps(catalogue, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    for path, data in outputs.items():
        if check:
            if not path.exists() or path.read_bytes() != data:
                raise ValueError('Stale NPC speech asset: ' + str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(data)
    stale = set(AUDIO.rglob('*.wav')) - set(outputs)
    if stale:
        raise ValueError('Unexpected speech files: ' + ', '.join(str(p) for p in stale))
    print(f"NPC_INSECT_SPEECH actors={len(characters)} phrases={len(design['phrases'])} clips={len(outputs)-1} check={check}")
    return catalogue


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    build(parser.parse_args().check)
