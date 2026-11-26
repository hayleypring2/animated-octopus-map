# Draw the frames of the animated octopus map from export/*.csv. Run from the project folder: python3 animation/run_parallel.py
import os
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager
from matplotlib.colors import to_rgb
from matplotlib.path import Path

HERE = os.path.dirname(os.path.abspath(__file__))
EXP = os.path.join(HERE, "..", "export")
OUT = os.path.join(HERE, "frames")
os.makedirs(OUT, exist_ok=True)

FPS = 20
W, H, DPI = 12.0, 6.32, 100

# Use the first of these fonts that is installed
INSTALLED = {f.name for f in font_manager.fontManager.ttflist}
plt.rcParams["font.family"] = next((f for f in ["Arial", "Liberation Sans"] if f in INSTALLED), "DejaVu Sans")

# ---- Read the exported flows ----
col = dict(pd.read_csv(f"{EXP}/colours.csv").values)
world = pd.read_csv(f"{EXP}/world.csv")
crude = pd.read_csv(f"{EXP}/crude_paths.csv")
refined = pd.read_csv(f"{EXP}/refined_paths.csv")
suppliers = pd.read_csv(f"{EXP}/suppliers.csv")
sources = pd.read_csv(f"{EXP}/sources.csv")
locations = pd.read_csv(f"{EXP}/locations.csv")
shares = pd.read_csv(f"{EXP}/source_shares.csv").set_index("source")["share_pct"]

SRC_COL = {"Persian Gulf": col["red"], "United States": col["yellow"],
           "Russia": col["darkred"], "Other": col["grey3"]}
ORANGE, AUS = col["orange"], col["darkorange"]
AUS_XY = (134, -24)

# Line width rises in a straight line with volume, as scale_linewidth() does in R
ml_all = np.concatenate([crude.ML.values, refined.ML.values])
ML_MIN, ML_MAX = ml_all.min(), ml_all.max()
def lw(ml):
    return 0.9 + (ml - ML_MIN) / (ML_MAX - ML_MIN) * (14.0 - 0.9)

# ---- Timeline, in seconds ----
T_REFINED = 0.8            # refined lines start growing
SOURCE_ORDER = ["Persian Gulf", "United States", "Russia", "Other"]
T_CRUDE = {"Persian Gulf": 4.6, "United States": 7.0, "Russia": 8.5, "Other": 9.8}
T_FLOW = 11.6              # barrels start moving
T_GULF = 14.2              # crude from outside the Gulf fades back
T_FADE = 18.4              # the map fades out
T_END = 19.4
GROW = 1.3                 # time one line takes to grow
STAGGER = 0.16             # delay between one line and the next

# Smooth step from 0 to 1
def ease(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)

# Progress from 0 to 1 of a change that starts at t0 and lasts dur
def ramp(t, t0, dur):
    return ease((t - t0) / dur)

# ---- Build the flows ----
# Refined fuel bought straight from the Gulf appears with the Gulf crude
flows = []
ref_order = refined.groupby("supplier").ML.first().sort_values(ascending=False)
i = 0
for sup, ml in ref_order.items():
    xy = refined.loc[refined.supplier == sup, ["x", "y"]].values
    if sup == "Persian Gulf":
        start = T_CRUDE["Persian Gulf"] + 0.9
    else:
        start = T_REFINED + i * STAGGER * 1.4
        i += 1
    flows.append(dict(xy=xy, colour=ORANGE, ml=ml, start=start, kind="refined", source=None, sup=sup))

for src in SOURCE_ORDER:
    g = crude[crude.source == src]
    order = g.groupby("group").ML.first().sort_values(ascending=False)
    for j, (grp, ml) in enumerate(order.items()):
        xy = g.loc[g.group == grp, ["x", "y"]].values
        flows.append(dict(xy=xy, colour=SRC_COL[src], ml=ml, start=T_CRUDE[src] + j * STAGGER,
                          kind="crude", source=src, sup=grp))

# Draw crude under refined and thick lines before thin ones, as on the static map
flows.sort(key=lambda f: (f["kind"] == "refined", -f["ml"]))

# Distance along each line
for f in flows:
    seg = np.sqrt((np.diff(f["xy"], axis=0) ** 2).sum(1))
    f["cum"] = np.concatenate([[0], np.cumsum(seg)])

