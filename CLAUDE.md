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

**Bieżący etap:** M4b-1.5 „Miasto” (obracanie budynków, dwa rzędy domów, nowe pierzeje): zrobione (obracanie, drzwi, kamienice szczytem do ulicy), czeka na ocenę właściciela na laptopie (ROADMAP). Zrzut kwartału kamienic: `town_shot.tscn -- --minutes=85 --layout --focus=<all|row|corner|back|patrician_back|burgher_corner> [--zoom=2]`. Następnie M4b-2 (mięso, straganiarze, kupiec wędrowny). M4b-1 oceniony 2026-11-05 (4/5, kamienice 2/5). Do zrzutów: `src/prototype/m4a/town_shot.tscn -- --minutes=85 --select=<id>` (w chmurze przez `xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 …`). Mury i wieża bramna są w prototypie (`src/prototype/walls/`). A1 częściowo: brakuje postaci (ROADMAP, A1).

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
```

Raporty testów trafiają do `reports/` (ignorowane przez git). Nowy `class_name` wymaga importu, żeby trafił do cache klas. `run_tests.sh` robi to automatycznie. Przy ręcznym uruchamianiu najpierw zrób import.

Repozytorium zdalne: `origin` = https://github.com/slota145/Your-Kingdom.git, gałąź `main`.

## Zasady pracy

- **Komunikacja po polsku. Kod, nazwy, komentarze i commity po angielsku.**
- Pracujemy **etapami z ROADMAP.md**. Po ukończeniu etapu (wszystkie punkty DoD): krótkie podsumowanie i **stop, czekamy na akceptację**.
- Nie piszemy kodu wykraczającego poza bieżący etap.
- Zmiana decyzji z dokumentów oznacza aktualizację odpowiedniego dokumentu w tym samym commicie.
- Każda zmiana w `src/sim` ma testy. Testy muszą przechodzić przed commitem.
- Commity tylko na prośbę użytkownika albo na końcu zatwierdzonego etapu. Bez wysyłania na zdalne repozytorium, dopóki użytkownik o to nie poprosi.
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
