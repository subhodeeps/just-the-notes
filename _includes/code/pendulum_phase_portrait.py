#!/usr/bin/env python3
#
# Author(s): Subhodeep Sarkar
# Affiliation: IIT Gandhinagar and IIIT Allahabad
# Contact: subhodeep.sarkar1@gmail.com
# Date: 2021
# Last updated: October 2026
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

"""Solve the pendulum with `odeint` and plot its phase portrait.

The script writes the pendulum, x'' + sin x = 0, as the first-order
system x' = y, y' = -sin x, and solves it for several initial
conditions. It plots the vector field and the trajectories with the
amore matplotlib stylesheet and saves each figure twice, as
<name>-light.png and <name>-dark.png, for the light and dark themes of
the site. These are the figures of the post "Solving ODEs using
`odeint`".

The script has three parts: the simulation, the drawing, and the
aesthetics (colours, sizes and the axes), which the drawing uses.

The amore MPL stylesheet (https://github.com/subhodeeps/amore.mplstyle)
is optional. Without it, the figures use the default matplotlib style
with the same colours. amore typesets text with LaTeX; set USETEX =
False below if LaTeX is not installed.

Usage
-----
    uv run pendulum_phase_portrait.py [folder]

On the first run, uv reads the dependencies from the comment block at
the top of this file and installs them in a separate environment. The
script saves the figures in ./figures, or in `folder` if given.
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

# Window of the phase plane
XMIN, XMAX, YMIN, YMAX = -4.0 * np.pi, 4.0 * np.pi, -3.0, 3.0

# More time steps than in the post, for smooth curves
TSPAN = np.linspace(0.0, 45.0, 4001)


def f(S, t=0):
    """Return the right-hand side of the pendulum.

    Parameters
    ----------
    S : sequence
        State [x, y]. The components may be arrays, e.g. a grid.
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
    """Solve the pendulum from the initial condition (x0, y0).

    Parameters
    ----------
    x0, y0 : float
        Initial angle and angular velocity.
    tspan : ndarray, optional
        Times at which the solution is returned.

    Returns
    -------
    dict
        The initial condition, under "x0" and "y0", the solution, under
        "x" and "y", and the methods and the highest order that LSODA
        used, under "methods" and "order".
    """
    S0 = [x0, y0]
    ys, info = odeint(f, S0, tspan, full_output=True)
    return dict(
        x0=x0,
        y0=y0,
        x=ys[:, 0],
        y=ys[:, 1],
        methods=set(info["mused"].tolist()),
        order=int(info["nqu"].max()),
    )


METHODS = {
    1: "Adams",
    2: "BDF",
}  # the methods of LSODA, as `odeint` numbers them


def methods_used(orbits):
    """Summarise the methods that LSODA used for a set of trajectories.

    Parameters
    ----------
    orbits : list of dict
        Trajectories, as returned by `trajectory`.

    Returns
    -------
    str
        How many trajectories used each method, and the highest order
        used.
    """
    counts = {
        name: sum(m in orbit["methods"] for orbit in orbits)
        for m, name in METHODS.items()
    }
    order = max(orbit["order"] for orbit in orbits)
    used = ", ".join(
        f"{name} for {n} of them" for name, n in counts.items() if n
    )
    return (
        f"LSODA solved {len(orbits)} trajectories, using {used}, "
        f"up to order {order}."
    )


def first_lap(x):
    """Return the index at which a libration completes one period.

    The libration starts at x = 0, and the period ends at the second
    crossing of x = 0.

    Parameters
    ----------
    x : ndarray
        Angle along the trajectory.

    Returns
    -------
    int
        Index one past the end of the first period.
    """
    crossings = np.flatnonzero(np.sign(x[1:]) != np.sign(x[:-1]))
    return crossings[1] + 2


def energy(orbit):
    """Return the energy E = y^2 / 2 - cos x along a trajectory.

    Parameters
    ----------
    orbit : dict
        Trajectory, as returned by `trajectory`.

    Returns
    -------
    ndarray
        Energy at each time of the trajectory.
    """
    return 0.5 * orbit["y"] ** 2 - np.cos(orbit["x"])


def energy_errors():
    """Return the change in energy along three trajectories.

    The trajectories start at x = 0 and use the same 1000 times and the
    default tolerances of `odeint` as the code in the post, since the
    plot shows the error of that code.

    Returns
    -------
    list of dict
        For each trajectory, the initial velocity under "y0", and the
        times and |E(t) - E(0)| under "t" and "error", without t = 0.
    """
    tspan = np.linspace(0.0, 45.0, 1000)
    errors = []
    for y0 in [0.5, 1.5, 1.95]:
        E = energy(trajectory(0.0, y0, tspan))
        errors.append(
            dict(y0=y0, t=tspan[1:], error=np.abs(E[1:] - E[0]))
        )
    return errors


def librations():
    """Return the trajectories of the second figure, started at x = 0.

    The eight with |y0| < 2 are librations. The two with y0 = +2.05 and
    -2.05 are rotations, which go over the top to the right and to the
    left.

    Returns
    -------
    list of dict
        Trajectories, as returned by `trajectory`.
    """
    x0 = 0.0
    c = np.linspace(-2.05, 2.05, 10)
    return [trajectory(x0, y0) for y0 in c]


