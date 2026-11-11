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
├── treasury: Treasury         # złoto, wspólne dla całego królestwa (GDD §3.5)
├── world: WorldSim            # prowincje świata: definicja, mapa, właściciel; czasy podróży;
│                              # wyprawy, szlaki handlowe, żądania osad neutralnych (M7+: armie, floty)
├── runtimes: Dictionary[int, RefCounted]   # tylko zasiedlone prowincje
│     ProvinceSim (oglądana, szczegółowa) LUB ProvinceAbstract (uproszczona)
├── viewed_id: int, province: ProvinceSim   # prowincja oglądana = runtimes[viewed_id]
├── command_queue: Array[Command]
└── event_queue: Array[SimEvent]

**M6, część 2 (wyprawy):** zbiórka wyprawy należy do prowincji (`Departure` w `ProvinceSim.departure`: osadnicy wychodzą z domów, tragarze znoszą zestaw na wóz albo na nabrzeże, a portowcy na kogę gracza, której `Voyage` ładuje wtedy zestaw zamiast planu). Gdy ostatni opuści mapę, `Simulation` zamienia ją w wyprawę świata (`Expedition` w `WorldSim.expeditions`): podróż po zegarze (`travel_seconds`), czekanie przy granicy, a po wejściu gracza nowa `ProvinceSim` z wariantu szablonu (`load_map(map, mirrored, richness, settled)`) z lądowaniem (`Landing.arrive_by_sea` albo `arrive_by_land`). Po lądowaniu koga wraca do portu tyle, ile płynęła. Osadnicy i woźnica idą zadaniem `KIND_TRAVEL` (`TravelStep`). Przebieg od 2026-11-06: `PrepareExpeditionCommand(prowincja, morzem?)` zaczyna zbiórkę bez celu (działa też dla prowincji nieoglądanej: tam `gather_at_once`). Gdy wszyscy są i zestaw jest załadowany, `Departure` przechodzi w `READY` (wóz stoi przed ratuszem, koga czeka zacumowana, `Voyage` nie odbija, dopóki `Departure.target == 0`). `SendExpeditionCommand(skąd, dokąd)` płaci złoto i ustawia cel, a dalej wszystko idzie jak wcześniej. `DisbandExpeditionCommand` przed wysłaniem oddaje ludzi do domów i zestaw do magazynów (w oglądanej prowincji kładzie go na ziemi dla tragarzy, a koga rozładowuje się przez `UNLOADING`). Zapis bez zmiany formatu: `READY` dopisano na końcu wyliczenia, a stare zbiórki mają już cel, więc ruszają same. Interfejs: `ExpeditionBox` w panelu ratusza i na mapie świata, znaczek wyprawy i prawy przycisk w `WorldMapCanvas`. Wariant szablonu: odbicie zamienia x z y (na ekranie lewo z prawo; budynki startowe dostają orientację 1), a bogactwo 1 usuwa co trzecie złoże, 3 daje półtora raza więcej w każdym.

**M6, część 3 (szlaki, osady, wino):** szlak handlowy to `TradeRoute` w `WorldSim.routes` (skąd, dokąd, morzem czy lądem, pojazd, do 3 linii towar/ilość/próg, stan i ładunek w drodze). `TradeRoutes.update` co sekundę (z `Simulation._update_world`) prowadzi każdy szlak: w stanie „czeka” liczy kurs (`plan_run`: linie, w których B ma mniej niż próg, a A ma towar, przycięte do ładowni), potem załadunek w A, podróż po zegarze (`travel_seconds`), rozładunek w B i powrót. Załadunek kogi to jej `Voyage` z `route` (ładuje `route_run` zamiast planu, nie kupuje, a za horyzontem oddaje ładunek do `shipped`, który zabiera szlak; koga zostaje „za horyzontem”, dopóki szlak nie wróci, `call_home`). Załadunek i rozładunek wozu to `RouteWagon` w `ProvinceSim.route_wagons`: skład adresowany id szlaku (tragarze ładują go przez zlecenia transportu, jak wóz osadników) i woźnica z zadaniem `KIND_TRAVEL` (`bb.route`), który czeka przy wozie, a potem jedzie za krawędź mapy; w B wjeżdża i stoi przy magazynie najbliższym wjazdu. W prowincji nieoglądanej wszystko dzieje się od razu, a `ProvinceAbstract.freeze` kończy wozy szlaków (`finish_at_once`). Wóz kupiecki należy do składu kupieckiego (`trading_post`, `BuildingState.lent`; od 2026-11-07, `TradeRoute.WAGON_LOAD` 40, podróż ×1,25 w `TradeRoutes.travel_seconds`); jego woźnica nie bierze zleceń w mieście (`Carriers.carter_ready`). Jednorazowy szlak (`one_off`) robi rejs „do mojej prowincji” z panelu portu (`StartVoyageCommand.to_province`). Osada neutralna: `NeutralTown.build` stawia miasteczko z danych `ProvinceDef` (`town_buildings`, `town_burghers`) w nowej grze (`from_world`) albo w pierwszych sekundach starego zapisu i zamraża je (`ProvinceAbstract`), a `Simulation.step` nie liczy prowincji, która nie należy do gracza. Żądanie to `NeutralSettlement` w `WorldSim.settlements` (złoto, towary, co już dano, termin); `_update_settlements` przekazuje osadę graczowi albo po terminie daje nowe, droższe żądanie. Szlak do osady neutralnej liczy towar do żądania (`NeutralSettlement.take`). Wino: `ProvinceSim.load_map(..., rare)` zapamiętuje rzadki surowiec (`rare_resource`) i kładzie ziemię winną (`vine_soil`) w prowincji z winoroślą; `BuildingDef.needs_rare` pozwala postawić winnicę tylko tam, a `field_bonus_terrain` i `field_bonus` przyspieszają krzewy na ziemi winnej (od 2026-11-07), a `NeedDef.extra` i `tax_bonus` robią z wina potrzebę ponad 100 punktów (`Population._pay_taxes`).

**M6, część 1:** `Simulation.province` zostało jako skrót do oglądanej prowincji, więc kod widoku, komend i testów działa bez zmian. Gra na jednej mapie to świat z jedną prowincją (`WorldSim.single`, `world_id` pusty). Prowincja pusta nie ma `runtime`, dopóki ktoś jej nie zasiedli (`Simulation.open_province`). Do oglądanej prowincji przełącza `EnterProvinceCommand` (tylko prowincje gracza). Encje wszystkich prowincji biorą id z jednego licznika `EntityIds`, a każda prowincja w trybie uproszczonym ma własną, nieczytaną kolejkę zdarzeń.

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
9. świat (armie, floty, szlaki, prowincje uproszczone: każda raz na sekundę, w ticku `id % 10` w obrębie sekundy, żeby nie liczyły się wszystkie naraz),
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
- Tragarz niesie **1 sztukę** na kurs (`JobBoard.PORTER_LOAD`, potwierdzone przez właściciela projektu; większe ładunki dają wózki i wozy od M4b-3). Rezerwacja pobrania powstaje już przy przydziale zlecenia, więc dwóch tragarzy nie dostanie tej samej sztuki.
- Zlecenie niewykonalne (brak towaru albo miejsca) czeka, a po nieudanym kursie odpoczywa 5 s. Zlecenie z celem, który zniknął, jest anulowane.
- Pracownicy w M2 pojawiają się przez `SpawnAgentCommand` + `AssignWorkerCommand`. Automatyczny przydział wolnego mieszkańca do nowego budynku przychodzi z populacją w M3.

Testy jednostkowe obejmują każdy z tych przypadków.

**Realizacja (M3):**
- **Budowa:** postawienie budynku tworzy `ConstructionSite` z własnym id i własnym `Stockpile` (adresowany jak magazyn). Plac zamawia od razu całe materiały przez `JobBoard`. Faza 1 i 2 zużywają po połowie kosztu (`BuildingDef.phase_cost`), czas `build_time` dzieli się po równo. Budowniczy (`builder`, pracownik ratusza) bierze najbliższy plac, na którym jest co robić (`Construction.site_for`), i wykonuje krok `build`. Awans domu to plac jednofazowy na gotowym domu. Rozbiórka: dostarczone materiały wracają w całości, zużyte w połowie, gotowy budynek oddaje połowę kosztu (kupy na ziemi).
- **Magazyny publiczne i prywatne:** `nearest_source` i `nearest_sink` widzą tylko magazyny publiczne (`BuildingState.stock`) i kupy. Spiżarnia domu (`supply`) i plac budowy przyjmują dostawy tylko wtedy, gdy ktoś je wprost wskaże.
- **Pola:** `FieldStore` trzyma kafle pól z farmą, etapem, czasem siewu i dojrzałości oraz roszczeniem rolnika. Wzrost nie wymaga pracy w ticku: kafel jest dojrzały, gdy `tick >= ripe_tick`. Krok `field` wybiera: żniwa > siew > orka, najbliższy kafel. Żniwa kończą się wiązaniem snopa, a następny krok receptury (`deliver`) niesie go do magazynu.
- **Ludność** (`Population`, raz na sekundę): konsumpcja ułamkowa ze spiżarni, zadowolenie dąży do sumy wag spełnionych potrzeb (2 pkt/s), domownik (`householder`) wychodzi po towar, gdy zapas spada do połowy (niesie do 2 sztuk), awans po 60 s spełnionych potrzeb, ostrzeżenie po 60 s braków. Brak potrzeby podstawowej odejmuje jej wagę od celu zadowolenia; po 300 s braku i przy zadowoleniu < 40 co 180 s odchodzi jeden mieszkaniec, ale nigdy poniżej połowy miejsc (`core_residents`, decyzja 2026-11-06). Nowi mieszkańcy (`settler`) przychodzą pieszo z `entry_tile` co 10 s do domu z wolnym miejscem i zadowoleniem ≥ 50, albo ≥ 30 do połowy miejsc (`accepts_newcomer`). Tempo pracy (`WorkStep`, prace polowe) dzieli się przez `work_speed` domu pracownika (0,8–1,0 przy zadowoleniu 0–50); tryb uproszczony mnoży postęp cykli przez średnią prowincji (`average_work_speed`). Pracuje połowa mieszkańców. Wolni dostają przydział do budynków z brakami według `staffing_priority` (ratusz 0), z najbliższego domu. Postać pracownika pojawia się w domu i idzie do pracy. Gdy dom traci ludzi, najnowsi pracownicy z niego tracą pracę (postać znika, niesiony towar ląduje na ziemi).
- **Zasięg usług** (`ServiceCoverage`): Dijkstra z kopcem po kosztach ruchu od wejścia budynku usługowego. Nie jest zapisywany, bo wynika ze stanu. **Od M4b-3 przyrostowo:** każdy budynek usługowy ma własny wynik (lista kafli), a na kaflu jest licznik źródeł danej usługi. Źródło liczy zasięg od nowa tylko wtedy, gdy zmieniony kafel leży w jego zasięgu albo tuż obok (Dijkstra czyta tylko te kafle), więc wynik jest taki sam jak przy liczeniu wszystkiego od zera, także po wczytaniu gry. Tawerna bez napitków wyłącza i włącza swój wynik bez liczenia. Koszt zasięgu to droga, bruk, pole i teren, **bez drzew** (ścinanie i sadzenie przy mieście nie zmienia zasięgów). Dijkstra czyta płaskie tablice (`NavGrid.solid_map`, `ServiceCoverage.cost_map`).
- **Drogi:** warstwa w `TileGrid`, koszt 0,67 (+50% szybkości, GDD §5.2). Pole ma koszt 1,2.
- **Zagrody (Z1):** kratka zagrody to kafel pola (`FieldStore`) należący do budynku z `BuildingDef.max_pens` (chlew: 12, zasięg 4); te same komendy co pola (`PlaceFieldCommand`, `RemoveFieldCommand`, `BuildingDef.field_limit`), to samo blokowanie miejsca i zapis. `ProvinceSim.is_pen` odróżnia kratkę zagrody od pola: koszt ruchu `PEN_COST` 6 (ludzie obchodzą ogrodzenie, pracownik wchodzi). `BuildingState.pens` (nieliczone w zapisie, `update_herd_room` po każdej zmianie i `update_herd_rooms` po wczytaniu) daje miejsce stada `herd_room` = kratki × `BuildingDef.pen_animals` (2, stadnina 1), czyli `stack_limit` stada (`yard`); stado ponad miejsce zostaje, nie rośnie, a `herd_spare` (ponad `BuildingState.herd_keep`, suwak 2..miejsce, `SetHerdKeepCommand`) biorą rzeźnik, kupiec i koszary. Para przychodzi raz, gdy zagroda gotowego budynku ma na nią miejsce (`give_pair`, `herd_given`). Świniarz idzie do kratki (`GoToStepDef.target = &"pen"`, bez kratek `no_pen`). `Pens` (sim): `groups` (kratki stykające się bokiem = jedna zagroda), `gate` (bok kratki najbliżej drzwi budynku), `auto_place` (zagroda w jednym kawałku obok budynku, nie przed drzwiami; dla osad, władców i testów). Widok: `PenLayer` rysuje płot na brzegach zagrody (każdy odcinek osobnym węzłem sortowanym w połowie brzegu), furtkę otwartą, gdy pracownik stoi w niej albo przed nią, i zwierzęta (tylko widok: losowy spacer po kratkach własnej zagrody i do sąsiedniej kratki, odpoczynek albo ryjenie; nic nie jest zapisywane); podłoże `terrain/pen/ground*.png` rysuje `TerrainLayer`. **Część 2:** `BuildingDef.herd_work` (owczarnia): czas `WorkStep` × `BuildingState.herd_work_factor` (√(8 / stado)), w trybie uproszczonym ten sam mnożnik w `estimated_cycle_seconds` (bez pomiaru i bez zapamiętanego tempa); bez stada `GoToStep` zwraca `no_animals`. `Movement` liczy prędkość na kratce zagrody jak na polu (`FIELD_COST`), choć szukanie drogi płaci `PEN_COST`. Kupiec: `Merchant.ANIMALS` (cena, sztuk na wizytę), `buy_animal`, `animal_error`, `BuyAnimalCommand` (`BuyPigCommand` to jego odmiana dla świni). **Część 3:** ule to kafle pola pasieki (`BuildingDef.max_hives`, `has_hives`, `has_tiles` = zagrody albo ule, `paced_work` = stado albo ule; `BuildingState.hives` liczone jak `pens`, `work_factor` √(4 / ule), `has_work_source`). `ProvinceSim.is_hive`; koszt ruchu jak pola. `GoToStepDef.target = &"hive"`: obok jednego z uli (`approach_tile`), każdy krok „do ula” ma własny wybór w tablicy zadania (`hive<numer kroku>`), więc pszczelarz dogląda jednego ula, a miód zbiera z drugiego. Widok: `PenLayer` stawia kosz (`nature/hive/skep.png`) na każdym ulu i rysuje pszczoły nad światem (`_Bees`, `z_index` 1); `TerrainLayer` kładzie pod ulem `terrain/hive/ground.png`.

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

