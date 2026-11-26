# Draw every frame of the animation on all processor cores. Run from the project folder: python3 animation/run_parallel.py
import os
from multiprocessing import Pool

import octopus_animate as oa

N_FRAMES = int(round(oa.T_END * oa.FPS))


def draw_frame(k):
    oa.render(k / oa.FPS, os.path.join(oa.OUT, f"f{k:04d}.png"))


if __name__ == "__main__":
    with Pool(os.cpu_count()) as pool:
        pool.map(draw_frame, range(N_FRAMES), chunksize=4)
