#!/usr/bin/env python3
"""
Downloads the kundenangaben OpenAPI spec and prints every leaf field path
with its type, in the form:
  kundenangaben.haushalte[].kunden[].wohnsituation.voranschrift.ort=string

Usage:
  ./list-all-field-types.sh
  ./list-all-field-types.sh [openapi-json-file]
"""

import json
import sys
import os
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

OPENAPI_FILE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    SCRIPT_DIR, "kundenangaben.json"
)

OPENAPI_URL = "https://raw.githubusercontent.com/europace/baufismart-kundenangaben-api/master/kundenangaben-openapi.json"

def download_openapi(url, dest):
    print(f"Downloading OpenAPI spec from {url} ...", file=sys.stderr)
    urllib.request.urlretrieve(url, dest)
    print(f"Saved to {dest}", file=sys.stderr)

def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def resolve_ref(spec, ref):
    parts = ref.lstrip("#/").split("/")
    node = spec
    for part in parts:
        node = node[part]
    return node

def effective_schema(spec, schema, _depth=0):
    if _depth > 30:
        return schema

    if "$ref" in schema:
        return effective_schema(spec, resolve_ref(spec, schema["$ref"]), _depth + 1)

    if "allOf" in schema:
        merged = {}
        for sub in schema["allOf"]:
            resolved = effective_schema(spec, sub, _depth + 1)
            merged.setdefault("properties", {}).update(resolved.get("properties", {}))
            if "type" not in merged and "type" in resolved:
                merged["type"] = resolved["type"]
            if "discriminator" not in merged and "discriminator" in resolved:
                merged["discriminator"] = resolved["discriminator"]
            for combiner in ("oneOf", "anyOf"):
                if combiner in resolved:
                    merged.setdefault(combiner, []).extend(resolved[combiner])
        return merged
    return schema

def type_label(current):
    if "enum" in current:
        return "enum(" + ", ".join(current["enum"]) + ")"
    if "type" in current:
        return current["type"]
    if "properties" in current or "discriminator" in current:
        return "object"
    if "oneOf" in current or "anyOf" in current:
        return "oneOf"
    return "unknown"

def walk(spec, schema, path, visited_refs, results):
    schema = effective_schema(spec, schema)

    # Collect properties from the schema itself plus all discriminator variants
    all_props = dict(schema.get("properties", {}))

    discriminator = schema.get("discriminator", {})
    for ref in discriminator.get("mapping", {}).values():
        try:
            variant = effective_schema(spec, {"$ref": ref})
            all_props.update(variant.get("properties", {}))
        except (KeyError, TypeError):
            pass

    for combiner in ("oneOf", "anyOf"):
        for alt in schema.get(combiner, []):
            try:
                alt_schema = effective_schema(spec, alt)
                all_props.update(alt_schema.get("properties", {}))
            except (KeyError, TypeError):
                pass

    for field_name, field_schema in all_props.items():
        if field_name == "@type":
            results.append(f"{path}.@type=string (discriminator)")
            continue

        resolved = effective_schema(spec, field_schema)

        # Detect arrays
        if resolved.get("type") == "array" and "items" in resolved:
            child_path = f"{path}.{field_name}[]"
            item_schema = effective_schema(spec, resolved["items"])

            # Guard against infinite recursion via $ref cycles
            ref_key = resolved["items"].get("$ref", "")
            if ref_key and ref_key in visited_refs:
                results.append(f"{child_path}=(cycle)")
                continue
            new_visited = visited_refs | ({ref_key} if ref_key else set())

            if "properties" in item_schema or "discriminator" in item_schema \
                    or "allOf" in item_schema or "oneOf" in item_schema or "anyOf" in item_schema:
                walk(spec, item_schema, child_path, new_visited, results)
            else:
                results.append(f"{child_path}={type_label(item_schema)}")
        else:
            child_path = f"{path}.{field_name}"
            ref_key = field_schema.get("$ref", "")
            if ref_key and ref_key in visited_refs:
                results.append(f"{child_path}=(cycle)")
                continue
            new_visited = visited_refs | ({ref_key} if ref_key else set())

            if "properties" in resolved or "discriminator" in resolved \
                    or "allOf" in resolved or "oneOf" in resolved or "anyOf" in resolved:
                walk(spec, resolved, child_path, new_visited, results)
            else:
                results.append(f"{child_path}={type_label(resolved)}")

def main():
    download_openapi(OPENAPI_URL, OPENAPI_FILE)
    spec = load_json(OPENAPI_FILE)

    root = effective_schema(spec, spec["components"]["schemas"]["ImportKundenangabenRequest"])

    results = []
    walk(spec, root, "", set(), results)

    for line in results:
        # strip leading dot from root path
        print(line.lstrip("."))

if __name__ == "__main__":
    main()
