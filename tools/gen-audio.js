// DEX DASH procedural audio generator.
// Synthesizes every music track and sound effect from code - fully original audio.
// Emits 44.1kHz 16-bit stereo WAV files.
const fs = require("fs");
const path = require("path");

const SR = 44100;

// ---------- WAV writer ----------
function writeWav(file, samples) {
  // samples: Float32Array interleaved stereo
  const data = Buffer.alloc(samples.length * 2);
  for (let i = 0; i < samples.length; i++) {
    let v = Math.max(-1, Math.min(1, samples[i]));
    data.writeInt16LE(Math.round(v * 32767), i * 2);
  }
  const buf = Buffer.alloc(44);
  buf.write("RIFF", 0);
  buf.writeUInt32LE(36 + data.length, 4);
  buf.write("WAVE", 8);
  buf.write("fmt ", 12);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20); // PCM
  buf.writeUInt16LE(2, 22); // stereo
  buf.writeUInt32LE(SR, 24);
  buf.writeUInt32LE(SR * 4, 28);
  buf.writeUInt16LE(4, 32);
  buf.writeUInt16LE(16, 34);
  buf.write("data", 36);
  buf.writeUInt32LE(data.length, 40);
  fs.writeFileSync(file, Buffer.concat([buf, data]));
  console.log(`  ${path.basename(file)}: ${(samples.length / SR / 2).toFixed(1)}s`);
}

// ---------- synthesis helpers ----------
class Mix {
  constructor(seconds) {
    this.n = Math.floor(seconds * SR);
    this.L = new Float32Array(this.n);
    this.R = new Float32Array(this.n);
    this.final = new Float32Array(this.n * 2);
  }
  add(sample, vol, pan = 0) {
    for (let i = 0; i < this.n && i < sample.length; i++) {
      const v = sample[i] * vol;
      this.L[i] += v * (1 - Math.max(0, pan));
      this.R[i] += v * (1 + Math.min(0, pan));
    }
  }
  get len() { return this.n; }
  render(file, master = 0.9) {
    for (let i = 0; i < this.n; i++) {
      this.final[i * 2] = Math.tanh(this.L[i] * master);
      this.final[i * 2 + 1] = Math.tanh(this.R[i] * master);
    }
    writeWav(file, this.final);
  }
}

const TWO_PI = Math.PI * 2;

function makeWave(seconds, fn) {
  const n = Math.floor(seconds * SR);
  const out = new Float32Array(n);
  for (let i = 0; i < n; i++) out[i] = fn(i / SR);
  return out;
}

// envelopes
function adsr(seconds, a, d, s, r) {
  return makeWave(seconds, (t) => {
    if (t < a) return t / a;
    const dt = t - a;
    if (dt < d) return 1 + (s - 1) * (dt / d);
    const rt = t - a - d - s * (0); // release handled separately
    return s;
  });
}
// simple one-shot: attack + decay
function ad(seconds, a, d) {
  return makeWave(seconds, (t) => {
    if (t < a) return t / a;
    return Math.max(0, 1 - (t - a) / d);
  });
}
function softEnv(seconds, curve = 3) {
  return makeWave(seconds, (t) => Math.max(0, 1 - t / seconds) ** curve);
}

function osc(freq, type, t, phase = 0) {
  const ph = TWO_PI * freq * t + phase;
  switch (type) {
    case "sine": return Math.sin(ph);
    case "square": return Math.sign(Math.sin(ph));
    case "saw": return 2 * ((freq * t + phase / TWO_PI) % 1) - 1;
    case "tri": return 4 * Math.abs(((freq * t + phase / TWO_PI) % 1) - 0.5) - 1;
    case "noise": return Math.random() * 2 - 1;
    default: return 0;
  }
}

function note(freq, seconds, type = "sine", env = "ad", a = 0.005, d = null) {
  d = d ?? Math.max(0.02, seconds * 0.7);
  const e = env === "ad" ? ad(seconds, a, d) : softEnv(seconds);
  return makeWave(seconds, (t) => e[t * SR | 0] * osc(freq, type, t));
}

