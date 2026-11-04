# Your Kingdom — architektura techniczna

> Status: **wersja 0.1 (do zatwierdzenia)** · data: 2026-11-04
> Powiązane: [GDD.md](GDD.md) · [ROADMAP.md](ROADMAP.md) · [ART_SPEC.md](ART_SPEC.md)

Decyzje zapisuję w formacie **Decyzja → Uzasadnienie → Alternatywy**. Zmiana decyzji wymaga aktualizacji tego dokumentu w tym samym commicie.

---

## 1. Ocena założeń z briefu

| Założenie | Ocena | Doprecyzowanie lub zmiana |
|---|---|---|
| Budynki, towary, receptury, jednostki i prowincje definiowane danymi | ✅ Tak | Dane opisują **parametry i sekwencje kroków** z zamkniętego zbioru typów kroków. Nowy budynek, który składa się z istniejących kroków (idź, pobierz, pracuj, wytwórz, odnieś), nie wymaga kodu. **Nowy rodzaj zachowania** (np. pierwszy budynek z łodzią) wymaga dodania nowego typu kroku w kodzie. Definicje logiczne są **oddzielone od wizualnych** (§3.3), co jest warunkiem łatwej podmiany grafik. |
| Logika symulacji oddzielona od widoku | ✅ Tak | Mocniejsza wersja: symulacja **nie używa węzłów (`Node`)**, a tylko klas `RefCounted`. Działa headless i bez sceny. Widok czyta stan, a zmienia go wyłącznie przez **komendy** (§4.3). |
| Zapis i odczyt od początku | ✅ Tak | Zapisujemy **tylko stan symulacji**, a widok odtwarzamy z tego stanu. Format ma wersję i migracje (§8). |
| Setki widocznych mieszkańców | ✅ Tak | Cel: 500 postaci w aktywnej prowincji i 250 jednocześnie na ekranie przy 60 FPS (§9). Postacie nie są węzłami w symulacji. Węzły graficzne pochodzą z puli i istnieją tylko dla widocznych postaci. |
| Prowincje, których gracz nie ogląda | ➕ Propozycja | Symulacja dwutrybowa: **szczegółowa** dla oglądanej prowincji i **uproszczona** (przepływowa) dla pozostałych, kalibrowana na danych z trybu szczegółowego (§7). |
| Testy i konwencje | ✅ Tak | gdUnit4, testy jednostkowe symulacji, **testy scenariuszowe headless** (np. „po 10 min gry powstał chleb”), **lint danych** i **lint lokalizacji** (§11). |

Dodatkowe propozycje spoza briefu:
- **Wzorzec komend** (§4.3). Daje jedno wejście do symulacji dla gracza, AI i testów, a w przyszłości także powtórki.
- **Deterministyczny zegar z niezależnym od FPS tickiem symulacji** (§4.2). Zapewnia powtarzalne testy i stabilne przyspieszanie czasu.
- **Renderer**: zostajemy przy Forward+ z projektu startowego. W M1 sprawdzimy tryb Compatibility (lżejszy, lepszy dla słabszych PC) i podejmiemy decyzję na podstawie pomiarów.

---

## 2. Struktura folderów

```
your-kingdom/
├── CLAUDE.md
├── project.godot
├── addons/
│   └── gdUnit4/                # framework testów (zewnętrzny)
├── assets/                     # WYŁĄCZNIE pliki graficzne, dźwiękowe i fonty (zob. ART_SPEC §2)
│   ├── characters/ buildings/ walls/ goods/ terrain/ ships/ ui/ fonts/ audio/
│   └── _placeholder/           # generowane placeholdery w tym samym układzie co finalne grafiki
├── data/                       # definicje danych gry (.tres)
│   ├── goods/ recipes/ buildings/ units/ ships/ needs/ population/
│   ├── terrain/ provinces/ maps/ scenarios/
│   └── visuals/                # definicje wizualne (mapowanie id → grafika)
├── localization/
│   ├── messages.pot
│   ├── pl.po
│   └── en.po
├── src/
│   ├── core/                   # autoloady i usługi ogólne: Data, Game, EventBus, Locale, SaveService
│   ├── defs/                   # klasy Resource definicji: GoodDef, BuildingDef, RecipeDef...
│   ├── sim/                    # SYMULACJA — bez Node, bez widoku
│   │   ├── core/               # Simulation, SimClock, Rng, Commands, SimEvents, EntityId
│   │   ├── grid/               # TileGrid, Occupancy, IsoMath (czysta matematyka)
│   │   ├── pathing/            # NavGrid (AStarGrid2D), PathRequestQueue
│   │   ├── economy/            # Inventory, Reservation, Stockpile, StockpileLayout
│   │   ├── buildings/          # BuildingState, Construction, Production
│   │   ├── agents/             # Agent, AgentStore, TaskRunner, steps/
│   │   ├── jobs/               # JobBoard, TransportRequest, assignment
│   │   ├── population/         # Household, Needs, Happiness, Workforce
│   │   ├── walls/              # WallGraph, WallConnectivity
│   │   ├── province/           # ProvinceSim (szczegółowa), ProvinceAbstract (uproszczona)
│   │   └── world/              # WorldSim, ProvinceGraph, Army, Fleet, TradeRoute
│   ├── view/                   # WIDOK — sceny i skrypty renderujące
│   │   ├── camera/ province/ world_map/ agents/ buildings/ walls/ terrain/ overlays/
│   ├── ui/                     # panele, menu, HUD (sceny + skrypty)
│   └── main/                   # scena startowa, ładowanie, menu główne
├── tests/
│   ├── unit/                   # odzwierciedla strukturę src/sim
│   ├── scenario/               # headless scenariusze długiego działania
│   ├── data/                   # lint danych i lokalizacji
│   └── fixtures/               # małe mapy i dane testowe
├── tools/                      # generator placeholderów, importer grafik, skrypty CI
└── docs/
```

