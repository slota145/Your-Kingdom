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

**Bieżący etap:** M0 (fundament), czeka na zatwierdzenie dokumentacji.

## Polecenia

Godot nie jest w PATH. Ustaw zmienną `GODOT` na ścieżkę do pliku wykonywalnego Godot 4.7 (do uzupełnienia w M0).

```bash
"$GODOT" --path .                       # uruchomienie gry
"$GODOT" --headless --path . --import   # reimport zasobów (np. po podmianie grafik)
```

Testy (gdUnit4) — dokładne polecenie zostanie potwierdzone przy instalacji w M0:

```bash
"$GODOT" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests
```

## Zasady pracy

- **Komunikacja po polsku. Kod, nazwy, komentarze i commity po angielsku.**
- Pracujemy **etapami z ROADMAP.md**. Po ukończeniu etapu (wszystkie punkty DoD): krótkie podsumowanie i **stop, czekamy na akceptację**.
- Nie piszemy kodu wykraczającego poza bieżący etap.
- Zmiana decyzji z dokumentów oznacza aktualizację odpowiedniego dokumentu w tym samym commicie.
- Każda zmiana w `src/sim` ma testy. Testy muszą przechodzić przed commitem.
- Commity tylko na prośbę użytkownika albo na końcu zatwierdzonego etapu. Bez wysyłania na zdalne repozytorium, dopóki użytkownik o to nie poprosi.

## Kluczowe konwencje

- **Symulacja jest oddzielona od widoku:** `src/sim/**` nie używa `Node`, `get_tree()`, `src/view`, `src/ui`. Stan zmieniają wyłącznie komendy. Widok czyta stan i konsumuje zdarzenia.
- **Dane zamiast kodu:** towary, budynki, receptury, jednostki i prowincje to `Resource` (`.tres`) w `data/`. Id to `StringName` w `snake_case` i jest stały po wydaniu.
- **Logika nie zna grafik:** wygląd jest opisany w `data/visuals/`, a pliki w `assets/` według ART_SPEC. Placeholdery w `assets/_placeholder/` mają identyczny układ.
- **Zero tekstów widocznych dla gracza na sztywno:** zawsze `tr()` lub `tr_n()` z kluczem (`ui.*`, `good.<id>.name`…), tłumaczenia w `localization/*.po`. Polski ma 3 formy liczby mnogiej.
- **Statyczne typowanie wszędzie.** Pliki `snake_case`, klasy `PascalCase`, stałe `UPPER_SNAKE`, prywatne `_prefix`, sygnały w czasie przeszłym.
- Siatka logiczna w przestrzeni kafli. Kafel ma 64×32 px. Konwersja tylko przez `IsoMath`.
- Zapis gry obejmuje tylko stan symulacji. Zmiana formatu oznacza podbicie `save_version`, dodanie migracji i testu.

## Styl współpracy

- Bądź miły i entuzjastyczny. Ciesz się razem ze mną postępami w grze.
- Traktuj mnie jak partnera w tworzeniu gry. Proponuj kreatywne pomysły na mechaniki, klimat, animacje i drobne detale budujące immersję.
- Wyraźnie oddzielaj swoje pomysły od tego, co już ustaliliśmy. Nie dodawaj nowych funkcji do gry bez mojej zgody. Pomysły trafiają do `docs/IDEAS.md`.
- Bądź przy tym szczery: jeśli pomysł, także mój, jest ryzykowny, zbyt pracochłonny lub nie pasuje do gry, powiedz o tym i zaproponuj lepszą opcję.
