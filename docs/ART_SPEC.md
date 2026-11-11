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
├── goods/stacks/<good_id>.png                      # stosy w magazynie: klatki zapełnienia w poziomie (G2: jedna na sztukę)
├── buildings/<building_id>/<state>.png             # base, construction_1, construction_2, upgrade_scaffold...
├── buildings/<building_id>/<state>.json            # footprint, wejście, pivot (punkt B footprintu w obrazku)
├── buildings/<building_id>/fx_<name>.png           # animowane efekty: dym, ogień, śmigło młyna
├── buildings/<house_id>/level_<n>_<variant>_<axis>.png  # dom poziomu n i warianty pierzei (§7)
├── walls/<wall_type>/<piece>.png                   # filary, półsegmenty, bramy, baszty (§6)
├── terrain/<terrain_id>/<variant>.png              # kafle terenu
├── terrain/field/<stage>.png                       # fazy pola zboża (M3): fallow, plowed, sown_1..3, ripe
├── terrain/range/a.png, terrain/cursor/ok|bad.png  # nakładki: zasięg usługi, kursor budowy
├── nature/<object_id>/<state>.png                  # drzewa (rośnie / stoi / ścięte / pień), krzaki, skały
├── ships/<ship_id>/<anim>.png                      # arkusze kierunków jak postacie
├── vehicles/<vehicle_id>.png                       # pojazdy bez kierunków, np. wóz kupca (M4b-2), stopa w (48, 64)
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
| Postać dorosła | **ok. 34 px wysokości** (było 42 px w M1) | głowa ok. 8 px. Zmiana 2026-11-05: przy 42 px ludzie byli ponad dwa razy wyżsi od drzwi. Drzwi mają ok. 26 px, ściany parterowe ok. 36–42 px |
| Dziecko | ok. 30 px | [PÓŹNIEJ], przechodnie |
| Płótno klatki postaci | **64×64 px** (długa broń: większa kwadratowa klatka, np. 96×96 halabardnika, 2026-11-10) | zapas na narzędzia (kosa, łopata do pieca, włócznia) |
| Punkt stopy (pivot) | **(32, 58)** na płótnie 64×64; w większej klatce (szerokość/2, wysokość − 6), np. (48, 90) | środek między stopami, dotyka ziemi |
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

Klatka ma 64×64 (albo większa kwadratowa, np. 96×96: gra odczytuje jej rozmiar z wysokości arkusza, 8 albo 5 wierszy, `CharacterSheet.frame_side`). Arkusz to wiersze kierunków × kolumny klatek. Wartości FPS to **(M1)**.

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

- **Zwierzę prowadzone (M4b-2): kategoria `animal`.** Postać idzie zwykłym `walk` z wolnymi rękami, a zwierzę z `goods/carried/animal/<good_id>.png` (5 kierunków: przód, trzy widoki z boku, tył) idzie obok jej stopy (`AgentSprite.LED_OFFSET`), za postacią przy kierunkach od kamery. Stos takiego towaru (`goods/stacks/pig.png`) to 1–4 stojące zwierzęta zamiast sterty.

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

Pliki leżą w folderze budynku domu (`buildings/hut/`), a ich nazwy wskazuje `data/visuals/buildings/hut.tres` (`level_art`, `row_from_level`). Stan z M3:

| Poziom | Pliki |
|---|---|
| 1 (chata) | `base.png` (później warianty wyglądu `base_b`, `base_c`) |
| 1 (chata), od tyłu | `base_back.png`, `base_2_back.png`, `base_3_back.png` |
| 2 (dom mieszczański) | `level_2_<fragment>.png`; fragmenty `single`, `end_a`, `middle`, `end_b`, `corner_a`, `corner_b`; inne kształty szczytu `level_2_<fragment>_2.png`, `_3.png` (`row_variants`); od tyłu z dopiskiem `_back` (np. `level_2_middle_2_back.png`) |
| 3 (patrycjusze) | jak poziom 2 (`level_3_…`) |
| Ulepszanie | `upgrade_scaffold.png` (rusztowanie nakładane na dom), `upgrade_scaffold_back.png` |
| Budowa | `construction_1.png` (fundament i rusztowanie), `construction_2.png` (ściany na rusztowaniu) — każdy budynek ma własne, w tym samym kadrze co `base`; domy także `construction_1_back.png`, `construction_2_back.png` |

- **Orientacje (M4b-1.5):** grafikę rysujemy dla orientacji 0 (drzwi na ścianie +x, prawej dolnej). Orientacja 1 to ta sama grafika w lustrze (odbija ją gra). Domy w orientacjach 2 i 3 używają grafiki `_back` (drzwi po stronie niewidocznej, od kamery tył: tylne drzwi, mniej ozdób), 3 w lustrze. Pozostałe budynki nie mają grafik `_back`.
- Pierzeja na grafice biegnie wzdłuż osi y (front domu na ścianie +x); pierzeje wzdłuż x to lustro. `a` to koniec o mniejszej współrzędnej: `end_a` łączy się z sąsiadem tylko po stronie `b`, `end_b` tylko po stronie `a`, `corner_a` po stronie `a` i z tyłu (tam stoi dom drugiego rzędu), `corner_b` po stronie `b` i z tyłu.
- **Kamienice stoją szczytem do ulicy:** kalenica od ulicy w głąb, dachy sąsiadów stykają się koszami. Jeden fragment (działka 2×2) to kilka węższych domów: mieszczanie 1–3, patrycjusze 1–2, każdy z własną wysokością, szczytem, odcieniem z surowej palety i lekko przesuniętym frontem. Cała działka jest wybrukowana; działki mieszczan mają między sobą wąskie przerwy, patrycjuszy stykają się. Róg ma dwa szczyty (na obie ulice) i ścięty narożnik z bramą pod ukośnym szczytem albo (patrycjusze, wygląd `_2`) wykusz z wieżyczką. Rysuje je `tools/town_house_art.gd` z buforem głębi (§10.3).
- Domy mają footprint 2×2, więc każdy fragment ma 128 px szerokości (plus margines).

---

## 8. Teren, natura i towary w magazynie

| Kategoria | Zawartość [SLICE] | [1.0] |
|---|---|---|
| Teren | tekstury terenu organicznego (§8.1): `grass/a`, `grass/light`, `grass/dark`, `meadow/a`, `forest/a` (ściółka), `water/a`, `water/b`, `ford/a`, `bank/a` (skarpa brzegu); ozdoby `grass_decor/*`; M4b-3: `stony/a`, `stony/b` (kamienisty grunt), `lake/a`, `lake/b` (jezioro; od paczki 3 poprawek tylko źródło kamieni i palety, w grze `stony/big_{a,b,c}`, `stony/rocks_{a,b}`, `lake/big_{a,b,c}`, §8.1), trzciny `reeds/{a,b,c}` (kod, 24×32, stopa w (12, 29), na kaflach jeziora przy brzegu); M5: `sea/a`, `sea/b` (głębokie morze), `sea/shallow` (płytkie morze, osobny slot `SHALLOW` w shaderze), `sand/a` (plaża) | zbocza; **gotowe na później** (PixelLab, M4b-3): `bedrock/a` (spękana skała), `gravel/a` (żwir), `marsh/a`, `marsh/b` (bagno), `clay/a` (glina), `stubble/a` (ściernisko), `ice/a` (lód), `peat/a` (torf) |
| Pojazdy | wózek ręczny (M4b-3, kod: `tools/generate_goods.gd`): `vehicles/handcart/empty.png`, `loaded.png`, 5 wierszy (S, SE, E, NE, N) po 48×40, środek wózka na ziemi w (24, 30), stoi 0,4 kafla przed stopami tragarza; wóz konny: `vehicles/wagon/empty.png`, `loaded.png`, 5 wierszy po 112×80, punkt między wozem a koniem na ziemi w (56, 52), 0,6 kafla za woźnicą | |
| Statki (M5) | kod: `tools/generate_ships.gd`. Łódź rybacka `ships/fishing_boat/<anim>.png`: `idle` (pusta, 1 klatka), `row` (rybak wiosłuje), `cast_net`, `wait_net` (pływaki sieci na wodzie), `haul_net` (po 4 klatki); 8 wierszy (S, SE, E, NE, N, NW, W, SW, bez luster, bo łódź nie jest symetryczna z rybakiem), klatka 80×64, środek łodzi na linii wody w (40, 46). Łódź na pochylni: `build_0` (szkielet), `build_1` (poszycie), te same wiersze. Rybak w łodzi jest częścią grafiki łodzi. Ławica ryb `nature/fish_shoal/shoal.png`: 4 klatki × 3 wiersze (pełna z mewą, przełowiona, pusta), 64×48, środek kafla w (32, 32). **Część 2:** obca koga kupca morskiego `ships/foreign_cog/idle.png` (kod: `tools/render_cog.py`, przeniesiony z prototypu `src/prototype/ships/`): 8 wierszy (kierunki jak wyżej) × 4 klatki kołysania, klatka 220×220, środek kogi na linii wody w (110, 168); części frakcji (pasy żagla, tarcze, flaga) w kolorze kupca (zielony). Trap między nabrzeżem a statkiem rysuje widok (deska od stopy trapu do burty) | koga gracza i jej etapy budowy (część 3, ten sam generator w kolorze gracza) |
| Drogi | ubita: `road/a`, `road/b`; bruk: `paving/a` (PixelLab, ten sam zestaw `create_tiles_pro` co woda i droga, kafel 14 „cobblestone pavement”, krawędzie wyrównane `pixellab_tile_edges.py`), `paving/b` (lustro `a`); kształt drogi rysuje shader | |
| Pola | `terrain/field/`: `fallow` (ugór, też po żniwach), `plowed` (zaorane), `sown_1..3` (zasiane, rośnie, prawie dojrzałe), `ripe` (dojrzałe) | chmiel, winorośl, len (`terrain/field_<crop>/…`) |
| Natura | drzewo liściaste: `growing_1..3`, `grown`, `falling` (anim.), `felled` (ścięte, leży, aż drwal zabierze ostatnią kłodę), `stump`. Krzaki, kamienie dekoracyjne | iglaste, skały ze złożem |

**Kilka wyglądów jednego obiektu natury (2026-11-10):** `<stan>.png` to wygląd 1, `<stan>_2.png`, `<stan>_3.png`… kolejne (drzewo: 5 gatunków). Widok (`NatureLayer`) sam liczy wyglądy po plikach `grown_N` i wybiera jeden na stałe ze współrzędnych kafla.
| Stosy w magazynie | `stacks/<good_id>.png`: arkusz klatek po 64 px szerokości (romb 1 kafla w dolnych 32 px + wysokość); **G2:** jedna klatka na sztukę (`stack_size` klatek, 64×96), starsze arkusze 4 klatki (25/50/75/100%), gra liczy klatki z szerokości obrazka | wszystkie towary |
| Ikony towarów | 32×32 | wszystkie |

**Punkt zaczepienia stosów i natury (M2):** romb kafla zajmuje **dolne 32 px** obrazka (lub klatki stosu). Środek rombu, czyli punkt `(szerokość/2, wysokość − 16)`, leży na środku kafla. Placeholdery: stos 64×64 na fazę, drzewo 64×96.

### 8.1 Teren organiczny (decyzja 2026-11-05)