Sceny (`.tscn`) leżą **obok swoich skryptów** w `src/view` i `src/ui`. Nie ma osobnego folderu `scenes/`.

---

## 3. Dane gry

### 3.1 Format

**Decyzja:** definicje to własne klasy `Resource` (`class_name GoodDef extends Resource` itd.) zapisywane jako tekstowe pliki `.tres` w `data/`. Rejestr `Data` (autoload) skanuje foldery przy starcie i buduje słowniki `id → def`.

**Uzasadnienie:** typowanie i podpowiedzi w edytorze, edycja w Inspektorze, odwołania między zasobami sprawdzane przez silnik, czytelne diffy w git (format tekstowy).

**Alternatywy:**
- JSON lub YAML: łatwiejsze dla zewnętrznych narzędzi i modów, ale bez typów i walidacji edytora. W razie potrzeby modów można później dodać import JSON → Resource.
- Arkusze CSV: wygodne do balansu. Rozważymy narzędzie eksportu tabeli balansu z `.tres` do CSV i z powrotem [PÓŹNIEJ].

### 3.2 Główne definicje

| Klasa | Kluczowe pola |
|---|---|
| `GoodDef` | `id: StringName`, `category`, `carry_category` (sack/crate/barrel/log/basket/bundle), `stack_size`, `base_price`, `is_rare` |
| `RecipeDef` | `inputs: Dictionary[StringName,int]`, `outputs`, `steps: Array[StepDef]` |
| `StepDef` (podklasy) | `GoToStep(target)`, `FetchStep(good, qty)`, `WorkStep(anim, duration, spot)`, `ProduceStep`, `DeliverStep`, `FieldStep(action)`, `GatherStep(resource)`… |
| `BuildingDef` | `id`, `footprint: Vector2i`, `entrance: Vector2i`, `build_cost`, `build_steps`, `workers`, `recipe`, `service_radius`, `storage_slots`, `category`, `unlock` |
| `HouseLevelDef` | `level`, `capacity`, `needs: Array[NeedDef]`, `upgrade_cost`, `tax` |
| `NeedDef` | `kind` (good/service), `goods: Array` (dowolny z listy), `consumption_rate`, `is_basic` |
| `UnitDef`, `ShipDef` | statystyki, koszt, wymagane towary, `combat: CombatStatsDef` |
| `TerrainDef` | `walkable`, `move_cost`, `buildable`, `resource` |
| `ProvinceDef` / `MapDef` | typ, rozmiar, teren (z pliku mapy), złoża, rzadki surowiec |

**Identyfikatory:** `StringName` w `snake_case` (`bread`, `bakery`). Id są stałe po wydaniu, bo zapisy gry je przechowują.

### 3.3 Rozdział logiki i wyglądu

- `BuildingDef.id = &"bakery"` nie wie nic o grafice.
- `data/visuals/buildings/bakery.tres` (`BuildingVisualDef`) wskazuje sprite’y, punkty animacji (dym, ogień), wycinki do sortowania (§6.2) i punkty pracy (`work_spots`: gdzie stoi piekarz przy stole lub przy piecu).
- Punkty pracy mają **nazwy logiczne** (`&"oven"`, `&"table"`). Symulacja używa nazwy, a pozycję na mapie ustala definicja wizualna. **Uwaga:** pozycja punktu pracy w kaflach jest częścią logiki, bo postać tam idzie. Dlatego `work_spots` jako **pozycje kafli** są zapisane w `BuildingDef`, a w `BuildingVisualDef` jest tylko **przesunięcie pikselowe** do dopasowania postaci do grafiki.
- Podmiana placeholderów na PixelLab zmienia wyłącznie `assets/` i `data/visuals/` (zob. ART_SPEC §10).

