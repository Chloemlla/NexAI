#!/usr/bin/env python3
"""Create the tiny JetBrains Mono subset used by NexAI.

The generated font keeps only ASCII letters, digits, spaces, and the minimal
punctuation needed by timers, dashboards, and developer logs.
"""

from __future__ import annotations

import argparse
import math
import struct
import tempfile
import urllib.request
from pathlib import Path


SOURCE_URL = (
    "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/"
    "v2.304/fonts/ttf/JetBrainsMono-Regular.ttf"
)
DEFAULT_OUTPUT = (
    "assets/fonts/jetbrains_mono/JetBrainsMonoNexAI-Regular.ttf"
)
DEFAULT_CODEPOINTS = (
    [0x0020, 0x0025, 0x002D, 0x002E]
    + list(range(0x0030, 0x003B))
    + list(range(0x0041, 0x005B))
    + [0x005F]
    + list(range(0x0061, 0x007B))
)


def u16(data: bytes, offset: int) -> int:
    return struct.unpack_from(">H", data, offset)[0]


def s16(data: bytes, offset: int) -> int:
    return struct.unpack_from(">h", data, offset)[0]


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from(">I", data, offset)[0]


def pack_u16(value: int) -> bytes:
    return struct.pack(">H", value & 0xFFFF)


def pad4(data: bytes) -> bytes:
    return data + (b"\0" * ((4 - len(data) % 4) % 4))


def checksum(data: bytes) -> int:
    padded = pad4(data)
    total = 0
    for offset in range(0, len(padded), 4):
        total = (total + u32(padded, offset)) & 0xFFFFFFFF
    return total


def read_tables(font: bytes) -> tuple[bytes, dict[str, bytes]]:
    version = font[:4]
    num_tables = u16(font, 4)
    tables: dict[str, bytes] = {}

    for index in range(num_tables):
        record_offset = 12 + index * 16
        tag = font[record_offset : record_offset + 4].decode("latin1")
        offset = u32(font, record_offset + 8)
        length = u32(font, record_offset + 12)
        tables[tag] = font[offset : offset + length]

    return version, tables


def cmap_format4_mapping(subtable: bytes, codepoints: list[int]) -> dict[int, int]:
    seg_count = u16(subtable, 6) // 2
    end_offset = 14
    start_offset = end_offset + seg_count * 2 + 2
    delta_offset = start_offset + seg_count * 2
    range_offset = delta_offset + seg_count * 2
    mapping: dict[int, int] = {}

    for codepoint in codepoints:
        for index in range(seg_count):
            end_code = u16(subtable, end_offset + index * 2)
            start_code = u16(subtable, start_offset + index * 2)
            if codepoint < start_code or codepoint > end_code:
                continue

            delta = s16(subtable, delta_offset + index * 2)
            id_range_offset = u16(subtable, range_offset + index * 2)
            if id_range_offset == 0:
                glyph_id = (codepoint + delta) & 0xFFFF
            else:
                glyph_offset = (
                    range_offset
                    + index * 2
                    + id_range_offset
                    + (codepoint - start_code) * 2
                )
                if glyph_offset + 2 > len(subtable):
                    glyph_id = 0
                else:
                    glyph_id = u16(subtable, glyph_offset)
                    if glyph_id != 0:
                        glyph_id = (glyph_id + delta) & 0xFFFF

            if glyph_id != 0:
                mapping[codepoint] = glyph_id
            break

    return mapping


def cmap_format12_mapping(subtable: bytes, codepoints: list[int]) -> dict[int, int]:
    groups = u32(subtable, 12)
    mapping: dict[int, int] = {}

    for codepoint in codepoints:
        for index in range(groups):
            offset = 16 + index * 12
            start_char = u32(subtable, offset)
            end_char = u32(subtable, offset + 4)
            start_glyph = u32(subtable, offset + 8)
            if start_char <= codepoint <= end_char:
                glyph_id = start_glyph + codepoint - start_char
                if glyph_id != 0:
                    mapping[codepoint] = glyph_id
                break

    return mapping


