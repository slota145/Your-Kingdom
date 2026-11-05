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
- **Renderer: Forward+ (D3D12)**, decyzja z M1. W benchmarku 500 postaci Compatibility (OpenGL) był 2–3× wolniejszy (75 vs 219 FPS przy zoomie 0,5×), a Forward+ na zintegrowanej grafice Intela był równie szybki jak na RTX (§9.3).

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
│   ├── resource_nodes/         # drzewa i inne złoża na kaflach (ResourceNodeDef)
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
│   │   ├── core/               # Simulation, SimClock, SimRng, Command, SimEvents, EntityIds, SimCodec
│   │   ├── commands/           # PlaceBuildingCommand, DemolishCommand, SpawnAgentCommand...
│   │   ├── grid/               # TileGrid, ResourceField, IsoMath (czysta matematyka)
│   │   ├── pathing/            # NavGrid (AStarGrid2D), PathRequestQueue
│   │   ├── economy/            # Stockpile (sloty + rezerwacje), Reservation, StockpileLayout, GroundPile
│   │   ├── buildings/          # BuildingState, BuildingStore, Construction, ConstructionSite
│   │   ├── farming/            # FieldStore (kafle pól farm)
│   │   ├── agents/             # Agent, AgentStore, Task, TaskRunner, Movement, steps/
│   │   ├── jobs/               # JobBoard, TransportRequest
│   │   ├── population/         # Population, HouseState, ServiceCoverage
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
| `RecipeDef` | `steps: Array[StepDef]` (M2). `inputs`/`outputs` jako podsumowanie dla UI dojdą w M3 |
| `StepDef` (podklasy, czyste dane) | `GoToStepDef(target, resource)`, `FetchStepDef(good, amount)`, `WorkStepDef(activity, duration, spot)`, `GatherStepDef`, `ProduceStepDef(output, amount)`, `DeliverStepDef(drop_on_fail)`, później `FieldStepDef(action)`… Wykonuje je symulacja (`src/sim/agents/steps/`), definicje nie zawierają logiki |
| `ResourceNodeDef` | `good`, `amount` (ile razem), `per_gather` (ile na kurs), `solid`. Drzewo: 3 kłody po 1, po ostatniej zostaje pniak (M2: bez odrastania) |
| `BuildingDef` | `id`, `footprint: Vector2i`, `entrance: Vector2i`, `build_cost`, `build_time`, `worker_kinds` (zawód na każde miejsce pracy), `staffing_priority`, `recipe`, `work_radius`, `max_fields`, `field_grow_time`, `service_radius`, `storage_slots`, `house_levels`, `category`, później `unlock` |
| `HouseLevelDef` | `level`, `capacity`, `needs: Array[NeedDef]`, `supply_units` (spiżarnia), `upgrade_cost`, `upgrade_time`, później `tax` |
| `NeedDef` | `kind` (good/service), `goods: Array` (dowolny z listy), `service` (id budynku), `per_resident_per_minute`, `weight` (punkty zadowolenia), `is_basic` |
| `UnitDef`, `ShipDef` | statystyki, koszt, wymagane towary, `combat: CombatStatsDef` |
| `TerrainDef` | `index` (zapis w siatce), `walkable`, `move_cost`, `buildable`, `map_color`, `resource_node` (las → drzewo) |
| `ProvinceDef` / `MapDef` | M3: `MapDef` = obrazek terenu, `entry_tile`, układ startowy (`StartBuildingDef`: budynek, mieszkańcy, towary). Później: typ, złoża, rzadki surowiec |

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

