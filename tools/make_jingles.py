#!/usr/bin/env python3
"""Synthesises the three intermission jingles (assets/sounds/intermission1-3.wav):
chiptune square-wave lead + triangle bass, deterministic (re-running gives
byte-identical files). Parts match the cartoon scenes in intermission.gd.

  python3 tools/make_jingles.py
"""
import wave, pathlib
import numpy as np

SR = 44100
EIGHTH = 0.178                       # seconds per eighth note
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "sounds"

def hz(m): return 440.0 * 2 ** ((m - 69) / 12.0)

def square(f, n, duty=0.25):
    t = np.arange(n) / SR
    return np.where((t * f) % 1.0 < duty, 1.0, -1.0)

def triangle(f, n):
    t = np.arange(n) / SR
    return 2.0 * np.abs(2.0 * ((t * f) % 1.0) - 1.0) - 1.0

def voice(notes, wave_fn, per, gate=0.85, gain=1.0):
    """notes: midi numbers (0 = rest), each lasting `per` eighths."""
    out = []
    n_each = int(SR * EIGHTH * per)
    for m in notes:
        seg = np.zeros(n_each)
        if m:
            n_on = int(n_each * gate)
            w = wave_fn(hz(m), n_on)
            env = np.exp(-np.linspace(0, 2.2, n_on))            # plucky decay
            env[: int(SR * 0.004)] *= np.linspace(0, 1, int(SR * 0.004))
            seg[:n_on] = w * env * gain
        out.append(seg)
    return np.concatenate(out)

def part(lead, bass):
    l = voice(lead, lambda f, n: square(f, n), 1, 0.8, 0.55)
    b = voice(bass, triangle, 4, 0.95, 0.5)
    n = max(len(l), len(b))
    l = np.pad(l, (0, n - len(l))); b = np.pad(b, (0, n - len(b)))
    return l + b

ACTS = {
    1: [  # chase (minor), reversal (major)
        ([69,72,76,72, 69,72,76,72, 67,71,74,71, 67,71,74,71, 69,72,76], [45,45,43,43,45]),
        ([72,76,79,76, 72,76,79,84, 83,81,79,77, 76,74,72,0, 79,0,84,0], [48,48,55,55,53]),
    ],
    2: [
        ([62,65,69,65, 62,65,69,74, 72,69,65,69, 62,0,62,0, 64,65,67], [38,38,41,41,38]),
        ([67,71,74,71, 67,71,74,79, 78,74,71,74, 67,0,67,0, 69,71,72,74,76], [43,43,50,50,48,48]),
    ],
    3: [
        ([60,0,60,64, 67,0,67,64, 62,0,62,65, 69,0,69,65, 64,67,72,0], [36,36,38,38,40]),
        ([67,70,74,70, 67,70,74,79, 77,74,70,74, 67,0,70,0, 74,0,77,0, 79,0], [43,43,46,46,50,50]),
        ([84,79,84,79, 86,81,86,81, 88,0], [48,48,55]),
    ],
}

def main():
    for act, parts in ACTS.items():
        sig = np.concatenate([part(l, b) for l, b in parts] + [np.zeros(int(SR * 0.3))])
        sig = sig / np.max(np.abs(sig)) * 0.85
        pcm = (sig * 32767).astype(np.int16)
        stereo = np.repeat(pcm[:, None], 2, axis=1)
        path = OUT / f"intermission{act}.wav"
        with wave.open(str(path), "wb") as w:
            w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
            w.writeframes(stereo.tobytes())
        print(path.name, round(len(sig) / SR, 2), "s")

if __name__ == "__main__":
    main()