function kick(seconds = 0.35) {
  const e = ad(seconds, 0.002, 0.3);
  return makeWave(seconds, (t) => {
    const f = 60 + 90 * Math.exp(-t * 22);
    return e[t * SR | 0] * Math.sin(TWO_PI * f * t);
  });
}
function snare(seconds = 0.25) {
  const e = ad(seconds, 0.001, 0.18);
  const tone = makeWave(seconds, (t) => Math.sin(TWO_PI * (190 + t * -40) * t));
  return makeWave(seconds, (t) => (tone[t] * 0.45 + (Math.random() * 2 - 1) * 0.55) * e[t]);
}
function hat(seconds = 0.12, open = false) {
  const e = ad(seconds, 0.001, open ? 0.1 : 0.03);
  const h = makeWave(seconds, (t) => {
    const n = (Math.random() * 2 - 1);
    return n * Math.sin(TWO_PI * 8000 * t) * 0.35 + n * 0.65;
  });
  return makeWave(seconds, (t) => h[t] * e[t]);
}
function clap(seconds = 0.2) {
  const e = makeWave(seconds, (t) => {
    const burst = Math.exp(-t * 40);
    return burst * (t < 0.02 ? t / 0.02 : 1);
  });
  return makeWave(seconds, (t) => (Math.random() * 2 - 1) * e[t] * 0.8 + Math.sin(TWO_PI * 250 * t) * e[t] * 0.3);
}