**Realizacja (M2):**
- Rezerwacje żyją w `Stockpile` (sloty + rezerwacje z właścicielem). Osobnej klasy `Inventory` nie ma. Magazyn to budynek z `Stockpile`, a kupa na ziemi (`GroundPile`) to `Stockpile` z jednym slotem, który tylko oddaje towar.
- Wykonawcy kroków są bezstanowi. Wszystko, co krok pamięta, jest w tablicy zadania (`Task.bb`), która trafia do zapisu. Klucze z `_` są lokalne dla kroku i znikają po jego zakończeniu.
- Kiedy postać idzie, krok nie jest wywoływany co tick (oszczędność). Jeśli cel zniknie po drodze, rozbiórka sama przerywa zadania, które go dotyczą.
- Po niepowodzeniu postać z towarem w rękach dostaje zadanie „odłóż” (`stash`): najbliższy magazyn z miejscem, a gdy go nie ma albo nie ma do niego drogi, kupa na ziemi. Kupa od razu tworzy zlecenie transportowe.
- Tragarz niesie **1 sztukę** na kurs (`JobBoard.PORTER_LOAD`, potwierdzone przez właściciela projektu; większe ładunki dadzą wózki i wozy, zob. IDEAS). Rezerwacja pobrania powstaje już przy przydziale zlecenia, więc dwóch tragarzy nie dostanie tej samej sztuki.
- Zlecenie niewykonalne (brak towaru albo miejsca) czeka, a po nieudanym kursie odpoczywa 5 s. Zlecenie z celem, który zniknął, jest anulowane.
- Pracownicy w M2 pojawiają się przez `SpawnAgentCommand` + `AssignWorkerCommand`. Automatyczny przydział wolnego mieszkańca do nowego budynku przychodzi z populacją w M3.

Testy jednostkowe obejmują każdy z tych przypadków.

**Realizacja (M3):**
- **Budowa:** postawienie budynku tworzy `ConstructionSite` z własnym id i własnym `Stockpile` (adresowany jak magazyn). Plac zamawia od razu całe materiały przez `JobBoard`. Faza 1 i 2 zużywają po połowie kosztu (`BuildingDef.phase_cost`), czas `build_time` dzieli się po równo. Budowniczy (`builder`, pracownik ratusza) bierze najbliższy plac, na którym jest co robić (`Construction.site_for`), i wykonuje krok `build`. Awans domu to plac jednofazowy na gotowym domu. Rozbiórka: dostarczone materiały wracają w całości, zużyte w połowie, gotowy budynek oddaje połowę kosztu (kupy na ziemi).
- **Magazyny publiczne i prywatne:** `nearest_source` i `nearest_sink` widzą tylko magazyny publiczne (`BuildingState.stock`) i kupy. Spiżarnia domu (`supply`) i plac budowy przyjmują dostawy tylko wtedy, gdy ktoś je wprost wskaże.
- **Pola:** `FieldStore` trzyma kafle pól z farmą, etapem, czasem siewu i dojrzałości oraz roszczeniem rolnika. Wzrost nie wymaga pracy w ticku: kafel jest dojrzały, gdy `tick >= ripe_tick`. Krok `field` wybiera: żniwa > siew > orka, najbliższy kafel. Żniwa kończą się wiązaniem snopa, a następny krok receptury (`deliver`) niesie go do magazynu.
- **Ludność** (`Population`, raz na sekundę): konsumpcja ułamkowa ze spiżarni, zadowolenie dąży do sumy wag spełnionych potrzeb (2 pkt/s), domownik (`householder`) wychodzi po towar, gdy zapas spada do połowy (niesie do 2 sztuk), awans po 60 s spełnionych potrzeb, ostrzeżenie po 60 s braków, spadek po 180 s. Nowi mieszkańcy (`settler`) przychodzą pieszo z `entry_tile` co 10 s do domu z wolnym miejscem i zadowoleniem ≥ 50. Pracuje połowa mieszkańców. Wolni dostają przydział do budynków z brakami według `staffing_priority` (ratusz 0), z najbliższego domu. Postać pracownika pojawia się w domu i idzie do pracy. Gdy dom traci ludzi, najnowsi pracownicy z niego tracą pracę (postać znika, niesiony towar ląduje na ziemi).
- **Zasięg usług** (`ServiceCoverage`): Dijkstra z kopcem po kosztach ruchu od wejścia budynku usługowego. Liczony od nowa, gdy zmieni się siatka nawigacji albo zbiór budynków usługowych. Nie jest zapisywany, bo wynika ze stanu.
- **Drogi:** warstwa w `TileGrid`, koszt 0,67 (+50% szybkości, GDD §5.2). Pole ma koszt 1,2.

