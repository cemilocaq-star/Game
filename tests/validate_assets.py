"""Verify binary glTF framing and the local resources referenced by its document."""
import json
from pathlib import Path
import struct
from urllib.parse import unquote

PROJECT = Path(__file__).resolve().parents[1]


def validate_glb(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data)
    if (magic, version, length) != (b"glTF", 2, len(data)):
        raise ValueError("invalid GLB header")
    offset = 12
    chunks = {}
    while offset < length:
        size, kind = struct.unpack_from("<I4s", data, offset)
        offset += 8
        if size % 4 or offset + size > length or kind in chunks:
            raise ValueError("invalid GLB chunk")
        chunks[kind] = data[offset:offset + size]
        offset += size
    if next(iter(chunks), None) != b"JSON":
        raise ValueError("first chunk must be JSON")
    asset = json.loads(chunks[b"JSON"])
    buffer_sizes = []
    for index, buffer in enumerate(asset.get("buffers", [])):
        declared = buffer["byteLength"]
        if "uri" in buffer:
            if buffer["uri"].startswith("data:"):
                # Embedded data URIs will be decoded by the Godot import test.
                available = declared
            else:
                available = (path.parent / unquote(buffer["uri"])).stat().st_size
        elif index == 0:
            available = len(chunks.get(b"BIN\x00", b""))
        else:
            raise ValueError("unresolved buffer")
        if declared < 0 or declared > available:
            raise ValueError("buffer length exceeds storage")
        buffer_sizes.append(declared)
    for view in asset.get("bufferViews", []):
        start, size = view.get("byteOffset", 0), view["byteLength"]
        if start < 0 or size <= 0 or start + size > buffer_sizes[view["buffer"]]:
            raise ValueError("buffer view points outside its buffer")
    for image in asset.get("images", []):
        uri = image.get("uri")
        if uri and not uri.startswith("data:") and not (path.parent / unquote(uri)).is_file():
            raise ValueError(f"missing image {uri}")
    accessors = asset.get("accessors", [])
    for mesh in asset.get("meshes", []):
        for primitive in mesh["primitives"]:
            position = accessors[primitive["attributes"]["POSITION"]]
            if position["type"] != "VEC3" or position["count"] <= 0:
                raise ValueError("primitive has no usable positions")
            for semantic, slot in primitive["attributes"].items():
                if accessors[slot]["count"] != position["count"]:
                    raise ValueError(f"attribute {semantic} has a mismatched count")
            if "indices" in primitive and accessors[primitive["indices"]]["type"] != "SCALAR":
                raise ValueError("primitive indices must be scalar")


def main():
    files = sorted((PROJECT / "assets").rglob("*.glb"))
    if not files:
        raise SystemExit("No GLB assets found")
    errors = []
    for path in files:
        try:
            validate_glb(path)
        except (ValueError, OSError, struct.error, KeyError, IndexError) as error:
            errors.append(f"{path.relative_to(PROJECT)}: {error}")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"PASS: GLB framing, buffer ranges, image paths and mesh attribute counts for {len(files)} assets")


if __name__ == "__main__":
    main()
