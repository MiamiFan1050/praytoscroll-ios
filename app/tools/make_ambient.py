#!/usr/bin/env python3
"""Original ambient loop for Scroll the Word (made from scratch here: sine pads + soft air, no samples).
Seamless: every partial and LFO completes whole cycles in the loop length."""
import math, random, struct, wave, sys
SR = 22050
T = 32.0                      # loop seconds
N = int(SR * T)
def snap(f): return round(f * T) / T          # whole cycles per loop
# A warm open chord (D, A, D, E, F#, A) with slow swells; each voice has its own breathing LFO.
voices = [(146.83, 0.22), (220.0, 0.16), (293.66, 0.12), (329.63, 0.07), (369.99, 0.07), (440.0, 0.05), (587.33, 0.025)]
voices = [(snap(f), a, snap(1.0 / random.Random(i).choice([8, 16, 32])), random.Random(i * 7).random() * 6.28) for i, (f, a) in enumerate(voices)]
detune = 1.0 / T * 2          # a slow chorus: a second copy two cycles apart per loop
out = [0.0] * N
for f, a, lfo, ph in voices:
    w1 = 2 * math.pi * f / SR; w2 = 2 * math.pi * (f + detune) / SR; wl = 2 * math.pi * lfo / SR
    for n in range(N):
        env = 0.55 + 0.45 * math.sin(wl * n + ph)
        out[n] += a * env * (math.sin(w1 * n) + 0.6 * math.sin(w2 * n + ph)) * 0.6
# Soft "air": low-passed noise, crossfaded around the loop point so it's seamless.
rng = random.Random(42)
air = [0.0] * (N + SR)
y = 0.0
for n in range(len(air)):
    y += 0.02 * (rng.uniform(-1, 1) - y)
    air[n] = y
fade = SR
for n in range(N):
    v = air[n]
    if n < fade:
        k = n / fade
        v = air[n] * k + air[N + n] * (1 - k)
    out[n] += v * 0.9
peak = max(abs(x) for x in out)
gain = 0.5 / peak             # about -6 dBFS peak: it's background
with wave.open(sys.argv[1], "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * gain)) * 32767)) for x in out))
print("wrote", sys.argv[1], N, "samples, peak gain", round(gain, 3))