def parse_cmap(cmap: bytes, codepoints: list[int]) -> dict[int, int]:
    table_count = u16(cmap, 2)
    candidates: list[tuple[int, int, int, bytes]] = []

    for index in range(table_count):
        record_offset = 4 + index * 8
        platform_id = u16(cmap, record_offset)
        encoding_id = u16(cmap, record_offset + 2)
        subtable_offset = u32(cmap, record_offset + 4)
        subtable = cmap[subtable_offset:]
        fmt = u16(subtable, 0)

        score = 0
        if fmt == 12:
            score += 100
        elif fmt == 4:
            score += 50
        else:
            continue
        if platform_id == 3 and encoding_id in (1, 10):
            score += 10
        elif platform_id == 0:
            score += 5
        candidates.append((score, fmt, subtable_offset, subtable))

    if not candidates:
        raise RuntimeError("No Unicode cmap format 4 or 12 table found")

    _, fmt, _, subtable = max(candidates, key=lambda item: item[0])
    if fmt == 12:
        mapping = cmap_format12_mapping(subtable, codepoints)
        if len(mapping) == len(codepoints):
            return mapping

    return cmap_format4_mapping(subtable, codepoints)


def parse_loca(tables: dict[str, bytes], num_glyphs: int) -> list[int]:
    head = tables["head"]
    loca = tables["loca"]
    loca_format = s16(head, 50)

    if loca_format == 0:
        return [u16(loca, index * 2) * 2 for index in range(num_glyphs + 1)]
    return [u32(loca, index * 4) for index in range(num_glyphs + 1)]


def parse_hmtx(tables: dict[str, bytes], num_glyphs: int) -> list[tuple[int, int]]:
    hhea = tables["hhea"]
    hmtx = tables["hmtx"]
    metric_count = u16(hhea, 34)
    metrics: list[tuple[int, int]] = []
    last_advance = 0

    for glyph_id in range(num_glyphs):
        if glyph_id < metric_count:
            offset = glyph_id * 4
            advance = u16(hmtx, offset)
            lsb = s16(hmtx, offset + 2)
            last_advance = advance
        else:
            offset = metric_count * 4 + (glyph_id - metric_count) * 2
            advance = last_advance
            lsb = s16(hmtx, offset)
        metrics.append((advance, lsb))

    return metrics


def composite_components(glyph: bytes) -> list[int]:
    if len(glyph) < 10 or s16(glyph, 0) >= 0:
        return []

    components: list[int] = []
    offset = 10

    while offset + 4 <= len(glyph):
        flags = u16(glyph, offset)
        glyph_id = u16(glyph, offset + 2)
        components.append(glyph_id)
        offset += 4
        offset += 4 if flags & 0x0001 else 2

        if flags & 0x0008:
            offset += 2
        elif flags & 0x0040:
            offset += 4
        elif flags & 0x0080:
            offset += 8

        if not flags & 0x0020:
            break

    return components


def strip_simple_instructions(glyph: bytes) -> bytes:
    if not glyph:
        return glyph

    contour_count = s16(glyph, 0)
    if contour_count < 0:
        return glyph

    instruction_length_offset = 10 + contour_count * 2
    if instruction_length_offset + 2 > len(glyph):
        return glyph

    instruction_length = u16(glyph, instruction_length_offset)
    rest_offset = instruction_length_offset + 2 + instruction_length
    if rest_offset > len(glyph):
        return glyph

    return (
        glyph[:instruction_length_offset]
        + pack_u16(0)
        + glyph[rest_offset:]
    )


def remap_composite_glyph(glyph: bytes, old_to_new: dict[int, int]) -> bytes:
    if not glyph:
        return glyph

    if len(glyph) < 10 or s16(glyph, 0) >= 0:
        return strip_simple_instructions(glyph)

    output = bytearray(glyph[:10])
    offset = 10

    while offset + 4 <= len(glyph):
        flags = u16(glyph, offset)
        old_glyph_id = u16(glyph, offset + 2)
        arg_length = 4 if flags & 0x0001 else 2
        transform_length = 0

        if flags & 0x0008:
            transform_length = 2
        elif flags & 0x0040:
            transform_length = 4
        elif flags & 0x0080:
            transform_length = 8

        component_length = 4 + arg_length + transform_length
        if offset + component_length > len(glyph):
            return glyph

        output += pack_u16(flags & ~0x0100)
        output += pack_u16(old_to_new.get(old_glyph_id, 0))
        output += glyph[offset + 4 : offset + component_length]
        offset += component_length

        if not flags & 0x0020:
            break

    return bytes(output)


