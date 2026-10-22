"""Build the data of the home page animation: the photon of the marginal pocket (Hartle-Thorne,
b = 4.304332 M) from ht_chaos_reproduction, as in animation/pocket_photons.mp4, right column.

The photon is that of Fig. 2 of K. Kostaros and G. Pappas, Class. Quantum Grav. 39, 134001 (2022),
doi:10.1088/1361-6382/ac7028, arXiv:2111.09367. The simulation and animation are our own reproduction.

Nothing is integrated. The inputs are stored in tools/data/:

    photon_marginal_pocket-7d81183a367e.npz   the stored orbit, copied from ht_chaos_reproduction
                                              data/python/shared/ (alpha = 0.0051, to t = 17916 M);
                                              samples = (t, r, theta)
    pocket-separatrix.npz                     the zero-velocity separatrix W(r, theta; b) = 0 in the
                                              window, as (r, theta) rows with NaN rows between lines

Building needs only the Python standard library:

    python3 tools/export_pocket_orbit.py

and writes assets/data/pocket-orbit.json for assets/js/home-hero-pocket.js:

    view        the (r, theta) window and the canvas size it maps to
    separatrix  polylines of W = 0, as flat [x0, y0, x1, y1, ...] in canvas units x scale
    orbit       the photon from its entry into the pocket to the end of the run, same units,
                evenly thinned to --points samples
    t           coordinate time (M) at the first and last orbit sample

The separatrix is the closed-form potential (geodesics.analysis.veff) on a grid, as
drawing.separatrix draws it. To compute it again (for another window), run with the research
project's Python, which has numpy, matplotlib and its modules:

    ~/Documents/ht_chaos_reproduction/.venv/bin/python tools/export_pocket_orbit.py separatrix \
        --repo ~/Documents/ht_chaos_reproduction
"""
import argparse
import ast
import json
import math
import struct
import sys
import zipfile
from array import array
from pathlib import Path

SITE = Path(__file__).resolve().parent.parent
DATA = Path(__file__).resolve().parent / "data"
ORBIT = DATA / "photon_marginal_pocket-7d81183a367e.npz"
SEPARATRIX = DATA / "pocket-separatrix.npz"
OUT = SITE / "assets" / "data" / "pocket-orbit.json"

B_MARGINAL = 4.304332       # pocket_photons.B_MARGINAL
R_POCKET = 2.6              # in the pocket at r < R_POCKET (pocket_photons_animation.R_POCKET)
VIEW_R = (2.17, 2.38)       # the window around the pocket (M)
VIEW_TH = (1.44, 1.70)      # (rad); theta grows upwards, as in the figures
SIZE = (400, 300)           # canvas units the window maps to
SCALE = 10                  # coordinates are stored as integers: canvas units x SCALE


# --- Reading .npz without numpy ------------------------------------------------------------

TYPECODES = {"<f4": "f", "<f8": "d", "<i8": "q"}


def load_npz(path: Path, keys: tuple) -> dict:
    """The arrays `keys` of an .npz file, as (flat array, shape, fortran_order). Little-endian
    float32, float64 and int64 arrays, in C or Fortran order."""
    out = {}
    with zipfile.ZipFile(path) as z:
        for key in keys:
            raw = z.read(f"{key}.npy")
            if raw[:6] != b"\x93NUMPY":
                raise ValueError(f"{path}: {key} is not an .npy array")
            major = raw[6]
            fmt, start = ("<H", 10) if major == 1 else ("<I", 12)
            (length,) = struct.unpack(fmt, raw[8:start])
            header = ast.literal_eval(raw[start:start + length].decode("latin1"))
            if header["descr"] not in TYPECODES:
                raise ValueError(f"{path}: {key} is {header['descr']}, not one of {list(TYPECODES)}")
            values = array(TYPECODES[header["descr"]])
            values.frombytes(raw[start + length:])
            out[key] = (values, header["shape"], header["fortran_order"])
    return out


# --- Building the JSON ----------------------------------------------------------------------

def to_canvas(r: float, th: float) -> list:
    """(r, theta) to integer canvas coordinates [x, y]."""
    (r0, r1), (t0, t1), (w, h) = VIEW_R, VIEW_TH, SIZE
    return [round((r - r0) / (r1 - r0) * w * SCALE), round((t1 - th) / (t1 - t0) * h * SCALE)]


