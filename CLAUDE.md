# Your Kingdom

Strategia 2D w izometrii (Godot 4.7, GDScript), inspirowana Twierdzą i Anno. Gra ma dwie warstwy: mapę królestwa z prowincjami oraz widok prowincji, w którym toczy się właściwa rozgrywka ekonomiczna i militarna. Najważniejsza jest immersja: każdy mieszkaniec wykonuje widoczną pracę, a towary są fizycznie noszone i składowane.

## Dokumenty

| Dokument | Zawartość |
|---|---|
| [docs/GDD.md](docs/GDD.md) | projekt gry: mechaniki, ekonomia, zakres |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | architektura techniczna i decyzje z uzasadnieniem |
| [docs/ROADMAP.md](docs/ROADMAP.md) | etapy prac, kryteria ukończenia, ryzyka, co odłożone |
| [docs/ART_SPEC.md](docs/ART_SPEC.md) | skala, animacje, nazwy plików, przepływ pracy z PixelLab |
| [docs/IDEAS.md](docs/IDEAS.md) | poczekalnia niezatwierdzonych pomysłów |
| [docs/HISTORY.md](docs/HISTORY.md) | dawne notatki etapów: polecenia zrzutów, fixtur, pomiarów i grafik |

**Stan (2026-11-12):** pakiet ekonomii w kolejności właściciela: E2 „Jedzenie na start i nowe potrzeby” → E3 „Cechy prowincji” → E4 „Badania i koszary” → dopiero potem G3 „Stare grafiki ze SpriteKiln”. **E2:** części 1 (sad) i 2 (myśliwy, dzikie stada) zaakceptowane; część 3 (dieta 1/2/3, punkty z progiem 60/85, podatek za nadwyżkę, buźki nad domami i pasek w panelu, zapis bez zmian v37) zaakceptowana („Jest super!”, ROADMAP, E2, „Część 3, stan”); część 4 (władcy i osady neutralne stawiają sad i myśliwego, automatyczny gracz testów z myśliwym i wcześniejszym łańcuchem patrycjuszy: 4 domy w 72./70./67. minucie z 90) gotowa; części 1–4 scalone do `main` 2026-11-11 na prośbę właściciela, część 4 przed oceną (ROADMAP, E2, „Część 4, stan”); pomiary `src/prototype/e2/patrician_probe.gd -- --map=<mapa>`, `settle_probe.gd -- --minutes=90`. **E3 „Cechy prowincji”** (plan zaakceptowany 2026-11-11): część 1 (cecha „bogata w kamień”, odkrywka ze SpriteKiln) scalona do `main` 2026-11-11 na prośbę właściciela, czeka na ocenę na laptopie; część 2 (głęboka kopalnia żelaza ze SpriteKiln, 3 górników, wieża szybu) i część 3 (losowe światy rozdają „bogatą w kamień”, władcy, osady i automatyczny gracz stawiają odkrywkę i głęboką kopalnię) oraz część 4 (żyzna ziemia +50% plonu, bogata w zwierzynę: 1,5× stad i odradzanie 2×; w „Królestwie” Wierzbowa Dolina i Lustrzane Jeziora) scalone do `main` 2026-11-11 na prośbę właściciela; cały E3 czeka na ocenę (ROADMAP, E3); pomiar `src/prototype/e3/traits_probe.gd -- [--all_rich] [--all_iron] [--all_fertile] [--all_game] [--scenario=islands] [--minutes=150]`. **E4 „Szkoła, uniwersytet, badania oraz koszary”:** plan z ankiet 2026-11-11 w ROADMAP (E4), start 2026-11-11 (poprawek z ocen E3 brak); część 1 (tryb deweloperski: pole w „Nowej grze”, F12, pełny skarbiec, budowa od razu i za darmo, wieczna ochrona mieszkańców, zapis v38) scalona do `main` 2026-11-11 na prośbę właściciela, czeka na ocenę; zrzut `game_shot.tscn -- --shot=<plik> --dev`. Część 2 (szkoła ze SpriteKiln po pierwszym domu mieszczan, 11 badań szkoły, okno „Badania” z drzewkiem, kłódki w menu budowy, zapis v39) scalona do `main` 2026-11-11 na prośbę właściciela, czeka na ocenę; zrzuty `game_shot.tscn -- --shot=<plik> --research` (okno) i `--plain --tile=48,56 --focus=43,53 --zoom=3 --yards=school --fields_seconds=25` (szkoła). Część 3 (uniwersytet 4×4 ze SpriteKiln, 2 uczonych, 11 badań uniwersytetu, „Kamieniarstwo obronne” w szkole, blokady jednostek i murów, „Nadanie”, zapis v40) scalona do `main` 2026-11-11, czeka na ocenę; zrzut `--plain --tile=48,56 --focus=45,54 --zoom=2 --yards=university --fields_seconds=30`. Część 4 (małe koszary 2×2 od startu, duże 5×5 ze SpriteKiln za badaniem „Duże koszary”, musztra na dziedzińcu, dawne koszary poza menu, zapis v41) scalona do `main` 2026-11-11 na prośbę właściciela, czeka na ocenę; zrzut `game_shot.tscn -- --shot=<plik> --m7=barracks --drill --zoom=2`. Część 5 (władcy badają: własne badania, szkoła i uniwersytet bez patrycjuszy w ich planie, kolejność według trudności, rezerwa 150 zł; osady znają to, co stoi; „Najazd” z badaniami wojska; automatyczni gracze badają; **szkoła od startu gry**; zapis v42) scalona do `main` 2026-11-12 na prośbę właściciela, czeka na ocenę (ROADMAP, E4, „Część 5, stan”); pomiary `src/prototype/e4/world_probe.gd -- [--difficulty=2 --rulers=3]`, `src/prototype/e2/patrician_probe.gd -- --map=<mapa> [--open]`. **G3 „Stare grafiki ze SpriteKiln”:** plan z ankiety 2026-11-12 w ROADMAP (G3) zaakceptowany: najpierw mieszkańcy, wspólne ruchy pracy z narzędziem zawodu, budynki z PixelLab też, mury, bramy i wieże zostają. Część 1 (pilot: wspólny model mieszkańca, tragarz, rolnik, budowniczy, punkt noszenia z modelu, ART_SPEC §10.27) scalona do `main` 2026-11-13 na prośbę właściciela, czeka na ocenę; zrzut `src/prototype/g3/folk_shot.tscn -- --shot=<plik> --id=porter|farmer|builder`. Część 2a (17 zawodów surowców i rolnictwa, 13 nowych ruchów, 8 narzędzi) scalona do `main` 2026-11-13 na prośbę właściciela, czeka na ocenę (ROADMAP, G3, „Część 2a, stan”). Część 2b (25 zawodów rzemiosła i miasta, suknie i długie szaty, 17 nowych ruchów, 10 narzędzi, bandyci jako bure odmiany pikiniera i łucznika; od teraz cała ludność ze SpriteKiln) scalona do `main` 2026-11-13 na prośbę właściciela, czeka na ocenę (ROADMAP, G3, „Część 2b, stan”). **UI-2 „Poprawki właściciela”** (ankieta 2026-11-13: osobny etap teraz, przed częścią 3 G3; ROADMAP, UI-2): część 1 błędy i wygoda budowania, część 2 start kolonii i stosy, część 3 nowa gra z podglądem świata. Potem G3 część 3 (warsztaty i surowce). **Czekają na ocenę na laptopie:** M8, Z1 (i starsze M7, B1, W1, J1), poprawki z ocen mają pierwszeństwo. Stan każdego etapu: ROADMAP; dawne notatki i **polecenia zrzutów, fixtur i pomiarów**: [docs/HISTORY.md](docs/HISTORY.md).