### 3.4 Walidacja

Test `tests/data/test_data_integrity.gd` sprawdza:
- czy wszystkie odwołania id istnieją,
- czy receptury się bilansują (nie ma pustych wejść i wyjść),
- czy każdy budynek ma wizualizację,
- czy każdy towar ma ikonę i kategorię noszenia,
- czy każdy klucz lokalizacji istnieje w obu językach.

---

## 4. Symulacja

### 4.1 Struktura

```
Simulation (RefCounted)
├── clock: SimClock
├── rng: SimRng (ziarno + podstrumienie dla systemów)
├── world: WorldSim            # graf prowincji, armie, floty, szlaki, złoto
├── provinces: Dictionary[int, ProvinceRuntime]
│     ProvinceRuntime = ProvinceSim (szczegółowa) LUB ProvinceAbstract (uproszczona)
├── command_queue: Array[Command]
└── event_queue: Array[SimEvent]

ProvinceSim
├── grid: TileGrid             # teren, zajętość, drogi, mury
├── nav: NavGrid               # AStarGrid2D + kolejka zapytań
├── buildings: BuildingStore
├── agents: AgentStore
├── jobs: JobBoard
├── economy: ProvinceEconomy   # magazyny, rezerwacje
└── population: Population     # domy, potrzeby, zadowolenie, siła robocza
```

### 4.2 Zegar i tick

**Decyzja:** stały tick symulacji **10 Hz** (`TICK = 0.1 s` czasu gry). Pętla w `Game` (autoload) akumuluje `delta × speed` i wykonuje 0–N ticków na klatkę, z limitem ticków na klatkę, aby uniknąć spirali śmierci. Pauza oznacza 0 ticków.

**Uzasadnienie:**
- determinizm i niezależność od FPS,
- przyspieszenie 4× to po prostu 40 ticków na sekundę,
- testy mogą wykonać 6000 ticków (10 minut gry) w pętli bez renderowania.

**Interpolacja:** widok interpoluje pozycje postaci między ostatnimi dwoma tickami, dzięki czemu ruch jest płynny przy 60+ FPS.

**Kolejność systemów w ticku (stała):**
1. komendy,
2. czas i wzrost (pola, budowy),
3. zapotrzebowania (JobBoard),
4. przydział zadań,
5. wykonanie kroków postaci (TaskRunner),
6. ruch,
7. ekonomia (konsumpcja, rezerwacje),
8. populacja (potrzeby, zadowolenie, awans domów),
9. świat (armie, floty, szlaki, prowincje uproszczone),
10. emisja zdarzeń.

### 4.3 Komendy i zdarzenia

- **Komendy** (`PlaceBuildingCommand`, `DemolishCommand`, `SetPriorityCommand`, `SetTaxCommand`, `RecruitCommand`, `MoveArmyCommand`…) to jedyny sposób zmiany stanu z zewnątrz. Wydają je UI, AI i testy. Każda komenda ma `validate(sim) -> Result` i `apply(sim)`.
- **Zdarzenia** (`SimEvent`: `building_placed`, `agent_spawned`, `good_stored`, `house_upgraded`…) symulacja wystawia do kolejki, a widok i UI je konsumują. Służą do jednorazowych reakcji wizualnych i powiadomień.
- **Odczyt stanu ciągłego** (pozycje postaci, zawartość magazynów) widok wykonuje bezpośrednio, tylko do odczytu, w każdej klatce. Nie przez zdarzenia, bo byłoby ich za dużo.

### 4.4 Losowość

`SimRng` (oparty na `RandomNumberGenerator` z ziarnem) z podstrumieniami dla poszczególnych systemów. Stan RNG jest zapisywany razem z grą. Widok ma osobny, niezapisywany RNG do efektów kosmetycznych.

---

## 5. Postacie, zadania i logistyka

### 5.1 Postać (Agent)

Zwykły obiekt (`RefCounted`) w `AgentStore`. Nie jest węzłem.

```
Agent
  id: int
  kind: StringName            # zawód lub typ: baker, farmer, porter, householder, soldier...
  home_id, workplace_id: int
  pos: Vector2                # pozycja w kaflach (float), nie w pikselach
  facing: int                 # 0..7 (S, SE, E, NE, N, NW, W, SW)
  carrying: StringName / qty
  activity: StringName        # idle / walk / work_knead / work_bake ... → animacja
  task: TaskInstance          # bieżąca sekwencja kroków i indeks kroku
  path: PackedVector2Array, path_index
```

**Widok wybiera animację** wyłącznie na podstawie `activity`, `facing` i `carrying`. To ten sam kontrakt, który opisuje ART_SPEC §4.

### 5.2 System zadań

Są dwa źródła pracy:

1. **Cykl stanowiska pracy.** Pracownik przypisany do budynku wykonuje w pętli `RecipeDef.steps`. Przykład piekarni:
   `FetchStep(flour, 2)` → `WorkStep(&"knead", 4 s, &"table")` → `WorkStep(&"bake", 8 s, &"oven")` → `ProduceStep` → `DeliverStep(bread)`.
   `FetchStep` i `DeliverStep` szukają najbliższego magazynu z towarem albo wolnym miejscem przez system rezerwacji.
2. **Zlecenia transportowe (`TransportRequest`)** na `JobBoard`: dostawy materiałów na budowy, wyjścia domowników po zapasy, przewozy między magazynami, załadunek statków i wozów. Wolni tragarze dostają zlecenia przez **zachłanne dopasowanie po odległości**, wykonywane co 5 ticków z limitem dopasowań na tick.

**Rezerwacje** (`Inventory`): `amount`, `reserved_out`, `reserved_in`, `capacity`. Pobranie i dostawa zawsze najpierw rezerwują. Dzięki temu dwóch tragarzy nie weźmie tej samej sztuki i nikt nie przyniesie towaru do pełnego magazynu. Rezerwacje mają właściciela (id postaci) i są zwalniane przy anulowaniu zadania lub zniknięciu postaci.

**Odporność na zakleszczenia:**
- każdy krok ma warunek niepowodzenia (brak ścieżki, cel zniknął, brak towaru),
- po niepowodzeniu: zwolnienie rezerwacji, odłożenie niesionego towaru do najbliższego magazynu albo na ziemię jako stos do zebrania, ponowna próba z odczekaniem.

Testy jednostkowe obejmują każdy z tych przypadków.

### 5.3 Pathfinding

**Decyzja:** `AStarGrid2D` (implementacja C++ w Godocie) na siatce kafli w **przestrzeni siatki, nie ekranu**, z 8 kierunkami ruchu i `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`, co zapobiega przechodzeniu „przez róg” między dwoma ukośnymi kaflami muru.

| Element | Ustalenie |
|---|---|
| Koszty kafli | `weight_scale` z `TerrainDef.move_cost`: droga 0,6; bruk 0,5; trawa 1,0; pole 1,2; las 1,5. Woda i budynki są `solid`, z wyjątkiem kafla wejścia. |
| Zmiany mapy | Budowa lub rozbiórka aktualizuje komórki (`set_point_solid`, `set_point_weight_scale`). Ścieżki niosą numer wersji siatki. Postać, której następny odcinek stał się nieprzejezdny, liczy ścieżkę od nowa. |
| Budżet | Kolejka zapytań `PathRequestQueue` ma limit, wyjściowo **32 zapytania na tick**. Postać czeka na ścieżkę w stanie `idle` przez co najwyżej kilka ticków, co jest niewidoczne dla gracza. |
| Pamięć podręczna | Częste trasy (budynek → najbliższy magazyn) są cache’owane per para (budynek, magazyn) i unieważniane przy zmianie wersji siatki w obszarze trasy. |
| Rezerwa | Jeśli pomiary w M1 pokażą problem: pola przepływu (flow fields) do magazynów, hierarchiczny A* albo zapytania na `WorkerThreadPool`. |
| Kolizje postaci | **Brak kolizji między postaciami.** Kilka osób może stać na jednym kaflu. Widok dodaje małe, stałe przesunięcie wynikające z id postaci, żeby postacie nie nakładały się idealnie. To kluczowa oszczędność wydajności, typowa dla gatunku. |
| Okręty | Osobny `NavGrid` dla wody o tej samej strukturze, przygotowany pod bitwy morskie [PÓŹNIEJ]. |

### 5.4 Ruch

Postać przesuwa się po punktach ścieżki z prędkością `base_speed / move_cost(kafel)`, wyjściowo 1,2 kafla/s po trawie. `facing` wylicza się z wektora ruchu kwantyzowanego do 8 kierunków **ekranowych** (zob. §6.1).

---

## 6. Warstwa wizualna

### 6.1 Geometria izometryczna

- Kafel ma **64×32 px** (romb 2:1). Szczegóły skali opisuje ART_SPEC §3.
- `IsoMath` (czysta funkcja, testowana):
  ```
  screen.x = (grid.x - grid.y) * 32
  screen.y = (grid.x + grid.y) * 16
  ```
  Odwrotność służy do przeliczania kliknięcia myszy na kafel.
- Ruch wzdłuż osi siatki wygląda na ekranie jak ruch po przekątnej (SE, NW, NE, SW). Ruch po przekątnej siatki wygląda na ekranie jak ruch w pionie lub poziomie (S, N, E, W). Kierunki animacji są **ekranowe**.
- Ustawienia: filtr tekstur `Nearest`, `snap_2d_transforms_to_pixel` i `snap_2d_vertices_to_pixel` włączone.