**Realizacja (M4a):**
- **Tragarze magazynów:** magazyn ma 2 miejsca pracy `porter` (`staffing_priority` 6, czyli po produkcji). `JobBoard` nie rozróżnia, skąd jest tragarz: każdy wolny tragarz bierze najbliższe zlecenie.
- **Rezerwa (opał przed budową):** `BuildingState.reserves` (towar → sztuki), domyślnie z `BuildingDef.default_reserves` (magazyn: 5 drewna). Zlecenie z celem na placu budowy szuka źródła przez `nearest_source(..., keep_reserve = true)` i `can_give`, więc rezerwa zostaje w magazynie. Domownicy i receptury biorą bez ograniczeń. Komenda `SetReserveCommand`.
- **Priorytet pracy:** `BuildingState.priority` (wysoki, normalny, niski), komenda `SetPriorityCommand`. `Population._balance_workforce` sortuje miejsca pracy po priorytecie gracza, potem po `staffing_priority`, potem po id. Gdy brakuje wolnych ludzi, a budynek wyżej stoi pusty, jeden pracownik najniżej postawionego budynku (najnowszego) wraca do domu (raz na sekundę). W następnej sekundzie dostaje go ważniejszy budynek. Zdarzenie `worker_reassigned`.
- **Złoto:** `Treasury` (złoto, stawka podatku, ułamek) należy do `Simulation`, bo jest globalne. `ProvinceSim.treasury` wskazuje ten sam obiekt. Podatek co sekundę: mieszkańcy × `HouseLevelDef.tax_per_minute` / 60 × zadowolenie / 100 × mnożnik stawki (0,5 / 1 / 1,5). Stawka dodaje do celu zadowolenia +10 / 0 / −15. `BuildingDef.gold_cost` płacimy przy postawieniu (`PlaceBuildingCommand` sprawdza, czy starczy). Rozbiórka placu przed rozpoczęciem pracy oddaje całość, później i po ukończeniu połowę.
- **Wagi potrzeb na poziom:** `NeedDef` jest wspólny dla poziomów, a `HouseLevelDef.need_weights` nadpisuje wagę (`weight_of`), żeby suma na każdym poziomie wynosiła 100.
- **Awans tylko przy zapasie:** dom zaczyna awans dopiero wtedy, gdy w magazynach i spiżarni jest po pełnej spiżarni (`supply_units` następnego poziomu) każdego towaru podstawowego następnej klasy (`Population.next_level_available`). Bez tego automatyczny gracz pokazał „huśtawkę”: dom awansował, po 3 minutach braku piwa spadał i deski szły na marne.
- **Dwa surowce w recepturze:** warsztat z `BuildingDef.input_goods` ma mały prywatny schowek (`BuildingState.supply`, 2 sztuki na towar). Krok `deposit` odkłada niesiony towar do schowka. `FetchStepDef.skip_if_stocked` pomija kurs, gdy schowek już ma towar (np. po przerwanym cyklu). `ProduceStepDef.consume` zużywa towary ze schowka. Browar: zboże do schowka, chmiel w rękach, warzenie, 2 beczki.
- **Nad wodą:** `BuildingDef.needs_terrain_near` (wędkarz: woda w `work_radius`) sprawdza `placement_error` (`no_water_nearby`). `GoToStepDef.target = &"shore"` wybiera najbliższy wolny kafel brzegu (`ProvinceSim.find_shore`) i zapisuje w `bb["node"]` kafel wody, żeby wędkarz patrzył na wodę.
- **Skały:** `MapDef.resource_spots` (kafel → węzeł) kładzie pojedyncze węzły na mapie, np. skały `rock` (8 kamieni). Kamieniarz używa tych samych kroków co drwal.
- **Uprawy:** chmielnik to farma z `FieldStepDef.harvest_good = hops`. Widok rysuje pola z folderu `terrain/field_<towar>`, jeśli istnieje (chmiel: tyczki), w innym razie `terrain/field`.

### 5.3 Pathfinding

**Decyzja:** `AStarGrid2D` (implementacja C++ w Godocie) na siatce kafli w **przestrzeni siatki, nie ekranu**, z 8 kierunkami ruchu i `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`, co zapobiega przechodzeniu „przez róg” między dwoma ukośnymi kaflami muru.

