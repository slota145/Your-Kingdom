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

**Bieżący etap:** M6 „Mapa świata i prowincje” (ROADMAP, M6): **start 2026-11-06 przed oceną M4b-2, M4b-3 i M5** (decyzja właściciela: właściciel przetestuje wszystkie zaległości razem na laptopie, a poprawki z tych ocen mają pierwszeństwo przed dalszą pracą). Plan M6 (3 części: świat i tryb uproszczony; zasiedlanie, wyspy i ratusz jako siedziba; szlaki, wykup osad i wino) **zaakceptowany 2026-11-06** (ROADMAP, M6). **Część 1 (świat i tryb uproszczony) gotowa i scalona 2026-11-06 (PR #23), czeka na ocenę właściciela** (stan: ROADMAP, M6, „Część 1, stan”). **Część 2 (zasiedlanie) gotowa 2026-11-06, czeka na ocenę** (stan: ROADMAP, M6, „Część 2, stan”). Następny krok po ocenie: część 3 (szlaki, wykup osad, wino). Mapa „Wyspy”: `python3 tools/generate_island_map.py`. Fixtura v13: `"$GODOT" --headless --path . -s res://tools/build_expedition_fixture.gd`. Zrzut mapy świata: `src/prototype/m6/world_shot.tscn -- --out=<plik.png> [--select=<id prowincji>] [--settle]`. Pomiar trybu uproszczonego: `"$GODOT" --headless --path . -s res://src/prototype/m6/abstract_bench.gd`. Fixtura v12: `"$GODOT" --headless --path . -s res://tools/build_world_fixture.gd`. Dane świata: `python3 tools/generate_world_data.py`.

**Czeka na ocenę gry:** M5 „Woda, porty i statki”: części 1–3 scalone do `main` 2026-11-06 (PR #18, #19, #20); część 3 przed oceną. plan zaakceptowany 2026-11-06 (ROADMAP, M5; 3 części). **Część 1 (morze i ryby) zaakceptowana i scalona do `main` 2026-11-06. Część 2 (port i kupiec morski) zaakceptowana i scalona do `main` 2026-11-06. Część 3 gotowa i scalona do `main` 2026-11-06 przed oceną (decyzja właściciela): ocena gry M5 odłożona i zrobiona razem z zaległymi ocenami M4b-2 i M4b-3, etap formalnie otwarty do tej oceny** (koga gracza w 4 etapach, rejsy za horyzont z planem w panelu portu, start ze statku na „Wybrzeżu”, obóz pionierów zamiast ratusza na start, zapis v11). Zrzuty części 3: `game_shot.tscn -- --map=coast --tile=74,70 --zoom=2 --cog_stage=<0..3> [--select=port]` (koga na pochylni, koga na kotwicy, plan rejsu) i `game_shot.tscn -- --map=coast --tile=70,74 --zoom=3 --advance=<s>` (lądowanie). Grafika kogi gracza: `python3 tools/render_cog.py cog 46,84,168 [--stages]`. Pomysły z części 3 (ratusz na później, dom budowniczych, rejsy w kółko): IDEAS. Pomysł gracza na nabrzeża budowane w głąb morza: IDEAS (po M5). Część 2: port (`Harbour`), kupiec morski (`SeaMerchant`), panel statku, zapis v10. Zrzut portu z kogą kupca: `src/prototype/terrain/game_shot.tscn -- --map=coast --tile=74,70 --zoom=2 --port --select=ship`. Grafika kogi: `python3 tools/render_cog.py foreign_cog 40,118,72`. Część 1: mapa „Wybrzeże” (`tools/generate_coast_map.py`), wodne siatki ruchu, `ShipUnit`, smolarnia, stocznia, przystań rybacka, ławice, zapis v9. Zrzut portu: `src/prototype/terrain/game_shot.tscn -- --map=coast --tile=74,70 --zoom=2 --harbour`. Grafika statków: `"$GODOT" --headless --path . -s res://tools/generate_ships.gd`. Poprawki z odłożonej oceny M4b-2 i M4b-3 mają pierwszeństwo. Prototyp kogi: `src/prototype/ships/`.

**Poprzedni etap:** M4b-3 (wozy i bruk, nowa mapa 128×128 z jeziorem i kamienistym gruntem, duże miasto 400+ postaci, wydajność): plan zaakceptowany 2026-11-05. Części 1 (bruk, wózki, stajnia i wozy), 2 (mapa „Pojezierze” 128×128) i 3 (duże miasto: fixtura `big_city.json` ze skryptu `tools/build_big_city.gd`, 412 budynków, średnio 436 postaci; 2 h bez zakleszczeń; tick 3,6 ms średnio, 3,5–3,8 ms przy 460–480 postaciach, przed poprawkami 50 ms, ARCHITECTURE §9.3) gotowe i przetestowane. Scalone do `main` 2026-11-06 przed oceną (decyzja właściciela): ocena gry M4b-3 i M4b-2 oraz pomiar FPS na laptopie odłożone na później, oba etapy formalnie otwarte do tej oceny. Pomiar ticku: `"$GODOT" --headless --path . -s res://src/prototype/m4b3/tick_bench.gd -- --minutes=120`. Zrzut nowej mapy: `game_shot.tscn -- --map=lakeland --tile=78,48 --zoom=3`. Zrzut wózków i wozów: `src/prototype/terrain/game_shot.tscn -- --tile=56,50 --zoom=3 --roads --paved --carts`. **M4b-3 startuje przed oceną M4b-2** (decyzja 2026-11-05, świadome ryzyko poprawek; poprawki z oceny M4b-2 mają pierwszeństwo). Pomiar FPS na laptopie: osobna sesja z właścicielem. M4b-2 (stos przy budynku, gęsty las, mięso, straganiarze, kupiec wędrowny, „Zapasy królestwa”): kod gotowy, DoD odhaczone poza oceną gry; czeka na ocenę właściciela na laptopie. Zrzut z oknem zapasów: `town_shot.tscn -- --minutes=62 --stocks`. M4b-1.5 „Miasto” zamknięty 2026-11-05 (kamienice 5/5). Zrzut kwartału kamienic: `town_shot.tscn -- --minutes=85 --layout --focus=<all|row|corner|back|patrician_back|burgher_corner> [--zoom=2]`. Do zrzutów: `src/prototype/m4a/town_shot.tscn -- --minutes=85 --select=<id>` (w chmurze przez `xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 …`). Mury i wieża bramna są w prototypie (`src/prototype/walls/`). A1 częściowo: brakuje postaci (ROADMAP, A1).

## Polecenia

Godot 4.7.2 nie jest w PATH. Skąd go wziąć:
- **Laptop właściciela (Windows):** `C:\Godot_v4.7.2-stable_win64.exe` to **folder**, a w nim są pliki wykonywalne. W Git Bash używaj wersji `_console`.
- **Chmura (Linux):** hook `SessionStart` ustawia `$GODOT` sam. Jeśli go brak: `GODOT="$(tools/setup_godot.sh)"`. Konfiguracja środowiska: [docs/CLOUD_SETUP.md](docs/CLOUD_SETUP.md). W chmurze nie ma ekranu ani karty graficznej: benchmarków i oceny „na oko” nie robimy, prosimy o nie właściciela projektu na laptopie.

```bash
GODOT="/c/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"   # tylko Windows
"$GODOT" --path .                                                   # uruchomienie gry
"$GODOT" --headless --path . --import                               # reimport zasobów i cache klas
tools/run_tests.sh                                                  # wszystkie testy (gdUnit4 v6.2.2), headless
"$GODOT" --headless --path . -s res://tools/generate_placeholders.gd   # generowanie placeholderów
"$GODOT" --headless --path . -s res://tools/generate_art.gd            # grafiki budynków rysowane kodem (assets/buildings)
"$GODOT" --headless --path . -s res://tools/generate_characters.gd     # postacie rysowane kodem (assets/characters)
"$GODOT" --headless --path . -s res://tools/generate_goods.gd          # towary, skały i drzewa rysowane kodem (assets/goods, assets/nature)
"$GODOT" --headless --path . -s res://tools/build_big_city.gd         # duże miasto M4b-3 → tests/fixtures/saves/big_city.json
```

Raporty testów trafiają do `reports/` (ignorowane przez git). Nowy `class_name` wymaga importu, żeby trafił do cache klas. `run_tests.sh` robi to automatycznie. Przy ręcznym uruchamianiu najpierw zrób import.

Repozytorium zdalne: `origin` = https://github.com/slota145/Your-Kingdom.git, gałąź `main`.

## Zasady pracy

- **Komunikacja po polsku. Kod, nazwy, komentarze i commity po angielsku.**
- Pracujemy **etapami z ROADMAP.md**. Po ukończeniu etapu (wszystkie punkty DoD): krótkie podsumowanie i **stop, czekamy na akceptację**.
- Nie piszemy kodu wykraczającego poza bieżący etap.
- Zmiana decyzji z dokumentów oznacza aktualizację odpowiedniego dokumentu w tym samym commicie.
- Każda zmiana w `src/sim` ma testy. Testy muszą przechodzić przed commitem.
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