### 6.2 Sortowanie głębi

**Problem:** `y_sort` w Godocie sortuje po jednym punkcie na węzeł. Duży budynek ma jeden punkt, a postać stojąca przy jego prawej lub lewej ścianie może zostać narysowana za nim, choć stoi przed nim.

**Decyzja:**
1. Wszystkie obiekty świata (postacie, budynki, mury, drzewa, stosy towarów) leżą w jednym węźle z `y_sort_enabled`. Punkt sortowania to **„stopa”**: dla postaci miejsce styku z ziemią, dla obiektów kaflowych przednia krawędź podstawy.
2. **Budynki wielokaflowe są automatycznie cięte na pionowe paski o szerokości pół kafla (32 px).** Każdy pasek to osobny `Sprite2D` z `region_rect` na tej samej teksturze. Jego punkt sortowania leży na dolnej krawędzi rombu podstawy w obrębie paska. Cięcie wykonuje kod widoku na podstawie `footprint`, więc **grafik nie przygotowuje pasków ręcznie**.
3. Postacie nigdy nie stoją wewnątrz footprintu budynku. Wejście leży na krawędzi, a postać „wchodząca” do środka znika po animacji wejścia.
4. **Mury** to elementy jednokaflowe złożone z kilku kawałków, z których każdy sortuje się osobno (§6.3). Sortują się więc poprawnie z natury.
5. **Rezerwa**, jeśli paski zawiodą w testach M1: sortowanie topologiczne prostopadłościanów izometrycznych (bounding boxów) widocznych obiektów, z koszykami przestrzennymi.

**Widoczność postaci za budynkami** (do wyboru po prototypie M1, punkty a i b to minimum):
- **a)** budynek, za którym jest zaznaczona lub śledzona postać albo kursor, staje się półprzezroczysty (alpha ≈ 0,35),
- **b)** klawisz „obniż budynki”: budynki rysują tylko parter lub obrys, jak spłaszczenie widoku w Twierdzy,
- **c)** sylwetki zasłoniętych postaci rysowane przez shader. Budynki zapisują w `SubViewport` maskę z wartością głębi (y-sort) w kanałach koloru. Shader postaci porównuje własną głębię z maską i w zasłoniętych pikselach rysuje kontur lub sylwetkę w kolorze klasy lub frakcji. **Eksperyment M1:** jeśli działa wydajnie, zostaje jako domyślny tryb dla żołnierzy i postaci zaznaczonych.

### 6.3 Mury w 8 kierunkach

- Mur zajmuje kafel. `WallConnectivity` liczy **8-bitową maskę połączeń** z sąsiadami murami w 8 kierunkach siatki (czysta funkcja, testowana).
- **Składanie kawałków zamiast 256 gotowych grafik:**
  - **filar** (środek kafla), w wariantach: `post` (narożnik, koniec lub skrzyżowanie) i `none` (prosty bieg: dokładnie dwa przeciwległe połączenia, więc filar jest ukryty),
  - do **8 półsegmentów**, każdy od środka kafla do krawędzi w stronę sąsiada. Dwa półsegmenty sąsiadujących kafli tworzą pełny odcinek muru.
  - Każdy kawałek jest osobnym sprite’em z własnym punktem sortowania w środku swojej podstawy. Dzięki temu postać przy murze ukośnym lub narożniku sortuje się poprawnie.
- Gdy sąsiedzi w kierunkach osiowych i ukośnych łączą się jednocześnie, aby uniknąć „trójkątów”, łączymy po przekątnej tylko wtedy, gdy oba sąsiednie kafle osiowe nie są murem. Reguła jest w `WallConnectivity` i ma testy.
- **Pathfinding:** mur jest `solid`, a tryb `ONLY_IF_NO_OBSTACLES` uszczelnia przekątne.
- **Bramy:** specjalny kafel z kierunkiem osiowym, przejezdny dla swoich, zamknięty dla wrogów. **Chodzenie po murach** [1.0] korzysta z osobnej warstwy nawigacji „na murze” z przejściami przez schody i baszty.

### 6.4 Postacie w widoku

- `AgentViewPool`: pula węzłów `AgentSprite` (`Sprite2D` + własny odtwarzacz klatek). Węzeł dostaje postać tylko wtedy, gdy ta jest w prostokącie kamery powiększonym o margines. Pozostałe postacie nie mają węzłów.
- Animacje odtwarza prosty licznik klatek oparty na tablicy regionów atlasu. Bez `AnimationPlayer`, żeby było tanio.
- **Lustrzane odbicia** realizuje `flip_h`, zgodnie z tabelą kierunków w ART_SPEC §4.2.
- **Niesiony towar** to drugi sprite (nakładka) na punkcie zaczepienia z tabeli klatek (ART_SPEC §5).
- Przy zoomie 0,5× postacie mają obniżony framerate animacji, a nakładki towarów są uproszczone do kolorowej plamki z ikony.

