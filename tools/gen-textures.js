// DEX DASH procedural texture generator.
// Creates every visual asset in the game from code - fully original art.
// Emits: assets/textures/atlas_game.png|.json, atlas_ui.png|.json, atlas_bg.png|.json
const fs = require("fs");
const path = require("path");
const { encodePNG } = require("./lib/png");

// ---------- tiny raster canvas ----------
class Canvas {
  constructor(w, h) {
    this.w = w; this.h = h;
    this.buf = new Uint8Array(w * h * 4);
  }
  set(x, y, r, g, b, a = 255) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    const i = (y * this.w + x) * 4;
    const sa = a / 255;
    const da = this.buf[i + 3] / 255;
    const oa = sa + da * (1 - sa);
    if (oa <= 0) return;
    this.buf[i] = Math.round((r * sa + this.buf[i] * da * (1 - sa)) / oa);
    this.buf[i + 1] = Math.round((g * sa + this.buf[i + 1] * da * (1 - sa)) / oa);
    this.buf[i + 2] = Math.round((b * sa + this.buf[i + 2] * da * (1 - sa)) / oa);
    this.buf[i + 3] = Math.round(oa * 255);
  }
  fillRect(x, y, w, h, r, g, b, a = 255) {
    for (let yy = Math.max(0, y | 0); yy < Math.min(this.h, y + h | 0); yy++)
      for (let xx = Math.max(0, x | 0); xx < Math.min(this.w, x + w | 0); xx++)
        this.set(xx, yy, r, g, b, a);
  }
  fillRRect(x, y, w, h, rad, r, g, b, a = 255) {
    for (let yy = y | 0; yy < (y + h) | 0; yy++) {
      for (let xx = x | 0; xx < (x + w) | 0; xx++) {
        // rounded corner test
        const cx = xx < x + rad ? x + rad : xx > x + w - rad - 1 ? x + w - rad - 1 : xx;
        const cy = yy < y + rad ? y + rad : yy > y + h - rad - 1 ? y + h - rad - 1 : yy;
        const dx = xx - cx, dy = yy - cy;
        if (dx * dx + dy * dy <= rad * rad + 1) this.set(xx, yy, r, g, b, a);
      }
    }
  }
  fillCircle(cx, cy, rad, r, g, b, a = 255) {
    const r2 = rad * rad;
    for (let yy = Math.floor(cy - rad); yy <= Math.ceil(cy + rad); yy++)
      for (let xx = Math.floor(cx - rad); xx <= Math.ceil(cx + rad); xx++) {
        const dx = xx - cx, dy = yy - cy;
        if (dx * dx + dy * dy <= r2) this.set(xx, yy, r, g, b, a);
      }
  }
  // soft radial glow
  glow(cx, cy, rad, r, g, b, intensity = 1) {
    const r2 = rad * rad;
    for (let yy = Math.floor(cy - rad); yy <= Math.ceil(cy + rad); yy++)
      for (let xx = Math.floor(cx - rad); xx <= Math.ceil(cx + rad); xx++) {
        const dx = xx - cx, dy = yy - cy;
        const d2 = dx * dx + dy * dy;
        if (d2 > r2) continue;
        const d = Math.sqrt(d2) / rad;
        const a = (1 - d) * (1 - d) * 255 * intensity;
        this.set(xx, yy, r, g, b, a);
      }
  }
  gradientRect(x, y, w, h, cTop, cBottom) {
    for (let yy = y | 0; yy < (y + h) | 0; yy++) {
      const t = (yy - y) / h;
      const r = cTop[0] + (cBottom[0] - cTop[0]) * t;
      const g = cTop[1] + (cBottom[1] - cTop[1]) * t;
      const b = cTop[2] + (cBottom[2] - cTop[2]) * t;
      for (let xx = x | 0; xx < (x + w) | 0; xx++) this.set(xx, yy, r, g, b);
    }
  }
  // filled triangle
  tri(x0, y0, x1, y1, x2, y2, r, g, b, a = 255) {
    const minX = Math.floor(Math.min(x0, x1, x2)), maxX = Math.ceil(Math.max(x0, x1, x2));
    const minY = Math.floor(Math.min(y0, y1, y2)), maxY = Math.ceil(Math.max(y0, y1, y2));
    const edge = (px, py, ax, ay, bx, by) => (bx - ax) * (py - ay) - (by - ay) * (px - ax);
    const e0 = edge(x0, y0, x1, y1, x2, y2);
    for (let yy = minY; yy <= maxY; yy++)
      for (let xx = minX; xx <= maxX; xx++) {
        const s0 = edge(xx, yy, x1, y1, x2, y2) * (e0 >= 0 ? 1 : -1);
        const s1 = edge(xx, yy, x2, y2, x0, y0) * (e0 >= 0 ? 1 : -1);
        const s2 = edge(xx, yy, x0, y0, x1, y1) * (e0 >= 0 ? 1 : -1);
        if (s0 >= 0 && s1 >= 0 && s2 >= 0) this.set(xx, yy, r, g, b, a);
      }
  }
  diamond(cx, cy, rx, ry, r, g, b, a = 255) {
    const pts = [[cx, cy - ry], [cx + rx, cy], [cx, cy + ry], [cx - rx, cy]];
    for (let i = 0; i < 4; i++) {
      const p0 = pts[i], p1 = pts[(i + 1) % 4];
      // draw line p0-p1 as thick dots
      this.line(p0[0], p0[1], p1[0], p1[1], r, g, b, a, 1);
    }
    this.fillPoly(pts, r, g, b, a);
  }
  fillPoly(pts, r, g, b, a = 255) {
    const minX = Math.floor(Math.min(...pts.map(p => p[0])));
    const maxX = Math.ceil(Math.max(...pts.map(p => p[0])));
    const minY = Math.floor(Math.min(...pts.map(p => p[1])));
    const maxY = Math.ceil(Math.max(...pts.map(p => p[1])));
    for (let yy = minY; yy <= maxY; yy++) {
      const xs = [];
      for (let i = 0; i < pts.length; i++) {
        const p0 = pts[i], p1 = pts[(i + 1) % pts.length];
        if ((p0[1] <= yy && p1[1] > yy) || (p1[1] <= yy && p0[1] > yy)) {
          xs.push(p0[0] + ((yy - p0[1]) / (p1[1] - p0[1])) * (p1[0] - p0[0]));
        }
      }
      xs.sort((a, b) => a - b);
      for (let i = 0; i + 1 < xs.length; i += 2)
        for (let xx = Math.floor(xs[i]); xx <= Math.ceil(xs[i + 1]); xx++) this.set(xx, yy, r, g, b, a);
    }
  }
  line(x0, y0, x1, y1, r, g, b, a = 255, thickness = 1) {
    const steps = Math.ceil(Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0)));
    for (let i = 0; i <= steps; i++) {
      const t = i / steps;
      const xx = Math.round(x0 + (x1 - x0) * t), yy = Math.round(y0 + (y1 - y0) * t);
      for (let dy = -thickness; dy <= thickness; dy++)
        for (let dx = -thickness; dx <= thickness; dx++)
          this.set(xx + dx, yy + dy, r, g, b, a);
    }
  }
  ring(cx, cy, rad, thick, r, g, b, a = 255) {
    for (let i = 0; i < 360; i += 1.5) {
      const t = i * Math.PI / 180;
      const x = cx + Math.cos(t) * rad, y = cy + Math.sin(t) * rad;
      this.fillCircle(x, y, thick / 2, r, g, b, a);
    }
  }
  ringGrad(cx, cy, rad, thick, cA, cB, a = 255) {
    for (let i = 0; i < 360; i += 1) {
      const t = i * Math.PI / 180;
      const x = cx + Math.cos(t) * rad, y = cy + Math.sin(t) * rad;
      const mix = (Math.sin(i * Math.PI / 180) + 1) / 2;
      this.fillCircle(x, y, thick / 2,
        cA[0] + (cB[0] - cA[0]) * mix, cA[1] + (cB[1] - cA[1]) * mix, cA[2] + (cB[2] - cA[2]) * mix, a);
    }
  }
  star(cx, cy, outer, inner, n, rot, r, g, b, a = 255) {
    const pts = [];
    for (let i = 0; i < n * 2; i++) {
      const rad = i % 2 === 0 ? outer : inner;
      const t = rot + (i * Math.PI) / n;
      pts.push([cx + Math.cos(t) * rad, cy + Math.sin(t) * rad]);
    }
    this.fillPoly(pts, r, g, b, a);
  }
  // diagonal checker strip
  checkerRect(x, y, w, h, size, c1, c2) {
    for (let yy = y | 0; yy < (y + h) | 0; yy++)
      for (let xx = x | 0; xx < (x + w) | 0; xx++) {
        const c = (Math.floor(xx / size) + Math.floor(yy / size)) % 2 === 0 ? c1 : c2;
        this.set(xx, yy, c[0], c[1], c[2]);
      }
  }
  toRGBA() { return this.buf; }
}

