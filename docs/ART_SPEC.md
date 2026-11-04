# Your Kingdom — specyfikacja grafik

> Status: **wersja 0.1 (do zatwierdzenia)** · data: 2026-11-04
> Cel: placeholdery i grafiki z PixelLab mają **identyczny układ plików**, więc podmiana nie wymaga zmian w logice ani w scenach.
> Wartości oznaczone **(M1)** zostaną potwierdzone lub poprawione w prototypie czytelności.

---

## 1. Styl

- **Pixel art**, izometria 2:1, stała kamera bez obrotu.
- **Światło z góry i lekko z przodu**, czyli od strony kamery, a nie z boku. Dzięki temu lustrzane odbicia postaci nie odwracają kierunku światła (§4.2). Budynki mogą mieć delikatnie jaśniejszą ścianę lewą (SW) niż prawą (SE). Budynków nie odbijamy.
- **Kontur:** 1 px, ciemny, selektywny, dopasowany do koloru (nie czysto czarny) dla postaci, towarów i budynków. Teren jest bez konturu.
- **Paleta:** wspólna, ok. 48–64 kolorów, ciepła i ziemista. Kolory obiektów ważnych dla rozgrywki (towary, postacie) są bardziej nasycone niż teren, żeby się wyróżniały.
- **Kolor frakcji:** w spritach jednostek, flag i tarcz zarezerwowany jest zakres 4 odcieni **magenty** (`#FF00FF`, `#CC00CC`, `#990099`, `#660066`). Shader podmienia je na kolor gracza lub AI. W grafikach z PixelLab trzeba będzie te odcienie dorysować lub zamienić narzędziem (`tools/`).
- **Tło sprite’ów:** przezroczyste (PNG RGBA). Bez półprzezroczystych krawędzi, z wyjątkiem dymu i efektów.

---

## 2. Foldery i nazwy plików

```
assets/
├── characters/<character_id>/<anim>.png            # arkusz: wiersze = kierunki, kolumny = klatki
├── characters/<character_id>/<anim>.anchors.png    # (opcjonalnie) mapa punktów zaczepienia niesionego towaru
├── goods/icons/<good_id>.png                       # ikona UI 32×32
├── goods/carried/<carry_category>/<good_id>.png    # nakładka niesionego towaru (arkusz kierunków)
├── goods/stacks/<good_id>.png                      # stosy w magazynie: 4 fazy zapełnienia w poziomie
├── buildings/<building_id>/<state>.png             # base, construction_1, construction_2, upgrade_scaffold...
├── buildings/<building_id>/fx_<name>.png           # animowane efekty: dym, ogień, śmigło młyna
├── buildings/houses/<level>/<variant>_<axis>.png   # warianty łączenia kamienic (§7)
├── walls/<wall_type>/<piece>.png                   # filary, półsegmenty, bramy, baszty (§6)
├── terrain/<terrain_id>/<variant>.png              # kafle terenu
├── terrain/fields/<crop_id>_<stage>.png            # fazy upraw
├── nature/<object_id>/<state>.png                  # drzewa (rośnie / stoi / ścięte / pień), krzaki, skały
├── ships/<ship_id>/<anim>.png                      # arkusze kierunków jak postacie
├── ui/…                                            # 9-slice panele, przyciski, ikony
├── fonts/
└── _placeholder/                                   # LUSTRZANY układ wszystkich powyższych
```

**Reguły nazw:**
- wszystkie nazwy plików i folderów w `snake_case`, po angielsku,
- `<character_id>`, `<good_id>`, `<building_id>` = **dokładnie** `id` z definicji w `data/`,
- nazwy animacji z §4.3.

**Mechanizm podmiany:**
- Definicje wizualne w `data/visuals/` wskazują ścieżki przez **ustawienie projektu `your_kingdom/art_root`** (`res://assets/_placeholder` albo `res://assets`).
- Importer (`tools/import_visuals.gd`) skanuje drzewo, czyta wymiary arkuszy i liczbę klatek, a następnie generuje lub aktualizuje `data/visuals/*.tres`.
- Finalne grafiki trafiają do `assets/` pod tymi samymi nazwami. **Jeśli liczba klatek się zmieni, importer to uwzględni. Logika odwołuje się tylko do nazw animacji.**
- Brak finalnej grafiki dla danego id oznacza automatyczny powrót do placeholdera. Dzięki temu grafiki można podmieniać stopniowo.