**Zrzuty i próby bieżącego etapu:** odkrywka `game_shot.tscn -- --shot=<plik> --plain --tile=48,56 --focus=43,55 --zoom=3 --yards=stone_pit --fields_seconds=7|13` (głęboka kopalnia: `--yards=deep_mine --fields_seconds=2|25|29`); `town_shot.tscn -- --shot=<plik> --minutes=40 --select=hut --zoom=1 --moods` (buźki i panel domu), `game_shot.tscn -- --shot=<plik> --map=lakeland --tile=26,56 --zoom=3 --yards=hunter_lodge --fields_seconds=3|22` (myśliwy), `--plain --tile=48,56 --focus=44,56 --zoom=2 --yards=orchard,farm --fields_seconds=175|240` (sad); próby `src/prototype/e2/settle_probe.gd` (wyprawy władców), `patrician_probe.gd -- --map=<id>` (patrycjusze automatycznego gracza). Zrzuty w chmurze: `xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 src/prototype/<…>.tscn -- --shot=<plik> …` (w `game_shot` i `town_shot` to `--shot=`, w `world_shot` i `menu_shot` `--out=`).

**Grafiki:** nowe ze SpriteKiln (ART_SPEC §10.20–10.21, mieszkańcy §10.27: `gen_civilians.py`, `export_civilian.py`, ściąga `tools/spritekiln/AGENT_NOTES.md`; `pip install spritekiln numba`), reszta po staremu. **Po `tools/generate_art.gd` przywróć ręczne i SpriteKiln-owe budynki:** `git checkout assets/buildings/{pioneer_camp,hut,woodcutter,quarry,fishing_hut}/ assets/buildings/{pigsty,sheep_farm,apiary,stone_pit,deep_mine,school,university,barracks_small,barracks_large}/base.*` (i sprawdź `git status assets/buildings`: cofnij każdy budynek ze SpriteKiln, którego nie zmieniałeś).