# The first part of a line, up to a fraction of its length
def partial(f, frac):
    if frac >= 1:
        return f["xy"]
    cum, xy = f["cum"], f["xy"]
    L = cum[-1] * frac
    k = np.searchsorted(cum, L)
    k = max(k, 1)
    r = (L - cum[k - 1]) / (cum[k] - cum[k - 1])
    tip = xy[k - 1] + r * (xy[k] - xy[k - 1])
    return np.vstack([xy[:k], tip])

def darken(c, amt):
    return tuple(np.array(to_rgb(c)) * (1 - amt))

def lighten(c, amt):
    r = np.array(to_rgb(c))
    return tuple(r + (1 - r) * amt)

# ---- Barrel marker ----
# A drum with bulging sides and two hoops
side = [(0.35, 0.5), (0.41, 0.25), (0.43, 0.0), (0.41, -0.25), (0.35, -0.5)]
verts = side + [(-x, y) for x, y in reversed(side)] + [(0.35, 0.5)]
codes = [Path.MOVETO] + [Path.LINETO] * (len(verts) - 2) + [Path.CLOSEPOLY]
for yh in (0.2, -0.2):
    verts += [(-0.42, yh), (0.42, yh)]
    codes += [Path.MOVETO, Path.LINETO]
BARREL = Path(verts, codes)
BARREL_SPEED = 60.0       # pixels per second
BARREL_K = 480_000        # gap between barrels in pixels is BARREL_K / ML

# ---- Labels ----
SUP_LABEL_T = {f["sup"]: f["start"] + 0.35 for f in flows if f["kind"] == "refined"}
SRC_LABELS = {
    "Persian Gulf": dict(x=42, y=19, ha="left", va="top", fmt="Crude from the\nPersian Gulf {}%", bg=True),
    "Russia": dict(x=43, y=61, ha="left", va="center", fmt="Crude from Russia {}%", bg=True),
    "United States": dict(x=273, y=35, ha="right", va="bottom", fmt="Crude from the US {}%", bg=True),
    "Other": dict(x=49, y=-38.5, ha="left", va="center", fmt="All other countries {}%", bg=False),
}
SOURCE_NOTE = ("Source: Grattan analysis of DCCEEW (2026), Australian Petroleum Statistics; UN Comtrade (2026). "
               "2025. Line width shows volume; flows under 150 ML not shown.")

# ---- Draw the base map ----
fig = plt.figure(figsize=(W, H), dpi=DPI)
fig.patch.set_facecolor("white")
ax = fig.add_axes([0.0, 0.055, 1.0, 0.94])
ax.set_xlim(40, 275); ax.set_ylim(-42, 64)
ax.set_aspect(1.1, adjustable="datalim")
ax.axis("off")

for _, g in world.groupby("group"):
    ax.fill(g.long, g.lat, facecolor=col["grey1"], edgecolor="white", linewidth=0.3, zorder=0)

# Measure each line in pixels, so barrels move at the same speed everywhere on screen
fig.canvas.draw()
for f in flows:
    disp = ax.transData.transform(f["xy"])
    f["pix"] = np.concatenate([[0], np.cumsum(np.sqrt((np.diff(disp, axis=0) ** 2).sum(1)))])
    f["gap"] = float(np.clip(BARREL_K / f["ml"], 34, 460))

fig.text(0.02, 0.025, SOURCE_NOTE, fontsize=9, color=col["grey4"], va="bottom")

# Everything drawn for one frame, removed before the next
dynamic = []
def add(a):
    dynamic.append(a)
    return a

def label_box(a):
    return dict(boxstyle="round,pad=0.25,rounding_size=0.15", fc=(1, 1, 1, 0.8 * a), ec="none")

