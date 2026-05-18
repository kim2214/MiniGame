#!/usr/bin/env python3
"""Generate retro 8-bit style SFX as WAV files for the MiniGame project.

Re-run this script any time you want to regenerate the assets:
    python3 scripts/generate_sfx.py

Outputs to assets/audio/.
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio"


def write_wav(name: str, samples: list[float]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / name
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # 16-bit PCM
        wf.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s))
            frames += struct.pack("<h", int(v * 32767))
        wf.writeframes(bytes(frames))
    print(f"  wrote {path} ({len(samples)} samples, {len(samples)/SAMPLE_RATE:.2f}s)")


def square(freq: float, t: float, duty: float = 0.5) -> float:
    return 1.0 if (t * freq) % 1.0 < duty else -1.0


def envelope(t: float, duration: float, attack: float = 0.005, release: float = 0.05) -> float:
    if t < attack:
        return t / attack
    if t > duration - release:
        return max(0.0, (duration - t) / release)
    return 1.0


def make_jump() -> None:
    """Short rising 'boop' for jump."""
    duration = 0.16
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Pitch sweep 380Hz -> 880Hz
        freq = 380 + (880 - 380) * (t / duration)
        env = envelope(t, duration, release=0.08)
        s = square(freq, t) * 0.28 * env
        samples.append(s)
    write_wav("jump.wav", samples)


def make_hit() -> None:
    """Crash: descending pitch + noise burst."""
    duration = 0.32
    n = int(SAMPLE_RATE * duration)
    samples = []
    rng = random.Random(0)
    for i in range(n):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, release=0.18)
        # Descending pitch
        freq = 240 * (1 - 0.65 * (t / duration))
        tone = square(freq, t, duty=0.35)
        # Filtered noise (averaging adjacent samples acts like simple low-pass)
        noise = rng.uniform(-1, 1)
        s = (noise * 0.55 + tone * 0.45) * 0.42 * env
        samples.append(s)
    write_wav("hit.wav", samples)


def _arpeggio(notes_hz: list[float], note_duration: float, volume: float = 0.25) -> list[float]:
    """Sequence of notes back-to-back, each with its own envelope."""
    samples: list[float] = []
    for freq in notes_hz:
        n = int(SAMPLE_RATE * note_duration)
        for i in range(n):
            t = i / SAMPLE_RATE
            env = envelope(t, note_duration, release=0.04)
            samples.append(square(freq, t) * volume * env)
    return samples


def make_score_milestone() -> None:
    """C5-E5-G5 arpeggio."""
    notes = [523.25, 659.25, 783.99]
    samples = _arpeggio(notes, note_duration=0.10, volume=0.24)
    write_wav("score_milestone.wav", samples)


def make_new_best() -> None:
    """Fanfare: C-E-G-C-G-C (octave jump at end)."""
    notes = [523.25, 659.25, 783.99, 1046.50, 783.99, 1046.50]
    samples = _arpeggio(notes, note_duration=0.10, volume=0.24)
    write_wav("new_best.wav", samples)


def main() -> None:
    print(f"Generating SFX -> {OUT_DIR}")
    make_jump()
    make_hit()
    make_score_milestone()
    make_new_best()
    print("Done.")


if __name__ == "__main__":
    main()