### 6.5 Magazyn: jedno źródło prawdy

- `Stockpile` (sim) przechowuje sloty: `slot_index → {good, amount}`. Lista w UI i wygląd placu wynikają z tych samych danych.
- `StockpileLayout.visual_for(slot, def) -> {sprite_id, fill_stage}` to **czysta funkcja**. Faza zapełnienia (1–4) wynika z `amount / stack_size`. Widok tylko ją wyświetla.
- Test: dla losowych stanów magazynu suma ilości w UI = suma w slotach, a faza każdego stosu jest zgodna z funkcją.

### 6.6 Łączenie domów w kamienice

`HouseRowResolver` (czysta funkcja w widoku, bo nie wpływa na logikę) dla każdego domu poziomu 2 lub wyższego sprawdza sąsiadów tego samego poziomu wzdłuż obu osi, przylegających pełną krawędzią i wyrównanych. Zwraca wariant `single`, `end_a`, `middle` albo `end_b` i oś. Grafiki wariantów opisuje ART_SPEC §7.

### 6.7 Kamera i zoom

- Zoom w krokach **0,5× · 1× · 2× · 3×** (kółko myszy), z animowanym przejściem i przyciąganiem do kroku na końcu animacji.
- Przy 1× jeden piksel grafiki odpowiada jednemu pikselowi ekranu w rozdzielczości 1080p.
- Przy 1440p i 4K stosujemy **skalę bazową** całkowitą (1× lub 2×) wynikającą z wysokości okna. Zoom gracza mnoży skalę bazową.
- Przesuwanie kamery: WSAD lub strzałki, krawędź ekranu, przeciąganie środkowym przyciskiem myszy.

---

## 7. Prowincje nieoglądane: symulacja dwutrybowa

**Decyzja:**
- Tylko oglądana prowincja działa w trybie **szczegółowym** (`ProvinceSim`).
- Pozostałe, w tym wszystkie prowincje AI, działają w trybie **uproszczonym** (`ProvinceAbstract`), z tickiem co 1 s czasu gry.

### 7.1 Tryb uproszczony

- Stan zawiera budynki (bez postaci), magazyny (liczby), domy (poziom, mieszkańcy, zadowolenie), siłę roboczą, garnizon i postęp budów.
- **Produkcja** jest liczona jako przepływ. Dla każdego obsadzonego budynku:
  ```
  cycle_time = sum(czasy WorkStep) + travel_estimate
  rate = outputs / cycle_time × efektywność(zadowolenie, obsada)
  ```
  Wejścia są pobierane proporcjonalnie, a przy braku wejść produkcja się zatrzymuje.
- `travel_estimate`:
  - kalibrowane **średnią kroczącą rzeczywistych czasów transportu** zmierzonych, gdy prowincja była oglądana (zapisaną per budynek),
  - jeśli takich pomiarów nie ma: estymata z długości ścieżki do najbliższego magazynu × 2 / prędkość.
- Potrzeby, zadowolenie i awans domów działają według tych samych reguł, tylko na zagregowanych liczbach.

### 7.2 Przełączanie trybów

| Przejście | Co się dzieje |
|---|---|
| Szczegółowy → uproszczony (gracz opuszcza prowincję) | Towary niesione wracają do magazynu, z którego je pobrano (albo trafiają do celu, jeśli postać była bliżej celu). Rezerwacje zostają wyczyszczone. Postęp cyklu pracy zapisujemy jako procent. Postacie przestają istnieć, a zostają liczby. |
| Uproszczony → szczegółowy (gracz wchodzi) | Pracownicy pojawiają się na swoich stanowiskach w kroku wynikającym z zapisanego procentu cyklu. Tragarze pojawiają się przy swoim magazynie lub ratuszu. Zawartość magazynów to te same liczby, więc gracz natychmiast widzi stosy. |

**Test spójności** (`tests/scenario/`): ta sama prowincja przez 30 minut gry w trybie szczegółowym i uproszczonym ma dać produkcję chleba różną najwyżej o ±15%. Tolerancję będziemy zawężać w miarę strojenia.

**Alternatywa:** pełna symulacja szczegółowa wszystkich prowincji. Odrzucona z powodu kosztu CPU i braku korzyści, bo gracz i tak nie widzi tych postaci.

---

## 8. Zapis i odczyt

