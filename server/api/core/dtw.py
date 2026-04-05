"""Full-matrix Dynamic Time Warping — exact port of dtw.dart.

Uses the same O(n*m) algorithm as the client for score parity.
"""

from dataclasses import dataclass

import numpy as np

from .pose_math import pose_distance


@dataclass
class DtwResult:
    distance: float
    normalized_distance: float
    warping_path: list[tuple[int, int]]


def compute_dtw(
    ref_frames: list[np.ndarray],
    user_frames: list[np.ndarray],
    dist_fn=None,
) -> DtwResult:
    """Compute DTW between two lists of normalized pose frames.

    Args:
        ref_frames: List of (33, 4) numpy arrays for the reference.
        user_frames: List of (33, 4) numpy arrays for the user.
        dist_fn: Optional distance function (frame, frame) -> float.
                 Defaults to pose_distance.

    Returns:
        DtwResult with distance, normalized distance, and warping path.
    """
    if dist_fn is None:
        dist_fn = pose_distance

    n = len(ref_frames)
    m = len(user_frames)

    if n == 0 or m == 0:
        return DtwResult(
            distance=float("inf"),
            normalized_distance=float("inf"),
            warping_path=[],
        )

    # Build full cost matrix.
    cost = np.zeros((n, m), dtype=np.float64)

    cost[0, 0] = dist_fn(ref_frames[0], user_frames[0])

    # First column.
    for i in range(1, n):
        cost[i, 0] = cost[i - 1, 0] + dist_fn(ref_frames[i], user_frames[0])

    # First row.
    for j in range(1, m):
        cost[0, j] = cost[0, j - 1] + dist_fn(ref_frames[0], user_frames[j])

    # Fill the rest.
    for i in range(1, n):
        for j in range(1, m):
            d = dist_fn(ref_frames[i], user_frames[j])
            cost[i, j] = d + min(cost[i - 1, j], cost[i, j - 1], cost[i - 1, j - 1])

    # Backtrack to find optimal warping path.
    path: list[tuple[int, int]] = []
    i, j = n - 1, m - 1
    path.append((i, j))

    while i > 0 or j > 0:
        if i == 0:
            j -= 1
        elif j == 0:
            i -= 1
        else:
            diag = cost[i - 1, j - 1]
            left = cost[i, j - 1]
            up = cost[i - 1, j]

            if diag <= left and diag <= up:
                i -= 1
                j -= 1
            elif up <= left:
                i -= 1
            else:
                j -= 1
        path.append((i, j))

    # Path was built end-to-start; reverse it.
    path.reverse()
    total_distance = float(cost[n - 1, m - 1])

    return DtwResult(
        distance=total_distance,
        normalized_distance=total_distance / len(path),
        warping_path=path,
    )