| Element | Ustalenie |
|---|---|
| Koszty kafli | `weight_scale` z `TerrainDef.move_cost`: droga ubita 0,67 (M3, zgodnie z GDD +50%); bruk 0,5; trawa i łąka 1,0; pole 1,2; las 1,5; bród 2,0. Woda i budynki są `solid`, z wyjątkiem kafla wejścia. |
| Zmiany mapy | Budowa lub rozbiórka aktualizuje komórki (`set_point_solid`, `set_point_weight_scale`). Ścieżki niosą numer wersji siatki. Postać, której następny odcinek stał się nieprzejezdny, liczy ścieżkę od nowa. |
| Budżet | Kolejka zapytań `PathRequestQueue` ma limit, wyjściowo **32 zapytania na tick**. Postać czeka na ścieżkę w stanie `idle` przez co najwyżej kilka ticków, co jest niewidoczne dla gracza. |
| Pamięć podręczna | Częste trasy (budynek → najbliższy magazyn) są cache’owane per para (budynek, magazyn) i unieważniane przy zmianie wersji siatki w obszarze trasy. **W M2 jeszcze niepotrzebne** (500 tragarzy mieści się w budżecie, §9.3). Wracamy do tego w M4, jeśli pomiar pokaże piki. |
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

**Stan po M1:**
- **Sortowanie jest zweryfikowane automatycznie.** Test `tests/unit/view/test_sorting.gd` porównuje punkty sortowania z prawdziwą głębią izometryczną (`DepthOracle`) dla każdej pozycji, w której może stanąć idąca postać. Sprawdzane przypadki:
  - budynki od 1×1 do 4×4,
  - mury proste, ukośne, narożniki 45°, 90° i 135°,
  - trójniki, skrzyżowania (także ukośne) i bramy.

  Wynik: 0 błędów. Próba kontrolna (celowo przesunięte punkty) jest wykrywana.
- **Zapasy:** postać przed budynkiem ma co najmniej 8 px zapasu nad punktem sortowania paska, a za budynkiem ponad 16 px.
- **M4b-1.5:** lustrzane grafiki tnie ten sam `BuildingSlicer` (piwot odbity w poziomie). `test_sorting.gd` sprawdza też domy w każdej orientacji (okapy szersze z jednej strony), rzędy, rogi i rzędy plecami do siebie, w tym kolejność pasków dwóch stykających się budynków.
- **Warianty a i b są zaimplementowane** (`BuildingView.set_faded`, `set_lowered`). Wariant b tnie każdy pasek osobno tuż nad przednią krawędzią, przez co powstaje schodkowa linia cięcia. Do wygładzenia shaderem przy grafikach docelowych.
- **Wariant c odłożony.** Wymaga wspólnej maski głębi w `SubViewport`, a a+b wystarczają do sprawdzenia czytelności. Wracamy do niego w M7 (wojsko za murami).

### 6.3 Mury w 8 kierunkach

- Mur zajmuje kafel. `WallConnectivity` liczy **8-bitową maskę połączeń** z sąsiadami murami w 8 kierunkach siatki (czysta funkcja, testowana).
- **Składanie kawałków zamiast 256 gotowych grafik:**
  - **filar** (środek kafla), w wariantach: `post` (narożnik, koniec lub skrzyżowanie) i `none` (prosty bieg: dokładnie dwa przeciwległe połączenia, więc filar jest ukryty),
  - do **8 półsegmentów**, każdy od środka kafla do krawędzi w stronę sąsiada. Dwa półsegmenty sąsiadujących kafli tworzą pełny odcinek muru.
  - Każdy kawałek jest osobnym sprite’em z własnym punktem sortowania w środku swojej podstawy. Dzięki temu postać przy murze ukośnym lub narożniku sortuje się poprawnie.
- Gdy sąsiedzi w kierunkach osiowych i ukośnych łączą się jednocześnie, aby uniknąć „trójkątów”, łączymy po przekątnej tylko wtedy, gdy oba sąsiednie kafle osiowe nie są murem. Reguła jest w `WallConnectivity` i ma testy.
- **Pathfinding:** mur jest `solid`, a tryb `ONLY_IF_NO_OBSTACLES` uszczelnia przekątne.
- **Bramy:** specjalny kafel z kierunkiem osiowym, przejezdny dla swoich, zamknięty dla wrogów. **Chodzenie po murach** [1.0] korzysta z osobnej warstwy nawigacji „na murze” z przejściami przez schody i baszty.