**Realizacja (M4b-2):**
- **Stos przy budynku (`BuildingState.yard`):** warsztat, którego cykl coś odnosi (`BuildingState.yard_goods`: wyroby `ProduceStepDef`, `FieldStepDef`, węzłów z `GoToStepDef`), ma `Stockpile` z jednym slotem na wyrób i `stack_divisor = 2` (pół stosu). Adres stosu to **ujemne id budynku** (`ProvinceSim.yard_id`), więc `storage`, `access_tile` (wejście budynku), `all_storages` i rezerwacje działają bez osobnej encji. `DeliverStep`: gdy `nearest_sink` nic nie znajdzie, pracownik (zadanie receptury albo odłożenia) niesie wyrób na swój stos; gdy stos jest pełny, idzie pod budynek i czeka z towarem (`bb["_yard_full"]`, sprawdzenie co 1 s). `TaskRunner` nie zaczyna nowego cyklu, gdy stos jest pełny towaru, na który nie ma miejsca (`ProvinceSim.yard_blocked`, powód `yard_full`). Odłożenie na stos tworzy zlecenie ze stosu do „dowolnego magazynu” (`JobBoard.add_or_merge`), a `trim_yard_requests` co 1 s przycina je do tego, co jest na stosie (inni mogą brać ze stosu: `nearest_source` widzi stosy). Pusty stos nie trafia do zapisu, bo odtwarza go `ensure_yard`. **Podwórko (poprawka z oceny 2026-11-07):** stos stoi na jednym kaflu budynku zostawionym w grafice wolnym, obok drzwi (`BuildingDef.yard_tile`, domyślnie `yard_at`: kafel przy ścianie z drzwiami, w stronę tyłu). `PileLayer` dzieli stos na dwie połówki i sortuje każdą tuż za pasem budynku (`BuildingSlicer`) nad jej kolumnami ekranu; ludzie chodzą po liniach między środkami kafli, więc ci przed budynkiem są dalej rysowani przed stosem (test w `test_sorting.gd`). Stado (chlew) zostaje na kaflach zagrody jak dotąd.
- **Las:** `ResourceNodeDef.move_cost` (drzewo 1,5) i `solid = false`. `refresh_tile` bierze większy z kosztów terenu i węzła. Skały dalej blokują. Leśniczy (`can_plant`) sadzi na każdym wolnym kaflu w zasięgu, nie na drodze ani polu i nie obok budynku; limitu drzew nie ma.
- **Stado (`BuildingDef.herd_good`):** chlew ma stos (`yard`) jednego towaru z limitem `herd_capacity`. `_breed_herds` co 1 s: przy ≥ 2 zwierzętach, pracowniku i miejscu dolicza `GROW_CHECK_TICKS` i co `breed_time × 2 / stado` dodaje zwierzę. `nearest_source` zostawia `herd_keep` zwierząt, a `nearest_sink` kieruje żywe towary (`GoodDef.is_live`, kategoria `animal`) tylko do stad. Rzeźnik niesie świnię jak towar; widok rysuje ją obok postaci (`AgentSprite._show_led`).
- **Targowisko:** `BuildingDef.stall_goods` daje kramy (`supply`, 6 sztuk na towar, `one_slot_per_good`). Straganiarz: `ChooseStallStep` (najmniej zapełniony kram, którego towar jest w magazynach) → `FetchStep` → `DepositStep` → praca `sell`. Targowisko działa w zasięgu, gdy kramy mają towar (`_update_markets` przesuwa `serving_until`). `Population._request_supplies` najpierw szuka targowiska w zasięgu domu z towarem (`ProvinceSim.market_source`) i wpisuje je zleceniu domownika jako `from`.
- **Kupiec (`Merchant`, `ProvinceSim.merchant`):** stany `AWAY → COMING → TRADING → LEAVING`. Postać `merchant` z zadaniem `KIND_MERCHANT` (`MerchantStep`). Przy targowisku otwiera wóz: `Stockpile` z własnym id encji (`wagon_id`), adresowany jak magazyn (`storage`, `access_tile` = miejsce wozu). Co 1 s płaci za towar dowieziony na wóz (cena bazowa) i ustawia zlecenia „z dowolnego magazynu na wóz” na nadwyżkę ponad próg gracza (`JobBoard.set_amount`). `BuyPigCommand` płaci i dodaje świnię na wóz ze zleceniem do chlewu; nieodebrane świnie są zwracane w złocie, gdy kupiec odjeżdża. Progi: `SetSellAboveCommand` (`Merchant.sell_above`).
- **Liczniki:** `GoodsLedger` (`ProvinceSim.ledger`) liczy towary wytworzone (zbiór, żniwa, produkcja, narodziny, kupno) i zużyte (jedzenie, przetwarzanie, budowy, tawerna, sprzedaż) w 5 minutowych kubełkach. Tylko statystyka dla okna „Zapasy królestwa”, nie trafia do zapisu.

**Realizacja (M4b-3):**
- **Bruk:** `TileGrid` trzyma w warstwie dróg 0 (brak), 1 (ubita) albo 2 (bruk), więc format siatki się nie zmienia. `BuildPavingCommand` zamienia wolny teren w drogę ubitą i zakłada `PavingSite` (własne id, `Stockpile` na kamień, kolejka kafli), który zamawia 1 kamień na kafel przez `JobBoard` (z rezerwą magazynu jak budowa). `access_tile` placu to następny kafel do ułożenia, więc tragarze kładą kamień tam, gdzie pracuje budowniczy. `Construction.site_for` daje budowniczemu najpierw budowy, potem bruk; `BuildStep` idzie na kafel, pracuje 3 s i woła `ProvinceSim.pave_next`. Usunięcie drogi z zamówionego kafla zmniejsza zamówienie (`_withdraw_paving`); kamień, który został, ląduje na ziemi. Widok: niebieski kanał mapy terenu oznacza bruk, a shader rysuje go teksturą `terrain/paving`. Zapis v8 (`paving`).
- **Wózki:** `BuildingDef.max_carts` (magazyn: 2), `BuildingState.carts` (kupione, `BuyCartCommand` zdejmuje 3 deski z najbliższych magazynów przez `take_from_storages`). `JobBoard._assign_one`: gdy zlecenie potrzebuje jeszcze ≥ 2 sztuk, a magazyn wybranego tragarza ma wolny wózek (`Carriers.has_free_handcart`: kupione minus używane przez jego tragarzy), ładunek rośnie do 3 (`_largest_load` sprawdza źródło i cel), a tragarz dostaje `Agent.vehicle = handcart`. Wózek zostaje przy tragarzu, dopóki ten ma towar w rękach (także przy odkładaniu po niepowodzeniu). `Movement` mnoży koszt kafla poza drogą przez 1/0,7. `Carriers.still_handling` dodaje w `FetchStep` i `DeliverStep` 1 s na sztukę (czynność `load`). Widok rysuje wózek przed postacią (`AgentSprite._update_vehicle`, arkusz 5 kierunków `vehicles/handcart/{empty,loaded}`).
- **Wozy konne:** `ProvinceSim.road_nav` to druga `NavGrid`, w której przejezdne są tylko kafle dróg (aktualizowana w `refresh_tile`). Woźnica (`carter`, pracownik `stable`) ma `vehicle = wagon`; `Movement` liczy mu ścieżkę przez `find_road_path` (wyjście z budynku drzwiami z drogą przed nimi), a kafle poza drogą sprawdza w `road_nav`. Przystanek wozu to `road_stop(id)`: kafel z drogą przed drzwiami budynku (także stosu i placu budowy), następny kafel bruku albo kupa lub wóz kupca stojące na drodze; `Carriers.stop_for` podaje go `FetchStep` i `DeliverStep`. `JobBoard.update` najpierw daje wozom zlecenia z ≥ 4 sztukami (`_assign_wagon`: oba przystanki istnieją, są ≥ 10 kafli od siebie i łączy je droga, źródło i cel mieszczą 4–6 sztuk; cel „dowolny magazyn” wybiera `Carriers.road_sink` z góry), potem tragarzom. Żywy towar nie jedzie wozem. Woźnica jest gotowy (`Carriers.carter_ready`), gdy ma już wóz albo stoi w stajni; między kursami zadanie `park` (`ParkStep`) odprowadza wóz drogą pod stajnię, zdejmuje go i wchodzi do środka (można je przerwać nowym kursem). Widok: wóz jedzie 0,6 kafla za woźnicą, który prowadzi konia (`vehicles/wagon/{empty,loaded}`, 112×80).

- **Tereny (część 2):** `TerrainDef.farmable` (kamienisty grunt: nie, `field_error` → `terrain_not_farmable`), `counts_as` (jezioro liczy się jako `water` dla `needs_terrain_near`, `find_shore` i komunikatu o wejściu na wodę; `is_kind`), `extra_map_color` + `extra_node` (drugi kolor na mapie: kamienisty grunt ze skałą). `ResourceNodeDef.leaves_terrain`: wydobyta skała zamienia kafel w kamienisty grunt (`ProvinceSim.leave_terrain`, zdarzenie `terrain_changed`). Mapa `lakeland` (128×128) jest rysowana skryptem `tools/generate_lakeland_map.py`; menu ma przycisk „Nowa gra” dla każdej mapy (`Game.start_request["map"]`).