// ---------- atlas packer ----------
function pack(entries, cell) {
  // entries: {name, w, h, draw(cv, x, y)}
  const cols = 21; // 21 * 96 = 2016 < 2048
  let rows = 0;
  const rects = {};
  for (const e of entries) {
    const ew = Math.ceil(e.w / cell), eh = Math.ceil(e.h / cell);
    // find a free block of cells (simple greedy row scan)
    let placed = false;
    outer:
    for (let y = 0; y <= rows; y++) {
      for (let x = 0; x <= cols - ew; x++) {
        if (fit(rects, x, y, ew, eh, cell)) {
          rects[e.name] = { x: x * cell, y: y * cell, w: e.w, h: e.h };
          placed = true;
          break outer;
        }
      }
    }
    if (!placed) {
      const y = rows;
      rects[e.name] = { x: 0, y: y * cell, w: e.w, h: e.h };
      rows += eh;
      continue;
    }
    const r = rects[e.name];
    if (Math.ceil((r.y + r.h) / cell) > rows) rows = Math.ceil((r.y + r.h) / cell);
  }
  function fit(rects, cx, cy, ew, eh, cell) {
    for (const r of Object.values(rects)) {
      const rx = r.x / cell, ry = r.y / cell, rw = Math.ceil(r.w / cell), rh = Math.ceil(r.h / cell);
      if (cx < rx + rw && cx + ew > rx && cy < ry + rh && cy + eh > ry) return false;
    }
    return true;
  }
  const W = cols * cell, H = rows * cell;
  const cv = new Canvas(W, H);
  for (const e of entries) e.draw(cv, rects[e.name].x, rects[e.name].y);
  return { cv, rects, W, H };
}

function writeAtlas(fileBase, cell, entries) {
  const { cv, rects, W, H } = pack(entries, cell);
  fs.writeFileSync(fileBase + ".png", encodePNG(W, H, cv.toRGBA()));
  const json = {};
  for (const [k, v] of Object.entries(rects)) json[k] = { x: v.x, y: v.y, w: v.w, h: v.h };
  fs.writeFileSync(fileBase + ".json", JSON.stringify(json));
  console.log(`  ${path.basename(fileBase)}: ${W}x${H}, ${entries.length} textures`);
}

// ---------- palette ----------
const P = {
  cyan: [0, 229, 255], cyanD: [0, 120, 160],
  magenta: [255, 47, 214], purple: [124, 77, 255],
  orange: [255, 167, 38], orangeD: [200, 90, 0],
  lime: [105, 240, 174], red: [255, 82, 82], redD: [160, 20, 20],
  yellow: [255, 215, 64], gold: [255, 200, 40],
  white: [245, 245, 255],
  navy: [10, 12, 28], navy2: [16, 18, 44], deep: [6, 7, 18],
  glass: [140, 160, 255],
};

// ---------- texture painters ----------
function C(name, w, h, draw) { return { name, w, h, draw }; }

function blockTex(cv, x, y, border, fill, glowColor) {
  const s = 96, b = 7;
  cv.glow(x + s / 2, y + s / 2, s * 0.85, glowColor[0], glowColor[1], glowColor[2], 0.9);
  cv.fillRRect(x, y, s, s, 14, border[0], border[1], border[2]);
  cv.fillRRect(x + b, y + b, s - b * 2, s - b * 2, 8, fill[0], fill[1], fill[2]);
  cv.fillRRect(x + b + 3, y + b + 3, s - (b + 3) * 2, 3, 2, 255, 255, 255, 26);
  cv.fillRRect(x + b + 3, y + s - b - 6, s - (b + 3) * 2, 3, 2, 0, 0, 0, 40);
}

const makeBlocks = () => {
  const out = [];
  const defs = {
    block_cyan: { border: P.cyan, fill: [14, 24, 52], glow: P.cyan },
    block_magenta: { border: P.magenta, fill: [40, 12, 52], glow: P.magenta },
    block_purple: { border: P.purple, fill: [22, 16, 56], glow: P.purple },
    block_orange: { border: P.orange, fill: [46, 26, 10], glow: P.orange },
    block_lime: { border: P.lime, fill: [10, 40, 30], glow: P.lime },
    block_red: { border: P.red, fill: [44, 12, 20], glow: P.red },
    block_white: { border: [220, 225, 255], fill: [38, 42, 62], glow: [200, 210, 255] },
    block_gray: { border: [120, 130, 170], fill: [24, 26, 40], glow: [90, 100, 140] },
  };
  for (const [name, d] of Object.entries(defs)) {
    out.push(C(name, 96, 96, (cv, x, y) => {
      blockTex(cv, x, y, d.border, d.fill, d.glow);
    }));
  }
  // hazard block: warning stripes
  out.push(C("block_hazard", 96, 96, (cv, x, y) => {
    blockTex(cv, x, y, P.red, [44, 12, 20], P.red);
    for (let i = -2; i < 5; i++) {
      cv.fillRect(x + 10 + i * 18, y + 14, 9, 8, P.yellow[0], P.yellow[1], P.yellow[2], 200);
      cv.fillRect(x + 6 + i * 18, y + 74, 9, 8, P.yellow[0], P.yellow[1], P.yellow[2], 200);
    }
  }));
  return out;
};