**Mur kamienny: model bryłowy** (decyzja 2026-11-04, prototyp w `src/prototype/walls/`). Opisany wyżej model „linii” zostaje dla palisady.
- Każdy kafel muru kamiennego to pełny blok 1×1. Ściany boczne i krawędzie korony (z blankami) rysujemy tylko tam, gdzie sąsiad nie jest murem. Równoległe rzędy zlewają się więc w jeden gruby mur.
- **Przekątne, wariant „prosto”:** w wolnych kaflach między dwoma blokami po przekątnej stoją trójkątne kliny o przyprostokątnej 1 kafla, więc lico muru jest proste. Klin nie powstaje w narożniku 90° ani w trójniku, czyli wtedy, gdy mur biegnie dalej prosto przez drugi kafel pośredni. Kafle z klinami są w nawigacji `solid`. Mur ukośny jest przez to ok. √2 grubszy od osiowego.
- **Sortowanie:** bloki, kliny i blanki są osobnymi kawałkami z punktem sortowania w środku ciężkości podstawy. Wyjątki:
  - pomost bramy sortuje się na przedniej krawędzi przejścia,
  - wszystko, co stoi na koronie (blanki, ludzie), sortuje się co najmniej 1 px za kawałkiem, na którym stoi.

  Sprawdzone tą samą metodą co `test_sorting.gd`: 0 błędów dla postaci na ziemi.
- **Brama** w murze kamiennym to tunel: dwa filary i pomost niosący koronę.

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

`HouseRowResolver` (czysta funkcja w widoku, bo nie wpływa na logikę) dla każdego domu poziomu 2 lub wyższego sprawdza sąsiadów tego samego poziomu i tej samej orientacji wzdłuż frontu domu (orientacje 0 i 2: oś y, 1 i 3: oś x), przylegających pełną krawędzią i wyrównanych. Dom z jednym sąsiadem w rzędzie, za którym stoi dom obrócony prostopadle, jest rogiem (`corner_a`/`corner_b`), a dom za nim łączy się z nim jak z sąsiadem. Wynik: `single`, `end_a`, `middle`, `end_b`, `corner_a` albo `corner_b`. `BuildingVisualDef.row_variant_name` dobiera kształt szczytu według położenia, a `BuildingLayer.oriented_art` grafikę `_back` i lustro (sufiks klucza `@m`; `BuildingView.setup(…, mirrored)` odbija teksturę i piwot). Grafiki opisuje ART_SPEC §7.

**Orientacja (M4b-1.5):** `BuildingState.orientation` (domy 0–3, reszta 0–1). `BuildingDef.entrance_at` i `door_dir` obracają wejście (1 = zamiana x i y, 2 = obrót o 180°, 3 = oba); obrysy są kwadratowe, więc kafle się nie zmieniają. `ProvinceSim.find_path` prowadzi każdą ścieżkę do wejścia i z wejścia przez kafel przed drzwiami najbliższymi celu (`door_pairs`); cały obrys budynku, także wejścia, jest w `NavGrid` nieprzechodni. `BuildingDef.door_orientations` daje drzwi budynku (`door_sides`: domy jedne, magazyny z każdej strony, reszta z przodu i z tyłu); sprawdzanie miejsca wymaga jednych drzwi z dostępem i nie pozwala odciąć innych budynków. Obrót postawionego budynku: `RotateBuildingCommand`. Podgląd stawiania: `PlacementTurn` (UI) i `ProvinceSim.suggested_orientation` (droga przed drzwiami, potem rząd z sąsiadem). `BuildRoadCommand` obraca domy bez drogi przed drzwiami do nowej drogi (`turn_houses_to_road`, `turn_building`; zdarzenie `building_turned`). Wybrany wygląd domu to `BuildingState.look` (`SetLookCommand`), czytany tylko przez widok.

### 6.6a Widok prowincji (M3)

