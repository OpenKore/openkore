#!/usr/bin/env python3
"""Runtime simulation for same-map portal traversal in MapRoute.

Simulates the route sequence reported by the user:
  moc_para0b -> moc_para0b -> moc_para0b -> prontera -> payon

The simulation mirrors the same-map detection rules implemented in Task::MapRoute:
- Prefer map == dest_map when present.
- Fallback to parsing the portal string (from=to) when dest_map is missing.
"""

from __future__ import annotations


def is_same_map_portal_step(step: dict) -> bool:
    if step.get("dest_map") is not None and step.get("map") is not None:
        return step.get("map") == step.get("dest_map")

    # Fallback when either map/dest_map metadata is incomplete.
    portal = step.get("portal")
    if not portal or "=" not in portal:
        return False

    left, right = portal.split("=", 1)
    left_parts = left.split()
    right_parts = right.split()
    if not left_parts or not right_parts:
        return False

    return left_parts[0] == right_parts[0]


def run_simulation() -> None:
    # Mirrors the same route shape seen in logs.
    map_solution = [
        {"portal": "moc_para0b 179 90=moc_para0b 41 185"},
        {"portal": "moc_para0b 41 187=moc_para0b 179 93"},
        {"portal": "moc_para0b 47 161=moc_para0b 47 18"},
        {"portal": "moc_para0b 30 10=prontera 116 72"},
        {"portal": "prontera 146 89=payon 161 58"},
    ]

    # Metadata-incomplete step should still be recognized via portal parsing.
    assert is_same_map_portal_step({
        "dest_map": "moc_para0b",
        "portal": "moc_para0b 179 90=moc_para0b 41 185",
    })

    flags = [is_same_map_portal_step(step) for step in map_solution]
    expected_flags = [True, True, True, False, False]
    assert flags == expected_flags, (
        f"same-map flags mismatch: expected {expected_flags}, got {flags}"
    )

    # Simulate "find first inter-map portal" loop in MapRoute teleport flow.
    selected = None
    for step in map_solution:
        selected = step
        if not is_same_map_portal_step(step):
            break

    assert selected is not None
    assert selected["portal"] == "moc_para0b 30 10=prontera 116 72", (
        "MapRoute selected the wrong target portal after same-map steps: "
        f"{selected['portal']}"
    )

    # Simulate three same-map mapChanged events finishing each Route segment.
    queue = map_solution.copy()
    for i in range(3):
        assert is_same_map_portal_step(queue[0]), f"step {i} should be same-map"
        # mapChanged hook behavior for same-map: finish current subtask, advance to next step.
        queue.pop(0)

    # After 3 same-map warps, next step should be inter-map to prontera.
    assert queue[0]["portal"] == "moc_para0b 30 10=prontera 116 72"
    assert not is_same_map_portal_step(queue[0])

    # Then prontera -> payon should also be inter-map.
    assert queue[1]["portal"] == "prontera 146 89=payon 161 58"
    assert not is_same_map_portal_step(queue[1])

    print("OK: simulation passed for moc_para0b -> moc_para0b -> moc_para0b -> prontera -> payon")


if __name__ == "__main__":
    run_simulation()