const makeSpikes = () => {
  const out = [];
  const spike = (name, up) => C(name, 96, 96, (cv, x, y) => {
    cv.glow(x + 48, up ? y + 30 : y + 66, 52, P.red[0], P.red[1], P.red[2], 1);
    const base = up ? 64 : 32, tip = up ? 16 : 80;
    cv.fillPoly([[x + 12, y + base], [x + 84, y + base], [x + 48, y + tip]], P.redD[0], P.redD[1], P.redD[2]);
    cv.fillPoly([[x + 20, y + base - 6], [x + 76, y + base - 6], [x + 48, y + tip + 6]], P.red[0], P.red[1], P.red[2]);
    cv.fillPoly([[x + 30, y + base - 8], [x + 60, y + base - 8], [x + 48, y + tip + 12]], [255, 150, 150][0], [255, 150, 150][1], [255, 150, 150][2]);
    cv.line(x + 48, y + tip + 4, x + 48, y + (up ? base - 12 : base + 12), 255, 230, 230, 120, 1);
  });
  out.push(spike("spike_up", true));
  out.push(spike("spike_down", false));
  const spikeSide = (name, dir) => C(name, 96, 96, (cv, x, y) => {
    cv.glow(x + 48, y + 48, 52, P.red[0], P.red[1], P.red[2], 1);
    const d = dir === 1 ? 1 : -1;
    const tipX = x + 48 + d * 36, baseX = x + 48 - d * 36;
    cv.fillPoly([[baseX, y + 14], [baseX, y + 82], [tipX, y + 48]], P.redD[0], P.redD[1], P.redD[2]);
    cv.fillPoly([[baseX + d * 6, y + 22], [baseX + d * 6, y + 74], [tipX - d * 6, y + 48]], P.red[0], P.red[1], P.red[2]);
  });
  out.push(spikeSide("spike_right", 1));
  out.push(spikeSide("spike_left", -1));
  return out;
};

const makeCoins = () => {
  return [
    C("coin", 96, 96, (cv, x, y) => {
      cv.glow(x + 48, y + 48, 44, P.yellow[0], P.yellow[1], P.yellow[2], 1);
      cv.fillCircle(x + 48, y + 48, 26, P.gold[0], P.gold[1], P.gold[2]);
      cv.fillCircle(x + 48, y + 48, 20, [255, 235, 120][0], [255, 235, 120][1], [255, 235, 120][2]);
      cv.fillCircle(x + 48, y + 48, 12, [70, 50, 10], [50, 36, 8], [30, 20, 4]);
      cv.fillRRect(x + 38, y + 40, 8, 16, 4, 255, 255, 255, 160);
      // star emblem
      cv.star(x + 48, y + 48, 10, 4.5, 5, -Math.PI / 2, P.gold[0], P.gold[1], P.gold[2]);
    }),
    C("coin_secret", 96, 96, (cv, x, y) => {
      cv.glow(x + 48, y + 48, 44, P.cyan[0], P.cyan[1], P.cyan[2], 1);
      cv.fillCircle(x + 48, y + 48, 26, P.cyan[0], P.cyan[1], P.cyan[2]);
      cv.fillCircle(x + 48, y + 48, 20, [190, 250, 255][0], [190, 250, 255][1], [190, 250, 255][2]);
      cv.fillCircle(x + 48, y + 48, 12, [0, 60, 80], [0, 60, 80], [0, 60, 80]);
      cv.star(x + 48, y + 48, 10, 4.5, 5, -Math.PI / 2, P.cyan[0], P.cyan[1], P.cyan[2]);
    }),
  ];
};

const makePads = () => {
  return [
    C("pad", 96, 96, (cv, x, y) => {
      cv.glow(x + 48, y + 48, 44, P.orange[0], P.orange[1], P.orange[2], 1);
      cv.fillRRect(x + 8, y + 34, 80, 50, 8, P.orangeD[0], P.orangeD[1], P.orangeD[2]);
      cv.fillRRect(x + 8, y + 34, 80, 50, 8, P.orange[0], P.orange[1], P.orange[2], 0);
      cv.fillRRect(x + 12, y + 38, 72, 42, 6, [255, 200, 120][0], [255, 200, 120][1], [255, 200, 120][2]);
      for (let i = 0; i < 3; i++) {
        const yy = y + 62 - i * 12;
        cv.fillPoly([[x + 48 - 12 + i * 3, yy], [x + 48 + 12 - i * 3, yy], [x + 48, yy - 10]], P.orange[0], P.orange[1], P.orange[2]);
      }
    }),
  ];
};