- `ProvinceView` składa warstwy: teren (`TerrainLayer`: teren organiczny z shadera `organic_ground` czytającego mapę kafli z tekstury, potem ozdoby i pola; kawałki 16×16 przerysowywane tylko po zmianie, ART_SPEC §8.1), nakładki (`TileOverlay`: zasięg studni, kursor budowy), świat z `y_sort` (natura, `BuildingLayer`, kupy, postacie). Czyta stan symulacji co klatkę, a zmiany budynków robi po zdarzeniach.
- `BuildingLayer` wybiera grafikę ze stanu: plac budowy fazy 1 lub 2 ze stosem materiałów, gotowy budynek, dom na swoim poziomie (wariant pierzei z `HouseRowResolver`), rusztowanie przy awansie, plac magazynu ze stosami. Nad budynkiem bez pracowników jest znak „!”.
- `data/visuals/buildings/<id>.tres` (`BuildingVisualDef`): folder grafik, grafiki poziomów domu, od którego poziomu domy łączą się w pierzeję, przesunięcia punktów pracy (`spot_offsets`, np. piec i stół w piekarni). `data/visuals/agents/<kind>.tres` (`AgentVisualDef`): postać i kolor zawodu.
- UI (`src/ui`) opisuje postać przez `AgentDescriber` z tych samych danych, które animuje widok (czynność, bieżący krok, niesiony towar), więc tekst zgadza się z obrazem.
- Scena gry: `src/main/game_scene.tscn`. Gracz zmienia stan wyłącznie komendami. Szybki zapis to F5, przycisk albo powrót do menu głównego (żeby pomyłkowe kliknięcie nie kasowało gry), a odczyt F9, przycisk albo menu główne. Pseudolokalizacja do sprawdzania długości tekstów: F11.

### 6.7 Kamera i zoom

- Zoom w krokach **0,5× · 1× · 2× · 3×** (kółko myszy), z animowanym przejściem i przyciąganiem do kroku na końcu animacji.
- **Skala bazowa (decyzja M1):**
  - rozdzielczość logiczna 1280×720, tryb `canvas_items`, `aspect = expand`, **`scale_mode = integer`**,
  - Godot sam dobiera całkowitą skalę płótna do okna: 1080p → 1, 1440p i 2560×1600 → 2, 4K → 3,
  - zoom gracza ją mnoży, więc piksel grafiki zawsze wypada na całkowitą liczbę pikseli ekranu (poza 0,5× przy skali 1).

  Przykład na ekranie 2560×1600: zoom 1× daje 2 px ekranu na piksel grafiki (postać ma 84 px), a 0,5× daje 1:1.
- **Interfejs** skaluje się razem z płótnem. Rozmiary fontów pikselowych dobieramy tak, żeby po skalowaniu były wielokrotnościami siatki fontu.
- Tryb gracza: domyślnie pełny ekran w natywnej rozdzielczości [M10]. W trakcie produkcji okno ma 1600×900.
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
- **Zawartość:** id encji (licznik `next_id`), wszystkie rezerwacje, zadania postaci (rodzaj, indeks kroku, tablica `bb` z celami po id), **pozostałe punkty ścieżek i kolejka zapytań o ścieżki**, roszczenia do drzew, zlecenia transportowe, stan RNG i zegar.
- **Ścieżki zapisujemy (decyzja z M2).** Liczenie ich od nowa w połowie drogi może przy remisach kosztów dać inną trasę. Wtedy wczytana gra rozjechałaby się z grą bez zapisu, a DoD wymaga identycznego przebiegu. Koszt: kilkadziesiąt liczb na idącą postać.
- **Nie zapisujemy:** węzłów widoku, cache’y, kolejki zdarzeń (widok opróżnia ją co klatkę) ani komend czekających na następny tick. `prev_pos` po wczytaniu równa się `pos`.
- **Liczby:** JSON zapisujemy z pełną precyzją (`full_precision`), żeby pozycje float wracały bit w bit. Wartości 64-bitowe (stan RNG) zapisujemy jako tekst. Siatki kafli zapisujemy jako base64.
- **Wersja 2 (M3):** teren i drogi w siatce, place budowy, pola, wejście na mapę, dom postaci, stan domów. Migracja v1 → v2 w `SaveMigrations` (mapa v1 to sama trawa, wszystkie budynki gotowe). Fixtury: `tests/fixtures/saves/v1_woodcutter.json` i `v2_village.json`.
- **Wersja 3 (M4a):** skarbiec (`treasury`), rezerwy magazynów, priorytety pracy, schowki warsztatów. Migracja v2 → v3 daje miastu z M3 100 złota, magazynom rezerwę 5 drewna, a spiżarniom chat sloty na nowe towary. `BuildingState.from_dict` dodatkowo poszerza spiżarnię, gdy dane dodadzą nowe towary. Fixtura: `tests/fixtures/saves/v3_town.json`.
- **Wersja 4 (M4a, wnioski z testów):** zapas na budowy w prowincji (`keep_for_building`, towar → liczba sztuk). Migracja v3 → v4 daje pusty zapas, więc stara gra działa jak wcześniej. Fixtura: `tests/fixtures/saves/v4_town.json`.
- **Wersja 6 (M4b-1.5):** każdy budynek zapisuje orientację (`orient`), a dom wybrany wygląd (`look`, gdy różny od 0). Migracja v5 → v6 daje 0, czyli dotychczasowe wejście. Fixtura: `tests/fixtures/saves/v6_town.json`.
- **Mapa** to obrazek PNG importowany jako `Image` (nie tekstura), więc symulacja czyta piksele bez widoku. Kolor piksela = `TerrainDef.map_color`. Zapis gry zawiera już gotowy teren, więc późniejsza zmiana obrazka nie psuje zapisów.
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

