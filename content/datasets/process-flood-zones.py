#!/usr/bin/env python3
"""Process Environment Agency flood zone shapefiles into simplified GeoJSON.

Reads Flood Zone 2 and 3 shapefiles, reprojects to WGS84, simplifies
geometry to reduce file size, and outputs a single GeoJSON file with
zone classification.

Requires: GDAL Python bindings (osgeo) or falls back to ogr2ogr subprocess.
"""

import argparse
import glob
import json
import os
import subprocess
import sys
import tempfile


def find_shapefile(directory):
    """Find the first .shp file in a directory tree."""
    for root, _, files in os.walk(directory):
        for f in files:
            if f.endswith(".shp"):
                return os.path.join(root, f)
    return None


def convert_shp_to_geojson(shp_path, output_path, zone_label, tolerance=0.001):
    """Convert shapefile to simplified GeoJSON using ogr2ogr."""
    cmd = [
        "ogr2ogr",
        "-f", "GeoJSON",
        output_path,
        shp_path,
        "-t_srs", "EPSG:4326",
        "-simplify", str(tolerance),
        "-lco", "COORDINATE_PRECISION=5",
    ]
    subprocess.run(cmd, check=True, capture_output=True)

    with open(output_path, "r") as f:
        data = json.load(f)

    for feature in data.get("features", []):
        feature["properties"] = {"zone": zone_label}

    with open(output_path, "w") as f:
        json.dump(data, f)

    return len(data.get("features", []))


def merge_geojson(files, output_path):
    """Merge multiple GeoJSON files into one FeatureCollection."""
    merged = {
        "type": "FeatureCollection",
        "features": [],
    }
    for path in files:
        with open(path, "r") as f:
            data = json.load(f)
            merged["features"].extend(data.get("features", []))

    with open(output_path, "w") as f:
        json.dump(merged, f)

    return len(merged["features"])


def main():
    parser = argparse.ArgumentParser(description="Process EA flood zone data")
    parser.add_argument("--fz2-dir", required=True, help="Directory containing Flood Zone 2 shapefiles")
    parser.add_argument("--fz3-dir", required=True, help="Directory containing Flood Zone 3 shapefiles")
    parser.add_argument("--output", required=True, help="Output GeoJSON path")
    parser.add_argument("--tolerance", type=float, default=0.001,
                        help="Simplification tolerance in degrees (default: 0.001 ≈ 100m)")
    args = parser.parse_args()

    fz2_shp = find_shapefile(args.fz2_dir)
    fz3_shp = find_shapefile(args.fz3_dir)

    if not fz2_shp:
        print(f"ERROR: No .shp file found in {args.fz2_dir}", file=sys.stderr)
        sys.exit(1)
    if not fz3_shp:
        print(f"ERROR: No .shp file found in {args.fz3_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"  FZ2 shapefile: {fz2_shp}")
    print(f"  FZ3 shapefile: {fz3_shp}")

    with tempfile.TemporaryDirectory() as tmpdir:
        fz2_json = os.path.join(tmpdir, "fz2.geojson")
        fz3_json = os.path.join(tmpdir, "fz3.geojson")

        print("  Converting Flood Zone 2...")
        n2 = convert_shp_to_geojson(fz2_shp, fz2_json, "FZ2", args.tolerance)
        print(f"    {n2} features")

        print("  Converting Flood Zone 3...")
        n3 = convert_shp_to_geojson(fz3_shp, fz3_json, "FZ3", args.tolerance)
        print(f"    {n3} features")

        print("  Merging...")
        total = merge_geojson([fz2_json, fz3_json], args.output)
        print(f"  Total: {total} features → {args.output}")


if __name__ == "__main__":
    main()