const makePortals = () => {
  const out = [];
  const portalBase = (name, color, c2, glyph) => C(name, 96, 192, (cv, x, y) => {
    const cx = x + 48, cy = y + 96;
    cv.glow(cx, cy, 86, color[0], color[1], color[2], 0.75);
    // outer frame
    cv.fillRRect(x + 26, y + 8, 44, 176, 20, color[0], color[1], color[2], 70);
    cv.fillRRect(x + 30, y + 12, 36, 168, 16, color[0] * 0.35, color[1] * 0.35, color[2] * 0.35);
    // inner swirl rings
    for (let i = 0; i < 3; i++) {
      cv.ringGrad(cx, cy, 30 + i * 10, 3, color, c2 || color, 200 - i * 50);
    }
    // energy core
    cv.glow(cx, cy, 30, color[0], color[1], color[2], 1.2);
    cv.fillCircle(cx, cy, 14, [255, 255, 255], [255, 255, 255], [255, 255, 255], 230);
    cv.fillCircle(cx, cy, 8, color[0], color[1], color[2]);
    // top/bottom caps
    cv.fillCircle(cx, y + 14, 8, color[0], color[1], color[2]);
    cv.fillCircle(cx, y + 178, 8, color[0], color[1], color[2]);
    if (glyph) glyph(cv, cx, cy, color);
  });
  out.push(portalBase("portal_grav_up", P.magenta, null, (cv, cx, cy, c) => {
    cv.fillPoly([[cx, cy - 16], [cx - 12, cy - 2], [cx + 12, cy - 2]], 255, 255, 255, 220);
    cv.fillPoly([[cx, cy - 6], [cx - 9, cy + 6], [cx + 9, cy + 6]], c[0], c[1], c[2], 200);
  }));
  out.push(portalBase("portal_grav_down", P.magenta, null, (cv, cx, cy, c) => {
    cv.fillPoly([[cx, cy + 16], [cx - 12, cy + 2], [cx + 12, cy + 2]], 255, 255, 255, 220);
    cv.fillPoly([[cx, cy + 6], [cx - 9, cy - 6], [cx + 9, cy - 6]], c[0], c[1], c[2], 200);
  }));
  out.push(portalBase("portal_speed", P.orange, null, (cv, cx, cy, c) => {
    for (let i = 0; i < 3; i++) {
      cv.fillPoly([[cx - 16 + i * 14, cy + 14 - i * 2], [cx - 8 + i * 14, cy + 14 - i * 2], [cx + 14 - i * 4, cy - 14 + i * 2]], 255, 255, 255, 220);
    }
  }));
  out.push(portalBase("portal_size", P.purple, null, (cv, cx, cy, c) => {
    cv.fillPoly([[cx - 20, cy - 14], [cx - 20, cy + 14], [cx - 6, cy + 14], [cx - 6, cy - 14]], 255, 255, 255, 220);
    cv.fillPoly([[cx + 6, cy - 14], [cx + 6, cy + 14], [cx + 20, cy + 14], [cx + 20, cy - 14]], 255, 255, 255, 220);
  }));
  out.push(portalBase("portal_dash", P.cyan, null, (cv, cx, cy, c) => {
    cv.fillPoly([[cx - 18, cy - 10], [cx - 18, cy + 10], [cx + 2, cy + 10], [cx + 2, cy - 10]], 255, 255, 255, 230);
    cv.fillPoly([[cx + 6, cy - 10], [cx + 6, cy + 10], [cx + 26, cy + 10], [cx + 26, cy - 10]], 255, 255, 255, 120);
    cv.fillPoly([[cx + 10, cy], [cx + 26, cy - 5], [cx + 26, cy + 5]], c[0], c[1], c[2], 230);
  }));
  out.push(portalBase("portal_teleport", P.red, null, (cv, cx, cy, c) => {
    cv.ringGrad(cx, cy, 34, 4, P.red, P.magenta, 230);
    cv.ringGrad(cx, cy, 20, 3, P.yellow, P.red, 220);
    cv.fillCircle(cx, cy, 7, 255, 255, 255, 240);
  }));
  out.push(portalBase("portal_rotate_cw", P.lime, null, (cv, cx, cy, c) => {
    cv.ring(cx, cy, 26, 4, P.lime[0], P.lime[1], P.lime[2], 220);
    cv.fillPoly([[cx + 26, cy], [cx + 16, cy - 8], [cx + 16, cy + 8]], 255, 255, 255, 230);
    cv.line(cx, cy, cx + 26, cy, 255, 255, 255, 160, 1);
  }));
  out.push(portalBase("portal_rotate_ccw", P.lime, null, (cv, cx, cy, c) => {
    cv.ring(cx, cy, 26, 4, P.lime[0], P.lime[1], P.lime[2], 220);
    cv.fillPoly([[cx - 26, cy], [cx - 16, cy - 8], [cx - 16, cy + 8]], 255, 255, 255, 230);
    cv.line(cx, cy, cx - 26, cy, 255, 255, 255, 160, 1);
  }));
  return out;
};

const makePlayer = () => {
  return [
    C("player_idle", 96, 96, (cv, x, y) => {
      cv.glow(x + 48, y + 48, 50, P.cyan[0], P.cyan[1], P.cyan[2], 1.1);
      cv.fillRRect(x + 14, y + 14, 68, 68, 12, P.cyan[0], P.cyan[1], P.cyan[2]);
      cv.fillRRect(x + 14, y + 14, 68, 68, 12, 0, 0, 0, 0);
      cv.fillRRect(x + 19, y + 19, 58, 58, 9, [255, 255, 255], [255, 255, 255], [255, 255, 255], 235);
      cv.fillRRect(x + 24, y + 24, 48, 48, 7, [20, 30, 60], [20, 30, 60], [20, 30, 60]);
      cv.fillRRect(x + 26, y + 26, 44, 44, 6, P.cyanD[0], P.cyanD[1], P.cyanD[2], 90);
      // eyes
      cv.fillRRect(x + 32, y + 40, 10, 16, 4, 255, 255, 255, 230);
      cv.fillRRect(x + 54, y + 40, 10, 16, 4, 255, 255, 255, 230);
      cv.fillCircle(x + 39, y + 48, 4, 12, 14, 30);
      cv.fillCircle(x + 61, y + 48, 4, 12, 14, 30);
    }),
    C("player_small", 96, 96, (cv, x, y) => {
      cv.glow(x + 48, y + 48, 38, P.lime[0], P.lime[1], P.lime[2], 1);
      cv.fillRRect(x + 28, y + 28, 40, 40, 8, P.lime[0], P.lime[1], P.lime[2]);
      cv.fillRRect(x + 32, y + 32, 32, 32, 6, [240, 255, 250], [240, 255, 250], [240, 255, 250]);
      cv.fillRRect(x + 35, y + 35, 26, 26, 5, [14, 40, 30], [14, 40, 30], [14, 40, 30]);
      cv.fillRRect(x + 38, y + 42, 6, 10, 3, 255, 255, 255);
      cv.fillRRect(x + 52, y + 42, 6, 10, 3, 255, 255, 255);
    }),
    C("player_ghost", 96, 96, (cv, x, y) => {
      cv.fillRRect(x + 14, y + 14, 68, 68, 12, P.purple[0], P.purple[1], P.purple[2], 90);
      cv.fillRRect(x + 24, y + 24, 48, 48, 9, [200, 170, 255], [200, 170, 255], [200, 170, 255], 60);
    }),
  ];
};