### 9.3 Wyniki M1

Pomiar: `src/prototype/m1/m1_bench.tscn -- --bench` (scena usunięta w M2), okno 1600×900, vsync wyłączony, laptop z RTX 5070 Ti oraz zintegrowaną grafiką Intel.
- Postacie chodzą między losowymi celami w obszarze 48×48 wokół 20 budynków i murów.
- Pathfinding przez `NavGrid` (AStarGrid2D) z budżetem 32 zapytań na tick.
- Pula sprite’ów tylko dla widocznych postaci.

| Konfiguracja | Zoom | Widoczne | Śr. FPS | 99. percentyl klatki | Tick symulacji |
|---|---|---|---|---|---|
| 500 postaci, Forward+, RTX | 0,5× | 498 | 219 | 5,3 ms | 0,64 ms |
| | 1× | 408 | 322 | 3,3 ms | 0,64 ms |
| | 2× | 233 | 547 | 2,1 ms | 0,66 ms |
| 500 postaci, Forward+, **Intel iGPU** | 0,5× | 498 | 223 | 4,8 ms | 0,63 ms |
| 500 postaci, Compatibility, RTX | 0,5× | 498 | 75 | 15,0 ms | 0,64 ms |
| **2000 postaci**, Forward+, RTX | 0,5× | 1983 | 91 | 13,6 ms | 1,84 ms (max 2,8) |
| | 1× | 1511 | 103 | 11,7 ms | 2,37 ms |

**Wnioski:**
- Cel (250 widocznych przy 60 FPS, tick ≤ 4 ms przy 500 postaciach) jest spełniony z około 4× zapasem.
- Wąskim gardłem jest CPU (skrypt widoku), a nie GPU: iGPU = RTX.
- Rezerwy z §9.2 (flow fields, GDExtension) nie są na razie potrzebne. Ponowny pomiar w M4, z prawdziwymi zadaniami zamiast losowego chodzenia.
- Zastrzeżenie: CPU laptopa jest szybszy niż „średni PC”. Przy 2× wolniejszym CPU szacujemy ok. 110 FPS przy 500 widocznych postaciach.

**Pomiar M2 (chmura, headless, bez GPU — tylko czas ticku):** `src/prototype/m2/m2_bench.tscn -- --bench`. Tragarze wykonują prawdziwe zlecenia transportowe (`TaskRunner`, `JobBoard`, rezerwacje) między 3 magazynami na mapie 64×64, prędkość 4×.

| Konfiguracja | Tick symulacji (śr.) |
|---|---|
| 200 tragarzy + drwal | 1,1 ms |
| 500 tragarzy + drwal (`--porters=500`) | 2,1 ms |

Cel ≤ 4 ms przy 500 postaciach jest spełniony.

**Pomiar M2 (laptop, 2026-11-05):** ta sama scena z oknem, `--resolution 1600x900 ... -- --bench`, vsync wyłączony, Forward+ (D3D12), RTX 5070 Ti. 200 tragarzy, prędkość 4×, 60 s pomiaru.

| Śr. FPS | Najgorsza klatka | Tick symulacji (śr.) |
|---|---|---|
| 713 | 3,2 ms | 0,54 ms |

DoD M2 (płynność przy 4× z 200 postaciami) jest spełniony z dużym zapasem. Najgorsza klatka mieści się ok. 5× w budżecie 60 FPS.

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
- **Statyczne typowanie jest obowiązkowe.** W ustawieniach projektu `untyped_declaration` jest błędem w całym projekcie (z wyłączeniem `addons/`), a `unsafe_*` to ostrzeżenia. Godot nie pozwala ustawić poziomów ostrzeżeń osobno dla folderów.
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