def portrait():
    """Return the trajectories of the last figure.

    These are four rotations started from each side and ten librations
    about the origin.

    Returns
    -------
    list of dict
        Trajectories, as returned by `trajectory`.
    """
    orbits = []
    for x0, c in [
        (5.0 * np.pi, np.linspace(-2.0, -1.0, 4)),
        (-5.0 * np.pi, np.linspace(1.0, 2.0, 4)),
        (0.0, np.linspace(-1.95, 1.95, 10)),
    ]:
        orbits += [trajectory(x0, y0) for y0 in c]
    return orbits


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


def draw_orbit(ax, orbit, colours, arrows=True):
    """Draw a trajectory, with arrowheads for the direction of motion.

    A libration (x0 = 0) is a closed curve, so it gets arrowheads on its
    first period only. Librations with y0 < 0 get none, since they trace
    the same curves as those with -y0.

    Parameters
    ----------
    ax : matplotlib.axes.Axes
        Axes to draw on.
    orbit : dict
        Trajectory, as returned by `trajectory`.
    colours : dict
        Colours of the theme, from `THEMES`.
    arrows : bool, optional
        Whether to draw arrowheads.
    """
    x, y = orbit["x"], orbit["y"]
    ax.plot(
        x, y, color=colours["orbit"], lw=LOOK["orbit_width"], zorder=3
    )
    closed = orbit["x0"] == 0.0 and abs(orbit["y0"]) < 2.0
    if not arrows or (closed and orbit["y0"] < 0):
        return
    end = first_lap(x) if closed else len(x)
    draw_arrowheads(ax, x[:end], y[:end], colours["head"])


def figure_vector_field(data, colours):
    """Draw the streamlines of the vector field."""
    fig, ax = phase_plane()
    draw_flow(ax, data["field"], colours)
    return fig


def figure_librations(data, colours):
    """Draw the trajectories started at x = 0, without arrowheads."""
    fig, ax = phase_plane()
    for orbit in data["librations"]:
        draw_orbit(ax, orbit, colours, arrows=False)
    return fig


def figure_phase_portrait(data, colours):
    """Draw the streamlines with rotations and librations."""
    fig, ax = phase_plane()
    draw_flow(ax, data["field"], colours)
    for orbit in data["portrait"]:
        draw_orbit(ax, orbit, colours)
    return fig


def figure_energy(data, colours):
    """Draw the energy error on a logarithmic scale."""
    fig, ax = energy_axes()
    lines = zip(data["energy"], colours["lines"], strict=True)
    for line, colour in lines:
        label = rf"$c = {line['y0']}$"
        ax.plot(
            line["t"],
            line["error"],
            color=colour,
            lw=LOOK["orbit_width"],
            label=label,
        )
    ax.legend(loc="lower right")
    return fig


FIGURES = {
    "vector-field": figure_vector_field,
    "librations": figure_librations,
    "phase-portrait": figure_phase_portrait,
    "energy": figure_energy,
}


# --- Aesthetics -------------------------------------------------------

USETEX = True

if amore is not None:
    TEAL, RED, AMBER, SLATE = (
        amore.palette("teal"),
        amore.palette("red"),
        amore.palette("amber"),
        amore.palette("slate"),
    )
else:
    # The same colours as the amore palettes
    TEAL = dict(main="#4e9e9f")
    RED = dict(ink="#6b1d2a", main="#d2737f", light="#efc0c4")
    AMBER = dict(main="#d39b3c")
    SLATE = dict(ink="#28313d", light="#c2c9d1")

LINES = [
    TEAL["main"],
    RED["main"],
    AMBER["main"],
]  # one colour per curve of the energy plot

THEMES = {
    "light": dict(
        text=SLATE["ink"],
        flow=TEAL["main"],
        orbit=RED["main"],
        head=RED["ink"],
        lines=LINES,
    ),
    "dark": dict(
        text=SLATE["light"],
        flow=TEAL["main"],
        orbit=RED["main"],
        head=RED["light"],
        lines=LINES,
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


def energy_axes():
    """Create a figure with the logarithmic axes of the energy plot.

    Returns
    -------
    fig : matplotlib.figure.Figure
    ax : matplotlib.axes.Axes
    """
    fig, ax = plt.subplots(figsize=LOOK["size"], layout="constrained")
    ax.set_yscale("log")
    ax.set_xlim(0.0, 45.0)
    ax.set_xlabel(r"$t$")
    ax.set_ylabel(r"$|E(t) - E(0)|$")
    return fig, ax


def main(out=Path("figures")):
    """Solve the system, then save every figure in both themes.

    Parameters
    ----------
    out : pathlib.Path, optional
        Folder for the figures.
    """
    data = dict(
        field=vector_field(),
        librations=librations(),
        portrait=portrait(),
        energy=energy_errors(),
    )
    orbits = data["librations"] + data["portrait"]
    print(methods_used(orbits))
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
