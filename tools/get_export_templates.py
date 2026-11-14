#!/usr/bin/env python3
"""Fetch only the Godot export templates the game needs (ROADMAP M10 part 2), for the cloud.

The template archive is 1.3 GB; this reads just the wanted files out of it over HTTP ranges and
puts them where Godot looks (~/.local/share/godot/export_templates/4.7.2.stable).

    python3 tools/get_export_templates.py            # Linux and Windows release templates
    python3 tools/get_export_templates.py --list     # what the archive holds
"""
import io, os, sys, urllib.request, zipfile
URL = "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
class Remote(io.RawIOBase):
    def __init__(self, url):
        req = urllib.request.Request(url, method="HEAD")
        r = urllib.request.urlopen(req, timeout=60)
        self.url = r.geturl(); self.size = int(r.headers["Content-Length"]); self.pos = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else (self.pos + off if whence == 1 else self.size + off); return self.pos
    def readinto(self, b):
        if self.pos >= self.size: return 0
        end = min(self.pos + len(b), self.size) - 1
        req = urllib.request.Request(self.url, headers={"Range": "bytes=%d-%d" % (self.pos, end)})
        data = urllib.request.urlopen(req, timeout=300).read()
        b[:len(data)] = data; self.pos += len(data); return len(data)

WANT = ["version.txt", "linux_release.x86_64", "windows_release_x86_64.exe", "windows_release_x86_64_console.exe"]
OUT = os.path.expanduser("~/.local/share/godot/export_templates/4.7.2.stable")


def main() -> None:
    z = zipfile.ZipFile(io.BufferedReader(Remote(URL), buffer_size=1 << 20))
    names = z.namelist()
    if "--list" in sys.argv:
        for n in names:
            print(n, z.getinfo(n).file_size)
        return
    os.makedirs(OUT, exist_ok=True)
    for w in WANT:
        target = os.path.join(OUT, w)
        if os.path.exists(target):
            continue
        n = next(x for x in names if x.endswith("/" + w))
        with z.open(n) as src, open(target, "wb") as dst:
            while True:
                chunk = src.read(1 << 22)
                if not chunk:
                    break
                dst.write(chunk)
        print("got", w, os.path.getsize(target))


if __name__ == "__main__":
    main()