def build_cmap(codepoint_to_glyph: dict[int, int]) -> bytes:
    items = sorted(codepoint_to_glyph.items())
    segments: list[tuple[int, int, int]] = []

    if items:
        start_code, start_glyph = items[0]
        end_code = start_code
        previous_glyph = start_glyph

        for codepoint, glyph_id in items[1:]:
            if codepoint == end_code + 1 and glyph_id == previous_glyph + 1:
                end_code = codepoint
                previous_glyph = glyph_id
            else:
                segments.append((start_code, end_code, start_glyph))
                start_code = end_code = codepoint
                start_glyph = previous_glyph = glyph_id
        segments.append((start_code, end_code, start_glyph))

    seg_count = len(segments) + 1
    entry_selector = int(math.log2(2 ** int(math.log2(seg_count))))
    search_range = (2 ** entry_selector) * 2
    range_shift = seg_count * 2 - search_range
    length = 16 + seg_count * 8

    end_codes = [end for _, end, _ in segments] + [0xFFFF]
    start_codes = [start for start, _, _ in segments] + [0xFFFF]
    deltas = [
        (start_glyph - start_code) & 0xFFFF
        for start_code, _, start_glyph in segments
    ] + [1]
    range_offsets = [0] * seg_count

    subtable = bytearray(
        struct.pack(
            ">HHHHHHH",
            4,
            length,
            0,
            seg_count * 2,
            search_range,
            entry_selector,
            range_shift,
        )
    )
    subtable += b"".join(pack_u16(value) for value in end_codes)
    subtable += pack_u16(0)
    subtable += b"".join(pack_u16(value) for value in start_codes)
    subtable += b"".join(pack_u16(value) for value in deltas)
    subtable += b"".join(pack_u16(value) for value in range_offsets)

    return (
        struct.pack(">HH", 0, 1)
        + struct.pack(">HHI", 3, 1, 12)
        + bytes(subtable)
    )


def build_name_table() -> bytes:
    names = {
        1: "JetBrainsMonoNexAI",
        2: "Regular",
        4: "JetBrains Mono NexAI Regular",
        6: "JetBrainsMonoNexAI-Regular",
        16: "JetBrains Mono NexAI",
        17: "Regular",
    }
    records = []
    storage = bytearray()

    for name_id, value in sorted(names.items()):
        encoded = value.encode("utf-16-be")
        records.append((3, 1, 0x0409, name_id, len(encoded), len(storage)))
        storage += encoded

    string_offset = 6 + len(records) * 12
    header = struct.pack(">HHH", 0, len(records), string_offset)
    record_data = b"".join(
        struct.pack(">HHHHHH", *record) for record in records
    )
    return header + record_data + bytes(storage)


def build_post_table(old_post: bytes | None) -> bytes:
    if old_post and len(old_post) >= 16:
        return struct.pack(">I", 0x00030000) + old_post[4:16] + b"\0" * 16
    return struct.pack(">IIIIIIII", 0x00030000, 0, 0, 0, 0, 0, 0, 0)


def build_font(version: bytes, tables: dict[str, bytes]) -> bytes:
    tags = sorted(tables)
    num_tables = len(tags)
    entry_selector = int(math.log2(2 ** int(math.log2(num_tables))))
    search_range = (2 ** entry_selector) * 16
    range_shift = num_tables * 16 - search_range
    table_offset = 12 + num_tables * 16
    records = bytearray()
    table_data = bytearray()
    offsets: dict[str, int] = {}

    for tag in tags:
        data = tables[tag]
        padded = pad4(data)
        offset = table_offset + len(table_data)
        offsets[tag] = offset
        records += (
            tag.encode("latin1")
            + struct.pack(">III", checksum(data), offset, len(data))
        )
        table_data += padded

    font = bytearray(
        version
        + struct.pack(">HHHH", num_tables, search_range, entry_selector, range_shift)
        + records
        + table_data
    )

    head_offset = offsets["head"]
    font[head_offset + 8 : head_offset + 12] = b"\0\0\0\0"
    adjustment = (0xB1B0AFBA - checksum(bytes(font))) & 0xFFFFFFFF
    font[head_offset + 8 : head_offset + 12] = struct.pack(">I", adjustment)
    return bytes(font)


