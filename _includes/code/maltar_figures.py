#!/usr/bin/env python3
#
# Author(s): Subhodeep Sarkar
# Affiliation: IIT Gandhinagar and IIIT Allahabad
# Contact: subhodeep.sarkar1@gmail.com
# Date: June 2026
# Last updated: October 2026
# Github: https://github.com/subhodeeps/quasinormal-notes
#
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "numpy",
#     "matplotlib",
#     "amore @ git+https://github.com/subhodeeps/amore.mplstyle",
# ]
# ///

"""Plot the Phase-1 benchmarks of the Maltár cluster.

The first figure shows the Mathematica benchmark: the time to compute
the spectral radii of 120 random 3000 x 3000 matrices with
`ParallelMap`, on the MacBook Air alone, on the ThinkPad alone and on
both, with the coarsest and the finest grained distribution of the
work. The timings come from maltar_tests/maltar_phase_1.nb.

The second and third figures show the Julia benchmark: the time to
solve the Lorenz system for a sweep of rho with `pmap`, and the number
of trajectories solved per second, against the number of
trajectories, for the same three pools of workers. The timings come
from maltar_tests/lorenz_scaling_performance.csv, which
maltar_tests/test_cluster.ipynb wrote.

The script prints the speedup of both machines over the faster
machine alone for each benchmark, and saves each figure twice, as
<name>-light.png and <name>-dark.png, for the light and dark themes of
the site. These are
the figures of the posts "The Maltár Tactical Compute Asset" and
"Testing Maltár in Julia and Mathematica".

The amore MPL stylesheet (https://github.com/subhodeeps/amore.mplstyle)
is optional. Without it, the figures use the default matplotlib style
with the same colours. amore typesets text with LaTeX; set USETEX =
False below if LaTeX is not installed.

Usage
-----
    uv run maltar_figures.py [folder]

The script saves the figures in ./figures, or in `folder` if given.
"""

import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np

try:
    import amore
except ImportError:
    amore = None


# --- Data -------------------------------------------------------------

HERE = Path(__file__).resolve().parent
TIMINGS = HERE / "maltar_tests" / "lorenz_scaling_performance.csv"

# Seconds for the 120 spectral radii, from maltar_phase_1.nb, as
# (CoarsestGrained, FinestGrained)
EIGEN = {
    "MacBook Air\n8 kernels": (361.919, 394.768),
    "ThinkPad\n12 kernels": (383.948, 395.444),
    "Both\n20 kernels": (233.649, 195.544),
}

SMALLEST = 1000  # trajectories; smaller runs take under 0.2 s
WINDOW = 25  # points in the running median of the throughput


def running_median(y, window=WINDOW):
    """Return the running median of y over `window` points.

    Parameters
    ----------
    y : ndarray
        Values to smooth.
    window : int, optional
        Number of points in the window, centred where possible.

    Returns
    -------
    ndarray
        Running median, of the same length as y.
    """
    half = window // 2
    return np.array(
        [
            np.median(y[max(0, i - half) : i + half + 1])
            for i in range(len(y))
        ]
    )


def timings():
    """Return the timings of the Julia benchmark for each pool.

    Returns
    -------
    numpy.ndarray
        Structured array with the number of trajectories under
        "trajectories" and the seconds of each pool under
        "<pool>_time_seconds", for "local", "remote" and "hybrid".
    """
    return np.genfromtxt(TIMINGS, delimiter=",", names=True)


def throughput():
    """Return the throughput of the Julia benchmark for each pool.

    Returns
    -------
    dict
        The numbers of trajectories under "n", and for each pool
        ("local", "remote", "hybrid") the trajectories per second, raw
        and as a running median under "<pool>_median".
    """
    data = timings()
    keep = data["trajectories"] >= SMALLEST
    n = data["trajectories"][keep]
    out = dict(n=n)
    for pool in ["local", "remote", "hybrid"]:
        rate = n / data[f"{pool}_time_seconds"][keep]
        out[pool] = rate
        out[f"{pool}_median"] = running_median(rate)
    return out