**Realizacja (M5, część 1):**
- **Statek** (`ShipUnit`, `ProvinceSim.ships`): id, definicja (`ShipDef`, `data/ships/`), pozycja i kierunek, ścieżka, dom (`home_id`: przystań), przystań lub stocznia, przy której cumuje (`dock_id`), załoga (`crew`: id postaci) i ładownia (`Stockpile`, adresowana id statku jak magazyn; na razie trafiają tam tylko ryby rybaka, który zniknął na morzu). `Ships.move_all` przesuwa statki co tick i niesie załogę (postać ma wtedy `vehicle = boat` i nie chodzi sama).
- **Budynki na wodzie:** `BuildingDef.water_tiles` (kafle, które muszą być morzem), `berth` (miejsce cumowania przed pomostem), `berth_fairway` (stocznia: potrzebny tor do głębokiej wody). `BuildingDef.turned` obraca kafle względne jak wejście. `placement_error`: `needs_sea`, `no_berth`, `no_deep_water`, `tile_has_ship`.
- **Stocznia:** `BuildingState.ship_orders` (kolejka, komendy `OrderShipCommand`, `CancelShipOrderCommand`). `Ships.update` (co 1 s) otwiera `ShipBuild` dla pierwszego zamówienia: własne id i `Stockpile` jak plac budowy, zlecenia `JobBoard` na wszystkie materiały (z rezerwą magazynów), uzupełniane co sekundę (`ShipBuild.still_needed`). Krok `ship_build` (`ShipBuildStep`): etap startuje, gdy jego materiały leżą na pochylni, cieśla odrabia `build_time / stages`; po ostatnim etapie `Ships.launch` stawia statek na `berth`.
- **Przystań rybacka:** receptura `net_fishing`: idź do pracy → `SailStep(shoal)` (wsiada do łodzi przy pomoście albo przy stoczni, zajmuje najbliższą ławicę w promieniu 24 kafli i płynie na nią) → praca `cast_net`, `wait_net`, `haul_net` → `GatherStep` (6 ryb) → `SailStep(home)` → `DeliverStep`. Zadanie przerwane na morzu kończy się zadaniem `sail_home`. `Ships.update` daje nowym łodziom najbliższą przystań bez łodzi i odsyła do domu łodzie bez załogi.
- **Ławice:** węzeł `fish_shoal` (`solid = false`) z `ResourceNodeDef.regrow_time`: co 20 s każda ławica poniżej pełnej odzyskuje rybę (w tickach podzielnych przez czas odnowy, więc bez zapisywanego licznika; `ProvinceSim._regrow_nodes`). Ławice na mapie to drugi kolor terenu morza (`extra_map_color`).
- **Widok:** `ShipLayer` (statki i statek na pochylni, w świecie sortowanym), `ShoalLayer` (ławice, pod światem); `AgentViewPool` nie rysuje postaci na łodzi. Shader terenu ma slot `SHALLOW`.

**Realizacja (M5, część 2):**
- **Port:** `BuildingDef.quay_slots` (plac portowy, 6 slotów) i `gangway` (stopa trapu na nabrzeżu), `is_port()`. Plac to `BuildingState.stock`, ale budynek nie ma `storage_slots`, więc `nearest_source`/`nearest_sink`, wozy i rezerwy go nie widzą: towar trafia tam i stamtąd tylko przez zlecenia z id portu. `Harbour.update` (co 1 s) daje zlecenie „z placu do dowolnego magazynu” na wszystko, czego nie trzyma statek przy nabrzeżu (towary, które kupuje kupiec morski, czekają na placu).
- **Cumowanie:** `ShipUnit.berth_id` (zapisywane) to port, którego miejsce statek zarezerwował w drodze albo przy którym stoi (`Harbour.claim_berth`, `berth_holder`, `moor`: statek staje wzdłuż nabrzeża). Port ma jedno miejsce; drugi statek go nie dostanie.
- **Ładownia jak magazyn:** ładownia statku zacumowanego w porcie (`Harbour.port_of`) przyjmuje dostawy (`accepts_deliveries`), a jej `access_tile` to wejście portu. Zlecenia z ładownią na jednym końcu (`Harbour.request_port`) dostają tylko portowcy (`docker`, 2 na port) tego portu (`JobBoard.update`); zwykli tragarze i wozy ich nie biorą.
- **Trap:** po dojściu do wejścia `FetchStep` i `DeliverStep` wołają `Harbour.walk_out`: portowiec idzie po prostej przez nabrzeże do stopy trapu i po trapie do statku (tempo pieszego, liczone w tickach w `Task.bb["_gw"]`), podaje towar przez 1 s (`hand_over`), towar zmienia właściciela (`commit`), a `walk_back` prowadzi go tą samą drogą z powrotem (droga zapisana w `bb`, więc wraca nawet wtedy, gdy statek odpłynął). Przerwane zadanie stawia go z powrotem w wejściu (`Harbour.step_ashore` w `TaskRunner.fail`), więc nic nie ląduje w wodzie. Widok nie wygasza postaci w porcie (to otwarty plac).
- **Kupiec morski (`SeaMerchant`, `ProvinceSim.sea_merchant`):** stany `AWAY → COMING → TRADING → LEAVING` jak `Merchant`. Wizyta: pierwszy port z wolnym miejscem, wejście to kafel głębokiej wody na krawędzi mapy najbliższy miejscu cumowania, z którego prowadzi droga (`_edge_for`); obca koga (`foreign_cog`, ładownia 8×10) z ofertą w ładowni rezerwuje miejsce i płynie. Przy nabrzeżu co 1 s: rozliczenie (`_settle`: zmiana zawartości ładowni od ostatniej sekundy; ubyło jego towaru — płaci gracz; przybyło towaru gracza — płaci kupiec), zlecenia „z magazynów na plac” (nadwyżka ponad `Merchant.sell_above`, razem do 40 sztuk na wizytę), „z placu do ładowni” (to, co leży na placu) i „z ładowni na plac” (`buy_up_to` minus zapas królestwa, towar w rękach i zarezerwowany w ładowni, w granicach złota). Po 4 minutach zlecenia znikają, kupiec czeka (do 30 s), aż portowcy zejdą z trapu, i odpływa do swojej krawędzi, gdzie statek znika. Gdy nie ma portu, sprawdza znowu po minucie.
- **Widok:** `QuayYard` (deski placu jako naklejka pod światem i stosy towarów; grafika portu ma przezroczyste kafle lądu), `ShipLayer` rysuje kogę z arkusza 220×220 (`BIG_FRAMES`) i trap (`Polygon2D`) do każdego statku w porcie. `ShipPanel` (kliknięcie statku) pokazuje stan, handel kupca i ładownię przez `StockpilePanel` czytający `Stockpile` statku.

**Realizacja (M5, część 3):**
- **Koga gracza:** `ShipDef.stage_goods` (koszt każdego etapu osobno: szkielet 8 desek, poszycie 10 desek i 4 smoły, maszt z żaglem 2 deski i 4 sukna, wodowanie 2 smoły) i `ShipDef.trades` (statek handlowy gracza). Taki statek ma `ShipUnit.voyage` (`Voyage`, zapisywane): port macierzysty (`home_id`, najbliższy port bez kogi), kotwicowisko (`anchor`: głęboka woda co najmniej 3 kafle od miejsca cumowania, poza torem wodnym, BFS po `cog_nav`), plan (`sell`, `order`) i stan rejsu. `Ships.update` takich statków nie rusza; robi to `Voyage.update_all` (raz na sekundę, po kupcu morskim, przed `Harbour.update`).
- **Rejs:** `IDLE` (na kotwicy, nabrzeże wolne dla kupca) → `TO_BERTH` (rezerwacja miejsca, czeka na kotwicy, gdy zajęte) → `LOADING` (zlecenia „z magazynów na plac” do brakującej części planu i „z placu do ładowni”; plac trzyma te towary dla kogi przez `Harbour._kept_on_quay`; koniec, gdy plan jest na pokładzie albo nic więcej nie przyjdzie, albo na rozkaz „odpłyń teraz”, po zejściu portowców z trapu) → `OUTBOUND` (sakiewka na zamówienie zdjęta ze skarbca, ograniczona złotem i ładownią; płynie do krawędzi `SeaMerchant._edge_for`) → `AWAY` (270 s; sprzedaż ładunku po `ceil(cena bazowa × 1,25)`, zakup zamówienia do ładowni; statek zostaje w `ships`, ale widok i kliknięcia go pomijają) → `INBOUND` (do nabrzeża; złoto ze sprzedaży wpływa po zacumowaniu) → `UNLOADING` (zlecenia „z ładowni na plac”, a plac odnoszą tragarze) → `IDLE`. Komendy `SetVoyagePlanCommand` (linia planu, sprawdza miejsca w ładowni) i `StartVoyageCommand` (wypłyń / odpłyń teraz).
- **Start ze statku:** `MapDef.start_by_ship`, `landing_tile`, `beach_tile`, `start_settlers`, `start_pile`, `first_building`. `load_map` nie stawia budynków, tylko zakłada `ProvinceSim.landing` (`Landing`, zapisywane do końca lądowania): koga `settler_cog` (wygląd kogi gracza, `ShipDef.art`) wpływa z krawędzi, rzuca kotwicę, zestaw startowy ląduje na plaży jako kupy po jednym stosie na kafel (najbliższe wolne kafle lądu), osadnicy co 2 s brodzą do plaży (zadanie `KIND_LAND`, `LandStep`, 0,6 tempa pieszego, postęp w `bb`), potem koga odpływa i znika. Do czasu obozu budowniczy buduje bez miejsca pracy (`TaskRunner`), a tragarze bez miejsca pracy noszą jak każdy tragarz. `Landing._settle` (co sekundę, przed `Population`) daje gotowemu obozowi (`BuildingDef.unique`) budowniczego i 2 tragarzy z osadników (mieszkają w obozie, `home_id = 0`), a pozostałych, gdy są wolni, zamienia w nowych mieszkańców (`settler`, `MoveInStep`) pierwszych chat z wolnym miejscem. `ProvinceSim.first_building`: dopóki nie stoi obóz, `placement_error` zwraca `build_camp_first`; `unique` daje `only_one`. Menu budowy pokazuje wtedy tylko obóz (`BuildMenu.lock_to`).
- **Widok:** `ShipLayer` rysuje kogę gracza z arkusza `ships/cog/idle.png`, statki za horyzontem chowa, a kogę na pochylni z `build_0..2.png` (220×220, 8 kierunków, kadłub na klocach); przy wodowaniu kadłub zjeżdża z pochylni do miejsca cumowania (postęp etapu, ruch z przyspieszeniem). Panel portu ma `VoyagePanel` (stan rejsu, plan po 5 sztuk, przyciski).

**Realizacja (N1, część 2):**
- **Dźwig przeładunkowy:** `BuildingDef.crane_reach` (2): dźwig stoi tylko na nabrzeżu i musi mieć w tym zasięgu (Chebyshev od obrysu) miejsce cumowania portu albo miejsca cumowania (`Cranes.berth_building`, błąd `no_berth_nearby`). Dźwigowy (`crane_operator`) ma recepturę `crane_work`: idzie do pracy, a krok `crane` (`CraneStep`) bierze jedno podniesienie: pierwsze otwarte zlecenie między placem tego miejsca a zacumowanym statkiem (`Cranes.take_load`), do 3 sztuk naraz, z rezerwacją na obu końcach (`_res` w źródle, `_res_in` w celu) i `in_flight` w zleceniu, więc portowcy i dźwig nigdy nie biorą tej samej sztuki. Mniej niż 3 sztuki tylko na koniec towaru: dopóki tragarze niosą ten towar na plac, dźwig czeka (portowcy noszą wtedy pojedyncze sztuki). Cykl 4,2 s: zaczepienie 0,8 s, obrót 1,3 s, opuszczenie i odczepienie 0,8 s (wtedy towar zmienia właściciela, `Cranes.hand_over`), powrót 1,3 s; postęp w `bb["_lift"]`, więc zapis w środku wznawia podniesienie. Sam dźwig przenosi ok. 1,8× tyle co dwóch portowców, razem ok. 2,8× (`test_n1_crane.gd`). Przerwane zadanie (`TaskRunner.fail` → `Cranes.abort`) oddaje sztuki do zlecenia, a rezerwacje zwalnia jak zawsze; nic nie ginie, bo towar zmienia miejsce dopiero przy odczepieniu. Bez statku albo towaru krok kończy się powodem `no_ship` / `no_cargo` i dźwigowy sprawdza znowu po 3 s. `dangling_holds` uznaje drugą rezerwację (`_res_in` z `_dst`).
- **Magazyn portowy:** zwykły magazyn (`storage_slots` 8, 2 tragarzy) z `quay_only`, więc stoi tylko na nabrzeżu; najbliższy statkom, więc tragarze biorą z niego i odnoszą do niego najpierw.
- **Widok:** `CraneLayer` (nad światem, `z_index` 1) rysuje ramię od masztu do punktu nad placem albo statkiem (obrót z wygładzeniem), linę od koła do masztu, linę z hakiem i ładunek w siatce (ikony towaru) według `Cranes.lift_progress`; maszt i koło są w grafice budynku (`tools/generate_art.gd`, `crane`), a dźwigowy stoi w kole i „idzie” (`open_ground`, aktywność `walk`). Panel dźwigu: które miejsce obsługuje, statek i to, co właśnie podnosi.
- **Postój przy nabrzeżu (2026-11-07):** `Harbour.moor` stawia statek w `moor_point` (0,45 kafla za środkiem miejsca cumowania, od strony stopy trapu na zewnątrz, dalej na tym samym kafelku, więc logika kafli się nie zmienia); tam kończy się droga portowca po trapie. Widok rysuje kadłub kogi jeszcze 0,5 kafla dalej (`ShipLayer.hull_shift`).
- **Automatyczny gracz:** `tests/support/harbour_bot.gd` obok `SliceBot` na „Wybrzeżu” (`tests/long/test_n1_harbour_bot.gd`).