## Polecenia

Godot 4.7.2 nie jest w PATH. Skąd go wziąć:
- **Laptop właściciela (Windows):** `C:\Godot_v4.7.2-stable_win64.exe` to **folder**, a w nim są pliki wykonywalne. W Git Bash używaj wersji `_console`.
- **Chmura (Linux):** hook `SessionStart` ustawia `$GODOT` sam. Jeśli go brak: `GODOT="$(tools/setup_godot.sh)"`. Konfiguracja środowiska: [docs/CLOUD_SETUP.md](docs/CLOUD_SETUP.md). W chmurze nie ma ekranu ani karty graficznej: benchmarków i oceny „na oko” nie robimy, prosimy o nie właściciela projektu na laptopie.

```bash
GODOT="/c/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"   # tylko Windows
"$GODOT" --path .                                                   # uruchomienie gry
"$GODOT" --headless --path . --import                               # reimport zasobów i cache klas
tools/run_tests.sh                                                  # szybkie testy w 4 Godotach naraz (ok. 2 min), przed każdym commitem
tools/run_tests.sh --long                                           # długie testy równolegle (ok. 10 min), przed scaleniem do main
tools/run_tests.sh --all                                            # oba poziomy naraz
tools/run_tests.sh -a res://tests/long/<suite>.gd                    # jeden zestaw; dokładny pomiar szybkości (równolegle limit x2)
"$GODOT" --headless --path . -s res://tools/generate_placeholders.gd   # generowanie placeholderów
"$GODOT" --headless --path . -s res://tools/generate_art.gd            # grafiki budynków rysowane kodem (assets/buildings)
"$GODOT" --headless --path . -s res://tools/generate_characters.gd     # postacie rysowane kodem (assets/characters)
"$GODOT" --headless --path . -s res://tools/generate_goods.gd          # towary, skały i drzewa rysowane kodem (assets/goods, assets/nature)
"$GODOT" --headless --path . -s res://tools/build_big_city.gd         # duże miasto M4b-3 → tests/fixtures/saves/big_city.json
pip install spritekiln numba                                         # SpriteKiln + przyspieszenie (numba osobno, nie [fast])
cd tools/spritekiln/art/specs/<characters|props>/<id> && spritekiln pose <id>.yaml   # podgląd modelu 3D → pixel art (ART_SPEC §10.20)
```

Raporty testów trafiają do `reports/` (ignorowane przez git). Nowy `class_name` wymaga importu, żeby trafił do cache klas. `run_tests.sh` robi to automatycznie. Przy ręcznym uruchamianiu najpierw zrób import.

Repozytorium zdalne: `origin` = https://github.com/slota145/Your-Kingdom.git, gałąź `main`.

## Zasady pracy

