"""Offline administrative divisions of Nepal.

Data as of ``2026-10-13``. Generated from
``data/nepal_local_levels.json`` by ``tool/generate_bindings.dart``; do not
edit by hand.

    >>> import nepal_admin as nad
    >>> nad.get_local_body_by_cbs(31304).name
    'Bharatpur'

Pure standard library, no dependencies.
"""

import json
import os
from typing import Dict, List, Optional

__version__ = "2.7.1"

_DATA_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data.json")
with open(_DATA_PATH, encoding="utf-8") as _fh:
    _raw = json.load(_fh)

meta = _raw["meta"]
DATA_AS_OF = meta["dataAsOf"]

#: All 7 provinces, each with its districts nested under ``districts``.
provinces = _raw["provinces"]
#: All 77 districts, flat.
districts = _raw["districts"]
#: All 753 local bodies (palikas), flat.
local_bodies = _raw["localBodies"]

_province_by_id = {p["id"]: p for p in provinces}
_province_by_iso = {p["isoCode"].upper(): p for p in provinces if p.get("isoCode")}
_district_by_name = {d["name"].lower(): d for d in districts}
_district_by_cbs = {d["cbsCode"]: d for d in districts if d.get("cbsCode") is not None}
_local_body_by_cbs = {
    b["cbsCode"]: b for b in local_bodies if b.get("cbsCode") is not None
}

# Type aliases, so a caller can annotate without importing typing machinery.
LocalBody = Dict[str, object]
District = Dict[str, object]
Province = Dict[str, object]


# --------------------------------------------------------------------------
# Lookups. Names are matched case-insensitively.
# --------------------------------------------------------------------------

def get_province_by_id(province_id):
    """By id (``'bagmati'``) or ISO code (``'NP-P3'``), case-insensitive."""
    if not isinstance(province_id, str):
        return None
    return _province_by_id.get(province_id.lower()) or _province_by_iso.get(
        province_id.upper()
    )


def get_province_by_iso(iso):
    return _province_by_iso.get(iso.upper()) if isinstance(iso, str) else None


def get_province_by_cbs(code):
    for p in provinces:
        if p["cbsCode"] == code:
            return p
    return None


def get_all_provinces():
    return list(provinces)


def get_all_districts():
    return list(districts)


def get_all_local_bodies():
    return list(local_bodies)


def get_district_by_name(name):
    return _district_by_name.get(name.strip().lower()) if isinstance(name, str) else None


def get_district_by_cbs(code):
    return _district_by_cbs.get(code)


def get_local_bodies_by_district(district_name):
    d = get_district_by_name(district_name)
    if not d:
        return []
    return [b for b in local_bodies if b["district"] == d["name"]]


def get_local_bodies_by_province(province_id):
    p = get_province_by_id(province_id)
    if not p:
        return []
    return [b for b in local_bodies if b["province"] == p["name"]]


def get_local_bodies_by_type(body_type):
    return [b for b in local_bodies if b["type"] == body_type]


def get_local_bodies_by_name(name, district_name):
    """Disambiguates the duplicate names that make ``search`` ambiguous."""
    d = get_district_by_name(district_name)
    if not d or not isinstance(name, str):
        return []
    target = name.lower()
    return [b for b in local_bodies
            if b["district"] == d["name"] and b["name"].lower() == target]


def get_local_body_by_full_path(path):
    """Resolve ``'Bharatpur, Chitwan, Bagmati'``.

    Order-insensitive and tolerant of a partial path. Returns ``None`` when the
    path matches nothing *or* more than one body: an ambiguous answer is never
    guessed.
    """
    if not isinstance(path, str):
        return None
    parts = [p.strip().lower() for p in path.split(",") if p.strip()]
    if not parts:
        return None
    matches = []
    for b in local_bodies:
        haystack = {b["name"].lower(), b["district"].lower(), b["province"].lower()}
        if all(p in haystack for p in parts):
            matches.append(b)
    return matches[0] if len(matches) == 1 else None


def get_local_body_by_cbs(code):
    """Any confidence tier; resolves 744 of 753."""
    return _local_body_by_cbs.get(code)


def get_local_body_by_cbs_verified(code):
    """Strictly the doubly-attested tier."""
    b = _local_body_by_cbs.get(code)
    return b if b and b.get("cbsCodeVerified") else None