---

## 3. Skala

### 3.1 Kafel i postać

| Element | Rozmiar | Uwagi |
|---|---|---|
| Kafel terenu | **64×32 px** (romb 2:1) | plik 64×32. Kafle z wysokością, np. skarpy brzegu: 64×48 z romb u dołu |
| Postać dorosła | **42 px wysokości** (±2) | głowa ok. 9–10 px, szerokość ciała ok. 14–18 px **(M1)** |
| Dziecko | ok. 30 px | [PÓŹNIEJ], przechodnie |
| Płótno klatki postaci | **64×64 px** | zapas na narzędzia (kosa, łopata do pieca, włócznia) |
| Punkt stopy (pivot) | **(32, 58)** na płótnie 64×64 | środek między stopami, dotyka ziemi |
| Niesiony towar | 10–16 px | większy niż „realistycznie”, żeby był czytelny |
| Jeździec | płótno 96×96, pivot (48, 88) | [1.0] |
| Ikona towaru (UI) | 32×32 (rysowana w 16×16 ×2 lub natywnie 32) | **(M1)** |

**Uzasadnienie:** przy 1× i 1080p widać ok. 30 kafli w poziomie, a 42-pikselowa postać jest wtedy duża jak w Twierdzy. Przy 2× (84 px na ekranie) dokładnie widać czynności i niesione przedmioty. Przy 0,5× (21 px) widać ruch i kolor towaru, czyli wystarczająco dla widoku przeglądowego.

### 3.2 Budynki

| Footprint | Szerokość sprite’a | Maks. wysokość sprite’a | Przykłady |
|---|---|---|---|
| 1×1 | 64 | 96 | studnia, baszta (2×2 dla dużej) |
| 2×2 | 128 | 160 | chata, piekarnia, drwal, młyn (śmigło jako osobny efekt, wyższe) |
| 3×3 | 192 | 208 | warsztaty [1.0] |
| 4×4 | 256 | 256 | ratusz, magazyn (plac + szopa) |

- **Pivot budynku:** dolny wierzchołek rombu podstawy (przedni róg footprintu), wyrażony w pikselach od lewego górnego rogu pliku i zapisany w definicji wizualnej.
- **Drzwi i wejście** muszą być narysowane na kaflu wejścia z `BuildingDef.entrance`.
- **Punkty pracy** (stół, piec, kowadło) muszą być widoczne **od strony kamery**, czyli po przedniej stronie budynku albo pod wiatą lub w otwartym warsztacie. To wymóg immersji: czynności robione „w środku” nie byłyby widoczne. Piekarz przy piecu stoi w otwartym przedsionku albo przy piecu chlebowym na zewnątrz.
- Ściany i dach rysujemy w całości. Kod sam tnie budynek na paski do sortowania (ARCHITECTURE §6.2).

### 3.3 Poziomy zoomu

| Zoom | Piksel grafiki → ekran (1080p) | Postać na ekranie | Zastosowanie |
|---|---|---|---|
| 0,5× | 0,5 | ~21 px | przegląd. Animacje z mniejszą liczbą klatek, uproszczony towar |
| **1×** | 1 | 42 px | domyślny |
| 2× | 2 | 84 px | obserwacja pracy |
| 3× | 3 | 126 px | detal, tryb „śledź” |

0,5× jest jedynym zoomem niecałkowitym. Do weryfikacji w M1: filtr `Nearest` z ewentualnym pomniejszeniem przez mipmapy lub osobny „przeglądowy” zestaw grafik [PÓŹNIEJ].

**Po M1:**
- Zoom liczymy względem rozdzielczości logicznej 1280×720 ze skalą całkowitą (ARCHITECTURE §6.7). Tabela powyżej dotyczy skali płótna 1 (okno lub monitor ~1080p).
- Na monitorach 1440p i 2560×1600 skala płótna wynosi 2, więc „1×” daje postać 84 px, a 0,5× jest wtedy ostre (1:1).
- Ocena czytelności przy 1× i 2× na zrzutach z M1: czynność i niesiony towar są czytelne od 2× w górę, a przy 1× rozróżnialne po kolorze i kształcie. **Do potwierdzenia przez właściciela projektu na własnym ekranie.**