### 5.3 Pathfinding

**Decyzja:** `AStarGrid2D` (implementacja C++ w Godocie) na siatce kafli w **przestrzeni siatki, nie ekranu**, z 8 kierunkami ruchu i `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`, co zapobiega przechodzeniu „przez róg” między dwoma ukośnymi kaflami muru.

| Element | Ustalenie |
|---|---|
| Koszty kafli | `weight_scale` z `TerrainDef.move_cost`: droga ubita 0,67 (M3, zgodnie z GDD +50%); bruk 0,55 (M4b-3, +80%); trawa i łąka 1,0; pole 1,2; las 1,5 (także drzewo na trawie, M4b-2); bród 2,0. Woda, skały i budynki są `solid`; drzewa nie (M4b-2). |
| Zmiany mapy | Budowa lub rozbiórka aktualizuje komórki (`set_point_solid`, `set_point_weight_scale`). Ścieżki niosą numer wersji przejezdności (`ProvinceSim.blocking_version`: zmienia się tylko, gdy kafel staje się przejezdny albo nie, dla pieszych lub wozów; zmiana samego kosztu, np. ścięte drzewo, nie każe sprawdzać tras, M4b-3). Postać, której dalsza trasa stała się nieprzejezdna, liczy ścieżkę od nowa. |
| Budżet | Kolejka zapytań `PathRequestQueue` ma limit, wyjściowo **32 zapytania na tick**. Postać czeka na ścieżkę w stanie `idle` przez co najwyżej kilka ticków, co jest niewidoczne dla gracza. |
| Pamięć podręczna | Częste trasy (budynek → najbliższy magazyn) są cache’owane per para (budynek, magazyn) i unieważniane przy zmianie wersji siatki w obszarze trasy. **W M2 jeszcze niepotrzebne** (500 tragarzy mieści się w budżecie, §9.3). **W M4b-3 też niepotrzebne:** na dużym mieście wyszukiwanie tras to ok. 0,15 ms na tick (§9.3). |
| Rezerwa | Jeśli pomiary w M1 pokażą problem: pola przepływu (flow fields) do magazynów, hierarchiczny A* albo zapytania na `WorkerThreadPool`. |
| Kolizje postaci | **Brak kolizji między postaciami.** Kilka osób może stać na jednym kaflu. Widok dodaje małe, stałe przesunięcie wynikające z id postaci, żeby postacie nie nakładały się idealnie. To kluczowa oszczędność wydajności, typowa dla gatunku. |
| Okręty | **M5:** dwie wodne `NavGrid` w `ProvinceSim`: `boat_nav` (płytkie i głębokie morze, `TerrainDef.sail_depth` ≥ 1) i `cog_nav` (głębokie morze i tor wodny). Kafle budynków są zamknięte dla statków. Tor wodny (`ProvinceSim.fairway`, wyliczany, niezapisywany) to najkrótsza droga po płytkiej wodzie od miejsca cumowania stoczni do głębokiej (`Ships.fairway_from`, BFS po 4 sąsiadach). Statki nie zderzają się ze sobą. Ta sama struktura posłuży bitwom morskim [PÓŹNIEJ]. **N1 (nabrzeża):** kafel z nabrzeżem (`TileGrid` warstwa `quays`: 1 pomost, 2 nabrzeże kamienne) jest przejezdny dla ludzi (koszt jak droga ubita albo bruk) i nie jest wodą dla statków (`ProvinceSim.sail_depth` = 0). Kafle zamówione, a jeszcze nieułożone, są zamknięte dla statków od razu. Zamówienie sprawdza `quay_plan`: zasięg najwyżej 8 kafli od brzegu (BFS po nabrzeżach) i porównanie „przed i po” zalewania wody od krawędzi mapy, osobno dla łodzi i dla kogi (miejsca cumowania, ławice, statki nie mogą zostać odcięte). **B1 (mosty):** kafel z mostem (`TileGrid` warstwa `bridges`) nad rzeką, brodem albo jeziorem (nie morzem) jest przejezdny dla ludzi (koszt jak droga ubita albo bruk) i jest drogą dla wozów (`road_nav`). Most zaczyna się i kończy rampą na lądzie (po kaflu na każdym brzegu). Zamówienie sprawdza `ProvinceSim.bridge_plan`: linia w 8 kierunkach, oba brzegi wolne, najwyżej 8 kafli wody, całość albo nic. Budowniczy staje na brzegu albo na ułożonym kawałku mostu. **B1, część 2:** budynek z `BuildingDef.stilts_row` może mieć jeden skrajny rząd nad płytką wodą (`ProvinceSim.stilt_tiles`, reguły w `_stilts_error`); te kafle są zajęte przez budynek, więc są zamknięte dla ludzi i łodzi. |

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
- **Bramy:** specjalny kafel z kierunkiem osiowym, przejezdny dla swoich, zamknięty dla wrogów. **Chodzenie po murach** [1.0] korzysta z osobnej warstwy nawigacji „na murze” z przejściami przez schody i baszty. **W grze (M7, część 2) bramą jest wieża bramna 3×3 (budynek), a model bryłowy i kliny są w `src/view/walls/block_wall_model.gd` i `src/sim/walls/walls.gd` (§10).**

**Mur kamienny: model bryłowy** (decyzja 2026-11-04, prototyp w `src/prototype/walls/`). Opisany wyżej model „linii” zostaje dla palisady.
- Każdy kafel muru kamiennego to pełny blok 1×1. Ściany boczne i krawędzie korony (z blankami) rysujemy tylko tam, gdzie sąsiad nie jest murem. Równoległe rzędy zlewają się więc w jeden gruby mur.
- **Przekątne, wariant „prosto”:** w wolnych kaflach między dwoma blokami po przekątnej stoją trójkątne kliny o przyprostokątnej 1 kafla, więc lico muru jest proste. Klin nie powstaje w narożniku 90° ani w trójniku, czyli wtedy, gdy mur biegnie dalej prosto przez drugi kafel pośredni. Kafle z klinami są w nawigacji `solid`. Mur ukośny jest przez to ok. √2 grubszy od osiowego.
- **Sortowanie:** bloki, kliny i blanki są osobnymi kawałkami z punktem sortowania w środku ciężkości podstawy. Wyjątki:
  - pomost bramy sortuje się na przedniej krawędzi przejścia,
  - wszystko, co stoi na koronie (blanki, ludzie), sortuje się co najmniej 1 px za kawałkiem, na którym stoi.

  Sprawdzone tą samą metodą co `test_sorting.gd`: 0 błędów dla postaci na ziemi.
- **Brama** w murze kamiennym to tunel: dwa filary i pomost niosący koronę.

**Nabrzeża (N1):** płaskie, więc nie tniemy ich na paski. `QuayLayer` rysuje je pod światem sortowanym (jak plac portu): pokład na wysokości lądu (ludzie stoją na nim jak na ziemi), a boki opadają do wody tylko od strony otwartej wody i tylko te zwrócone do kamery (normalna w stronę +x, +y albo +x+y), więc rzędy obok siebie zlewają się w jedną bryłę. Pod linią wody bok idzie dalej z gradientem do koloru wody (widać, że nabrzeże chowa się pod wodą). **Ukosy (2026-11-07):** przeciąganie przyciąga się do 8 kierunków (`BuildQuayCommand.line`), a skos dostaje kliny po bokach każdego kroku; w symulacji to zwykłe kafle (przejście po skosie wymaga wolnych kafli obok), a widok ścina róg klina od wody (`QuayLayer.cut_corner`: dwa sąsiedzi od strony rogu to woda, dwaj przeciwni to nabrzeże, a wzdłuż cięcia linia biegnie dalej), więc boki skosu są proste. Nabrzeże może wejść na ląd do 2 kafli od morza (`QUAY_LAND_REACH`; `quay_error` sprawdza wolny teren jak przy drodze): kafel na lądzie liczy się w `quay_plan` jako brzeg (głębokość 0), a `_free_ground_error` nie wpuszcza na nabrzeże dróg, pól ani drzew; widok rysuje tam krawężnik zamiast ściany. Zasięg (`quay_plan`) liczy krok po skosie jako 1, a kolejność układania to BFS po 4 sąsiadach od brzegu. **Dźwig (N1, część 2):** ramię, liny i ładunek rysuje `CraneLayer` nad światem (są wysoko nad wszystkim), maszt i koło są w grafice budynku. Tym samym kodem `QuayLayer` rysuje pas nad wodą budynków portowych (`BuildingDef.water_tiles`, a stoczni tylko `BuildingVisualDef.quay_tiles`, bez pochylni), dlatego port, stocznia, przystań i nabrzeża gracza tworzą jedną budowlę (decyzja właściciela 2026-11-07). Grafiki tych budynków nie mają już własnych pomostów.

### 6.4 Postacie w widoku

- `AgentViewPool`: pula węzłów `AgentSprite` (`Sprite2D` + własny odtwarzacz klatek). Węzeł dostaje postać tylko wtedy, gdy ta jest w prostokącie kamery powiększonym o margines. Pozostałe postacie nie mają węzłów.
- Animacje odtwarza prosty licznik klatek oparty na tablicy regionów atlasu. Bez `AnimationPlayer`, żeby było tanio.
- **Lustrzane odbicia** realizuje `flip_h`, zgodnie z tabelą kierunków w ART_SPEC §4.2.
- **Miejsca pracy** (`BuildingVisualDef.spot_offsets`): robotnik przy kroku z `spot` stoi w punkcie przesuniętym od środka kafla wejścia. `"<spot>_<n>"` to miejsce n-tego robotnika budynku (od 1), używane przed wspólnym `"<spot>"` (odkrywka: `face_1..3`, `crane_1..3`, E3). Miejsca z `BuildingVisualDef.hidden_spots` są poza wzrokiem: robotnik przy takim kroku nie jest rysowany (głęboka kopalnia: `below`, górnik pod ziemią; E3, część 2). To tylko widok, symulacja go nie zna. W budynku odbitym (orientacje 1 i 3) przesunięcie w poziomie zmienia znak (poprawka E3; dotyczy też cegielni i smolarni).
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

### 6.8 Interfejs: motyw i menu główne (UI-1)

- **Jeden motyw:** `UiKit.theme()` (pergamin i drewno, grafiki z `tools/generate_ui.gd`) jest ustawiony na korzeniu interfejsu gry i menu. Okna nie nadpisują stylu paneli ani kolorów ramek; kolory tekstu biorą ze stałych `UiKit` (`INK`, `INK_SOFT`, `HEADING`, `GOOD`, `BAD`, `LIGHT`, `GOLD`). Paski z deski (pasek u góry, menu budowy) mają własny, mały motyw `UiKit.board_theme()` (deska, jasny tekst z obrysem, mniejsze przyciski); reszta typów spada na motyw główny przodka.
- **Dziewięć pól powtarzanych, nie rozciąganych** (`AXIS_STRETCH_MODE_TILE_FIT`), żeby włókna pergaminu i słoje drewna zostały piksel w piksel.
- **Menu główne** (`src/main/main.gd`) buduje się w kodzie: `MenuBackdrop` (warstwy obrazu, chmury, dym, mewy, shader wody) i pergaminowy panel z przyciskami. Obraz pokrywa okno skalą całkowitą, jeśli tylko się da (1280×720: ×2, 1920×1080: ×3).

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