Teren **nie jest układany z kafli przejść** (autotile). Gracz nie widzi siatki ani rombów, a granice terenów są zaokrąglone i nieregularne.
- **Tekstura** terenu to romb 64×32 bez obramowania. Shader próbkuje ją okresowo w przestrzeni świata, więc sąsiednie kafle nie mają szwów. Jedna tekstura wystarcza na cały teren danego typu; drugi wariant (`b`) miesza się z pierwszym w miękkich plamach, żeby wzór się nie powtarzał.
- **Kształt** terenu bierze się z mapy kafli (symulacja widzi całe kafle), ale shader wygładza ją między środkami kafli i przesuwa granice szumem o ok. ⅓ kafla. Skośne „schodki” stają się prostymi liniami, a narożniki są zaokrąglone. Drogi też: plac to po prostu kilka kafli drogi obok siebie.
- **Pasy przy granicach** rysuje shader: skarpa (`bank/a`) na lądzie przy rzece, ciemna linia cienia na wodzie przy skarpie, płycizna (`sea/shallow`) i piana przy plaży, wytarty, „rozsypany” brzeg drogi.
- **Trawa** ma dodatkowo jaśniejsze i ciemniejsze plamy (`grass/light`, `grass/dark`), a kwiatki i koniczyna (`grass_decor/*`) leżą w przypadkowych miejscach, nie na środku kafla.
- Brzegi plam są rozpraszane wzorem pikseli (dithering), a nie przez półprzezroczystość, więc teren zostaje ostrym pixel artem.
- **Woda jest animowana** (decyzja 2026-11-05): tekstura rzeki i morza przesuwa się pod nieruchomym brzegiem o całe piksele (rzeka szybciej, bród wolniej, morze powoli w inną stronę), na wodzie migoczą pojedyncze jasne odblaski, a piana na plaży podchodzi i cofa się falami, nierówno wzdłuż brzegu. Bez nowych grafik.
- **Duże tekstury bez powtórzeń** (poprawki z oceny 2026-11-07, paczka 3): jezioro i kamienisty grunt mają wzór na **4×4 kafle** (obraz 256×128 z rombem 4×4 kafli; wzór zawija się w przestrzeni siatki, więc kopie stykają się bez szwu) w **3 wariantach** (`big_a`, `big_b`, `big_c`) mieszanych w miękkie plamy. Kamienie leżą osobno: dwie przezroczyste warstwy `stony/rocks_a` (co 5 kafli, 320×160) i `stony/rocks_b` (co 7 kafli, 448×224), więc układ kamieni powtarza się dopiero co 35 kafli i żaden kamień nie jest ucięty brzegiem kafla ani plamą wariantu. Generator: `python3 tools/generate_terrain_variants.py` (ziemia i woda rysowane kodem w paletach kafli PixelLab, kamienie wycięte w całości z `stony/a` i `stony/b`).
- **Miękki brzeg (B1, część 2):** granica wody i lądu (i płycizny z głębiną) to linia 0,5 wygładzonej mapy wody (krzywa B-sklejana na 4×4 kaflach), marszczona słabiej niż inne granice (`shore_warp` 0,12 zamiast `border_warp` 0,32); środek kafla (`shore_core` 0,14) zostaje taki jak w siatce. Wyłącznik do porównań: `soft_shore`.
- **Ujścia rzek** (paczka 3): gdzie woda rzeki spotyka jezioro albo morze, obie wody mieszają się wzorem pikseli w pasie ok. 1,5 kafla w każdą stronę (udział drugiej wody maleje z odległością, brzeg pasa jest nierówny); każda woda przesuwa się po swojemu, a morze przy ujściu jest płytkie.
- **Pola** zostają kaflami (to dzieło ludzi, prostokątne z natury).
- Nowy typ terenu: tekstura w `assets/terrain/<id>/` i miejsce (slot) w shaderze `src/view/terrain/organic_ground.gdshader` oraz w `TerrainLayer.SLOT_BY_TERRAIN`.

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
5. **Teren:** tekstury z `create_tiles_pro` (16 niezależnych rombów 64×32 za 10–15 generacji; wzór stylu: nasza trawa). Przejścia i kształty rysuje shader (§8.1), więc zestawy autotile nie są potrzebne.
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
- **Przemalowanie naszego wzoru (`edit_image`, 10 generacji za obraz do 256×256) to najlepsza droga do murów i bram.** Wzór renderuje `src/prototype/walls/export_reference.gd` (mur i brama rysowane kodem, przezroczyste tło). PixelLab zachowuje obrys: 99,7% (brama) i 100% (mur) pikseli pokrywa się ze wzorem, a styl jest dużo bogatszy (jasny piaskowiec, drewniany dach, ostry łuk z broną). Wynik leży więc dokładnie na naszej geometrii i da się go pociąć na kawałki według §6. Do ustalenia: jak ciąć obraz na kawałki i jak zachować spójność między seriami (ten sam opis i ta sama referencja).
- **Cięcie przemalowania na kawałki działa** (`src/prototype/walls/repaint_skin.gd`, klawisz K w piaskownicy przełącza mur z PixelLab i mur rysowany kodem):
  - z przemalowanego muru wycinamy 3 próbki i prostujemy je do prostokątów: ścianę jasną (+y, 2 kafle), ścianę ciemną (+x, 1 kafel) i wierzch korony (2×1 kafla); kod rysuje nimi mur w dowolnym kształcie, a blanki dostają średni kolor kamienia,
  - wieżę bramną wycinamy z przemalowania maską z rzutu jej kawałków i używamy jak grafiki budynku (paski z `BuildingSlicer`); druga orientacja to odbicie lustrzane, więc światło jest wtedy odwrócone (przy grafice docelowej: osobne przemalowanie drugiej orientacji),
  - próbki muszą pochodzić z miejsc niczym nie zasłoniętych i w całości na obrazku, z dala od narożników (tam wzór ma kontury i cienie), inaczej wychodzą smugi albo pionowe linie co kafel,
  - próbki są bezszwowe: wycinamy 8 px więcej i płynnie przenikamy nadmiar w początek próbki.
- **Tilesety właściciela projektu są top-down (kwadratowe Wang, 64×64).** Jednolite kafle (trawa, zaorana ziemia) da się rzutować na romb 64×32 (obrót o 45° i spłaszczenie, próbkowanie najbliższym pikselem). Wychodzi bez szwów, a faktura trawy i bruzd wygląda naturalnie. Kafle przejść (brzegi) po rzutowaniu nie pasują do naszych sąsiedztw, więc przejścia trzeba robić osobno. Trawa jest bardziej nasycona niż paleta z §1.
- **Sieć:** środowisko w chmurze ma dostęp do `backblaze.pixellab.ai` (Allowed domains), więc pliki pobieramy bezpośrednio.

### 10.2 Teren (2026-11-05)

- **`create_tiles_pro`, niezależne kafle izometryczne 64 px:** 16 rombów 64×32 na płótnie 64×64 za 10 generacji (ze wzorem stylu z obrazka: 15). Faktura trawy, wody, piasku, drogi i ściółki jest dobra.
- **Kafle mają przyciemnione dolne krawędzie** (jakby miały grubość, mimo `tile_depth_ratio=0`). Ułożone obok siebie dają widoczną kratkę. Poprawka: `tools/pixellab_tile_edges.py` wyrównuje jasność pasa przy każdej krawędzi do środka kafla i przycina wynik do rombu 64×32.
- **Nawet idealne styki nie ukryją siatki,** bo oko łapie powtarzający się co 64 px wzór. Rozwiązanie to teren organiczny (§8.1). Wzory o dużym kontraście (fale na wodzie) trzeba złagodzić (zmieszać ze średnim kolorem) i mieszać dwa warianty.
- PixelLab nie ma narzędzia, które gwarantuje bezszwowe kafle izometryczne ani organiczne przejścia (potwierdzone w ich pomocy). Ponownie sprawdzone 2026-11-07 (dokumentacja MCP i pomoc): dalej brak opcji „bez szwów” i zawijania przy domalowywaniu, dlatego duże tekstury jeziora i kamienistego gruntu rysuje kod (§8.1).
- **Druga paczka (M4b-3, 15 generacji):** `create_tiles_pro` w trybie stylu z trzema kaflami pierwszego zestawu (łąka, droga, bruk) jako wzorem. Udane: kamienisty grunt ×2, spękana skała, żwir, woda jeziora, bagno ×2, glina, ściernisko, lód, torf. Nieudane (krzywy kształt albo inny materiał): płytki brzeg, sucha trawa, błoto, spalona ziemia, śnieg. Woda jeziora miała jasne i ciemne krawędzie mimo `pixellab_tile_edges.py`, więc kafel złożono od nowa ze środka oryginału (lustrzane powtórzenie, bez szwów) i zmieszano w 35% ze średnim kolorem.

### 10.3 Budynki rysowane kodem (2026-11-05)

**Decyzja właściciela projektu:** zanim powstaną grafiki z PixelLab albo ręczne, budynki rysuje kod, starannie, jako grafiki docelowe w `assets/buildings/` (placeholdery zostają bez zmian). Narzędzie: `tools/generate_art.gd`.

- **Bryły zamiast klocków:** budynek składa się z kilku brył: dom z dachem dwuspadowym lub czterospadowym, przybudówka, otwarta wiata (widać pracę w środku: piec, kozioł z kłodą, kocioł, bloki kamienia), okrągła wieża ze stożkowym dachem (wiatrak, suszarnia chmielu), wieża z iglicą (kościół, kaplica, ratusz z zegarem). Bryły rysujemy od tyłu do przodu.
- **Bryła mniejsza od kratek:** ściany stoją ok. 0,14 kafla od krawędzi footprintu, więc wokół budynku widać ziemię. Wyjątek: domy mieszczańskie w pierzei stykają się wzdłuż rzędu.
- **Materiały** w układzie każdej ściany i połaci: szachulec, kamień, bale, deski, tynk, strzecha, gont, dachówka, łupek. Okna z okiennicami, drzwi zawsze na kaflu wejścia, kominy na dachu.
- **Warianty wyglądu:** `BuildingVisualDef.base_variants` (pliki `base`, `base_2`, `base_3`...). Budynek wybiera wariant według położenia na mapie. Chata ma 3: szachulcowa z drewutnią, z bali z przybudówką, tynkowana w kształcie litery L. Placeholdery mają te same nazwy plików.
- **Place budowy:** faza 1 to kamienny fundament, paliki ze sznurkiem i sterty materiałów, faza 2 to szkielet z belek i krokwi, część deskowania, rusztowanie i drabina.
- Światło według §1, kontur 1 px w ciemniejszym odcieniu własnego koloru. Rozmiary i pivoty jak w §3.2. Plik `.json` obok każdego `.png`.
- **Skala (2026-11-05):** ściany parteru 36–42 px, drzwi ok. 26 px, okna ok. 9×12 px, dom mieszczański 58 px (dwa piętra), żeby pasowały do postaci 34 px (§3.1).
- **Ograniczenie:** rysunek z prostych brył, czytelny, ale nie ręcznie malowany. Każdy plik można później podmienić lepszą grafiką bez zmian w kodzie.
- **Jeszcze niezrobione:** plac magazynu (rysuje go widok jako brązowy romb).

### 10.4 Postacie rysowane kodem (2026-11-05)

Narzędzie: `tools/generate_characters.gd`, wynik w `assets/characters/<zawód>/`. Każdy zawód ma własną postać (`data/visuals/agents/<zawód>.tres` wskazuje ją bez zabarwienia).

- Ciało z części w przestrzeni postaci (nogi, buty, tułów, ręce, głowa, włosy, broda, kapelusz, fartuch, sukienka, peleryna, narzędzie), obracane do 5 kierunków (S, SE, E, NE, N; reszta to odbicia, §4.2) i rysowane od tyłu do przodu. Rysowane dla 42 px i zmniejszane wokół stóp do ok. 34 px (§3.1), stopa w (32, 58), kontur 1 px.
- Stroje według §4.4: rolnik i chmielarz w słomkowym kapeluszu, młynarz w białym fartuchu i czapce, piekarz w białym czepku i fartuchu, drwal w czerwonej koszuli z brodą, tragarz z czerwoną chustą, budowniczy w skórzanym fartuchu, wędkarz w kapeluszu z szerokim rondem, domowniczka w sukience z chustką, przybysz w kapturze z kosturem.
- Animacje: `idle` (4 klatki), `walk` i wszystkie `walk_carry_*` (8 klatek, z mapą zaczepień), `work` (ogólna) i `work_<czynność>` dla czynności zawodu: zamach nad głową (rąbanie, kucie, orka, budowa), praca nisko (żniwa, ociosywanie), pchanie (piła, ciasto, łopata do pieca), mieszanie (żarna, kadź, kocioł), siew, wiązanie, zarzucanie wędki, czekanie na branie, wyciąganie ryby.
- **Ograniczenie:** postać 42 px rysowana z kształtów. Czytelna przy zoomie 1–2×, ale mimika i drobne ruchy są uproszczone. Warianty kolorów (§4.4) jeszcze nie.

### 10.5 Towary i natura rysowane kodem (2026-11-05)

Narzędzie: `tools/generate_goods.gd`, wynik w `assets/goods/` i `assets/nature/`.

- **Stosy w magazynie** (4 etapy zapełnienia): kłody w piramidzie z widocznymi czołami, deski w równych warstwach, worki mąki, snopy zboża, skrzynie z chlebem i rybami, kosze chmielu, beczki piwa, bloki kamienia. Przedmioty to małe bryły ułożone na kaflu od tyłu do przodu, więc stos rośnie jak prawdziwa sterta.
- **Towary w rękach** (§5, 5 wierszy po 24×24) i **ikony** 32×32 rysowane tymi samymi kształtami.
- **Skały:** grupa głazów ze światłem z góry, pęknięciami i mchem; po wydobyciu mniejsze głazy, na końcu gruz. **Drzewo:** pień z gałęziami i korona z kęp liści; ścięte leży obok pnia; zostaje pień z korzeniami.


### 10.6 Morze i statki rysowane kodem (M5, część 1, 2026-11-06)

- **Budynki nad wodą** (`tools/generate_art.gd`): smolarnia (chata z bali, dół smolny jako kopiec ziemi z dymkiem i kranikiem, beczki smoły), stocznia (warsztat, otwarta szopa z deskami, żuraw, pochylnia z szynami i klocami opadająca do wody, kładka na palach), przystań rybacka (chata z suszarnią ryb i sieciami, pomost na palach z pachołkami). Nowy element „deck”: pomost albo pochylnia na palach, rysowany przed bryłami budynku.
- **Statki** (`tools/generate_ships.gd`): łódź to mały model 3D (burty z pierścieni, ławki, rybak w kapeluszu, wiosła, sieć) rzutowany jak budynki, z ciemnym obrysem. Woda wokół łodzi (fale, kilwater), wiosła i sieć są rysowane po obrysie, cienką kreską.
- **Postacie** (`tools/generate_characters.gd`): cieśla okrętowy (młotek, fartuch), smolarz (okopcony, z drągiem), rybak (kapelusz, broda).
- **Towar:** smoła w ciemnej beczce z zaciekiem.