---

## 4. Animacje postaci

### 4.1 Kierunki

**8 kierunków ekranowych:** S, SE, E, NE, N, NW, W, SW.
Kolejność wierszy w arkuszu: **S, SE, E, NE, N, NW, W, SW** (zgodnie z ruchem wskazówek zegara, zaczynając od kierunku „do kamery”).

Ruch po osiach siatki (najczęstszy) daje kierunki SE, NW, NE, SW. Ruch po przekątnej siatki daje S, N, E, W. Wszystkie 8 kierunków jest więc potrzebne, a 4 nie wystarczą, bo postać „sunęłaby bokiem”.

### 4.2 Lustrzane odbicia

| Rysowane | Odbijane z |
|---|---|
| S, SE, E, NE, N | — |
| SW | SE |
| W | E |
| NW | NE |

Rysujemy więc **5 kierunków zamiast 8**, czyli ok. 37% mniej grafik.

**Ocena jakości:**

| Kwestia | Ocena |
|---|---|
| Kierunek światła | ✅ Nie jest problemem przy świetle „z góry i z przodu” (§1). |
| Asymetria postaci | ⚠️ Narzędzie w prawej ręce po odbiciu trafia do lewej. U cywilów (worek na ramieniu, sierp) jest to niezauważalne i stosowane w wielu grach gatunku. U żołnierzy z tarczą, mieczem i łukiem bywa widoczne. |
| Elementy kierunkowe | ⚠️ Herby, napisy i asymetryczne stroje odbite wyglądają źle. Wymagamy symetrycznych strojów albo rysujemy 8 kierunków. |

**Decyzja:**
- Cywile: **5 kierunków + odbicia** (domyślnie).
- Żołnierze i postacie bohaterskie: **8 kierunków** (flaga `mirror: false` w definicji wizualnej).
- PixelLab może generować 8 kierunków od razu. Wtedy odbicia oszczędzają głównie kredyty, pamięć i czas poprawek spójności. **(M1)** porównamy postać odbitą z wygenerowaną.

Arkusz z odbiciami ma 5 wierszy (S, SE, E, NE, N), a importer to wykrywa.

**Wynik porównania M1** (`src/prototype/m1/mirror_lineup.tscn`, postać z narzędziem w prawej ręce):
- W kierunkach NW, W i SW odbita postać trzyma narzędzie w **lewej** ręce i przed sobą. Wersja rysowana w 8 kierunkach chowa je poprawnie za ciałem.
- Przy zoomie 3× różnicę widać, przy 1× jest praktycznie niezauważalna.
- Decyzja bez zmian: cywile 5 kierunków + odbicia, żołnierze i postacie z wyraźnie asymetrycznym ekwipunkiem 8 kierunków.
- Jeśli w pilocie A1 PixelLab da 8 spójnych kierunków bez dodatkowego kosztu, rozważymy 8 dla wszystkich (wyższa jakość przy zoomie 3×).

### 4.3 Stany i liczba klatek

Klatka ma 64×64. Arkusz to wiersze kierunków × kolumny klatek. Wartości FPS to **(M1)**.

**Wspólne dla wszystkich cywilów:**

| Animacja (`<anim>`) | Klatki | FPS | Pętla | Opis |
|---|---|---|---|---|
| `idle` | 4 | 4 | tak | oddech, rozglądanie |
| `walk` | 8 | 10 | tak | marsz z pustymi rękami |
| `walk_carry_sack` | 8 | 10 | tak | worek na ramieniu (zboże, mąka, wełna) |
| `walk_carry_crate` | 8 | 10 | tak | skrzynia przed sobą w obu rękach (narzędzia, ubrania, broń) |
| `walk_carry_barrel` | 8 | 9 | tak | beczka na ramieniu (piwo, wino, smoła, ryby solone) |
| `walk_carry_log` | 8 | 9 | tak | kłoda lub deski na ramieniu (drewno, deski) |
| `walk_carry_basket` | 8 | 10 | tak | kosz przy biodrze (chleb, jabłka, ryby) |
| `walk_carry_bundle` | 8 | 10 | tak | snop lub wiązka na plecach (zboże ze żniw, chmiel) |
| `walk_carry_stone` | 8 | 8 | tak | blok kamienia w objęciach, wolniej |
| `pickup` | 4 | 10 | nie | schyla się i podnosi (wersja z rękami pustymi → kategoria) |
| `putdown` | 4 | 10 | nie | odkłada |
| `enter` / `exit` | 4 | 10 | nie | [1.0] wejście w drzwi (z fade). W slice tylko fade |

