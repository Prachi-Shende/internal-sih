"""
places_service.py
-----------------
Fetches nearby safe places using the 100% free OpenStreetMap Overpass API.
Includes an offline caching fallback mechanism for resilience during GPS/Internet failure demos.
"""

import os
import json
import requests
from pathlib import Path

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
CACHE_FILE = Path(os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "cached_safe_places.json"))

def get_nearby_safe_places(lat: float, lon: float, radius_m: int = 1500, max_per_type: int = 5) -> list[dict]:
    """
    Finds police stations, hospitals, and hotels near a given coordinate.
    If the internet fails, it falls back to the locally cached JSON.
    """
    query = f"""
    [out:json];
    (
      node["amenity"="police"](around:{radius_m},{lat},{lon});
      node["amenity"="hospital"](around:{radius_m},{lat},{lon});
      node["tourism"="hotel"](around:{radius_m},{lat},{lon});
    );
    out center 20; 
    """
    
    try:
        # Try fetching live from the internet
        resp = requests.post(OVERPASS_URL, data={'data': query}, timeout=5)
        resp.raise_for_status()
        data = resp.json()
        
        safe_places = []
        for element in data.get('elements', []):
            tags = element.get('tags', {})
            if tags.get('amenity') == 'police':
                place_type = 'police'
            elif tags.get('amenity') == 'hospital':
                place_type = 'hospital'
            elif tags.get('tourism') == 'hotel':
                place_type = 'hotel'
            else:
                continue
                
            place_lat = element.get('lat') or element.get('center', {}).get('lat')
            place_lon = element.get('lon') or element.get('center', {}).get('lon')
            name = tags.get('name', f'Unnamed {place_type.capitalize()}')
            
            if place_lat and place_lon:
                safe_places.append({
                    "id": str(element.get('id', 'N/A')),
                    "name": name,
                    "type": place_type,
                    "lat": place_lat,          # Expected by static/index.html UI
                    "lon": place_lon,          # Expected by static/index.html UI
                    "latitude": place_lat,     # Expected by P3 backend
                    "longitude": place_lon,    # Expected by P3 backend
                    "open_now": True,
                    "vicinity": "OpenStreetMap",
                })
                
        # Update our offline cache if we successfully retrieved places
        if safe_places:
            os.makedirs(CACHE_FILE.parent, exist_ok=True)
            with open(CACHE_FILE, 'w') as f:
                json.dump(safe_places, f)
            print(f"[places] Fetched {len(safe_places)} live places from Overpass API and updated offline cache.")
            
        return safe_places

    except Exception as e:
        print(f"[places] Error fetching from Overpass API (Internet disconnected?): {e}")
        
        # --- The Hackathon Offline Fallback Trick ---
        if CACHE_FILE.exists():
            print("[places] ⚠️ INTERNET OFF: Falling back to local offline cache!")
            try:
                with open(CACHE_FILE, 'r') as f:
                    cached_places = json.load(f)
                    return cached_places
            except Exception as cache_e:
                print(f"[places] Error reading offline cache: {cache_e}")
                
        print("[places] No cache available, returning emergency mock fallback data.")
        return _mock_safe_places(lat, lon)


def _mock_safe_places(lat: float, lon: float) -> list[dict]:
    """Last resort hardcoded data if no cache exists during offline mode."""
    offsets = [
        ("Mumbai Police Station",      "police",    0.003,  0.002),
        ("KEM Hospital",               "hospital",  -0.002, 0.004),
        ("Trident Hotel",              "hotel",     0.001, -0.003),
    ]
    return [
        {
            "id":         f"MOCK_{i}",
            "name":       name,
            "type":       ptype,
            "lat":        round(lat + dlat, 6),
            "lon":        round(lon + dlon, 6),
            "latitude":   round(lat + dlat, 6),
            "longitude":  round(lon + dlon, 6),
            "open_now":   True,
            "vicinity":   "Emergency Fallback",
        }
        for i, (name, ptype, dlat, dlon) in enumerate(offsets)
    ]
