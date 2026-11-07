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
| Teren | tekstury terenu organicznego (§8.1): `grass/a`, `grass/light`, `grass/dark`, `meadow/a`, `forest/a` (ściółka), `water/a`, `water/b`, `ford/a`, `bank/a` (skarpa brzegu); ozdoby `grass_decor/*`; M4b-3: `stony/a`, `stony/b` (kamienisty grunt), `lake/a`, `lake/b` (jezioro), trzciny `reeds/{a,b,c}` (kod, 24×32, stopa w (12, 29), na kaflach jeziora przy brzegu); M5: `sea/a`, `sea/b` (głębokie morze), `sea/shallow` (płytkie morze, osobny slot `SHALLOW` w shaderze), `sand/a` (plaża) | zbocza; **gotowe na później** (PixelLab, M4b-3): `bedrock/a` (spękana skała), `gravel/a` (żwir), `marsh/a`, `marsh/b` (bagno), `clay/a` (glina), `stubble/a` (ściernisko), `ice/a` (lód), `peat/a` (torf) |
| Pojazdy | wózek ręczny (M4b-3, kod: `tools/generate_goods.gd`): `vehicles/handcart/empty.png`, `loaded.png`, 5 wierszy (S, SE, E, NE, N) po 48×40, środek wózka na ziemi w (24, 30), stoi 0,4 kafla przed stopami tragarza; wóz konny: `vehicles/wagon/empty.png`, `loaded.png`, 5 wierszy po 112×80, punkt między wozem a koniem na ziemi w (56, 52), 0,6 kafla za woźnicą | |
| Statki (M5) | kod: `tools/generate_ships.gd`. Łódź rybacka `ships/fishing_boat/<anim>.png`: `idle` (pusta, 1 klatka), `row` (rybak wiosłuje), `cast_net`, `wait_net` (pływaki sieci na wodzie), `haul_net` (po 4 klatki); 8 wierszy (S, SE, E, NE, N, NW, W, SW, bez luster, bo łódź nie jest symetryczna z rybakiem), klatka 80×64, środek łodzi na linii wody w (40, 46). Łódź na pochylni: `build_0` (szkielet), `build_1` (poszycie), te same wiersze. Rybak w łodzi jest częścią grafiki łodzi. Ławica ryb `nature/fish_shoal/shoal.png`: 4 klatki × 3 wiersze (pełna z mewą, przełowiona, pusta), 64×48, środek kafla w (32, 32). **Część 2:** obca koga kupca morskiego `ships/foreign_cog/idle.png` (kod: `tools/render_cog.py`, przeniesiony z prototypu `src/prototype/ships/`): 8 wierszy (kierunki jak wyżej) × 4 klatki kołysania, klatka 220×220, środek kogi na linii wody w (110, 168); części frakcji (pasy żagla, tarcze, flaga) w kolorze kupca (zielony). Trap między nabrzeżem a statkiem rysuje widok (deska od stopy trapu do burty) | koga gracza i jej etapy budowy (część 3, ten sam generator w kolorze gracza) |
| Drogi | ubita: `road/a`, `road/b`; bruk: `paving/a` (PixelLab, ten sam zestaw `create_tiles_pro` co woda i droga, kafel 14 „cobblestone pavement”, krawędzie wyrównane `pixellab_tile_edges.py`), `paving/b` (lustro `a`); kształt drogi rysuje shader | |
| Pola | `terrain/field/`: `fallow` (ugór, też po żniwach), `plowed` (zaorane), `sown_1..3` (zasiane, rośnie, prawie dojrzałe), `ripe` (dojrzałe) | chmiel, winorośl, len (`terrain/field_<crop>/…`) |
| Natura | drzewo liściaste: `growing_1..3`, `grown`, `falling` (anim.), `felled` (ścięte, leży, aż drwal zabierze ostatnią kłodę), `stump`. Krzaki, kamienie dekoracyjne | iglaste, skały ze złożem |
| Stosy w magazynie | `stacks/<good_id>.png`: arkusz 4 faz (25/50/75/100%), każda faza 64×64 (romb 1 kafla + wysokość) | wszystkie towary |
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
- PixelLab nie ma narzędzia, które gwarantuje bezszwowe kafle izometryczne ani organiczne przejścia (potwierdzone w ich pomocy).
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
- Port, przystań i stocznia (pas obok pochylni) nie mają już pomostu w grafice (`tools/generate_art.gd`): ich pas nad wodą rysuje `QuayLayer`, więc łączy się z nabrzeżem gracza. Miejsce cumowania to same rekwizyty (pachołki, latarnia, beczki, sieci) na nabrzeżu.
- Zrzut: `game_shot.tscn -- --map=coast --tile=76,84 --zoom=2 --port --quays`.

### 10.10 Interfejs „pergamin i drewno” i menu główne (UI-1, 2026-11-07)

- **Skala:** grafiki interfejsu i menu mają piksel rysunku = 2×2 piksele ekranu bazowego 1280×720 (jak obraz menu 640×360 w skali 2). Nic nie jest rysowane w skali 1 ani skalowane nierówno.
- **Grafiki interfejsu** (`tools/generate_ui.gd` → `assets/ui/`): `panel.png` (pergamin w ramie z ciemnego drewna z żelaznymi okuciami w rogach; dziewięć pól z marginesem 12 px), `panel_inset.png` (ciemniejszy pergamin bez okuć: pola tekstowe), `button_{normal,hover,pressed,disabled}.png` (drewniana tabliczka ze złotymi ćwiekami; wciśnięta niżej o 1 piksel rysunku), `board.png` (deski z gwoździami: pasek u góry i menu budowy, powtarzane w poziomie), `tooltip.png`, ikony 10×10 rysunku: `icon_gold`, `icon_people`, `icon_workers`, `icon_time`. Środki i krawędzie dziewięciu pól są powtarzane, nie rozciągane (włókna pergaminu i słoje drewna zostają piksel w piksel).
- **Kolory tekstu** (`UiKit`): atrament `INK` na pergaminie, wyblakły atrament `INK_SOFT` na podpowiedzi, czerwonobrązowe nagłówki `HEADING`, zielony `GOOD` i czerwony `BAD` dla bilansów, jasny `LIGHT` z ciemnym obrysem na drewnie i nad miastem (powiadomienia), złoty `GOLD` dla złota w pasku.
- **Obraz menu głównego** (PixelLab, „Create Image (Pro)”, 640×360, wariant 2 z 3, wybór właściciela 2026-11-07): koga z granatowym żaglem wpływa do portu, tragarz z workiem na nabrzeżu pełnym skrzyń i beczek, miasto z kościołem i zamkiem na wzgórzu, pogodny dzień, po lewej wolne morze i niebo na menu. Źródło: `assets/ui/menu/source.png`. Warstwy tnie `python3 tools/split_menu_art.py`: `sky.png` (niebo; pod lądem niebo ciągnie się w dół), `land.png` (miasto, morze, statek i nabrzeże bez nieba), `water.png` (maska otwartego morza); każda warstwa ma 8 pikseli powtórzonej krawędzi. Kawałki nieba zamknięte przez olinowanie dopisuje się do `EXTRA_SKY`.
- **Ruch w menu** (`MenuBackdrop`): niebo przesuwa się do 2, a ląd do 5 pikseli rysunku za myszą; po niebie, za miastem, płyną 3 małe chmury; z 3 kominów leci dym; krążą 4 mewy; otwarte morze migocze (shader `water_glint.gdshader` na masce wody).