**Praca, według zawodów [SLICE]:**

| Postać | Animacja | Klatki | Kierunki | Uwagi |
|---|---|---|---|---|
| farmer | `work_plow` | 8 | 5+lustro | orka motyką |
| | `work_sow` | 6 | 5+lustro | siew z worka |
| | `work_harvest` | 8 | 5+lustro | żęcie sierpem |
| | `work_bind` | 6 | 2 (SE, SW) | wiązanie snopa, stoi bokiem do kamery |
| miller | `work_pour` | 8 | 1 (S) | wsypuje zboże. Stoi zawsze w tym samym miejscu, więc 1 kierunek |
| | `work_fill` | 6 | 1 (S) | napełnia worek mąki |
| baker | `work_knead` | 8 | 1 (S) | zagniatanie przy stole |
| | `work_bake` | 10 | 1 (SE) | łopata do pieca: wsuwa, wyjmuje |
| woodcutter | `work_chop` | 8 | 5+lustro | rąbie drzewo siekierą |
| | `work_saw` | 8 | 2 | piłuje kłodę [1.0] |
| builder | `work_hammer` | 6 | 5+lustro | młotek na budowie |
| householder | `idle`, `walk`, `walk_carry_basket` | — | — | domownik idzie po zapasy |
| porter | wszystkie `walk_carry_*` | — | — | tragarz |

**Zasada praktyczna:** stanowiska z określonym punktem pracy (`work_spot`) mają **1–2 kierunki** narysowane pod kątem, z którego postać będzie widoczna. Czynności w terenie (pole, las, budowa) mają pełne 5 kierunków z odbiciami. To mocno ogranicza liczbę klatek.

**[1.0] dodatkowe:** fisher (`work_cast_net`, `work_pull_net`), docker (ładowanie po trapie = `walk_carry_crate`/`barrel` + `work_lift`), smith (`work_forge`, `work_quench`), brewer, butcher, weaver itd. Ten sam schemat: 6–10 klatek, kierunki według punktu pracy.

**Żołnierze [1.0]:** `idle`, `walk`, `run`, `attack` (6–8), `hit` (3), `die` (6), `shoot` (łucznik, 8), `climb` (drabina, 6, tylko kierunki muru). 8 kierunków, bez odbić.

### 4.4 Warianty postaci

- **Zawód** rozpoznaje się po stroju i nakryciu głowy:
  - rolnik: słomkowy kapelusz,
  - młynarz: biały fartuch, czapka zakurzona mąką,
  - piekarz: biały fartuch i czepek,
  - drwal: czerwona koszula, siekiera,
  - tragarz: brązowy kubrak, chusta,
  - budowniczy: skórzany fartuch.

  Sylwetki muszą się różnić nawet przy 0,5×.
- **Różnorodność:** 2–3 warianty kolorystyczne na zawód przez **zamianę palety w shaderze** (włosy, odcień koszuli). Nie potrzeba dodatkowych grafik. Wybór wariantu wynika z id postaci.
- Mężczyźni i kobiety: kobiety jako domowniczki, tkaczki, sprzedawczynie [1.0].

---

## 5. Niesione towary

**Decyzja (M1: sprawdzimy obie opcje):**