**Jak to zrobiliśmy (M6, część 1):**
- `ProvinceAbstract` **nie kopiuje stanu**: trzyma tę samą `ProvinceSim` bez postaci („zamrożoną”) i liczy na jej budynkach, magazynach, polach i statkach. Dzięki temu wejście i wyjście nie przepisuje towarów, a widok po powrocie od razu ma te same stosy.
- **Cykl pracy** (`WorkCycle`) czyta przepis budynku: wejścia (kroki pobrania), wyjścia (wytworzenie, zbiór z pola, złoże, ławica), czas pracy, liczbę kursów, sadzenie, obsługę (karczma). Cykl się odbywa, gdy są wejścia, złoże w zasięgu i miejsce w magazynach; inaczej budynek czeka 5 s i próbuje znowu.
- **Kalibracja** (`ProductionLog` przy `ProvinceSim`, zapisywana): przy oglądanej prowincji każdy budynek notuje odstępy między kolejnymi wytworzeniami głównego towaru (ostatnie 10). Odstęp, w którym pracownik porzucił zadanie (brak wejścia, drzewa, miejsca), nie jest liczony, bo tryb uproszczony sam liczy braki. Pomiar obejmuje więc chodzenie, pracę i czekanie na zboże, czyli pełny czas cyklu. Bez pomiarów: praca + kursy × 2 × ścieżka do najbliższego magazynu / prędkość chodu (+ droga do drzewa, rejs łodzi, a farma: czas wzrostu pola / liczba pól).
- **Praca równoległa (E3):** budynek z `BuildingDef.parallel_work` (odkrywka: 3 kamieniarzy, głęboka kopalnia: 3 górników, każdy ma własny cykl) bez pomiaru liczy tyle cykli naraz, ilu ma miejsc pracy; inne budynki z kilkoma pracownikami (targ, duża stocznia) dalej jeden cykl.
- **Obsada** liczona jest co 10 s tymi samymi regułami co zatrudnianie (`Population.staffing`: priorytet gracza, priorytet obsady, wiek budynku). Robotnicy bez domu (obóz pionierów) i osadnicy z lądowania bez domu są pamiętani z rodzaju.
- **Domy**: te same reguły (`Population.update_abstract`), tylko spiżarnie są uzupełniane od razu z magazynów co 5 s (zamiast domowników), a przybysz od razu zamieszkuje.
- **Budowy i stocznie**: co 5 s tragarze (0,1 sztuki na tragarza na sekundę) donoszą materiały na place i pochylnie, a budowniczowie i szkutnicy odrabiają etapy. Zlecenia transportu są przy tym zmniejszane, żeby po powrocie nic nie przyszło dwa razy.
- **Towary na ziemi, na nabrzeżu i przy warsztatach** trafiają co 5 s do magazynów. Drzewa rosną, ławice odrastają, stada się rozmnażają (stado wymaga obsady).
- **Kupcy i rejsy po czasie**: kupiec wędrowny i morski handlują od razu, gdy przypada wizyta (te same progi), a koga gracza ładuje plan z magazynów, „płynie” według zegara (wyjazd i powrót + 90 s) i rozładowuje się do magazynów.
- **Koszt** (pomiar w chmurze, `src/prototype/m6/abstract_bench.gd`): duże miasto z M4b-3 (412 budynków) 0,64 ms na tick (z postaciami 3,6 ms), miasteczka z fixtur ok. 0,02 ms. Cel ≤ 0,2 ms na prowincję spełniają zwykłe prowincje; wielkie miasto w trybie uproszczonym jest ponad celem (do sprawdzenia przy pomiarze 5 prowincji w części 3).

### 7.2 Przełączanie trybów

| Przejście | Co się dzieje |
|---|---|
| Szczegółowy → uproszczony (gracz opuszcza prowincję) | Towary niesione wracają do magazynu, z którego je pobrano (albo trafiają do celu, jeśli postać była bliżej celu). Rezerwacje zostają wyczyszczone. Postęp cyklu pracy zapisujemy jako procent. Postacie przestają istnieć, a zostają liczby. |
| Uproszczony → szczegółowy (gracz wchodzi) | Pracownicy pojawiają się na swoich stanowiskach w kroku wynikającym z zapisanego procentu cyklu. Tragarze pojawiają się przy swoim magazynie lub ratuszu. Zawartość magazynów to te same liczby, więc gracz natychmiast widzi stosy. |

**Jak to zrobiliśmy (M6, część 1):**
- Wyjście (`ProvinceAbstract.freeze`): najpierw kończy się to, co trwa (decyzja właściciela 2026-11-06): lądowanie od razu (zestaw na plaży, osadnicy na brzegu, koga znika), statki w ruchu stają u celu, łodzie bez załogi wracają do przystani i oddają połów do magazynu. Potem każda postać schodzi z mapy: niesione towary trafiają do celu zadania (nigdy na statek), a gdy się nie da, do najbliższego magazynu albo na ziemię; domownik zanosi zakupy do domu, przybysz w drodze od razu zamieszkuje, tragarz pracujący przy statku oddaje towar do magazynu. Rezerwacje i roszczenia znikają razem z zadaniami.
- Wejście (`thaw`): robotnicy bez domu stają przy swoim obozie, osadnicy z lądowania na plaży (dalej czekają na obóz i domy), a reszta jest zatrudniana z domów i od razu stoi przy swoich stanowiskach (`Population.staff_at_workplaces`). **Uproszczenie:** pracownik zaczyna cykl od początku; postęp niedokończonego cyklu z trybu uproszczonego (mniej niż jeden cykl na budynek) przepada.
- Otwarcie mapy świata nie przełącza trybu (decyzja 2026-11-06): przełączenie następuje dopiero przy wejściu do innej prowincji.

**Test spójności** (`tests/scenario/`): ta sama prowincja przez 30 minut gry w trybie szczegółowym i uproszczonym ma dać produkcję chleba różną najwyżej o ±15%. Tolerancję będziemy zawężać w miarę strojenia. **M6, część 1** (`test_m6_coherence.gd`): duże miasto po 10 minutach oglądania (kalibracja), potem 30 minut w obu trybach: chleb −11%, deski +2%, piwo −8%. Drugi test (`test_m6_modes.gd`): wyjście i wejście na wszystkich fixturach zapisu (v1–v12) i na dużym mieście nie zmienia towarów królestwa (magazyny, ziemia, place, ładownie, ręce; bez tego, co należy do kupców), nie zostawia rezerwacji, a gra toczy się dalej.

**Władcy AI (M8, część 3):** miasta władców żyją w tym samym trybie uproszczonym co nieoglądane prowincje gracza (osady neutralne dalej czekają zamrożone). Każdy władca ma własny skarbiec (`RulerState` w `WorldSim.rulers`); `Simulation.bind_treasuries` co sekundę i po wczytaniu przypina każdej prowincji skarbiec jej właściciela, więc podatki, koszt budynków i wypraw idą z właściwej kasy także po zmianie właściciela. „Planista” (`RulerPlanner`, co 5 s na prowincję) stawia place budowy według listy rozwoju i braków (drewno, kamień, chleb, zablokowane ogniwo łańcucha), wstrzymuje tartak, gdy brakuje drewna, i zamawia kogę w stoczni; miejsce szuka jak `NeutralTown.place`. `RulerExpansion` wysyła wyprawy tymi samymi regułami co gracz (`PrepareExpeditionCommand.prepare`, `SendExpeditionCommand.send`), wykupuje osady (osobne wpłaty władców w `NeutralSettlement.rivals`) i zakłada szlaki (`CreateTradeRouteCommand.create`). Wyprawa władcy ląduje od razu w trybie uproszczonym z obozem pionierów i magazynem (`RulerExpansion.found`), bo w tym trybie nikt nie zniósłby zestawu z plaży na pierwsze budowy. Kto pierwszy, ten lepszy: wyprawa, która zastanie prowincję zajętą (`WorldSim.is_claimed`), wraca z ludźmi i towarem. Gracz może wejść do miasta władcy (tryb szczegółowy, jak każda prowincja), ale bez budowania: pasek budowy jest schowany, panele budynków i statków nie mają przycisków. Koszt (chmura, `tests/long/test_m8_rulers_long.gd`): 3 władców po 90 minutach (po 3 prowincje, ok. 170 budynków każdy) i oglądane lądowanie gracza: 1,1 ms na tick.

**Władcy na wojnie (M8, część 4):** `RulerWar` (raz na sekundę z `Simulation._update_world`, po planiście i ekspansji). Werbunek co 10 s na prowincję: łóżko w koszarach, złoto (2× `UnitDef.gold_cost`, zapas 150 zł) i mieszkaniec domu z co najmniej 2 osobami; żołnierz trafia do `BuildingState.garrison` (oglądane miasto: postać przy drzwiach, strona `home_faction`). „Dowódca” co 10 s na władcę: armie bez zadania wracają (`ArmyOrders.plan` i `follow`, które działają teraz dla każdego właściciela: rejs na własnych okrętach, powrót floty do własnego portu, `Fleets.dock`), zagrożona prowincja zawraca kampanię i robi wypad (`order_chase`), a po czasie ochronnym `attack` waży 4 najbliższe cele `BattleResolver.chances` (oblężenie z `Armies.fort_of`; drabiniarze i taran za darmo przy murach i bramie) i wystawia armię z części załogi najsilniejszej prowincji (nie z oglądanej). Obrońcy miasta to `RulerWar.defenders`: straż osady albo załoga koszar. Przy mieście (`RulerWar.arrive` z `Armies.arrive_on_land`): oglądana prowincja gracza dostaje szturm na żywo przez `Raids.start_army(..., conquest = true)` (prawdziwe postacie żołnierzy, nie łupią, tylko trzymają rozbite drzwi; `Armies._inside` przejmuje miasto przez `Raids.can_capture`); każda inna: `Armies.battle`. `RulerWar.take_province` to wspólne przejęcie (także dla gracza, `Armies.capture`): właściciel, skarbiec, `home_faction`, rozbrojona załoga, naprawione drzwi, koniec szlaków poprzedniego właściciela. Gracz przy mieście władcy czeka jak przy osadzie (`WAITING`); „Wejdź i walcz” wyprowadza żołnierzy koszar jako straż (`RulerWar.guards_out`, `Armies.spawn_guards` z listą), a przy zamrażaniu wracają do koszar (`guard_home`). Poziom pokojowy (`GameSettings.PEACEFUL`): `growth_level()` daje łatwy; `target_ok` pomija gracza, `ArmyMeetings._at_peace` pomija spotkania z graczem, chyba że to on ściga. Szturm władcy jest prowadzony nawet bez napadów bandytów (`raids_enabled`). Zapis v30.