### 10.7 Port i kupiec morski rysowane kodem (M5, część 2, 2026-11-06)

- **Port** (`tools/generate_art.gd`): nabrzeże na palach na dwóch rzędach wody, żuraw portowy ze skrzynią na linie, beczki, pachołki cumownicze, latarnia i słupki bramy przy wejściu. **Kafle lądowe portu są w grafice przezroczyste:** plac portowy (deski) i stosy towarów rysuje widok (`QuayYard`), żeby budynek nigdy nie zasłaniał towaru czekającego na załadunek.
- **Kupiec morski:** obca koga z prototypu w 8 kierunkach z delikatnym kołysaniem (`tools/render_cog.py <id> <kolor frakcji>`, ok. 3 min, Python z Pillow i numpy).
- **Postać:** portowiec (chusta na głowie, fartuch, czynność `hand_over`: podaje towar na trapie).

### 10.8 Koga gracza i obóz pionierów rysowane kodem (M5, część 3, 2026-11-06)

- **Koga gracza:** ta sama koga co u kupca, w kolorze gracza (granat `46,84,168` na żaglu, tarczach i fladze): `python3 tools/render_cog.py cog 46,84,168`. Koga z osadnikami na starcie „Wybrzeża” używa tej samej grafiki (`ShipDef.art`).
- **Etapy budowy na pochylni:** `python3 tools/render_cog.py cog 46,84,168 --stages` (ok. 10 min) rysuje `build_0.png` (stępka, dziobnica, rufa i wręgi), `build_1.png` (poszyty i osmołowany kadłub z kasztelami) i `build_2.png` (maszt z żaglem, liny, flaga, tarcze). Kadłub stoi na czterech klocach, cały nad wodą; czwarty etap, wodowanie, to w widoku zjazd kadłuba `build_2` z pochylni na wodę. Format jak arkusz pływającej kogi: 220×220, 8 wierszy kierunków, po jednej klatce.
- **Obóz pionierów** (`tools/generate_art.gd`): chata z bali kryta strzechą, dwa płócienne namioty, ognisko z kociołkiem na trójnogu, sągi drewna, beczka, łopata i chorągiew.


### 10.9 Wino i szlaki rysowane kodem (M6, część 3, 2026-11-06)

- **Winnica i tłocznia** (`tools/generate_art.gd`): winnica 3×3 to kamienny dom winogrodnika z dachówką i szopą, przed nim tyczki z krzewami, kosze i beczka; tłocznia 2×2 to kamienny dom z otwartą przybudówką, w której stoi kadź i stojak na beczki. Na razie złożone z istniejących elementów (dachy, kadzie, beczki); prawdziwa prasa ślimakowa może przyjść z PixelLab.
- **Towary** (`tools/generate_goods.gd`): kosz winogron (wiklinowy kosz z fioletowymi kiśćmi i liściem winorośli, niesiony jak kosz) i beczka wina (beczka z czerwonym wiekiem i fioletowym znakiem, niesiona jak beczka).
- **Postacie** (`tools/generate_characters.gd`): winogrodnik (fioletowa koszula, słomkowy kapelusz, nożyk do cięcia), winiarz (jasna koszula, bordowy fartuch i czapka). Czynność „press” (tłoczenie) to ruch „push”.
- **Ziemia winna i krzewy** (`tools/generate_placeholders.gd`, placeholdery): ciepła, czerwonobrązowa ziemia z grudkami i kępkami trawy (`terrain/vine_soil/a.png`, nowe miejsce `VINE` w shaderze terenu) i pola winnicy `terrain/field_grapes/` (rzędy tyczek; krzewy gęstnieją z każdym etapem, dojrzałe mają fioletowe grona).
- **Skład kupiecki i wóz kupiecki (2026-11-07):** skład to dwupiętrowy magazyn z muru pruskiego z dachówką i otwartą wiatą (beczki, worki, wóz); wóz kupiecki (`vehicles/trade_wagon/`, `tools/generate_goods.gd`) to dłuższy wóz konny z wysokim płóciennym dachem na obręczach, te same klatki co zwykły wóz (112×80, 5 rzędów).
- **Uwaga:** `tools/generate_art.gd` przy okazji rysuje od nowa kamienice patrycjuszy (`assets/buildings/hut/level_3_*`), a te w repozytorium są dopracowane ręcznie. Po uruchomieniu przywróć je: `git checkout assets/buildings/hut/`.

### 10.9a Nabrzeża rysowane kodem (N1, część 1, 2026-11-07)

- `QuayLayer` (widok, bez plików grafik): pomost to deski w poprzek kafla, belka na krawędzi i pale w wodzie; nabrzeże kamienne to płyty w dwóch rzędach z przesuniętymi spoinami, jasna krawędź i ściana z mokrym pasem przy wodzie. Pokład na wysokości lądu; ściana opada do wody (kamień 20 px z profilem według referencji właściciela z Anno 1404: przypory z kamienną czapą i pachołkiem na każdym rogu kafla, między nimi łukowe wnęki schodzące pod wodę, gzyms wzdłuż górnej krawędzi, warstwy bloków i pas wodorostów; pomost 14 px w stylu Anno: belka z końcami desek, listwa, okrągłe pale wystające przed lico, zastrzały na krzyż, wysokie słupy cumownicze na rogach, czasem drabinka; deski pokładu w różnych odcieniach z gwoździami; na lądzie krawężnik od strony ziemi, a bok zwrócony do kamery schodzi trójkątem po skarpie, od pełnej wysokości przy wodzie do zera 2 kafle w głąb lądu: kamień z warstwami i ziemią u stopy, pomost z coraz krótszymi palami), a pod linią wody z pianą idzie dalej 16 px, coraz bardziej w kolorze wody. Boki tylko od strony wody i tylko widoczne dla kamery. Skos w 8 kierunkach ma ścięte kliny, więc jego boki są proste.
- `BridgeLayer` (B1, widok, bez plików grafik): pokład i boki mostu tym samym kodem co `QuayLayer` (drewniany jak pomost na palach, kamienny: ściana z ciosów z jednym łukiem w każdym boku kafla, przez łuk widać ciemną wodę, gzyms pod pokładem). Na brzegach rampa: bok opada od pełnej wysokości przy wodzie do zera na końcu kafla lądu. Poręcze (drewno: słupki i dwie żerdzie, 7 px) i murki (kamień: 9 px z jaśniejszym zwieńczeniem) stoją wzdłuż mostu, także na rampach, gdzie się obniżają; nie ma ich na wjazdach. Każdy odcinek poręczy to osobny węzeł w świecie z sortowaniem po środku boku, więc ludzie przechodzą przed tylną i za przednią poręczą. Bok biegnący na ekranie pionowo (most po skosie) jest rysowany lekko z góry: słupki wychylone o 6 px na zewnątrz z jasnymi główkami i żerdzią, murek jako pas kamienia wychylony o 3 px ze zwieńczeniem, a na pokładzie przy nich pasek cienia.
- Port, przystań i stocznia (pas obok pochylni) nie mają już pomostu w grafice (`tools/generate_art.gd`): ich pas nad wodą rysuje `QuayLayer`, więc łączy się z nabrzeżem gracza. Miejsce cumowania to same rekwizyty (pachołki, latarnia, beczki, sieci) na nabrzeżu.
- Zrzut: `game_shot.tscn -- --map=coast --tile=76,84 --zoom=2 --port --quays`.

### 10.9b Dźwig i magazyn portowy (N1, część 2, 2026-11-07)

- **Dźwig** (`tools/generate_art.gd`, `crane`, 2×2; masywniejszy po uwadze właściciela 2026-11-07): kamienny cokół z drewnianym podestem, gruby maszt z kantówki (bryła 3D, jasna i cienista ściana, żelazne opaski z nitami) na czterech zastrzałach ze stężeniami, obrotowy kołnierz z okuciem na wysokości ok. 95 px i daszek z gontu nad krążkiem na szczycie; przy wejściu duże koło deptakowe (obręcze 22 px, 28 szczebli, podwójne szprychy, bęben z nawiniętą liną, ciężkie kozły na podwalinach). Ramię, liny, hak i ładunek nie są w grafice: rysuje je `CraneLayer` (gruba belka ramienia z okuciami, zastrzał od masztu, lina od daszku, blok z krążkiem na końcu, blok haka z żelaznym hakiem; ramię kończy się 100 px nad placem albo statkiem, hak wisi 66 px nad ziemią w czasie obrotu, a przy statku opuszcza się do pokładu, 26 px), więc dźwig obraca się w stronę każdego miejsca cumowania. Ładunek to do 3 ikon towaru (`goods/icons`) w siatce z lin. Dźwigowy ma wygląd portowca i „idzie” w kole.
- **Koga przy nabrzeżu** (uwaga właściciela 2026-11-07: wchodziła na nabrzeże): statek staje 0,45 kafla za środkiem miejsca cumowania (`Harbour.MOOR_OFFSET`), a widok rysuje kadłub kogi jeszcze 0,5 kafla dalej (`ShipLayer.MOORED_HULL_SHIFT`, narasta przy podpływaniu), więc między burtą a nabrzeżem widać wodę, a trap i portowiec na pokładzie sięgają bliższej burty.
- **Magazyn portowy:** plac jak zwykły magazyn (`yard`), rysowany przez widok na nabrzeżu.
- Zrzut: `game_shot.tscn -- --map=coast --tile=73,103 --zoom=2 --port --quays --crane [--lift=<0..1>]`.

### 10.9c Poprawki z oceny, paczka 2 (2026-11-07)

- **Podwórko warsztatu** (`tools/generate_art.gd`): budynek, którego pracownik odkłada wyroby na stos, zostawia wolny kafel obok drzwi, przy tej samej ścianie (`BuildingDef.yard_at`; 2×2 z wejściem (1, 1): kafel (1, 0)). Generator rysuje tam ubitą ziemię z wiórami i kamyczkami, a chatę stawia na pozostałych kaflach (w 2×2 zwykle `rect` do x = 1,0, ścianą z drzwiami tuż za kaflem wejścia; drzwi dostaje też ściana do 0,15 kafla za kaflem wejścia, `DOOR_REACH`). Na kolumnach ekranu podwórka przed nim nie może stać nic wysokiego (kafel wejścia po stronie podwórka zostaje pusty), bo stos jest rysowany na wierzchu pasów budynku.
- **Stos na podwórku** (`PileLayer`): dwie połówki po 32 px, każda sortowana zaraz za pasem budynku nad jej kolumnami, więc ściany za podwórkiem nigdy go nie zasłaniają (test `test_yard_stack_sorts_correctly`).
- **Koła** (`tools/generate_goods.gd`): arkusze `vehicles/handcart`, `wagon`, `trade_wagon` mają 4 kolumny (`WHEEL_FRAMES`), szprychy obrócone o 1/6 obrotu w 4 krokach; widok przełącza je 10 razy na sekundę, gdy postać idzie (wiersze lustrzane w odwrotnej kolejności).
- **Winorośl** (`tools/generate_goods.gd`): `nature/vines/{pruned,bud,leaf,full,ripe}.png`, 64×56, środek kafla na ziemi w (32, 44); jeden rząd na kafel wzdłuż osi x siatki (pal na obu końcach, linki na 9 i 17 px, dwa krzewy). Ziemia pola: `terrain/field_grapes/<etap>.png` (ziemia winna, ubity pas pod rzędem, trawa między rzędami). Rysuje je `VineLayer` (sortowany jak drzewa).
- **Wodowanie kogi** (`ShipLayer`): zjazd w ostatnich `LAUNCH_SLIDE` = 8 s etapu, krzywa „smoothstep”; od początku zjazdu kadłub to klatka `idle` kogi (bez klocków), a zwodowana koga przy pochylni (do 1,2 kafla od miejsca cumowania) sortuje się jak kadłub na pochylni.

### 10.10 Interfejs „pergamin i drewno” i menu główne (UI-1, 2026-11-07)

