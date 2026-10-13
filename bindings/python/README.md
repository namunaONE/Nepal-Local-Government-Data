# nepal-admin-data

Offline administrative divisions of Nepal for Python — **7 provinces,
77 districts, 753 local bodies, 6,743 wards**, with official CBS codes,
Devanagari names, coordinates and ward counts.

Data as of **2026-10-13**. Generated from
[`data/nepal_local_levels.json`](https://github.com/namunaONE/Nepal-Local-Government-Data)
by `tool/generate_bindings.dart` — do not edit by hand.

- **Zero dependencies.** Pure standard library.
- **Bilingual.** Devanagari names for all 7 provinces, 77 districts and
  731 of 753 palikas. Never transliterated.
- Same data, same numbers and the same API shape as the Dart package
  [`nepal_admin_api`](https://pub.dev/packages/nepal_admin_api).

## Install

```bash
pip install nepal-admin-data
```

## Use

```python
import nepal_admin as nad

b = nad.get_local_body_by_cbs(31304)
b["name"]        # 'Bharatpur'
b["nameNe"]      # 'भरतपुर'

nad.get_district_by_name("Chitwan")["headquarter"]     # 'Bharatpur'
nad.get_local_body_by_full_path("Bharatpur, Chitwan, Bagmati")["name"]

# Search works in BOTH scripts, in either direction.
len(nad.search("Bharatpur")["localBodies"]) == len(nad.search("भरतपुर")["localBodies"])

# Building a code-keyed join (the common case)
by_code = {b["cbsCode"]: b for b in nad.get_local_bodies_with_code()}
len(by_code)     # 744

# With pandas, using the shipped CSV:
#   pd.read_csv("csv/local_bodies.csv")

nad.get_national_stats()
# {'provinces': 7, 'districts': 77, 'total': 753, 'wards': 6743,
#  'verified_wards': 6697, 'ward_gaps': 8, 'unreconciled_wards': 46, ...}
```

```bash
python -m nepal_admin      # print a summary
```

## Two ward totals, on purpose

`wards` is the **declared** national figure (6,743). `verified_wards` is what
the per-palika rows this package substantiates add up to (6,697). The 46-ward
difference is 8 palikas documented as roster defects — reported, not hidden.

## Data files

Also ships `csv/` for pandas, Excel, R and QGIS, and `geojson/` centroid
FeatureCollections (RFC 7946) for Folium, geojson.io and QGIS.

## License

MIT for the code. The data is CC-BY-4.0 / CC-BY derived and attributed in
[NOTICE](NOTICE). Not affiliated with the Government of Nepal.
