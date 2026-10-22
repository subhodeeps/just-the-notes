#!/usr/bin/env python3
#
# Author(s): Subhodeep Sarkar
# Affiliation: IIT Gandhinagar and IIIT Allahabad
# Contact: subhodeep.sarkar1@gmail.com
# Date: October 2026
# Github: https://github.com/subhodeeps/quasinormal-notes
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

"""Solve the damped pendulum with `odeint` and plot its phase portrait.

The script adds friction to the pendulum of the post "Solving ODEs using
`odeint`", x'' + gamma x' + sin x = 0, written as the first-order system
x' = y, y' = -sin x - gamma y. Friction drains the energy, dE/dt =
-gamma y^2, so every trajectory ends at rest at one of the stable
equilibria x = 2 pi n. The script plots the vector field and a few
trajectories with the amore matplotlib stylesheet and saves the figure
twice, as damped-phase-portrait-light.png and
damped-phase-portrait-dark.png, for the light and dark themes of the
site.

The amore MPL stylesheet (https://github.com/subhodeeps/amore.mplstyle)
is optional. Without it, the figure uses the default matplotlib style
with the same colours. amore typesets text with LaTeX; set USETEX =
False below if LaTeX is not installed.

Usage
-----
    uv run damped_pendulum.py [folder]

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
from matplotlib.patches import FancyArrowPatch
from scipy.integrate import odeint

try:
    import amore
except ImportError:
    amore = None


# --- Simulation -------------------------------------------------------

GAMMA = 0.25  # damping coefficient

# Window of the phase plane
XMIN, XMAX, YMIN, YMAX = -4.0 * np.pi, 4.0 * np.pi, -3.0, 3.0

TSPAN = np.linspace(0.0, 40.0, 4001)


def f(S, t=0, gamma=GAMMA):
    """Return the right-hand side of the damped pendulum.

    Parameters
    ----------
    S : sequence
        State [x, y]. The components may be arrays, e.g. a grid.
    t : float, optional
        Time. Unused, since the system is autonomous, but required by
        `odeint`.
    gamma : float, optional
        Damping coefficient.

    Returns
    -------
    list
        The derivatives [x', y'] = [y, -sin x - gamma y].
    """
    x, y = S
    return [y, -np.sin(x) - gamma * y]


def vector_field(n=30):
    """Evaluate the vector field on an n x n grid over the window.

    Parameters
    ----------
    n : int, optional
        Number of grid points along each axis.

    Returns
    -------
    XX, YY : ndarray
        Coordinates of the grid points.
    xdot, ydot : ndarray
        Components of the vector field at the grid points.
    """
    x = np.linspace(XMIN, XMAX, n)
    y = np.linspace(YMIN, YMAX, n)
    XX, YY = np.meshgrid(x, y)
    xdot, ydot = f([XX, YY])
    return XX, YY, xdot, ydot


def trajectory(x0, y0, tspan=TSPAN):
    """Solve the damped pendulum from the initial condition (x0, y0).

    Parameters
    ----------
    x0, y0 : float
        Initial angle and angular velocity.
    tspan : ndarray, optional
        Times at which the solution is returned.

    Returns
    -------
    dict
        The initial condition, under "x0" and "y0", and the solution,
        under "x" and "y".
    """
    S0 = [x0, y0]
    ys = odeint(f, S0, tspan)
    return dict(x0=x0, y0=y0, x=ys[:, 0], y=ys[:, 1])


def orbits():
    """Return the trajectories of the figure.

    One starts at the bottom and spirals into the origin. The others
    start at the edges of the window or at the saddles x = -3 pi and
    x = 3 pi, with enough energy to whirl over the top. Each loses
    energy on every turn, until one of the wells captures it.

    Returns
    -------
    list of dict
        Trajectories, as returned by `trajectory`.
    """
    starts = [(0.0, 1.9), (-4.0 * np.pi, 2.95), (4.0 * np.pi, -2.95)]
    starts += [(-3.0 * np.pi, 1.2), (3.0 * np.pi, -1.2)]
    return [trajectory(x0, y0) for x0, y0 in starts]


# --- Drawing ----------------------------------------------------------


def draw_flow(ax, field, colours):
    """Draw the streamlines of the vector field.

    Parameters
    ----------
    ax : matplotlib.axes.Axes
        Axes to draw on.
    field : tuple of ndarray
        Grid and vector field, as returned by `vector_field`.
    colours : dict
        Colours of the theme, from `THEMES`.
    """
    ax.streamplot(
        *field,
        density=LOOK["flow_density"],
        color=colours["flow"],
        linewidth=LOOK["flow_width"],
        arrowsize=LOOK["flow_arrows"],
    )


def draw_arrowheads(ax, x, y, colour):
    """Draw arrowheads along a curve at even intervals.

    LOOK["head_spacing"] sets the spacing in inches on the figure, which
    keeps the arrowheads evenly spaced whatever the scales of the two
    axes.

    Parameters
    ----------
    ax : matplotlib.axes.Axes
        Axes to draw on.
    x, y : ndarray
        Points of the curve.
    colour : str
        Colour of the arrowheads.
    """
    box = ax.get_position()
    fig_w, fig_h = ax.figure.get_size_inches()
    sx = box.width * fig_w / (XMAX - XMIN)  # inches per unit of x
    sy = box.height * fig_h / (YMAX - YMIN)  # inches per unit of y
    length = np.concatenate(
        [[0], np.cumsum(np.hypot(np.diff(x) * sx, np.diff(y) * sy))]
    )
    spacing = LOOK["head_spacing"]
    for at in np.arange(spacing / 2, length[-1], spacing):
        i = np.searchsorted(length, at)
        if i + 1 < len(x) and XMIN < x[i] < XMAX and YMIN < y[i] < YMAX:
            ax.add_patch(
                FancyArrowPatch(
                    (x[i], y[i]),
                    (x[i + 1], y[i + 1]),
                    arrowstyle="-|>",
                    mutation_scale=LOOK["head_size"],
                    lw=0,
                    color=colour,
                    zorder=4,
                )
            )


def draw_orbit(ax, orbit, colours):
    """Draw a trajectory, with arrowheads for the direction of motion.

    Parameters
    ----------
    ax : matplotlib.axes.Axes
        Axes to draw on.
    orbit : dict
        Trajectory, as returned by `trajectory`.
    colours : dict
        Colours of the theme, from `THEMES`.
    """
    x, y = orbit["x"], orbit["y"]
    ax.plot(
        x, y, color=colours["orbit"], lw=LOOK["orbit_width"], zorder=3
    )
    # Draw arrowheads only while the motion is large, so that the tight
    # inner turns stay clear
    end = np.argmax(
        np.hypot(np.sin(x / 2), y / 2) < LOOK["head_cutoff"]
    )
    draw_arrowheads(ax, x[:end], y[:end], colours["head"])


def figure_damped(data, colours):
    """Draw the phase portrait of the damped pendulum."""
    fig, ax = phase_plane()
    draw_flow(ax, data["field"], colours)
    for orbit in data["orbits"]:
        draw_orbit(ax, orbit, colours)
    return fig


FIGURES = {"damped-phase-portrait": figure_damped}


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
    RED = dict(ink="#6b1d2a", main="#d2737f", light="#efc0c4")
    SLATE = dict(ink="#28313d", light="#c2c9d1")

THEMES = {
    "light": dict(
        text=SLATE["ink"],
        flow=TEAL["main"],
        orbit=RED["main"],
        head=RED["ink"],
    ),
    "dark": dict(
        text=SLATE["light"],
        flow=TEAL["main"],
        orbit=RED["main"],
        head=RED["light"],
    ),
}

LOOK = dict(
    size=(8.0, 2.6),  # figure size in inches
    dpi=200,
    flow_width=0.5,  # streamlines: thin, in the background
    flow_arrows=0.6,
    flow_density=2,
    orbit_width=1.3,  # trajectories: thicker, in front
    head_size=7,
    head_spacing=1.6,  # inches between arrowheads
    head_cutoff=0.35,  # no arrowheads once the motion is this small
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


def phase_plane():
    """Create a figure with the axes of the phase plane.

    Returns
    -------
    fig : matplotlib.figure.Figure
    ax : matplotlib.axes.Axes
    """
    fig, ax = plt.subplots(figsize=LOOK["size"], layout="constrained")
    ax.set_xlim(XMIN, XMAX)
    ax.set_ylim(YMIN, YMAX)
    ax.set_xticks(
        np.pi * np.arange(-4, 5, 2),
        [r"$-4\pi$", r"$-2\pi$", r"$0$", r"$2\pi$", r"$4\pi$"],
    )
    ax.set_yticks([-2, 0, 2])
    ax.set_xlabel(r"$x$")
    ax.set_ylabel(r"$y = \dot{x}$")
    # fix the layout, so that the size of the axes is known
    fig.canvas.draw()
    return fig, ax


def main(out=Path("figures")):
    """Solve the system, then save the figure in both themes.

    Parameters
    ----------
    out : pathlib.Path, optional
        Folder for the figure.
    """
    data = dict(field=vector_field(), orbits=orbits())
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
