#!/usr/bin/env python3
#
# Author(s): Subhodeep Sarkar
# Affiliation: IIT Gandhinagar and IIIT Allahabad
# Contact: subhodeep.sarkar1@gmail.com
# Date: October 2026
# Github: https://github.com/subhodeeps/just-the-notes
#
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "numpy",
#     "scipy",
#     "matplotlib",
#     "amore @ git+https://github.com/subhodeeps/amore.mplstyle",
# ]
# ///

"""Measure the period of the pendulum with `odeint`.

The script solves the pendulum of the post "Solving ODEs using
`odeint`", x'' + sin x = 0, from x(0) = 0 with y(0) = c. It plots x(t)
for a small and a large swing, and the period for many values of c
against the exact result, T = 4 K(c / 2), where K is the complete
elliptic integral of the first kind. Small swings have the period 2 pi
of the linear pendulum, and the period grows without bound as c
approaches 2. It saves the figure twice, as pendulum-period-light.png
and pendulum-period-dark.png, for the light and dark themes of the site.

The amore MPL stylesheet (https://github.com/subhodeeps/amore.mplstyle)
is optional. Without it, the figure uses the default matplotlib style
with the same colours. amore typesets text with LaTeX; set USETEX =
False below if LaTeX is not installed.

Usage
-----
    uv run pendulum_period.py [folder]

On the first run, uv reads the dependencies from the comment block at
the top of this file and installs them in a separate environment. The
script saves the figure in ./figures, or in `folder` if given.
"""

import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
from scipy.integrate import odeint
from scipy.special import ellipk

try:
    import amore
except ImportError:
    amore = None


# --- Simulation -------------------------------------------------------

SWINGS = (0.5, 1.95)  # values of c for the plot of x(t)
TMAX = 30.0  # length of the plot of x(t)


def f(S, t=0):
    """Return the right-hand side of the pendulum.

    Parameters
    ----------
    S : sequence
        State [x, y].
    t : float, optional
        Time. Unused, since the system is autonomous, but required by
        `odeint`.

    Returns
    -------
    list
        The derivatives [x', y'] = [y, -sin x].
    """
    x, y = S
    return [y, -np.sin(x)]


def swing(c, tspan):
    """Solve the pendulum from x(0) = 0, y(0) = c.

    Parameters
    ----------
    c : float
        Initial angular velocity.
    tspan : ndarray
        Times at which the solution is returned.

    Returns
    -------
    ndarray
        The angle x at the times in tspan.
    """
    S0 = [0.0, c]
    ys = odeint(f, S0, tspan, rtol=1e-10, atol=1e-10)
    return ys[:, 0]


def measured_period(c):
    """Measure the period of the swing started with y(0) = c.

    The period is the mean time between the upward crossings of x = 0,
    found by linear interpolation between the output times.

    Parameters
    ----------
    c : float
        Initial angular velocity, with |c| < 2.

    Returns
    -------
    float
        The period.
    """
    t_end = 4.0 * exact_period(c)  # about four periods
    tspan = np.linspace(0.0, t_end, 40001)
    x = swing(c, tspan)
    up = np.flatnonzero((x[:-1] < 0) & (x[1:] >= 0))
    crossings = tspan[up] - x[up] * (tspan[up + 1] - tspan[up]) / (
        x[up + 1] - x[up]
    )
    return float(np.mean(np.diff(crossings)))


def exact_period(c):
    """Return the exact period, T = 4 K(k) with k = c / 2.

    scipy.special.ellipk takes the parameter m = k^2.

    Parameters
    ----------
    c : float or ndarray
        Initial angular velocity, with |c| < 2.

    Returns
    -------
    float or ndarray
        The period.
    """
    return 4.0 * ellipk((np.asarray(c) / 2.0) ** 2)


# --- Drawing ----------------------------------------------------------


def figure_period(data, colours):
    """Draw x(t) for two swings, and the period against c."""
    fig, (left, right) = period_axes()
    swings = zip(SWINGS, data["swings"], colours["lines"], strict=True)
    for c, x, colour in swings:
        left.plot(
            data["t"],
            x,
            color=colour,
            lw=LOOK["line_width"],
            label=rf"$c = {c}$",
        )
    left.legend(loc="lower left")

    right.axhline(
        2.0 * np.pi,
        color=colours["guide"],
        lw=LOOK["guide_width"],
        ls="--",
    )
    right.plot(
        data["c_fine"],
        data["exact"],
        color=colours["lines"][0],
        lw=LOOK["line_width"],
        label=r"$4K(c/2)$",
    )
    right.plot(
        data["c"],
        data["measured"],
        "o",
        ms=LOOK["marker_size"],
        color=colours["lines"][1],
        label=r"\texttt{odeint}" if USETEX else "odeint",
    )
    right.legend(loc="upper left")
    return fig


FIGURES = {"pendulum-period": figure_period}


# --- Aesthetics -------------------------------------------------------

USETEX = True

if amore is not None:
    TEAL, RED, SLATE = (
        amore.palette("teal"),
        amore.palette("red"),
        amore.palette("slate"),
    )
else:
    # The same colours as the amore palettes
    TEAL = dict(main="#4e9e9f")
    RED = dict(main="#d2737f")
    SLATE = dict(ink="#28313d", main="#768594", light="#c2c9d1")

THEMES = {
    "light": dict(
        text=SLATE["ink"],
        lines=[TEAL["main"], RED["main"]],
        guide=SLATE["main"],
    ),
    "dark": dict(
        text=SLATE["light"],
        lines=[TEAL["main"], RED["main"]],
        guide=SLATE["main"],
    ),
}

LOOK = dict(
    size=(8.0, 2.6),  # figure size in inches
    dpi=200,
    line_width=1.3,
    guide_width=0.8,
    marker_size=3.5,
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
        }
    )
    return colours


def period_axes():
    """Create a figure with two panels: x(t), and the period against c.

    Returns
    -------
    fig : matplotlib.figure.Figure
    axes : tuple of matplotlib.axes.Axes
    """
    fig, (left, right) = plt.subplots(
        1,
        2,
        figsize=LOOK["size"],
        layout="constrained",
        width_ratios=(1.6, 1.0),
    )
    left.set_xlim(0.0, TMAX)
    left.set_ylim(-3.2, 3.2)
    left.set_yticks([-np.pi, 0, np.pi], [r"$-\pi$", r"$0$", r"$\pi$"])
    left.set_xlabel(r"$t$")
    left.set_ylabel(r"$x$")
    right.set_xlim(0.0, 2.0)
    right.set_ylim(5.0, 16.0)
    right.set_yticks(
        [2.0 * np.pi, 10, 15], [r"$2\pi$", r"$10$", r"$15$"]
    )
    right.set_xlabel(r"$c$")
    right.set_ylabel(r"$T$")
    return fig, (left, right)


def main(out=Path("figures")):
    """Measure the periods, then save the figure in both themes.

    Parameters
    ----------
    out : pathlib.Path, optional
        Folder for the figure.
    """
    t = np.linspace(0.0, TMAX, 3001)
    c = np.linspace(0.1, 1.98, 20)
    c_fine = np.linspace(0.0, 1.995, 400)
    data = dict(
        t=t,
        swings=[swing(ci, t) for ci in SWINGS],
        c=c,
        measured=np.array([measured_period(ci) for ci in c]),
        c_fine=c_fine,
        exact=exact_period(c_fine),
    )
    error = np.max(
        np.abs(data["measured"] - exact_period(c)) / exact_period(c)
    )
    print(f"Largest relative difference from 4K(c/2): {error:.1e}")
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