- **A (domyślna) — nakładki.** Animacja ciała zależy od **kategorii noszenia** (`walk_carry_sack` itd.). Sam towar jest osobnym sprite’em nakładanym na punkt zaczepienia:
  - `goods/carried/<carry_category>/<good_id>.png` to arkusz 5 kierunków × 1 klatka, ok. 24×24 px na klatkę, np. worek mąki biały, worek zboża złoty, beczka piwa z ciemnym wiekiem, beczka wina z czerwonym znakiem,
  - **punkty zaczepienia:** `<anim>.anchors.png`, arkusz w tym samym układzie co animacja, gdzie w każdej klatce jest 1 piksel w kolorze `#FF0000` (pozycja zaczepienia) i opcjonalnie 1 piksel `#0000FF` (towar rysowany ZA postacią, np. dla kierunku N). Importer zamienia je na tablice przesunięć,
  - **zaleta:** 7 animacji noszenia × postacie + 1 mały sprite na towar zamiast pełnych animacji na każdy towar,
  - **wada:** wymaga mapy punktów zaczepienia, którą PixelLab nie wygeneruje sam. Trzeba ją dorysować albo wyznaczyć narzędziem.
- **B (rezerwa) — towar wypieczony w animacji.** Dla kategorii, w których towar wizualnie się nie różni (kłody, kamień), nakładka nie jest potrzebna: `walk_carry_log` zawiera już kłodę. Flaga `baked_good: true`.

**Rozróżnialność towarów** w tej samej kategorii zapewnia kolor i znak na worku lub beczce. Muszą być czytelne przy 1×.

---

## 6. Mury (8 kierunków)

Zasada składania kawałków opisana jest w ARCHITECTURE §6.3. Dla każdego typu muru (`palisade`, `stone_wall`):

| Plik | Ilość | Opis |
|---|---|---|
| `post.png` | 1–2 warianty | filar w środku kafla. Widoczny na końcach, narożnikach i skrzyżowaniach |
| `half_<dir>.png` | 8 | półsegment od środka kafla do krawędzi w kierunku `<dir>` siatki: `n, ne, e, se, s, sw, w, nw` (kierunki **siatki**, nie ekranu) |
| `gate_half_<dir>.png` | 4 (`n`, `e`, `s`, `w`) | filar bramy na zewnętrznej części półsegmentu (zmiana w M1: brama składa się z kawałków jak mur, dzięki czemu postać przechodząca przez bramę sortuje się poprawnie) |
| `gate_lintel_x.png`, `gate_lintel_y.png` | 2 (+ stany `open`, `broken` [1.0]) | belka nad otworem bramy wzdłuż osi X lub Y siatki |
| `tower.png` | 1 (+ `broken`) | baszta 2×2 |
| `stairs_<dir>.png` | 4 | schody na mur [1.0] |
| `damaged_` warianty | dla półsegmentów | [1.0] stany zniszczenia |

- Każdy plik ma płótno **64×96** z pivotem w punkcie (32, 80), czyli środku kafla. Wysokość muru kamiennego to ok. **56 px** nad ziemią (1,33× postaci), palisady ok. 48 px.
- Półsegmenty przekątne (`ne`, `se`, `sw`, `nw` w siatce) biegną na ekranie poziomo lub pionowo. Muszą mieć **tę samą grubość wizualną** co osiowe, a końce stykać się bez szczelin z filarem i z półsegmentem sąsiada. **To główny cel prototypu M1.**
- Korona muru (blanki) jest rysowana w każdym półsegmencie. Na filarze narożnym korona jest pełna.
- **Zmiana 2026-11-04:** powyższe kawałki dotyczą palisady. Mur kamienny ma model bryłowy (ARCHITECTURE §6.3) i składa się z kawałków:
  - wierzch bloku,
  - dwie przednie ściany,
  - krawędzie korony z blankami,
  - kliny przekątne.

  Dokładną listę plików ustalimy przy pierwszych grafikach muru.

---

## 7. Domy i kamienice

| Poziom | Pliki |
|---|---|
| 1 (chata) | `houses/1/single.png` + 2–3 warianty wyglądu (`single_b`, `single_c`) |
| 2 (dom mieszczański) | `houses/2/single.png`, `end_a_x.png`, `middle_x.png`, `end_b_x.png`, analogicznie `_y` dla drugiej osi |
| 3 (patrycjusze) | jak poziom 2 |
| Ulepszanie | `houses/<level>/upgrade_scaffold.png` (rusztowanie nakładane na dom) |