const makeParticles = () => {
  return [
    C("part_soft", 64, 64, (cv, x, y) => {
      cv.glow(x + 32, y + 32, 32, 255, 255, 255, 1);
    }),
    C("part_spark", 32, 32, (cv, x, y) => {
      cv.fillPoly([[x + 16, y + 2], [x + 30, y + 16], [x + 16, y + 30], [x + 2, y + 16]], 255, 255, 255);
      cv.fillPoly([[x + 16, y + 7], [x + 25, y + 16], [x + 16, y + 25], [x + 7, y + 16]], 220, 230, 255, 200);
    }),
    C("part_ring", 128, 128, (cv, x, y) => {
      cv.ring(x + 64, y + 64, 52, 6, 255, 255, 255, 220);
      cv.ring(x + 64, y + 64, 40, 4, 255, 255, 255, 120);
    }),
    C("part_shard", 48, 48, (cv, x, y) => {
      cv.fillPoly([[x + 24, y + 4], [x + 42, y + 24], [x + 24, y + 44], [x + 6, y + 24]], 255, 255, 255, 220);
    }),
    C("part_diamond", 32, 32, (cv, x, y) => {
      cv.fillPoly([[x + 16, y], [x + 32, y + 16], [x + 16, y + 32], [x, y + 16]], 255, 255, 255, 230);
    }),
    C("part_heart", 48, 48, (cv, x, y) => {
      cv.fillCircle(x + 16, y + 18, 10, P.red[0], P.red[1], P.red[2]);
      cv.fillCircle(x + 32, y + 18, 10, P.red[0], P.red[1], P.red[2]);
      cv.fillPoly([[x + 8, y + 22], [x + 40, y + 22], [x + 24, y + 44]], P.red[0], P.red[1], P.red[2]);
    }),
  ];
};

const makeDecor = () => {
  return [
    C("deco_star", 96, 96, (cv, x, y) => {
      cv.glow(x + 48, y + 48, 42, P.yellow[0], P.yellow[1], P.yellow[2], 0.8);
      cv.star(x + 48, y + 48, 26, 11, 5, -Math.PI / 2, P.yellow[0], P.yellow[1], P.yellow[2]);
      cv.star(x + 48, y + 48, 14, 6, 5, -Math.PI / 2, [255, 245, 190][0], [255, 245, 190][1], [255, 245, 190][2]);
    }),
    C("deco_crystal", 96, 96, (cv, x, y) => {
      cv.glow(x + 48, y + 52, 40, P.purple[0], P.purple[1], P.purple[2], 0.9);
      cv.fillPoly([[x + 48, y + 12], [x + 66, y + 44], [x + 56, y + 78], [x + 40, y + 78], [x + 30, y + 44]], P.purple[0], P.purple[1], P.purple[2]);
      cv.fillPoly([[x + 48, y + 18], [x + 60, y + 44], [x + 48, y + 72]], [190, 150, 255], [190, 150, 255], [190, 150, 255], 220);
      cv.fillPoly([[x + 34, y + 30], [x + 24, y + 52], [x + 34, y + 70], [x + 40, y + 50]], [230, 215, 255], [230, 215, 255], [230, 215, 255], 180);
    }),
    C("deco_orb", 96, 96, (cv, x, y) => {
      cv.glow(x + 48, y + 48, 40, P.magenta[0], P.magenta[1], P.magenta[2], 0.9);
      cv.fillCircle(x + 48, y + 48, 22, P.magenta[0], P.magenta[1], P.magenta[2]);
      cv.fillCircle(x + 48, y + 48, 16, [255, 190, 240][0], [255, 190, 240][1], [255, 190, 240][2]);
      cv.fillCircle(x + 44, y + 42, 6, 255, 255, 255, 190);
    }),
    C("deco_gear", 96, 96, (cv, x, y) => {
      cv.glow(x + 48, y + 48, 40, P.cyan[0], P.cyan[1], P.cyan[2], 0.7);
      cv.fillCircle(x + 48, y + 48, 26, P.cyanD[0], P.cyanD[1], P.cyanD[2]);
      for (let i = 0; i < 8; i++) {
        const t = (i / 8) * Math.PI * 2;
        cv.fillRRect(x + 48 + Math.cos(t) * 22 - 7, y + 48 + Math.sin(t) * 22 - 7, 14, 14, 3, P.cyan[0], P.cyan[1], P.cyan[2]);
      }
      cv.fillCircle(x + 48, y + 48, 16, [230, 250, 255], [230, 250, 255], [230, 250, 255]);
      cv.fillCircle(x + 48, y + 48, 7, P.cyanD[0], P.cyanD[1], P.cyanD[2]);
    }),
  ];
};

const makeFinish = () => {
  return [
    C("finish", 96, 192, (cv, x, y) => {
      const cx = x + 48;
      cv.fillRRect(x + 38, y + 10, 20, 130, 6, [60, 66, 96], [60, 66, 96], [60, 66, 96]);
      cv.fillRRect(x + 38, y + 10, 20, 130, 6, [255, 255, 255], [255, 255, 255], [255, 255, 255], 90);
      cv.checkerRect(x + 20, y + 140, 56, 44, 9, [245, 245, 255], [60, 66, 96]);
      cv.fillPoly([[cx - 6, y + 44], [cx + 46, y + 32], [cx - 6, y + 20]], P.cyan[0], P.cyan[1], P.cyan[2]);
      cv.fillPoly([[cx - 2, y + 40], [cx + 40, y + 32], [cx - 2, y + 24]], [190, 250, 255], [190, 250, 255], [190, 250, 255], 220);
      cv.glow(x + 48, y + 32, 40, P.cyan[0], P.cyan[1], P.cyan[2], 0.9);
    }),
  ];
};