# ---- Draw one frame ----
def render(t, fname):
    for a in dynamic:
        a.remove()
    dynamic.clear()

    fade = 1 - ramp(t, T_FADE, T_END - T_FADE - 0.15)
    flowing = t >= T_FLOW
    gulf_focus = ramp(t, T_GULF, 0.8) * (1 - ramp(t, T_FADE - 0.6, 0.6))

    # Lines
    for f in flows:
        frac = ramp(t, f["start"], GROW)
        if frac <= 0:
            continue
        alpha = fade
        if f["kind"] == "crude" and f["source"] != "Persian Gulf":
            alpha *= 1 - 0.75 * gulf_focus
        if alpha <= 0.01:
            continue
        w = lw(f["ml"])
        xy = partial(f, frac)
        z = 3 if f["kind"] == "refined" else 2
        add(ax.plot(xy[:, 0], xy[:, 1], color=f["colour"], lw=w, alpha=alpha,
                    solid_capstyle="butt", solid_joinstyle="round", zorder=z)[0])

        # Barrels, which fade in and out at each end of the line
        if flowing and frac >= 1:
            gap = f["gap"]
            offset = ((t - T_FLOW) * BARREL_SPEED) % gap
            d = np.arange(offset, f["pix"][-1], gap)
            bx = np.interp(d, f["pix"], f["xy"][:, 0])
            by = np.interp(d, f["pix"], f["xy"][:, 1])
            edge = np.minimum(d, f["pix"][-1] - d)
            ba = alpha * ramp(t, T_FLOW, 0.5)
            ms = np.clip(9 + w * 0.4, 9.5, 14)
            for x, y, e in zip(bx, by, edge):
                barrel_alpha = ba * np.clip(e / 14, 0, 1)
                if barrel_alpha > 0.02:
                    add(ax.plot([x], [y], ls="none", marker=BARREL, ms=ms, mfc=lighten(f["colour"], 0.8),
                                mec=darken(f["colour"], 0.35), mew=0.9, alpha=barrel_alpha, zorder=z + 0.5)[0])

    # Dots for the suppliers, the crude sources and Australia
    pa = fade
    add(ax.scatter(locations.lon, locations.lat, s=22, color=col["grey4"], zorder=5, alpha=pa,
                   linewidths=0))
    for _, s in sources.iterrows():
        a = ramp(t, T_CRUDE[s.source] - 0.3, 0.3) * fade
        if a > 0:
            add(ax.scatter([s.src_lon], [s.src_lat], s=110, color=SRC_COL[s.source], edgecolor="white",
                           linewidths=1.2, zorder=6, alpha=a))
    pulse = 1 + 0.12 * np.sin(2 * np.pi * t / 1.2) if flowing else 1
    add(ax.scatter([AUS_XY[0]], [AUS_XY[1]], s=260 * pulse * ramp(t, 0, 0.5), color=AUS, zorder=7,
                   alpha=pa, linewidths=0))
    add(ax.text(141, -28, "Australia", fontsize=15, color=AUS, ha="center", va="center", zorder=8,
                alpha=pa))

    # Supplier labels
    for _, s in suppliers.iterrows():
        a = ramp(t, SUP_LABEL_T[s.supplier], 0.35) * fade
        if a > 0.01:
            ha = {0: "left", 1: "right", 0.5: "center"}[s.hj]
            add(ax.text(s.lx, s.ly, f"{s.supplier} {int(np.floor(s.share + 0.5))}%", fontsize=13,
                        color=col["black"], ha=ha, va="center", zorder=9, alpha=a, bbox=label_box(a)))
    a = ramp(t, T_CRUDE["Other"] + 0.4, 0.35) * fade
    if a > 0.01:
        add(ax.text(109, 12.5, "Vietnam", fontsize=13, color=col["black"], ha="left", va="center",
                    zorder=9, alpha=a, bbox=label_box(a)))
    a = ramp(t, T_REFINED + 1.0, 0.4) * (1 - ramp(t, T_CRUDE["Persian Gulf"] - 0.8, 0.4))
    if a > 0.01:
        add(ax.text(150, 6.5, "Refined fuel\nimports", fontsize=14, color=ORANGE, ha="left",
                    va="center", alpha=a, zorder=9, linespacing=0.95))

    # Crude source labels, with each share counting up as its lines grow
    for src, L in SRC_LABELS.items():
        t0 = T_CRUDE[src]
        a = ramp(t, t0 - 0.2, 0.35) * fade
        if a <= 0.01:
            continue
        val = shares[src] * ramp(t, t0, GROW + 0.6)
        txt = L["fmt"].format(int(np.floor(val + 0.5)))
        big = src == "Persian Gulf"
        size = 15 + (5 * gulf_focus if big else 0)
        add(ax.text(L["x"], L["y"], txt, fontsize=size, color=SRC_COL[src], ha=L["ha"], va=L["va"],
                    zorder=10, alpha=a, linespacing=0.95, fontweight="bold" if big and gulf_focus > 0.5 else "normal",
                    bbox=label_box(a) if L["bg"] else None))

    fig.savefig(fname, dpi=DPI, facecolor="white")


# ---- Run ----
# Give times in seconds to draw previews, or nothing to draw every frame
if __name__ == "__main__":
    only = [float(x) for x in sys.argv[1:]]
    if only:
        for t in only:
            render(t, os.path.join(HERE, f"preview_{t:05.2f}.png"))
    else:
        for k in range(int(round(T_END * FPS))):
            render(k / FPS, os.path.join(OUT, f"f{k:04d}.png"))