def subset_font(font: bytes, codepoints: list[int]) -> bytes:
    version, tables = read_tables(font)
    required = {"head", "hhea", "maxp", "OS/2", "hmtx", "cmap", "loca", "glyf"}
    missing_tables = sorted(required - set(tables))
    if missing_tables:
        raise RuntimeError(f"Missing required font tables: {', '.join(missing_tables)}")

    num_glyphs = u16(tables["maxp"], 4)
    cmap = parse_cmap(tables["cmap"], codepoints)
    missing_codepoints = [cp for cp in codepoints if cp not in cmap]
    if missing_codepoints:
        missing = ", ".join(f"U+{cp:04X}" for cp in missing_codepoints)
        raise RuntimeError(f"Source font does not contain required glyphs: {missing}")

    loca = parse_loca(tables, num_glyphs)
    glyph_table = tables["glyf"]
    old_glyphs = [
        glyph_table[loca[index] : loca[index + 1]] for index in range(num_glyphs)
    ]
    metrics = parse_hmtx(tables, num_glyphs)

    selected: list[int] = [0]
    for codepoint in sorted(codepoints):
        glyph_id = cmap[codepoint]
        if glyph_id not in selected:
            selected.append(glyph_id)

    index = 0
    while index < len(selected):
        glyph_id = selected[index]
        for component in composite_components(old_glyphs[glyph_id]):
            if component not in selected:
                selected.append(component)
        index += 1

    old_to_new = {old_id: new_id for new_id, old_id in enumerate(selected)}
    glyph_bytes = bytearray()
    loca_offsets = [0]

    for old_glyph_id in selected:
        new_glyph = remap_composite_glyph(old_glyphs[old_glyph_id], old_to_new)
        glyph_bytes += pad4(new_glyph)
        loca_offsets.append(len(glyph_bytes))

    new_hmtx = bytearray()
    for old_glyph_id in selected:
        advance, lsb = metrics[old_glyph_id]
        new_hmtx += struct.pack(">Hh", advance, lsb)

    head = bytearray(tables["head"])
    head[8:12] = b"\0\0\0\0"
    head[50:52] = struct.pack(">h", 1)

    hhea = bytearray(tables["hhea"])
    hhea[34:36] = pack_u16(len(selected))

    maxp = bytearray(tables["maxp"])
    maxp[4:6] = pack_u16(len(selected))

    os2 = bytearray(tables["OS/2"])
    if len(os2) >= 68:
        os2[64:66] = pack_u16(min(codepoints))
        os2[66:68] = pack_u16(max(codepoints))

    codepoint_to_new_glyph = {
        codepoint: old_to_new[glyph_id] for codepoint, glyph_id in cmap.items()
    }

    new_tables = {
        "OS/2": bytes(os2),
        "cmap": build_cmap(codepoint_to_new_glyph),
        "glyf": bytes(glyph_bytes),
        "head": bytes(head),
        "hhea": bytes(hhea),
        "hmtx": bytes(new_hmtx),
        "loca": b"".join(struct.pack(">I", offset) for offset in loca_offsets),
        "maxp": bytes(maxp),
        "name": build_name_table(),
        "post": build_post_table(tables.get("post")),
    }

    return build_font(version, new_tables)


def load_source_font(source: str | None) -> bytes:
    if source:
        return Path(source).read_bytes()

    with tempfile.TemporaryDirectory() as temp_dir:
        source_path = Path(temp_dir) / "JetBrainsMono-Regular.ttf"
        urllib.request.urlretrieve(SOURCE_URL, source_path)
        return source_path.read_bytes()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", help="Path to a local JetBrains Mono TTF")
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    parser.add_argument("--max-bytes", type=int, default=20_000)
    args = parser.parse_args()

    font = load_source_font(args.source)
    subset = subset_font(font, DEFAULT_CODEPOINTS)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(subset)

    if len(subset) > args.max_bytes:
        raise RuntimeError(
            f"Subset font is {len(subset)} bytes, exceeding {args.max_bytes}"
        )

    print(f"Wrote {output.as_posix()} ({len(subset)} bytes)")


if __name__ == "__main__":
    main()
