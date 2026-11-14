#!/usr/bin/env python3
"""Download the game's CC0 sounds and music and turn them into assets/audio (ROADMAP M10, part 1).

Every file the game plays comes from the SOURCES table below: where it is from, who made it,
its licence and how it is processed. The script downloads each source once into a cache folder
(outside the repository), cuts and levels the sound with ffmpeg and writes Ogg Vorbis files into
assets/audio, then rewrites assets/audio/CREDITS.md from the same table.

    python3 tools/audio/prepare_audio.py --cache <folder>   # needs ffmpeg, curl and py7zr

Processing kinds:
    hit    one short sound (a blow): mono, leading silence cut, peak at -1 dBFS, at most 1.2 s
    shot   a longer one-shot (a wave, a bleat): mono or stereo as given, peak at -1 dBFS
    loop   a background bed: stereo, the end crossfaded into the start so it loops without a seam
    loop60 the same from the opening minute of a long recording
    music  a piece of music: stereo, loudness levelled to -16 LUFS
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio"
OGA = "https://opengameart.org/sites/default/files/"
BSB = "https://bigsoundbank.com/"

# Source packs: key -> (page, author, licence, download: a file name on OpenGameArt or a full URL).
PACKS: dict[str, tuple[str, str, str, str]] = {
    "wood_metal": ("https://opengameart.org/content/100-cc0-metal-and-wood-sfx", "rubberduck", "CC0",
                   "100-CC0-wood-metal-SFX.zip"),
    "rpg": ("https://opengameart.org/content/80-cc0-rpg-sfx", "rubberduck", "CC0", "80-CC0-RPG-SFX_0.zip"),
    "smith": ("https://opengameart.org/content/blacksmiths-hammer", "vishwajai", "CC0", "blacksmithhammer.wav"),
    "rock": ("https://opengameart.org/content/breaking-rock", "themightyglider", "CC0", "rock_break_0.ogg"),
    "sheep": ("https://opengameart.org/content/sheep-baa", "antumdeluge", "CC0", "sheep_baa_0.ogg"),
    "birds": ("https://opengameart.org/content/forest-bird-sounds", "pauliuw", "CC0", "forest_birds.7z"),
    "birds_bed": ("https://opengameart.org/content/ambient-bird-sounds", "isaiah658", "CC0", "birds-isaiah658_0.ogg"),
    "river": ("https://opengameart.org/content/sea-and-river-wave-sounds", "RandomMind", "CC0", "VistulaShort_0.mp3"),
    "gull1": ("https://opengameart.org/content/solo-seagull-sound-effects", "rango-mango", "CC0",
              "Seagull%20Ambient%201.wav"),
    "gull3": ("https://opengameart.org/content/solo-seagull-sound-effects", "rango-mango", "CC0",
              "Seagull%20Ambient%203.wav"),
    "wave1": ("https://opengameart.org/content/beach-ocean-waves", "jasinski (shared by qubodup)", "CC0",
              "wave_01_cc0-18363__jasinski__alkaibeach.flac"),
    "wave2": ("https://opengameart.org/content/beach-ocean-waves", "jasinski (shared by qubodup)", "CC0",
              "wave_02_cc0-18363__jasinski__alkaibeach.flac"),
    "wave3": ("https://opengameart.org/content/beach-ocean-waves", "jasinski (shared by qubodup)", "CC0",
              "wave_03_cc0-18363__jasinski__alkaibeach.flac"),
    "wave4": ("https://opengameart.org/content/beach-ocean-waves", "jasinski (shared by qubodup)", "CC0",
              "wave_04_cc0-18363__jasinski__alkaibeach.flac"),
    "market_day": ("https://opengameart.org/content/medieval-market-day", "RandomMind", "CC0", "Market_Day.wav"),
    # Music, round 2 (owner's choice 2026-11-14).
    "harvest_season": ("https://opengameart.org/content/medieval-harvest-season", "RandomMind", "CC0", "harvestseason.wav"),
    "exploration": ("https://opengameart.org/content/medieval-exploration", "RandomMind", "CC0", "Exploration.wav"),
    "kings_feast": ("https://opengameart.org/content/medieval-kings-feast", "RandomMind", "CC0", "Kings_Feast_0.mp3"),
    "minstrel_dance": ("https://opengameart.org/content/medieval-minstrel-dance", "RandomMind", "CC0",
                       "Minstrel_Dance_0.mp3"),
    "bards_tale": ("https://opengameart.org/content/medieval-the-bards-tale", "RandomMind", "CC0", "The_Bards_Tale.mp3"),
    "old_tower_inn": ("https://opengameart.org/content/medieval-the-old-tower-inn", "RandomMind", "CC0",
                      "The_Old_Tower_Inn.mp3"),
    "rejoicing": ("https://opengameart.org/content/medieval-rejoicing", "RandomMind", "CC0", "Rejoicing_0.mp3"),
    "flute_strings": ("https://opengameart.org/content/minimalistic-flute-strings-tune", "Spring Spring", "CC0",
                      "ff_2.ogg"),
    "at_home": ("https://opengameart.org/content/at-home-orchestral", "Wolfgang", "CC0", "cinematic-calm.wav"),
    "beautiful_forest": ("https://opengameart.org/content/beautiful-forest-orchestra", "nene", "CC0",
                         "beautiful_forest_16bit_44.1khz_1.ogg"),
    # Town hubbub and village sounds from BigSoundBank (Joseph Sardin, CC0; owner's choice 2026-11-14).
    "walla": (BSB + "walla-group-averages-discussions-s0684.html", "Joseph Sardin (BigSoundBank)", "CC0",
              BSB + "UPLOAD/bwf-en/0684.wav"),
    "rooster": (BSB + "rooster-s0104.html", "Joseph Sardin (BigSoundBank)", "CC0", BSB + "UPLOAD/bwf-en/0104.wav"),
    "cock": (BSB + "cock-song-1-s0440.html", "Joseph Sardin (BigSoundBank)", "CC0", BSB + "UPLOAD/bwf-en/0440.wav"),
    "henhouse": (BSB + "henhouse-s0282.html", "Joseph Sardin (BigSoundBank)", "CC0", BSB + "UPLOAD/bwf-en/0282.wav"),
    "dogs": (BSB + "2-dogs-barking-s0868.html", "Joseph Sardin (BigSoundBank)", "CC0", BSB + "UPLOAD/bwf-en/0868.wav"),
    "bell": (BSB + "1-church-bell-s0830.html", "Joseph Sardin (BigSoundBank)", "CC0", BSB + "UPLOAD/bwf-en/0830.wav"),
    "goats": (BSB + "small-herd-of-goats-s0821.html", "Joseph Sardin (BigSoundBank)", "CC0",
              BSB + "UPLOAD/bwf-en/0821.wav"),
    "barrow": (BSB + "squeaky-wheelbarrow-1-s2516.html", "Joseph Sardin (BigSoundBank)", "CC0",
               BSB + "UPLOAD/flac/2516.flac"),
}

# Target (under assets/audio) -> (pack, file inside the pack or "" for the download itself, kind, gain dB)
# and optionally a cut of the source made first: {"start": s, "len": s, "lowpass": Hz}.
SOURCES: dict[str, tuple] = {
    # An axe biting into a trunk (woodcutter).
    "sfx/work/axe_1.ogg": ("wood_metal", "wood_hit_03.ogg", "hit", 0.0),
    "sfx/work/axe_2.ogg": ("wood_metal", "wood_hit_04.ogg", "hit", 0.0),
    "sfx/work/axe_3.ogg": ("wood_metal", "wood_hit_07.ogg", "hit", 0.0),
    "sfx/work/axe_4.ogg": ("wood_metal", "wood_hit_08.ogg", "hit", 0.0),
    "sfx/work/axe_5.ogg": ("wood_metal", "wood_hit_09.ogg", "hit", 0.0),
    # A hammer on timber (builders, shipwrights).
    "sfx/work/wood_hammer_1.ogg": ("wood_metal", "wood_hammer_01.ogg", "hit", 0.0),
    "sfx/work/wood_hammer_2.ogg": ("wood_metal", "wood_hammer_02.ogg", "hit", 0.0),
    "sfx/work/wood_hammer_3.ogg": ("wood_metal", "hammer_02.ogg", "hit", 0.0),
    "sfx/work/wood_hammer_4.ogg": ("wood_metal", "hammer_03.ogg", "hit", 0.0),
    # A hammer on the anvil (smiths, armourer).
    "sfx/work/anvil_1.ogg": ("wood_metal", "metal_hit_01.ogg", "hit", 0.0),
    "sfx/work/anvil_2.ogg": ("wood_metal", "metal_hit_02.ogg", "hit", 0.0),
    "sfx/work/anvil_3.ogg": ("wood_metal", "metal_hit_04.ogg", "hit", 0.0),
    "sfx/work/anvil_4.ogg": ("smith", "", "hit", 0.0),
    # A pick or chisel on stone (quarrymen, stonecutters, miners).
    "sfx/work/stone_1.ogg": ("rock", "", "hit", 0.0),
    "sfx/work/stone_2.ogg": ("rpg", "stones_04.ogg", "hit", 0.0),
    "sfx/work/stone_3.ogg": ("rpg", "item_stone_03.ogg", "hit", 0.0),
    "sfx/work/stone_4.ogg": ("rpg", "item_stone_04.ogg", "hit", 0.0),
    # A spade in earth and gravel (clay diggers, planting).
    "sfx/work/dig_1.ogg": ("rpg", "stones_01.ogg", "hit", 0.0),
    "sfx/work/dig_2.ogg": ("rpg", "stones_02.ogg", "hit", 0.0),
    # Sheep at the shearing.
    "sfx/animals/sheep_1.ogg": ("sheep", "", "shot", 0.0),
    # Background beds and scattered sounds.
    "ambience/forest_bed.ogg": ("birds_bed", "", "loop", 0.0),
    "ambience/water_bed.ogg": ("river", "", "loop60", 0.0),
    # Town: people talking (a walla group, softened as from a distance) and village sounds over it.
    "ambience/town_bed.ogg": ("walla", "", "loop", 0.0, {"start": 10, "len": 60, "lowpass": 6000}),
    "ambience/rooster_1.ogg": ("rooster", "", "shot", 0.0, {"start": 1.5, "len": 2.5}),
    "ambience/rooster_2.ogg": ("cock", "", "shot", 0.0, {"start": 0, "len": 2.2}),
    "ambience/hens_1.ogg": ("henhouse", "", "shot", 0.0, {"start": 0, "len": 8.6}),
    "ambience/hens_2.ogg": ("henhouse", "", "shot", 0.0, {"start": 9.2, "len": 6.5}),
    "ambience/dogs_1.ogg": ("dogs", "", "shot", 0.0, {"start": 2.05, "len": 3.5}),
    "ambience/dogs_2.ogg": ("dogs", "", "shot", 0.0, {"start": 9.6, "len": 2.2}),
    "ambience/bell_1.ogg": ("bell", "", "shot", -3.0, {"start": 0, "len": 9}),
    "ambience/goats_1.ogg": ("goats", "", "shot", 0.0, {"start": 10, "len": 8}),
    "ambience/barrow_1.ogg": ("barrow", "", "shot", 0.0, {"start": 2, "len": 4}),
    "ambience/wave_1.ogg": ("wave1", "", "shot", 0.0),
    "ambience/wave_2.ogg": ("wave2", "", "shot", 0.0),
    "ambience/wave_3.ogg": ("wave3", "", "shot", 0.0),
    "ambience/wave_4.ogg": ("wave4", "", "shot", 0.0),
    "ambience/bird_1.ogg": ("birds", "Forest Birds/Forest Birds 3.wav", "shot", 0.0),
    "ambience/bird_2.ogg": ("birds", "Forest Birds/Forest Birds 6.wav", "shot", 0.0),
    "ambience/bird_3.ogg": ("birds", "Forest Birds/Forest Birds 7.wav", "shot", 0.0),
    "ambience/bird_4.ogg": ("birds", "Forest Birds/Forest Birds 9.wav", "shot", 0.0),
    "ambience/gull_1.ogg": ("gull1", "", "shot", 0.0),
    "ambience/gull_2.ogg": ("gull3", "", "shot", 0.0),
    # Music.
    "music/market_day.ogg": ("market_day", "", "music", 0.0),
    "music/harvest_season.ogg": ("harvest_season", "", "music", 0.0),
    "music/exploration.ogg": ("exploration", "", "music", 0.0),
    "music/kings_feast.ogg": ("kings_feast", "", "music", 0.0),
    "music/minstrel_dance.ogg": ("minstrel_dance", "", "music", 0.0),
    "music/bards_tale.ogg": ("bards_tale", "", "music", 0.0),
    "music/old_tower_inn.ogg": ("old_tower_inn", "", "music", 0.0),
    "music/rejoicing.ogg": ("rejoicing", "", "music", 0.0),
    "music/flute_strings.ogg": ("flute_strings", "", "music", 0.0),
    "music/at_home.ogg": ("at_home", "", "music", 0.0),
    "music/beautiful_forest.ogg": ("beautiful_forest", "", "music", 0.0),
}

LOOP_FADE = 3.0


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit("command failed: %s\n%s" % (" ".join(cmd), result.stderr[-2000:]))
    return result.stdout + result.stderr


def fetch(cache: Path, pack: str) -> Path:
    name = PACKS[pack][3]
    url = name if name.startswith("http") else OGA + name
    local = (pack + "_" + name.rsplit("/", 1)[1]) if name.startswith("http") else name
    path = cache / "downloads" / local.replace("%20", "_")
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        run(["curl", "-sSfL", "--max-time", "300", "-o", str(path), url])
    return path


def cut(cache: Path, src: Path, target: str, opts: dict) -> Path:
    """The part of [src] given by [opts] (start, len, lowpass), faded in and out, as a WAV in the cache."""
    out = cache / "cuts" / (target.replace("/", "_") + ".wav")
    out.parent.mkdir(parents=True, exist_ok=True)
    length = float(opts["len"])
    filters = ["afade=t=in:d=0.05", "afade=t=out:st=%.3f:d=0.4" % max(length - 0.4, 0.05)]
    if "lowpass" in opts:
        filters.insert(0, "lowpass=f=%d" % opts["lowpass"])
    run(["ffmpeg", "-y", "-loglevel", "error", "-ss", str(opts.get("start", 0)), "-t", str(length), "-i", str(src),
         "-af", ",".join(filters), "-c:a", "pcm_s24le", str(out)])
    return out


def unpack(cache: Path, pack: str, inner: str) -> Path:
    archive = fetch(cache, pack)
    if inner == "":
        return archive
    folder = cache / "unpacked" / pack
    if not folder.exists():
        folder.mkdir(parents=True)
        if archive.suffix == ".zip":
            with zipfile.ZipFile(archive) as z:
                z.extractall(folder)
        else:
            import py7zr
            with py7zr.SevenZipFile(archive) as z:
                z.extractall(folder)
    matches = [p for p in folder.rglob("*") if p.as_posix().endswith(inner)]
    if not matches:
        sys.exit("%s: no %s in the pack" % (pack, inner))
    return sorted(matches)[0]


def duration(path: Path) -> float:
    out = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)])
    return float(out.strip().splitlines()[0])


def peak_gain(path: Path, filters: str) -> float:
    """Gain in dB that brings the peak of [path] after [filters] to -1 dBFS."""
    out = run(["ffmpeg", "-nostats", "-i", str(path), "-af", filters + ",volumedetect", "-f", "null", "-"])
    for line in out.splitlines():
        if "max_volume:" in line:
            return -1.0 - float(line.split("max_volume:")[1].split()[0])
    return 0.0


def encode(src: Path, dst: Path, kind: str, gain: float) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    ogg = ["-c:a", "libvorbis", "-q:a", "5", "-ar", "44100", "-map_metadata", "-1"]
    if kind == "hit":
        trim = "silenceremove=start_periods=1:start_threshold=-45dB,atrim=0:1.2,afade=t=out:st=1.1:d=0.1"
        g = peak_gain(src, trim) + gain
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-af", "%s,volume=%.2fdB" % (trim, g),
             "-ac", "1", *ogg, str(dst)])
    elif kind == "shot":
        trim = "silenceremove=start_periods=1:start_threshold=-50dB"
        g = peak_gain(src, trim) + gain
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-af", "%s,volume=%.2fdB" % (trim, g),
             *ogg, str(dst)])
    elif kind in ("loop", "loop60"):
        # body = [F, L-F]; tail = [L-F, L] crossfaded into head = [0, F]. Played in a loop the
        # file ends with the opening seconds, so it runs on into the body without a seam.
        # "loop60" first keeps only the opening minute of a long recording.
        length = min(duration(src), 60.0) if kind == "loop60" else duration(src)
        f = LOOP_FADE
        work = dst.parent / ("_" + dst.stem)
        work.mkdir(exist_ok=True)
        wav = ["-ar", "44100", "-ac", "2", "-c:a", "pcm_s16le"]

        def cut(name: str, start: float, end: float) -> Path:
            out = work / name
            run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-af",
                 "atrim=%.3f:%.3f,asetpts=PTS-STARTPTS" % (start, end), *wav, str(out)])
            return out

        body = cut("body.wav", f, length - f)
        tail = cut("tail.wav", length - f, length)
        head = cut("head.wav", 0.0, f)
        seam = work / "seam.wav"
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(tail), "-i", str(head), "-filter_complex",
             "[0:a][1:a]acrossfade=d=%.3f:c1=tri:c2=tri[o]" % (f - 0.01), "-map", "[o]", *wav, str(seam)])
        joined = work / "joined.wav"
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(body), "-i", str(seam), "-filter_complex",
             "[0:a][1:a]concat=n=2:v=0:a=1[o]", "-map", "[o]", *wav, str(joined)])
        g = peak_gain(joined, "anull") + gain
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(joined), "-af", "volume=%.2fdB" % g, *ogg, str(dst)])
        for p in work.iterdir():
            p.unlink()
        work.rmdir()
    elif kind == "music":
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-af",
             "loudnorm=I=-16:TP=-1.5:LRA=11,volume=%.2fdB" % gain, "-ac", "2", *ogg, str(dst)])
    else:
        sys.exit("unknown kind " + kind)


def write_credits() -> None:
    lines = [
        "# Dźwięki i muzyka: autorzy i licencje",
        "",
        "Plik tworzy `tools/audio/prepare_audio.py` z tej samej tabeli, z której robi pliki. Nie edytuj ręcznie.",
        "Źródła: OpenGameArt (opengameart.org) i BigSoundBank (Joseph Sardin, bigsoundbank.com).",
        "Wszystkie nagrania są na licencji CC0 (domena publiczna): wolno ich używać, zmieniać i sprzedawać bez",
        "zgody i podpisu. Autorów i tak wymieniamy z wdzięczności.",
        "",
        "| Plik | Źródło | Autor | Licencja | Oryginał |",
        "|---|---|---|---|---|",
    ]
    for target, (pack, inner, *_rest) in SOURCES.items():
        page, author, licence, name = PACKS[pack]
        original = inner if inner != "" else name
        lines.append("| `%s` | %s | %s | %s | `%s` |" % (target, page, author, licence, original))
    (OUT / "CREDITS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--cache", required=True, help="folder for downloads (outside the repository)")
    parser.add_argument("--only", nargs="*", default=[], help="targets to rebuild (default: all)")
    args = parser.parse_args()
    cache = Path(args.cache).resolve()
    for target, (pack, inner, kind, gain, *rest) in SOURCES.items():
        if args.only and target not in args.only:
            continue
        src = unpack(cache, pack, inner)
        if rest:
            src = cut(cache, src, target, rest[0])
        encode(src, OUT / target, kind, gain)
        print("%-34s %5.2f s" % (target, duration(OUT / target)))
    write_credits()


if __name__ == "__main__":
    main()