- **Zapisujemy tylko stan `Simulation`.** Każda klasa stanu implementuje `to_dict() -> Dictionary` i `static from_dict(d) -> Self`. Widok jest w całości odtwarzany ze stanu.
- **Format:** JSON skompresowany do `.sav` (`FileAccess.open_compressed`, ZSTD). Wersje deweloperskie dodatkowo zapisują nieskompresowany `.json` do debugowania.
- **Nagłówek:** `save_version`, wersja gry, data, nazwa prowincji, miniatura [1.0].
- **Migracje:** łańcuch funkcji `migrate_vN_to_vN+1(dict)` w `SaveMigrations`. Każda zmiana formatu podbija wersję i dodaje migrację oraz test na zapisanym pliku-fixturze.
- **Zawartość:** id encji (licznik `next_id`), wszystkie rezerwacje, zadania postaci (indeks kroku, cele po id), stan RNG i zegar.
- **Nie zapisujemy:** ścieżek (są liczone od nowa po wczytaniu), węzłów widoku ani cache’y.
- **Test round-trip:** stan → zapis → odczyt → zapis daje identyczny słownik. Dodatkowo test, w którym symulacja po wczytaniu idzie dalej deterministycznie tak samo jak bez zapisu.

---

## 9. Wydajność

### 9.1 Docelowe liczby

| Wielkość | Cel |
|---|---|
| Postacie w aktywnej prowincji | do **500** |
| Postacie widoczne na ekranie | do **250** przy 60 FPS na średnim PC (4 rdzenie, zintegrowana lub niższa dedykowana grafika) |
| Rozmiar mapy prowincji | do 192×192 kafli |
| Prowincje w świecie | 20–40, w tym 1 szczegółowa |
| Ludność całkowita królestwa | kilka tysięcy (agregaty w trybie uproszczonym) |
| Budżet ticku symulacji (aktywna prowincja) | ≤ 4 ms przy 500 postaciach, tak aby przy prędkości 4× (≈ 4 ticki na klatkę) mieścić się w klatce |

### 9.2 Ocena głównych kosztów

| Obszar | Ocena | Środki zaradcze |
|---|---|---|
| Pathfinding | Główny koszt szczytowy. A* w C++ na 36 tys. komórek to zwykle ułamki milisekundy na zapytanie, ale 500 postaci zmieniających cel jednocześnie dałoby piki. | Budżet zapytań na tick, cache tras budynek → magazyn, brak kolizji między postaciami. Rezerwa: flow fields, wątki. |
| System zadań | Przy naiwnym „każdy tragarz sprawdza każde zlecenie” rośnie jak O(n·m). | Dopasowanie co 5 ticków, limit dopasowań na przebieg, indeks przestrzenny magazynów (kubełki 16×16 kafli). |
| Animacje | 250 sprite’ów z ręcznym odtwarzaniem klatek to dla Godota niewielki koszt. Kosztowne byłoby 500 węzłów `AnimationPlayer` i węzły dla niewidocznych postaci. | Pula węzłów tylko dla widocznych postaci, odtwarzacz klatek bez `AnimationPlayer`, atlasy tekstur (mniej przełączeń tekstur). |
| Sortowanie | y-sort setek węzłów co klatkę jest tani. Cięcie budynków na paski zwiększa liczbę sprite’ów 2–4×. | Pomiar w M1. Rezerwa: pominięcie cięcia dla budynków, przy których nie ma postaci, albo `RenderingServer` bez węzłów. |
| Skrypty GDScript w pętli ticku | GDScript jest wolniejszy od C#. | Statyczne typowanie (szybszy kod), tablice `Packed*` dla danych masowych. Rezerwa: przeniesienie gorących pętli (ruch, dopasowanie zadań) do GDExtension (C++), jeśli profiler to wskaże. |

**Test wydajności (M1):** scena benchmarkowa z 500 postaciami chodzącymi losowo między 20 budynkami na mapie 192×192. Logujemy czasy ticku i FPS przy każdym poziomie zoomu.

---

## 10. Walka i jednostki (przygotowanie)

- Żołnierz to `Agent` z `CombatState` (HP, cel, cooldown ataku). Te same systemy ruchu, sortowania i animacji co cywile.
- Okręt to `ShipUnit` z `CombatState` i ładownią (`Inventory`), poruszający się po `NavGrid` wodnym. Na mapie świata to część floty. **Struktura od razu pozwala na interaktywne bitwy morskie [PÓŹNIEJ]** bez przebudowy: brakuje wtedy tylko AI walki okrętów, animacji i UI.
- Automatyczne rozstrzyganie (`BattleResolver`) to czysta funkcja `(armia A, armia B, teren, fortyfikacje, rng) → wynik`, pokryta testami.

---

## 11. Lokalizacja

**Decyzja:** pliki **gettext `.po`** (`localization/pl.po`, `en.po`) i szablon `messages.pot`.

**Uzasadnienie:**
- `.po` obsługuje **formy liczby mnogiej**, a CSV nie. Polski wymaga 3 form:
  `Plural-Forms: nplurals=3; plural=(n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);`
- `.po` ma też standardowe narzędzia, np. Poedit.