- `x` i `y` oznaczają oś siatki, wzdłuż której biegnie pierzeja. Fragmenty `end_a`, `middle` i `end_b` muszą stykać się ścianami szczytowymi bez szwów, a linia dachu musi być ciągła.
- Domy mają footprint 2×2, więc fragment `middle` ma 128 px szerokości jak dom pojedynczy.

---

## 8. Teren, natura i towary w magazynie

| Kategoria | Zawartość [SLICE] | [1.0] |
|---|---|---|
| Teren | trawa (4 warianty), ziemia, piasek nad rzeką, płytka i głęboka woda, brzeg (autotile 47 lub 16 kafli, **(M1)**: decyzja zestawu) | skała, bagno, morze, plaża, zbocza |
| Drogi | ubita (autotile 16) | bruk |
| Pola | `wheat_0` (zaorane), `wheat_1` (zasiane), `wheat_2` (rośnie), `wheat_3` (dojrzałe), `wheat_4` (ścierń) | chmiel, winorośl, len |
| Natura | drzewo liściaste: `growing_1..3`, `grown`, `falling` (anim.), `stump`. Krzaki, kamienie dekoracyjne | iglaste, skały ze złożem |
| Stosy w magazynie | `stacks/<good_id>.png`: arkusz 4 faz (25/50/75/100%), każda faza 64×64 (romb 1 kafla + wysokość) | wszystkie towary |
| Ikony towarów | 32×32 | wszystkie |

---

## 9. Lista assetów

### 9.1 Prototyp M1 (placeholdery generowane kodem)

- kafel trawy i kafel siatki,
- postać 42 px z czerwonym „nosem” wskazującym kierunek i narzędziem w prawej ręce:
  - `peasant`: 8 kierunków rysowanych,
  - `peasant_mirror`: 5 kierunków + odbicia,
  - animacje `idle`, `walk`, `walk_carry_sack`, `walk_carry_basket`, `walk_carry_bundle`, każda z `.anchors.png`,
- budynki-pudełka 2×2, 3×2 i 4×4 z dachem i drzwiami, a obok `base.json` (footprint, wejście, pivot),
- mur kamienny: `post`, 8 × `half_*`, 4 × `gate_half_*`, 2 × `gate_lintel_*`,
- 3 ikony towarów i 3 nakładki niesionych towarów: mąka (worek), chleb (kosz), zboże (snop).

Wszystko generuje `tools/generate_placeholders.gd`.

### 9.2 Vertical slice M3

| Grupa | Assety |
|---|---|
| Postacie (6) | farmer, miller, baker, woodcutter, porter, builder, householder (= porter z innym strojem) |
| Budynki (8) | town_hall, warehouse, hut (+ house lvl 2: single, end_a/middle/end_b × 2 osie), well, woodcutter, grain_farm, mill (+ fx śmigło), bakery (+ fx dym, ogień) |
| Budowa | `construction_1`, `construction_2` dla footprintów 1×1, 2×2, 4×4 (wspólne), `upgrade_scaffold` dla domów |
| Towary (5) | wood, grain, flour, bread, firewood (= wood w slice): ikony, nakładki, stosy |
| Teren | trawa ×4, ziemia, piasek, woda płytka i głęboka, brzeg rzeki, droga ubita, pole ×5 faz |
| Natura | drzewo liściaste (pełny cykl), 2 krzaki, 2 kamienie |
| UI | panel 9-slice, przycisk ×3 stany, ikony kategorii budowy ×6, ikony statusów (brak pracowników, brak surowca, pauza). Font: **Jersey 10** (OFL), wybrany w M1, z wyłączonym wygładzaniem. Pixelify Sans odrzucony, bo myli Z/2 i S/5 |

### 9.3 Wersja 1.0 (orientacyjnie)

ok. 25 typów postaci cywilnych, 6 typów żołnierzy, ok. 40 budynków, 2 typy murów, 3 statki, ok. 30 towarów, teren dla 3 typów map oraz mapa świata (ikony prowincji, armii i flot, tło).

---

## 10. Przepływ pracy z PixelLab