**Scenariusze (M8, część 5):** `GameSettings.scenario` (`COLONIZATION`, `DIVIDED`, `ISLANDS`, `INVASION`; `fit_scenario` ustawia warunek: `VICTORY_GOLD` z `gold_target`, `VICTORY_SURVIVE` bez władców). `WorldGenerator`: start gracza zawsze na wybrzeżu; `_realms` rozdaje władcom prowincje wokół stolicy (`CAPITAL_TOWN` z koszarami, `RULER_TOWN`), resztę osadom; `_archipelago` układa wyspy po 1–3 komórki na większym pergaminie (`ISLAND_SHEET`), z dala od krawędzi. Pętle planisty, ekspansji i wojny mają wersje dla jednego właściciela (`update_owner`), z których korzysta też automatyczny gracz testów (`tests/support/auto_player.gd`, `Simulation.autopilot`: wyprawy gracza lądują od razu). Kupieckie wyspy: `RulerExpansion.sell_surplus` (co minutę, port albo skład kupiecki), `RulerWar.wanted` o połowę mniejsze; `Victory` porównuje skarbce (władca pierwszy = porażka z `winner`). Najazd: `Invasion` (raz na sekundę z `_update_world`; stan `InvasionState` w `WorldSim.invasion`) wysyła fale jako floty właściciela `Rulers.RAIDERS` (traktowanego jak władca: `RulerWar.arrive` i `assault`, `take_province`, ale pominiętego w `Rulers.alive`, planiście, ekspansji i werbunku); `RulerWar.target_ok` puszcza najeźdźców na każde miasto gracza, także bez ratusza i w czasie ochronnym (bez drzwi do szturmu bitwa idzie od razu). Zapis v31. **Twierdza** (`ProvinceSim.stronghold`, `has_stronghold`): ratusz, a bez niego obóz pionierów; jej drzwi łamią napady, szturmy i fale (`Raids`, `Armies.fort_of`, `RulerWar.target_ok`). **Fale rabunkowe** (`Army.plunder`, `GameSettings.plunder_waves`): `RulerWar.assault` puszcza je jak napad bandytów (`Raids.start_army(..., conquest = false, soldiers = true)`) albo łupi od razu (`Raids.loot`). **Przetrwanie** (`GameSettings.endless`, `VICTORY_ENDLESS`): `Invasion.men_of` i `units_of` dla fal po 8., `Victory.survived`; rekord trzyma interfejs (`SurvivalRecord`, poza zapisem gry).

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
- **Wersja 7 (M4b-2):** kupiec (`merchant`: stan, następna wizyta, progi sprzedaży `sell_above`, a w czasie wizyty wóz z własnym id), niepuste stosy przy budynkach i stada (`yard`), czas rozmnażania (`breed`), kramy targowiska (`supply` z `single`). Migracja v6 → v7 daje spiżarniom chat slot na mięso i kupca w drodze (pierwsza wizyta od razu). Fixtura: `tests/fixtures/saves/v7_town.json`.
- **Wersja 6 (M4b-1.5):** każdy budynek zapisuje orientację (`orient`), dom wybrany wygląd (`look`, gdy różny od 0), a leśniczówka zaznaczone miejsce sadzenia (`plant_area`, gdy niepuste). Migracja v5 → v6 daje 0, czyli dotychczasowe wejście. Fixtura: `tests/fixtures/saves/v6_town.json`.
- **Wersja 9 (M5, część 1):** statki (`ships`: pozycja, ścieżka, dom, cumowanie, załoga, ładownia) i statki na pochylniach (`ship_builds`), kolejki stoczni (`ship_orders` przy budynku). Tor wodny nie jest zapisywany. Migracja v8 → v9 daje puste listy. Fixtura: `tests/fixtures/saves/v9_harbour.json` (rybak na morzu, druga łódź na pochylni).
- **Wersja 10 (M5, część 2):** kupiec morski (`sea_merchant`: stan, następna wizyta, progi „kupuj do N”, a w czasie wizyty statek, port, krawędź, rozliczenie ładowni i towary trzymane na placu) i rezerwacja miejsca przy nabrzeżu (`berth` przy statku). Portowiec na trapie ma postęp i drogę w `bb` zadania. Migracja v9 → v10 daje kupca w drodze (przypłynie, gdy powstanie port). Fixtura: `tests/fixtures/saves/v10_port.json` (koga kupca przy nabrzeżu, portowiec na trapie z drewnem).
- **Wersja 11 (M5, część 3):** koga gracza zapisuje rejs (`voyage`: stan, plan, kotwicowisko, krawędź, powrót, sakiewka, zarobek, wynik ostatniego rejsu, towary trzymane na placu), a gra ze startem ze statku lądowanie (`landing`: stan, statek, kotwica, plaża, osadnicy na pokładzie i na lądzie, zestaw startowy, następny osadnik) i budynek, który trzeba postawić najpierw (`first_building`). Osadnik brodzący do brzegu ma postęp w `bb` zadania. Migracja v10 → v11 nic nie dodaje (wcześniej nie było kogi gracza ani startu ze statku). Fixtura: `tests/fixtures/saves/v11_voyage.json` (koga za horyzontem, druga koga na pochylni w etapie poszycia).
- **Wersja 12 (M6, część 1):** świat. Zamiast `province` zapis ma `world` (id świata i prowincje: definicja, mapa, właściciel), `viewed` (oglądana prowincja) i listę `provinces` z trybem (`detail` albo `abstract`) i stanem. Prowincja szczegółowa zapisuje też kalibrację (`production`: ostatnie odstępy wytworzeń na budynek, gdy niepuste), a uproszczona dodatkowo robotników bez domu (`homeless`), osadników bez domu (`wanderers`), postęp cykli (`progress`) i zapas donoszenia (`carry`). Migracja v11 → v12 robi ze starego zapisu świat z jedną prowincją (id 1, gracza, oglądaną; mapa nieznana). Fixtura: `tests/fixtures/saves/v12_world.json` (nowa gra w świecie w trakcie lądowania i Wierzbowa Dolina w trybie uproszczonym; skrypt `tools/build_world_fixture.gd`).
- **Wersja 13 (M6, część 2):** wyprawy osadników. Świat zapisuje wyprawy w drodze (`expeditions`: skąd, dokąd, morzem czy lądem, stan, osadnicy, zestaw, koga, czasy), prowincja zbiórkę wyprawy (`departure`: stan, cel, wezwani i obecni osadnicy, koga albo wóz z ładunkiem i jego woźnica), lądowanie skąd przyszło (`expedition`) i czy lądem (`by_land`, `wagon`), a koga gracza wyprawę, którą wiezie (`expedition` w `voyage`). Pola zapisują się tylko, gdy są użyte. Migracja v12 → v13 nic nie dodaje. Fixtura: `tests/fixtures/saves/v13_expedition.json` (jedna wyprawa w drodze, druga w trakcie zbiórki; skrypt `tools/build_expedition_fixture.gd`).
- **Wersja 14 (M6, część 3):** szlaki handlowe (`routes` w świecie: skąd, dokąd, pojazd, linie, stan, ładunek, czasy, kursy), żądania osad neutralnych (`settlements`), wozy szlaków w prowincji (`route_wagons`: skład, gdzie stoi, woźnica, plan albo rozładunek), pożyczone wozy składów kupieckich (`lent`), rzadki surowiec prowincji (`rare`) i koga na szlaku (`route`, `route_run`, `shipped` w `voyage`). Migracja v13 → v14 daje spiżarniom chat miejsce na wino (8); miasteczka osad neutralnych powstają w pierwszych sekundach gry. Fixtura: `tests/fixtures/saves/v14_routes.json` (wóz szlaku ładowany przed stajnią, drugi szlak w drodze powrotnej, dwie osady neutralne; skrypt `tools/build_routes_fixture.gd`).
- **Wersja 17 (poprawki z oceny, paczka 1, 2026-11-07):** prowincja może mieć `grace_until` (tick końca czasu ochronnego), a lądowanie `landed` (ilu osadników już zeszło, każdy idzie na inne miejsce plaży). Oba klucze są zapisywane tylko wtedy, gdy nie są zerem. Migracja v16 → v17 nic nie zmienia: stara gra jest już po starcie, więc nie ma ochrony. Test: `tests/scenario/test_review_fixes_1.gd` (fixtura v16 wczytuje się bez zmian).
- **Wersja 18 (M7, część 1, 2026-11-07):** budynek może mieć wybór kowala (`recipe_mode`, `next_choice`), a koszary swoich żołnierzy (`soldiers`), rekrutów w drodze (`recruits`), niezjedzoną część posiłku (`mess_hunger`) i, w trybie uproszczonym, załogę liczoną rodzajami (`garrison`). Żołnierz ma `combat` (`CombatState`: życie, cel, przerwa między ciosami), zadania mają rodzaje `enlist` (rekrut po broń) i `soldier` (żołnierz przy koszarach). Na każdej mapie część skał to żyły rudy (`ProvinceSim.choose_ore_veins`: stały skrót kafla, najwyżej 1/3 skał). Migracja v17 → v18 zamienia te same skały w żyły w zapisanych prowincjach (bez skał, nad którymi pracuje kamieniarz). Test: `tests/scenario/test_m7_military.gd`.
- **Wersja 19 (M7, część 2, 2026-11-08):** prowincja może mieć mury (`walls`: rodzaj kafla i życie, base64; kliny i kafle wież bramnych i baszt nie są zapisywane, wynikają z murów i budynków), drabiny (`military`), strzały w locie (`arrows`) i stan napadów (`raids`: stan, następny napad, licznik, wejście, bandyci, kara do zadowolenia). Budynek z życiem zapisuje `hp`, gdy różne od pełnego, warsztat oblężniczy zamówienia (`siege_orders`, `siege_work`), plac muru rodzaj 3–5 (palisada, mur, schody z kierunkiem `stairs`). Postać może mieć `level` (1 = na murze), a `combat` stronę, jednostkę, rozkaz, postawę, posterunek i drogę po obu poziomach. Zadanie `shelter` (mieszkaniec w ratuszu). Migracja v18 → v19 nic nie zmienia. Testy: `tests/scenario/test_m7_raids.gd` (zapis v14 wczytany i zmigrowany).
- **Wersja 20 (M7, część 3, 2026-11-08):** świat zapisuje armie (`armies`: właściciel, stan, gdzie, droga, rodzaje i liczby żołnierzy, chleb, okręty i ich port, wejście, łup bandytów), obóz bandytów (`camp`: prowincja, straż, następny napad, łup, odrodzenie) i raporty ostatnich bitew (`reports`, 8 najnowszych); osada neutralna straż (`guards`) i to, czy ma już mury (`fortified`); walczący swoją armię (`army`) i cel rozkazu „rozbij” (`aim`); napad armię, z której przyszedł, i jej łup (`raids.army`, `loot_gold`). Mury osad nie są zapisywane osobno (to zwykłe mury prowincji). Migracja v19 → v20 nic nie zmienia: obóz powstaje, a osady dostają mury i straż w pierwszych sekundach gry. Test: `tests/scenario/test_m7_armies.gd`, `test_m7_raids.gd` (zapis v14 dostaje obóz).
- **Wersja 21 (B1, część 1, 2026-11-08):** siatka prowincji ma warstwę mostów (`grid.bridges`, base64: 0 brak, 1 drewniany, 2 kamienny), plac mostu to plac bruku rodzaju 6 albo 7. Migracja v20 → v21 dopisuje pustą warstwę. Test: `tests/scenario/test_b1_bridges.gd` (zapis v16 zmigrowany).
- **Wersja 22 (J1, część 2, 2026-11-08):** balista (nowa machina oblężnicza, zapisana jak taran: postać z `combat`) i jej bełty w locie (strzała z `"b": 1`, a strzała w mur z `"w"`: kafel muru). Migracja v21 → v22 nic nie zmienia. Test: `tests/scenario/test_j1_ballista.gd`.
- **Wersja 27 (M8, część 1, 2026-11-09):** świat zapisuje ustawienia partii (`settings`: scenariusz, numer świata, liczba prowincji, władcy, trudność, zwycięstwo, cel) i wynik (`result`). Świat wygenerowany nie ma plików: przy wczytaniu `Simulation.from_dict` robi go od nowa z numeru (`WorldGenerator`, ten sam numer i ustawienia dają ten sam świat) i rejestruje w danych (`DataRegistry.register_generated`, nazwy przez `GeneratedNames` w `TranslationServer`). Pola opcjonalne; migracja nic nie zmienia. Test: `tests/scenario/test_m8_world.gd`.
- **Wersja 34 (Z1, część 3, 2026-11-10):** ule. Ul to kafel pola pasieki (`BuildingDef.max_hives`); zapis jak dla zagród. Migracja v33 → v34: stara pasieka dostaje `pens_due` = 4 (`SaveMigrations.AUTO_HIVES`, stawiane w pierwszej sekundzie), zadania pszczelarza przechodzą na nowe numery kroków (0, 1, 2, 3, 4 → 0, 2, 4, 5, 6). Test: `tests/scenario/test_z1_pens.gd`, fixtura `v34_hives.json`.
- **Wersja 33 (Z1, część 2, 2026-11-10):** owce i konie w zagrodach. Budynek zapisuje kratki, które gra jeszcze postawi (`pens_due`, `ProvinceSim._place_due_pens` w pierwszej sekundzie); kupiec zapisuje zwierzęta na sprzedaż (`animals`: towar → ile, zamiast `pigs`). Migracja v32 → v33: stara stadnina 3×3 dostaje zagrodę z 5 zwolnionych kafli (jak chlew w v32; `limit` stada 5, `STUD_PEN_ANIMALS`), stara owczarnia `pens_due` = 3 (`SaveMigrations.AUTO_SHEEP_PENS`), kupiec `pigs` → `animals` (owce 4, konie 2); zadania pasterza i stajennego za pierwszym krokiem idą o krok dalej (`_shift_steps`: nowy krok „do zagrody”; v31 → v32 tak samo dla świniarza). Test: `tests/scenario/test_z1_pens.gd`, fixtura `v33_flocks.json`.
- **Wersja 32 (Z1, część 1, 2026-11-10):** zagrody. Budynek zapisuje rezerwę stada (`herd_keep`, gdy inna niż domyślne 2) i to, czy dostał parę na start (`herd_given`); kratki zagrody są w `fields`. Chlew ma 2×2 zamiast 3×3. Migracja v31 → v32: każdy stary chlew zostaje w swoim miejscu, a 5 kafli, które zwolnił, to jego zagroda (`SaveMigrations.OLD_PIGSTY_PEN`, miejsce dla 10 świń; większe stado zostaje i nie rośnie, dopóki gracz nie doda kratek), `herd_given` = prawda, `limit` stada 10. Test: `tests/scenario/test_z1_pens.gd`.
- **Wersja 28 (M8, część 2, 2026-11-09):** armia ma miejsce na mapie świata i drogę z punktów (`pos`, `path`) zamiast trasy po prowincjach (`next`, `route`, `depart`, `arrive`), cel (`target`: miasto prowincji albo 0), pościg (`chase`), wysadzenie z floty (`ashore`, `ashore_goal`), wejście do portu (`docking`), bitwę (`battle`) i czas spokoju po porażce (`safe_until`); świat zapisuje bitwy w polu (`battles`), a w trakcie bitwy na żywo zapis ma mapę pola (`battlefield`, `viewed` = -1); okręt może „wypływać” na mapę świata (`sail_out`). Migracja v27 → v28: trasa zamienia się na cel (ostatnia prowincja), a miejsce na mapie armia dostaje w pierwszej sekundzie gry (`Armies._place_old`) i szuka drogi na nowo. Test: `tests/scenario/test_m8_armies.gd`.
- **Wersja 26 (P2, część 3, 2026-11-09):** 5 poziomów podatku zamiast 3 (`Treasury.TaxRate`: brak, niskie, normalne, wysokie, bardzo wysokie); migracja przesuwa zapisany poziom o 1. Test: `tests/scenario/test_p2_town.gd`.
- **Wersja 25 (P2, część 2, 2026-11-09):** statek zapisuje żołnierzy na pokładzie i w drodze na pokład (`troops`: aboard, boarding, landed, order, called; `TroopTransport`). Pole opcjonalne: starszy statek go nie ma; migracja nic nie zmienia. Żołnierz na pokładzie zostaje agentem (życie, jednostka, koszary) z `vehicle = Ships.ABOARD`, porusza się ze statkiem i jest pomijany przez `Troops` (nie walczy, nie jest celem) i przez zaznaczanie. Test: `tests/scenario/test_p2_troops.gd`.
- **Wersja 24 (P2, część 1, 2026-11-09):** nowe budynki (słupek, skład i mały magazyn portowy, chata i dom portowców). Magazyny portowe nie mają już tragarzy: `Population` zwalnia pracowników ponad liczbę miejsc pracy budynku, więc tragarze ze starego zapisu wracają do domu w pierwszej sekundzie. Migracja nic nie zmienia; wersja chroni grę z nowymi budynkami przed starszą wersją programu. Test: `tests/scenario/test_p2_port.gd`.
- **Wersja 23 (J1, część 3, 2026-11-08):** armia na morzu zapisuje flotę po rodzajach okrętów (`fleet`: id okrętu → liczba). Armia zapisana wcześniej miała same okręty wojenne: `Army.from_dict` czyta `ships` jako tyle okrętów `warship`. Migracja nic nie zmienia. Test: `tests/scenario/test_j1_ships.gd`.
- **Wersja 16 (N1, część 2):** dźwig przeładunkowy i magazyn portowy to nowe budynki, a podniesienie dźwigowego żyje w tablicy zadania, więc format się nie zmienia; wersja chroni grę z dźwigami przed starszym wydaniem, które ich nie zna. Migracja v15 → v16 nic nie zmienia. Fixtura: `tests/fixtures/saves/v16_crane.json` (dźwig przy miejscu cumowania w połowie podniesienia drewna na kogę, magazyn portowy z towarem; skrypt `tools/build_crane_fixture.gd`).
- **Wersja 15 (N1, część 1):** nabrzeża w siatce (`quays` w `grid`, base64 jak teren) i rodzaj placu (`kind` w zapisie `paving`: 1 pomost, 2 nabrzeże; brak = bruk). Migracja v14 → v15 daje każdej prowincji pustą warstwę nabrzeży. Fixtura: `tests/fixtures/saves/v15_quays.json` (port i stocznia połączone nabrzeżem kamiennym, pomost z miejscem cumowania, drugi pomost w budowie; skrypt `tools/build_quay_fixture.gd`).
- **Cechy prowincji (E3, 2026-11-11) nie są zapisywane.** To dane (`ProvinceDef.traits`, a „bogata w żelazo” wynika z rudy★: `ProvinceDef.traits_of`), nie stan. `load_map` ustawia `ProvinceSim.traits`, a `Simulation.from_dict` po wczytaniu nadaje je od nowa z definicji prowincji świata (także wygenerowanego). Stare zapisy dostają więc cechy bez migracji, a zmiana cech w danych obejmuje też stare gry. Gra na jednej mapie (bez świata) nie ma cech.
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

