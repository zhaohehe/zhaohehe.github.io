#!/usr/bin/env python3
"""
从照片里读出拍摄参数，合并进 data/photo-exif.json。

为什么用这个笨办法：
    照片上传到 R2 之后，Hugo 构建时读不到文件里的 EXIF（我们特意不让它去抓图）。
    所以在上传这一步把参数读出来、存成一个小 JSON，模板按文件名查表就行。
    这个 JSON 是纯文本，几 KB，进仓库没问题。

用法：
    ./scripts/exif.py photos-inbox/jeju-01.jpg

    默认用「源文件名去掉扩展名 + .webp」当键名，和上传脚本产出的文件名一致。
    如果源文件名和上传后的名字不一样（比如 DSC08081.jpg 传上去叫 jeju-01.webp），
    就用 键名=路径 的写法指定：

    ./scripts/exif.py jeju-01=photos-inbox/DSC08081.jpg
"""

import json
import os
import struct
import sys

TYPES = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 6: 1, 7: 1, 8: 2, 9: 4, 10: 8, 11: 4, 12: 8}


def exif_block(data):
    """从 JPEG 里抠出 EXIF（APP1 段）。"""
    if data[:2] != b"\xff\xd8":
        return None
    i = 2
    while i < len(data) - 3:
        if data[i] != 0xFF:
            return None
        marker = data[i + 1]
        if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
            i += 2
            continue
        if marker == 0xDA:
            return None
        length = struct.unpack(">H", data[i + 2:i + 4])[0]
        if marker == 0xE1 and data[i + 4:i + 10] == b"Exif\x00\x00":
            return data[i + 10:i + 2 + length]
        i += 2 + length
    return None


def read_ifd(buf, off, en):
    if off + 2 > len(buf):
        return {}
    count = struct.unpack(en + "H", buf[off:off + 2])[0]
    out = {}
    for k in range(count):
        e = off + 2 + k * 12
        if e + 12 > len(buf):
            break
        tag, typ, cnt = struct.unpack(en + "HHI", buf[e:e + 8])
        size = TYPES.get(typ, 1) * cnt
        valoff = e + 8 if size <= 4 else struct.unpack(en + "I", buf[e + 8:e + 12])[0]
        out[tag] = (typ, cnt, valoff, size)
    return out


def value(buf, entry, en):
    typ, cnt, off, size = entry
    raw = buf[off:off + size]
    try:
        if typ == 2:
            return raw.split(b"\x00")[0].decode("utf-8", "replace")
        if typ == 3:
            return list(struct.unpack(en + "%dH" % cnt, raw))
        if typ == 4:
            return list(struct.unpack(en + "%dI" % cnt, raw))
        if typ in (5, 10):
            fmt = "II" if typ == 5 else "ii"
            return [
                (lambda a, b: a / b if b else 0)(*struct.unpack(en + fmt, raw[j * 8:(j + 1) * 8]))
                for j in range(cnt)
            ]
    except struct.error:
        return None
    return raw


def first(buf, entries, tag, en):
    if tag not in entries:
        return None
    v = value(buf, entries[tag], en)
    return v[0] if isinstance(v, list) and v else v


def shoot(path):
    data = open(path, "rb").read()
    buf = exif_block(data)
    if not buf:
        return None
    en = "<" if buf[0:2] == b"II" else ">"
    ifd0 = read_ifd(buf, struct.unpack(en + "I", buf[4:8])[0], en)
    eoff = first(buf, ifd0, 0x8769, en)
    exif = read_ifd(buf, eoff, en) if eoff else {}

    make = first(buf, ifd0, 0x010F, en) or ""
    model = first(buf, ifd0, 0x0110, en) or ""
    camera = (make + " " + model).replace("SONY", "Sony").strip()

    info = {}
    if camera:
        info["camera"] = camera
    lens = first(buf, exif, 0xA434, en)
    if lens:
        info["lens"] = lens

    aperture = first(buf, exif, 0x829D, en)
    if aperture:
        info["aperture"] = "f/%.1f" % aperture

    exposure = first(buf, exif, 0x829A, en)
    if exposure:
        info["shutter"] = ("1/%ds" % round(1 / exposure)) if exposure < 1 else ("%gs" % exposure)

    iso = first(buf, exif, 0x8827, en)
    if iso:
        info["iso"] = str(iso)

    focal = first(buf, exif, 0x920A, en)
    if focal:
        info["focal"] = "%dmm" % round(focal)

    return info or None


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip())
        return 1

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    store = os.path.join(root, "data", "photo-exif.json")
    os.makedirs(os.path.dirname(store), exist_ok=True)

    table = {}
    if os.path.exists(store):
        try:
            table = json.load(open(store, encoding="utf-8"))
        except Exception:
            table = {}

    changed = 0
    for arg in argv[1:]:
        # 支持 键名=路径；没有 = 就按文件名推算键名
        if "=" in arg:
            name, path = arg.split("=", 1)
            key = name if name.endswith(".webp") else name + ".webp"
        else:
            path = arg
            key = os.path.splitext(os.path.basename(path))[0] + ".webp"

        if not os.path.isfile(path):
            print("  跳过（不是文件）: %s" % path)
            continue
        try:
            info = shoot(path)
        except Exception as err:
            print("  %-24s 读取失败: %s" % (key, err))
            continue
        if not info:
            print("  %-24s 没有 EXIF（可能被导出软件抹掉了）" % key)
            continue
        table[key] = info
        changed += 1
        bits = " ".join(filter(None, [
            info.get("focal"), info.get("aperture"), info.get("shutter"),
            ("ISO " + info["iso"]) if info.get("iso") else "",
        ]))
        print("  %-24s %s" % (key, bits))

    with open(store, "w", encoding="utf-8") as f:
        json.dump(table, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")

    print("\n  已写入 %s（共 %d 条）" % (os.path.relpath(store, root), len(table)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