- **Skala:** grafiki interfejsu i menu mają piksel rysunku = 2×2 piksele ekranu bazowego 1280×720 (jak obraz menu 640×360 w skali 2). Nic nie jest rysowane w skali 1 ani skalowane nierówno.
- **Grafiki interfejsu** (`tools/generate_ui.gd` → `assets/ui/`): `panel.png` (pergamin w ramie z ciemnego drewna z żelaznymi okuciami w rogach; dziewięć pól z marginesem 12 px), `panel_inset.png` (ciemniejszy pergamin bez okuć: pola tekstowe), `button_{normal,hover,pressed,disabled}.png` (drewniana tabliczka ze złotymi ćwiekami; wciśnięta niżej o 1 piksel rysunku), `board.png` (deski z gwoździami: pasek u góry i menu budowy, powtarzane w poziomie), `tooltip.png`, ikony 10×10 rysunku: `icon_gold`, `icon_people`, `icon_workers`, `icon_time`. Środki i krawędzie dziewięciu pól są powtarzane, nie rozciągane (włókna pergaminu i słoje drewna zostają piksel w piksel).
- **Kolory tekstu** (`UiKit`): atrament `INK` na pergaminie, wyblakły atrament `INK_SOFT` na podpowiedzi, czerwonobrązowe nagłówki `HEADING`, zielony `GOOD` i czerwony `BAD` dla bilansów, jasny `LIGHT` z ciemnym obrysem na drewnie i nad miastem (powiadomienia), złoty `GOLD` dla złota w pasku.
- **Obraz menu głównego** (PixelLab, „Create Image (Pro)”, 640×360, wariant 2 z 3, wybór właściciela 2026-11-07): koga z granatowym żaglem wpływa do portu, tragarz z workiem na nabrzeżu pełnym skrzyń i beczek, miasto z kościołem i zamkiem na wzgórzu, pogodny dzień, po lewej wolne morze i niebo na menu. Źródło: `assets/ui/menu/source.png`. Warstwy tnie `python3 tools/split_menu_art.py`: `sky.png` (niebo; pod lądem niebo ciągnie się w dół), `land.png` (miasto, morze, statek i nabrzeże bez nieba), `water.png` (maska otwartego morza); każda warstwa ma 8 pikseli powtórzonej krawędzi. Kawałki nieba zamknięte przez olinowanie dopisuje się do `EXTRA_SKY` albo leżą w prostokącie `RIGGING` (każdy prześwit nieba w nim jest niebem). **Poprawki z oceny (paczka 3):** za lądem niebo ma kolor najbliższego piksela nieba (bez pionowych smug), a zapas wokół warstw to lustrzane odbicie obrazu (nie rozciągnięta krawędź).
- **Ruch w menu** (`MenuBackdrop`): niebo przesuwa się do 2, a ląd do 5 pikseli rysunku za myszą (nigdy więcej niż zapas 8 pikseli), doganiając ją jak na sprężynie bez przeskoku w ok. 0,45 s (paczka 3); po niebie, za miastem, płyną 3 małe chmury; z 3 kominów leci dym; krążą 4 mewy; otwarte morze migocze (shader `water_glint.gdshader` na masce wody).

### 10.11 Próba budynków z PixelLab (2026-11-07, przed G1)

- **Zadanie:** obóz pionierów (3×3) i chata (2×2) wygenerowane od zera, na płótnie jak obecne grafiki (216×152 i 152×152), opis „isometric … seen from above at 45 degrees (two walls visible) … on a 2:1 isometric diamond footprint”. Wstawione na próbę do sceny gry (przycięte do zawartości, pivot w najniższym pikselu). Pliki: `src/prototype/g1/`.
- **`create_object_pro_flash`** (widok „high top-down”, 1 kierunek; 6 generacji przy 152 px, 9 przy 216 px): **wybrany**. Ciepłe kolory, strzecha, belki, dobrze pasuje do terenu. Wychodzi mniejszy niż płótno (obóz 142×108 zamiast ok. 192 szerokości), drzwi chaty na prawej ścianie.
- **`create_map_object`** (widok „high top-down”, „high detail”): chata ładna, ale bardziej bajkowa i trochę za duża; obóz wyszedł jako wysepka ze skarpą ziemi pod spodem (do odrzucenia).
- **Za ciemne:** budynki Pro Flash są ciemniejsze niż teren. Rozjaśnienie skryptem `python3 tools/brighten_pixellab.py <in> <out>` (krzywa gamma 0,65 na jasności i 95% nasycenia, poziom „średni” wybrany przez właściciela z trzech): ciemne i średnie tony jaśnieją, światła i kontury zostają. Stosujemy je do każdego budynku z PixelLab, żeby całe miasto było spójne.

### 10.12 Budynki z PixelLab, zestaw pionierów (G1, 2026-11-07)

Przepływ pracy dla kolejnych partii budynków z PixelLab:
- **Narzędzie:** `create_image_pixen` (1 generacja), `no_background`, `view: high top-down`, `direction: south-east`, `detail: highly detailed`, `outline: selective outline`. Płótno: 152×152 dla budynku 2×2 (wychodzi ok. 120–130 px szerokości), 120×120 dla wąskiej chaty warsztatu (2 tylne kafle), 32–96 dla drobnych elementów. Kilka ziaren (`seed`) i wybór najlepszego.
- **Opis:** zaczyna się od „isometric … 2:1 isometric view from above, two walls visible”, potem materiały, na końcu „warm earthy colors, no ground, no shadow”. **Drzwi:** dom „the wooden front door is in the gable wall facing the lower right”, wąski warsztat „the long side wall with the wooden door faces the lower right, the narrow gable end faces the lower left” (orientacja 0: drzwi na ścianie +x, §7). Pixen lubi dorysować płytę ziemi albo trawy: wtedy „the building stands directly on a transparent background, no ground tile, no grass, no terrain block”.
- **Przeróbki:** `edit_image_pixen` (1 generacja) na adresie gotowego obrazka. Etap 1: „remove the whole … completely, … only a flat low grey stone foundation outline … wooden stakes with a string, a pile of logs and a stack of planks”. Etap 2: „half-built … bare roof rafters …, scaffolding and a ladder”. Tył domu: „remove the door from the gable wall on the right and fill it with the same …, add a small window there instead”. Mniejszy rozmiar elementu: przeróbka z `width`/`height` mniejszymi od wejścia (model rysuje od nowa, nie skaluje).
- **Do gry:** surowe obrazki w `tools/pixellab_src/buildings/<id>/<nazwa>.png`, lista w `tools/build_pixellab_buildings.py`, a `tools/fit_pixellab_building.py` usuwa okruchy pikseli (rozjaśnienie z §10.11 wyłączone dla Pixena, decyzja właściciela 2026-11-07: Pixen jest tak jasny jak budynki z kodu; włącza je usunięcie `--no-brighten` z `COMMON`), ustawia budynek na kratkach (środek obrazka nad środkiem obrysu, najniższy piksel 4 px nad przednim rogiem), dorysowuje podwórko warsztatu i zapisuje `<nazwa>.png` z `.json` (pivot w przednim rogu). Etap budowy i tył biorą przesunięcie gotowego budynku (`--like`), więc leżą dokładnie na nim.
- **Ujednolicenie kolorów** (decyzja właściciela 2026-11-07, `tools/harmonize_pixellab.py`, wołane przez `build_pixellab_buildings.py` dla całego zestawu): piksele dzielą się na materiały (szarości, czerwień, ciemne drewno, słoma i jasne drewno, zieleń, niebieski łupek); odcień i nasycenie każdego materiału budynku dociągamy do średniej całego zestawu, jasność budynku w 3/4 do średniej zestawu, a wszystkie szarości dostają ten sam ciepły odcień. Etapy budowy i tyły biorą korektę swojego gotowego budynku. Cieniowanie zostaje.
- **Obóz pionierów** jest złożony z osobnych elementów (`tools/compose_pixellab_camp.py`, części w `parts/`), bez własnego gruntu, w rombie 3×3.
- **Sortowanie:** grafiki są szersze niż z kodu (okap, rekwizyty), więc `test_pixellab_building_art_sorts_correctly` sprawdza każdą z jej prawdziwym pivotem i rozmiarem, także w lustrze.
- Nie przywracamy tych budynków przez `tools/generate_art.gd`: po nim `git checkout assets/buildings/{pioneer_camp,hut,woodcutter,quarry,fishing_hut}/` albo `python3 tools/build_pixellab_buildings.py`.

### 10.13 Towary z PixelLab i stosy sztuka po sztuce (G2, 2026-11-07)

- **Sztuka towaru:** `create_image_pixen`, płótno **24×24** (sztuka wychodzi 14–23 px), `no_background`, `view: high top-down`, `detail: highly detailed`, `outline: selective outline`, opis „single isometric …, 2:1 isometric view from above, warm colors, no ground, no shadow”. Jedna generacja na towar; 21 towarów (świnia zostaje stadem). Beczki: każdy napój inna (piwo jasna z chmielem, wino ciemna z czerwoną plamą, miód pitny mała z mosiężnymi obręczami, miód okrągła z kapiącym miodem, smoła osmolona). Surowe obrazki: `tools/pixellab_src/goods/<towar>.png` (kłoda drewna to `wood.png`).
- **Stosy:** `python3 tools/compose_pixellab_stacks.py [<towar>…]` układa sztuki w arkusz `assets/goods/stacks/<towar>.png`: `stack_size` klatek po 64×96, klatka k pokazuje k+1 sztuk. Układy zaprojektowane ręcznie (`LAYOUTS`): warstwy w siatce na kaflu, każda wyżej o część wysokości sztuki i przesunięta o pół kroku (piramida kłód 6-5-4-3-2, deski warstwami na krzyż na całym kaflu (wzdłuż, w poprzek z odbitą deską, znowu wzdłuż; prośba właściciela), worki, kosze i bloki 3×3, 3×3, 2, beczki stojące 3×2, 2×2, 2, bele sukna, snopy stojące). Sztuki dochodzą warstwa po warstwie od tyłu do przodu, więc każda nowa jest widoczna. Kolory: `harmonize_pixellab.py` bez zmiany jasności (biała mąka zostaje biała), kamień rozjaśniony (`GAMMA`).
- **Gra:** `StackSprite` liczy klatki z szerokości arkusza (`FRAME_W` = 64) i pokazuje `fill_stage(ilość, stack_size, klatki)`, więc stare arkusze 4-klatkowe (świnie) działają dalej. Test: `test_goods_stacks.gd` (liczba klatek = `stack_size`).

### 10.14 Wojsko: budynki i towary z PixelLab, postacie kodem (M7, część 1, 2026-11-07)

- **Budynki (decyzja właściciela: PixelLab):** węglarz, kopalnia, huta, kowal, płatnerz, łuczarz (wąskie warsztaty na 2 tylnych kaflach z podwórkiem, płótno 120×120), stadnina, zbrojownia i koszary (3×3, płótno 232×176). Przepływ jak §10.12: Pixen, opis z drzwiami („the long side wall with the wooden door faces the lower right”), etapy budowy przeróbką gotowego budynku. Koszary mają drzwi na ścianie w lewo w dół (wejście `(1, 2)`), zbrojownia i stadnina w prawo w dół (`(2, 1)`). Ujednolicenie kolorów: wspólne odcienie liczone tylko z zestawu G1, więc zaakceptowane budynki się nie zmieniają (`harmonize(..., reference=...)`). Budowa: `python3 tools/build_pixellab_buildings.py <id>…`.
- **Towary:** sztuki 24×24 z Pixena (węgiel w worku, ruda, sztaba żelaza, włócznia, miecz, łuk, kolczuga); stosy `compose_pixellab_stacks.py` (włócznie i miecze na krzyż jak deski, łuki w równych rzędach), ikony i towary w rękach z tych samych sztuk: `python3 tools/make_goods_icons.py`. Koń rysowany kodem (stado jak świnie, prowadzony koń, ikona) w `tools/generate_characters.gd`.
- **Żyła rudy:** skała z rdzawymi pręgami, z grafiki skały: `python3 tools/make_ore_vein_art.py`.
- **Postacie kodem (`tools/generate_characters.gd`):** węglarz, górnik, hutnik, kowal, płatnerz, łuczarz, stajenny, rekrut i 4 rodzaje żołnierzy w barwach królestwa (czerwień i złoto jak herb gracza): włócznik (przeszywanica, kapalin, okrągła tarcza, włócznia z proporcem), łucznik (kaptur, skórzany kaftan z ćwiekami, łuk, kołczan), miecznik (kolczuga, tunika z krzyżem, hełm z nosalem, tarcza migdałowa, pochwa miecza), jeździec (koń w czerwonym czapraku, hełm garnczkowy z pióropuszem). Animacje: `idle`, `walk`, `work_drill` (pchnięcie włócznią, naciąganie łuku i strzał, cięcie mieczem). Zrzut: `game_shot.tscn -- --map=lakeland --tile=84,64 --zoom=2 --m7=army [--drill]`.

### 10.15 Mury, bramy i oblężenie (M7, część 2, 2026-11-08)