### 9.3 Wyniki pomiarów (M1, M2, M4b-3)

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

**Pomiar M4b-3 (chmura, headless, bez GPU, 2026-11-06 — tylko czas ticku):** `src/prototype/m4b3/tick_bench.gd -- --minutes=120` na dużym mieście z fixtury `tests/fixtures/saves/big_city.json` (mapa „Pojezierze”, budowane skryptem `tools/build_big_city.gd`). Miasto: 412 budynków, 109 domów (727 mieszkańców na starcie, ok. 1150 po godzinie), 23 magazyny z wózkami, 3 stajnie z wozami, 150 kafli bruku, wszystkie łańcuchy. Postacie to pracownicy, tragarze, woźnice i domownicy w drodze po zapasy, więc ich liczba faluje (324–580). Pomiar w oknach 10-minutowych; 4 rdzenie, CPU chmury (wolniejszy od laptopa, por. pomiar M2: 2,1 ms w chmurze przy 500 tragarzach).

| Okno gry | Postacie (śr.) | Tick (śr.) | 99. percentyl |
|---|---|---|---|
| 0–10 min | 358 | 3,2 ms | 9,0 ms |
| 30–40 min | 414 | 3,6 ms | 10,4 ms |
| 60–70 min | 459 | 3,6 ms | 8,4 ms |
| 70–80 min | 480 | 3,8 ms | 10,3 ms |
| 100–120 min | 465–471 | 3,5 ms | 7,8–8,2 ms |
| **całe 2 h** | **436** | **3,6 ms** | **9,4 ms** |

Pierwszy tick po wczytaniu trwa ok. 0,25 s: wtedy wszystkie budynki usługowe liczą zasięg od zera (koszt jednorazowy, przy wczytywaniu gry). Potem najdłuższy tick to ok. 30 ms (rzadko).

**Przed poprawkami** to samo miasto miało tick średnio **50 ms** i piki do **0,9 s** (raz na sekundę). Wprowadzone środki, od najtańszych (każdy daje ten sam wynik gry, poza trzema drobnymi zmianami zasad opisanymi niżej):
1. **Zasięg usług przyrostowo** (§5.2): zamiast liczyć wszystkie studnie, kościoły, targi i tawerny od nowa przy każdej zmianie mapy, liczy się tylko źródło, w którego zasięgu coś się zmieniło. Dijkstra czyta płaskie tablice (3,4× szybciej). **Zmiana zasady:** drzewa nie skracają zasięgu usług (inaczej każda ścinka przy mieście przeliczała kilka zasięgów).
2. **Indeks magazynów:** wyszukiwanie najbliższego źródła i miejsca dla towaru przegląda tylko magazyny, targi i podwórza budynków, które ten towar mogą mieć (`ProvinceSim.storage_buildings`, `yard_buildings`, `market_buildings`), zamiast wszystkich 400 budynków. Listy `buildings.all()` i `agents.all()` są pamiętane do najbliższej zmiany.
3. **Ludność:** zapasy miasta liczone raz na tick, a nie dla każdego domu i towaru; tani test „czy w ogóle jest skąd wziąć”, zanim domownik zacznie szukać; pracownicy domów zebrani w jednym przejściu. **Domy rozłożone na 10 ticków sekundy** (każdy dom dalej raz na sekundę, ale w ticku swojego id), co usunęło piki co sekundę.
4. **Trasy:** postać sprawdza resztę trasy tylko wtedy, gdy jakiś kafel stał się nieprzejezdny (`blocking_version`), a nie przy każdej zmianie kosztu ruchu; postacie w drodze pomijają logikę zadania bez wywołania.
5. **Puste szukanie:** zlecenie, którego nikt nie może wykonać (brak towaru albo miejsca), wraca do dopasowania po 2 s, a nie co 0,5 s. **Zmiana zasady:** pracownik, który nie ma nad czym pracować (brak drzewa, skały, wolnego miejsca do sadzenia), czeka 10 s zamiast 3 s przed kolejnym szukaniem (leśniczy przy pełnym lesie szukał co 3 s po 324 kaflach). Szukanie drzew i skał czyta płaskie tablice; kupy na ziemi mają indeks kafli.

**Wniosek:** cel z §9.1 (≤ 4 ms przy 500 postaciach) jest spełniony w chmurze z małym zapasem: 3,5–3,8 ms przy 460–480 postaciach, szacunek dla 500 ok. 3,9 ms. Laptop jest szybszy niż chmura. Rezerwy z §9.2 (pamięć tras, pola przepływu, GDExtension) nie są potrzebne. Największe pozostałe koszty: ludność ok. 1 ms na tick (domy), ruch ok. 0,8 ms, kroki zadań. Pomiar FPS na laptopie (scena 60 s przy 4×, trzy zbliżenia) w osobnej sesji z właścicielem projektu.

**M4b-3, FPS na laptopie (2026-11-07)** (`src/prototype/m4b3/fps_bench.tscn`, okno 1600×900, vsync wyłączony, RTX 5070 Ti Laptop, D3D12; duże miasto, kamera nad centrum, pierwsze 2 s po każdym przeskoku kamery nie liczone):

| Prędkość | Zoom | Postacie | Śr. FPS | 1% najgorszych | Najgorsza klatka | Klatki > 33 ms |
|---|---|---|---|---|---|---|
| 4× | 0,5× | 363 | 130 | 17 FPS | 91 ms | 17 w 18 s |
| 4× | 1× | 334 | 198 | 28 FPS | 83 ms | 13 w 18 s |
| 4× | 2× | 375 | 215 | 29 FPS | 83 ms | 14 w 18 s |
| 1× | 0,5× | 386 | 148 | 34 FPS | 97 ms | 3 w 10 s |
| 1× | 1× | 349 | 233 | 71 FPS | 83 ms | 2 w 10 s |
| 1× | 2× | 367 | 257 | 114 FPS | 83 ms | 1 w 10 s |

**Wniosek:** średnio cel 60 FPS jest spełniony z 2–4× zapasem. **Problem: zacięcia** (klatki ok. 80–95 ms) mniej więcej raz na 4–5 s czasu gry, przy 4× ok. raz na sekundę, niezależnie od zbliżenia. Liczba rośnie z prędkością gry, więc źródłem jest symulacja (rzadki, drogi tick, ok. 80 ms; w chmurze najdłuższy tick ok. 30 ms), a nie rysowanie. Do znalezienia i poprawki (ROADMAP M4b-3, poprawki z oceny).


**Poprawka zacięć (2026-11-07, paczka 1 poprawek z ocen).** Pomiar z profilem (`tick_bench.gd -- --minutes=10 --profile`, laptop) pokazał źródło: **zasięg usług**. Gdy kamieniarz wybierze skałę w środku miasta, kafel staje się przejezdny i 3–8 studni, kaplic i kościołów naraz liczyło zasięg od zera (każde ok. 10–20 ms, tick 80–140 ms; 41 takich ticków w 10 minut). Teraz każde źródło pamięta długość drogi do każdego kafla (`ServiceCoverage._Source.best`) i zmianę, która tylko **otwiera albo skraca** drogi (wybrana skała, nowa droga, bruk) albo **zamyka kafel, przez który nie prowadziła żadna policzona droga**, dolicza na miejscu (Dijkstra tylko od zmienionych kafli). Od zera liczy się tylko wtedy, gdy jakaś droga mogła się wydłużyć (np. nowy budynek na ścieżce). Wynik jest dokładnie taki sam jak liczony od zera (test losowych zmian w `test_service_coverage.gd`), więc wczytana gra dalej zgadza się z grającą. Po poprawce (laptop, 20 minut po minucie rozgrzewki): tick średnio 1,97 ms, 99. percentyl 4,9 ms, **najdłuższy 11,4 ms** (wcześniej do 140 ms); zasięg średnio 0,06 ms na tick (było 0,17). **Podgląd zasięgu przy stawianiu** (kaplica, studnia): zasięg stojących budynków to osobna warstwa (`ProvinceView.range_overlay`) przeliczana tylko po zmianie zasięgu (`ServiceCoverage.version`), a przy ruchu myszy liczy się tylko zasięg nowego budynku, bez przeglądania całej mapy.

**Druga przyczyna zacięć: widok.** Po poprawce symulacji `fps_bench` dalej pokazywał klatki 80–145 ms. Pomiar części klatki wskazał dwa koszty widoku: (1) `BuildingLayer.refresh_all()` po każdej zmianie budynku (etap budowy, awans domu, droga obok domu) liczył klucz grafiki dla 412 budynków po ok. 0,2 ms, bo `BuildingVisualDef.for_building()` przy każdym wywołaniu sprawdzał plik na dysku (`ResourceLoader.exists`): razem 70–100 ms. Teraz opisy wyglądu są w pamięci podręcznej (raz na typ budynku), a `refresh_all()` trwa ok. 2 ms. (2) Grafiki postaci wczytywały się dopiero przy pierwszym pokazaniu danego typu postaci (ok. 90 ms każda); teraz `AgentViewPool.warm_up()` wczytuje przy otwarciu prowincji postacie, które w niej są albo pracują w jej budynkach.

**Poprawki z ocen, paczka 1, FPS na laptopie (2026-11-07)** (ta sama scena i sprzęt co wyżej):

| Prędkość | Zoom | Postacie | Śr. FPS | 1% najgorszych | Najgorsza klatka | Klatki > 33 ms |
|---|---|---|---|---|---|---|
| 4× | 0,5× | 376 | 144 | 94 FPS | 12,8 ms | 0 w 18 s |
| 4× | 1× | 348 | 228 | 163 FPS | 8,8 ms | 0 w 18 s |
| 4× | 2× | 386 | 248 | 174 FPS | 9,0 ms | 0 w 18 s |
| 1× | 0,5× | 401 | 158 | 119 FPS | 9,4 ms | 0 w 8 s |
| 1× | 1× | 368 | 249 | 234 FPS | 5,5 ms | 0 w 8 s |
| 1× | 2× | 353 | 285 | 223 FPS | 5,7 ms | 0 w 8 s |