def summary(times, rates):
    """Summarise the gain of both machines over the faster one alone.

    The speedup divides the best time of either machine alone, with
    any method, by the time of both machines together. For the Julia
    benchmark, it uses the largest run and the median throughput.

    Parameters
    ----------
    times : numpy.ndarray
        Timings of the Julia benchmark, from `timings`.
    rates : dict
        Throughput of the Julia benchmark, from `throughput`.

    Returns
    -------
    str
        The speedups of both benchmarks, and the median throughput of
        each pool with its share of the sum of the two machines.
    """
    alone = min(min(t) for t in list(EIGEN.values())[:2])
    coarse, fine = list(EIGEN.values())[2]
    last = times[-1]
    lorenz_alone = min(
        last["local_time_seconds"], last["remote_time_seconds"]
    )
    medians = {
        pool: np.median(rates[pool])
        for pool in ["local", "remote", "hybrid"]
    }
    total = medians["local"] + medians["remote"]
    faster = max(medians["local"], medians["remote"])
    return (
        f"Eigenvalues: best alone {alone:.1f} s; both {coarse:.1f} s "
        f"(speedup {alone / coarse:.2f}) and {fine:.1f} s "
        f"(speedup {alone / fine:.2f}).\n"
        f"Lorenz, {last['trajectories']:.0f} trajectories: best alone "
        f"{lorenz_alone:.3f} s, both "
        f"{last['hybrid_time_seconds']:.3f} s "
        f"(speedup {lorenz_alone / last['hybrid_time_seconds']:.2f}).\n"
        f"Lorenz throughput: local {medians['local']:.0f}/s, remote "
        f"{medians['remote']:.0f}/s, both {medians['hybrid']:.0f}/s "
        f"(speedup {medians['hybrid'] / faster:.2f}, "
        f"{medians['hybrid'] / total:.0%} of the sum)."
    )


# --- Drawing ----------------------------------------------------------

POOLS = {
    "local": "MacBook Air (8 workers)",
    "remote": "ThinkPad (12 workers)",
    "hybrid": "Both (20 workers)",
}


def figure_times(data, colours):
    """Draw the time of the Julia benchmark against its size."""
    fig, ax = plt.subplots(figsize=LOOK["size"], layout="constrained")
    times = data["timings"]
    n = times["trajectories"] / 1000
    for (pool, label), colour in zip(
        POOLS.items(), colours["lines"], strict=True
    ):
        ax.plot(
            n,
            times[f"{pool}_time_seconds"],
            color=colour,
            lw=0.8,
            label=label,
        )
    ax.set_yscale("log")
    ax.set_xlim(0, 50)
    ax.set_xlabel(r"Trajectories ($\times 10^3$)")
    ax.set_ylabel("Time (s)")
    ax.legend(loc="lower right")
    return fig


def figure_eigenvalues(data, colours):
    """Draw the times of the eigenvalue benchmark as grouped bars."""
    fig, ax = plt.subplots(figsize=LOOK["size"], layout="constrained")
    x = np.arange(len(EIGEN))
    width = LOOK["bar_width"]
    methods = ["CoarsestGrained", "FinestGrained"]
    for j, (method, colour) in enumerate(
        zip(methods, colours["bars"], strict=True)
    ):
        times = [t[j] for t in EIGEN.values()]
        bars = ax.bar(
            x + (j - 0.5) * width,
            times,
            width,
            color=colour,
            label=rf"\texttt{{{method}}}" if USETEX else method,
        )
        ax.bar_label(bars, fmt="%.0f", padding=2)
    ax.set_xticks(x, list(EIGEN))
    ax.set_xlim(-0.6, len(EIGEN) - 0.3)
    ax.set_ylim(0, 470)
    ax.set_ylabel("Time (s)")
    ax.legend(loc="upper right", ncols=2)
    return fig