- **Komunikacja po polsku. Kod, nazwy, komentarze i commity po angielsku.**
- Pracujemy **etapami z ROADMAP.md**. Po ukończeniu etapu (wszystkie punkty DoD): krótkie podsumowanie i **stop, czekamy na akceptację**.
- Nie piszemy kodu wykraczającego poza bieżący etap.
- Zmiana decyzji z dokumentów oznacza aktualizację odpowiedniego dokumentu w tym samym commicie.
- Każda zmiana w `src/sim` ma testy. **Szybkie testy muszą przechodzić przed każdym commitem, a długie (`--long`) przed scaleniem do `main` i na koniec części etapu** (decyzja właściciela 2026-11-07, ARCHITECTURE §12). Test dłuższy niż ok. 8 s trafia do `tests/long`.
- **Commity bez pytania (decyzja właściciela 2026-11-05):** commituj gotowe, przetestowane kawałki pracy i wysyłaj je na bieżącą gałąź roboczą bez pytania (w chmurze kontener znika, więc nic nie może czekać tylko lokalnie). Scalanie do `main` (PR) dalej tylko na prośbę właściciela.
- **Po każdym scaleniu PR do `main`** podaj komendę do aktualizacji gry na laptopie (w folderze gry): `powershell -ExecutionPolicy Bypass -File aktualizuj.ps1`. Skrypt sprawdza lokalne zmiany, pobiera `main` i wczytuje grafiki do Godota.
- **Po dużym zadaniu albo etapie** (jeśli jest następny krok) przygotuj gotowy prompt do wklejenia w nowej sesji, żeby oszczędzać tokeny. Ma być krótki i samodzielny: cel i zakres z ROADMAP, dokumenty do przeczytania, stan po poprzedniej sesji, otwarte decyzje i to, gdzie się zatrzymać. Nie przepisuj dokumentów, tylko na nie wskaż.

## Kluczowe konwencje

- **Symulacja jest oddzielona od widoku:** `src/sim/**` nie używa `Node`, `get_tree()`, `src/view`, `src/ui`. Stan zmieniają wyłącznie komendy. Widok czyta stan i konsumuje zdarzenia.
- **Dane zamiast kodu:** towary, budynki, receptury, jednostki i prowincje to `Resource` (`.tres`) w `data/`. Id to `StringName` w `snake_case` i jest stały po wydaniu.
- **Logika nie zna grafik:** wygląd jest opisany w `data/visuals/`, a pliki w `assets/` według ART_SPEC. Placeholdery w `assets/_placeholder/` mają identyczny układ.
- **Zero tekstów widocznych dla gracza na sztywno:** zawsze `tr()` lub `tr_n()` z kluczem (`ui.*`, `good.<id>.name`…), tłumaczenia w `localization/*.po`. Polski ma 3 formy liczby mnogiej.
- **Statyczne typowanie wszędzie.** Pliki `snake_case`, klasy `PascalCase`, stałe `UPPER_SNAKE`, prywatne `_prefix`, sygnały w czasie przeszłym.
- Siatka logiczna w przestrzeni kafli. Kafel ma 64×32 px. Konwersja tylko przez `IsoMath`.
- `src/prototype/<etap>/` to kod jednorazowy (sceny testowe, benchmarki). Wolno w nim używać angielskich tekstów debugowych na sztywno. Nic z kodu docelowego nie może od niego zależeć.
- Sortowanie głębi: wszystko, co stoi na mapie, jest dzieckiem jednego węzła z `y_sort_enabled`, a punkt sortowania to „stopa”. Nowe obiekty wielokaflowe tnij przez `BuildingSlicer` i dopisz przypadek do `test_sorting.gd`.
- Placeholdery generuje `tools/generate_placeholders.gd`. Nie edytuj ręcznie `assets/_placeholder/`.
- Zapis gry obejmuje tylko stan symulacji. Zmiana formatu oznacza podbicie `save_version`, dodanie migracji i testu.

## Styl współpracy

- Bądź miły i entuzjastyczny. Ciesz się razem ze mną postępami w grze.
- Traktuj mnie jak partnera w tworzeniu gry. Proponuj kreatywne pomysły na mechaniki, klimat, animacje i drobne detale budujące immersję.
- Wyraźnie oddzielaj swoje pomysły od tego, co już ustaliliśmy. Nie dodawaj nowych funkcji do gry bez mojej zgody. Pomysły trafiają do `docs/IDEAS.md`.
- Bądź przy tym szczery: jeśli pomysł, także mój, jest ryzykowny, zbyt pracochłonny lub nie pasuje do gry, powiedz o tym i zaproponuj lepszą opcję.
- **Jestem początkujący, więc pisz prosto, „łopatologicznie”.** Krótkie zdania, zwykłe słowa, najpierw to, co z tego wynika dla gry. Bez żargonu, a jeśli termin jest potrzebny, wyjaśnij go w kilku słowach. Szczegóły techniczne (nazwy klas, plików, algorytmów) podawaj tylko wtedy, gdy o nie poproszę albo gdy są naprawdę potrzebne.
- **Każdy wybór, który mam podjąć, zadawaj w formie ankiety** (narzędzie do pytań z opcjami do kliknięcia), z krótkim opisem każdej opcji i Twoją rekomendacją na pierwszym miejscu.