Zasady:
- **Klucze zamiast tekstu źródłowego** (`msgid "ui.build_menu.title"`). Oba języki mają pełne tłumaczenia, a brak tłumaczenia wychwytuje test.
- **Klucze danych są wyprowadzane z id:**
  - nazwa: `good.<id>.name`,
  - opis: `good.<id>.desc`,
  - forma liczbowa: `good.<id>.count`,
  - analogicznie `building.<id>.*`, `unit.<id>.*`, `step.<activity>.label` (np. „piecze chleb”).
- **Liczba mnoga:** `tr_n("good.bread.count", "good.bread.count_plural", n)` z formatowaniem `%d`. Pomocnik `Loc.count(&"bread", n)`.
- **Zakaz tekstów na sztywno.** Tekst widoczny dla gracza powstaje tylko przez `tr()` lub `tr_n()` albo przez automatyczne tłumaczenie węzłów UI z kluczem w `text`. Test `test_no_hardcoded_strings` skanuje `src/ui` i `src/view` w poszukiwaniu literałów przypisywanych do `text`, `tooltip_text` i `title`, które nie są kluczami.
- **Formatowanie liczb:** `Fmt.number(n)` ze spacją jako separatorem tysięcy w PL i przecinkiem w EN.
- **Fonty:** font pixelowy z licencją OFL (lub podobną) obsługujący **Latin Extended-A** (ą ć ę ł ń ó ś ź ż i wielkie litery). Wybór w M0. Test glifów renderuje wszystkie polskie znaki i sprawdza, czy font je zawiera (`Font.has_char`).
- **Dłuższe teksty:** layout oparty na kontenerach z automatycznym rozmiarem, bez stałych szerokości przycisków. W M3 sprawdzamy UI z włączoną **pseudolokalizacją** Godota (wydłużanie tekstów o 30–40%).
- Generowanie `.pot`: z edytora (Projekt → Lokalizacja → Generowanie POT) oraz z danych przez skrypt `tools/extract_data_keys.gd`, który dopisuje klucze wynikające z id definicji.

---

## 12. Testy

| Poziom | Zakres | Narzędzie |
|---|---|---|
| Jednostkowe | `IsoMath`, `WallConnectivity`, `StockpileLayout`, `Inventory` z rezerwacjami, przydział zadań, kroki zadań (w tym ścieżki błędów), ruch, potrzeby i zadowolenie, awans domów, `BattleResolver`, polskie formy liczby mnogiej | gdUnit4 |
| Scenariuszowe (headless) | mała mapa-fixture: „po 10 min gry w magazynie jest chleb”, „dom awansuje”, „rozbiórka w trakcie dostawy nie gubi towaru”, spójność trybu szczegółowego i uproszczonego, determinizm, round-trip zapisu | gdUnit4 + `Simulation` bez sceny |
| Dane | integralność id, kompletność wizualizacji i lokalizacji | gdUnit4 |
| Wydajność | benchmark 500 postaci (ręcznie lub w nocnym przebiegu, nie blokuje commitów) | scena benchmarkowa + log |

**Zasada:** każda zmiana w `src/sim` ma test. Testy muszą przechodzić przed commitem.

---

## 13. Konwencje kodu

- [Oficjalny styl GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).
- Nazwy plików `snake_case.gd` i `.tscn`, klasy `PascalCase` (`class_name`), funkcje i zmienne `snake_case`, stałe `UPPER_SNAKE`, prywatne z prefiksem `_`.
- Sygnały w czasie przeszłym (`building_placed`).
- **Statyczne typowanie jest obowiązkowe.** W ustawieniach projektu ostrzeżenia `untyped_declaration` i `unsafe_*` są ustawione jako błędy w `src/sim` i `src/core`.
- `src/sim/**` nie może importować niczego z `src/view`, `src/ui`, ani używać `Node`, `get_tree()` czy autoloadów widoku. Pilnuje tego test skanujący pliki.
- Id definicji zapisujemy jako `StringName` (`&"bread"`), a często używane stałe trzymamy w `Ids` (klasa ze stałymi), żeby uniknąć literówek.
- Komentarze i nazwy w kodzie po angielsku. Dokumentacja po polsku.
- Commity małe, z opisem po angielsku w trybie rozkazującym („Add stockpile layout”). Każdy commit przechodzi testy.

---

## 14. Autoloady (singletony)

| Autoload | Rola |
|---|---|
| `Data` | rejestr definicji, tylko do odczytu |
| `Game` | posiada bieżącą `Simulation`, pętlę ticków, prędkość i pauzę |
| `EventBus` | rozsyłanie `SimEvent` do widoku i UI |
| `Loc` | pomocnicy lokalizacji i formatowania |
| `SaveService` | zapis, odczyt i migracje |

Symulacja **nie** korzysta z autoloadów (poza `Data`, przekazywanym jawnie przez konstruktor, co ułatwia testy).