- **Kamień murów z PixelLab (decyzja właściciela: grafika muru i bramy z początku projektu):** `tools/make_wall_skin.gd` wycina z przeróbki PixelLab prototypu (`src/prototype/walls/pixellab/repaint/`) próbki lica jasnego i ciemnego oraz korony (bez szwów) i ciało wieży bramnej do `assets/walls/stone/` (+ `skin.json`: początek i okres próbek, kolor blanek i obrysu). Gra rysuje mury kodem z tymi teksturami (`WallPieceNode`), jak prototyp.
- **Budynki** `tools/render_fort_art.gd` (wymaga ekranu: `xvfb-run`): wieża bramna = ciało z PixelLab (prawe lico zamalowane kamieniem, bo przeróbka miała tam kawałek muru) + blanki modelu; baszta 2×2 o 48 px wyższa od muru (prośba właściciela: „troszkę wyższa”); etapy budowy: niższe ściany i rusztowanie; warsztat oblężniczy (wiata z belek, gonty, szkielet taranu, deski, drabina). Ikony narzędzi w `assets/walls/icons/`.
- **Obrócona wieża bramna (prośba właściciela 2026-11-08):** lustrzane odbicie dawało cień po złej stronie. Gra używa grafiki `<nazwa>_turned` zamiast odbicia, gdy taka istnieje (`BuildingLayer.oriented_art`; mechanizm można dać później innym budynkom). Dla gotowej bramy narzędzie odbija samą bryłę z PixelLab i przemalowuje jasność zewnętrznych ścian według stosunku jasności lic z oryginału (szczegóły z PixelLab zostają), a blanki rysuje od nowa w obróconym ustawieniu (poprawka 2026-11-08: odbite blanki miały cień po złej stronie); etapy budowy rysuje od razu obrócone.
- **Kodem w widoku:** palisada (zaostrzone bale z wiązaniami, uszkodzona ma złamane bale), schody (stopnie i lity bok), pęknięcia na uszkodzonym murze, taran (buda ze skór na kołach, okuta kłoda, nogi 4 ludzi, proporzec: czerwony królestwa albo czarny bandytów), drabina oparta o mur, polegli (pierwsza klatka postaci położona, plama krwi), strzały w locie, paski życia.
- **Postacie kodem** (`tools/generate_characters.gd`, `BANDITS`): bandyta (ciemny kaptur, przeszywanica, włócznia, tarcza w szarych barwach), bandyta z łukiem, drabiniarz (czerwona czapka, drabina na ramieniu). Barwy tarcz i proporców zależą od postaci (`royal`, `gold`).

### 10.16 Armie na mapie świata i okręt wojenny (M7, część 3, 2026-11-08)

- **Okręt wojenny** (kod, `tools/render_cog.py`): koga gracza z rzędem okrągłych tarcz na nadburciu wzdłuż całego śródokręcia (`--war`), żagiel, tarcze i flaga w czerwieni `168,40,36`: `python3 tools/render_cog.py warship 168,40,36 --war` (pływający, 8 kierunków × 4 klatki kołysania) i `... --war --stages` (etapy na pochylni `build_0..2`). Format jak koga: 220×220, środek na linii wody w (110, 168).
- **Mapa świata** (kod, `WorldMapCanvas`): armia to trzech małych żołnierzy pod chorągwią na drzewcu z liczbą żołnierzy obok (gracz: czerwień herbu, bandyci: czarna chorągiew z białą czaszką), rysowana 1,5 raza większa od miasteczek; wybrana pulsuje złotym kołem, czekająca u granic osady ma złoty pierścień. Obóz bandytów: cztery ciemne namioty wokół ogniska. Droga armii: przerywana linia przez kolejne prowincje (zielona: można, czerwona: nie).
- **Brama w palisadzie** (kod, `tools/render_palisade_gate.gd`, wymaga `xvfb-run`): dwa ciosane słupy (66 px) z belką i daszkiem z gontów, dwa skrzydła wrót z pionowych desek z zaostrzonymi końcami, dwoma okuciami, zastrzałem i kołem do ciągnięcia; `base`, `construction_1` (dwa niskie słupy), `construction_2` (słupy z belką); kafel 1×1, płot wzdłuż osi y, obrócona = odbicie. Palisada łączy się z bramą (`FortLayer`).
- **Mury osad neutralnych** to te same mury, wieża bramna i baszty co u gracza (część 2), stawiane przez grę wokół centrum osady.

### 10.17 Nowe jednostki (J1, część 1, 2026-11-08)

- **Żołnierze kodem** (`tools/generate_characters.gd`, `SOLDIERS`, ankieta 2026-11-08): halabardnik (zbroja płytowa na kolczudze: napierśnik z grzbietem i naramienniki, tunika królestwa, kapalin, halabarda z toporem, hakiem i szpicem), kusznik (przeszywanica, kapalin, kusza ze stalowym łęczyskiem, ruch `aim`: celuje, strzela w połowie, opuszcza i napina), ciężki zbrojny (zbroja płytowa, hełm garnczkowy, tarcza, morgenstern przy pasie albo w ręku), lekka jazda (przeszywanica, hełm z nosalem, okrągła tarcza, włócznia, koń). Generowanie: `"$GODOT" --headless --path . -s res://tools/generate_characters.gd -- --only=<rodzaj>`.
- **Broń** (kod zamiast PixelLab): kawałki 24×24 halabardy, kuszy i morgensternu rysuje `python3 tools/draw_weapon_pieces.py` w barwach kawałków włóczni i miecza (ciemny kontur, dębowe drzewce, stal z jasną krawędzią) do `tools/pixellab_src/goods/`; stosy jak zawsze `python3 tools/compose_pixellab_stacks.py halberd crossbow morning_star`, ikony i broń w rękach `python3 tools/make_goods_icons.py`.
- Zrzut: `game_shot.tscn -- --map=lakeland --tile=84,64 --zoom=3 --m7=army2 [--drill]`.
- **Balista** (J1, część 2, kod w `SiegeLayer`, jak taran): wielka kusza na dwóch kołach ze szprychami (obracają się w jeździe), kozioł pod nosem, łoże z rowkiem, ramiona wiązane żelazem; cięciwa do kołowrotu z bełtem, gdy naładowana, po strzale prosta; dwóch obsługujących za nią (pchają, kręcą kołowrotem); proporczyk czerwony albo czarny. Bełt w locie (`TroopsLayer`): gruby, z lotkami i żelaznym grotem, lot płaski.

### 10.18 Karawela, karaka i galeon (J1, część 3, 2026-11-08)

- **Kod** (`tools/render_cog.py <id> <r,g,b> --type=caravel|carrack|galleon [--war] [--stages [--stage=N]]`), według referencji właściciela (karawela Pinta, karaka Victoria, galeon). Model „dużego statku”: kadłub zaokrąglony przy dnie, burty zwężają się ku górze, dziób i rufa wystają nad wodę i wznoszą się łukiem, kasztele wyrastają z tego samego kadłuba (tylny w jednej albo dwóch kondygnacjach), relingi ochrowe z tralkami, ciemne listwy, okna rufowe, furty na galeonie, ster; maszty z żaglami jeden nad drugim (karawela po 1, karaka po 2, galeon po 3), bocianie gniazda, żagle łacińskie na tylnych masztach, bukszpryt (z żaglem na karace i galeonie), proporce na każdym maszcie; krzyż w barwie frakcji na żaglach. Klatki: karawela 270×270 (środek na linii wody w (135, 206)), karaka 320×320 (160, 246), galeon 370×370 (185, 290), `ShipLayer.BIG_FRAMES`.
- Wersje wojenne (`<id>_war`, barwa `168,40,36`, `--war`): tarcze wzdłuż śródokręcia; etapy budowy 0 i 1 to te same pliki co statku handlowego, etap 2 liczony osobno (`--stages --stage=2`).
- Koga liczy się tak jak przedtem (sprawdzone co do piksela).
- **Duża stocznia** (kod, `tools/generate_art.gd`, `large_shipyard`).

### 10.19 Słupek, chata i dom portowców (P2, część 1, 2026-11-09)

- **Kod** (`tools/generate_art.gd`, `-- --only=<id>`): `bollard` (kamienny słupek z żelazną czapą i liną, latarnia na słupie, zwój liny), `docker_hut` (chata z deskami i gontem, otwarta przybudówka z linami i workami, sieci, skrzynie), `docker_house` (piętrowy dom z muru pruskiego na kamiennym cokole i dachówką, wieżyczka z łupkowym dachem i chorągiewką, tylne skrzydło z desek, otwarta szopa z workami i beczkami, ręczny żuraw, skrzynie). Nowe elementy: `stone_bollard`, `rope_coil`, `lantern_pole`, `crate_stack`, `hand_crane`.
- `port_store` i `port_warehouse_small` są placami jak magazyn (`special: yard`); nowe podłogi magazynów w części 3.
- Chata budowniczych (P2, część 3): kod (`generate_art.gd -- --only=builders_hut`): dom z muru pruskiego na kamiennym cokole z gontem i kominem, otwarta szopa z deskami i kozłem, kamienie, kłody, łopata.
- Podłogi magazynów (P2, część 3, `StockpileView`): zwykły magazyn na drewnianym podeście (deski wzdłuż x, każda w innym odcieniu, przesunięte styki z gwoździami, legary wzdłuż tylnych krawędzi), magazyny portowe na kamiennych płytach (2 rzędy na kafel, przesunięte spoiny, jaśniejszy krawężnik); obie podłogi stoją 3 px nad ziemią, przednie krawędzie widać.
- Ikonki żołnierzy (P2, część 2): `python3 tools/make_unit_icons.py` → `assets/units/icons/<jednostka>.png`, 32×32, popiersie 16×16 z pierwszej klatki `idle` (głowa na środku tułowia), podwojone co do piksela.
- Pale pod budynkiem stojącym nad wodą rysuje `QuayLayer` (także 2 rzędy i nad głęboką wodą). Dom portowców stoi całą powierzchnią na kamiennym nabrzeżu zamiast drewnianego pomostu (`BuildingVisualDef.stone_strip`, prośba właściciela 2026-11-09), więc łączy się z kamiennym nabrzeżem obok w jedną bryłę.

### 10.20 Próba SpriteKiln: postacie z modelu 3D zamiast kredytów PixelLab (2026-11-09, test, nie decyzja)

Powód: kredyty PixelLab skończyły się po ok. 2 tygodniach. Szukamy darmowych narzędzi. **To test, a nie zmiana sposobu robienia grafik.** Gra niczego z tego nie używa.