**Wniosek:** zacięć nie ma; 1% najgorszych klatek to 94–234 FPS (wcześniej 17–114).

**M6, część 3, pięć prowincji gracza** (`src/prototype/m6/five_bench.gd`, chmura, 5 minut gry po minucie rozgrzewki): duże miasto oglądane (ok. 340 postaci) i 4 miasteczka po ok. 35 budynków w trybie uproszczonym (oraz 2 czekające osady neutralne): **2,83 ms na tick średnio**, samo duże miasto 2,59 ms. Cel ROADMAP M6 (≤ 4 ms) spełniony; najwolniejsza sekunda 7,8 ms na tick w obu przypadkach (to samo duże miasto, nie prowincje uproszczone). Pomiar na laptopie: osobna sesja z właścicielem.
---

## 10. Walka i jednostki (przygotowanie)

- Żołnierz to `Agent` z `CombatState` (HP, cel, cooldown ataku). Te same systemy ruchu, sortowania i animacji co cywile.
- **M7, część 1 (2026-11-07):** `UnitDef` (`data/units/`) ma ekwipunek (`gear`), cenę i `combat: CombatStatsDef`. Rekrutację, posiłki i szeregi (bez żołdu od 2026-11-08) prowadzi `Barracks` (`src/sim/military/`): rekrut to wolny mieszkaniec z puli pracy (dom traci mieszkańca), krok `EnlistStep` odbiera zarezerwowany ekwipunek (zbrojownia, stado koni, podwórko warsztatu) i nigdy nie zawodzi (czeka i próbuje dalej), `SoldierStep` stawia żołnierza na placu przed koszarami (`Barracks.parade_posts`, 2 na kafel, 16 miejsc) albo w środku. Broń trafia tylko do zbrojowni: magazyn ma kategorie towarów (`BuildingDef.storage_accepts`, `Stockpile.only/never`). W trybie uproszczonym żołnierze są liczeni w `garrison` koszar i wracają jako ludzie przy `thaw`.
- Okręt to `ShipUnit` z `CombatState` i ładownią (`Inventory`), poruszający się po `NavGrid` wodnym. **M5 część 1:** `ShipUnit` istnieje bez `CombatState` (ładownia to `Stockpile`, ruch po `boat_nav` albo `cog_nav`, §5.2). **Część 2:** statek rezerwuje miejsce przy nabrzeżu portu (`berth_id`), a ładownię w porcie ładują portowcy (§5.2). Na mapie świata to część floty. **Struktura od razu pozwala na interaktywne bitwy morskie [PÓŹNIEJ]** bez przebudowy: brakuje wtedy tylko AI walki okrętów, animacji i UI.
- **M7, część 2 (2026-11-08):**
  - **Mury** (`Walls`, `src/sim/walls/walls.gd`): warstwa kafli (palisada, mur kamienny, schody z kierunkiem) z życiem; kliny murów kamiennych liczone tą samą regułą co widok (`Walls.wedges_of`, test zgodności z `BlockWallModel`). Mur i klin są `solid` na ziemi. Wieża bramna i baszta to budynki z `BuildingDef.fort_kind`; ich kafle są w `Walls.fort_tiles` (mur się do nich dokleja), a przejście wieży bramnej (`BuildingDef.passage_at`) jest dla mieszkańców przechodnie (także dla wozów). Mury buduje się jak bruk: `PavingSite` rodzaju 3–5, budowniczy stoi obok kafla, ludzie na nowym murze odsuwają się (`_step_aside`). `wall_plan` sprawdza kliny i to, czy mur nie odetnie drzwi, stosów ani ludzi.
  - **Nawigacja walczących** (`MilitaryNav`): siatki `wall_nav` (korona), `enemy_nav` (ziemia dla wroga, zamknięte bramy są `solid`) i `siege_nav` (mury i bramy przechodnie z kosztem rozbicia, do szukania przeszkody), przejścia między poziomami (`Portal`: schody i drabiny dla wszystkich, drzwi baszty i przejście bramy tylko dla swoich) i `route` (Dijkstra po końcach przejść w obrębie obszarów z `NavGrid.area_of`, potem A* na odcinkach). Droga to kafle i poziomy (`CombatState.path`, `levels`).
  - **Oddziały** (`Troops`): walczący pod rozkazami (`CombatState.commanded`) są poza `TaskRunner` i `Movement`; co tick: wybór celu według postawy (komórki 4×4 kafle), cios albo strzała (`Troops.Arrow`, obrażenia po czasie lotu), pościg z nową drogą co sekundę, ruch po obu poziomach (przejścia „w środku” od razu), szyk przy rozkazie ruchu, rozbijanie mur/bram/drzwi (`damage_structure`, `break_building`). Żołnierz w szeregu (`SoldierStep`) zostaje przy koszarach, dopóki nie dostanie rozkazu.
  - **Machiny** (`SiegeWorks`, `UnitDef.siege`): warsztat oblężniczy zamawia materiały do własnego schowka (jak spiżarnia koszar), po komplecie i z wolnymi mieszkańcami składa taran albo drabinę; obsługa wychodzi z domów jak rekruci.
  - **Napady** (`Raids`): harmonogram, ostrzeżenie, wejście od krawędzi (`siege_nav` łączy ją z ratuszem), cele bandytów (drzwi ratusza albo pierwsza przeszkoda na drodze rozbicia), chowanie się mieszkańców (`ShelterStep`), łup i odejście, naprawa drzwi i bram po napadzie; `Raids.capture` na część 3. Napady liczą się tylko, gdy `Simulation.raids_enabled` (gra gracza; testy i pomiary bez napadów).
  - **Widok:** `FortLayer` (mury z `BlockWallModel`, palisady `PalisadeNode`, schody `StairsNode`, wysokość stania na murze `height_at`), `TroopsLayer` (paski życia, znacznik, strzały, ramka), `CorpseLayer`, `SiegeLayer` (tarany, drabiny). Postać na murze sortuje się z koroną (`crown_sort_key`), a rysuje wyżej (`AgentSprite.set_lift`).
- Automatyczne rozstrzyganie (`BattleResolver`) to czysta funkcja `(armia A, armia B, teren, fortyfikacje, rng) → wynik`, pokryta testami.
- **M7, część 3 (2026-11-08):**
  - **`BattleResolver`** (`src/sim/military/battle_resolver.gd`, `BattleSide`, `BattleFort`, `BattleResult`): pule żołnierzy według rodzaju, rundy po 5 s z wartościami `CombatStatsDef` (cios, przerwa, premie) × 0,5; fazy ostrzał, pod murami (rundy na rozbicie: taran przy bramie, drabiny, rąbanie), wręcz; okręty jako balisty z życiem; szum ±10% z `SimRng` (strumień `battles`); `chances` liczy 20 rozstrzygnięć ze stałymi ziarnami.
  - **Armie** (`Army`, `Armies` w `src/sim/world/`): stany INSIDE (żołnierze na mapie oglądanej prowincji), IDLE, MOVING, WAITING. Żołnierz z rozkazem MARCH schodzi z mapy (`Troops.march_off` → `ProvinceSim.marched` → `Armies.absorb` w tym samym ticku). `WorldSim.land_route` (Dijkstra po sąsiadach) i `army_seconds`. Przy wyjściu z prowincji (`Armies.fold` przed `freeze`) żołnierze armii, strażnicy i bandyci wracają do liczb; trwający napad rozstrzyga się automatycznie. `ProvinceSim.home_faction` (gracz albo `CombatState.TOWN`, wyliczane z właściciela, niezapisywane) mówi, czyje są mury i bramy: `MilitaryNav.ground_nav`, przejścia wież i obrona drzwi liczą się względem niej.
  - **Osady:** `NeutralTown.fortify` (pierścień 4-spójny wokół centrum, brama na prostym odcinku najbliżej ratusza z wolnym polem przed sobą, baszty najdalej od bramy); straż powstaje przy wejściu do osady (`Armies.spawn_guards`, postawa „broń się”).
  - **Bandyci:** `BanditCamp` w świecie; napady jako armie (`Raids.start_army` w oglądanej prowincji, `Armies._raid` z `BattleResolver` w nieoglądanej); harmonogram napadów prowincji (`Raids.update`, `scheduled`) działa już tylko w grze na jednej mapie.
  - **Walka:** `Troops.nearest_enemy` pomija wrogów, do których nie da się dojść (inny obszar siatki, inny poziom bez schodów i drabin dla tej strony), `blocked_id` na 5 s; rozkaz BREAK (`order_break`) z celem końcowym `aim`, miejsca przy budowli rozłożone (`stand_by`, 4 najbliższe według id).
  - **Brama w palisadzie:** `fort_kind = palisade_gate` (`BuildingDef.is_gate`, przejście jak w wieży bramnej; `has_crown` fałsz: bez masy muru i korony, zastępuje palisadę pod sobą).
  - **Okręt wojenny:** `ShipDef.troops` (30); po wodowaniu kotwiczy (`Ships._anchor_warship`); `Armies.goes_by_sea`, `ArmyOrders._board`, `Fleets.dock`.
  - **M8, część 2 (ruch po mapie świata):** `WorldNav` (kratki 20 px: prowincja albo morze, z obrysów prowincji, robione raz na świat i niezapisywane; A* w 8 kierunkach bez ścinania rogów, potem prostowanie po linii widoczności). `Army.pos` i `path` (punkty pergaminu, wartości `SimCodec.savable`, żeby zapis i wczytanie dawały to samo); `ArmyOrders` (plan drogi: ląd, morze na okrętach prowincji, wysadzenie, port; pościg), `Fleets` (flota to `Army` z okrętami na morzu, `by_sea`), `ArmyMeetings` (co sekundę pary wrogów bliżej niż 24 px; gracz → `FieldBattles.begin`, inni → `BattleResolver` od razu), `FieldBattles` i `FieldBattle` (PENDING czeka na wybór gracza, LIVE: `Simulation.enter_battlefield` zamraża oglądaną prowincję jak przy zmianie widoku, a mapa pola to `ProvinceSim` z szablonu mapy bez budynków pod id `Simulation.BATTLEFIELD` (-1), zapisywana osobno w `battlefield`; `leave_battlefield` wraca do poprzedniej). Okręt, który wypływa (`ShipUnit.sail_out`), schodzi z mapy przez `ProvinceSim.marched` jak żołnierz (`Armies.absorb` liczy okręty i wojsko z pokładu).

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

**Dwa poziomy testów (decyzja właściciela 2026-11-07):**
- **Szybkie** (`tests/unit`, `tests/data`, `tests/scenario`; ok. 610 testów): `tools/run_tests.sh`, w 4 Godotach naraz (przyspieszenie 2026-11-11, ankieta właściciela: jeden Godot liczył je 6,5 minuty, 4 naraz ok. 1 min 50 s w chmurze; najpierw rozdawane są po kolei wolne zestawy świata M6–M8, potem reszta). `tools/run_tests.sh --serial` liczy je w jednym Godocie. Muszą przechodzić przed **każdym commitem**.
- **Długie** (`tests/long`: automatyczni gracze na trzech mapach i w świecie, 3 pełne partie scenariuszy M8 (`test_m8_game_*_long.gd`), port automatycznego gracza na „Wybrzeżu” (N1), duże miasto przez 2 godziny gry, spójność trybów na dużym mieście; 10 testów): `tools/run_tests.sh --long`, każdy plik w osobnym Godocie naraz (ok. 5 minut zamiast 11 po kolei). Muszą przechodzić przed **scaleniem do `main`** i na koniec części etapu. Wyłapują rzadkie rzeczy (zakleszczenia po godzinie gry, balans, wydajność), które rzadko psuje pojedyncza zmiana.
- `tools/run_tests.sh --all` puszcza oba poziomy naraz. Logi i raporty przebiegów równoległych: `reports/<nazwa>.log`.
- Nowy test trafia do `tests/long`, gdy trwa dłużej niż ok. 8 sekund (2026-11-11: 7 najwolniejszych testów świata, 9–16 s każdy, przeniesiono do `tests/long/*_slow.gd`).
- **Pomiary szybkości w testach** (`SimFixture.speed_limit`): przy równoległym biegu (`YK_SHARED_CPU=1` z `run_tests.sh`) limit jest 2 razy większy, bo Godoty dzielą procesor i test władców przekraczał 4 ms, choć sam liczył 1,9 ms. Dokładny pomiar: zestaw osobno (`tools/run_tests.sh -a res://tests/long/<suite>.gd`).

**Zasada:** każda zmiana w `src/sim` ma test.

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
