# pipeline/crime_ingestion.py
"""
Crime data ingestion module.
Responsible for loading raw crime data from CSV, JSON, or in-memory dicts.
Output is always a list of raw dicts ready for the cleaner.
"""
import pandas as pd
import json
from typing import List, Dict


def load_from_csv(filepath: str) -> List[Dict]:
    """Load crime records from a CSV file. Expected columns: lat, lon, crime_type, date, severity, source."""
    df = pd.read_csv(filepath, dtype=str)  # read all as str to avoid type coercion
    return df.where(pd.notnull(df), None).to_dict(orient="records")


def load_from_json(filepath: str) -> List[Dict]:
    """Load crime records from a JSON file (array of objects)."""
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError("JSON crime file must be an array of objects.")
    return data


def load_from_records(records: List[Dict]) -> List[Dict]:
    """
    Pass-through for in-memory records (e.g. from POST /hotspots/upload).
    Returns the list unchanged — cleaning happens downstream.
    """
    return records