// ---------- sequencer ----------
// seq: array of {b: beat, dur, f, type, vol, pan}
function seqToTrack(beats, bpm, events) {
  const secs = (beats / bpm) * 60;
  const n = Math.floor(secs * SR);
  const L = new Float32Array(n);
  const R = new Float32Array(n);
  const blen = (60 / bpm);
  const byBeat = {};
  for (const ev of events) {
    (byBeat[ev.b] = byBeat[ev.b] || []).push(ev);
  }
  for (const [bStr, evs] of Object.entries(byBeat)) {
    const b = +bStr;
    for (const ev of evs) {
      const start = b * blen;
      const len = Math.min(n - start * SR, (ev.dur || blen * 0.8) * SR);
      if (len <= 0) continue;
      const e = ev.env === "long" ? softEnv(len / SR, 2) : null;
      const e2 = e ? null : ad(len / SR, 0.004, Math.max(0.03, (len / SR) * 0.6));
      const e3 = e ? null : ad(len / SR, 0.001, 0.16);
      const e4 = e ? null : ad(len / SR, 0.001, 0.03);
      const e5 = e ? null : ad(len / SR, 0.002, len / SR * 0.8);
      const e6 = e ? null : ad(len / SR, 0.005, len / SR * 0.8);
      const e7 = e ? null : ad(len / SR, 0.002, 0.3);
      const e8 = e ? null : ad(len / SR, 0.002, len / SR * 0.5);
      for (let i = 0; i < len; i++) {
        const t = i / SR;
        let v;
        if (ev.type === "kick") v = Math.sin(TWO_PI * (60 + 90 * Math.exp(-t * 22)) * t) * e7[i];
        else if (ev.type === "snare") {
          v = (Math.sin(TWO_PI * (190 + t * -30) * t) * 0.45 + (Math.random() * 2 - 1) * 0.55) * e3[i];
        }
        else if (ev.type === "hat" || ev.type === "hat_open") {
          const nn = Math.random() * 2 - 1;
          v = (nn * Math.sin(TWO_PI * 8000 * t) * 0.35 + nn * 0.65) * (ev.type === "hat_open" ? e4 : e5)[i];
        }
        else if (ev.type === "bass") {
          const saw = 2 * ((ev.f * t) % 1) - 1;
          const sub = Math.sin(TWO_PI * ev.f * t) * 0.5;
          v = (saw * 0.7 + sub) * e2[i];
        }
        else if (ev.type === "lead" || ev.type === "arp" || ev.type === "pad") {
          const en = e ? e[i] : e6[i];
          let wave;
          if (ev.type === "pad") {
            wave = Math.sin(TWO_PI * ev.f * t) * 0.6 + Math.sin(TWO_PI * ev.f * 2 * t) * 0.3 + Math.sin(TWO_PI * ev.f * 3 * t) * 0.15;
          } else {
            const detune = Math.sin(TWO_PI * ev.f * 1.005 * t) * 0.5 + Math.sin(TWO_PI * ev.f * 0.995 * t) * 0.5;
            wave = Math.sign(Math.sin(TWO_PI * ev.f * t)) * 0.35 + detune * 0.4;
            if (ev.type === "arp") wave = Math.sin(TWO_PI * ev.f * t) * 0.7 + wave * 0.4;
          }
          const vib = 1 + 0.004 * Math.sin(TWO_PI * 5.5 * t);
          v = wave * en * vib * (ev.type === "pad" ? 0.6 : 1);
        }
        else if (ev.type === "pluck") {
          v = Math.sin(TWO_PI * ev.f * t) * e8[i] * 0.8 + Math.sin(TWO_PI * ev.f * 2 * t) * e8[i] * 0.2;
        }
        else v = 0;
        const vol = ev.vol ?? 1;
        const idx = start * SR + i;
        if (idx >= n) break;
        L[idx] += v * vol * (1 - Math.max(0, ev.pan || 0));
        R[idx] += v * vol * (1 + Math.min(0, ev.pan || 0));
      }
    }
  }
  // normalize
  let peak = 0;
  for (let i = 0; i < n; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
  const g = peak > 0 ? 0.85 / peak : 1;
  const final = new Float32Array(n * 2);
  for (let i = 0; i < n; i++) {
    final[i * 2] = Math.tanh(L[i] * g * 1.2);
    final[i * 2 + 1] = Math.tanh(R[i] * g * 1.2);
  }
  return final;
}

const N = {
  C: 16.35, "C#": 17.32, D: 18.35, "D#": 19.45, E: 20.6, F: 21.83,
  "F#": 23.12, G: 24.5, "G#": 25.96, A: 27.5, "A#": 29.14, B: 30.87,
};
function nf(noteName, octave) { return N[noteName] * Math.pow(2, octave); }

// ---------- music tracks ----------
// Each track: 8 bars, bpm. Patterns differ by mood.
// returns interleaved stereo Float32Array
function buildTrack(opts) {
  const { bpm = 128, bars = 8, root = "A", scale = [0, 2, 4, 5, 7, 9, 11], style = "energetic", name } = opts;
  const beats = bars * 4;
  const rootF = nf(root, 3);
  const m2 = (v) => rootF * Math.pow(2, v / 12);
  const events = [];
  const isMinor = opts.minor;

  // drums
  const four = style === "chill" || style === "calm";
  for (let b = 0; b < beats; b++) {
    events.push({ b, type: "kick", vol: 1 });
    if (b % 4 === 2) events.push({ b, type: "kick", vol: 0.55 });
    if (four) { if (b % 2 === 1) events.push({ b, type: "snare", vol: 0.8 }); }
    else { if (b % 4 === 2) events.push({ b, type: "snare", vol: 0.85 }); }
    if (b % 2 === 1) events.push({ b, type: "hat", vol: 0.5 });
    if (b % 4 === 3) events.push({ b, type: "hat", vol: 0.4 });
    if (b % 4 === 1 && !four) events.push({ b, type: "hat_open", vol: 0.25 });
    if (b % 8 === 6) events.push({ b, type: "clap" in opts ? "snare" : "hat", vol: 0.1 });
  }
  // bass: root pattern
  const bassPatt = [0, 0, 7, 0, 0, 7, 3, 5];
  for (let b = 0; b < beats; b++) {
    const deg = bassPatt[b % 8];
    const f = m2(deg - 12);
    events.push({ b, type: "bass", f, dur: 0.9, vol: 0.5 });
  }
  // chords/pads
  const prog = isMinor ? [0, 3, 5, 4] : [0, 5, 3, 4];
  for (let bar = 0; bar < bars; bar++) {
    const ch = prog[bar % 4];
    const f1 = m2(ch), f2 = m2(ch + (isMinor ? 3 : 4)), f3 = m2(ch + 7);
    for (const f of [f1, f2, f3]) {
      events.push({ b: bar * 4, type: "pad", f, dur: 3.6, vol: style === "chill" ? 0.22 : 0.13, env: "long" });
    }
  }
  // leads
  const leadPatt = [0, 2, 4, 7, 4, 2, 9, 7, 12, 9, 7, 4, 2, 0, -2, 2];
  const leadType = style === "chill" ? "arp" : "lead";
  const leadVol = style === "chill" ? 0.32 : 0.3;
  for (let b = 0; b < beats; b++) {
    if (b % 1 === 0) {
      const deg = leadPatt[(b * 2) % 16];
      const f = m2(deg + 12);
      events.push({ b, type: leadType, f, dur: 0.45, vol: leadVol, pan: (b % 2 === 0 ? -0.2 : 0.2) });
    }
    if (b % 4 === 2) {
      const f = m2(leadPatt[(b * 2 + 1) % 16] + 12);
      events.push({ b, type: "pluck", f, dur: 0.3, vol: 0.2 });
    }
  }
  if (style === "calm") {
    // sparse piano-ish notes
    for (let bar = 0; bar < bars; bar++) {
      const degs = [12, 7, 9, 12, 9, 16, 14, 12];
      for (let i = 0; i < 8; i++) {
        events.push({ b: bar * 4 + i * 0.5, type: "pluck", f: m2(degs[i % 8]), dur: 1.2, vol: 0.16 });
      }
    }
  }
  const samples = seqToTrack(beats, bpm, events);
  return { samples, bpm, beats };
}

// ---------- SFX ----------
function buildSfx() {
  const out = {};
  // jump: quick rising blip
  out.jump = makeWave(0.18, (t) => {
    const f = 300 + 500 * (t / 0.18);
    return Math.sin(TWO_PI * f * t) * softEnv(0.18)[t * SR | 0] * 0.7;
  });
  // jump2 (higher jump, gravity flip)
  out.jump_big = makeWave(0.22, (t) => {
    const f = 220 + 700 * (t / 0.22);
    return Math.sin(TWO_PI * f * t) * softEnv()[t * SR | 0] * 0.7;
  });
  // death: descending harsh noise
  out.death = makeWave(0.5, (t) => {
    const e = softEnv()[t * SR | 0];
    const f = 700 - 600 * (t / 0.5);
    return (Math.sin(TWO_PI * f * t) * 0.5 + (Math.random() * 2 - 1) * 0.5) * e * 0.9;
  });
  // coin: two-tone ding
  out.coin = makeWave(0.28, (t) => {
    const e = softEnv()[t * SR | 0];
    const f = t < 0.05 ? 1046 : 1568;
    return Math.sin(TWO_PI * f * t) * e * 0.6 + Math.sin(TWO_PI * f * 2 * t) * e * 0.2;
  });
  out.secret = makeWave(0.4, (t) => {
    const e = softEnv()[t * SR | 0];
    const seq = [784, 1046, 1318, 1568];
    const idx = Math.min(3, Math.floor(t / 0.1));
    return Math.sin(TWO_PI * seq[idx] * t) * e * 0.6;
  });
  // portal: whoosh
  out.portal = makeWave(0.35, (t) => {
    const e = softEnv()[t * SR | 0];
    const f = 200 + 800 * t / 0.35;
    return Math.sin(TWO_PI * f * t) * e * 0.5 + (Math.random() * 2 - 1) * e * 0.3;
  });
  out.portal_speed = makeWave(0.4, (t) => {
    const e = softEnv()[t * SR | 0];
    const f = 120 + 1400 * (t / 0.4);
    return Math.sin(TWO_PI * f * t) * e * 0.55;
  });
  out.teleport = makeWave(0.5, (t) => {
    const e = softEnv()[t * SR | 0];
    const f = 900 * (1 - t / 0.5) + 100;
    return (Math.sin(TWO_PI * f * t) * 0.4 + Math.sin(TWO_PI * f * 1.5 * t) * 0.3) * e;
  });
  out.dash = makeWave(0.3, (t) => {
    const e = softEnv()[t * SR | 0];
    const f = 500 * (1 - t * 1.6) + 200;
    return Math.sin(TWO_PI * f * t) * e * 0.7 + (Math.random() * 2 - 1) * e * 0.2;
  });
  out.rotate = makeWave(0.45, (t) => {
    const e = softEnv()[t * SR | 0];
    return (Math.sin(TWO_PI * 400 * t) + Math.sin(TWO_PI * 600 * t)) * e * 0.4;
  });
  out.gravity = makeWave(0.3, (t) => {
    const e = softEnv()[t * SR | 0];
    return Math.sin(TWO_PI * (300 - 150 * t / 0.3) * t) * e * 0.6;
  });
  out.checkpoint = makeWave(0.5, (t) => {
    const e = softEnv()[t * SR | 0];
    const seq = [523, 659, 784, 1046];
    const idx = Math.min(3, Math.floor(t / 0.12));
    return Math.sin(TWO_PI * seq[idx] * t) * e * 0.55;
  });
  out.click = makeWave(0.06, (t) => Math.sin(TWO_PI * (500 + 300 * t) * t) * softEnv()[t * SR | 0] * 0.5);
  out.hover = makeWave(0.08, (t) => Math.sin(TWO_PI * 800 * t) * softEnv()[t * SR | 0] * 0.3);
  out.win = makeWave(1.2, (t) => {
    const e = softEnv()[t * SR | 0];
    const seq = [523, 659, 784, 1046, 1318, 1568];
    const idx = Math.min(5, Math.floor(t / 0.18));
    return Math.sin(TWO_PI * seq[idx] * t) * e * 0.55;
  });
  out.achievement = makeWave(1.0, (t) => {
    const e = softEnv()[t * SR | 0];
    const seq = [392, 523, 659, 784, 659, 784, 1046];
    const idx = Math.min(6, Math.floor(t / 0.12));
    return (Math.sin(TWO_PI * seq[idx] * t) * 0.5 + Math.sin(TWO_PI * seq[idx] * 2 * t) * 0.2) * e;
  });
  out.countdown = makeWave(0.15, (t) => Math.sin(TWO_PI * 880 * t) * softEnv()[t * SR | 0] * 0.5);
  out.go = makeWave(0.4, (t) => {
    const e = softEnv()[t * SR | 0];
    return Math.sin(TWO_PI * 1174 * t) * e * 0.55 + Math.sin(TWO_PI * 1568 * t) * e * 0.3;
  });
  out.land = makeWave(0.12, (t) => Math.sin(TWO_PI * 180 * t) * softEnv()[t * SR | 0] * 0.45);
  out.boss_roar = makeWave(1.4, (t) => {
    const e = softEnv()[t * SR | 0];
    const f = 90 + 30 * Math.sin(TWO_PI * 4 * t);
    return Math.sin(TWO_PI * f * t) * e * 0.6 + (Math.random() * 2 - 1) * e * 0.3;
  });
  out.boss_hit = makeWave(0.6, (t) => {
    const e = softEnv()[t * SR | 0];
    const f = 250 - 150 * (t / 0.6);
    return (Math.sin(TWO_PI * f * t) * 0.6 + (Math.random() * 2 - 1) * 0.4) * e;
  });
  out.pause = makeWave(0.12, (t) => Math.sin(TWO_PI * 440 * t) * softEnv()[t * SR | 0] * 0.4);
  out.unpause = makeWave(0.12, (t) => Math.sin(TWO_PI * 660 * t) * softEnv()[t * SR | 0] * 0.4);
  out.error = makeWave(0.25, (t) => Math.sin(TWO_PI * 180 * t) * softEnv()[t * SR | 0] * 0.5);
  out.step = makeWave(0.08, (t) => Math.sin(TWO_PI * 300 * t) * softEnv()[t * SR | 0] * 0.25);
  return out;
}

// ---------- main ----------
const OUT = path.join(__dirname, "..", "assets", "audio");
fs.mkdirSync(OUT, { recursive: true });
console.log("DEX DASH audio generation");
console.log("  out:", OUT);

// music tracks (each ~15-25s loop)
const tracks = [
  { name: "menu", bpm: 100, root: "A", minor: true, style: "chill", bars: 8 },
  { name: "tutorial", bpm: 110, root: "C", style: "calm", bars: 8 },
  { name: "easy", bpm: 122, root: "A", minor: false, style: "energetic", bars: 8 },
  { name: "normal", bpm: 130, root: "D", minor: true, style: "energetic", bars: 8 },
  { name: "hard", bpm: 142, root: "E", minor: true, style: "energetic", bars: 8 },
  { name: "harder", bpm: 150, root: "F", minor: true, style: "energetic", bars: 8 },
  { name: "insane", bpm: 160, root: "G", minor: true, style: "energetic", bars: 8 },
  { name: "extreme", bpm: 174, root: "A", minor: true, style: "energetic", bars: 8 },
  { name: "endless", bpm: 168, root: "B", minor: true, style: "energetic", bars: 8 },
  { name: "boss", bpm: 150, root: "D", minor: true, style: "energetic", bars: 8 },
];
for (const t of tracks) {
  const { samples, bpm, beats } = buildTrack(t);
  writeWav(path.join(OUT, "music_" + t.name + ".wav"), samples);
  fs.writeFileSync(path.join(OUT, "music_" + t.name + ".json"), JSON.stringify({ bpm, beats }));
}

console.log(" sfx...");
const sfx = buildSfx();
for (const [name, s] of Object.entries(sfx)) {
  const inter = new Float32Array(s.length * 2);
  for (let i = 0; i < s.length; i++) { inter[i * 2] = s[i]; inter[i * 2 + 1] = s[i]; }
  writeWav(path.join(OUT, "sfx_" + name + ".wav"), inter);
}
console.log("done.");