def get_local_bodies_with_code():
    return [b for b in local_bodies if b.get("cbsCode") is not None]


def get_verified_local_bodies():
    return [b for b in local_bodies if b.get("cbsCodeVerified")]


def get_single_source_local_bodies():
    return [b for b in local_bodies if b.get("cbsCodeConfidence") == "singleSource"]


def get_uncoded_local_bodies():
    return [b for b in local_bodies if b.get("cbsCode") is None]


# --------------------------------------------------------------------------
# Search. Matches BOTH scripts in either direction.
# --------------------------------------------------------------------------

def _hit(value, term):
    return isinstance(value, str) and term in value.lower()


def search(query):
    """Case-insensitive search across provinces, districts and local bodies.

    Matches both scripts, so ``search('भरतपुर')`` and ``search('Bharatpur')``
    return the same palika.

    Returns a dict with ``provinces``, ``districts`` and ``localBodies`` keys.
    """
    term = query.strip().lower() if isinstance(query, str) else ""
    if not term:
        return {"provinces": [], "districts": [], "localBodies": []}
    return {
        "provinces": [
            p for p in provinces
            if _hit(p.get("name"), term) or _hit(p.get("nameNe"), term) or _hit(p.get("isoCode"), term)
        ],
        "districts": [d for d in districts if _hit(d.get("name"), term) or _hit(d.get("nameNe"), term)],
        "localBodies": [
            b for b in local_bodies
            if _hit(b.get("name"), term) or _hit(b.get("nameNe"), term)
            or term in "{} , {}, {}".format(b["name"], b["district"], b["province"]).lower()
        ],
    }


# --------------------------------------------------------------------------
# Computed totals.
#
# ``wards`` is the declared national total; ``verified_wards`` is what the
# per-palika rows substantiate. They differ because 8 palikas carry no verified
# ward count. Both are reported rather than one silently shadowing the other.
# --------------------------------------------------------------------------

def get_national_stats():
    def count(t):
        return sum(1 for b in local_bodies if b["type"] == t)

    verified_wards = sum(b.get("wards") or 0 for b in local_bodies)
    declared_wards = sum(p["wards"] for p in provinces)
    return {
        "provinces": len(provinces),
        "districts": len(districts),
        "metro": count("metropolitan"),
        "sub_metro": count("subMetropolitan"),
        "municipalities": count("municipality"),
        "rural_municipalities": count("ruralMunicipality"),
        "total": len(local_bodies),
        "wards": declared_wards,
        "verified_wards": verified_wards,
        "ward_gaps": sum(1 for b in local_bodies if b.get("wards") is None),
        "unreconciled_wards": declared_wards - verified_wards,
    }


def get_province_stats(province_id):
    """Per-province ward reconciliation, mirroring the Dart API."""
    p = get_province_by_id(province_id)
    if not p:
        return None
    bodies = get_local_bodies_by_province(p["id"])
    verified = sum(b.get("wards") or 0 for b in bodies)
    out = dict(p)
    out["verified_wards"] = verified
    out["unreconciled_wards"] = p["wards"] - verified
    out["wards_reconcile"] = p["wards"] == verified
    return out


def get_mappable_local_bodies():
    """The joinable, plottable subset: has a code AND a coordinate."""
    return [
        b for b in local_bodies
        if b.get("cbsCode") is not None and b.get("lat") is not None and b.get("lng") is not None
    ]


__all__ = [
    "meta", "DATA_AS_OF", "provinces", "districts", "local_bodies",
    "get_province_by_id", "get_province_by_iso", "get_province_by_cbs",
    "get_all_provinces", "get_all_districts", "get_all_local_bodies",
    "get_district_by_name", "get_district_by_cbs",
    "get_local_bodies_by_district", "get_local_bodies_by_province",
    "get_local_bodies_by_type", "get_local_bodies_by_name",
    "get_local_body_by_full_path", "get_local_body_by_cbs",
    "get_local_body_by_cbs_verified", "get_local_bodies_with_code",
    "get_verified_local_bodies", "get_single_source_local_bodies",
    "get_uncoded_local_bodies", "get_mappable_local_bodies",
    "get_national_stats", "get_province_stats", "search",
]