const makeUi = () => {
  const out = [];
  // round button (9-patch-ish; game scales corners)
  out.push(C("btn", 96, 96, (cv, x, y) => {
    cv.fillRRect(x, y, 96, 96, 24, P.glass[0], P.glass[1], P.glass[2], 40);
    cv.fillRRect(x, y, 96, 96, 24, P.cyan[0], P.cyan[1], P.cyan[2], 0);
    cv.fillRRect(x + 2, y + 2, 92, 92, 22, P.cyan[0], P.cyan[1], P.cyan[2], 0);
    cv.fillRRect(x + 3, y + 3, 90, 90, 21, [24, 34, 64], [24, 34, 64], [24, 34, 64], 60);
    cv.fillRRect(x + 8, y + 8, 80, 6, 3, 255, 255, 255, 36);
  }));
  out.push(C("btn_hl", 96, 96, (cv, x, y) => {
    cv.fillRRect(x, y, 96, 96, 24, P.glass[0], P.glass[1], P.glass[2], 60);
    cv.fillRRect(x, y, 96, 96, 24, P.cyan[0], P.cyan[1], P.cyan[2], 0);
    cv.fillRRect(x + 2, y + 2, 92, 92, 22, P.cyan[0], P.cyan[1], P.cyan[2], 0);
    cv.fillRRect(x + 3, y + 3, 90, 90, 21, [24, 44, 80], [24, 44, 80], [24, 44, 80], 120);
    cv.glow(x + 48, y + 48, 52, P.cyan[0], P.cyan[1], P.cyan[2], 0.5);
    cv.fillRRect(x + 8, y + 8, 80, 6, 3, 255, 255, 255, 60);
  }));
  out.push(C("btn_primary", 96, 96, (cv, x, y) => {
    cv.fillRRect(x, y, 96, 96, 24, P.cyan[0], P.cyan[1], P.cyan[2], 0);
    cv.fillRRect(x + 2, y + 2, 92, 92, 22, P.cyan[0], P.cyan[1], P.cyan[2], 0);
    cv.fillRRect(x + 3, y + 3, 90, 90, 21, [0, 60, 90], [0, 60, 90], [0, 60, 90], 200);
    cv.glow(x + 48, y + 48, 54, P.cyan[0], P.cyan[1], P.cyan[2], 0.7);
    cv.fillRRect(x + 8, y + 8, 80, 6, 3, 255, 255, 255, 50);
  }));
  out.push(C("panel", 96, 96, (cv, x, y) => {
    cv.fillRRect(x, y, 96, 96, 22, [20, 26, 52], [20, 26, 52], [20, 26, 52], 230);
    cv.fillRRect(x, y, 96, 96, 22, P.glass[0], P.glass[1], P.glass[2], 36);
    cv.fillRRect(x + 1, y + 1, 94, 94, 21, P.glass[0], P.glass[1], P.glass[2], 18);
    cv.fillRRect(x + 8, y + 8, 80, 5, 2, 255, 255, 255, 24);
  }));
  out.push(C("check", 96, 96, (cv, x, y) => {
    cv.fillRRect(x + 18, y + 18, 60, 60, 14, [14, 18, 38], [14, 18, 38], [14, 18, 38]);
    cv.fillRRect(x + 18, y + 18, 60, 60, 14, P.glass[0], P.glass[1], P.glass[2], 40);
  }));
  out.push(C("check_on", 96, 96, (cv, x, y) => {
    cv.fillRRect(x + 18, y + 18, 60, 60, 14, P.cyanD[0], P.cyanD[1], P.cyanD[2]);
    cv.fillRRect(x + 18, y + 18, 60, 60, 14, P.cyan[0], P.cyan[1], P.cyan[2], 0);
    cv.fillRRect(x + 20, y + 20, 56, 56, 12, [0, 90, 130], [0, 90, 130], [0, 90, 130]);
    cv.fillPoly([[x + 30, y + 48], [x + 44, y + 62], [x + 68, y + 34]], 255, 255, 255, 0);
    cv.line(x + 30, y + 48, x + 44, y + 62, 200, 255, 255, 255, 7);
    cv.line(x + 44, y + 62, x + 68, y + 34, 200, 255, 255, 255, 7);
  }));
  out.push(C("knob", 96, 96, (cv, x, y) => {
    cv.glow(x + 48, y + 48, 40, P.cyan[0], P.cyan[1], P.cyan[2], 0.8);
    cv.fillCircle(x + 48, y + 48, 30, P.cyan[0], P.cyan[1], P.cyan[2]);
    cv.fillCircle(x + 48, y + 48, 22, [235, 252, 255], [235, 252, 255], [235, 252, 255]);
    cv.fillCircle(x + 48, y + 48, 10, P.cyanD[0], P.cyanD[1], P.cyanD[2]);
  }));
  out.push(C("icon_star", 96, 96, (cv, x, y) => {
    cv.glow(x + 48, y + 48, 36, P.yellow[0], P.yellow[1], P.yellow[2], 0.7);
    cv.star(x + 48, y + 48, 26, 11, 5, -Math.PI / 2, P.yellow[0], P.yellow[1], P.yellow[2]);
    cv.star(x + 48, y + 48, 14, 6, 5, -Math.PI / 2, [255, 248, 210], [255, 248, 210], [255, 248, 210]);
  }));
  out.push(C("icon_lock", 96, 96, (cv, x, y) => {
    cv.fillRRect(x + 22, y + 40, 52, 40, 8, [120, 130, 170], [120, 130, 170], [120, 130, 170]);
    cv.fillRRect(x + 26, y + 44, 44, 32, 6, [60, 66, 96], [60, 66, 96], [60, 66, 96]);
    cv.fillRRect(x + 30, y + 20, 36, 26, 10, [120, 130, 170], [120, 130, 170], [120, 130, 170]);
    cv.fillCircle(x + 48, y + 56, 5, 200, 205, 240, 180);
  }));
  out.push(C("icon_trophy", 96, 96, (cv, x, y) => {
    cv.fillPoly([[x + 20, y + 18], [x + 76, y + 18], [x + 72, y + 52], [x + 60, y + 60], [x + 58, y + 76], [x + 38, y + 76], [x + 36, y + 60], [x + 24, y + 52]], P.gold[0], P.gold[1], P.gold[2]);
    cv.fillPoly([[x + 26, y + 24], [x + 70, y + 24], [x + 66, y + 44], [x + 30, y + 44]], [255, 235, 140], [255, 235, 140], [255, 235, 140]);
    cv.fillRRect(x + 36, y + 76, 24, 10, 4, P.gold[0], P.gold[1], P.gold[2]);
    cv.fillRRect(x + 30, y + 86, 36, 8, 4, P.gold[0], P.gold[1], P.gold[2]);
  }));
  out.push(C("icon_crown", 96, 96, (cv, x, y) => {
    cv.glow(x + 48, y + 48, 36, P.gold[0], P.gold[1], P.gold[2], 0.6);
    cv.fillPoly([[x + 18, y + 62], [x + 14, y + 30], [x + 34, y + 46], [x + 48, y + 24], [x + 62, y + 46], [x + 82, y + 30], [x + 78, y + 62]], P.gold[0], P.gold[1], P.gold[2]);
    cv.fillRRect(x + 18, y + 62, 60, 12, 4, P.gold[0], P.gold[1], P.gold[2]);
  }));
  out.push(C("icon_key", 96, 96, (cv, x, y) => {
    cv.glow(x + 48, y + 48, 34, P.yellow[0], P.yellow[1], P.yellow[2], 0.6);
    cv.fillCircle(x + 34, y + 62, 20, P.gold[0], P.gold[1], P.gold[2]);
    cv.fillCircle(x + 34, y + 62, 10, [40, 30, 8], [40, 30, 8], [40, 30, 8]);
    cv.fillRRect(x + 48, y + 32, 26, 18, 4, P.gold[0], P.gold[1], P.gold[2]);
    cv.fillRRect(x + 66, y + 30, 8, 52, 3, P.gold[0], P.gold[1], P.gold[2]);
    cv.fillRRect(x + 66, y + 74, 8, 8, 2, P.gold[0], P.gold[1], P.gold[2]);
  }));
  out.push(C("icon_gear", 96, 96, (cv, x, y) => {
    cv.glow(x + 48, y + 48, 36, P.glass[0], P.glass[1], P.glass[2], 0.5);
    cv.fillCircle(x + 48, y + 48, 24, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    for (let i = 0; i < 8; i++) {
      const t = (i / 8) * Math.PI * 2;
      cv.fillRRect(x + 48 + Math.cos(t) * 20 - 6, y + 48 + Math.sin(t) * 20 - 6, 12, 12, 3, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    }
    cv.fillCircle(x + 48, y + 48, 12, [70, 78, 110], [70, 78, 110], [70, 78, 110]);
    cv.fillCircle(x + 48, y + 48, 5, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
  }));
  out.push(C("icon_play", 96, 96, (cv, x, y) => {
    cv.glow(x + 48, y + 48, 42, P.lime[0], P.lime[1], P.lime[2], 0.8);
    cv.fillPoly([[x + 30, y + 16], [x + 30, y + 80], [x + 82, y + 48]], P.lime[0], P.lime[1], P.lime[2]);
    cv.fillPoly([[x + 38, y + 26], [x + 38, y + 70], [x + 74, y + 48]], [230, 255, 245], [230, 255, 245], [230, 255, 245]);
  }));
  out.push(C("icon_pause", 96, 96, (cv, x, y) => {
    cv.fillRRect(x + 26, y + 18, 14, 60, 5, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    cv.fillRRect(x + 56, y + 18, 14, 60, 5, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
  }));
  out.push(C("icon_home", 96, 96, (cv, x, y) => {
    cv.fillPoly([[x + 16, y + 46], [x + 48, y + 16], [x + 80, y + 46]], [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    cv.fillRRect(x + 28, y + 42, 40, 38, 4, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    cv.fillRRect(x + 42, y + 50, 12, 30, 3, [70, 78, 110], [70, 78, 110], [70, 78, 110]);
  }));
  out.push(C("icon_undo", 96, 96, (cv, x, y) => {
    cv.ring(x + 50, y + 52, 26, 6, [150, 160, 210], [150, 160, 210], [150, 160, 210], 240);
    cv.fillPoly([[x + 16, y + 52], [x + 34, y + 38], [x + 34, y + 66]], [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    cv.line(x + 50, y + 52, x + 50, y + 52, 0, 0, 0, 0, 0);
  }));
  out.push(C("icon_redo", 96, 96, (cv, x, y) => {
    cv.ring(x + 46, y + 52, 26, 6, [150, 160, 210], [150, 160, 210], [150, 160, 210], 240);
    cv.fillPoly([[x + 80, y + 52], [x + 62, y + 38], [x + 62, y + 66]], [150, 160, 210], [150, 160, 210], [150, 160, 210]);
  }));
  out.push(C("icon_plus", 96, 96, (cv, x, y) => {
    cv.fillRRect(x + 40, y + 18, 16, 60, 5, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    cv.fillRRect(x + 18, y + 40, 60, 16, 5, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
  }));
  out.push(C("icon_trash", 96, 96, (cv, x, y) => {
    cv.fillRRect(x + 26, y + 26, 44, 52, 4, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    cv.fillRRect(x + 18, y + 20, 60, 10, 3, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    cv.fillCircle(x + 48, y + 14, 8, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    cv.fillRRect(x + 34, y + 34, 8, 36, 3, [70, 78, 110], [70, 78, 110], [70, 78, 110]);
    cv.fillRRect(x + 54, y + 34, 8, 36, 3, [70, 78, 110], [70, 78, 110], [70, 78, 110]);
  }));
  out.push(C("icon_ghost", 96, 96, (cv, x, y) => {
    cv.fillCircle(x + 48, y + 42, 26, [170, 140, 255], [170, 140, 255], [170, 140, 255]);
    cv.fillRRect(x + 22, y + 40, 52, 36, 8, [170, 140, 255], [170, 140, 255], [170, 140, 255]);
    cv.fillCircle(x + 40, y + 42, 5, 40, 30, 80);
    cv.fillCircle(x + 56, y + 42, 5, 40, 30, 80);
  }));
  out.push(C("icon_flag", 96, 96, (cv, x, y) => {
    cv.fillRRect(x + 20, y + 14, 10, 68, 3, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    cv.fillPoly([[x + 28, y + 16], [x + 74, y + 30], [x + 28, y + 46]], P.magenta[0], P.magenta[1], P.magenta[2]);
  }));
  out.push(C("icon_bomb", 96, 96, (cv, x, y) => {
    cv.fillCircle(x + 44, y + 54, 24, [40, 44, 70], [40, 44, 70], [40, 44, 70]);
    cv.fillRRect(x + 40, y + 24, 8, 16, 3, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    cv.fillCircle(x + 36, y + 34, 7, [150, 160, 210], [150, 160, 210], [150, 160, 210]);
    cv.fillCircle(x + 38, y + 54, 3, [255, 235, 140], [255, 235, 140], [255, 235, 140]);
  }));
  out.push(C("logo_dash", 96, 96, (cv, x, y) => {
    cv.fillPoly([[x + 14, y + 48], [x + 36, y + 26], [x + 36, y + 70]], P.cyan[0], P.cyan[1], P.cyan[2]);
    cv.fillPoly([[x + 38, y + 48], [x + 60, y + 26], [x + 60, y + 70]], P.magenta[0], P.magenta[1], P.magenta[2]);
    cv.fillPoly([[x + 62, y + 48], [x + 84, y + 26], [x + 84, y + 70]], P.purple[0], P.purple[1], P.purple[2]);
  }));
  return out;
};

const makeBg = () => {
  const out = [];
  out.push(C("bg_moon", 192, 192, (cv, x, y) => {
    cv.glow(x + 96, y + 96, 80, [160, 170, 255], [160, 170, 255], [160, 170, 255], 0.35);
    cv.fillCircle(x + 96, y + 96, 56, [235, 238, 255], [235, 238, 255], [235, 238, 255]);
    cv.fillCircle(x + 78, y + 74, 10, [205, 210, 240], [205, 210, 240], [205, 210, 240]);
    cv.fillCircle(x + 120, y + 110, 14, [205, 210, 240], [205, 210, 240], [205, 210, 240]);
    cv.fillCircle(x + 100, y + 130, 8, [205, 210, 240], [205, 210, 240], [205, 210, 240]);
  }));
  out.push(C("bg_mountain_far", 256, 128, (cv, x, y) => {
    cv.fillPoly([[x, y + 128], [x + 60, y + 40], [x + 120, y + 128]], [38, 34, 84], [38, 34, 84], [38, 34, 84]);
    cv.fillPoly([[x + 90, y + 128], [x + 160, y + 20], [x + 230, y + 128]], [50, 46, 104], [50, 46, 104], [50, 46, 104]);
    cv.fillPoly([[x + 190, y + 128], [x + 250, y + 60], [x + 256, y + 128]], [38, 34, 84], [38, 34, 84], [38, 34, 84]);
    cv.fillPoly([[x + 150, y + 32], [x + 160, y + 20], [x + 170, y + 36]], [180, 220, 255], [180, 220, 255], [180, 220, 255], 160);
  }));
  out.push(C("bg_mountain_near", 256, 128, (cv, x, y) => {
    cv.fillPoly([[x, y + 128], [x + 80, y + 64], [x + 160, y + 128]], [20, 22, 48], [20, 22, 48], [20, 22, 48]);
    cv.fillPoly([[x + 120, y + 128], [x + 200, y + 44], [x + 256, y + 128]], [28, 30, 60], [28, 30, 60], [28, 30, 60]);
    cv.fillPoly([[x + 192, y + 54], [x + 200, y + 44], [x + 208, y + 56]], [120, 220, 255], [120, 220, 255], [120, 220, 255], 140);
  }));
  out.push(C("bg_cloud", 192, 96, (cv, x, y) => {
    const c = [90, 100, 160];
    cv.fillCircle(x + 56, y + 60, 24, c[0], c[1], c[2], 110);
    cv.fillCircle(x + 96, y + 48, 32, c[0], c[1], c[2], 110);
    cv.fillCircle(x + 136, y + 60, 24, c[0], c[1], c[2], 110);
    cv.fillRRect(x + 40, y + 60, 116, 26, 13, c[0], c[1], c[2], 110);
  }));
  out.push(C("bg_pillar", 96, 192, (cv, x, y) => {
    cv.fillRRect(x + 12, y + 16, 72, 160, 8, [26, 30, 60], [26, 30, 60], [26, 30, 60]);
    cv.fillRRect(x + 6, y + 4, 84, 20, 6, [40, 46, 90], [40, 46, 90], [40, 46, 90]);
    cv.fillRRect(x + 16, y + 22, 64, 8, 3, [120, 140, 220], [120, 140, 220], [120, 140, 220], 80);
    cv.fillRRect(x + 12, y + 150, 72, 26, 8, [40, 46, 90], [40, 46, 90], [40, 46, 90]);
  }));
  out.push(C("bg_planet", 192, 192, (cv, x, y) => {
    cv.glow(x + 96, y + 96, 84, P.magenta[0], P.magenta[1], P.magenta[2], 0.3);
    cv.fillCircle(x + 96, y + 96, 48, [90, 40, 120], [90, 40, 120], [90, 40, 120]);
    cv.fillCircle(x + 86, y + 84, 20, [140, 80, 180], [140, 80, 180], [140, 80, 180], 120);
    cv.fillCircle(x + 112, y + 104, 14, [60, 26, 90], [60, 26, 90], [60, 26, 90]);
    // ring
    cv.ring(x + 96, y + 96, 66, 6, [190, 120, 255], [190, 120, 255], [190, 120, 255], 90);
    cv.ring(x + 96, y + 96, 74, 3, [190, 120, 255], [190, 120, 255], [190, 120, 255], 60);
  }));
  return out;
};

// ---------- boss sprites ----------
const makeBoss = () => {
  const out = [];
  out.push(C("boss_core", 192, 192, (cv, x, y) => {
    const cx = x + 96, cy = y + 96;
    cv.glow(cx, cy, 90, P.red[0], P.red[1], P.red[2], 0.8);
    cv.fillCircle(cx, cy, 62, [60, 24, 40], [60, 24, 40], [60, 24, 40]);
    cv.fillCircle(cx, cy, 62, P.red[0], P.red[1], P.red[2], 0);
    cv.fillCircle(cx, cy, 58, [30, 10, 20], [30, 10, 20], [30, 10, 20]);
    for (let i = 0; i < 8; i++) {
      const t = (i / 8) * Math.PI * 2;
      cv.fillCircle(cx + Math.cos(t) * 52, cy + Math.sin(t) * 52, 10, [70, 30, 50], [70, 30, 50], [70, 30, 50]);
      cv.fillCircle(cx + Math.cos(t) * 52, cy + Math.sin(t) * 52, 6, P.red[0], P.red[1], P.red[2]);
    }
    cv.fillCircle(cx, cy, 30, [20, 8, 14], [20, 8, 14], [20, 8, 14]);
    cv.fillCircle(cx - 10, cy - 8, 12, [255, 90, 90], [255, 90, 90], [255, 90, 90]);
    cv.fillCircle(cx + 10, cy - 8, 12, [255, 90, 90], [255, 90, 90], [255, 90, 90]);
    cv.fillCircle(cx - 10, cy - 8, 5, 255, 255, 255);
    cv.fillCircle(cx + 10, cy - 8, 5, 255, 255, 255);
    cv.fillPoly([[cx - 18, cy + 14], [cx + 18, cy + 14], [cx, cy + 30]], [255, 90, 90], [255, 90, 90], [255, 90, 90]);
  }));
  out.push(C("boss_eye", 192, 192, (cv, x, y) => {
    const cx = x + 96, cy = y + 96;
    cv.glow(cx, cy, 80, P.yellow[0], P.yellow[1], P.yellow[2], 0.5);
    cv.fillCircle(cx, cy, 56, [46, 40, 14], [46, 40, 14], [46, 40, 14]);
    cv.fillCircle(cx, cy, 52, [60, 52, 16], [60, 52, 16], [60, 52, 16]);
    cv.fillCircle(cx, cy, 26, [255, 220, 90], [255, 220, 90], [255, 220, 90]);
    cv.fillCircle(cx, cy, 14, [20, 12, 4], [20, 12, 4], [20, 12, 4]);
    cv.fillCircle(cx, cy, 6, [255, 250, 220], [255, 250, 220], [255, 250, 220]);
    cv.line(cx - 52, cy - 52, cx - 8, cy - 20, 46, 40, 14, 255, 10);
    cv.line(cx + 52, cy - 52, cx + 8, cy - 20, 46, 40, 14, 255, 10);
    cv.line(cx - 52, cy + 52, cx - 8, cy + 20, 46, 40, 14, 255, 10);
    cv.line(cx + 52, cy + 52, cx + 8, cy + 20, 46, 40, 14, 255, 10);
  }));
  return out;
};

// ---------- main ----------
const OUT = path.join(__dirname, "..", "assets", "textures");
fs.mkdirSync(OUT, { recursive: true });
console.log("DEX DASH texture generation");
console.log("  out:", OUT);

console.log(" game atlas...");
writeAtlas(path.join(OUT, "atlas_game"), 96, [
  ...makeBlocks(), ...makeSpikes(), ...makeCoins(), ...makePads(),
  ...makePortals(), ...makePlayer(), ...makeParticles(), ...makeDecor(),
  ...makeFinish(), ...makeBoss(),
]);
console.log(" ui atlas...");
writeAtlas(path.join(OUT, "atlas_ui"), 96, makeUi());
console.log(" bg atlas...");
writeAtlas(path.join(OUT, "atlas_bg"), 96, makeBg());
console.log("done.");
