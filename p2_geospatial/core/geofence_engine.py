"""
geofence_engine.py
------------------
Determines whether a user's current location is OUTSIDE, APPROACHING,
or INSIDE any hotspot.

This module is completely stateless — call check_geofence() every time
P1 sends a new coordinate.  It does NOT care whether the coordinate
came from GPS or PDR; both are just (lat, lon).
"""

import math
from dataclasses import dataclass


# ─── Geo-fence distance thresholds (metres) ──────────────────────────────────
INSIDE_RADIUS_M      = 150   # < 150 m  → INSIDE
APPROACHING_RADIUS_M = 300   # 150–300 m → APPROACHING
                              # > 300 m  → OUTSIDE


# ─────────────────────────────────────────────────────────────────────────────
# Distance formula
# ─────────────────────────────────────────────────────────────────────────────

def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Return the great-circle distance in metres between two (lat, lon) points.

    Uses the Haversine formula — accurate enough for < 10 km distances.
    """
    R = 6_371_000  # Earth radius in metres

    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)

    a = (math.sin(dphi / 2) ** 2 +
         math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2)

    return R * 2 * math.asin(math.sqrt(a))


# ─────────────────────────────────────────────────────────────────────────────
# Geo-fence result dataclass
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class GeofenceEvent:
    """
    Emitted whenever the user's state relative to a hotspot changes
    (or is first determined).

    Fields:
        state              — "INSIDE" | "APPROACHING" | "OUTSIDE"
        hotspot_id         — e.g. "H0012", or None if state is OUTSIDE
        risk               — "HIGH" | "MEDIUM" | "LOW" | None
        reported_incidents — int or None
        distance_m         — nearest relevant hotspot distance in metres
        location_source    — "GPS" | "PDR" | "UNKNOWN" (pass through from P1)
    """
    state:               str
    hotspot_id:          str | None
    risk:                str | None
    reported_incidents:  int | None
    distance_m:          float
    location_source:     str = "UNKNOWN"

    def to_dict(self) -> dict:
        return {
            "geofence_state":      self.state,
            "hotspot_id":          self.hotspot_id,
            "risk":                self.risk,
            "reported_incidents":  self.reported_incidents,
            "distance_m":          round(self.distance_m, 1),
            "location_source":     self.location_source,
        }


# ─────────────────────────────────────────────────────────────────────────────
# Main check function
# ─────────────────────────────────────────────────────────────────────────────

def check_geofence(
    user_lat: float,
    user_lon: float,
    hotspots: list[dict],
    location_source: str = "UNKNOWN",
    only_risks: list[str] | None = None,
) -> GeofenceEvent:
    """
    Compare the user's position against every hotspot and return
    the most critical GeofenceEvent.

    Parameters
    ----------
    user_lat / user_lon
        Current position from P1 (GPS or PDR — we don't distinguish).
    hotspots
        List of hotspot dicts (as produced by hotspot_engine.to_hotspot_list).
    location_source
        Pass P1's "source" field through for transparency in the event.
    only_risks
        Optional filter, e.g. ["HIGH"] to ignore LOW/MEDIUM hotspots.

    Returns
    -------
    GeofenceEvent with the MOST CRITICAL state found.
    Priority: INSIDE > APPROACHING > OUTSIDE
    If multiple hotspots qualify at the same level, the closest one is returned.
    """
    if only_risks is None:
        only_risks = ["HIGH", "MEDIUM"]   # ignore LOW by default

    best_inside      : tuple[float, dict] | None = None
    best_approaching : tuple[float, dict] | None = None
    nearest_distance : float = float("inf")

    for hotspot in hotspots:
        if hotspot["risk"] not in only_risks:
            continue

        dist = haversine(user_lat, user_lon,
                         hotspot["center_lat"], hotspot["center_lon"])

        nearest_distance = min(nearest_distance, dist)

        if dist <= INSIDE_RADIUS_M:
            if best_inside is None or dist < best_inside[0]:
                best_inside = (dist, hotspot)
        elif dist <= APPROACHING_RADIUS_M:
            if best_approaching is None or dist < best_approaching[0]:
                best_approaching = (dist, hotspot)

    # ── Return the most critical event found ──────────────────────────────
    if best_inside:
        dist, h = best_inside
        return GeofenceEvent(
            state               = "INSIDE",
            hotspot_id          = h["id"],
            risk                = h["risk"],
            reported_incidents  = h["reported_incidents"],
            distance_m          = dist,
            location_source     = location_source,
        )

    if best_approaching:
        dist, h = best_approaching
        return GeofenceEvent(
            state               = "APPROACHING",
            hotspot_id          = h["id"],
            risk                = h["risk"],
            reported_incidents  = h["reported_incidents"],
            distance_m          = dist,
            location_source     = location_source,
        )

    return GeofenceEvent(
        state               = "OUTSIDE",
        hotspot_id          = None,
        risk                = None,
        reported_incidents  = None,
        distance_m          = nearest_distance if nearest_distance != float("inf") else -1,
        location_source     = location_source,
    )