1. **Postać:** generujemy postać bazową w rozmiarze płótna 64 (lub najbliższym obsługiwanym, **do weryfikacji w M9**). Sprawdzamy wzrost 42 px i pivot. Następnie generujemy animacje według §4.3 i eksportujemy klatki.
2. **Konwersja:** `tools/pixellab_to_sheet.gd` (lub skrypt Pythona) składa klatki w arkusz w kolejności kierunków z §4.1. Wykrywa 5 kierunków lub 8 i dopasowuje pivot (wyrównanie stóp po najniższym nieprzezroczystym pikselu).
3. **Weryfikacja:** scena `tools/art_review.tscn` pokazuje animację we wszystkich kierunkach obok placeholdera, z siatką kafli, przy zoomach 0,5×, 1× i 2×. Pokazuje też nakładkę towaru i jej punkty zaczepienia.
4. **Budynki:** generowane jako obiekty izometryczne. Ręcznie (lub narzędziem) dopasowujemy romb podstawy do footprintu i ustawiamy pivot. Punkty pracy dopasowujemy przesunięciem w `BuildingVisualDef`.
5. **Kafle terenu:** generator kafli izometrycznych w docelowym rozmiarze 64×32 i zestawy autotile do brzegów i dróg.
6. **Spójność:** dla każdej serii używamy tych samych opisów stylu, palety i referencji (postać bazowa jako wzór). Wynik sprawdzamy narzędziem redukcji palety do wspólnej palety projektu.

**Kryterium akceptacji grafiki:**
- czytelna czynność przy 1×,
- rozróżnialny towar przy 1×,
- brak „pływania” stóp (pivot stały),
- zgodność z płótnem i nazwami,
- poprawne sortowanie w scenie testowej.

### 10.1 Pierwsza próba (2026-11-04, początek A1)

Wyniki są w piaskownicy murów (`src/prototype/walls/`, obiekty w `pixellab/`).
- **Drzewa i drobiazgi** z biblioteki właściciela projektu (widok RPG 3/4, 80×80 i 32×32) pasują do izometrii bez przeróbek. Skala względem postaci 42 px jest dobra. Część kandydatów jest przycięta na krawędzi płótna. Wykrywamy to automatycznie (nieprzezroczysty piksel na krawędzi) i odrzucamy albo poprawiamy.
- **Budynki z widokiem od frontu** (np. „medieval village”) nie pasują: mają jedną ścianę zamiast dwóch pod kątem.
- **`create_map_object`** z opisem „isometric … on a diamond base” (1 generacja) dał wieżę bramną na izometrycznej płycie. Romb ma proporcję ok. 1,8:1 zamiast 2:1, ale na placeholder wystarcza. Fasada jest zwrócona do kamery, więc obiekt pasuje do muru ukośnego (biegnącego poziomo na ekranie), a nie do osiowego. Bez słowa „diamond base” wychodzi czysty widok od frontu.
- **`create_isometric_tile` (blok 64 px)** daje sześcian o wysokości ok. 32 px z konturem na każdej krawędzi. Sąsiednie bloki nie zlewają się w jeden mur, a wysokość nie zgadza się z 56 px. Do muru bryłowego potrzebne są kawałki według §6. Do sprawdzenia: inpainting na naszym placeholderze.
- **Chaty z biblioteki** (słowiańskie z bali, kryte strzechą, ruiny farmy; 128×128) są narysowane izometrycznie z dwiema ścianami. Wchodzą na footprint 2×2 z pivotem w najniższym punkcie obrazka. Są trochę mniejsze od rombu 2×2, ale skala względem postaci jest dobra.
- **Rekwizyty** (farma, warsztat, winnica; 64×64) też pasują. Z 9 przyciętych kandydatów 7 odrzucił import, a 2 dotykają tylko dolnej krawędzi i zostały. Import usuwa też drobne „okruchy” pikseli i kawałki sąsiednich kandydatów. Odrzucony został m.in. stóg siana z widłami: widły dotykają krawędzi.
- **Sieć:** środowisko w chmurze ma dostęp do `backblaze.pixellab.ai` (Allowed domains), więc pliki pobieramy bezpośrednio.