- **SpriteKiln** (https://github.com/LucasJRamos/spritekiln, MIT, `pip install spritekiln`): postać opisana w YAML (szkielet, kształty, materiały, kanały animacji) renderowana jako model 3D i zamieniana na pixel art (paleta, kontur, cieniowanie). Działa na samym procesorze, więc także w chmurze, bez karty graficznej. 8 kierunków z jednego modelu, animacje z kanałów.
- Projekt: `tools/spritekiln/` (`.gdignore`, Godot go pomija). Styl zapisany w `spritekiln.toml`: postać 34 px, klatka 64×64, 8 kierunków bez odbić, kontur selektywny, światło z góry. **Kamera `pitch: 30`**, bo sin 30° = 0,5 daje nasz rzut 2:1. Domyślne 38° SpriteKiln nie pasuje. Paleta `art/specs/palettes/kingdom.yaml` (ziemista, z kolorów drwala z §10.4).
- Drwal testowy: `art/specs/characters/woodcutter/woodcutter.yaml`: czerwona tunika, broda, siekiera (zestaw `axe`), animacje `idle`, `walk` i `chop` (rąbanie oburącz, siekiera za głową w zamachu). Podglądy w `tools/spritekiln/previews/`. Render: `cd tools/spritekiln/art/specs/characters/woodcutter && spritekiln render woodcutter.yaml` (168 klatek w ok. 20 s). Wyniki (`out/`) są ignorowane przez git.
- **Wnioski z próby:** kierunki są w pełni spójne, poprawka to zmiana liczby i nowy render, nie zużywa kredytów. Wygląd jest bardziej „figurka 3D w pikselach” niż rysunek. Animacje pracy trzeba układać samemu (gotowy atak zestawu to cięcie mieczem). Punkt stopy SpriteKiln to (32, ~48), a nasz to (32, 58), więc przy imporcie trzeba przesunąć klatkę. Nie ma map zaczepień niesionego towaru (§4.5): przy przejściu trzeba by je zrobić z gniazd (`sockets`).
- Halabardnik testowy (2026-11-09): `art/specs/characters/halberdier/halberdier.yaml`: kapalin (zestaw `hat` ze stali), czerwona tunika ze złotym krzyżem (`paint`), stalowe ręce i naramienniki, halabarda (zestaw `spear` z dorobionym toporem i hakiem). Animacje `idle`, `walk` (ręka z halabardą spokojna) i `attack` (opuszcza halabardę i pcha szpicem). W pchnięciu sztuczki zestawu są wyłączone, a kąt drzewca zależy od kierunku (`pulse(yaw, …)`), żeby od przodu i od tyłu halabarda szła ukosem, a nie prosto w kamerę. Drzewce skrócone do 1,12, żeby pchnięcie mieściło się w klatce 64×64.
- Budynek testowy (2026-11-09): `art/specs/props/woodcutter_hut/woodcutter_hut.yaml`, chata drwala 2×2 jako `kind: prop` z jednym kierunkiem `[se]`: obrót o 45° daje romb 2:1 podłogi. Ta sama gęstość co postacie (`camera.scale` 0,05176), więc kafel ma 2,343 jednostki, a 2×2 ma 4,69. Bale to walce generowane raz skryptem (zazębione narożniki), dach z gontu to dwie płyty z `paint` (rzędy i ciemniejsze gonty), podmurówka, drzwi, pieniek z siekierą i stos drewna. Klatka 192×192, punkt SpriteKiln to środek podstawy, a nasz (przedni róg) leży 32 px niżej: (96, 154). Render jednego widoku trwa ok. 10 s.
- Chata „podkręcona” (prośba właściciela 2026-11-09), żeby była bliżej budynków z PixelLab: `render: {outline: dark, lines: depth+normal, light: classic, shading: toon}` tylko w tej chacie (jeden ciemny kontur, linie w zagłębieniach między balami, światło z lewej u góry, więc lewa ściana jest jaśniejsza, twarde stopnie cieni). Przednia połać to 6 osobnych rzędów gontów (`roof_c0..5`), w każdym przesunięte szczeliny i jaśniejsze gonty (`spots`), a pod dolną krawędzią rzędu cienka ciemna listewka (`roof_lines`). Linie malowane (`stripes`) na stoku ginęły. **Pułapka:** przy `shading: toon` materiał z `band: 0` robi się jasny, a ciemne linie muszą mieć `bands: [0, 1]`.
- Kamienice mieszczan z muru pruskiego (2026-11-09): generator `tools/spritekiln/gen_townhouses.py` pisze speki `art/specs/props/townhouse_<middle|end_a|end_b|corner_a>/` (działka 2×2, jak `hut` poziom 2, §7: 2–3 wąskie domy szczytem do ulicy, belki na tynku, podcień piętra, dachówka albo łupek, kominy, okiennice). Narożnik: dom szczytem do bocznej ulicy (oś −x) z drugim domem za nim, więc rząd za rogiem (w lustrze) dochodzi do niego od tyłu. Zrzut z obecnymi domami na trawie: `python3 tools/spritekiln/compose_townhouses.py` (`previews/townhouses_vs_current_2x.png`, zbliżenie `townhouses_closeup_3x.png`). Klatka 256×256, środek kamery `[0, 2.8, 0]`, nasz punkt to punkt SpriteKiln + 32 px w dół. Render jednego kawałka ok. 100 s (ok. 250 kształtów), 4 kawałki naraz na 4 rdzeniach. **Wynik:** rzędy łączą się bez szczelin, narożnik i rząd za rogiem pasują.
- Koga (2026-11-09): `art/specs/props/cog/cog.yaml`, 8 kierunków bez luster × 4 klatki kołysania (kanały `bob`, `pitch`, `roll` na kości `ship`), klatka 220×220, środek kamery `[0, 3.47, 0]` daje punkt dokładnie (110, 168) jak w grze. Kadłub to wydłużona elipsoida z prawie pionowymi burtami, cięta płaszczyzną na linii wody i dużym walcem wzdłuż burty (wznios ku dziobowi i rufie), wnętrze nadburcia wycięte drugą elipsoidą. Porównanie: `python3 tools/spritekiln/compose_cog.py` (`previews/cog_vs_current_2x.png`, animacja `cog_rocking_vs_current.gif`). Render 32 klatek ok. 6 min. Kierunki zgodne z arkuszem gry (S = dziób do kamery). Kadłub wyszedł wyższy nad wodą niż w obecnej kodze i nie ma piany przy burcie.
- **Lekcje (ściąga na następne sesje):**
  - Kolejność pracy: `spritekiln validate` po każdej zmianie, `pose --dirs all` do oglądania (ok. 4 s), `render` na końcu. Kilka wersji naraz: kopia speca z inną nazwą (`name:`), po teście usuń jej `out/` i `.kilncache/`.
  - Gotowe zestawy broni (`axe`, `spear`, `sword`) mają „sztuczki” (`cheat`), które same obracają broń do kamery. W animacjach pracy i ataku podłącz je do kanału (`with: {cheat: axe_cheat}`) i wyłącz (0) w klatkach, w których broń ma iść tam, gdzie patrzy postać.
  - Ruch zależny od kierunku: wartości kluczy mogą używać `yaw` (S = 0, E = 90, N = 180), np. `"2.0 - 0.55*pulse(yaw, 0, 60)"`. Od przodu i od tyłu broń skierowana prosto w kamerę znika, więc tam dajemy ukos.
  - Zamach nad głową: ręce wyżej i z tyłu (`hand_R` y ok. 1,25, z ok. −0,28), kąt broni ok. −1,6, wtedy ostrze opada za głowę, a nie przed twarz.
  - Długa broń w pchnięciu wychodzi poza klatkę 64×64 (błąd QA „clipped”): skróć drzewce albo wypad, nie zmieniaj `camera.scale`.
  - Linie wewnętrzne powstają tylko między osobnymi częściami. Coś, co ma mieć widoczną krawędź (rząd gontów, deska), musi być osobną częścią albo cienką ciemną listewką. `stripes` na pochyłej powierzchni łatwo ginie.
  - Belki muru pruskiego, okna i parapety: materiał z `line: false`, inaczej każda belka dostaje obwódkę i fasada w cieniu zlewa się w brąz. Belka 0,09 (ok. 1,7 px) wystarcza.
  - Dach z dachówki: jedna płyta na połać i cienkie ciemne walce wzdłuż kalenicy co 0,21 (rzędy) czytają się dobrze; szczyt pod dachem widać tylko przy okapie od frontu ok. 0,1.
  - Wnętrze czegoś (nadburcie, skrzynia): wytnij elipsoidę rozciągniętą w górę (`elongate: [0, 2, …]`) z płaskim dnem, zamiast przecinać dwie bryły (cięcia sumują się, nie da się ich przeciąć).
  - Obiekt z 8 kierunkami i kołysaniem: `kind: prop` z `directions: 8` działa; ostrzeżenie QA „idle slides” przy przechyle jest w porządku.
  - Poprawki po ocenie (2026-11-09): koga zanurzona o 0,35 (kość `ship` niżej, cięcie linii wody przesunięte razem z nią), piana to cienki pas kształtu kadłuba (powłoka `shell`) w przestrzeni świata, więc zostaje na wodzie przy kołysaniu; wydęty żagiel to przednia czasza dużej elipsoidy z `shell`, docięta płaszczyznami do prostokąta (kość `sailb` z obrotem rei). Kamienice: szczyty ozdobne `gable: stepped|curved` (murowany szczyt nad dachem, z gzymsem i kulą), 2 albo 3 piętra i różne nachylenie dachu w jednej działce.
  - **Pułapka (dwa razy):** wielokąt w `extrude` nie może mieć dwóch takich samych punktów pod rząd (krawędź zerowej długości): zamiast kształtu SpriteKiln wycina wielkie koło. Zaokrąglij punkty, potem usuń powtórki.
  - **Koga w grze (decyzja właściciela 2026-11-09):** `assets/ships/cog/idle.png` i `build_0..2.png` pochodzą z SpriteKiln (`cog.yaml`, etapy `python3 tools/spritekiln/gen_cog_stages.py`, kopiowanie do arkusza gry `python3 tools/spritekiln/export_ship.py <spec> cog 110,168 [--out=build_<n>]`). Klatki i punkt bez zmian, kod gry bez zmian. Etapy na pochylni: 0 = stępka, dziobnica i wręgi (rury `tube` w kształcie U), 1 = poszyty kadłub z kasztelami, 2 = cały statek; płaskie dno 0,3 pod linią wody, cztery kloce.
  - **Przyspieszenie:** `pip install numba` (osobno, bez `spritekiln[fast]`) zainstalował się w kilka sekund i SpriteKiln sam go używa („renderer: numba”): kamienica 100 s → 18 s. Bez niego galeon to kilka godzin.
  - Karawela i galeon (`python3 tools/spritekiln/gen_big_ships.py`, według szkiców i referencji właściciela 2026-11-09): kadłub to **profil z boku** (`extrude` wielokąta: płaskie dno, wypukły łuk dziobu, prawie pionowa pochylona pawęż, podniesiony przedni pokład, niski środek, schodek na tylny pokład wznoszący się do rufy) **przycięty rzutem z góry** (dwa `extrude` pionowe z dopełnieniem obrysu: ostry dziób, najszerzej w ⅓ długości od dziobu, proste zwężenie do płaskiej rufy). Pokłady to wycięcia obrysu wewnętrznego od wysokości pokładu w górę, listwy i deski to pasy wzdłuż linii burty (`extrude` w farbie), galeon ma płaszczyzny zawalenia burt. Elipsoida nie daje takiego kształtu (końce wychodzą jak kopuła). Mniej punktów w wielokątach = szybszy render.
  - Ikony towarów (`gen_icons.py`, `compose_icons.py`): 32×32, jeden widok `se`, pitch 35, kontur ciemny, toon; render poniżej sekundy.
  - Ścięty narożnik kamienic: dom narożny cięty płaszczyzną pod 45° (`cuts`), na ścięciu wąski dom obrócony o −45° (twarzą do kamery) z bramą, wykuszem z wieżyczką albo kramem.
  - **W grze ze SpriteKiln (decyzja właściciela 2026-11-09: „biorę je razem z karawelą”):** karawela (`assets/ships/caravel*`: `python3 tools/spritekiln/gen_big_ships.py caravel caravel_war caravel_build_0 caravel_build_1 caravel_build_2 caravel_war_build_2`, render, `export_ship.py <spec> <caravel|caravel_war> 135,206 [--out=build_<n>]`; wojenna: czerwień 168,40,36 i okrągłe tarcze wzdłuż śródokręcia, etapy 0 i 1 wspólne), kamienice mieszczan (`assets/buildings/hut/level_2_*`: `python3 tools/spritekiln/gen_townhouses.py game` daje 36 speców `townhouse_l2_<kawałek>[_2|_3][_back]`: 6 kawałków × 3 wyglądy × przód i tył; `corner_b` to `corner_a` odbity w x, widoki `_back` to odbicie w z z tylnymi ścianami (belki, okna, tylne drzwi); render, potem `python3 tools/spritekiln/export_houses.py`, który przycina obraz symetrycznie wokół punktu, bo gra odbija domy względem szerokości obrazka) i wszystkie 33 ikony towarów (`python3 tools/spritekiln/compose_icons.py --export`). Kamienice patrycjuszy (`level_3_*`), chata (`base*`), rusztowania i budowa zostają po staremu. **Po `tools/generate_art.gd` przywróć `git checkout assets/buildings/hut/`** (jak dotąd).
  - Galeon (poprawka po ocenie 2026-11-09, „zbyt klockowaty”): druga, bardziej stroma para płaszczyzn zwęża tylko wysokie pokłady rufy; rufa ma galerię (balkon z barierką i daszkiem), boczne wykusze z oknami, łukowe ochrowe zwieńczenie pawęży z tarczą i latarnię (`ornate_stern`).  Druga poprawka (właściciel 2026-11-09): bez najmniejszego masztu z tyłu, grotmaszt i bezanmaszt dalej ku rufie, większe żagle, dłuższy przedni pokład z fokmasztem na nim, większy żagiel pod bukszprytem, dziób jednym wypukłym łukiem od linii wody do przedniego pokładu (`bow_sweep`), a żagiel łaciński wypukły (czasza elipsoidy z `shell` docięta trzema płaszczyznami do trójkąta, `billow`; karawela ma dalej płaski). **W grze od 2026-11-09** (jak karawela: `gen_big_ships.py galleon galleon_war galleon_build_0 galleon_build_1 galleon_build_2 galleon_war_build_2`, `export_ship.py <spec> <galleon|galleon_war> 185,290 [--out=build_<n>]`; kloce pod galeonem szersze, bo pod szerokim kadłubem znikały).
  - Karaka (2026-11-09, **w grze**: handlowa, wojenna i etapy, `export_ship.py <spec> <carrack|carrack_war> 160,246 [--out=build_<n>]`): `gen_big_ships.py carrack`, klatka 320 i punkt (160, 246) jak `ShipLayer.BIG_FRAMES`; wysoki przedni kasztel z fokmasztem, dwupiętrowa rufa, po dwa piętra żagli, wypukły żagiel łaciński, zaokrąglony dziób, drewno pośrodku między karawelą a galeonem.
  - Galeon „z referencji” (2026-11-09, **właściciel: „Nowy jest lepszy!”, od tej chwili to galeon w grze**; `galleon` i `galleon_ref` to ten sam kształt): zdjęcie modelu z boku; cienkie liny odfiltrowane (ciemne piksele, otwarcie filtrem 5×5), zarys kadłuba nad przyjętą linią wody (⅓ od stępki), z niego proporcje: krótki niski środek, przedni kasztel od 0,23 długości, niski tylny pokład od −0,15, wysoka rufa od −0,60, duży łuk dziobu, mocno odchylona pawęż, grotmaszt i bezanmaszt dalej ku rufie. `ref compare` na samym kadłubie (`galleon_ref_hull`) daje IoU ok. 0,5, bo gra patrzy z góry (widać pokład) i nad rufą są latarnia i zwieńczenie; liczba służy do porównań między wersjami, decyduje oko. Porównanie: `previews/galleon_vs_galleon_ref_2x.png`, `galleon_ref_hull_compare.png`.
  - Tekstury terenu (próba 2026-11-10, `gen_terrain.py`, `compose_terrain.py`, nie w grze): SpriteKiln 0.3 nie ma kafli, więc tekstura to płaski model 4×4 kafli z widoku `se`, wzór powtórzony na sąsiednie łaty i wycięty środkowy prostokąt 256×128 (jak `stony/big_*`: gra układa takie prostokąty jak cegły, więc są bez szwu; wycinanie samego rombu daje kropkowane szwy na krawędziach). Kolory z obecnych tekstur (`palette extract`). **Wniosek:** bez szwów się da, ale wygląda gorzej niż obecne tekstury (trawa w plamy, bruk kanciasty i zaszumiony, ziemia płaska), a render trwa 2–10 min przez tysiące drobnych kształtów. SpriteKiln lepiej użyć do obiektów na terenie (skały, pnie, krzaki, brzegi z wysokością), nie do płaskich tekstur.
  - Drzewa, skały i świnia (próba 2026-11-10, `gen_nature.py`, `compose_nature.py`, nie w grze): drzewo i skały w 3 stanach jak w grze (`grown`, `felled`, `stump`; klatka 96 przycięta do 64×96, środek kafla w (32, 80)); korona to kępy elipsoid z jaśniejszymi i ciemniejszymi plamami liści, skały to zaokrąglone bloki ze ściętymi krawędziami (`blend: chamfer`), `edge_highlight`, rysy i mech. Świnia: 8 kierunków, kości ciała, głowy, ogona i nóg, animacje `idle` (oddech, ogonek, uszy), `walk` (nogi parami po przekątnej) i `root` (ryje w ziemi), klatka 32; 192 klatki w 6 s. Renderują się w sekundy, bo mają mało kształtów. Poprawka po ocenie („skały zbyt płaskie, drzewo nienaturalne, ścięte ma uciętą koronę”): skały to zaokrąglone, przechylone bryły (`round` ≈ połowa najmniejszego wymiaru) z miękkim cieniowaniem i rysami (`cut_blend: groove`), drzewo ma wygięty pień z rur, gałęzie i koronę z 24 kęp różnej wielkości na nierównej kopule z drobnymi plamami liści; ścięte drzewo leży w lewo w górę, żeby korona mieściła się w 64 px (wcześniej ucinał ją brzeg obrazka). Natura ma `shading: soft`, budynki dalej `toon`. Obecnie w grze świnia nie ma animacji (`goods/carried/animal/pig.png`: 5 nieruchomych widoków).
  - **Skały w grze od 2026-11-10** (`assets/nature/rock/{grown,felled,stump}.png` z `gen_nature.py rock_*`, klatka 96 przycięta do 64×96, środek kafla w (32, 80)). Uwaga: `tools/generate_goods.gd` rysuje skały od nowa, po nim `git checkout assets/nature/rock/`.
  - Drzewa według referencji właściciela (2026-11-10, **w grze jako mieszany las**: wygląd 1 = `tree_oak_a`, 2 = `tree_oak_b`, 3 = `tree_spruce`, 4 = `tree_pine`, 5 = `tree_spruce_light`, pliki `nature/tree/<stan>[_N].png`, ścięte i pniaki `tree_<gatunek>_{felled,stump}`; uwaga: `tools/generate_goods.gd` rysuje drzewo od nowa, po nim `git checkout assets/nature/tree/`): liściaste `tree_oak_a` (dąb) i `tree_oak_b` (jaśniejszy, węższy): gruby pień z płatami kory i korzeniami, konary widoczne pod koroną, korona z „chmurek” liści (każda osobną częścią, więc między nimi biegnie ciemna linia; na brzegu chmurki małe kulki dają postrzępiony obrys), `shading: toon`. Iglaste `tree_spruce`, `tree_pine` (rzadsze piętra), `tree_spruce_light`: piętra stożków z opadającymi, postrzępionymi końcami gałęzi (osobne części, linie między piętrami). Porównanie: `previews/tree_variants_3x.png`.
  - **Rework żołnierzy, pilot (2026-11-10, ankieta: najpierw 2 jednostki, 8 kierunków, machiny osobno):** halabardnik (według referencji landsknechta: salad z zasłoną brody, napierśnik, płatowa spódniczka, bufiaste rękawy i nogawice w czerwono-złote pasy, halabarda) i łucznik (według referencji łucznika: kaptur kolczy i hełm z nosalem, jasna tunika z czerwonym krzyżem na oliwkowym kaftanie, długi łuk, kołczan; w strzale łuk stoi pionowo także od przodu i od tyłu dzięki kątowi zależnemu od kierunku `pulse(yaw, …)`). Speki `art/specs/characters/<id>/<id>.yaml` (na bazie `humanoid`), arkusze gry: `python3 tools/spritekiln/export_character.py <id>` (8 wierszy S…SW, bez luster, klatka 64, stopa (32, 58) dzięki `camera.center` 1,554; `attack` → `work` i `work_drill`), potem ikonki `python3 tools/make_unit_icons.py`. `shadow: null` (postacie w grze nie mają cienia). Nogawek nie da się zabarwić różnie (`leg_R` to lustro `leg_L`), więc obie w pasy. Poprawki właściciela (2026-11-10): dłuższa halabarda z większym żeleźcem w klatce 96 px (pchnięcie nie mieści się w 64 px; gra czyta rozmiar klatki z wysokości arkusza), łucznik w zielonym kapturze z większym łukiem, cięciwa zawsze bliżej łucznika (kąty łuku liczone dla każdej klatki). Pilot zaakceptowany 2026-11-10.
  - **Rework żołnierzy, paczka 1 (2026-11-10):** włócznik (kapalin z szerokim rondem, pikowana przeszywanica, okrągła jasna tarcza z czerwonym krzyżem, włócznia z czerwonym proporczykiem; klatka 96 px i pchnięcie jak halabardnik), miecznik (otwarty hełm z nosalem, kolczuga, czerwony płaszcz i tarcza z złotym krzyżem, cięcie z szablonu bez świecącej smugi), kusznik (kapalin, pikowany kaftan, czerwone nogawice, torba z bełtami, kusza zbudowana z części: łoże, stalowe łęczysko wygięte do przodu, strzemię, cięciwa w kształcie V po napięciu albo prosta po strzale; strzał, opuszczenie, stopa w strzemieniu, napinanie, nowy bełt), ciężki zbrojny (zamknięty hełm z czerwonym pióropuszem i złotym otokiem, zbroja płytowa, naramienniki, duża tarcza, buzdygan; ciężki cios znad barku). Kusza i buzdygan: kości `xbow`/`mace` z obrotem nadpisanym w specu, kąty wyliczone numerycznie (kusza: kość przy pięści, obrót w układzie tułowia). W grze, czeka na ocenę.
  - **Rework żołnierzy, paczka 2 (2026-11-10, ankieta: koń wspólny dla obu konnych, inny strój; ramka 128 px):** wspólna baza `art/specs/characters/mounted/mounted.yaml` (gniadosz z czarną grzywą i ogonem, strzałką na czole, siodłem i ogłowiem, jeździec okrakiem; kości konia: tułów, szyja, głowa, ogon, po dwie kości na nogę; chód stępa w 4 taktach: zad L, przód L, zad P, przód P co ćwierć cyklu), a `knight.yaml` i `light_cavalry.yaml` ją rozszerzają (`extends: ../mounted/mounted.yaml`). Rycerz: zamknięty hełm z czerwonym pióropuszem i złotym otokiem, kolczuga i płyty, czerwony płaszcz i tarcza ze złotym krzyżem, miecz (cięcie z siodła znad barku), koń w czerwonym czapraku ze złotymi krzyżami i stalowym naczółku. Lekka jazda: hełm z nosalem, pikowany kaftan, jasna okrągła tarcza z czerwonym krzyżem, włócznia z proporczykiem (pchnięcie nad szyją konia), koń bez czapraka, z czerwoną derką pod siodłem. Drabiniarz (`ladderman.yaml`, klatka 96): czerwona czapka, skórzany kubrak, drabina z dwóch żerdzi i 9 szczebli na prawym ramieniu; w pracy zdejmuje ją, stawia pionowo, przechyla na mur i bierze z powrotem (podniesiona drabina odchylona w prawo, żeby nie zasłaniała twarzy). **Klatka 128 px ma stopę 16 px nad dolną krawędzią, (64, 112)** (`CharacterSheet.foot_margin`, środek kamery 2,869): od przodu przednie nogi konia sięgają niżej niż stopa. Broń przy dłoni wysuniętej do przodu (jeździec) obraca się źle w układzie dłoni: miecz i włócznię przypinamy kością w układzie tułowia (`bones: {sword: {parent: torso_rot, at: wrist_R, rot: …}}`), a wypoziomowaną włócznię od przodu i od tyłu odchylamy w bok obrotem wokół osi pionowej (`sp_y`), bo obrót wokół osi drzewca nic nie daje. Zrzut: `game_shot.tscn -- --map=lakeland --tile=84,64 --zoom=3 --m7=army3 [--drill]` (konni, drabiniarz i halabardnik). Uwaga: `tools/generate_characters.gd` rysuje tych żołnierzy od nowa, po nim przywróć `git checkout assets/characters/{knight,light_cavalry,ladderman}/` (jak resztę żołnierzy ze SpriteKiln). W grze, scalona do `main` 2026-11-10. Poprawka właściciela (2026-11-10, „miecz wygląda jak nóż”): miecznik i rycerz mają dłuższy miecz (klinga 0,74 i 0,78, szerszy jelec, dłuższy uchwyt i okrągła głowica, części `sword_guard`, `sword_grip`, `sword_pommel` nadpisane w specu).
  - **Machiny oblężnicze (2026-11-10, ankieta: taran z dachem ze skór, nogi ludzi pod dachem, balista z 2 ludźmi przy kołowrocie, ramka 128 px):** generator `python3 tools/spritekiln/gen_siege.py` pisze `art/specs/props/{ram,ram_enemy,ballista,ballista_enemy}/` (`kind: prop`, 8 kierunków bez luster, przód = +z, wygląd budynków: `toon`, ciemny kontur; punkt (64, 112) = środek machiny na ziemi, jak u konnych). Taran: szopa na 4 kołach ze szprychami, dwuspadowy dach z 3 skór na stronę (osobne części, sznury na łączeniach), szczyty z desek, belka z żelazną głowicą na linach, nogi 6 ludzi pod okapem; animacje `idle`, `walk` (koła i nogi), `strike` → `work` (belka cofa się i wali, 1,5 s). Balista: wóz na 2 kołach, kozioł pod przodem, łoże z rowkiem, rama z dwoma skręconymi wiązkami lin, ramiona z okuciami, cięciwa od końców ramion do zapadki (`"@tip_l"` → `"@nut"`), kołowrót z drążkami, bełt; `idle` (naciągnięta, z bełtem), `walk`, `reload` → `work` (ramiona i cięciwa do przodu, bez bełtu, kołowrót się kręci). `_enemy` różnią się tylko czarnym proporcem. Obsługa balisty to osobna postać `art/specs/characters/siege_crew/` (rozszerza włócznika bez broni: kapalin, przeszywanica; `walk` = pchanie, `attack` → `work` = kręcenie kołowrotem, ramka 64), którą gra rysuje 0,85 kafla za balistą. Eksport: `python3 tools/spritekiln/export_character.py <ram|ram_enemy> --props --anims=idle,walk,strike:work`, `<ballista|ballista_enemy> --props --anims=idle,walk,reload:work`, `siege_crew --anims=idle,walk,attack:work`. W grze rysuje je `SiegeLayer` (zamiast kresek w kodzie); koła: 20 klatek/s, czyli tyle, ile przejeżdża ćwierć (taran) albo szósta część (balista) obrotu koła. Render ok. 3 min na machinę.
  - **Ściąga dla agentów (wszystkie funkcje, polecenia, pułapki, wskazówki autora): `tools/spritekiln/AGENT_NOTES.md`; pełne przewodniki autora (wersja 0.3.0) w `tools/spritekiln/.spritekiln/agent/`.**
  - **Przydatne funkcje SpriteKiln (sprawdzone 2026-11-09):**
    - `spritekiln ref prep <obraz> --pitch 30` wycina tło ze zdjęcia albo rysunku (np. modelu statku na białym tle) i wyciąga z niego paletę; `spritekiln ref compare <spec> <obraz> --dir <kierunek>` daje arkusz: referencja, nasz sprite, nałożone sylwetki (czerwone = tylko w referencji, niebieskie = tylko u nas), 8 kierunków i obie palety, plus liczbę zgodności (IoU) i podpowiedzi typu „na wysokości 40–50% za szeroko”. Najlepiej działa ze zdjęciem dokładnie z boku albo z tego samego kąta co kierunek gry (`previews/galleon_ref_compare.png`: model San Francisco jest pod kątem, więc liczba jest niska).
    - `spritekiln palette extract <obraz> --k 6` wyciąga rampy kolorów z obrazka, np. z budynku z PixelLab, żeby nowe grafiki miały te same barwy; `palette ramp "#hex"` robi rampę z jednego koloru.
    - `spritekiln review <spec> --bg <zrzut trawy>` mierzy jasność na tle gry (kontrast, L*), liczbę kolorów i piksele każdego materiału; `--against <spec>` porównuje dwa assety.
    - Gotowe części postaci (`spritekiln kits`): topór, łuk, miecz, włócznia, buzdygan, młot, tarcza, hełm, kaptur, kapelusz, peleryna, pas, sakiewka, włosy. Przydadzą się przy postaciach.
    - `sockets` (punkty zaczepienia na klatkę, np. dłoń z niesionym towarem, §4.5), `--lit` z mapą normalnych do oświetlenia w Godocie i `spritekiln godot` (eksport do SpriteFrames): na później, przy postaciach.
  - Budynek: `kind: prop`, `directions: [se]`, `shadow: null`, gruntu nie podnosić (podwórko 0,01 nad ziemią, `outline: false`). Wymiary w jednostkach: kafel 2,343, drzwi ok. 1,5, ściana parteru ok. 2,2–2,4.
- Następny krok próby: decyzja właściciela po obejrzeniu porównań (`previews/*_vs_current_*.png`, `previews/woodcutter_hut_closeup.png`). Alternatywa do porównania na laptopie właściciela: Spriteloom (dodatek AI do Aseprite, karta NVIDIA ≥ 12 GB).

### 10.21 Zagrody ze zwierzętami (Z1, część 1, 2026-11-10)

- **Zwierzęta w zagrodzie:** `assets/animals/<towar>/{idle,walk,root}.png` (wiersze: kierunki S, SE, E, NE, N, NW, W, SW, bez luster; kolumny: klatki) i `sheet.json` (rozmiar klatki, punkt na ziemi, liczba klatek i czas klatki każdej animacji). Świnia ze SpriteKiln (`art/specs/props/pig`, klatka 32, punkt (16, 21)): `cd tools/spritekiln/art/specs/props/pig && spritekiln render pig.yaml`, potem `python3 tools/spritekiln/export_animal.py pig`. Placeholdery (owal) pisze `tools/generate_placeholders.gd`.
- **Płot i furtka** rysuje kod (`PenLayer`, jak poręcze mostu): słupki 13 px, dwie żerdzie na 5 i 10 px (ciemna linia z jasnym grzbietem); furtka między dwoma wyższymi słupkami (16 px), skrzydło z desek z zastrzałem, otwarte obraca się do środka zagrody. Zamiast osobnych obrazków ze SpriteKiln: brzegi zagrody mają dowolny kształt, a płot rysowany kodem sam łączy się w narożnikach (do zmiany po ocenie, jeśli będzie wyglądał za skromnie).
- **Podłoże zagrody:** wydeptana ziemia z kałużami błota, słomą i kępkami trawy przy brzegach, 2 wyglądy (`terrain/pen/ground{,_2}.png`, 64×32): `python3 tools/make_pen_ground.py`.
- **Mniejszy chlew** 2×2 ze SpriteKiln (prośba właściciela 2026-11-10; `art/specs/props/pigsty/pigsty.yaml`, jak chata drwala: jeden widok `[se]`, `toon`): chata z pionowych desek na kamiennej podmurówce, ciemne słupy narożne, gruba strzecha z ciemniejszymi plamami i związanym kalenicowym wałkiem, drzwi z żelaznymi okuciami w ścianie od strony podwórka (+x gry), okienko z okiennicą, otwarta wiata ze strzechą nad belami siana i workami, koryto z pomyjami, kosze z paszą, wiadro, widły oparte o ścianę, kałuże błota. Render ok. 3 s: `cd tools/spritekiln/art/specs/props/pigsty && spritekiln render pigsty.yaml`, potem `python3 tools/spritekiln/export_building.py pigsty` (wycina obraz symetrycznie wokół przedniego rogu działki i zapisuje punkt w `base.json`). Etapy budowy zostają rysowane kodem. **Po `tools/generate_art.gd` przywróć `git checkout assets/buildings/pigsty/base.*`.**
- Zrzut: `game_shot.tscn -- --plain --tile=62,64 --zoom=2 --pens [--select=pigsty]`.
- **Własny wygląd 5 budynków 2×2 (prośba właściciela 2026-11-11: chlew, owczarnia, stadnina, pasieka i chata tragarzy wyglądały jak ta sama chata pod strzechą):** jeden generator `tools/spritekiln/gen_farmsteads.py` pisze wszystkie pięć opisów (zastąpił `gen_farms.py`, `gen_porters.py` i ręczny `pigsty.yaml`). Każdy ma inną bryłę, dach i materiał: **chlew** niska obora z polnego kamienia pod jednospadowym dachem z desek opadającym ku podwórku, niskie drzwi z połówką z desek, okienko dla świń, słoma pod ścianą, koryto, wiadro, błoto; **owczarnia** szałas z wikliny na palikach pod stromym czterospadowym dachem ze strzechy (bryła z wyciętymi połaciami: `hip_roof` w generatorze), worki runa, ława do strzyżenia z runem i nożycami, drabinka z sianem, kij pasterski; **stadnina** wysoka stajnia z desek szczytem do podwórka, stromy dach z gontu z wiatrowskazem, szeroka brama z zastrzałami i podkową, siano w otworze strychu, otwarta wiata z siodłem i belami, kamienne poidło; **pasieka** chatka z bali pod gontem na lewym kaflu, na tylnym kaflu daszek z półką słomianych uli (prawy kafel zostaje dla stosu miodu), ława ze słoikami, fioletowe i żółte kwiaty; **chata tragarzy** bielona chałupka w ciemnej ramie z belek pod łupkowym dachem czterospadowym z kominem, otwarta szopa z wózkiem pełnym worków, skrzynie, beczki, nosidło. Wszystkie mają drzwi w tym samym miejscu (ściana +x gry, kafel wejścia wolny); prawy kafel (`yard_at(0)` = (1, 0)) bez wysokich rekwizytów tam, gdzie gra rysuje stos (pasieka). `cd tools/spritekiln && python3 gen_farmsteads.py [<id>…]`, potem `spritekiln render` i `python3 tools/spritekiln/export_building.py <id>`. Zrzut: `game_shot.tscn -- --shot=<plik> --plain --tile=50,58 --zoom=2 --yards=stud_farm,apiary,porters_hut,pigsty`.
- **Stojące zboże i chmiel (prośba właściciela 2026-11-11: pola mają „wystawać” jak winnica):** `tools/spritekiln/gen_crops.py` pisze opis na każdą fazę (jeden kafel 2,343 × 2,343 w widoku `[se]`, środek kafla w początku układu): **pszenica** `sprout`, `young`, `green`, `ripe` (4 rzędy po 5 kęp, w kępie 3 źdźbła ze stożków, kłosy z elips, dojrzałe złote i lekko pochylone; bez obrysu i linii, bo cienkie łodygi dawały ciemną plątaninę), **chmiel** `poles`, `shoot`, `half`, `full`, `ripe` (dwie tyczki na brzegach kafla z drutem u góry, dwa sznurki tak ustawione, żeby na ekranie stały obok siebie, pędy z elips pnące się po sznurkach, jasne szyszki na dojrzałym; tyczki stoją też na ugorze). `python3 tools/spritekiln/export_crops.py` składa je do `assets/nature/crops/<roślina>/<faza>.png` (pszenica 64×64, środek kafla (32, 48); chmiel 64×112, (32, 96)) i podmienia ziemię pod nimi (`assets/terrain/field{,_hops}/`) na zaoraną glebę we wszystkich fazach poza ugorem. W grze rysuje je `VineLayer` (tabela `CROPS`, jak winorośl), kratka odświeża się od razu po siewie i żniwach. Zrzut: `game_shot.tscn -- --shot=<plik> --plain --tile=48,56 --focus=46,56 --zoom=2 --yards=farm,hop_farm --fields_seconds=150|205`.
- **Sad (E2, część 1, 2026-11-11):** jabłoń w `gen_crops.py` (`bare`, `leaf`, `blossom`, `green`, `ripe`: pień z rozwidlonymi gałęziami, korona z elips, kwiaty i owoce jako kulki na powierzchni korony, bo w środku ginęły; spady pod drzewem w `ripe`), `nature/crops/apples/*.png` 64×88 ze środkiem kafla w (32, 72), ziemia pod drzewami = trawa winnicy (`export_crops.py`, `GROUND_FROM`). Budynek sadu w `gen_farmsteads.py` (żółta chatka pod czerwoną dachówką na lewym kaflu, ziemna piwniczka na owoce na tylnym, prawy kafel wolny na stos jabłek). Ikona `gen_icons.py` (`apples`: dwa jabłka obok siebie, ogonek i listek). Element stosu (`tools/pixellab_src/goods/apples.png`) i niesiony kosz (`assets/goods/carried/basket/apples.png`): kosze winogron z fioletem przesuniętym na czerwień; stosy `python3 tools/compose_pixellab_stacks.py apples`.
- **Polowanie (E2, część 2, 2026-11-11):** sarna (`art/specs/props/deer/deer.yaml`, ręcznie na szkielecie świni: smukła, jasnobrązowa, długie nogi, szyja, duże uszy, białe lusterko; ramka 48, punkt (24, 34); `idle`, `walk`, `graze`) i dzik (`boar/boar.yaml` ze świni: ciemny szczeciniasty, grzywa na grzbiecie, długi ryj, kły; ramka 40, punkt (20, 25); `idle`, `walk`, `root`), eksport `python3 tools/spritekiln/export_animal.py deer --anims=idle,walk,graze` (dzik: `--anims=idle,walk,root`). Chata myśliwego w `gen_farmsteads.py` (ciemne bale `darklog`, dach z darni `turf`, poroże, skóra na ramie, zdobycz na haku, drwa, pieniek). Ikona zdobyczy `gen_icons.py` (`game`: leżąca sarna z wyciągniętymi nogami). Tusza na plecach rysowana w PIL (`goods/carried/sack/game.png`, 24×120, 5 kierunków jak worki). Strzałę rysuje kod (`WildLayer`).
- **Część 2 (owce i konie, 2026-11-10):** owca (`art/specs/props/sheep/sheep.yaml`, ręcznie na wzór świni: runo z kul zlanych w jedną bryłę z ciemniejszymi plamkami, ciemny pysk, uszy i nogi, klatka 32, punkt (16, 21); `idle`, `walk`, `graze` z głową w trawie), koń w zagrodzie (`art/specs/props/horse/horse.yaml`: części konia skopiowane z `characters/mounted/mounted.yaml`, bez jeźdźca i siodła, z kantarem; klatka 64, punkt (32, 54); `idle`, `walk` jak u konnych, `graze`). `PenLayer` w odpoczynku pokazuje `graze`, gdy arkusz go ma, inaczej `root` (świnia). Owca jako towar: `python3 tools/spritekiln/compose_animal_goods.py sheep` robi z `animals/sheep/idle.png` ikonę 32×32 (widok z boku), owcę prowadzoną (24×120, rzędy S, SE, E, NE, N, kopyta w (12, 20)) i stadko 1–4 owiec (4 klatki 64×64). Budynki owczarni i stadniny: `python3 tools/spritekiln/gen_farms.py` pisze ich specy z chlewa (ta sama działka, chata, dach i wiata; inne ściany, dach i rzeczy), potem render i `export_building.py`. Etapy budowy stadniny to te same obrazki co chlewa (ten sam kształt 2×2). **Po `tools/generate_art.gd` przywróć `git checkout assets/buildings/{pigsty,sheep_farm}/base.*`** (stadnina była dotąd z PixelLab: po `tools/build_pixellab_buildings.py` przywróć `git checkout assets/buildings/stud_farm/`).
- **Część 3 (ule, 2026-11-10):** ul (`art/specs/props/skep/skep.yaml`, jeden widok `[se]`, `toon`): kosz z plecionki słomy (`revolve` z zaokrąglonym profilem i ciemnymi zwojami co 0,12), ciemny wylot od strony kamery, guz na szczycie, deskowa podstawka na dwóch nóżkach; wycięty symetrycznie wokół punktu na ziemi do `assets/nature/hive/skep.png` (26×26) z `skep.json` (punkt (13, 21)). Pod ulem `terrain/hive/ground.png` (trawa z koniczyną i kwiatami, `tools/make_pen_ground.py`). Pszczoły rysuje kod (`PenLayer`): 3 na ul, złote 2×1 z ciemnym pikselem i migającym skrzydełkiem, na pętlach nad koszem. Pasieka (`gen_farms.py`, `apiary`): ochrowa polepa w ciemnej konstrukcji, strzecha, wiata z półką z 2 zapasowymi koszami i garnkami, ławka ze słojami miodu (`finish: glossy`), gliniany podkurzacz, kępy trawy z kwiatami. **Po `tools/generate_art.gd` przywróć też `git checkout assets/buildings/apiary/base.*`.**
