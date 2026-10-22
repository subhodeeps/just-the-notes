#!/usr/bin/env node
//
// Trace a coloured curve out of a plot image and write it as an inline SVG.
//
// Made for _includes/home-hero-ringdown.svg, which is the waveform in
// assets/images/ringdownl2s2.png. The curve is redrawn by CSS in the theme's
// accent colour, so it stays crisp and works in both light and dark mode.
//
// How it works:
//   1. Decode the PNG (8-bit RGB or RGBA, non-interlaced) with Node's zlib.
//   2. In every pixel column, find the run of curve-coloured pixels and take
//      its midpoint. That point lies on the curve, even on steep stretches.
//   3. Map columns to time using the curve's first and last column (--t-range),
//      and use the flat start of the signal as the zero line.
//   4. Keep the --window part, scale it to --size (amplitude normalised to fill
//      the height), and simplify the polyline (Ramer-Douglas-Peucker, --eps).
//
// Usage (no dependencies; `source .venv/bin/activate` first for node):
//   node tools/trace-plot-svg.mjs assets/images/ringdownl2s2.png > _includes/home-hero-ringdown.svg
//
// Options (defaults reproduce the home page figure):
//   --t-range -150,150   time at the curve's first and last column
//   --window  -50,110    time range to keep
//   --size    640,200    SVG viewBox width,height
//   --pad     8          vertical padding inside the viewBox
//   --eps     0.3        simplification tolerance, in viewBox units (smaller = more points)
//   --flat    300        columns at the start of the curve used to find the zero line
//
// The curve colour test (isCurve below) matches the orange of the amore palette's
// plots; change it for curves of another colour.

import { readFileSync } from 'node:fs'
import { basename } from 'node:path'
import { inflateSync } from 'node:zlib'

const isCurve = (r, g, b) => r > 150 && r - b > 100 && g < 160

// --- Arguments ---------------------------------------------------------------

const args = process.argv.slice(2)
const input = args.find((a, i) => !a.startsWith('--') && !args[i - 1]?.startsWith('--'))
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`)
  return (i < 0 ? fallback : args[i + 1]).split(',').map(Number)
}

if (!input) {
  console.error('Usage: node tools/trace-plot-svg.mjs <plot.png> [options] > out.svg')
  process.exit(1)
}

const [tFirst, tLast] = opt('t-range', '-150,150')
const [t0, t1] = opt('window', '-50,110')
const [W, H] = opt('size', '640,200')
const [pad] = opt('pad', '8')
const [eps] = opt('eps', '0.3')
const [flatCols] = opt('flat', '300')

// --- PNG decoding ------------------------------------------------------------

function decodePng(buf) {
  let pos = 8 // skip signature
  let width, height, channels
  const idat = []

  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos)
    const type = buf.toString('ascii', pos + 4, pos + 8)
    const data = buf.subarray(pos + 8, pos + 8 + len)
    if (type === 'IHDR') {
      width = data.readUInt32BE(0)
      height = data.readUInt32BE(4)
      const [depth, colour, , , interlace] = data.subarray(8)
      if (depth !== 8 || ![2, 6].includes(colour) || interlace !== 0) {
        throw new Error('Only 8-bit, non-interlaced RGB or RGBA PNGs are supported')
      }
      channels = colour === 6 ? 4 : 3
    } else if (type === 'IDAT') {
      idat.push(data)
    } else if (type === 'IEND') {
      break
    }
    pos += 12 + len
  }

  // Undo the per-row filters (PNG spec, section 9)
  const raw = inflateSync(Buffer.concat(idat))
  const stride = width * channels
  const px = Buffer.alloc(height * stride)
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)]
    const src = y * (stride + 1) + 1
    const row = y * stride
    for (let x = 0; x < stride; x++) {
      const a = x >= channels ? px[row + x - channels] : 0
      const b = y > 0 ? px[row - stride + x] : 0
      const c = x >= channels && y > 0 ? px[row - stride + x - channels] : 0
      let v = raw[src + x]
      if (filter === 1) v += a
      else if (filter === 2) v += b
      else if (filter === 3) v += (a + b) >> 1
      else if (filter === 4) {
        const p = a + b - c
        const pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c)
        v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c
      }
      px[row + x] = v & 0xff
    }
  }
  return { width, height, channels, px }
}

// --- Tracing -----------------------------------------------------------------

const { width, height, channels, px } = decodePng(readFileSync(input))

// Midpoint of the curve-coloured run in each column (null where there is none)
const mid = new Array(width).fill(null)
for (let x = 0; x < width; x++) {
  let lo = -1, hi = -1
  for (let y = 0; y < height; y++) {
    const i = (y * width + x) * channels
    if (isCurve(px[i], px[i + 1], px[i + 2])) {
      if (lo < 0) lo = y
      hi = y
    }
  }
  if (lo >= 0) mid[x] = (lo + hi) / 2
}

const cols = mid.flatMap((y, x) => (y === null ? [] : [x]))
if (!cols.length) throw new Error('No curve-coloured pixels found; adjust isCurve')
const [x0, x1] = [cols[0], cols.at(-1)]
const timeOf = (x) => tFirst + ((tLast - tFirst) * (x - x0)) / (x1 - x0)

const flat = cols.slice(0, flatCols).map((x) => mid[x])
const yZero = flat.reduce((s, y) => s + y, 0) / flat.length

const points = cols
  .filter((x) => timeOf(x) >= t0 && timeOf(x) <= t1)
  .map((x) => [timeOf(x), yZero - mid[x]]) // up is positive

const amax = Math.max(...points.map(([, y]) => Math.abs(y)))
const scaled = points.map(([t, y]) => [((t - t0) / (t1 - t0)) * W, H / 2 - (y / amax) * (H / 2 - pad)])

// Ramer-Douglas-Peucker simplification
function simplify(p) {
  if (p.length < 3) return p
  const [[ax, ay], [bx, by]] = [p[0], p.at(-1)]
  const dx = bx - ax, dy = by - ay
  const n = Math.hypot(dx, dy) || 1
  let index = 0, dmax = -1
  for (let k = 1; k < p.length - 1; k++) {
    const d = Math.abs(dy * (p[k][0] - ax) - dx * (p[k][1] - ay)) / n
    if (d > dmax) [index, dmax] = [k, d]
  }
  if (dmax <= eps) return [p[0], p.at(-1)]
  return [...simplify(p.slice(0, index + 1)).slice(0, -1), ...simplify(p.slice(index))]
}

const path = simplify(scaled)
const d = 'M' + path.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join(' L')
console.error(`${points.length} points -> ${path.length} after simplification`)

// --- Output ------------------------------------------------------------------

// `include.alt` is filled in by _includes/home-hero.html from index.html's front matter
process.stdout.write(`<!-- Traced from assets/images/${basename(input)}, t = ${t0} to ${t1} (amplitude rescaled) by tools/trace-plot-svg.mjs -->
<svg class="home-hero-figure" viewBox="0 0 ${W} ${H}" role="img" aria-label="{{ include.alt | escape }}">
  <line class="axis" x1="0" y1="${H / 2}" x2="${W}" y2="${H / 2}" />
  <path class="wave" d="${d}" />
</svg>
`)