def orbit(points: int) -> tuple:
    """The stored photon from its entry into the pocket, thinned to `points` samples."""
    samples, (n, _), fortran = load_npz(ORBIT, ("samples",))["samples"]
    if fortran:     # column by column: all t, then all r, then all theta
        t, r, th = samples[:n], samples[n:2 * n], samples[2 * n:]
    else:
        t, r, th = samples[0::3], samples[1::3], samples[2::3]
    start = next(i for i in range(n) if r[i] < R_POCKET)
    keep = sorted({round(start + (n - 1 - start) * j / (points - 1)) for j in range(points)})
    xy = [v for i in keep for v in to_canvas(r[i], th[i])]
    return xy, [float(t[start]), float(t[n - 1])]


def separatrix() -> list:
    """The stored separatrix lines, in canvas units."""
    rows, (n, _), fortran = load_npz(SEPARATRIX, ("lines",))["lines"]
    pairs = zip(rows[:n], rows[n:]) if fortran else zip(rows[0::2], rows[1::2])
    lines, line = [], []
    for r, th in pairs:
        if math.isnan(r):
            lines.append(line)
            line = []
        else:
            line += to_canvas(r, th)
    return [ln for ln in lines + [line] if len(ln) > 2]


def build(points: int, out: Path) -> None:
    xy, t = orbit(points)
    data = dict(view=dict(r=VIEW_R, theta=VIEW_TH, width=SIZE[0], height=SIZE[1], scale=SCALE),
                b=B_MARGINAL, t=t, separatrix=separatrix(), orbit=xy)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, separators=(",", ":")))
    n_sep = sum(len(s) // 2 for s in data["separatrix"])
    print(f"{out}: {len(xy) // 2} orbit points, {n_sep} separatrix points, {out.stat().st_size // 1024} KB")


# --- Computing the separatrix (research project's Python) -----------------------------------

def compute_separatrix(repo: Path, n: int) -> None:
    """W(r, theta; b) = 0 in the window, as drawing.separatrix computes it, to SEPARATRIX."""
    import numpy as np
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    sys.path.insert(0, str(repo / "src" / "python"))
    import hartle_thorne as ht
    from geodesics import analysis

    met, prm = ht.spacetime()
    pad = 0.02      # a little beyond the window, so the curves run off its edges
    R, T = np.meshgrid(np.linspace(VIEW_R[0] - pad, VIEW_R[1] + pad, n),
                       np.linspace(VIEW_TH[0] - pad, VIEW_TH[1] + pad, n))
    with np.errstate(all="ignore"):
        W = analysis.veff(met, prm, R, T, B_MARGINAL)
        W = np.where(np.abs(W) < 50.0, W, np.nan)   # the pole near r = 2M, as in drawing.separatrix
    segments = [seg for seg in plt.contour(R, T, W, levels=[0.0]).allsegs[0] if len(seg) > 1]
    plt.close("all")
    gap = np.full((1, 2), np.nan)
    lines = np.concatenate([part for seg in segments for part in (seg, gap)][:-1])
    np.savez(SEPARATRIX, lines=lines.astype("<f8"), b=np.array(B_MARGINAL),
             view_r=np.array(VIEW_R), view_theta=np.array(VIEW_TH), grid=np.array(n))
    print(f"{SEPARATRIX}: {len(segments)} lines, {len(lines) - len(segments) + 1} points")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("step", nargs="?", choices=["build", "separatrix"], default="build",
                    help="build the JSON (default), or compute the separatrix again")
    ap.add_argument("--points", type=int, default=8000, help="orbit samples to keep (build)")
    ap.add_argument("--out", type=Path, default=OUT, help="the JSON (build)")
    ap.add_argument("--repo", type=Path, help="the ht_chaos_reproduction folder (separatrix)")
    ap.add_argument("--grid", type=int, default=500, help="grid points per side (separatrix)")
    args = ap.parse_args()
    if args.step == "separatrix":
        if args.repo is None:
            ap.error("separatrix needs --repo")
        compute_separatrix(args.repo, args.grid)
    else:
        build(args.points, args.out)


if __name__ == "__main__":
    main()