def figure_throughput(data, colours):
    """Draw the throughput of the Julia benchmark against its size."""
    fig, ax = plt.subplots(figsize=LOOK["size"], layout="constrained")
    rates = data["rates"]
    n = rates["n"] / 1000
    for (pool, label), colour in zip(
        POOLS.items(), colours["lines"], strict=True
    ):
        ax.plot(n, rates[pool], color=colour, lw=0.5, alpha=0.35)
        ax.plot(
            n,
            rates[f"{pool}_median"],
            color=colour,
            lw=LOOK["line_width"],
            label=label,
        )
    ax.plot(
        n,
        rates["local_median"] + rates["remote_median"],
        color=colours["text"],
        lw=LOOK["line_width"],
        ls="dashed",
        label="Sum of the two machines",
    )
    ax.set_xlim(0, 50)
    ax.set_ylim(0, 16000)
    ax.set_xlabel(r"Trajectories ($\times 10^3$)")
    ax.set_ylabel("Trajectories per second")
    ax.legend(loc="lower right", ncols=2)
    return fig


FIGURES = {
    "eigenvalues": figure_eigenvalues,
    "lorenz-times": figure_times,
    "lorenz-throughput": figure_throughput,
}


# --- Aesthetics -------------------------------------------------------

USETEX = True

if amore is not None:
    TEAL, RED, AMBER, BLUE, SLATE = (
        amore.palette("teal"),
        amore.palette("red"),
        amore.palette("amber"),
        amore.palette("blue"),
        amore.palette("slate"),
    )
else:
    # The same colours as the amore palettes
    TEAL = dict(main="#4e9e9f")
    RED = dict(main="#d2737f")
    AMBER = dict(main="#d39b3c")
    BLUE = dict(main="#5c9dc7")
    SLATE = dict(ink="#28313d", light="#c2c9d1")

BARS = [BLUE["main"], AMBER["main"]]  # coarsest and finest grained
LINES = [
    TEAL["main"],
    RED["main"],
    AMBER["main"],
]  # MacBook Air, ThinkPad and both

THEMES = {
    "light": dict(text=SLATE["ink"], bars=BARS, lines=LINES),
    "dark": dict(text=SLATE["light"], bars=BARS, lines=LINES),
}

LOOK = dict(
    size=(8.0, 3.0),  # figure size in inches
    dpi=200,
    bar_width=0.36,
    line_width=1.3,
)


def use_theme(theme):
    """Set the style and colours for one theme of the site.

    Uses amore if it is installed and the default matplotlib style
    otherwise, with a transparent background in both cases.

    Parameters
    ----------
    theme : {"light", "dark"}
        Theme of the site.

    Returns
    -------
    dict
        Colours of the theme, from `THEMES`.
    """
    if amore is not None:
        amore.use()
    else:
        plt.style.use("default")
    colours = THEMES[theme]
    plt.rcParams.update(
        {
            "text.usetex": USETEX,
            "mathtext.fontset": "cm",  # used when USETEX is False
            "text.color": colours["text"],
            "axes.labelcolor": colours["text"],
            "axes.edgecolor": colours["text"],
            "xtick.color": colours["text"],
            "ytick.color": colours["text"],
            "axes.facecolor": "none",
            "figure.facecolor": "none",
            "savefig.transparent": True,
            "axes.grid": False,
            "legend.frameon": False,
        }
    )
    return colours


def main(out=Path("figures")):
    """Read the timings, then save every figure in both themes.

    Parameters
    ----------
    out : pathlib.Path, optional
        Folder for the figures.
    """
    data = dict(timings=timings(), rates=throughput())
    print(summary(data["timings"], data["rates"]))
    out.mkdir(parents=True, exist_ok=True)
    for theme in THEMES:
        colours = use_theme(theme)
        for name, draw in FIGURES.items():
            fig = draw(data, colours)
            path = out / f"{name}-{theme}.png"
            fig.savefig(path, dpi=LOOK["dpi"])
            plt.close(fig)
            print(path)


if __name__ == "__main__":
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else Path("figures"))
