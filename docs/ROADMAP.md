# Your Kingdom — roadmapa

> Status: **wersja 0.1 (do zatwierdzenia)** · data: 2026-11-04
> Powiązane: [GDD.md](GDD.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [ART_SPEC.md](ART_SPEC.md)

**Zasady:**
- Etapy realizujemy po kolei. Etap jest ukończony, gdy spełnia **wszystkie** kryteria ukończenia (DoD).
- Po każdym etapie robimy krótkie podsumowanie i czekamy na akceptację.
- Nowe pomysły trafiają do [IDEAS.md](IDEAS.md), a nie do bieżącego etapu.
- Szacunki czasu pomijamy celowo. Kolejność i kryteria są ważniejsze.

---

## Mapa zależności

```
M0 Fundament
 └─► M1 Prototyp czytelności + benchmark ──► A1 Pilot PixelLab (równolegle, mały)
      └─► M2 Rdzeń symulacji
           └─► M3 VERTICAL SLICE  ◄── kamień milowy: sprawdzenie głównego założenia gry
                ├─► M4 Miasto i ekonomia (M4a mieszczanie ─► M4b patrycjusze)
                │    └─► M5 Woda, porty i statki
                │         └─► M6 Mapa świata i prowincje
                │              └─► N1 Nabrzeża i port (UI-1 obok)
                │                   └─► G1 Grafika budynków z PixelLab, część 1 (pionierzy)
                │                        └─► M7 Wojsko, mury i oblężenia
                │                             └─► B1 Most przez rzekę i łagodniejszy brzeg
                │                                  └─► W1 Nowe wybrzeże ──► J1 Nowe jednostki i okręty
                │                                       └─► M8 Przeciwnicy i sandbox ──► M10 Wersja 1.0
                └─► M9 Produkcja grafik (równolegle od M4, partiami)
Po 1.0: P1 interaktywne bitwy morskie, P2 kampania, P3 pory roku, ...
```

---

## M0 — Fundament

**Cel:** pusty, ale poprawnie skonfigurowany projekt, w którym każdy kolejny krok ma testy i lokalizację.

**Zakres:**
- repozytorium git, struktura folderów (ARCHITECTURE §2),
- ustawienia projektu: filtr `Nearest`, snap do pikseli, typowanie jako błąd w `src/sim` i `src/core`,
- instalacja gdUnit4 i polecenie uruchamiające testy z linii poleceń (zapisane w `CLAUDE.md`),
- szkielet autoloadów (`Data`, `Game`, `EventBus`, `Loc`, `SaveService`),
- klasy `GoodDef` i `BuildingDef`, rejestr `Data` wczytujący `data/`,
- lokalizacja: `pl.po`, `en.po`, PL jako domyślny, pomocnik `Loc.count`, font z polskimi znakami,
- testy:
  - integralność danych,
  - kompletność kluczy lokalizacji,
  - polskie formy liczby mnogiej (1 chleb, 2 chleby, 5 chlebów, 12 chlebów, 22 chleby),
  - zakaz zależności `src/sim` → widok,
  - zakaz tekstów na sztywno,
- generator placeholderów (`tools/`), na razie kafel i postać-kapsuła.

**DoD:**
- [x] `git status` czysty, `.gitignore` obejmuje `.godot/`.
- [x] Testy uruchamiane jednym poleceniem przechodzą (min. 5 testów z listy). Stan: 18/18 (`tools/run_tests.sh`).
- [x] Scena startowa wyświetla przetłumaczony napis i działa przełącznik języka PL ↔ EN. Przełącznik czeka na ręczne kliknięcie przez właściciela projektu.
- [x] Wszystkie polskie znaki renderują się w wybranym foncie (test glifów).

**Uwaga z M0:** Pixelify Sans ma polskie znaki, ale przy obecnych rozmiarach słabo odróżnia „Z” od „2” i „5” od „S”. Rozwiązane w M1: porównano 6 fontów i wybrano Jersey 10.

---

## M1 — Prototyp czytelności, sortowania i wydajności

**Cel:** zanim powstanie jakakolwiek grafika i rozbudowana logika, sprawdzić **skalę, czytelność, sortowanie głębi, mury w 8 kierunkach i wydajność**. To etap najwyższego ryzyka technicznego.

**Zakres:**
- `IsoMath` z testami, kamera z zoomem 0,5×, 1×, 2× i 3×, przesuwanie,
- mapa testowa 64×64 z trawą, siatką i kilkoma przeszkodami,
- placeholdery według ART_SPEC §9.1: postacie 8-kierunkowe z animacjami `walk`, `idle` i `walk_carry_*`, nakładka towaru z punktami zaczepienia,
- budynki 2×2 i 4×4 cięte na paski (ARCHITECTURE §6.2),
- **mury w 8 kierunkach:** rysowanie przeciąganiem, `WallConnectivity` z testami, składanie filarów i półsegmentów, brama,
- postacie chodzące po `AStarGrid2D` wokół budynków i murów, w tym po przekątnych i przy narożnikach,
- widoczność za budynkami: wariant a (przezroczystość) i b (obniżanie budynków), **eksperyment** c (sylwetki przez shader),
- **benchmark:** 500 postaci, mapa 192×192, 20 budynków, pomiar FPS i czasu ticku przy każdym zoomie,
- porównanie: postać 5 kierunków z odbiciami vs 8 kierunków (na placeholderach asymetrycznych: narzędzie w prawej ręce),
- porównanie: renderer Forward+ vs Compatibility.

**Scena testowa sortowania:** postać obchodzi budynek 4×4 dookoła, mur prosty, mur ukośny, narożnik 90° i narożnik 45°, przechodzi przez bramę. Nagrywamy lub robimy zrzuty z każdej strony.

**DoD:**
- [x] Zero błędów sortowania w scenie testowej z każdej z 8 stron. Sprawdzone automatycznie względem prawdziwej głębi (`tests/unit/view/test_sorting.gd`) i wzrokowo na zrzutach.
- [x] Mury łączą się bez szczelin w każdym z 8 kierunków, w narożnikach (90°, 45°, 135°), w trójnikach i na skrzyżowaniach (także ukośnych). Testy maski połączeń przechodzą.
- [x] Postać nie przechodzi przez styk muru ukośnego (`test_nav_grid`).
- [x] Benchmark: 500 postaci, 498 widocznych → 219 FPS, tick 0,64 ms. 2000 postaci → 91 FPS (ARCHITECTURE §9.3).
- [x] Przy 1× widać, co niesie postać, a przy 0,5× widać ruch. Zaakceptowane przez właściciela projektu („Jest super!”, 2026-11-04).
- [x] Decyzje zapisane w dokumentach:
  - wzrost postaci 42 px (bez zmian),
  - widoczność: a + b, wariant c odłożony do M7,
  - odbicia: tak dla cywilów, 8 kierunków dla żołnierzy,
  - renderer: Forward+,
  - nakładki towarów: wariant A działa,
  - skala: całkowita, baza 1280×720,
  - font: Jersey 10.

**Notatki z M1:**
- Brama zmieniła formę: zamiast `gate_x/gate_y` jest złożona z kawałków (`gate_half_*`, `gate_lintel_*`), żeby postać w przejściu sortowała się poprawnie.
- Tryb „obniżone budynki” daje schodkową linię cięcia. Do wygładzenia shaderem przy grafikach docelowych.
- Kod prototypowy leży w `src/prototype/m1/` (ProtoCrowd, piaskownica, benchmark, porównania) i zostanie zastąpiony w M2. Kod docelowy (IsoMath, NavGrid, WallConnectivity, WallGeometry, BuildingSlicer, kamera, widoki) zostaje.
  - M2: piaskownicę i benchmark M1 zastąpiła `src/prototype/m2/` (prawdziwa symulacja). Piaskownica murów też działa już na prawdziwej symulacji (tragarze między magazynami przechodzą przez bramy), a `ProtoCrowd` został usunięty.

---

## A1 — Pilot PixelLab (równolegle z końcówką M1)

**Cel:** wcześnie sprawdzić, czy PixelLab da grafiki zgodne ze specyfikacją, zanim zbudujemy na niej resztę gry.

**Zakres:** jedna postać (piekarz): `idle`, `walk` i `walk_carry_sack` w 8 kierunkach oraz `work_bake`. Do tego jeden budynek 2×2, jeden kafel trawy i jeden blok muru kamiennego (model bryłowy, ARCHITECTURE §6.3). Konwersja narzędziem do formatu z ART_SPEC i podmiana w scenie M1.

**DoD:**
- [ ] Podmiana działa bez zmian w kodzie, tylko przez pliki i importer.
- [ ] Spełnione kryteria akceptacji z ART_SPEC §10 (lub lista wymaganych poprawek specyfikacji).
- [ ] Znane rzeczywiste ograniczenia narzędzia (rozmiar płótna, liczba klatek, spójność między animacjami) zostały wpisane do ART_SPEC.

**Stan A1 po pierwszej próbie (2026-11-05, szczegóły w ART_SPEC §10.1, kod w `src/prototype/walls/`):**
- **Mur kamienny: działa.** Przemalowanie wzoru rysowanego kodem (`edit_image`) zachowuje obrys w 99,7–100%. Próbki ścian i korony tną się automatycznie i teksturują mur w dowolnym kształcie, bez szwów. Brakuje docelowego formatu plików według ART_SPEC §6 i importera.
- **Budynek 2×2: działa** na chatach z biblioteki właściciela projektu (widok izometryczny, pivot w najniższym punkcie). Wieża bramna: przemalowanie wzoru; druga orientacja wymaga osobnego przemalowania (teraz jest lustrzana).
- **Teren: działa i jest w grze** (2026-11-05, ART_SPEC §8.1 i §10.2). Teren organiczny bez widocznej siatki: trawa z plamami i kwiatkami, łąka, ściółka lasu, rzeka ze skarpą, bród i droga z zaokrąglonymi brzegami. Morze z plażą działa w piaskownicy `src/prototype/terrain/` (mapa M3 nie ma morza). Grafiki finalne są włączone (`art_root = res://assets`); czego brak, bierze się z placeholderów.
- **Postać (piekarz): niezrobiona.** To największe ryzyko pilota (R5: spójność postaci między animacjami, rozmiar, pivot).
- Koszty: `edit_image` 10 generacji za obraz do 256×256, `create_map_object` i `create_isometric_tile` po 1, `create_tiles_pro` 10–15. Na koncie zostało ok. 300 z 5000 do 27.11.

---

## M2 — Rdzeń symulacji

**Cel:** działający silnik symulacji: postacie wykonują zadania, noszą towary, magazyny działają, a stan da się zapisać.

**Zakres:**
- `Simulation`, `SimClock` (10 Hz, pauza, 1×/2×/4×), `SimRng`, komendy i zdarzenia,
- `TileGrid`, `NavGrid` z budżetem zapytań, aktualizacja przy budowie,
- `BuildingStore`, komenda budowy (na razie natychmiastowej), `AgentStore`, `TaskRunner` z krokami `GoTo`, `Fetch`, `Work`, `Produce` i `Deliver`,
- `Inventory` z rezerwacjami, `Stockpile` ze slotami, `StockpileLayout` (rezerwacje są częścią `Stockpile`, zob. ARCHITECTURE §5.2),
- `JobBoard` i `TransportRequest` z dopasowaniem tragarzy,
- widok: `AgentViewPool`, interpolacja ruchu, stosy w magazynie, lista towarów w UI z tych samych danych,
- `SaveService`: zapis i odczyt z wersją, test round-trip.

**DoD:**
- [x] Test scenariuszowy: drwal ścina drzewa i odnosi drewno do magazynu. Po 5 min gry w magazynie jest > 0 drewna, a liczba w UI = suma stosów. (`tests/scenario/test_woodcutter.gd`: ok. 10 kłód w 5 min)
- [x] Testy błędów: magazyn pełny, cel zburzony w trakcie, brak ścieżki. Za każdym razem brak utraty towaru i zawieszonych rezerwacji. (`tests/scenario/test_failures.gd`: niezmiennik sprawdzany w każdym ticku)
- [x] Zapis → odczyt → zapis daje identyczny wynik, a symulacja po wczytaniu przebiega deterministycznie tak samo. (`tests/scenario/test_save_round_trip.gd`, fixtura zapisu v1)
- [x] Gra przy 4× działa płynnie z 200 postaciami (tragarze z losowymi zleceniami). Headless: tick 1,1 ms przy 200 i 2,1 ms przy 500 tragarzach. Laptop (2026-11-05, RTX 5070 Ti, okno 1600×900): śr. 713 FPS, najgorsza klatka 3,2 ms, tick 0,54 ms (ARCHITECTURE §9.3).

---

## M3 — VERTICAL SLICE: jeden pełny łańcuch, wszystko widoczne

**Cel:** sprawdzić **główne założenie gry**: czy obserwowanie widocznej pracy mieszkańców i fizycznego przepływu towarów jest czytelne i daje satysfakcję.

**Zakres:**
- mapa: prowincja kontynentalna 96×96 z rzeką, lasem i łąkami (ręcznie przygotowana w `data/maps/`),
- start: ratusz, magazyn, 3 chaty, zapas drewna i chleba,
- budynki według GDD §5.5: chata, studnia, drwal, farma zbożowa z polami, młyn, piekarnia, magazyn, ratusz,
- **budowa fizyczna:**
  - plac budowy,
  - tragarze przynoszą materiały,
  - budowniczy pracuje,
  - 2 fazy budowy,
- **pełny łańcuch z widocznymi etapami:**
  - pole: orka → siew → wzrost → żniwa → snopy do magazynu,
  - młyn: zboże → mąka,
  - piekarnia: mąka → zagniatanie → piec → chleb,
  - do magazynu,
- **domy:**
  - domownik zanosi chleb i drewno do domu,
  - potrzeby chłopów (chleb, opał, studnia),
  - zadowolenie,
  - awans chaty do domu mieszczańskiego po dostarczeniu desek lub drewna,
  - łączenie domów poziomu 2 w pierzeję,
- **ludność:** napływ do wolnych miejsc, siła robocza, przydział pracowników (domyślnie wolny mieszkaniec sam dostaje przydział do nowo postawionego budynku; w M2 robi to jeszcze komenda),
- drogi (ubite): przyspieszenie ruchu, bez wozów,
- **UI:**
  - menu budowy,
  - panel budynku z bieżącym etapem,
  - panel magazynu,
  - panel mieszkańca z trybem „śledź”,
  - nakładka zasięgu studni,
  - powiadomienia podstawowe,
- zapis i odczyt z menu, PL i EN, pseudolokalizacja sprawdzona,
- wszystko na placeholderach w docelowej skali (lub na grafikach z A1, jeśli są gotowe).

**Decyzje właściciela projektu (2026-11-05):**
- **Budowa:** materiały na każdą fazę osobno. Faza 1: fundament i rusztowanie, faza 2: ściany i dach. Tragarze znoszą materiały, a budowniczy pracuje, gdy materiał bieżącej fazy leży na placu.
- **Potrzeby i zadowolenie:** proste punkty. Każda spełniona potrzeba daje część zadowolenia (chleb 40, opał 30, studnia 30). Dom ma mały zapas (ok. 3 porcje). Domownik idzie po towar, gdy zapas spada do połowy. Zadowolenie zmienia się płynnie w stronę celu.
- **Mapa:** obrazek PNG 96×96 w `data/maps/`, kolor piksela = rodzaj terenu. Rzeka przecina mapę i ma 2 brody (przejście wolniejsze).
- **Pola:** najpierw stawiamy budynek farmy, potem pojedyncze kafle pola 1×1 w jej zasięgu (do 16 na farmę).
- **Grafiki:** własne placeholdery dla każdego budynku (z placem budowy w 2 fazach i rusztowaniem), opisane w `data/visuals/`.
- **Tragarze i budowniczowie:** ratusz to miejsce pracy dla 2 tragarzy i 1 budowniczego, obsadzane z wolnych mieszkańców z pierwszeństwem.
- **Napływ:** nowi mieszkańcy przychodzą pieszo z krawędzi mapy. Docelowy model (okresy handlowe, przyrost naturalny) jest w IDEAS.
- **Ustalone domyślnie (do zmiany na prośbę):** ubita droga jest darmowa i powstaje od razu. Dom poziomu 2 ma w slice’ie te same potrzeby co chata, tylko więcej mieszkańców i większe zużycie. Awans chaty kosztuje drewno (desek jeszcze nie ma).

**DoD:**
- [x] Od startu, bez kodów, da się w ~20–30 minut doprowadzić do co najmniej 6 domów poziomu 2 zaopatrywanych w chleb. Automatyczny gracz (`tests/support/slice_bot.gd`, tylko komendy) osiąga to w **20. minucie** (`tests/long/test_slice_dod.gd`). Od M4a mieszczanie potrzebują też ryb i piwa, więc ten sam test sprawdza teraz cel M4a. Właściciel projektu doszedł do celu w czasie (2026-11-05).
- [x] **Każda jednostka chleba w magazynie jest wyprodukowana przez widoczną sekwencję:** pole → snop → młyn → worek mąki → piekarz → kosz chleba. Test z licznikami zdarzeń przechodzi (`tests/scenario/test_bread_chain.gd`). W trybie „śledź” widać cały łańcuch (właściciel projektu, 2026-11-05).
- [x] Kliknięcie dowolnej postaci pokazuje, co robi, zgodnie z tym, co widać (`AgentDescriber`). Opis zawsze się zgadzał (właściciel projektu, 2026-11-05).
- [x] Lista w UI magazynu = stosy na placu, w każdej chwili. Oba czytają te same sloty (`Stockpile.totals`, `StockpileLayout`), test w `test_woodcutter.gd`.
- [x] Brak zakleszczeń przez 2 godziny gry przy 4× (test scenariuszowy headless, `test_slice_dod.gd`: żadna rezerwacja bez właściciela, żadne zadanie nie stoi 5 minut na jednym kroku). Tempo 4× nie zmienia ticków, więc test liczy po prostu 72 000 ticków.
- [x] Zapis w trakcie pracy (postacie niosą towary) → odczyt → wszystko kontynuuje bez utraty towaru (`test_save_round_trip.gd`: wioska z placem budowy, polami i domami, zapis v2, fixtura `v2_village.json`).
- [x] UI w PL i EN bez obciętych tekstów, poprawne formy liczby mnogiej. Sprawdzone na zrzutach w chmurze (PL, EN, pseudolokalizacja F11) i na laptopie (2026-11-05).
- [x] **Twoja ocena gry:** czy to jest fajne do oglądania? Ocena 5/5, wnioski w GDD §11.1.

**Balans wyjściowy (strojony automatycznym graczem, 2026-11-05):** drwal rąbie 4 s i wiąże 2 s, opał 0,03 na osobę na minutę, chleb 0,1 na osobę na minutę, na start 50 drewna i 12 chleba, 1 worek mąki = 2 chleby, pole dojrzewa 90 s. Wszystko jest w `data/`.

---

## M4 — Miasto i ekonomia

Podzielony na dwie części (decyzja 2026-11-05). Każda kończy się Twoją grą i oceną.

**Decyzje właściciela projektu (2026-11-05):**
- **Start bez oceny M3:** M4a robimy od razu, choć ocena M3 na laptopie jeszcze czeka. Świadome ryzyko: jeśli w M3 coś nie zagra, część M4a może wymagać poprawek. *Ocena M3 z 2026-11-05 wypadła 5/5, więc poprawki nie są potrzebne.*
- **Opał przed budową:** zlecenia budowy nie biorą ostatnich 5 sztuk drewna z magazynu (rezerwa dla domów). Gracz zmienia tę rezerwę suwakiem w panelu magazynu.
- **Tragarze w magazynach:** każdy magazyn ma 2 miejsca pracy dla tragarzy. Ratusz zostaje z 2 tragarzami i 1 budowniczym.
- **Białko dla mieszczan w M4a: ryby z wędkarzem** przy rzece. Mięso (chlew, rzeźnik) w M4b. Kutry na morzu później (IDEAS).
- **Opał:** domy dalej palą zwykłym drewnem. Osobnego drewna opałowego nie robimy.
- **Złoto:** część większych budynków (np. kościół, browar, targowisko) kosztuje też złoto.
- **Wozy:** w M4b razem z brukiem.
- **M4b-3 przed oceną M4b-2 (2026-11-05):** M4b-3 zaczynamy, zanim właściciel projektu oceni M4b-2 na laptopie. Świadome ryzyko poprawek, szczegóły w sekcji M4b-3.

### M4a — Mieszczanie i porządek w logistyce

**Zakres:**
- klasa mieszczan z pełnymi potrzebami (GDD §3.2): chleb, ryby, piwo, opał; dodatkowo kościół i targowisko,
- awans chaty do domu mieszczańskiego za deski zamiast drewna,
- budulec: tartak (deski), kamieniołom (kamień),
- żywność i napoje: wędkarz (ryby), farma chmielu i browar (piwo),
- kaplica (dodatkowa potrzeba chłopów), kościół, targowisko z zasięgiem,
- podatki ze stawką (niska, normalna, wysoka) i złoto jako koszt części budynków,
- priorytety pracy budynków (wysoki, normalny, niski),
- rezerwa drewna dla domów (suwak w panelu magazynu),
- 2 miejsca dla tragarzy w każdym magazynie,
- zapis: nowy `save_version` z migracją i testem.

**Ustalone przy realizacji (2026-11-05, do zmiany na prośbę):**
- **Awans czeka na towary nowej klasy:** chata zaczyna awans dopiero wtedy, gdy w magazynach jest po 4 sztuki chleba, ryb i piwa. Bez tego automatyczny gracz pokazał „huśtawkę”: domy awansowały, po 3 minutach bez piwa spadały, a deski przepadały. Potwierdzone przez właściciela projektu.
- **Balans:** 1 kłoda = 2 deski, 1 zboże + 1 chmiel = 2 beczki piwa, skała daje 8 kamieni, wędkarz łowi 2 ryby na kurs. Podatki 0,25 (chłop) i 0,6 (mieszczanin) złota na minutę. Szczegóły w GDD §3.2, §3.5, §4.3.
- **Skały** to pojedyncze węzły na mapie (dwie grupy na `riverlands`), bez nowego terenu. Teren skalisty zostaje w M4b.
- **Chłopi** jedzą chleb albo ryby (GDD §3.2), a kaplica to ich dodatkowa potrzeba.
- **Targowisko** to na razie usługa z zasięgiem. Straganiarze są w IDEAS.

**Wnioski z gry właściciela (2026-11-05):**
- Budynku nie da się postawić tak, żeby wejście było nieosiągalne (np. chata rybaka drzwiami do rzeki) albo żeby odciął drogę innym. Budowniczy omija budowę, do której nie dojdzie (GDD §5.1).
- Powrót do menu robi szybki zapis.
- **Domy się nie cofają:** brak potrzeby podstawowej obniża zadowolenie (mniejsze podatki, brak nowych mieszkańców), a przy bardzo niskim zadowoleniu ludzie powoli się wyprowadzają. Wariant łagodny (GDD §3.3).
- **Zapas na budowy:** warsztaty zostawiają w królestwie ustawioną liczbę sztuk towaru, np. tartak nie zje całego drewna (GDD §4.1, pkt 6). Zapis w wersji 4.

**DoD:**
- [x] Automatyczny gracz od startu dochodzi do 6 domów mieszczan ze wszystkimi potrzebami podstawowymi (chleb, ryby, piwo, opał, studnia) w **38. minucie** (`tests/long/test_slice_dod.gd`, limit 50 minut).
- [x] Każdy nowy łańcuch (deski, kamień, ryby, chmiel, piwo) ma test scenariuszowy z licznikami zdarzeń (`tests/scenario/test_m4a_chains.gd`).
- [x] Przy budowach domy nie tracą opału: budowy zostawiają rezerwę, domownicy ją biorą (`tests/unit/sim/economy/test_logistics.gd`, tam też priorytety, podatki i złoto).
- [x] Brak zakleszczeń przez 2 godziny przy 4× (`test_slice_dod.gd`). Po 2 godzinach mieszczanie wciąż są zaopatrzeni.
- [x] Zapis z M3 wczytuje się po migracji (v2 → v3) bez utraty towaru. Nowa fixtura `v3_town.json`.
- [x] UI w PL i EN, nowe teksty przez klucze tłumaczeń. Klucze sprawdza test, panele sprawdzone na zrzutach w chmurze (PL) i na laptopie w PL i EN (2026-11-05).
- [x] **Twoja ocena gry.** Ocena 4/5, wnioski w GDD §11.1.

### M4b — Patrycjusze i ruch w mieście

**Zakres:**
- klasa patrycjuszy (GDD §3.2): ubrania, miód pitny lub wino, łaźnia lub tawerna,
- tekstylia: owczarnia, tkalnia, krawiec; pasieka i miodosytnia; cegielnia,
- mięso: chlew i rzeźnik (mięso i skóry),
- wozy na drogach i bruk,
- kupiec wędrowny (także jako źródło nowych mieszkańców, IDEAS),
- więcej typów terenu (jezioro, skały),
- leśniczy sadzący drzewa, wstrzymanie produkcji w panelu budynku, straganiarze na targowisku (wnioski z testów M4a, decyzja 2026-11-05, opis w IDEAS).

**DoD:**
- [ ] Da się dojść do patrycjuszy.
- [ ] Każdy łańcuch ma test scenariuszowy.
- [ ] Brak zakleszczeń przez 2 godziny przy 4× na dużym mieście (400+ postaci).
- [ ] Wydajność według ARCHITECTURE §9.1.
- [ ] **Twoja ocena gry.**

**Podział na trzy części (decyzja właściciela projektu 2026-11-05).** Każda część kończy się Twoją grą i oceną. Powyższe DoD dotyczy całego M4b.
- **M4b-1: patrycjusze i poprawki** (szczegóły niżej).
- **M4b-1.5 „Miasto” (decyzja 2026-11-05, po ocenie M4b-1):** obracanie budynków przy stawianiu (wejście z wybranej strony), domy w dwóch rzędach plecami do siebie i przodem do drogi, nowe pierzeje mieszczan (biedniejsze) i patrycjuszy (bogatsze) z elementami narożnymi. Własny styl, inspiracja ilustracjami od właściciela projektu (Anno 1404), bez kopiowania.
- **M4b-2:** mięso (chlew, rzeźnik, skóry), straganiarze na targowisku, kupiec wędrowny, który skupuje nadwyżki (ujście towarów z pełnych magazynów), okno „Zapasy królestwa” (suma ze wszystkich magazynów) oraz produkcja i zużycie na minutę (decyzja 2026-11-05). Na początku etapu (ankieta po ocenie M4b-1.5, 2026-11-05): **prywatny stos przy budynku produkcyjnym** (gdy magazyny są pełne, pracownik odkłada towar na stos przy swoim budynku, a gdy ten jest pełny, czeka; koniec zawalania ziemi drewnem) oraz **gęsty las**: drzewa przestają być przeszkodą (przez las idzie się wolniej), a leśniczy sadzi kafel w kafel jak las z mapy, nigdy na drogach, polach, kaflach przed drzwiami i tuż przy budynkach.
- **M4b-3:** wozy i bruk, nowe tereny (jezioro, skały), duże miasto 400+ postaci i wydajność. Startuje przed oceną M4b-2 (decyzja 2026-11-05), szczegóły niżej.

#### M4b-1 — Patrycjusze i poprawki

**Decyzje (2026-11-05):**
- **Tawerna zamiast łaźni.** Karczmarz przynosi z magazynu piwo i miód pitny. Tawerna działa w zasięgu tylko wtedy, gdy niedawno podawała napitki (bez zapasów przestaje działać).
- **Miód pitny teraz, wino później.** Wino wymaga rzadkiego surowca (winorośl), który dojdzie z mapą świata (M6).

**Zakres:**
- leśniczy: sadzi sadzonki w zasięgu, najpierw na pniakach; sadzonka po kilku minutach rośnie w drzewo,
- przycisk „wstrzymaj produkcję” w panelu budynku (pracownik zostaje, ale nie zaczyna nowego cyklu),
- owczarnia → wełna → tkalnia → sukno → krawiec → ubrania,
- pasieka → miód → miodosytnia → miód pitny,
- glinianka nad wodą → glina; glina + drewno → cegielnia → cegły,
- tawerna (usługa z zasięgiem, zużywa piwo i miód pitny),
- kamienica patrycjuszy: awans domu mieszczańskiego za cegły i deski (GDD §3.2, §3.3),
- zapis: nowy `save_version` z migracją i testem.

**DoD:**
- [x] Automatyczny gracz od startu dochodzi do 4 kamienic patrycjuszy ze wszystkimi potrzebami podstawowymi w **77. minucie** (`test_slice_dod.gd`, limit 90 minut; etap patrycjuszy zaczyna od 45. minuty).
- [x] Każdy nowy łańcuch (wełna, sukno, ubrania, miód, miód pitny, glina, cegły) ma test scenariuszowy z licznikami zdarzeń (`tests/scenario/test_m4b1_chains.gd`, tam też tawerna).
- [x] Leśniczy: las przy drwalu nie znika przez 2 godziny gry (138 kłód z 16 drzew na starcie). Wstrzymany budynek nie zaczyna cyklu, a po wznowieniu pracuje dalej (`test_m4b1_chains.gd`).
- [x] Brak zakleszczeń przez 2 godziny przy 4× (`test_slice_dod.gd`, z patrycjuszami).
- [x] Zapis z M4a wczytuje się po migracji bez utraty towaru (v4 → v5, nowa fixtura `v5_town.json`).
- [x] UI w PL i EN, nowe teksty przez klucze tłumaczeń (test kluczy; panele obejrzane na zrzutach z laptopa).
- [x] **Twoja ocena gry:** 4/5 (2026-11-05). Wygląd kamienic 2/5. Wnioski niżej i w GDD §11.1.

**Wnioski z gry właściciela (2026-11-05):**
- Patrycjusze osiągalne bez problemu, tawerna prawie zawsze działa, teksty PL/EN bez uwag. Kierunek gry się podoba.
- **Poprawki w tym samym PR:** sadzonki widać od razu (był błąd odświeżania), drwal zabiera ostatnią kłodę razem z pniakiem, ikonka nad wstrzymanym budynkiem, ogranicznik klatek, puste pola w pełnym magazynie, łatwiejsze klikanie budynków, menu budowy z zakładkami i ikonkami.
- **Do M4b-1.5 „Miasto”:** łączone kamienice z narożnikami, domy przodem do drogi, obracanie budynków, dwa rzędy domów obok siebie (dziś niemożliwe, bo wejście jest zawsze w tym samym narożniku).
- **Do M4b-2:** magazyny szybko się zapełniają i blokują gospodarkę; brakuje podglądu zapasów ze wszystkich magazynów i licznika produkcji na minutę.
- Nowe postacie widać „częściowo”: ich praca mogłaby być czytelniejsza (IDEAS: efekty przy pracy).

**Ustalone przy realizacji (2026-11-05, do zmiany na prośbę):**
- **Leśniczy** sadzi w promieniu 8 kafli, co drugi kafel w obu kierunkach (między drzewami zawsze zostaje przejście), nigdy tuż obok budynku ani drogi. Przestaje sadzić przy 30 drzewach w swoim zasięgu. Sadzonka rośnie 5 minut i nie rośnie, gdy ktoś na niej stoi. Ścięte drzewo znika razem z pniakiem (pniaki ze starych zapisów leśniczy obsadza w pierwszej kolejności).
- **Magazyn** ma 15 pól zamiast 12: stos stoi na każdym kafelku placu oprócz wejścia. **Gra** rysuje najwyżej 60 klatek na sekundę.
- **Tawerna:** jedno podanie (1 piwo + 1 miód pitny) co ok. 50 s; po nim tawerna działa w zasięgu 90 s.
- **Balans:** owczarnia 2 wełny na cykl, 2 wełny = 1 sukno, 1 sukno = 2 ubrania, pasieka 1 miód, 1 miód = 2 miody pitne, glinianka 2 gliny, 1 glina + 1 drewno = 2 cegły. Patrycjusze: 12 osób, podatek 1,2 złota na minutę, ubrania 0,02 i miód pitny 0,03 na osobę na minutę.
- **Grafika** narysowana kodem (budynki, 9 zawodów, towary, sadzonka, kamienice z kamiennym parterem).

#### M4b-1.5 — Miasto

**Decyzje (2026-11-05, ankieta z właścicielem projektu):**
- **Kamera widzi tylko dwie przednie ściany budynku.** Lustrzane odbicie zamienia je między sobą, więc drzwi zostają widoczne. Drzwi z tyłu wymagają osobnej grafiki „od tyłu”.
- **Domy mają 4 orientacje, pozostałe budynki 2 (lustro).** Warsztaty, usługi i magazyny zawsze pokazują pracę kamerze. Domy z drzwiami z tyłu pokazują tylną ścianę (ogródek, tylne drzwi, mniej ozdób).
- **Obracamy wszystkie budynki** jednym mechanizmem (rozwiązuje też chatę rybaka drzwiami do rzeki).
- **Kierunek przy stawianiu:** podgląd sam obraca wejście do drogi, która przylega do budynku. Klawisz **R** przełącza stronę ręcznie i ręczny wybór obowiązuje do końca tego stawiania. Bez drogi obok: ostatnio wybrana strona.
- **Narożniki:** gdy dwa rzędy spotykają się pod kątem prostym, dom na rogu dostaje grafikę narożną (wspólny dach łamany na róg). Końce rzędów mają ozdobny szczyt. Patrycjusze: wykusz lub wieżyczka na rogu.
- **Obrys domów zostaje 2×2.** Zwartość daje grafika: wyższe dachy, lukarny, brak przerw między domami. Symulacja i balans bez zmian.
- **Podcienia patrycjuszy są tylko wyglądem** (arkady na parterze od strony drogi). Ludzie chodzą drogą przed nimi.
- **Zapis:** wersja 6, każdy budynek zapisuje orientację. Migracja v5 → v6 daje dzisiejszą stronę wejścia, więc nic się nie przesuwa.

**Zakres:**
- orientacja budynku w danych i symulacji: obrócone wejście, sprawdzanie miejsca (dostęp, „wejście na wodę”), komenda stawiania z orientacją,
- podgląd stawiania: automatyczny wybór strony do drogi i klawisz R, podpowiedź o R w UI (tłumaczenia PL i EN),
- widok: lustro grafiki, grafiki „od tyłu” dla domów (wszystkie 3 poziomy, plac budowy i rusztowanie), cięcie do sortowania (`BuildingSlicer`) dla każdej orientacji,
- pierzeje: łączenie w rzędy uwzględnia orientację (łączą się domy tego samego poziomu, patrzące w tę samą stronę), nowe warianty: róg, ozdobny koniec, środek; dwa rzędy plecami do siebie stykają się bez szwów,
- nowe grafiki rysowane kodem: pierzeje mieszczan (skromne: tynk, szachulec, proste szczyty) i patrycjuszy (bogate: cegła i kamień, wysokie dachy, lukarny, podcienia, wykusze na rogach). Własny styl, bez kopiowania Anno,
- zapis v6 z migracją, fixturą i testem; aktualizacja ART_SPEC §7 (nazwy plików nowych wariantów) i ARCHITECTURE §6.2, §6.6.

**Poza zakresem:** obracanie kamery i przechodzenie pod podcieniami (IDEAS), węższe domy 1×2, premie za pierzeje.

**DoD:**
- [x] Każdy budynek da się postawić w każdej swojej orientacji. Postacie wchodzą do budynku od wybranej strony (`test_orientation.gd`: każdy budynek i orientacja, wejście i wyjście przez kafel przed drzwiami).
- [x] Dwa rzędy domów plecami do siebie, każdy przodem do swojej drogi, działają w grze: mieszkańcy się wprowadzają i są zaopatrywani (`test_town_rows.gd`).
- [x] Podgląd sam obraca dom do przylegającej drogi, a R przełącza stronę (`test_orientation.gd`, `PlacementTurn`; w grze półprzezroczysty budynek pod kursorem i zaznaczony kafel przed drzwiami).
- [x] Sortowanie bez błędów dla każdej orientacji, także dla rogów i rzędów plecami do siebie (`test_sorting.gd`, także pasek budynku z paskiem sąsiada).
- [x] Pierzeje mieszczan i patrycjuszy z rogami i końcami widoczne na zrzucie (`town_shot.tscn --layout`, na laptopie) w układzie: prosty rząd, róg, dwa rzędy plecami do siebie.
- [x] Zapis z M4b-1 wczytuje się po migracji (v5 → v6) bez przesunięcia wejść, nowa fixtura `v6_town.json`.
- [x] Wszystkie testy przechodzą, automatyczny gracz dalej dochodzi do patrycjuszy w limicie (`test_slice_dod.gd`).
- [x] **Twoja ocena gry** na laptopie (2026-11-05): wygląd kamienic **5/5** (poprzednio 2/5); obracanie, wejścia, leśniczy i wyręby działają bardzo dobrze. Uwagi do M4b-2: drwale rąbią dalej przy pełnych magazynach i zawalają ziemię drewnem; leśnicy mogliby sadzić gęściej.

**Ustalone przy realizacji (2026-11-05, do zmiany na prośbę):**
- **Drzwi:** postacie wchodzą i wychodzą tylko przez kafel przed drzwiami. Przy stawianiu musi on być wolny (inaczej „ludzie nie dojdą” albo „wejście na wodę”) i potem nie da się go zabudować. W starych zapisach, gdzie jest zastawiony, ludzie używają innego wolnego boku wejścia.
- **Podgląd:** półprzezroczysty budynek w wybranej orientacji i zaznaczony kafel przed drzwiami. Wybór klawiszem R trwa do zmiany narzędzia (wygodne przy stawianiu całego rzędu). Bez drogi obok zostaje strona ostatnio postawionego budynku.
- **Kamienice szczytem do ulicy** (poprawka właściciela po pierwszej wersji, szkic 2026-11-05): kalenica w głąb działki, szczyty od ulicy w 3 kształtach (mieszczanie: szachulec, wygięty, schodkowy; patrycjusze: ceglany schodkowy z blendami, wygięty, prosty). Sąsiedzi dostają różne szczyty według położenia. Róg ma dwa szczyty, u patrycjuszy wykusz z wieżyczką. Tył: prosty szczyt, tylne drzwi, beczka i drewno. Podcienia patrycjuszy na obu ulicach rogu.
- **Działki z kilkoma domami** (druga poprawka właściciela, ankieta 2026-11-05): na działce 2×2 mieszczan stoją 1–3 węższe domy, na działce patrycjuszy 1–2 domy różnej wysokości. Fronty nie stoją w jednej linii (część domów lekko cofnięta). Między działkami mieszczan wąskie przerwy, całość na bruku; patrycjusze tworzą zwartą pierzeję. Każdy dom ma własny odcień z surowszej palety. Dachy: patrycjusze ciemny łupek, mieszczanie przygaszona dachówka, czasem łupek. Narożnik: ścięty róg z bramą i ukośnym szczytem nad nią (u patrycjuszy jeden z trzech wyglądów ma zamiast tego wykusz z wieżyczką). Dla gry to nadal jeden dom 2×2.
- **Po pierwszej grze właściciela (ankieta 2026-11-05):** narożnik powstaje też wtedy, gdy dom z sąsiadem w rzędzie ma drogę przed drzwiami i drogę przy wolnym końcu. Podgląd stawiania wybiera stronę z drogą, a wśród nich tę, przy której dom tworzy rząd z sąsiadem; bez drogi bierze kierunek sąsiada w rzędzie. Postawiony dom bez drogi przed drzwiami sam obraca się do nowej drogi obok (domy z drogą nie obracają się). Wygląd domu: klawisz T przy stawianiu i przycisk „Zmień wygląd” w panelu; wybór zapisuje się w grze (`look`, zapis v6).
- **Wejścia (druga gra właściciela, 2026-11-05):** magazyny mają drzwi z każdej strony, pozostałe budynki oprócz domów także po przeciwnej stronie (z tyłu, więc bez nowych grafik; wyjątek: ratusz ma drzwi narysowane tylko z jednej strony). Do stawiania i działania wystarczy jedne drzwi z wolnym kaflem przed nimi; ludzie wybierają drzwi bliższe celu. Cały budynek, także kafle wejść, jest nieprzechodni: na wejście wchodzi się tylko z kafla przed drzwiami, więc nikt nie skraca drogi przez róg budynku (ludzie „znikali pod budynkiem”). Panel budynku ma przycisk „Obróć”.
- **Leśniczy i wejścia (trzecia gra właściciela, 2026-11-05):** postać wchodząca do budynku płynnie znika w drzwiach, a wychodząca pojawia się (tylko widok; ludzie odpoczywający w środku nie są rysowani, pracujący przy stanowisku tak). Leśniczy przy pełnym lesie (30 drzew w zasięgu) pisze „las w zasięgu jest pełny”, a gdy nie ma gdzie sadzić, „brak wolnego miejsca do sadzenia”. W panelu leśniczówki „Miejsce sadzenia”: przeciągasz myszą po kaflach w zasięgu i leśniczy sadzi tylko tam (zapis `plant_area`); „Wyczyść miejsce sadzenia” wraca do całego zasięgu. Ścięte drzewo zabrane z pniakiem zmienia ściółkę leśną pod sobą w trawę.
- **Tawerna:** test daje 3 minuty na 2 podania zamiast 2,5 (droga przez drzwi jest odrobinę dłuższa).

#### M4b-2 — Mięso, targ i kupiec

**Decyzje (2026-11-05, ankieta z właścicielem projektu):**
- **Stos przy budynku:** gdy żaden magazyn nie ma miejsca, pracownik odkłada wyrób na stos przy swoim budynku. Stos mieści **pół pola magazynu** danego towaru (np. 10 drewna, 6 piw). Gdy stos jest pełny, pracownik czeka przy budynku (powód w panelu). Stos jest **wspólny**: warsztaty, domownicy i budowy biorą z niego jak z magazynu, a tragarze odnoszą go do magazynu, gdy zwolni się miejsce. Koniec zawalania ziemi drewnem.
- **Gęsty las:** **wszystkie** drzewa (z mapy i posadzone) są przechodnie. Przez las idzie się **1,5× wolniej** niż po trawie, tak jak dziś po ściółce. Kafel z drzewem nadal blokuje stawianie budynków, dróg i pól.
- **Leśniczy sadzi kafel w kafel, bez limitu drzew:** sadzi, dopóki ma wolne miejsce w zasięgu albo w „Miejscu sadzenia”. Nigdy na drogach, polach, kaflach przed drzwiami ani tuż przy budynkach.
- **Świnie (wersja prosta):** chlew jest „żywym magazynem” świń. Świnie rozmnażają się same, tym szybciej, im więcej ich jest, aż do pojemności chlewu. Pierwsze 2 świnie trzeba **kupić od kupca**, potem można dokupić więcej, żeby stado rosło szybciej. **Ostatnie 2 świnie zawsze zostają** (zabezpieczenie przed wybiciem stada). Rzeźnik przychodzi do chlewu po dorosłą świnię i **prowadzi ją do rzeźni** (świnia idzie obok niego jak niesiony towar). Rzeźnik robi mięso i skóry.
- **Później, osobny etap razem z owcami:** zagrody stawiane kafelkami z płotem, zwierzęta chodzące po zagrodzie i suwak „ile świń zostawiamy do rozmnażania” (IDEAS).
- **Skóry** w M4b-2 służą tylko na sprzedaż kupcowi. Garbarz i zbroje skórzane dojdą z wojskiem (M7).
- **Kupiec wędrowny:** wóz przyjeżdża z krawędzi mapy **co ok. 10 minut** gry i stoi **3 minuty przy targowisku**. Bez targowiska nie przyjeżdża. Tragarze noszą do wozu nadwyżki z magazynów (widoczna praca).
- **Ceny stałe, próg gracza:** każdy towar ma stałą cenę skupu według długości łańcucha. Gracz ustawia przy towarze „sprzedawaj powyżej N sztuk”. Domyślnie kupiec nic nie skupuje.
- **Kupiec sprzedaje tylko świnie** (przycisk w panelu targowiska). Inne towary na sprzedaż później.
- **Straganiarze:** noszą z magazynu na kramy wszystko, czego potrzebują domy: chleb, ryby, mięso, piwo, miód pitny, ubrania i drewno opałowe. Domownicy w zasięgu targowiska kupują na kramach zamiast iść do magazynu. Targowisko działa w zasięgu tylko wtedy, gdy kramy mają towar (jak tawerna).
- **Okno „Zapasy królestwa”:** przycisk na górnym pasku. Dla każdego towaru: ile jest we wszystkich magazynach i na stosach, ile powstaje i ile się zużywa na minutę (**średnia z ostatnich 5 minut** gry), a różnica na zielono lub czerwono.

**Część 2, stan (2026-11-06):** decyzje z ankiety: zbiórka wyprawy widoczna (osadnicy idą z domów, tragarze i portowcy ładują), wyprawa czeka przy granicy na wejście gracza, koga po wysadzeniu osadników wraca do portu. Zrobione: ratusz jako siedziba (jeden na prowincję, podatek mieszczan i patrycjuszy tylko przy ratuszu, wyprawy tylko z prowincji z ratuszem), warianty szablonów (odbicie, bogactwo złóż), mapa „Wyspy” (`tools/generate_island_map.py`), wyprawa osadników morzem i lądem (`Departure`, `Expedition`, `SendExpeditionCommand`, lądowanie od strony lądu z wozem osadników), okno wyprawy w ratuszu, kogi i wozy na mapie świata, zapis v13. Uproszczenia: wóz osadników jeździ też poza drogami i nie potrzebuje stajni; „żyzne pola” z bogactwa czekają (gra nie ma jeszcze żyzności gleby); w małym miasteczku zbiórka trwa kilka minut, bo osadnicy wychodzą z domów, a z nimi ubywa tragarzy (zestaw nosi się sztuka po sztuce, jak przy załadunku kogi). Zrzut mapy świata z wyprawami: `world_shot.tscn -- --out=<plik.png> --expeditions [--select=amber_coast]`. **Przebudowa wypraw (decyzja właściciela 2026-11-06, ankieta), gotowa i czeka na ocenę:** przyciski „Wyprawa lądowa” i „Wyprawa morska” w ratuszu i w panelu prowincji na mapie świata, bez wyboru celu. Gotowa wyprawa czeka w mieście (wóz przed ratuszem, koga przy nabrzeżu) i ma znaczek na mapie świata. Klik na znaczek, potem prawy przycisk na prowincję wysyła ją, a złoto płaci się dopiero wtedy. Przed wysłaniem można ją rozwiązać i wszystko wraca (ludzie, zestaw, koga na kotwicę). Okno „Wyprawa osadników” usunięte. Zapis zostaje w wersji 13 (bez zmiany formatu). Testy: `test_m6_expedition.gd`, `test_expedition_box.gd`. Zrzut gotowej wyprawy: `world_shot.tscn -- --out=<plik.png> --ready`.

**Kolejność prac:** najpierw stos przy budynku i gęsty las (część 1, sprawdzona testami przed resztą), potem mięso (część 2), na końcu targ, kupiec i okno zapasów (część 3). Jedna ocena gry na końcu etapu.

**Zakres:**
- część 1: stos przy budynku produkcyjnym (nowy rodzaj magazynu przy budynku: źródło dla wszystkich, zlecenia tragarzy do magazynu), czekanie pracownika przy pełnym stosie, grafika stosu przy budynku; drzewa przechodnie z kosztem lasu, leśniczy sadzący kafel w kafel bez limitu,
- część 2: chlew (świnie, rozmnażanie, pojemność, rezerwa 2 świń), rzeźnia (świnia → mięso + skóry), rzeźnik prowadzący świnię, mięso jako potrzeba mieszczan i patrycjuszy („mięso lub ryby”, GDD §3.2), nowe towary: świnie, mięso, skóry,
- część 3: kupiec wędrowny (przyjazd, postój przy targowisku, skup według progów, sprzedaż świń, złoto), panel targowiska z progami sprzedaży i kupnem świń, straganiarze i kramy, zakupy domowników na targu, okno „Zapasy królestwa” z licznikami na minutę,
- grafika rysowana kodem: chlew, rzeźnia, świnia (prowadzona), wóz kupca, kramy z towarem, stos przy budynku, zawody: świniarz, rzeźnik, straganiarz, kupiec,
- zapis: wersja 7 z migracją, fixturą i testem; teksty PL i EN; aktualizacja GDD §3.2, §4.1, §4.3, §4.6 i ARCHITECTURE §5.2, §5.3, §8.

**Poza zakresem:** zagrody kafelkami i zwierzęta chodzące po zagrodzie, suwak stada, owce od kupca, garbarz, kupiec sprzedający inne towary niż świnie, wahania cen, wozy i bruk (M4b-3).

**DoD:**
- [x] Przy pełnych magazynach pracownicy odkładają wyroby na stos przy budynku i czekają, gdy stos jest pełny. Na ziemi nie ma kup z produkcji. Po zwolnieniu miejsca tragarze odnoszą stosy do magazynu (`tests/unit/sim/economy/test_yard.gd`, `test_failures.gd`).
- [x] Postacie przechodzą przez las wolniej niż po trawie. Leśniczy sadzi kafel w kafel i nigdy na drogach, polach, kaflach przed drzwiami ani tuż przy budynkach (`tests/unit/sim/test_forest.gd`). Las przy drwalu nie znika przez 2 godziny gry (`test_m4b1_chains.gd`).
- [x] Łańcuch mięsa ma test scenariuszowy z licznikami: kupno świń, rozmnażanie do pojemności, rzeźnik prowadzi świnię, mięso i skóry w magazynie, ostatnie 2 świnie zostają (`tests/scenario/test_m4b2_chains.gd`).
- [x] Kupiec przyjeżdża co ok. 10 minut, skupuje tylko ponad progi gracza i płaci złotem; bez targowiska nie przyjeżdża (`test_m4b2_chains.gd`).
- [x] Domownicy w zasięgu targowiska z towarem kupują na kramach, a bez towaru na kramach idą do magazynu (`test_m4b2_chains.gd`).
- [x] Okno „Zapasy królestwa” pokazuje sumę ze wszystkich magazynów i stosów, zgodną z symulacją, oraz produkcję i zużycie na minutę (`test_goods_ledger.gd`; okno obejrzane na zrzucie z laptopa, `town_shot.tscn --stocks`).
- [x] Automatyczny gracz dalej dochodzi do patrycjuszy w limicie (6 domów mieszczan w 29. minucie, 4 kamienice w 72.), a mieszczanie jedzą też mięso: chlew i rzeźnia od 25. minuty, w 2 godziny 86 mięsa (`test_slice_dod.gd`).
- [x] Brak zakleszczeń przez 2 godziny przy 4×, także przy pełnych magazynach (`test_slice_dod.gd`; czekanie przy pełnym stosie nie jest zakleszczeniem). Kupiec kupił w tym czasie 58 desek i 22 skóry.
- [x] Zapis z M4b-1.5 wczytuje się po migracji (v6 → v7) bez utraty towaru, nowa fixtura `v7_town.json` (`test_save_round_trip.gd`).
- [x] UI w PL i EN, nowe teksty przez klucze tłumaczeń (test kluczy; panele chlewu i targu obejrzane na zrzutach w PL).
- [x] **Twoja ocena gry:** 5/5 (2026-11-07, ankieta na laptopie). Wnioski w GDD §11.1.

**Poprawki z oceny (2026-11-07, mają pierwszeństwo przed M7):**
- [x] **Podwórko przy budynkach ze stosem:** stos nie może leżeć na kaflach budynku (teraz wystaje zza ścian chaty drwala i chaty rybaka). Budynek ze stosem dostaje wolne pole przed wejściem i tam rośnie stos. Wymaga zmiany rozmiaru lub rysunku tych budynków i testu sortowania. **Zrobione (paczka 2, ankieta 2026-11-07: ten sam rozmiar, nowy rysunek, wszystkie budynki ze stosem):** 21 warsztatów zostaje w swoim rozmiarze, ale chata stoi na tylnych kaflach, a kafel obok drzwi (przy tej samej ścianie) to narysowane podwórko z ubitej ziemi; tam rośnie stos (dwa towary, np. mięso i skóry, stoją obok siebie). Przy obróconym budynku podwórko jest po drugiej stronie drzwi. Test sortowania: `test_yard_stack_sorts_correctly`. Zapis bez zmian (podwórko wynika z budynku). Zrzut: `game_shot.tscn -- --tile=56,62 --zoom=2 --plain --yards=woodcutter,fishing_hut,quarry,sawmill,bakery,slaughterhouse`.
- [x] **Więcej straganiarzy na targu** (np. 3–4 zamiast 2), żeby kramy w dużym mieście nie stały puste. **Zrobione (paczka 1, ankieta 2026-11-07): 4 straganiarzy na targ.**

**Do sprawdzenia przy ocenie gry (lista na laptop):**
- Stos przy budynku: czy przy pełnych magazynach drwal przestaje rąbać, stos widać przy chacie, a tragarze go odnoszą, gdy zrobi się miejsce. Czy panel mówi „czeka: stos przy budynku jest pełny”.
- Gęsty las: czy leśniczy sadzi kafel w kafel i nie zarasta dróg, pól ani wejść. Czy ludzie chodzący przez las wyglądają dobrze i nie są za wolni.
- Świnie: kupno pierwszych 2 świń u kupca (panel targu), czy tragarz prowadzi je do chlewu, czy stado rośnie i widać je w zagrodzie. Czy rzeźnik z prowadzoną świnią wygląda czytelnie.
- Kupiec: czy przyjeżdża co ok. 10 minut, czy wóz stoi w dobrym miejscu przy targu, czy sprzedaż ponad próg w oknie „Zapasy” jest zrozumiała.
- **Targ:** działa teraz tylko z towarem na kramach. W dużym mieście (ok. 120 mieszkańców) 2 straganiarzy nie nadąża i kramy bywają puste. Do decyzji: więcej straganiarzy, większe kramy albo zostawić.
- Okno „Zapasy”: czy liczby na minutę są czytelne i przydatne. Uwaga: po wczytaniu gry przez pierwsze minuty pokazują zera (liczniki nie są zapisywane).
- Stary zapis: po wczytaniu gry sprzed M4b-2 kupiec przyjeżdża od razu (gdy jest targowisko).
- Drewno: w grze automatycznego gracza drewna stale brakuje na budowy (było tak już wcześniej; chlew kosztuje 8 drewna). Czy w Twojej grze to przeszkadza.

**Ustalone przy realizacji (2026-11-05, do zmiany na prośbę):**
- **Stos przy budynku** mieści pół pola magazynu (drewno 10, piwo 6). Pracownik niesie wyrób na stos tylko wtedy, gdy żaden magazyn nie ma miejsca; gdy stos jest pełny, czeka pod budynkiem z towarem w rękach i nie zaczyna nowego cyklu (panel: „czeka: stos przy budynku jest pełny”). Stos widać na przednich kaflach budynku, a panel warsztatu pokazuje, co na nim leży.
- **Las:** drzewo spowalnia jak ściółka (1,5× wolniej), także posadzone na trawie. Leśniczy może sadzić tuż przy drodze (nie na niej). Skały dalej blokują przejście.
- **Chlew:** 3×3, stado do 12 świń. Przy 2 świniach nowa co 2 minuty, przy 6 co 40 s, przy 12 co 20 s (czas dzielony przez połowę stada). Stado rośnie tylko, gdy w chlewie pracuje świniarz. Ostatnie 2 świnie zostają. Świnie stojące w chlewie widać na jego przednich kaflach (1–4 świnie).
- **Rzeźnia:** rzeźnik prowadzi świnię z chlewu, rozbiera ją (6 s), odnosi 2 mięsa, potem oprawia skórę (4 s) i odnosi 1 skórę.
- **Ceny skupu** to ceny bazowe towarów z danych (np. drewno 2, deski 4, kamień 3, chleb 6, ryby 5, mięso 5, skóry 6, ubrania 12, miód pitny 12 złota). Świnia u kupca 30 złota, 4 na wizytę; nieodprowadzone do chlewu świnie kupiec oddaje w złocie przy odjeździe (czeka na nie do 2 minut).
- **Kupiec** pierwszy raz przyjeżdża w 10. minucie gry, potem co 10 minut. Stoi przed drzwiami targowiska, obok jego wozu. W starym zapisie przyjeżdża od razu po wczytaniu (gdy jest targowisko).
- **Kramy:** 6 sztuk każdego towaru, każdy towar na jednym kramie. Straganiarz bierze z magazynu 2 sztuki tego towaru, którego na kramach jest najmniej. Rezerwa „zapas na budowy” dotyczy też straganiarzy.
- **Okno „Zapasy królestwa”** (przycisk „Zapasy” na górnym pasku albo „Zapasy i handel” w panelu targowiska): zapas, + /min, − /min, bilans i sprzedaż kupcowi (zaznaczenie i liczba). Do zużycia liczy się też sprzedaż kupcowi i towar wbudowany w budowy.
- **Zapis w wersji 7.**

#### M4b-3 — Wozy, bruk, nowa mapa i duże miasto

**Start przed oceną M4b-2 (decyzja właściciela projektu 2026-11-05):** M4b-3 zaczynamy od razu, choć ocena gry M4b-2 na laptopie jeszcze czeka (lista „Do sprawdzenia przy ocenie gry” wyżej). M4b-2 zamkniemy po tej ocenie. Świadome ryzyko: jeśli w M4b-2 coś nie zagra (np. stos przy budynku, targ, kupiec), część M4b-3 może wymagać poprawek. Poprawki z oceny M4b-2 mają pierwszeństwo przed dalszą pracą nad M4b-3.

**Decyzje (2026-11-05, ankieta z właścicielem projektu):**
- **Wózek ręczny to sprzęt tragarza magazynu.** Gracz kupuje wózki w panelu magazynu za deski. Tragarz bierze wózek do zleceń od 2 sztuk i wiezie **3 sztuki**. Wózek jedzie wszędzie: na drodze tak szybko jak pieszy, poza drogą wolniej. Bez nowego budynku.
- **Wóz konny wymaga stajni.** Nowy budynek „stajnia” (drewno, deski, złoto) ma wozy, a każdy prowadzi **woźnica** (pracownik stajni). Wóz wiezie **6 sztuk** i jeździ **tylko po drogach** (ubitych i brukowanych). Koń jest „w cenie” stajni, bez hodowli. Konie jako towar (stadnina★) dojdą z wojskiem w M7.
- **Do czego jeżdżą wozy:** dyspozytor wysyła wóz do dużych zleceń tragarzy (od 4 sztuk, na dalsze trasy), wózek od 2 sztuk, a krótkie i drobne zostają pieszym. Duże zlecenia to: dostawy na budowy, odnoszenie stosów spod budynków do magazynu, ładunek na wóz kupca. Załadunek i rozładunek są widoczne (ok. 1 s na sztukę). Pracownicy warsztatów i domownicy dalej noszą sami.
- **Bruk kosztuje 1 kamień na kafel i układa go budowniczy.** Gracz rysuje bruk jak drogę, tragarze przynoszą kamień, a budowniczy układa kafel po kaflu (widoczna praca). Na bruku pieszy jest szybszy o 80% (droga ubita: 50%), a wóz po bruku jedzie szybciej niż po ubitej. Droga ubita zostaje darmowa i od razu.
- **Nowa mapa 128×128 obok dzisiejszej:** jezioro z trzcinami przy brzegu, rzeka wpadająca do jeziora, skaliste wzgórze i lasy. Jest na niej miejsce na miasto 400+ postaci. Jezioro działa jak rzeka (wędkarz, glinianka). Dzisiejsza mapa `riverlands`, stare zapisy i testy zostają bez zmian.
- **Kamienisty grunt i skały:** nowy teren „kamienisty grunt”. Da się po nim przejść (nieco wolniej), budować i kłaść drogi, ale nie da się siać pól. Na nim leżą skupiska skał dla kamieniołomu. Wybrana skała zostawia kamienisty grunt.
- **Duże miasto do testów to gotowy zapis.** Skrypt buduje na nowej mapie duże miasto (wszystkie łańcuchy, wozy, bruk, 400+ postaci) i zapisuje je jako fixturę. Na nim robimy test 2 godzin przy 4× i pomiar. Automatyczny gracz dalej sprawdza drogę od startu do patrycjuszy, ale nie musi dochodzić do 400 postaci.
- **Pomiar wydajności na razie tylko w chmurze:** czas ticku symulacji na dużym mieście (cel z ARCHITECTURE §9.1: ≤ 4 ms przy 500 postaciach). **Pomiar FPS na laptopie zrobimy w osobnej sesji**, gdy właściciel projektu będzie przy laptopie: scena pomiaru (60 s przy 4×, trzy poziomy zbliżenia, wynik w konsoli) i wpis do ARCHITECTURE §9.3. Do tego czasu ten punkt DoD zostaje otwarty.

**Część 2, decyzje (ankieta 2026-11-08, start części):**
- **Kolejność:** (A) mury, bramy, baszty i schody w rozgrywce; (B) chodzenie po murach i sterowanie jak w Twierdzy; (C) walka, łucznicy na murach, taran i drabiny; (D) bandyci, ucieczka cywilów, przejęcie przez drzwi ratusza, zapis. Ocena po całej części. Zdobywanie osady neutralnej siłą (marsz armii) w części 3.
- **Grafika:** mur i wieża bramna z prototypu (kamień z PixelLab z początku projektu, `src/prototype/walls/pixellab/`), reszta (baszta, schody, palisada, taran, drabina, warsztat oblężniczy) rysowana kodem.
- **Bandyci po rozbiciu drzwi ratusza bez obrońców: łupią i odchodzą** (część złota i towarów z magazynu, zadowolenie −30 przez 10 minut). Prowincja zostaje graczowi. Pełne przejęcie prowincji jest w kodzie i testach na część 3 i M8.
- **Taran i drabiny: nowy warsztat oblężniczy** (budynek w kategorii „Wojsko”, grafika kodem). Bandyci przynoszą własne drabiny, taran tylko przy rzadkim większym napadzie.
- **Napady rzadkie, z ochroną:** pierwszy po ok. 40 minutach gry, potem co 25–40 minut, 4–8 bandytów, ostrzeżenie 60 s wcześniej; przycisk „napad teraz” w menu narzędzi.

**Część 3, plan i decyzje (ankieta 2026-11-08, start części):**
- **Wymarsz:** gracz zaznacza żołnierzy w mieście i klika „Wymarsz” w panelu wojska. Żołnierze idą do krawędzi mapy (albo do okrętu wojennego) i znikają z niej; na mapie świata powstaje armia, która stoi przy mieście. Cel wskazuje się jak przy wyprawach: klik na armię, prawy przycisk na prowincję (zielona linia: można, czerwona: nie). Lądem armia idzie przez kolejnych sąsiadów, morzem płynie tylko okrętem wojennym.
- **Armia na mapie świata:** rodzaje i życie żołnierzy, zapas chleba (1 na 10 żołnierzy na minutę, ze sobą bierze na 10 minut, w prowincjach gracza uzupełnia z magazynu); bez jedzenia walczy słabiej (−30% w rozstrzyganiu). Armia, która wejdzie do swojej prowincji z koszarami, wraca do koszar (jeśli jest miejsce), inaczej stoi przy mieście.
- **Osada neutralna:** armia czeka przy granicy (jak wyprawa). W panelu dwa przyciski: „Wejdź i walcz” (walka na żywo w widoku prowincji: armia wchodzi od krawędzi, straż broni murów i ratusza) i „Rozstrzygnij automatycznie” (od razu wynik i raport; przed kliknięciem widać szanse). Wygrana: rozbite drzwi ratusza i brak straży przy nich → osada przechodzi do gracza z mieszkańcami i budynkami, zadowolenie −30 przez 10 minut. Przegrana: ocaleni wracają przed granicę.
- **Obrona osad:** Żelazny Gród ma mur kamienny wokół centrum z wieżą bramną i 2 basztami oraz 14 strażników (włócznicy i łucznicy); Końska Przystań palisadę z bramą i 8 strażników. Mury powstają z danych osady razem z miasteczkiem.
- **Obóz bandytów na mapie świata:** obóz w pustej prowincji (w „Królestwie”: Lustrzane Jeziora). Napady wychodzą z niego jako armia bandytów, widoczna na mapie, i idą do prowincji gracza. Armia gracza stojąca w tej prowincji przechwytuje je (bitwa polowa, rozstrzygana automatycznie). Napad na prowincję oglądaną toczy się na żywo jak w części 2; na nieoglądaną rozstrzyga automat (żołnierze w koszarach, mury i bramy). Armia gracza może rozbić obóz (bitwa polowa); obóz odradza się po 30 minutach w innej pustej prowincji, a łup z obozu wraca do gracza. Do prowincji z obozem nie można wysłać wyprawy. W grze na jednej mapie (bez świata) napady zostają jak w części 2.
- **`BattleResolver`:** czysta funkcja (armia A, armia B, rodzaj: polowa, morska albo oblężenie, mury, machiny, zaopatrzenie, losowość) → zwycięzca, straty i raport w kolejnych etapach (ostrzał, podejście pod mury, szturm, walka wręcz). Tabela testów w `tests/unit/test_battle_resolver.gd`.
- **Okręt wojenny:** stocznia buduje go w 4 etapach jak kogę (więcej desek i smoły, grafika kodem jak koga), wiezie do 30 żołnierzy; armia z okrętem płynie między wybrzeżami i ląduje na plaży. Bitwy morskie rozstrzyga automat (w M7 nie ma jeszcze wrogich flot, więc sprawdzają je testy; prawdziwe floty przeciwnika w M8).
- **Kolejność prac:** (A) `BattleResolver` z tabelą testów; (B) armia na mapie świata (wymarsz, ruch, powrót do koszar, jedzenie), zapis v20; (C) mury i straż osad, oblężenie z wyborem „na żywo” albo „automatycznie”, przejęcie; (D) obóz bandytów, napady jako armie, bitwy polowe; (E) okręt wojenny; (F) mapa świata: armie, panele, raport bitwy, zrzuty.

**Część 3, stan (2026-11-08): gotowa, scalona do `main` 2026-11-08 przed oceną (decyzja właściciela: przetestuje na laptopie).**
- **`BattleResolver` (A):** rundy po 5 s; ostrzał, podejście pod mury (taran przy bramie, drabiny na murze kamiennym, rąbanie palisady albo muru), walka wręcz, morska z balistami okrętów (800 życia, bełt 30 co 4 s); obrońca na murach dostaje połowę strzał i strzela 2 rundy wcześniej; ucieczka poniżej 25% ludzi; głodna armia −30%. Szanse = 20 rozstrzygnięć. Tabela testów: `tests/unit/sim/military/test_battle_resolver.gd`.
- **Armia (B):** „Wymarsz” w panelu wojska (zaznaczeni żołnierze idą do najbliższej krawędzi mapy i schodzą z niej); armia stoi przy mieście na mapie świata, idzie przez kolejnych sąsiadów (prędkość pieszych 1,1 jednostki mapy na sekundę, ok. 3–4 min na sąsiada), w prowincjach gracza dobiera chleb (ryby, mięso) z magazynów; w swojej prowincji z koszarami wraca do nich (przycisk „Do koszar”, przy dojściu sama). Zbyt mało miejsc: reszta zostaje armią.
- **Osady (C):** Żelazny Gród: mur kamienny wokół centrum (ok. 110 kafli), wieża bramna od strony wolnego pola, 2 baszty, 8 włóczników i 6 łuczników (łucznicy na murze przy bramie, włócznicy przy bramie i ratuszu); Końska Przystań: palisada z bramą w palisadzie, 5 włóczników i 3 łuczników. Pierścień muru to zewnętrzna krawędź centrum (budynki do 11 kafli od ratusza z 2 kaflami wolnego pola), drzewa, drogi i pola pod murem znikają. Armia czeka u granic; „Wejdź i walcz” albo „Rozstrzygnij automatycznie (szanse: N%)”. W widoku osady prawy przycisk na murze, bramie albo ratuszu wroga to „rozbij” (żołnierz idzie na to, co stoi na drodze, i dalej do celu; tłum rozstawia się wokół); „Odwrót” zabiera żołnierzy do granicy. Przejęcie jak przy napadzie: rozbite drzwi ratusza, brak strażników przy nich → osada gracza, zadowolenie −30 przez 10 minut, reszta straży składa broń, drzwi naprawione.
- **Bandyci (D):** obóz (9 ludzi) w Lustrzanych Jeziorach; napady wychodzą z niego na najbliższą (lądem) prowincję gracza z ratuszem, poza czasem ochronnym: 40 minut, potem co 25–40 minut, 4–8 ludzi, drabiniarze i taran jak w części 2. Napad widać na mapie i w powiadomieniu (ile minut drogi); minutę przed dojściem oglądana prowincja dostaje ostrzeżenie i walczy na żywo; nieoglądana: `BattleResolver` (żołnierze koszar, mury), łup do obozu. Armia gracza stojąca w prowincji, przez którą idą, walczy z nimi w polu. Rozbity obóz oddaje łup i wraca po 30 minutach w innej pustej prowincji (nie na wyspie). W grze na jednej mapie napady jak w części 2.
- **Okręt wojenny (E):** stocznia (32 deski, 10 smoły, 6 sukna, 4 etapy, 6 min), po wodowaniu kotwiczy w głębokiej wodzie. Armia płynie morzem, gdy w jej prowincji są okręty z miejscem dla wszystkich (30 na okręt), a morze jest szybsze albo jedyne (wyspy); ląduje na plaży, okręty wracają do portu od razu (jak koga wyprawy). Bitwa morska, gdy spotkają się dwie floty (w M7 wrogich flot nie ma).
- **Mapa świata (F):** armie pod chorągwiami z liczbą żołnierzy, obóz bandytów, droga przez prowincje; panel armii (żołnierze, chleb, dokąd i ile minut, przyciski), raport ostatniej bitwy w panelu prowincji, powiadomienia o napadach i bitwach.
- **Walka (poprawki przy okazji):** żołnierz nie wybiera wroga, do którego nie da się dojść (za murem, na murze bez schodów), a nieosiągalnego zostawia na 5 s; rozkaz „rozbij” bez drogi do celu bierze przeszkodę po drodze.
- **Brama w palisadzie (prośba właściciela 2026-11-08):** drewniane wrota na 1 kafel w linii palisady (6 drewna, 4 deski, 600 życia, zakładka „Obrona”); swoi przechodzą, wróg ją rozbija, na górę się nie wchodzi. Końska Przystań ma taką bramę zamiast wieży bramnej. Grafika kodem: `xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 -s res://tools/render_palisade_gate.gd`.
- Zapis v20 (ARCHITECTURE §8). Testy: `tests/scenario/test_m7_armies.gd` (11), `tests/unit/sim/military/test_battle_resolver.gd`.
- Zrzuty: mapa świata `world_shot.tscn -- --out=<plik> --armies`, oblężenie `game_shot.tscn -- --world --m7=siege --zoom=2 --raid_seconds=60 [--siege=horse_haven]`. Grafika okrętu: `python3 tools/render_cog.py warship 168,40,36 --war [--stages]`.
- **Świadomie uproszczone:** wsiadanie na okręt i powrót okrętu nie są widoczne (okręt znika z mapy i wraca od razu), armia przenosi tylko liczbę żołnierzy (rany się goją w drodze), łup bandytów to tylko złoto (towary przepadają), straż osady stoi przy swoich miejscach (nie robi wypadów), w trybie uproszczonym napad liczy się tylko na żołnierzy w koszarach i mury, balans (Żelazny Gród pada szturmem 30 ludzi z taranem w ok. 1,5 minuty) do oceny na laptopie.

**Wartości wyjściowe (do strojenia przy realizacji):**
- wózek: 3 sztuki, 3 deski za wózek, najwyżej 2 wózki na magazyn (po jednym na tragarza), poza drogą 0,7× szybkości pieszego, na drodze 1×,
- wóz: 6 sztuk, 1,3× szybkości pieszego na tej samej drodze, stajnia 3×3 z 2 wozami i 2 woźnicami, koszt np. 12 drewna, 8 desek, 40 złota,
- bruk: koszt ruchu 0,55 (+80%), ułożenie kafla ok. 3 s pracy budowniczego,
- kamienisty grunt: koszt ruchu 1,2.

**Kolejność prac:** część 1 (transport: bruk, wózki, stajnia i wozy, sprawdzona testami przed resztą), część 2 (nowa mapa: jezioro, kamienisty grunt, skały, wybór mapy przy nowej grze), część 3 (duże miasto: skrypt zapisu, test 2 godzin, pomiar ticku i poprawki wydajności). Jedna ocena gry na końcu etapu.

**Zakres:**
- część 1: pojemność i szybkość nośnika (pieszy 1, wózek 3, wóz 6) w zleceniach `JobBoard`, dyspozytor wybierający nośnik według liczby sztuk i długości trasy, wozy tylko po drogach (osobna siatka ruchu albo koszt „poza drogą = zablokowane”); gdy cel nie ma drogi pod drzwiami, zlecenie biorą piesi; widoczny załadunek i rozładunek; wózki kupowane w panelu magazynu; stajnia z woźnicami, postój wozów przy stajni; bruk jako zlecenie budowy (kamień, budowniczy, kafel po kaflu; do ułożenia kafel działa jak droga ubita), rysowanie bruku w menu dróg,
- część 2: nowa mapa 128×128 (jezioro z trzcinami, rzeka, skaliste wzgórze, lasy, start ratusza), teren „kamienisty grunt” (przechodni, bez pól), skupiska skał, wybór mapy przy nowej grze (menu),
- część 3: skrypt budujący duże miasto 400+ postaci na nowej mapie i zapisujący fixturę, test 2 godzin przy 4× bez zakleszczeń, pomiar czasu ticku w chmurze; jeśli cel nie jest spełniony, środki z ARCHITECTURE §9.2 od najtańszych (np. pamięć tras budynek → magazyn),
- grafika rysowana kodem: tragarz z wózkiem (8 kierunków, pusty i z ładunkiem), wóz konny z woźnicą (8 kierunków), stajnia, kafle bruku łączone jak droga, brzeg jeziora z trzcinami, kamienisty grunt, skupiska skał,
- zapis: wersja 8 z migracją, fixturą i testem (wózki, wozy, place brukowania, mapa); teksty PL i EN; aktualizacja GDD §2.2, §5.2, §5.5, ARCHITECTURE §5.2, §5.3, §9.3 i ART_SPEC.

**Poza zakresem:** przewozy między magazynami sterowane przez gracza („trzymaj tu N sztuk”), konie jako towar i stadnina (M7), wozy dla pracowników warsztatów i domowników, klify i poziomy terenu (IDEAS), mosty, szlaki handlowe między prowincjami (M6), pomiar FPS na laptopie (osobna sesja, patrz wyżej).

**DoD:**
- [x] Tragarz z wózkiem wiezie 3 sztuki, wóz 6 sztuk tylko po drogach; dyspozytor daje drobne i krótkie zlecenia pieszym, a duże wozom i wózkom; przy celu bez drogi wóz nie dostaje zlecenia (`tests/unit/sim/economy/test_handcarts.gd`, `test_wagons.gd`).
- [x] Bruk kosztuje 1 kamień na kafel, układa go budowniczy, a pieszy i wóz jadą po nim szybciej niż po drodze ubitej (`tests/unit/sim/test_paving.gd`: budowniczy układa kafle z kamieniem z magazynu, bruk 1,2× szybszy od drogi ubitej).
- [x] Stajnia z woźnicami działa w grze: wozy wożą na budowy, odnoszą stosy i ładują wóz kupca (`tests/scenario/test_m4b3_chains.gd`: 10 sztuk na budowę, 10 drewna ze stosu, 22 z 24 desek na wóz kupca).
- [x] Nowa mapa 128×128 z jeziorem i kamienistym gruntem: wędkarz i glinianka działają nad jeziorem, na kamienistym gruncie nie da się postawić pola, kamieniołom pracuje przy skałach (`tests/unit/sim/test_lakeland.gd`). Automatyczny gracz dochodzi na niej do 4 kamienic patrycjuszy w **77. minucie** (limit 90, `test_slice_dod.gd`).
- [x] Duże miasto (400+ postaci, gotowy zapis): brak zakleszczeń przez 2 godziny przy 4× (`tests/long/test_big_city.gd` na fixturze `big_city.json` ze skryptu `tools/build_big_city.gd`: 412 budynków, średnio 436 postaci, 324–580; wszystkie łańcuchy produkują do końca).
- [x] Wydajność według ARCHITECTURE §9.1: czas ticku ≤ 4 ms przy 500 postaciach (pomiar w chmurze, wynik w §9.3): 3,5–3,8 ms przy 460–480 postaciach, średnio 3,6 ms przez 2 h; przed poprawkami 50 ms.
- [x] Pomiar FPS na laptopie na dużym mieście (2026-11-07, `src/prototype/m4b3/fps_bench.tscn`, wynik w ARCHITECTURE §9.3): średnio 130–215 FPS przy 4×, ale zacięcia ok. 80–95 ms mniej więcej raz na sekundę przy 4× (poprawka niżej).
- [x] Automatyczny gracz na mapie `riverlands` dalej dochodzi do patrycjuszy w limicie (`test_slice_dod.gd`: 78. minuta po poprawkach wydajności, „Pojezierze” 77.).
- [x] Zapis z M4b-2 wczytuje się po migracji (v7 → v8) bez utraty towaru, nowa fixtura `v8_town.json` (`test_save_round_trip.gd`). Jeśli część 2 albo 3 zmieni format, fixturę v8 wygenerujemy od nowa (wersja 8 nie trafiła jeszcze do gry na `main`).
- [ ] UI w PL i EN, nowe teksty przez klucze tłumaczeń.
- [x] **Twoja ocena gry:** 5/5 (2026-11-07, ankieta na laptopie). Zamyka też całe M4b (DoD M4b wyżej). Wnioski w GDD §11.1.

**Poprawki z oceny (2026-11-07, mają pierwszeństwo przed M7):**
- [x] **Zacięcia symulacji:** na dużym mieście co kilka sekund gry jeden tick trwa ok. 80 ms (przy 4× zacięcie ok. raz na sekundę, ARCHITECTURE §9.3). Znaleźć i rozłożyć ten koszt. **Zrobione (paczka 1):** źródłem był zasięg usług liczony od zera po każdej wybranej skale w mieście; teraz zmiana jest doliczana na miejscu (ARCHITECTURE §9.3, „Poprawka zacięć”). Drugie źródło było w widoku: przy każdej zmianie budynku gra sprawdzała na dysku pliki wyglądu wszystkich 400 budynków, a grafiki postaci wczytywały się przy pierwszym pokazaniu. Pomiar FPS na laptopie po poprawkach: **0 klatek ponad 33 ms**, najgorsza klatka 13 ms przy 4× (było 83–97 ms).
- [x] **Zacięcia przy stawianiu budynku usługowego** (kaplica, studnia): podgląd zasięgu przelicza się przy każdym ruchu myszy. Do sprawdzenia i poprawki (np. liczyć raz na kafel albo rzadziej). **Zrobione (paczka 1):** podgląd liczył się już tylko przy zmianie kafla, ale za każdym razem budował i rysował od nowa zasięg wszystkich stojących budynków; teraz to osobna warstwa przeliczana tylko po zmianie zasięgu, a przy ruchu myszy liczy się tylko zasięg nowego budynku. Zasięgi się nakładają, więc kafle w zasięgu starego i nowego budynku są nieco ciemniejsze.
- [x] **Znacznik zaplanowanego bruku:** wyraźnie widać, które kafle czekają na bruk, i da się taki plan anulować. **Zrobione (paczka 1, ankieta 2026-11-07: oba sposoby):** kafel czekający na bruk ma przerywaną jasną ramkę z kamyczkami (następny kafel budowniczego ma ramkę złotą). Anulowanie: z narzędziem „Bruk” przeciągnięcie **prawym** przyciskiem po zaplanowanych kaflach albo „Rozbiórka” (klik albo przeciągnięcie zaczęte na zaplanowanym kaflu). Droga zostaje ubita, przyniesiony kamień zostaje w placu brukowania, a gdy nie ma już nic do ułożenia, ląduje na ziemi.
- [x] **Animacja obracających się kół** przy wózkach i wozach. **Zrobione (paczka 2):** wózek, wóz i wóz kupiecki mają po 4 klatki z obróconymi szprychami; koła kręcą się, gdy tragarz albo woźnica idzie, a stoją przy ładowaniu. Zrzut: `game_shot.tscn -- --tile=56,50 --zoom=3 --roads --paved --carts`.
- [x] **Tekstury wody i kamienistego gruntu:** warianty kafli losowane na mapie, żeby wzór się nie powtarzał (jezioro, kamienisty grunt); kamienisty grunt bez szwów; łagodne przejścia między wodą rzeki a jeziorem i między wodą rzeki a morzem. **Zrobione (paczka 3, ankieta 2026-11-07: rysowane kodem, rozsypane kamienie, duży wzór i 3 warianty):** jezioro i ziemia kamienistego gruntu powtarzają się dopiero co 4×4 kafle i mają po 3 warianty mieszane w miękkie plamy (`python3 tools/generate_terrain_variants.py`; PixelLab nie ma narzędzia do tekstur bez szwów, sprawdzone w dokumentacji i pomocy). Kamienie są wycięte w całości z kafli PixelLab i leżą na ziemi w dwóch przezroczystych warstwach powtarzających się co 5 i co 7 kafli, więc żaden kamień nie jest ucięty. Woda rzeki miesza się z jeziorem i z morzem w szerokim pasie (ok. 1,5 kafla w każdą stronę) wzorem pikseli, każda woda płynie po swojemu. Przy okazji: odblaski na wodzie nie układają się już w pionowe kolumny kropek. Zrzuty: `game_shot.tscn -- --map=lakeland --tile=72,40 --zoom=2` (rzeka i jezioro), `--map=lakeland --tile=44,98 --zoom=3` (kamienisty grunt), `--map=coast --tile=74,68 --zoom=2` (ujście do morza).

**Ustalone przy realizacji części 1 (2026-11-05, do zmiany na prośbę):**
- **Grafika bruku z PixelLab:** kafel 14 („cobblestone pavement”) z zestawu kafli terenu właściciela (`Flat isometric ground texture tiles…`), z wyrównanymi krawędziami jak reszta terenu; wariant `b` to lustro `a`.
- **Bruk:** gracz przeciąga narzędzie „Bruk” po drodze albo po wolnym terenie (wolny teren od razu staje się drogą ubitą). Jedno przeciągnięcie to jeden plac brukowania; tragarze kładą kamień przy kaflu, który budowniczy układa jako następny. Budowniczy bierze bruk dopiero wtedy, gdy żadna budowa go nie potrzebuje; po każdym kaflu (3 s) sprawdza, czy nie pojawiła się budowa. Usunięcie drogi z zamówionego kafla zmniejsza zamówienie, a niepotrzebny kamień ląduje na ziemi.
- **Wózki:** kupione wózki należą do magazynu, każdy tragarz tego magazynu może wziąć jeden. Wózek zostaje przy tragarzu, dopóki ten ma towar (także gdy odkłada go po nieudanym kursie). Tragarze ratusza nie mają wózków.
- **Wozy:** woźnica wyjeżdża tylko ze stajni (wóz czeka w stajni) albo jedzie dalej z miejsca poprzedniego kursu. Między kursami odstawia wóz pod stajnię i wchodzi do środka; nowy kurs może mu przerwać powrót. Ładuje i rozładowuje na drodze przed tymi drzwiami budynku, przed którymi jest droga. Żywe zwierzęta (świnie) nie jadą wozem. Woźnica idzie przodem i prowadzi konia za uzdę (grafika).
- **Ładowanie** wózka i wozu ma animację „schyla się i ładuje” (tragarz i woźnica).

**Ustalone przy realizacji części 3 (2026-11-06, do zmiany na prośbę):**
- **Ankieta z właścicielem (2026-11-06):** koga, która przywiozła osadników, po wyładunku odpływa (własną kogę buduje stocznia); koga gracza czeka na kotwicy w zatoce i podpływa do nabrzeża tylko na załadunek i rozładunek (kupiec morski dalej może przypływać); zamówienie płaci „sakiewka” zabrana ze skarbca przy wypłynięciu; 3 osadników bez zawodu nosi towar jak tragarze, dopóki nie stanie chata.
- **Obóz pionierów zamiast ratusza na start** (pomysł właściciela, ankieta 2026-11-06): budynek 3×3 za 10 drewna, budowniczy i 2 tragarzy, ustawianie podatków; najwyżej jeden na prowincję, w menu (zakładka magazynów) na każdej mapie. Na „Wybrzeżu” do jego postawienia menu ma tylko obóz, a inne budynki dają „Najpierw postaw obóz pionierów”. Ratusz na razie bez zmian; przesunięcie go na później z nowymi funkcjami i dom budowniczych: IDEAS.
- **Etapy kogi mają własne koszty:** szkielet 8 desek, poszycie 10 desek i 4 smoły, maszt z żaglem 2 deski i 4 sukna, wodowanie 2 smoły (razem jak w planie: 20 desek, 6 smoły, 4 sukna); każdy etap 60 s pracy cieśli. Przy wodowaniu kadłub zjeżdża z pochylni na wodę. Koga jest dłuższa od pochylni (ok. 3,7 kafla wobec 2), więc leży rufą przy brzegowym końcu pochylni, dziobem nad wodą, i rysuje się przed całą stocznią (uwaga właściciela 2026-11-06: warsztat zasłaniał rufę).
- **Jedna koga na port.** Nowa koga szuka najbliższego portu bez kogi; bez portu czeka na kotwicy przy stoczni. Kotwicowisko: najbliższa głęboka woda co najmniej 3 kafle od miejsca cumowania, poza torem wodnym.
- **Plan rejsu** w panelu portu: towary na sprzedaż i zamówienie po 5 sztuk, każda lista mieści się w ładowni (4 miejsca po 10 sztuk). Sprzedać można każdy towar z ceną, oprócz żywych zwierząt. Zamówić można to, co sprzedaje kupiec morski (deski, smoła, sukno), po jego cenie (+50%).
- **Załadunek kończy się sam**, gdy plan jest na pokładzie albo w królestwie nie ma już tego towaru; przycisk „Odpłyń teraz” wysyła kogę z tym, co ma. Za horyzontem koga jest 270 s (z drogą do krawędzi i z powrotem ok. 6 minut na „Wybrzeżu”). Złoto ze sprzedaży wpływa po powrocie do nabrzeża; nadwyżka sakiewki nie powstaje, bo zamówienie jest liczone przy wypłynięciu (najwyżej tyle, na ile starcza złota).
- **Start ze statku:** koga wpływa z najbliższej krawędzi morza i rzuca kotwicę w zatoce (73, 74), osadnicy co 2 s brodzą do plaży (70, 74). Zestaw startowy: **90 drewna i 20 chleba** (obóz 10, magazyn 8, 3 chaty 12, reszta jak zapas startowy innych map; przy 50 drewna automatyczny gracz grzązł). Leży jako kupy po jednym stosie na kafel obok plaży. Obóz bierze budowniczego i 2 tragarzy z osadników (mieszkają w obozie); pozostali wprowadzają się do pierwszych chat. Kamera startuje nad plażą.
- **Automatyczny gracz na „Wybrzeżu”** ma własne poprawki planu (tylko na tej mapie, inne mapy grają jak dotąd): obóz i magazyn przy stosie na plaży, miasto 12 kafli w głąb lądu, drwale przy południowym lesie, łańcuch chleba, rybacy, browary i cegły po stronie miasta (rzeka dzieli mapę), dodatkowe pola, młyn, piekarnia, chmielnik, browar, 4 chaty i studnia, magazyn przy polach (rolnik nosi każdy snop do magazynu: przy magazynie o 17 kafli dalej zbierał o połowę mniej). Miejsca wymagające dużego objazdu (bród) są pomijane. Wynik: 4 zaopatrzone kamienice patrycjuszy w 73. minucie (Nadrzecze 70., Pojezierze 79.). Ta sama mapa ze starym startem (ratusz) i planem z „Nadrzecza” nie dochodziła nawet do mieszczan, więc wniosek dla oceny gry: na „Wybrzeżu” las jest daleko od plaży, a rzeka odcina wschód.

**Ustalone przy realizacji części 2 (2026-11-06, do zmiany na prośbę):**
- **Grafika terenu z PixelLab** (prośba właściciela): kamienisty grunt i woda jeziora z nowej paczki kafli w stylu pierwszego zestawu. W tej samej paczce powstały kafle na później (spękana skała, żwir, bagno, glina, ściernisko, lód, torf; lista w ART_SPEC §3). Trzcin i skał nie było w grafikach właściciela, więc trzciny rysuje kod, a skały to dotychczasowe skały z kodu.
- **Mapa „Pojezierze”:** jezioro na północnym wschodzie, rzeka z północy wpada do jeziora (2 brody), kamieniste wzgórze ze skupiskami skał na południowym zachodzie i mała grupa skał blisko miasta, lasy przy krawędziach i zagajnik obok miasta. Osadnicy przychodzą z zachodniej krawędzi. Start jak na „Nadrzeczu” (ratusz, magazyn, 3 chaty).
- **Kamienisty grunt:** koszt ruchu 1,2. Wydobyta skała zostawia kamienisty grunt także na „Nadrzeczu”.
- **Jezioro** to osobny teren (`lake`), który dla budynków liczy się jak woda. Woda w jeziorze płynie wolniej niż w rzece. Trzciny rosną na ok. 70% kafli jeziora przy brzegu.
- **Menu:** zamiast jednego przycisku „Nowa gra” jest „Nowa gra: Nadrzecze” i „Nowa gra: Pojezierze”.
- **Automatyczny gracz** przesuwa budynek do najbliższych skał, drzew albo wody, gdy w zasięgu miejsca z planu ich nie ma (na „Nadrzeczu” nic się nie zmienia).

**Scalenie przed oceną (decyzja właściciela projektu 2026-11-06):** M4b-3 (części 1–3) trafia do `main` przed oceną gry. Ocena M4b-3 i M4b-2 oraz pomiar FPS na laptopie są odłożone na później; do tego czasu oba etapy zostają otwarte, a poprawki z oceny mają pierwszeństwo.

**Ustalone przy realizacji części 3 (2026-11-06, do zmiany na prośbę):**
- **Duże miasto** buduje skrypt (`tools/build_big_city.gd`, układ w `tests/support/big_city.gd`): siatka ulic z brukowanymi głównymi ulicami, gotowe budynki w dzielnicach, domy od razu zamieszkane (54 chaty, 31 domów mieszczan, 24 kamienice), zapasy w magazynach, wózki w magazynach, 6 świń w każdym chlewie, kupiec skupuje nadwyżki. Potem 5 minut gry (ludzie idą do pracy) i zapis. Młyny, piekarnie i browary stoją przy magazynach obok pól, bo warsztaty same chodzą po surowce: przy dalekim magazynie pracowały 2–3× wolniej. Miasto rośnie samo: po godzinie ma ok. 1150 mieszkańców.
- **Postacie** to pracownicy, tragarze, woźnice i domownicy w drodze (GDD §3.4), więc ich liczba faluje: średnio 436 w ciągu 2 godzin, od 324 do 580. Test sprawdza średnią ≥ 400 i minimum ≥ 300.
- **Drzewa nie skracają zasięgu usług** (studnia, kościół, targ, tawerna; GDD §5.2). Drogi, bruk, pola i teren dalej się liczą. Powód: wydajność, każda ścinka przy mieście przeliczała kilka zasięgów.
- **Pracownik bez pracy w zasięgu** (brak drzew, skał, miejsca na sadzonkę) szuka ponownie co 10 s, a nie co 3 s. Zlecenie tragarzy bez towaru albo miejsca wraca po 2 s.
- **Domy sprawdzane w różnych tickach sekundy** (według id), każdy dalej raz na sekundę. Nowi osadnicy wybierają dom w ostatnim ticku sekundy.

---

## M5 — Woda, porty i statki

**Status: plan zaakceptowany 2026-11-06. Część 1 (morze i ryby) gotowa i zaakceptowana przez właściciela 2026-11-06, scalona do `main`. Część 2 (port i kupiec morski) gotowa i zaakceptowana przez właściciela 2026-11-06, scalona do `main`. Część 3 (koga gracza, rejsy, start ze statku, obóz pionierów) gotowa 2026-11-06 i scalona do `main` przed oceną (decyzja właściciela). Ocena gry M5 odłożona: właściciel testuje ją razem z zaległymi ocenami M4b-2 i M4b-3; do tej oceny etap jest formalnie otwarty.** Poprawki z odłożonej oceny M4b-2 i M4b-3 (oraz pomiar FPS na laptopie) mają pierwszeństwo przed dalszą pracą nad M5.

**Decyzje (2026-11-06, ankieta z właścicielem projektu):**
- **Nowa mapa „Wybrzeże” 128×128 obok dzisiejszych.** Morze z jednej strony mapy, plaża, osłonięta zatoka na port, rzeka wpadająca do morza, lasy i skały. „Nadrzecze” i „Pojezierze”, stare zapisy, testy i duże miasto z M4b-3 zostają bez zmian. Wyspy czekają na M6.
- **Statki w M5: łódź rybacka i koga.** Reszta drzewka okrętów (karawela, karaka, wielki okręt z balistami; IDEAS) później. Kogę budujemy na bazie prototypu z `src/prototype/ships/`.
- **Przystań rybacka obok wędkarza.** Wędkarz zostaje bez zmian (tani, na start; łowi też z brzegu morza). Nowy budynek „przystań rybacka” stoi na brzegu morza i ma rybaka z łodzią: łódź wypływa na ławicę ryb, łowi siecią i wraca z większym połowem. Łódź buduje stocznia. Przystań tylko nad morzem (nie nad jeziorem ani rzeką).
- **Kupiec morski.** Obca koga co jakiś czas przypływa zza krawędzi morza do portu. Portowcy noszą na nią nadwyżki i zdejmują towary, które gracz kupuje. Działa jak kupiec z wozem (M4b-2), tylko przez port. Kupiec z wozem przyjeżdża dalej.
- **Własna koga: rejsy handlowe za horyzont.** Gracz w panelu portu wybiera towary i ilości, portowcy ładują kogę, a ta odpływa za krawędź mapy i po kilku minutach wraca ze złotem i z towarami zamówionymi z oferty kupca morskiego. W M6 ten sam rejs popłynie do innej prowincji.
- **Prosty start ze statku na „Wybrzeżu”** (scenariusz kolonizacji, IDEAS). Gra na tej mapie zaczyna się od kogi, która przypływa do plaży i wyładowuje osadników z zestawem startowym. Gracz sam stawia ratusz. Kolonizacja kolejnych prowincji przychodzi w M6.
- **Statki z desek, smoły i sukna** (GDD §5.4). Nowa smolarnia: drewno → smoła. Sukno na żagle już mamy (M4b-1).

**Wartości wyjściowe (do strojenia przy realizacji):**
- mapa: morze zajmuje ok. ¼ mapy, przy brzegu pas płytkiej wody 2–3 kafle, potem woda głęboka; plaża z piasku; morze liczy się jako woda dla wędkarza i glinianki (jak jezioro),
- smolarnia 2×2: smolarz bierze 2 drewna, pali w dole smolnym (dym), po ok. 40 s odnosi 1 beczkę smoły,
- stocznia: 4×3 na brzegu z pochylnią wchodzącą do wody, 1 cieśla okrętowy, koszt np. 20 drewna, 10 desek, 30 złota; gracz zamawia statek w panelu stoczni (kolejka),
- łódź rybacka: 6 desek, 2 smoły; ok. 1 min pracy; pływa po wodzie płytkiej i głębokiej, 1,5 kafla/s,
- koga: 20 desek, 6 smoły, 4 sukna; ok. 4 min pracy w 4 etapach (szkielet, poszycie, maszt z żaglem, wodowanie); tylko woda głęboka (płytką przy porcie i pochylni traktujemy jak tor wodny), 1,2 kafla/s; ładownia 40 sztuk,
- przystań rybacka 2×2 z pomostem, 1 rybak, 1 łódź; połów 4 ryby na kurs (wędkarz: 1), ok. 20 s łowienia; ławica ma 12 ryb i odnawia 1 rybę na 30 s; ławice widać na wodzie (pluski, mewy),
- port: 4×3, z czego nabrzeże na wodzie; plac portowy na 6 pól (jak mały magazyn), 2 portowców, 1 miejsce cumowania; załadunek po trapie, ok. 1 s na sztukę,
- kupiec morski: co ok. 12 min gry, stoi do 4 min; kupuje do 40 sztuk nadwyżek po cenie bazowej (progi z okna „Zapasy królestwa”, jak kupiec z wozem); sprzedaje kilka towarów (np. smoła, sukno, deski) w ograniczonej ilości, gdy zapas spadnie poniżej progu „kupuj do N” ustawionego przez gracza w tym samym oknie,
- rejs własnej kogi: ok. 6 min gry tam i z powrotem, sprzedaż po cenie bazowej +25%, zamówione towary po cenie kupca morskiego,
- start ze statku: 6 osadników (w tym budowniczy i 2 tragarzy), zestaw startowy na plaży jako wspólny stos (materiały na ratusz, magazyn i 3 chaty plus zapas żywności); do postawienia ratusza menu budowy ma tylko ratusz.

**Kolejność prac:** część 1 (morze i ryby: mapa „Wybrzeże”, wodna siatka ruchu, smolarnia, stocznia budująca łódź, przystań rybacka z ławicami, sprawdzone testami przed resztą), część 2 (port i kupiec morski: port z portowcami, cumowanie, załadunek sztuka po sztuce, obca koga), część 3 (koga gracza i start: budowa kogi w etapach do wodowania, rejsy za horyzont, start ze statku, zapis). Jedna ocena gry na końcu etapu.

**Zakres:**
- część 1: mapa „Wybrzeże” 128×128 (morze płytkie i głębokie, plaża, zatoka, rzeka do morza, lasy, skały, wybór w menu); nowe tereny `sea_shallow`, `sea_deep`, `sand`; wodna siatka ruchu (`NavGrid` dla wody, ARCHITECTURE §5.3) z osobnymi zasadami dla łodzi i kogi; statek jako jednostka symulacji z ładownią (`ShipUnit`, ARCHITECTURE §10, na razie bez walki); budynki częściowo na wodzie (nowa reguła stawiania: część kafli musi być wodą, wejście od lądu); towar smoła i smolarnia; stocznia z kolejką zamówień, dostawami materiałów przez tragarzy i budową łodzi; przystań rybacka, ławice ryb jako złoża na wodzie,
- część 2: port z placem portowym i portowcami; cumowanie (rezerwacja miejsca przy nabrzeżu); zlecenia „załaduj statek” i „rozładuj statek” na `JobBoard`, sztuka po sztuce po trapie; panel statku z ładownią czytaną ze stanu symulacji; kupiec morski (przypływa zza krawędzi, cumuje, kupuje i sprzedaje, odpływa); próg „kupuj do N” w oknie „Zapasy królestwa” dla towarów z oferty kupca morskiego,
- część 3: budowa kogi w 4 widocznych etapach i wodowanie; panel portu z planem rejsu (towary, ilości, zamówienie); rejs za horyzont (koga znika za krawędzią, wraca po czasie); start ze statku na „Wybrzeżu” (koga przy plaży, osadnicy schodzą z zestawem, gracz stawia ratusz); automatyczny gracz na „Wybrzeżu” zaczyna od statku,
- grafika rysowana kodem: koga i łódź rybacka w 8 kierunkach (z kołysaniem), koga w etapach budowy na pochylni, port z nabrzeżem i trapem, stocznia, przystań z pomostem, smolarnia z dołem smolnym, beczka smoły, ławica ryb, portowiec, cieśla okrętowy, smolarz, rybak w łodzi z siecią; kafle morza i plaży (gotowe w prototypie terenu, ART_SPEC §3),
- zapis: wersja 9 z migracją, fixturą i testem (statki z ładunkiem i trasą, budowy statków, ławice, cumowania, rejsy, kupiec morski); teksty PL i EN; aktualizacja GDD §2.2, §4.2, §4.3, §4.6, §5.4, §5.5, ARCHITECTURE §5.3, §8, §10 i ART_SPEC.

**Poza zakresem:** wyspy i mapy wyspowe (M6), karawela, karaka i okręt wojenny (drzewko okrętów, później), walka okrętów (M7 automatycznie, P1 interaktywnie), szlaki handlowe i rejsy do innych prowincji (M6), kolonizacja kolejnych prowincji (M6), przewozy między dwoma portami na jednej mapie, statki na jeziorze i rzece, mosty, sól i solone ryby, wahania cen w handlu morskim (1.0), pomiar FPS na laptopie (osobna sesja z M4b-3).

**Ryzyka etapu:**
- duża koga (kilka kafli długości) przy nabrzeżu i pochylni może źle się sortować z budynkami i postaciami na trapie (R1): przypadki dopisujemy do `test_sorting.gd`,
- budynki częściowo na wodzie to nowa reguła stawiania i nowy przypadek dla `BuildingSlicer`,
- start bez gotowego ratusza zmienia początek gry: automatyczny gracz i zasiedlanie muszą działać bez ratusza i magazynu, dopóki stoją tylko stos i osadnicy.

**DoD:**
- [x] Mapa „Wybrzeże” 128×128 z morzem, plażą i zatoką jest w menu; „Nadrzecze” i „Pojezierze” działają bez zmian (dotychczasowe testy przechodzą; `tests/unit/sim/test_water_nav.gd`).
- [x] Statki pływają tylko po wodzie: łódź po płytkiej i głębokiej, koga tylko po głębokiej i torze wodnym; wodna siatka ruchu ma testy (`test_water_nav.gd`).
- [x] Smolarnia robi smołę z drewna; stocznia buduje łódź z desek i smoły dostarczonych przez tragarzy (`tests/scenario/test_m5_chains.gd`).
- [x] Przystań rybacka: łódź płynie na ławicę, łowi, wraca, a rybak niesie ryby do magazynu; połów wyraźnie większy niż u wędkarza; ławice się odnawiają (`test_m5_chains.gd`: w 10 minut przystań 36 ryb, wędkarz 16).
- [x] Widoczny załadunek i rozładunek sztuka po sztuce: portowcy noszą towar po trapie między placem portowym a statkiem (`tests/scenario/test_m5_port.gd`; zrzut `game_shot.tscn -- --map=coast --tile=74,70 --zoom=2 --port --select=ship`).
- [x] Ładunek statku zgodny z UI: panel statku pokazuje stan ładowni z symulacji po każdej sztuce (test: `test_m5_port.gd`, panel sprawdzany po każdej sztuce wniesionej i zniesionej).
- [x] Kupiec morski przypływa tylko do portu, kupuje nadwyżki ponad progi i sprzedaje towary poniżej progu „kupuj do N” (`test_m5_port.gd`: kupił 40 sztuk drewna ponad próg 30, sprzedał 6 smoły do progu 8).
- [x] Statek budowany etapami do wodowania: koga przechodzi szkielet, poszycie, maszt z żaglem i wodowanie, każdy etap widać na pochylni (`tests/scenario/test_m5_voyage.gd`; zrzut `game_shot.tscn -- --map=coast --tile=74,70 --zoom=2 --cog_stage=<0..3>`).
- [x] Rejs za horyzont: koga gracza odpływa z ładunkiem i wraca ze złotem i zamówionymi towarami (`test_m5_voyage.gd`: 30 drewna sprzedane za 90 zł, 10 smoły kupione za 90 zł, smoła w magazynie).
- [x] Start ze statku na „Wybrzeżu”: koga wyładowuje osadników i zestaw startowy, gracz stawia obóz pionierów (decyzja 2026-11-06 zamiast ratusza); automatyczny gracz dochodzi z tego startu do 4 kamienic patrycjuszy w limicie 90 minut (`tests/scenario/test_m5_landing.gd`, `test_slice_dod.gd`: 73. minuta).
- [x] Zapis i odczyt w trakcie załadunku, w trakcie budowy statku i w czasie rejsu nie gubią towarów; zapis z M4b-3 wczytuje się po migracji (v8 → v9), nowa fixtura v9. (Część 2: zapis w trakcie załadunku gra dalej identycznie, migracja v9 → v10 i fixtura `v10_port.json`. Część 3: zapis w trakcie budowy kogi, za horyzontem i w czasie lądowania gra dalej identycznie, migracja v10 → v11, fixtura `v11_voyage.json`.)
- [ ] Bez spadku wydajności: duże miasto z M4b-3 nadal ≤ 4 ms na tick, automatyczny gracz na „Nadrzeczu” i „Pojezierzu” w limicie.
- [ ] UI w PL i EN, nowe teksty przez klucze tłumaczeń.
- [x] **Twoja ocena gry:** 5/5 (2026-11-07, część 3; części 1 i 2 zaakceptowane wcześniej). Wnioski w GDD §11.1.

**Poprawki z oceny (2026-11-07, mają pierwszeństwo przed M7):**
- [x] **Start bez czekania na kogę:** koga od razu stoi na kotwicy w zatoce i zaczyna wyładunek (teraz za długo płynie od krawędzi). **Zrobione (paczka 1):** także przy wyprawie morskiej do nowej prowincji. Wyładunek kończy się w ok. 17 s gry.
- [x] **Osadnicy rozproszeni na plaży** zamiast w jednym punkcie. **Zrobione (paczka 1):** każdy kolejny osadnik brodzi na inny suchy kafel brzegu (do 3 kafli od plaży, najbliższe najpierw).
- [x] **Czas ochronny na start** (ankieta 2026-11-07): przez pierwsze ok. 15 minut (albo do postawienia kilku chat) mieszkańcy się nie złoszczą i nie odchodzą; na pasku widać, ile ochrony zostało. Wartości do strojenia. **Zrobione (paczka 1, ankieta 2026-11-07): 15 minut, w nowej grze i w każdej świeżo zasiedlonej prowincji** (GDD §3.3). Zapis v17.
- [x] **Płynne wodowanie kogi:** kadłub zjeżdża z pochylni i wpływa na wodę bez przeskoku (teraz bardzo wolno sunie, a potem nagle jest na wodzie). **Zrobione (paczka 2):** przez etap wodowania cieśle wybijają kliny, a kadłub stoi na pochylni; w ostatnich 8 s etapu zjeżdża (najpierw przyspiesza, na wodzie zwalnia) i staje dokładnie tam i tak samo obrócony, jak koga po zwodowaniu. Zrzut: `game_shot.tscn -- --map=coast --tile=74,70 --zoom=2 --cog_stage=3 --launch=<0..1>` (1 = już zwodowana).

**Ustalone przy realizacji części 1 (2026-11-06, do zmiany na prośbę):**
- **Brzeg biegnie wzdłuż osi siatki.** Na ekranie brzeg „Wybrzeża” jest ukośny (morze wzdłuż dolnych krawędzi mapy), a w siatce prosty, z uskokami co 5–9 kafli. Powód: przystań i stocznia mają prostokątny pomost albo pochylnię, które na ukośnym w siatce brzegu (schodki) nigdzie się nie mieszczą. Zatoka jest prostokątna (13 kafli szerokości, głęboka woda w środku), rzeka wpada do jej końca. Tereny: `sand` (piasek, budować wolno, pól nie), `sea_shallow`, `sea_deep` (oba liczą się jako woda dla wędkarza i glinianki). Ławice to pojedyncze kafle morza w nieco jaśniejszym kolorze na obrazku mapy (13 sztuk, 2 w zatoce). Mapa: `tools/generate_coast_map.py`.
- **Budynki na wodzie stoją wodą do kamery.** Kafle pomostu i pochylni (`BuildingDef.water_tiles`) muszą być morzem, reszta lądem; przed pomostem musi być wolna woda (`berth`, miejsce cumowania). Budynek można obrócić tylko na dwa sposoby (jak inne warsztaty), więc woda jest zawsze z przodu (od strony kamery, ART_SPEC §3.2), a wejście z boku, od lądu. Brzegi zwrócone wodą „od kamery” (po drugiej stronie zatoki) zostają bez przystani.
- **Rozmiary:** przystań 3×3 (chata na 2 rzędach, pomost na trzecim), stocznia 4×4 (warsztat i szopa na 2 rzędach, pochylnia na 2 rzędach wody). Kwadratowe, bo obrót budynku zakłada kwadrat (ARCHITECTURE §5.2). Smolarnia 2×2.
- **Tor wodny** wyznacza się sam: od miejsca cumowania stoczni najkrótszą drogą po płytkiej wodzie do głębokiej (najwyżej 12 kafli; dalej stoczni postawić nie można: „Za daleko do głębokiej wody”). Po torze pływają kogi, nie jest zapisywany (wynika z budynków).
- **Połów:** wędkarz łowi 2 ryby na cykl (tak było od M4a), więc rybak z łodzi łowi **6 ryb** na rejs (ławica: 18 ryb, odnawia 1 rybę co 20 s). Pomiar: w 10 minut przystań 36 ryb, wędkarz 16. Ławica szukana w promieniu 24 kafli od pomostu.
- **Nowa łódź** czeka przy pochylni stoczni; dostaje ją najbliższa przystań bez łodzi, a rybak idzie do stoczni, wsiada i przypływa nią do domu. Łódź bez załogi na morzu (np. rybak stracił pracę) sama wraca do swojej przystani. Rozbiórka przystani: łódź czeka na nową przystań, ryby z rąk rybaka zostają w ładowni.
- **Stocznia** zamawia od razu wszystkie materiały statku (jak plac budowy) i co sekundę uzupełnia zamówienie, gdyby tragarz z towarem zniknął po drodze. Łódź: 2 etapy (szkielet, poszycie) po 30 s pracy cieśli, potem wodowanie. Kolejka do 5 zamówień; anulowanie statku na pochylni zostawia niezużyte materiały na ziemi.
- **Rybak w łodzi** to część grafiki łodzi (wiosłuje, zarzuca sieć, czeka przy pływakach, wyciąga sieć z rybami); postać rybaka jest wtedy ukryta.
- **Budynku na wodzie nie da się obrócić** po postawieniu (pomost wylądowałby na brzegu); obraca się go tylko przy stawianiu (R).
- **Pomiary po części 1:** duże miasto z M4b-3 średnio 2,7 ms na tick (20 minut, cel ≤ 4 ms); automatyczny gracz: „Nadrzecze” 4 kamienice patrycjuszy w 70. minucie, „Pojezierze” w 79. (limit 90). Wynik bota zmienia się nieco po każdej zmianie danych.
- **Zakładka „Morze i statki”** w menu budowy: smolarnia, stocznia, przystań rybacka. Koga ma już dane (`data/ships/cog.tres`), ale zamówić ją będzie można w części 3.

**Ustalone przy realizacji części 3 (2026-11-06, do zmiany na prośbę):**
- **Ankieta z właścicielem (2026-11-06):** koga, która przywiozła osadników, po wyładunku odpływa (własną kogę buduje stocznia); koga gracza czeka na kotwicy w zatoce i podpływa do nabrzeża tylko na załadunek i rozładunek (kupiec morski dalej może przypływać); zamówienie płaci „sakiewka” zabrana ze skarbca przy wypłynięciu; 3 osadników bez zawodu nosi towar jak tragarze, dopóki nie stanie chata.
- **Obóz pionierów zamiast ratusza na start** (pomysł właściciela, ankieta 2026-11-06): budynek 3×3 za 10 drewna, budowniczy i 2 tragarzy, ustawianie podatków; najwyżej jeden na prowincję, w menu (zakładka magazynów) na każdej mapie. Na „Wybrzeżu” do jego postawienia menu ma tylko obóz, a inne budynki dają „Najpierw postaw obóz pionierów”. Ratusz na razie bez zmian; przesunięcie go na później z nowymi funkcjami i dom budowniczych: IDEAS.
- **Etapy kogi mają własne koszty:** szkielet 8 desek, poszycie 10 desek i 4 smoły, maszt z żaglem 2 deski i 4 sukna, wodowanie 2 smoły (razem jak w planie: 20 desek, 6 smoły, 4 sukna); każdy etap 60 s pracy cieśli. Przy wodowaniu kadłub zjeżdża z pochylni na wodę. Koga jest dłuższa od pochylni (ok. 3,7 kafla wobec 2), więc leży rufą przy brzegowym końcu pochylni, dziobem nad wodą, i rysuje się przed całą stocznią (uwaga właściciela 2026-11-06: warsztat zasłaniał rufę).
- **Jedna koga na port.** Nowa koga szuka najbliższego portu bez kogi; bez portu czeka na kotwicy przy stoczni. Kotwicowisko: najbliższa głęboka woda co najmniej 3 kafle od miejsca cumowania, poza torem wodnym.
- **Plan rejsu** w panelu portu: towary na sprzedaż i zamówienie po 5 sztuk, każda lista mieści się w ładowni (4 miejsca po 10 sztuk). Sprzedać można każdy towar z ceną, oprócz żywych zwierząt. Zamówić można to, co sprzedaje kupiec morski (deski, smoła, sukno), po jego cenie (+50%).
- **Załadunek kończy się sam**, gdy plan jest na pokładzie albo w królestwie nie ma już tego towaru; przycisk „Odpłyń teraz” wysyła kogę z tym, co ma. Za horyzontem koga jest 270 s (z drogą do krawędzi i z powrotem ok. 6 minut na „Wybrzeżu”). Złoto ze sprzedaży wpływa po powrocie do nabrzeża; nadwyżka sakiewki nie powstaje, bo zamówienie jest liczone przy wypłynięciu (najwyżej tyle, na ile starcza złota).
- **Start ze statku:** koga wpływa z najbliższej krawędzi morza i rzuca kotwicę w zatoce (73, 74), osadnicy co 2 s brodzą do plaży (70, 74). Zestaw startowy: **90 drewna i 20 chleba** (obóz 10, magazyn 8, 3 chaty 12, reszta jak zapas startowy innych map; przy 50 drewna automatyczny gracz grzązł). Leży jako kupy po jednym stosie na kafel obok plaży. Obóz bierze budowniczego i 2 tragarzy z osadników (mieszkają w obozie); pozostali wprowadzają się do pierwszych chat. Kamera startuje nad plażą.
- **Automatyczny gracz na „Wybrzeżu”** ma własne poprawki planu (tylko na tej mapie, inne mapy grają jak dotąd): obóz i magazyn przy stosie na plaży, miasto 12 kafli w głąb lądu, drwale przy południowym lesie, łańcuch chleba, rybacy, browary i cegły po stronie miasta (rzeka dzieli mapę), dodatkowe pola, młyn, piekarnia, chmielnik, browar, 4 chaty i studnia, magazyn przy polach (rolnik nosi każdy snop do magazynu: przy magazynie o 17 kafli dalej zbierał o połowę mniej). Miejsca wymagające dużego objazdu (bród) są pomijane. Wynik: 4 zaopatrzone kamienice patrycjuszy w 73. minucie (Nadrzecze 70., Pojezierze 79.). Ta sama mapa ze starym startem (ratusz) i planem z „Nadrzecza” nie dochodziła nawet do mieszczan, więc wniosek dla oceny gry: na „Wybrzeżu” las jest daleko od plaży, a rzeka odcina wschód.

**Ustalone przy realizacji części 2 (2026-11-06, do zmiany na prośbę):**
- **Port 4×4, nie 4×3** (jak stocznia: obrót budynku zakłada kwadrat). Dwa rzędy lądu to plac portowy (6 stosów), dwa rzędy wody to nabrzeże na palach z żurawiem; miejsce cumowania przed nabrzeżem, z torem wodnym do głębokiej wody jak przy stoczni. Koszt: 16 drewna, 12 desek, 6 kamienia, 40 złota; 2 portowców. Zakładka „Morze i statki”.
- **Plac portowy jest prywatny** (jak plac budowy): tragarze nie odkładają na nim towarów sami z siebie i niczego z niego nie biorą. Towar trafia tam tylko na załadunek, a wszystko, na co nie czeka statek przy nabrzeżu (np. towar kupiony od kupca), tragarze odnoszą do magazynów. Zapas na placu liczy się do „Zapasów królestwa”.
- **Portowcy noszą tylko między placem a statkiem.** Z magazynów na plac i z placu do magazynów noszą zwykli tragarze. Portowiec idzie od wejścia portu przez nabrzeże do stopy trapu, wchodzi na statek, podaje towar (1 s) i wraca; na jeden kurs ok. 7–8 s. Dwóch portowców wnosi 40 sztuk w ok. 3 minuty.
- **Kupiec morski** przypływa co 12 minut gry i handluje 4 minuty (pierwsza wizyta po 12 minutach, a gdy wtedy nie ma portu, sprawdza znowu co minutę). Wpływa i wypływa przez najbliższy portowi kafel głębokiej wody na krawędzi mapy. Kupuje nadwyżki według progów „sprzedaj ponad N” kupca wędrownego (jedno ustawienie dla obu kupców), do 40 sztuk na wizytę, po cenie bazowej; **nie kupuje desek, smoły i sukna**, bo sam je sprzedaje. Przywozi 20 desek, 10 smoły, 10 sukna i sprzedaje je po **cenie bazowej +50%** (deska 6 zł, smoła 9 zł, sukno 11 zł). Płacimy sztuka po sztuce, gdy portowiec zdejmie towar ze statku; kupiec nie sprzeda więcej, niż starczy złota.
- **„Kupuj do N”** to nowa kolumna „Kupno z morza” w oknie „Zapasy królestwa”, tylko przy deskach, smole i suknie: kupiec sprzedaje, dopóki królestwo (z placem portowym i towarem w rękach) ma mniej niż N.
- **Obca koga** to osobny rodzaj statku (`foreign_cog`: ładownia 8 slotów po 10 sztuk, żeby zmieściła ofertę i 40 sztuk kupionych towarów), z grafiką kogi z prototypu w zielonych barwach kupca. Koga gracza (część 3) dostanie te same arkusze w kolorze gracza.
- **Portowiec na statku jest rysowany na wierzchu kogi** (prośba właściciela 2026-11-06): kto wszedł po trapie, stoi na pokładzie przed żaglem i kadłubem.
- **Pomiar po części 2:** duże miasto z M4b-3 średnio 2,3 ms na tick (20 minut, cel ≤ 4 ms).
- **Pomiar po części 3:** duże miasto z M4b-3 średnio 2,9 ms na tick (20 minut, cel ≤ 4 ms; w chmurze wynik waha się o kilka dziesiątych).
- **Panel statku:** kliknięcie statku pokazuje, czyj jest, czy stoi przy nabrzeżu, ile ma w ładowni (lista towarów z symulacji), a u kupca: ile zostało czasu i ile złota przeszło z rąk do rąk. Panel portu pokazuje, kto stoi przy nabrzeżu, i za ile minut przypłynie kupiec.

---

## M6 — Mapa świata i prowincje

**Status: plan zaakceptowany 2026-11-06 (ankieta z właścicielem projektu). Część 1 (świat i tryb uproszczony) gotowa i scalona do `main` 2026-11-06 (PR #23), czeka na ocenę właściciela. Część 2 (zasiedlanie) gotowa i scalona (PR #24, #26), czeka na ocenę. Część 3 (szlaki, wykup osad, wino) gotowa i scalona 2026-11-07 (PR #28), czeka na ocenę (stan niżej). Start przed oceną gry M4b-2, M4b-3 i M5 (decyzja właściciela); oceny zrobimy razem, a poprawki z nich mają pierwszeństwo przed dalszą pracą.**

**Część 3, stan (2026-11-06):** decyzje z ankiety 2026-11-06: osobne okno „Szlaki handlowe” (przycisk „Szlaki” w pasku u góry i „Szlaki handlowe” w panelu prowincji na mapie świata), do 3 towarów na szlak, pojazd wybierany z listy w oknie (wolna koga z portu albo wóz kupiecki ze składu kupieckiego prowincji A, zmiana 2026-11-07), panel żądań osady neutralnej na mapie świata, podział na kawałki A (szlaki), B (osady neutralne), C (wino, automatyczny gracz, pomiar) i jedna ocena na końcu. Zrobione:
- **A, szlaki:** `TradeRoute` w świecie (`WorldSim.routes`; stany: czeka, załadunek, w drodze, rozładunek, powrót), `TradeRoutes` (co sekundę: próg „gdy tam mniej niż N”, ilość na kurs, ładownia kogi 4 miejsca po 10, wóz szlaku 12), `RouteWagon` (wóz przed stajnią, tragarze go ładują, woźnica wyjeżdża za krawędź mapy; w B wjeżdża, a tragarze go rozładowują), koga szlaku ładowana przez portowców jak przed rejsem za horyzont (`Voyage.route`). W nieoglądanej prowincji załadunek i rozładunek dzieją się od razu, podróż po zegarze. Ładunek kogi w oglądanej B ląduje przed portem (albo ratuszem) i tragarze go znoszą. Komendy: `CreateTradeRouteCommand`, `SetTradeRouteCommand` (towary, wstrzymanie), `RemoveTradeRouteCommand` (usunięty w trasie kończy się po powrocie). Wóz ze stajni jest „pożyczony” (`BuildingState.lent`): jego woźnica zostaje w stajni. Panel portu ma cel rejsu: „za horyzont” albo „do mojej prowincji” (jednorazowy szlak, bez sprzedaży). Mapa świata rysuje szlaki kropkami i pojazdy w drodze. **Strojenie:** wóz szlaku wiezie 12, nie 6 (z 6 kurs w obie strony, ok. 6 min, przywoził za mało, żeby wykupić osadę lądem w 20 minut); po 45 s bez nowej sztuki wóz rusza z tym, co ma (towar na kramach targowiska liczy się jako zapas, ale tragarze go stamtąd nie biorą).
- **B, osady neutralne:** `NeutralTown` stawia miasteczko z danych prowincji (`town_buildings`, `town_burghers` w `ProvinceDef`): Żelazny Gród ma 37 budynków i 84 mieszkańców, Końska Przystań 33 budynki i 72 mieszkańców (na „Wybrzeżu” najpierw ratusz koło plaży). Miasteczko czeka zamrożone (nie żyje, dopóki jest neutralne). `NeutralSettlement`: żądanie złota i towarów z licznikiem (300 zł i 40 chleba albo 300 zł, 30 chleba i 20 desek, w 20 minut); złoto płaci się przyciskiem w panelu (`PaySettlementCommand`), towary dowozi szlak albo koga z celem „do mojej prowincji”. Po spełnieniu osada przechodzi do gracza z ludźmi i budynkami i zaczyna żyć. Po czasie przepada wszystko, co dano, a po 10 minutach przychodzi żądanie o 25% droższe.
- **C, wino:** kafle winne (`vine_soil`, 5 okrągłych łat) w prowincjach z winoroślą (Winne Wzgórza, Mewia Wyspa), winnica 3×3 (stawia się ją tylko przy kaflach winnych, krzewy rosną tylko na nich; 12 pól, wzrost 150 s), tłocznia 2×2 (3 kosze winogron → beczka wina w 40 s), wino jako dodatkowa potrzeba patrycjuszy (`NeedDef.extra`: +10 zadowolenia, najwyżej do 100, i +25% podatku; bez wina dom nie podupada). Grafiki rysowane kodem: ziemia winna i krzewy (placeholdery), winnica i tłocznia, kosz winogron i beczka wina, winogrodnik i winiarz. Oznaczenia rzadkich surowców na mapie świata były już od części 1.
- **Automatyczny gracz w świecie** (`tests/support/world_bot.gd`, `test_m6_world_bot.gd`): na „Wybrzeżu” stawia ratusz i stajnię, zasiedla lądem Wierzbową Dolinę (52. min) i Bursztynowe Wybrzeże (65. min) i wozi chleb do Doliny (w 90 minut 3–4 kursy po 12 sztuk), bez zakleszczeń.
- **Pomiar 5 prowincji** (chmura, orientacyjnie; `"$GODOT" --headless --path . -s res://src/prototype/m6/five_bench.gd`): duże miasto oglądane i 4 miasteczka po ok. 35 budynków w trybie uproszczonym: 2,83 ms na tick średnio (samo duże miasto 2,59 ms), cel ≤ 4 ms. Pomiar na laptopie zostaje dla właściciela.
- **Zapis v14:** szlaki, wozy szlaków, pożyczone wozy, koga na szlaku, żądania osad; spiżarnie domów dostają miejsce na wino. Fixtura `v14_routes.json` (`"$GODOT" --headless --path . -s res://tools/build_routes_fixture.gd`). Testy: `test_m6_routes.gd`, `test_m6_settlement.gd`, `test_m6_wine.gd`, `test_m6_world_bot.gd`, fixtura w `test_m6_modes.gd` i `test_world_sim.gd`.
- Zrzuty: mapa ze szlakami `world_shot.tscn -- --out=<plik.png> --routes [--window]`, panel osady `world_shot.tscn -- --out=<plik.png> --select=horse_haven`.
- **Zmiany po rozmowie z właścicielem (ankieta 2026-11-07, przed oceną):** szlaki lądowe jeżdżą **wozem kupieckim** z nowego budynku **„skład kupiecki”** (3×3, 10 desek, 6 kamienia, 6 drewna, 60 zł, jeden woźnica i jeden wóz): wóz z płóciennym dachem wiezie **40 sztuk** (jak koga), jedzie o 25% wolniej niż zwykły wóz i nie pracuje w mieście; stajnie wróciły do samej pracy w mieście. Żądania osad mieszczą się w jednym kursie: Żelazny Gród 300 zł i 40 chleba, Końska Przystań 300 zł, 25 chleba i 15 desek. **Winnica stoi w całej prowincji z winoroślą** (`BuildingDef.needs_rare`, `ProvinceSim.rare_resource`), krzewy rosną na każdym polu, a na ziemi winnej o połowę szybciej (100 s zamiast 150 s, `field_bonus_terrain`, `field_bonus`). Zapis zostaje w wersji 14 (gałąź jeszcze niewydana; prowincja zapisuje swój rzadki surowiec, `rare`).
- Uproszczenia: w oglądanej prowincji B koga szlaku nie wpływa do portu (towar pojawia się przy porcie i tragarze go znoszą); woźnica wozu szlaku jest „dodatkowy” (nie ubywa mieszkańca), a pożyczający wóz woźnica stajni czeka w niej; przystanie rybackie miasteczek neutralnych nie mają łodzi; grafiki winnicy i tłoczni są złożone z istniejących elementów (dachy, kadzie, beczki), a ziemia winna i krzewy to placeholdery.

**Część 1, stan (2026-11-06):** świat „Królestwo” z 9 prowincjami (`data/provinces/`, `data/worlds/kingdom.tres`, skrypt `tools/generate_world_data.py`); `WorldSim` i wiele prowincji w `Simulation` (ARCHITECTURE §4.1); `ProvinceAbstract`, `WorkCycle`, `ProductionLog` (ARCHITECTURE §7); `EnterProvinceCommand`; ekran mapy świata (klawisz M, przycisk „Mapa”; zrzut: `xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 res://src/prototype/m6/world_shot.tscn -- --out=<plik.png> [--select=<id prowincji>] [--settle]`); menu „Nowa gra” (świat) i „Pojedyncza prowincja: …”; zapis v12 z migracją i fixturą. Testy: wyjście i wejście bez zgubionych towarów na fixturach v1–v12 i na dużym mieście, spójność trybów (chleb −11%, deski +2%, piwo −8%). Koszt trybu uproszczonego: zwykła prowincja ok. 0,02 ms na tick, duże miasto 0,64 ms (cel 0,2 ms, do ponownego pomiaru w części 3). Decyzje z ankiety 2026-11-06: mapa świata nie przełącza trybu (ostatnio oglądana prowincja żyje dalej), a przy wyjściu z prowincji to, co trwa, kończy się od razu. Uproszczenia: po powrocie pracownik zaczyna cykl od początku; place brukowania w trybie uproszczonym czekają; do pustej prowincji nie da się jeszcze wejść (zasiedlanie w części 2); statków i wozów na mapie świata jeszcze nie ma (część 2).

**Decyzje (2026-11-06, ankieta z właścicielem projektu):**
- **Mały świat ręcznie ułożony: 9 prowincji.** Pełny świat sandbox (20–40 prowincji) i generator świata zostają w M8.
- **Mapy prowincji z szablonów z wariantami.** Każda prowincja korzysta z jednego szablonu („Nadrzecze”, „Pojezierze”, „Wybrzeże”, nowa „Wyspy”), z odbiciem lustrzanym i rozłożeniem złóż (las, skały, ławice, żyzne pola) zależnym od bogactwa surowców 1–3 (GDD §2.1).
- **Ilustrowana mapa świata.** Osobny ekran: mapa jak na pergaminie, rysowana kodem (ląd, morze, granice prowincji, ikony miast, kolor właściciela). Statki i wozy przesuwają się po szlakach. Kliknięcie prowincji otwiera panel (właściciel, ludność, zapasy, rzadki surowiec, „Wejdź”).
- **Tryb uproszczony jak w ARCHITECTURE §7.** Nieoglądana prowincja nie ma postaci, tylko liczby: budynki produkują w tempie z czasu pracy i dróg (kalibrowanym tym, co było widać), domy jedzą, awansują i podupadają, budowy idą dalej. Test spójności chleba ±15%.
- **Zasiedlanie statkiem i wozem, z lądowaniem.** Wyprawę osadników wysyła się z prowincji, która ma ratusz. Morzem: koga z portu zabiera osadników (ubywa ich w prowincji macierzystej) i zestaw startowy z magazynów; w nowej prowincji jest lądowanie jak dziś na „Wybrzeżu” i obóz pionierów. Lądem, do sąsiada: wóz osadników wjeżdża z krawędzi mapy, osadnicy idą obok.
- **Wykup osady neutralnej za złoto i dostawy w czasie.** Osada neutralna to gotowe małe miasteczko z żądaniami (złoto i towary w limicie czasu). Towary dowozi się szlakiem albo jednorazowym kursem. Po spełnieniu żądań osada przechodzi do gracza z mieszkańcami i budynkami.
- **Szlaki handlowe statkami i wozami, z regułą progu** (GDD §4.5): szlak A→B, towar, ilość i próg („wożę chleb, gdy w B jest mniej niż 20”). Koga albo wóz kursuje w kółko. W oglądanej prowincji widać załadunek i rozładunek, w nieoglądanej liczy się sam czas. „Rejsy w kółko” z IDEAS wchodzą w to same: rejs za horyzont z M5 dostaje drugi cel, „do mojej prowincji”.
- **Rzadkie surowce: złoża i jeden łańcuch, wino.** Prowincje mają rzadki surowiec (ruda żelaza, sól, winorośl, pastwiska koni) widoczny na mapie świata. W M6 działa tylko winorośl: winnica na kaflach winnych → tłocznia → wino jako dodatkowa potrzeba patrycjuszy (powód do szlaków). Żelazo i konie w M7, sól z solonymi rybami po 1.0.
- **Jeden szablon „Wyspy”**: mapa 128×128, jedna duża wyspa i 1–2 małe, plaże i zatoka na port. Do wyspy dociera się tylko statkiem.
- **Nowa gra zaczyna się w świecie, stare mapy zostają osobno.** „Nowa gra” startuje lądowaniem kogi w prowincji przybrzeżnej; reszta świata jest pusta albo neutralna. W menu zostaje „Pojedyncza prowincja” ze starymi mapami (do testów i do zaległych ocen M4b–M5). Stare zapisy wczytują się jako świat z jedną prowincją.
- **Ratusz staje się siedzibą prowincji** (IDEAS, wariant „ratusz = podatki + siedziba”): mieszczanie i patrycjusze płacą podatek tylko w prowincji z ratuszem (bez ratusza płacą jak chłopi), a wyprawę osadników wysyła się tylko z prowincji z ratuszem. Najwyżej jeden ratusz na prowincję. Obóz pionierów zostaje pierwszym budynkiem nowej osady.
- **Bez innych pomysłów z IDEAS:** dom budowniczych i nabrzeża w głąb morza czekają (nabrzeża to osobny etap, najlepiej przed M7).
- **Złoto wspólne, towary i ludzie osobno** (GDD §3.5): skarbiec jest jeden dla królestwa, a każda prowincja ma własne magazyny, mieszkańców i podatki.

**Wartości wyjściowe (do strojenia przy realizacji):**
- świat (9 prowincji, dane w `data/provinces/`):
  1. „Zatoka Lądowania”: przybrzeżna (szablon „Wybrzeże”), start gracza ze statku,
  2. przybrzeżna (lustrzane „Wybrzeże”), pusta, sąsiad lądowy startu,
  3. kontynentalna z rzeką („Nadrzecze”), pusta, sąsiad lądowy startu,
  4. kontynentalna z jeziorem („Pojezierze”), pusta,
  5. kontynentalna z rzeką (lustrzane „Nadrzecze”), pusta, **winorośl**,
  6. wyspa („Wyspy”), pusta, **winorośl**,
  7. wyspa (lustrzane „Wyspy”), pusta, sól (tylko oznaczenie),
  8. osada neutralna, kontynentalna („Pojezierze”), ruda żelaza (tylko oznaczenie),
  9. osada neutralna, przybrzeżna (lustrzane „Wybrzeże”), pastwiska koni (tylko oznaczenie);
  do 5 prowincji gracza można dojść zasiedlaniem samych pustych prowincji (7 pustych),
- czas podróży na mapie świata: wóz do sąsiada ok. 3 minuty gry, koga między portami 3–6 minut zależnie od odległości (prędkość jak przy rejsie za horyzont),
- tryb uproszczony: tick co 1 s gry; czas dojścia do magazynu kalibrowany średnią z ostatnich 10 zmierzonych kursów na budynek, bez pomiarów: długość ścieżki do najbliższego magazynu × 2 / prędkość; koszt ≤ 0,2 ms na prowincję na tick,
- wyprawa osadników: 6 osadników (w tym budowniczy i 2 tragarzy), zestaw jak start ze statku (90 drewna, 20 chleba), pobrany z magazynów prowincji macierzystej; morzem koga wiezie osadników i zestaw (na czas wyprawy ładownia kogi mieści cały zestaw), lądem wóz osadników (nowa jednostka, ładunek jak zestaw) i osadnicy pieszo; koszt wyprawy 100 złota,
- osada neutralna: ok. 30–40 budynków, 60–80 mieszkańców (fixtura ze skryptu, jak duże miasto z M4b-3); żądanie np. 300 złota i 40 chleba w 20 minut gry; niespełnione w czasie przepada, a nowe żądanie przychodzi po 10 minutach i jest o 25% droższe,
- szlak: jeden statek albo wóz na szlak, kurs startuje, gdy w B jest mniej niż próg, a w A jest towar; ładunek do pełnej ładowni (koga 40, wóz konny 6; **decyzja 2026-11-07: wóz kupiecki ze składu kupieckiego, 40**), przy czym wóz szlaku jeździ tylko do sąsiada lądowego,
- ratusz: podatek mieszczan i patrycjuszy liczony tylko przy ratuszu w prowincji, bez niego jak od chłopa; ratusz dalej daje budowniczego i 2 tragarzy,
- wino (**decyzja 2026-11-07: winnica w całej prowincji z winoroślą, ziemia winna przyspiesza krzewy o 50%**): winnica 3×3 przy kaflach winnych (jak farma, pola 1×1 z krzewami, zbiór winogron), tłocznia 2×2 (3 kosze winogron → 1 beczka wina w ok. 40 s); wino to dodatkowa potrzeba patrycjuszy: podnosi zadowolenie i podatek, ale nie jest wymagane do utrzymania poziomu domu (stare mapy bez winorośli działają jak dotąd),
- wejście do prowincji i wyjście z niej: przełączenie trwa najwyżej 2 s na laptopie (pomiar właściciela).

**Kolejność prac:** część 1 (świat i tryb uproszczony: wiele prowincji w symulacji, przełączanie trybów bez gubienia towarów, test spójności, pierwsza wersja ekranu mapy świata z wejściem do prowincji; sprawdzone testami przed resztą), część 2 (zasiedlanie: wyprawa osadników morzem i lądem, szablon „Wyspy” i warianty szablonów, ratusz jako siedziba, ruch statków i wozów na mapie świata), część 3 (szlaki i wykup: szlaki handlowe, rejs do własnej prowincji, osady neutralne i wykup, winorośl i wino, pomiar 5 prowincji gracza, automatyczny gracz w świecie). Ocena gry jak w M5: część po części, jeśli właściciel zechce, albo jedna na końcu.

**Zakres:**
- część 1: `WorldSim` (graf prowincji z granicami lądowymi i strefami morskimi, właściciele, czas podróży), dane prowincji (`ProvinceDef`: nazwa, szablon, wariant, bogactwo surowców, rzadki surowiec, właściciel, sąsiedzi, położenie na mapie świata) i świata (`data/worlds/`); `Simulation` z wieloma prowincjami (ARCHITECTURE §4.1), jedna oglądana w trybie szczegółowym; `ProvinceAbstract` (budynki, magazyny, domy, siła robocza, budowy, pola, stada, statki w stoczni, kupcy liczeni po czasie); przełączanie trybów według ARCHITECTURE §7.2 dla wszystkich dzisiejszych systemów (postacie z towarem, place budowy, wozy, statki, rejs za horyzont, kupcy, lądowanie); kalibracja czasu transportu; ekran mapy świata w pierwszej wersji (pergamin, prowincje, właściciele, panel, „Wejdź”, powrót klawiszem M); menu „Nowa gra” (świat) i „Pojedyncza prowincja” (stare mapy); zapis v12 ze światem,
- część 2: wyprawa osadników (okno wyprawy w ratuszu: cel na mapie świata, skład, koszt), koga z osadnikami odpływa za krawędź mapy, płynie po mapie świata i ląduje w nowej prowincji (gotowe lądowanie z M5), wóz osadników wyjeżdża przez krawędź i wjeżdża do sąsiada; nowa prowincja zaczyna od obozu pionierów; szablon „Wyspy” (`tools/generate_island_map.py`); warianty szablonów (odbicie i złoża według bogactwa); ratusz jako siedziba (podatki, wymóg wyprawy, jeden na prowincję); statki i wozy na mapie świata; zapis v13,
- część 3: szlaki handlowe (okno szlaków: A→B, towar, ilość, próg, przypisany statek albo wóz; załadunek przez portowców i tragarzy, w nieoglądanej prowincji liczony czasem; widok na mapie świata); plan rejsu w porcie z celem „do mojej prowincji”; osady neutralne (fixtury miasteczek, panel żądań, licznik czasu, przejęcie); kafle winne, winnica, tłocznia, wino i potrzeba patrycjuszy; oznaczenia rzadkich surowców na mapie świata; automatyczny gracz w świecie (zasiedla kolejne prowincje i stawia szlak); pomiar 5 prowincji gracza; zapis v14,
- grafika rysowana kodem: mapa świata (pergamin, ląd, morze, granice, ikony miast, herby w kolorach właścicieli, małe statki i wozy na szlakach, ikony rzadkich surowców), wóz osadników, kafle wyspy (z istniejących kafli plaży i morza), kafle winne i krzewy winorośli, winnica, tłocznia, beczka wina i kosz winogron, winiarz,
- zapis: wersje 12–14 z migracjami, fixturami i testami (stary zapis wczytuje się jako świat z jedną prowincją); teksty PL i EN; aktualizacja GDD §2.1, §2.2, §3.2, §3.5, §4.5, §4.6, §10, ARCHITECTURE §4.1, §7, §8 i ART_SPEC.

**Poza zakresem:** władcy AI, bandyci, armie i floty wojenne na mapie świata (M7–M8), oblężenia i bitwy (M7), generator świata i większe światy (M8), łańcuchy żelaza, soli i koni, dyplomacja, wahania cen i handel z obcymi portami o zmiennych cenach (1.0), archipelag wielu wysp w jednej prowincji i statki między dwoma portami jednej mapy, nabrzeża w głąb morza i dom budowniczych (IDEAS), przemieszczanie mieszkańców między prowincjami poza wyprawami osadników, pomiar FPS na laptopie (osobna sesja z właścicielem).

**Ryzyka etapu:**
- **przełączanie trybów** musi znać każdy dzisiejszy system (postacie z towarem, place budowy, statki, rejsy, kupcy, lądowanie, wozy, stada): łatwo o zgubiony towar albo zawieszone zlecenie. Ochrona: test „wejście i wyjście nie gubi towarów” uruchamiany na wszystkich fixturach zapisu i na dużym mieście,
- **rozjazd trybów** (R8): prowincja nieoglądana produkuje inaczej niż oglądana. Ochrona: test spójności ±15% dla chleba, a dodatkowo dla desek i piwa,
- **wydajność i pamięć:** dziś symulacja zakłada jedną prowincję (ok. 1650 linii w `ProvinceSim`). Rozdzielenie na świat i prowincje dotyka wielu miejsc. Ochrona: najpierw świat z jedną prowincją bez zmian w rozgrywce (wszystkie testy zielone), dopiero potem kolejne prowincje,
- **ratusz jako siedziba zmienia balans** sprawdzonych map: na „Nadrzeczu” i „Pojezierzu” ratusz stoi od startu, ale na „Wybrzeżu” automatyczny gracz musi go dobudować, zanim mieszczanie zaczną płacić; wynik bota w limicie 90 minut trzeba sprawdzić na nowo,
- **rozrost zakresu** (R9): to największy etap do tej pory. Ochrona: sztywny podział na 3 części, wszystko spoza listy do IDEAS.

**DoD:**
- [x] Świat z 9 prowincjami jest w menu jako „Nowa gra”; „Pojedyncza prowincja” ze starymi mapami działa bez zmian (dotychczasowe testy przechodzą).
- [x] Ekran mapy świata: widać prowincje, właścicieli, rzadkie surowce, statki i wozy w drodze; z panelu prowincji można do niej wejść i wrócić na mapę.
- [x] Test spójności trybów (±15%) przechodzi (chleb; dodatkowo deski i piwo).
- [x] Wejście i wyjście z prowincji nie gubi towarów (także towarów w rękach, na placach budowy, w ładowniach i na placu portowym).
- [x] Zasiedlanie morzem i lądem: wyprawa z prowincji z ratuszem dociera, ląduje i zakłada obóz pionierów; wyspę da się zasiedlić tylko statkiem.
- [x] Ratusz jako siedziba: mieszczanie i patrycjusze płacą pełny podatek tylko przy ratuszu; bez ratusza nie da się wysłać wyprawy.
- [x] Szlak handlowy statkiem i wozem przewozi towar według progu, z widocznym załadunkiem w oglądanej prowincji.
- [x] Wykup osady neutralnej: dostarczenie żądań w czasie przekazuje osadę graczowi z mieszkańcami i budynkami.
- [x] Wino: winnica i tłocznia działają tylko w prowincji z winoroślą, patrycjusze z winem mają wyższe zadowolenie i podatek.
- [x] Gra z 5 prowincjami gracza działa płynnie: tick ≤ 4 ms przy dużym mieście oglądanym i 4 prowincjach w trybie uproszczonym (2,83 ms w chmurze; pomiar na laptopie u właściciela); automatyczny gracz zasiedla kolejne prowincje i prowadzi szlak.
- [x] Zapis obejmuje cały świat: prowincje w obu trybach, wyprawy, szlaki, osady neutralne; stare zapisy wczytują się po migracji jako świat z jedną prowincją.
- [x] UI w PL i EN, nowe teksty przez klucze tłumaczeń.
- [x] **Twoja ocena gry:** 5/5 (2026-11-07, ankieta na laptopie, na gotowym świecie z `src/prototype/m6/review_world.gd`). Wnioski w GDD §11.1.

**Poprawki z oceny (2026-11-07, mają pierwszeństwo przed M7):**
- [x] **Wykup osady: „Wyślij towar” od razu wybiera to, czego osada żąda** (towary i ilości z jej żądań). **Zrobione (paczka 1):** przycisk otwiera okno szlaków z wybraną osadą, a nowy szlak bierze całe jej żądanie (do 3 towarów, ilość = ile jeszcze brakuje); okno pokazuje „zabierze żądanie osady: …”. Ilości można potem zmienić na liście szlaków.
- [x] **Wygląd winnicy:** rzędy pali z linkami i krzewy winorośli, które rosną i owocują (teraz pole wina to placeholder). **Zrobione (paczka 2, ankieta 2026-11-07: stojące krzewy jak drzewa):** na każdym polu winnicy stoi rząd (pale, dwie linki, dwa krzewy), rzędy łączą się w długie szpalery; krzewy są przycięte (pole puste i zaorane), puszczają pąki, liście, zielone grona i dojrzałe fioletowe grona (na zielonych liściach kilka żółknie). Pod spodem ziemia winna z ubitym pasem pod rzędem i trawą między rzędami. Ludzie chowają się za rzędami jak za drzewami. Zrzut: `game_shot.tscn -- --tile=50,58 --zoom=3 --vineyard`.

---

## UI-1 — Wygląd interfejsu i menu główne

**Status: start 2026-11-07, przed oceną gry M4b-2, M4b-3, M5 i M6 (decyzja właściciela; ankieta 2026-11-07).** Mały etap między M6 a M7: zmienia wygląd, nie zasady gry.

**Stan (2026-11-07):** gotowe i czeka na ocenę wyglądu. Obraz menu: wariant 2 z 3 (wybór właściciela), cięty na warstwy (`python3 tools/split_menu_art.py`; kawałek nieba za żaglem dopisany na uwagę właściciela). Motyw i grafiki interfejsu: `tools/generate_ui.gd`, `UiKit`. Pasek u góry z ikonami (mieszkańcy, pracujący, czas, złoto). Menu: „Nowa gra”, „Wczytaj szybki zapis”, „Pojedyncza prowincja” (rozwijane nazwy map), język, „Narzędzia twórców” (piaskownica, benchmark, próba czcionki i liczby mnogiej), „Wyjdź z gry”. Zrzut menu: `xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 res://src/prototype/ui/menu_shot.tscn -- --out=<plik.png> [--open=maps|tools]`. Do sprawdzenia na laptopie: menu w 1920×1080 (skala ×3; w chmurze nie da się zmienić rozmiaru okna). Uproszczenia: nabrzeże nie jest osobną warstwą (przesuwa się razem z miastem), koga się nie kołysze. **Dodatek (prośba właściciela 2026-11-07):** pasek budowy można schować przyciskiem „Schowaj”; schowany zostawia w lewym dolnym rogu tabliczkę „Budowa”, a klawisz B przełącza pasek (schowanie odkłada wybrane narzędzie). Zrzut: `town_shot.tscn -- --hide_build --shot=<plik.png>`. **Dodatek 2 (ankieta 2026-11-07):** sterowanie czasem na środku górnego paska, przy zegarze: ikony ‖ (pauza), ▶ (1×), ▶▶ (2×), ▶▶▶ (4×); każda od razu ustawia swoje tempo (i zdejmuje pauzę), aktywna jest wciśnięta ze złotą ikoną; przyciski „Pauza”, „Wolniej”, „Szybciej” zniknęły. Spacja i klawisze +/− działają jak dotąd.

**Decyzje (ankieta 2026-11-07):**
- **Styl „pergamin i drewno”, rysowany kodem:** panele jak pergamin w ramkach z ciemnego drewna z okuciami, przyciski jak drewniane tabliczki, nagłówki w kolorze ciemnej czerwieni i złota, pasek u góry jak deska z ikonami. Jeden wspólny motyw (`UiKit.theme()`), żadnych kolorów okien na sztywno.
- **Obrazek menu głównego z PixelLab** (pomysł właściciela): drewniane nabrzeże ze skrzyniami i beczkami na pierwszym planie, koga przy nabrzeżu ustawiona skośnie, dziobem w naszą stronę, z granatowym żaglem, w tle całe miasto na wzgórzu z zamkiem; **pogodny dzień**. Obraz 640×360 powiększony 3 razy (1920×1080). Właściciel wybiera jeden z wariantów.
- **Menu „żywe”:** obraz w warstwach przesuwa się lekko przy ruchu myszy, woda faluje, z kominów leci dym, krążą mewy, chmury płyną (rysowane kodem nad obrazem).
- **Nowe menu główne:** tytuł, „Nowa gra”, „Wczytaj”, „Pojedyncza prowincja” (rozwijane), język, „Wyjdź”; narzędzia deweloperskie (piaskownica, benchmark, próba liczby mnogiej) schowane pod jednym przyciskiem.

**Zakres:** generator grafik interfejsu (`tools/generate_ui.gd`: pergamin, ramki, przyciski w 4 stanach, deska paska, separatory, ikony złota i ludzi), motyw w `UiKit`, przepięcie wszystkich okien i paneli na motyw, nowe menu główne z warstwami i animacjami, teksty PL i EN, aktualizacja ART_SPEC i ARCHITECTURE (UI).

**Poza zakresem:** zmiana układu okien i nowych funkcji (po ocenie gry), dźwięki, animowane przejścia między ekranami, ikony budynków w menu budowy (M9).

**DoD:**
- [x] Wszystkie okna, panele, pasek i menu budowy mają styl pergaminu i drewna; tekst jest czytelny (kontrast, także w zrzutach w obu językach).
- [x] Menu główne z obrazkiem z PixelLab, warstwami i animacjami; działa w 1280×720 i 1920×1080.
- [x] Testy przechodzą (szybkie i długie; 2026-11-07 na laptopie: 395 szybkich, 10 długich).
- [x] **Twoja ocena wyglądu:** 5/5 (2026-11-07, ankieta na laptopie). Okna „ładne i czytelne”, pasek u góry wygodny, menu „dobrze, ale drobiazgi”. Wnioski w GDD §11.1.

**Poprawki z oceny (2026-11-07, mają pierwszeństwo przed M7):**
- [x] **Menu: pasek na niebie** w miejscu, gdzie na obrazie były liny żagla (ślad po cięciu na warstwy), widoczny, gdy tło się przesuwa. **Zrobione (paczka 3):** niebo za lądem bierze kolor najbliższego piksela nieba (wcześniej każda kolumna powtarzała w dół ostatni piksel, stąd smugi i ciemna linia pod masztem flagi zamku), a prześwity nieba w olinowaniu kogi należą do nieba.
- [x] **Menu: brzegi obrazu** przy przesunięciu w dół warstwy wychodzą poza obraz, a krawędzie się rozciągają. Warstwy muszą mieć zapas albo ruch musi być ograniczony. **Zrobione (paczka 3, ankieta: lustrzany zapas):** zapas 8 pikseli wokół każdej warstwy to lustrzane odbicie obrazu zamiast rozciągniętej krawędzi; ruch (najwyżej 5 pikseli) nigdy go nie przekracza. Zrzut skrajnych położeń: `menu_shot.tscn -- --out=<plik> --shift=1,1` (i `-1,-1`).
- [x] **Menu: płynniejszy ruch** warstw za myszą (łagodne doganianie zamiast skoków). **Zrobione (paczka 3):** warstwy doganiają mysz jak na sprężynie bez przeskoku (ok. 0,45 s, łagodny start i hamowanie), także po długiej klatce.

---

## N1 — Nabrzeża i port

**Status: zamknięty 2026-11-07 (obie części zaakceptowane i scalone do `main`). Plan zaakceptowany 2026-11-07 (ankieta z właścicielem projektu), przed M7 i przed oceną gry M4b-2, M4b-3, M5, M6 i UI-1 (poprawki z ocen mają pierwszeństwo).** Pomysł gracza z IDEAS („Nabrzeża budowane w głąb morza”), wersja średnia: 2 części, ocena po każdej.

**Część 1, stan (2026-11-07): zaakceptowana przez właściciela 2026-11-07 i scalona do `main`.** Zrobione:
- **Nabrzeża w symulacji:** warstwa nabrzeży w siatce (pomost i kamień), chodzenie po nich (pomost jak droga ubita, nabrzeże jak bruk), statki i łodzie nie przepływają; budowa jak bruk: tragarze niosą deski albo kamień, budowniczy stoi obok i układa kafel po kaflu od brzegu (6 s na kafel); zamówione kafle są od razu zamknięte dla statków. Zasady: tylko morze, najwyżej 8 kafli od brzegu, nie na torze wodnym ani miejscu cumowania, a cała linia jest odrzucana, gdy odcięłaby od morza miejsce cumowania, ławicę albo statek. Rozbiórka kafla, jeśli reszta nabrzeża dalej sięga brzegu.
- **Budynki na nabrzeżu:** port, stocznia, przystań stoją na wodzie albo na nabrzeżu (także częścią lądową); inne budynki nie.
- **Miejsce cumowania** (zmiana: 2×2 zamiast 1×2, bo budynki mają kwadratowy obrys): 4 deski, tylko na nabrzeżu, przód do wody, mały plac na 3 stosy; obsługują je portowcy najbliższego portu w zasięgu 12 kafli (bez portu nie da się postawić). Kupiec morski, koga gracza i szlaki traktują je jak drugi port.
- **Jedna bryła portu:** `QuayLayer` rysuje nabrzeża gracza i pas nad wodą portu, przystani i stoczni (obok pochylni) tym samym kodem; grafiki tych budynków nie mają już pomostów, także w starych zapisach.
- **Interfejs:** przyciski „Pomost” i „Nabrzeże” w pasku budowy (przeciąganie jak droga, podgląd całej linii na zielono albo czerwono), miejsce cumowania w zakładce „Morze i statki”, rozbiórka kafla nabrzeża.
- **Zapis v15** z migracją i fixturą `v15_quays.json` (`"$GODOT" --headless --path . -s res://tools/build_quay_fixture.gd`). Testy: `tests/scenario/test_n1_quays.gd` (budowa, koszt, zasięg, odcięcie morza, budynki na nabrzeżu, kupiec przy miejscu cumowania obsłużony przez portowców, rozbiórka, zapis, fixtura v15, migracja), fixtura w `test_m6_modes.gd`.
- Zrzut: `game_shot.tscn -- --map=coast --tile=76,84 --zoom=2 --port --quays`.
- **Zmiany po rozmowie z właścicielem (2026-11-07, przed oceną):** nabrzeża stawia się **jak mury, w 8 kierunkach**: przeciągnięcie przyciąga się do prostej albo skosu, a skos dostaje po bokach każdego kroku kliny (jak „prosto” przy murze kamiennym, ARCHITECTURE §6.3), więc ludzie po nim chodzą, a widok ścina kliny od strony wody i boki biegną prosto. Skos zużywa ok. 3 kafle na krok; krok po skosie liczy się jako 1 kafel zasięgu (8 kroków od brzegu). Nabrzeża są **wyższe**: pokład jest na wysokości lądu, a ściana opada do wody (kamień 20 px z **profilem jak w Anno 1404** według referencji właściciela: przypory z pachołkami, łuki schodzące do wody, gzyms; pomost 12 px z palami i zastrzałami), i **widać, że chowają się pod wodą**: pod linią wody z pianą ściana i pale idą dalej, coraz bardziej niebieskie i przezroczyste. **Druga rozmowa (2026-11-07):** **pomost bogatszy, jak w Anno** (pale z zastrzałami na krzyż, belka z końcami desek i listwa pod nią, wysokie słupy cumownicze na rogach, czasem drabinka do wody, deski w odcieniach z gwoździami; pomost 14 px nad wodą) i **nabrzeża wchodzą na ląd** na najwyżej 2 kafle od morza, także po skosie: na lądzie leżą jak bruk portowy (krawężnik od strony ziemi, a bok widoczny dla kamery schodzi trójkątem po skarpie: pełna wysokość przy wodzie, zero 2 kafle w głąb lądu; prośba właściciela), liczą się jako brzeg (nie zużywają zasięgu), a drogi, pola i domy na nie nie wchodzą. Przy okazji: plac nabrzeża co sekundę zamawia dokładnie brakujący materiał (tragarz, który nie doniósł ładunku, bo budowniczy przeszedł dalej, nie zatrzymuje już budowy).
- Uproszczenia: w trybie uproszczonym (prowincja nieoglądana) budowa nabrzeży czeka jak bruk; pas budynku nad wodą to zawsze pomost (chyba że stoi na kamiennym nabrzeżu); burzenie nabrzeża nie zwraca materiału.

**Część 2, stan (2026-11-07): zaakceptowana przez właściciela 2026-11-07 i scalona do `main`** (po uwadze właściciela: masywniejszy dźwig, koga cumuje dalej od nabrzeża). Decyzje z ankiety (2026-11-07, wszystkie według rekomendacji): dźwig pracuje **razem z portowcami** (nie zamiast nich), wygląd z **kołem deptakowym i ładunkiem na linie**, magazyn portowy to **zwykły magazyn** na nabrzeżu, automatyczny gracz stawia **pełny port z kogą**. Zrobione:
- **Dźwig przeładunkowy:** 2×2, tylko na nabrzeżu, najwyżej 2 kafle od miejsca, gdzie cumuje statek (przy porcie albo miejscu cumowania), 12 desek i 4 kamienie, 1 dźwigowy. Dźwigowy chodzi w kole, a ramię przenosi po 3 sztuki w siatce między placem a statkiem, obok portowców: sam dźwig ok. 1,8× tyle co dwóch portowców, razem statek ładuje się ok. 2,8× szybciej (24 drewna: portowcy 69 s, dźwig 38 s, razem 25 s). Mniej niż 3 sztuki tylko na koniec towaru: gdy tragarze dopiero znoszą towar na plac, dźwig czeka na pełny ładunek, a portowcy w tym czasie noszą pojedyncze sztuki. Przerwany załadunek (statek odpływa) niczego nie gubi.
- **Magazyn portowy:** 3×3, tylko na nabrzeżu, 8 desek i 4 kamienie, 8 stosów, 2 tragarzy; zwykły magazyn, najbliżej statków.
- **Wygląd:** maszt z kołem deptakowym rysowany kodem; ramię obraca się od placu nad statek, hak z ładunkiem w siatce podnosi się i opuszcza na pokład (`CraneLayer`). Panel dźwigu: które miejsce obsługuje, statek przy nim, co teraz podnosi.
- **Automatyczny gracz na „Wybrzeżu”** (`tests/support/harbour_bot.gd`, `tests/long/test_n1_harbour_bot.gd`, 130 minut): obok zwykłego planu miasta od 45. minuty stawia port, smolarnię, pomost z miejscem cumowania i dźwigiem, drugi pomost z magazynem portowym i stocznię (na południe, żeby domem kogi było miejsce cumowania), kupuje u kupca smołę i sukno, a gdy miejsce cumowania i dźwig stoją, zamawia kogę i wysyła ją w rejsy (deski tam, smoła i sukno z powrotem). Wynik: kupiec przy porcie i koga przy miejscu cumowania stoją naraz łącznie ok. 11 minut, 3 rejsy, dźwig przeniósł 28 sztuk w 11 podniesieniach, magazyn portowy przyjął 231 sztuk, bez zakleszczeń.
- **Zapis v16** (bez zmiany formatu: nowe budynki, a podniesienie żyje w zadaniu dźwigowego) z migracją i fixturą `v16_crane.json` (`"$GODOT" --headless --path . -s res://tools/build_crane_fixture.gd`; dźwig w połowie podniesienia). Testy: `tests/scenario/test_n1_crane.gd`, fixtura w `test_m6_modes.gd`.
- Zrzut: `game_shot.tscn -- --map=coast --tile=73,103 --zoom=2 --port --quays --crane [--lift=<0..1>]`.
- Uproszczenia: dźwig sięga placu miejsca cumowania (przy porcie: stopy trapu) z każdego miejsca w zasięgu; w trybie uproszczonym (prowincja nieoglądana) dźwig nie pracuje, bo kupiec handluje od razu, a koga płynie według zegara, jak dotąd; koło w grafice się nie obraca (ruch widać po dźwigowym, ramieniu i haku). Przy okazji poprawka: automatyczny gracz pokazał, że na „Wybrzeżu” szybko kończy się kamień, gdy koga go sprzedaje, więc jego drugi pomost jest drewniany.

**Decyzje (ankieta 2026-11-07):**
- **Mały etap przed M7** (zamiast po M7, wbrew rekomendacji, decyzja właściciela): port rośnie, zanim przyjdzie wojsko i oblężenia od morza.
- **Wersja średnia:** część 1 to pomost, nabrzeże kamienne, miejsce cumowania i budynki nad wodą stawiane na nabrzeżu; część 2 to dźwig przeładunkowy i magazyn portowy. Kuter z większą chatą rybacką i latarnia zostają w IDEAS; balisty i wieże portowe razem z walką okrętów.
- **Jedna bryła portu, jak w Anno** (pomysł właściciela 2026-11-07): część budynku nad wodą (pomost portu, przystani, pochylnia stoczni) to ten sam pas nabrzeża, który stawia gracz. Pas łączy się z nabrzeżem obok bez szwów, więc port, stocznia, przystań i nabrzeża wyglądają jak jedna budowla.
- **Nowy wygląd wszędzie:** port, stocznia i przystań na wszystkich mapach i w starych zapisach od razu mają nowy pas nabrzeża (zmiana tylko wyglądu, zasady bez zmian).

**Wartości wyjściowe (do strojenia przy realizacji):**
- pomost drewniany: 2 deski na kafel; nabrzeże kamienne: 3 kamienie na kafel (w M7 mocniejsze),
- stawiane linią jak mury, w 8 kierunkach (decyzja 2026-11-07), na wodzie morskiej płytkiej i głębokiej i do 2 kafli na lądzie przy morzu (decyzja 2026-11-07), najwyżej 8 kafli od lądu (liczone po nabrzeżu); pierwszy kafel musi dotykać lądu albo innego nabrzeża,
- rzędy obok siebie zlewają się w jedno szerokie nabrzeże (model bryłowy jak mur kamienny, ARCHITECTURE §6.3, ale płaski),
- ludzie chodzą po nabrzeżu jak po drodze; statki i łodzie nie przepływają; stawianie jest zabronione, jeśli odcięłoby od morza miejsce cumowania, pochylnię, przystań albo ławicę,
- budowa jak droga: budowniczy i tragarze, kafel po kaflu,
- miejsce cumowania 1×2 (2 deski; **przy realizacji 2×2 i 4 deski**, bo obrysy budynków są kwadratowe) na krawędzi nabrzeża, przodem do głębokiej wody: kolejne miejsce dla statku (koga gracza, kupiec morski, koga szlaku); obsługują je portowcy portu w zasięgu 12 kafli, a towar idzie na plac portu,
- port, stocznia i przystań można stawiać także na nabrzeżu: ich część „wodna” może stać na wodzie albo na nabrzeżu, a wejście od lądu albo od nabrzeża (krzywy brzeg przestaje przeszkadzać),
- część 2: dźwig przeładunkowy (2×2 na nabrzeżu przy miejscu cumowania, 12 desek, 4 kamienie, 1 dźwigowy; załadunek 3 sztuki naraz, ok. 2× szybciej niż portowcy na plecach), magazyn portowy (3×3 na nabrzeżu, 8 pól, zwykły magazyn z tragarzami, bliżej statków),
- zapis: v15 (część 1), v16 (część 2).

**Zakres:**
- część 1: kafle nabrzeża w siatce (pomost i kamień, przejezdne dla ludzi, zamknięte dla statków), narzędzie stawiania linią z podglądem i kosztem, budowa przez budowniczego, burzenie; sprawdzenie, czy statki dalej mają drogę do morza; miejsce cumowania i obsługa przez portowców; nowa reguła stawiania budynków nad wodą (wodą albo nabrzeżem); pas nabrzeża budynków nad wodą rysowany tym samym kodem co nabrzeże gracza, łączenie w jedną bryłę; nabrzeże w trybie uproszczonym (ARCHITECTURE §7) i przy przełączaniu trybów; zapis v15 z migracją, fixturą i testami; teksty PL i EN; aktualizacja GDD §5.4, ARCHITECTURE §5.3, §6.3 i ART_SPEC,
- część 2: dźwig przeładunkowy, magazyn portowy, automatyczny gracz na „Wybrzeżu” korzysta z nabrzeża i drugiego miejsca cumowania; zapis v16,
- grafika rysowana kodem: deski na palach, kamienne bloki z obramowaniem, pachołki, liny, drabinki do wody; dźwig z kołem deptakowym (część 2).

**Poza zakresem:** kuter i większa chata rybacka, latarnia, dźwig naprawczy (po bitwach, P1), balisty i wieże portowe (M7 i P1), nabrzeża na jeziorach i rzekach, mosty, przewozy między dwoma portami jednej mapy.

**Ryzyka etapu:**
- chodzenie po wodzie: nabrzeże zmienia siatki ruchu ludzi i statków naraz; łatwo odciąć statek albo ławicę. Ochrona: sprawdzenie łączności przy stawianiu i testy siatek,
- sortowanie głębi dużych statków przy długich pomostach (R1): przypadki do `test_sorting.gd`,
- zmiana wyglądu budynków nad wodą na wszystkich mapach: zrzuty przed i po, a stare zapisy w testach migracji.

**DoD:**
- [x] Pomost i nabrzeże kamienne stawia się linią na morzu; rzędy zlewają się w jedno nabrzeże; budowa idzie przez budowniczego i tragarzy.
- [x] Ludzie chodzą po nabrzeżu, statki nie; nie da się odciąć miejsca cumowania, pochylni, przystani ani ławicy od morza (testy).
- [x] Miejsce cumowania przyjmuje drugi statek, a portowcy go ładują i rozładowują.
- [x] Port, stocznia i przystań stoją także na nabrzeżu, a ich pas nad wodą łączy się z nabrzeżem gracza w jedną bryłę (zrzuty).
- [x] Dźwig przeładunkowy i magazyn portowy działają (część 2; `test_n1_crane.gd`, automatyczny gracz w `test_n1_harbour_bot.gd`).
- [x] Zapis v15 i v16 z migracjami i fixturami; stare zapisy wczytują się z nowym wyglądem pomostów.
- [x] UI w PL i EN, nowe teksty przez klucze tłumaczeń.
- [x] **Twoja ocena gry** (po każdej części; część 1 i część 2 zaakceptowane 2026-11-07).

---

## G1 — Grafika budynków z PixelLab, część 1 (pionierzy)

**Status: zaakceptowany przez właściciela 2026-11-07 („jest super”), scalony do `main`. Etap zamknięty.**

**Decyzje (ankieta 2026-11-07):**
- **Obóz pionierów:** nowa generacja na cały romb 3×3 (więcej namiotów, sterty, ognisko), nie obóz z próby.
- **Drzwi:** w opisie podajemy, gdzie mają być drzwi, i wybieramy pasującego kandydata; gdy żaden nie pasuje, drzwi domalowuje PixelLab (inpaint). Bez lustra obrazka, bo światło musi być jak w całym mieście.
- **Druga orientacja:** lustro (jak w całej grze), 0 generacji.
- **Etapy budowy:** oba (`construction_1`, `construction_2`) z PixelLab, przerobione z gotowego budynku, żeby pasowały wyglądem.
- **Chata:** 3 warianty wyglądu, każdy z tyłem (`*_back`) przerobionym z przodu. Kamienice (poziomy 2–3) bez zmian.
- **Budżet (195 generacji do 27.11):** najpierw cały zestaw (5 budynków z etapami budowy), warianty chaty na końcu, ile się zmieści; ok. 10 generacji zapasu.
- **Wzór stylu:** pierwszy gotowy budynek jest „style image” dla następnych. Drwal, kamieniołom i rybak mają podwórko na stos (paczka 2), więc ich chata zajmuje tylko 2 tylne kafle, a podwórko dalej rysuje kod.

**Zmiany w trakcie (ankiety 2026-11-07):**
- **Narzędzie: Pixen zamiast Pro Flash** (`create_image_pixen`, widok „high top-down”, kierunek „south-east”, „highly detailed”, „selective outline”, 1 generacja za obrazek). Pro Flash rysował drzwi na złej (lewej) ścianie, a przemalowanie chaty z kodu dało płaski styl. Właściciel porównał Pro Flash, Pro (4 kandydatów za 10 generacji, najwięcej detali) i Pixen i wybrał Pixen: prawdziwa izometria 2:1 (ściany pod kątem kafli), drzwi po prawej w opisie „door in the gable wall facing the lower right”, prawie darmowy. Pixen nie bierze wzoru stylu, więc spójność trzyma ten sam opis. Lustro obrazka (gdy drzwi wyjdą po lewej) odrzucone, zostaje opis i przeróbka.
- **Etapy budowy i tyły chat:** przeróbka gotowego budynku w Pixenie (`edit_image_pixen`, 1 generacja), na tym samym płótnie, więc leżą dokładnie na budynku. Fundament: „remove the whole building completely… only a flat stone foundation”.
- **Obóz pionierów z osobnych elementów** (prośba właściciela): obóz wygenerowany w całości miał własny grunt w innym kolorze niż nasza ziemia i wychodził poza kratki. Teraz domek z bali, 2 namioty, ognisko z kociołkiem, flaga, drewno i beczka ze skrzynią to osobne obrazki z Pixena, a skrypt `tools/compose_pixellab_camp.py` układa je w rombie 3×3 na naszej trawie (przód wolny na wejście). Etap 1: podłoga domku, jeden namiot i zapasy; etap 2: szkielet domku, oba namioty i ognisko.

**Stan (2026-11-07):** wszystkie 5 budynków z PixelLab w grze: obóz (gotowy i 2 etapy budowy), chata w 3 wyglądach (szachulec ze strzechą, bale z gontem, tynk z łupkiem) z tyłami i 2 etapami budowy (oba także od tyłu), drwal, kamieniarz i rybak z podwórkiem i 2 etapami. Surowe obrazki: `tools/pixellab_src/buildings/` (Godot ich nie importuje), budowa grafik: `python3 tools/build_pixellab_buildings.py` (ART_SPEC §10.12). Test sortowania prawdziwych grafik i ich luster: `test_pixellab_building_art_sorts_correctly`. Zrzuty: `game_shot.tscn -- --map=lakeland --tile=84,64 --zoom=1 --g1=finished` (gotowe) i `--g1=sites` (place budowy). Budżet: zużyte 128 generacji (ok. 67 na próby Pro Flash i Pro, ok. 61 na Pixen), zostało 67 do 27.11. Zapis bez zmian (v17). **Rozjaśnienie wyłączone** (prośba właściciela po pierwszych zrzutach 2026-11-07): Pixen jest sam z siebie tak jasny jak budynki z kodu. **Kolory ujednolicone kodem** (ankieta 2026-11-07: wyrównanie i wspólne odcienie materiałów, `tools/harmonize_pixellab.py`, ART_SPEC §10.12): chata z bali i warsztaty jaśniejsze, obóz spokojniejszy, szarości cieplejsze.

**Skąd ten etap:** budynki rysowane kodem są czytelne, ale „płaskie” obok terenu i menu z PixelLab. Próba 2026-11-07 (ART_SPEC §10.11): obóz pionierów i chata wygenerowane od zera w PixelLab dwoma narzędziami i wstawione na próbę do sceny gry. Wybór właściciela: **Pro Flash** (`create_object_pro_flash`, widok „high top-down”, 1 kierunek, ok. 6–9 generacji za budynek), **rozjaśnione średnio** skryptem `tools/brighten_pixellab.py`. „Obiekt na mapę” odpada (obóz wyszedł jako latająca wysepka ze skarpą). Pliki próby: `src/prototype/g1/`.

**Zakres:** zestaw pionierów, czyli pierwsze minuty gry: obóz pionierów, chata, drwal, kamieniołom, rybak.

**Do rozstrzygnięcia w planie (ankieta):**
- rozmiar względem obrysu (obóz z próby jest mniejszy niż 3×3 kafle) i wejście na właściwym kaflu (drzwi chaty z próby są na prawej ścianie),
- druga orientacja: lustro (światło z drugiej strony) czy osobna generacja,
- etapy budowy (`construction_1`, `construction_2`): z PixelLab na podstawie gotowego budynku czy kodem,
- warianty i tył chaty (`base_2`, `base_3`, `*_back`), kamienice na wyższych poziomach zostają na razie bez zmian,
- miejsca pracy i podwórka widoczne od strony kamery (ART_SPEC §3.2),
- budżet: ok. 195 generacji do 27 listopada.

**DoD:**
- [x] Budynki zestawu pionierów z PixelLab w grze, z pivotem, wejściem i cięciem do sortowania (`test_sorting.gd`), etapami budowy i obiema orientacjami.
- [x] Przepływ pracy opisany w ART_SPEC (opis stylu, rozjaśnienie, przycięcie, pivot), żeby kolejne partie były spójne.
- [x] Testy przechodzą (szybkie i długie).
- [x] **Twoja ocena wyglądu** (2026-11-07: zaakceptowane, po wyłączeniu rozjaśnienia i ujednoliceniu kolorów).

---

## G2 — Towary z PixelLab i stosy sztuka po sztuce

**Status: dopisany i zaplanowany 2026-11-07 na prośbę właściciela (ankieta), po G1, przed M7. Zaakceptowany przez właściciela 2026-11-07 (po ułożeniu desek na krzyż) i scalony do `main`. Etap zamknięty.**

**Stan (2026-11-07):** 21 sztuk z Pixena (płótno 24×24, 21 generacji, bez poprawek), stosy układa `tools/compose_pixellab_stacks.py` (ART_SPEC §10.13): jedna klatka na sztukę (12, 16 albo 20). Gra liczy klatki z arkusza, więc działa to w magazynie, na podwórkach, na ziemi, na placu budowy i w porcie bez osobnych zmian; świnie dalej jako stado (4 klatki). Zrzut: `game_shot.tscn -- --map=lakeland --tile=82,64 --zoom=2 --g2`. Zapis bez zmian (v17). Zostało ok. 46 generacji do 27.11.

**Cel:** każdy towar dostaje grafikę jednej sztuki z PixelLab (Pixen), a kod układa sztuki w stosy ręcznie zaprojektowanym układem (piramida kłód, rzędy worków, beczki na sobie). Stos rośnie o jedną sztukę za każdą sztukę w magazynie, zamiast 4 stanów.

**Decyzje (ankieta 2026-11-07):**
- **Stany stosu:** każda sztuka widoczna (12–20 stanów, tyle ile mieści pole magazynu, `stack_size` towaru).
- **Beczki:** inna beczka dla piwa, wina, miodu pitnego, miodu i smoły.
- **Zakres:** wszystkie 21 towarów (świnia zostaje stadem zwierząt jak dotąd). Budżet: ok. 30–40 generacji z 67 do 27.11.
- Ikony towarów i towary noszone przez ludzi bez zmian (osobny etap, jeśli zechcesz).

**DoD:**
- [x] Sztuka każdego z 21 towarów z PixelLab, ujednolicona kolorystycznie z budynkami G1.
- [x] Stosy układane kodem, jeden stan na sztukę, w magazynie, na podwórkach warsztatów, na ziemi, na placu budowy i w porcie.
- [x] Testy (szybkie i długie), w tym liczba stanów stosu.
- [x] Przepływ pracy w ART_SPEC.
- [x] **Twoja ocena wyglądu** (2026-11-07: zaakceptowane; poprawka: deski warstwami na krzyż).

---

## M7 — Wojsko, mury i oblężenia

**Status: plan zaakceptowany 2026-11-07 (ankieta z właścicielem projektu). Start po N1 „Nabrzeża i port”.**

**Decyzje (ankieta 2026-11-07):**
- **Trzy części, ocena po każdej:** (1) metale, broń, koszary i rekrutacja; (2) mury, bramy i walka w widoku prowincji; (3) armie na mapie świata, `BattleResolver`, oblężenia nieoglądane i okręt wojenny.
- **Przeciwnik w M7: bandyci i osady neutralne.** Bandyci z obozu w pustej prowincji co jakiś czas napadają na gracza (rzadko, słabo). Osadę neutralną można zdobyć siłą zamiast wykupu: ma mury i straż. Władcy AI dalej w M8.
- **Sterowanie jak w Twierdzy:** klik albo ramka zaznacza żołnierzy, prawy przycisk na ziemi to „idź”, na wrogu „atakuj”, Ctrl+1..9 zapamiętuje grupę, przyciski postawy: atakuj sam, broń się, stój w miejscu.
- **Przejęcie: rozbić drzwi ratusza** (albo obozu pionierów). Ratusz ma wytrzymałość jak brama; gdy drzwi padną, a przy ratuszu nie ma obrońców, napastnik zajmuje prowincję. Mieszkańcy i budynki zostają, zadowolenie spada (wartość niżej).
- **Ruda żelaza: małe złoża wszędzie.** Każda mapa ma kilka żył rudy w skałach, a prowincja z rudą (Żelazny Gród) ma ich dużo. Konie zostają rzadkie (stadnina tylko w prowincji z pastwiskami).
- **Żołnierz mieszka w koszarach:** rekrut wyprowadza się z domu (dom przyjmuje przybysza), śpi w koszarach i je z magazynu. ~~Do tego dostaje żołd.~~ **Zmiana 2026-11-08 (właściciel): bez żołdu, jak w Twierdzy i Anno; za to rekrutacja kosztuje 2 razy więcej (ankieta).** Rekrut zwalnia miejsce w domu, żołnierze nie zajmują miejsc mieszkańców.

**Część 1, decyzje (ankieta 2026-11-07, start części):**
- **Grafika:** nowe budynki i towary z PixelLab (przepływ ART_SPEC §10.12–10.13), postacie i żołnierze rysowane kodem, jak najstaranniej i najbardziej szczegółowo.
- **Kowal:** przełącznik w panelu: włócznie, miecze albo na zmianę (domyślnie na zmianę).
- **Brak jedzenia:** na razie bez kary (wrócimy przy balansie). Żołdu nie ma (zmiana 2026-11-08).
- **Żołnierze w części 1:** stoją w szeregu na placu przed koszarami i co jakiś czas ćwiczą. Sterowanie w części 2.

**Część 1, stan (2026-11-07): gotowa, scalona do `main` 2026-11-08 przed oceną (decyzja właściciela: przetestuje hurtem później).**
- Towary: węgiel drzewny, ruda żelaza, żelazo, włócznia, łuk, miecz, kolczuga, koń. Broń trafia tylko do zbrojowni (zwykły magazyn jej nie przyjmuje).
- Żyły rudy: część skał na każdej mapie (6, najwyżej 1/3 skał; w Żelaznym Grodzie 24), też w starych zapisach (migracja). Kopalnię stawia się tylko w zasięgu 6 kafli od żyły; żyła ma 40 rudy.
- Budynki (kategoria „Wojsko”): węglarz, kopalnia, huta, kowal (przełącznik: włócznie, miecze, na zmianę), płatnerz, łuczarz, stadnina (tylko z pastwiskami, start z parą koni, stado do 6), zbrojownia 3×3 (8 pól), koszary 3×3 (24 łóżka). Koszty budowy wyjściowe: w `data/buildings/`.
- Rekrutacja w panelu koszar: przycisk na każdy rodzaj wojska z wymaganiami w podpowiedzi. Rekrut to wolny mieszkaniec (bez pracy), wychodzi z domu, idzie po broń (i konia), przebiera się i wchodzi do koszar. Cena jednorazowa: włócznik 20 zł, łucznik 30, miecznik 60, jeździec 100; żołdu nie ma (2026-11-08). Tragarze noszą do koszar chleb, ryby albo mięso; brak jedzenia: bez kary (decyzja).
- Szeregi: do 16 żołnierzy na placu przed drzwiami (2 na kafel), reszta w środku; co 14 s wszyscy razem ćwiczą przez 8 s. Koszar z żołnierzami nie da się rozebrać.
- Grafika: 9 budynków z etapami budowy i 7 towarów z PixelLab (ART_SPEC §10.14, zostało 9 generacji do 27.11), postacie, żołnierze i koń kodem.
- Zapis v18 (ARCHITECTURE §8). Testy: `tests/scenario/test_m7_military.gd`.
- Zrzuty: `game_shot.tscn -- --map=lakeland --tile=84,64 --zoom=1 --m7=finished|sites`, wojsko: `--zoom=2 --m7=army [--drill]`.

**Część 2, stan (2026-11-08): gotowa, scalona do `main` 2026-11-08 na prośbę właściciela (po poprawce cieni obróconej bramy).**
- **Mury w grze (A):** palisada (2 drewna na kafel), mur kamienny (3 kamienie) i schody (4 kamienie, tylko przy murze kamiennym, wieży bramnej albo baszcie) rysuje się linią w 8 kierunkach (zakładka „Obrona”); budowniczy kładzie je kafel po kaflu, tragarze noszą materiał (jak bruk i nabrzeża). Mur kamienny to model bryłowy z prototypu (rzędy zlewają się w gruby mur, ukosy „prosto” z klinami, blanki) z kamieniem z PixelLab; palisada i schody kodem. Wieża bramna (3×3, grafika z PixelLab z prototypu, 30 kamieni i 10 desek) i baszta (2×2, o 48 px wyższa od muru, 20 kamieni) to budynki, które stawia się też w linii muru (zastępują go). Przejście bramy jest otwarte dla swoich, zamknięte dla wroga. Mur nie może odciąć części miasta (trzeba zostawić bramę). Każdy kafel ma życie (palisada 300, mur 1000, schody 400), brama, baszta i drzwi ratusza (oraz obozu pionierów) 1500.
- **Chodzenie po murach i sterowanie (B):** korona muru, wieży bramnej i baszty to osobna „mapa chodzenia”; na górę prowadzą schody, drabiny, drzwi baszty i przejście wieży bramnej (dwa ostatnie tylko dla swoich). Klik albo ramka zaznacza żołnierzy, prawy przycisk wysyła ich w szyku (2 na kafel; kliknięcie w koronę = na mur) albo na wroga, Ctrl+1..9 zapamiętuje grupę, 1..9 ją wybiera; panel wojska: postawy (atakuj sam, broń się, stój w miejscu) i „Wróć do koszar”. Żołnierz w szeregu zaatakowany sam się broni.
- **Walka (C):** ciosy i strzały (strzała leci łukiem i trafia po chwili, gdy cel nie uciekł), wartości z tabeli niżej; łucznik na murze strzela o 2 kafle dalej, a każdy na murze dostaje od strzał połowę obrażeń. Polegli leżą chwilę na ziemi. **Warsztat oblężniczy** (3×3, 20 desek, 6 kamieni, 40 zł, grafika kodem) buduje na zamówienie taran (20 desek, 4 żelaza, obsługa 4 mieszkańców, 60 s, życie 500, cios 150 w mury i bramy, strzały 1/5) i drabiniarza (4 deski, 1 mieszkaniec, 15 s). Drabina oparta o mur kamienny to droga na mur dla każdego; obrońca stojący na murze nad drabiną bez wroga przy niej zrzuca ją.
- **Bandyci (D):** pierwszy napad po 40 minutach gry, potem co 25–40 minut, ostrzeżenie 60 s wcześniej; 4–8 bandytów (co trzeci z łukiem), 2 drabiniarzy, gdy miasto ma mury kamienne, co trzeci napad z taranem, gdy jest brama. Wchodzą od krawędzi mapy i idą do drzwi ratusza; co stoi na drodze (palisada, mur, brama), rozbijają, z żołnierzami walczą. Mieszkańcy w promieniu 7 kafli od bandyty rzucają pracę i chowają się w ratuszu, potem wracają. Drzwi rozbite i nikt ich nie broni (żołnierz w promieniu 6 kafli): łup (30% złota, najwyżej 300, i po 12 sztuk 3 towarów, których jest najwięcej), zadowolenie −30 przez 10 minut, bandyci odchodzą. Po napadzie drzwi i bramy są naprawione, mury zostają uszkodzone. Pełne przejęcie prowincji (`Raids.capture`) gotowe na część 3. Do prób: F7 = napad teraz, w menu „Narzędzia” „Gra z szybkim napadem” (pierwszy po 2 minutach). Napady tylko w oglądanej prowincji.
- Zapis v19 (ARCHITECTURE §8). Testy: `tests/scenario/test_m7_walls.gd`, `test_m7_troops.gd`, `test_m7_raids.gd`.
- Zrzuty: `game_shot.tscn -- --map=lakeland --tile=84,64 --zoom=1 --m7=walls`, `--tile=82,70 --zoom=2 --m7=battle`, `--tile=82,72 --focus=79,80 --zoom=2 --m7=raid --raid_seconds=14`. Grafika: `"$GODOT" --headless --path . -s res://tools/make_wall_skin.gd`, `xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 -s res://tools/render_fort_art.gd`.
- Świadomie uproszczone: mury nie są naprawiane (trzeba je zburzyć i postawić od nowa), brama po skosie i hurdycje później, w trybie uproszczonym nie ma napadów ani walki, łucznicy nie strzelają do machin z ukrycia inaczej niż do ludzi, wydajność 300 walczących do sprawdzenia na laptopie.

**Wartości wyjściowe (do strojenia przy realizacji):**
- jednostki: włócznik (włócznia, ~~10~~ 20 zł, życie 100, cios 10, ×2 przeciw jeźdźcom), łucznik (łuk, ~~15~~ 30 zł, życie 70, strzała 8, zasięg 7 kafli; na murze +2 kafle i połowa obrażeń), miecznik (miecz i kolczuga, ~~30~~ 60 zł, życie 160, cios 16), jeździec (koń, miecz i kolczuga, ~~50~~ 100 zł, życie 200, cios 18, 2× szybszy); taran (20 desek, 4 żelaza, pcha go 4 żołnierzy), drabina (4 deski, niesie 1 żołnierz); ~~żołd 1 zł na minutę~~ bez żołdu (2026-11-08),
- łańcuchy: węglarz (2 drewna → 1 węgiel drzewny, 40 s), kopalnia przy żyle rudy (ruda co 45 s), huta (ruda + węgiel → żelazo, 40 s), kowal (żelazo + deska → 2 włócznie albo żelazo → miecz, 45 s), płatnerz (2 żelaza → kolczuga, 60 s), łuczarz (2 deski → łuk, 30 s), stadnina (koń co 120 s, tylko pastwiska), zbrojownia 3×3 (magazyn broni), koszary 3×3 (60 zł, 24 łóżka),
- mury: palisada (2 drewna na kafel, wytrzymałość 300), mur kamienny (3 kamienie, 1000), wieża bramna 3×3 (30 kamieni, 10 desek, 1500), baszta 2×2 (20 kamieni, 1500), schody (4 kamienie); drzwi ratusza 1500; po przejęciu zadowolenie −30 przez 10 minut,
- świat: armia nosi zapas jedzenia (1 chleb na 10 żołnierzy na minutę), w prowincjach gracza uzupełnia go z magazynu; okręt wojenny wiezie 30 żołnierzy i powstaje w stoczni etapami jak koga,
- zapis: kolejne wersje po N1 (po jednej na część).

**Zakres:**
- metale i broń (kopalnia, huta, kowal, płatnerz, łuczarz), zbrojownia,
- koszary i rekrutacja,
- mury, bramy, baszty i schody w rozgrywce, chodzenie po murach,
- walka w widoku prowincji: sterowanie oddziałami, łucznicy na murach, taran, drabiny,
- armie na mapie świata,
- `BattleResolver` dla bitew polowych, **morskich (automatycznie)** i oblężeń nieoglądanych,
- okręt wojenny jako jednostka transportowa i bojowa (tylko rozstrzyganie automatyczne).

**DoD:**
- [ ] Oblężenie od wejścia armii do przejęcia ratusza jest grywalne i czytelne.
- [ ] Wyniki rozstrzygania automatycznego są rozsądne według tabeli testów.
- [ ] 300 żołnierzy i cywilów w walce przy 60 FPS.

---

## B1 — Most przez rzekę i łagodniejszy brzeg

**Status: plan zaakceptowany 2026-11-08; część 1 (most) i część 2 (brzeg) gotowe i scalone do `main` 2026-11-08 na prośbę właściciela, przed oceną.** Wybór etapu: ankieta z właścicielem projektu 2026-11-08 (zamiast M8 i rejsów w oknie mapy świata). Mały etap jak N1, po M7, niezależny od oceny wojska. Pomysł gracza z oceny M5 (IDEAS: „Most przez rzekę i mniej kanciaste wybrzeże”). Poprawki z oceny M7 (i pomiar 300 walczących) mają pierwszeństwo przed dalszą pracą.

**Decyzje (ankieta 2026-11-08):**
- **Dwa rodzaje mostu:** drewniany (tani, jak droga ubita) i kamienny (droższy, jak bruk, z łukami).
- **8 kierunków** (wbrew rekomendacji „tylko prosto”, decyzja właściciela): most stawia się jak nabrzeże i mur, także po skosie; skos ma kliny po bokach każdego kroku (jak skos nabrzeża, ARCHITECTURE §6.3), więc ludzie i wozy po nim przejdą, a boki biegną prosto.
- **Nad wodą tylko budynki przy wodzie:** port, stocznia i przystań jak dotąd, a do tego wędkarz, glinianka, dźwig i magazyn portowy mogą mieć najwyżej 1 rząd kafli nad płytką wodą (morze, jezioro, brzeg rzeki) na palach, wejście na lądzie; nie mogą zagrodzić rzeki ani odciąć statków. Inne budynki bez zmian.
- **Mapy bez zmian:** miękki brzeg robi tylko rysowanie terenu; stare zapisy, automatyczny gracz i testy zostają.
- **Rampy na lądzie (prośba właściciela 2026-11-08, w trakcie części 1):** most zaczyna się i kończy na lądzie, po kaflu na każdym brzegu; boki i poręcze schodzą tam do ziemi, żeby most nie urywał się nad wodą. Rampa liczy się jako kafel mostu (materiał, rozbiórka), drzewo w jej miejscu jest ścinane, droga może pod nią zostać.
- **Most z drogi (prośba właściciela 2026-11-08, w trakcie części 1):** droga przeciągnięta przez rzekę sama zamawia nad wodą most drewniany, a bruk most kamienny (z rampami); podgląd pokazuje cały most. Gdy przeciągnięcie biegnie po skosie, most idzie prosto, a krótki kawałek drogi łączy jego koniec z resztą drogi. Nad wodą, gdzie most już stoi albo jest zamówiony, nic nowego się nie zamawia.

**Część 1, stan (2026-11-08): gotowa, scalona do `main` przed oceną** (po prośbie właściciela: kusza z wygiętym łęczyskiem i prostą cięciwą).
- Most drewniany i kamienny przeciąga się od brzegu do brzegu (przyciski „Most” i „Most kamienny” obok „Drogi”), w 8 kierunkach, najwyżej 8 kafli wody, z rampą na każdym brzegu; podgląd całej linii na zielono albo czerwono, całość albo nic. Budowniczy kładzie kafel po kaflu od bliższego brzegu (6 s), tragarze noszą deski albo kamień. Ludzie chodzą po moście jak po drodze albo bruku, wózki bez kary za jazdę poza drogą, wozy jeżdżą (most to droga). Rozbiórka zabiera cały most (nie, gdy ktoś na nim stoi) albo zamówienie.
- Most po skosie (na ekranie pionowy) ma wyraźne poręcze: słupki wychylone nad wodę z żerdzią na górze, a kamienny murek z jasnym zwieńczeniem (prośba właściciela 2026-11-08).
- Droga przez rzekę zamawia most drewniany, bruk most kamienny (`ProvinceSim.road_crossings`).
- Pasek budowy zawija narzędzia do drugiego wiersza, gdy ekran jest za wąski (przy 1280 px „Rozbiórka” i „Schowaj” wypadały poza ekran).
- Grafika kodem (`BridgeLayer`, ART_SPEC): łuki kamiennego mostu, pale drewnianego, poręcze i murki w świecie, rampy.
- Zapis v21 (ARCHITECTURE §8). Testy: `tests/scenario/test_b1_bridges.gd`.
- Zrzut: `game_shot.tscn -- --map=coast --tile=58,34 --zoom=2 --bridges [--focus=58,41]`.
- Uproszczenia: w trybie uproszczonym budowa mostu czeka jak bruk; burzenie mostu nie zwraca materiału; ruchome wozy na moście nie blokują rozbiórki.


**Część 2, stan (2026-11-08): gotowa, czeka na ocenę właściciela** (start na prośbę właściciela przed oceną części 1).
- **Miękki brzeg (tylko wygląd, mapy bez zmian):** granica wody i lądu oraz płycizny i głębiny morza jest liczona z wygładzonej „mapy wody” z 4×4 sąsiednich kafli, więc schodki po kaflach stają się łagodnym skosem, a narożniki się zaokrąglają. Linia brzegu marszczy się słabiej niż inne granice terenu (łagodne zakola zamiast ząbków). Środek każdego kafla (pas 0,14 kafla od środka) zostaje taki, jaki jest naprawdę, więc ląd pod ludźmi i budynkami nie wygląda jak woda. Piana, płycizna i skarpa idą za nową linią.
- **Budynki na palach:** chata wędkarza, glinianka, dźwig i magazyn portowy mogą stać jednym skrajnym rzędem nad płytką wodą (płytkie morze, jezioro, rzeka, bród; nie głębokie morze), resztą na lądzie (dźwig i magazyn portowy dalej na nabrzeżu). Za palami muszą zostać jeszcze 2 kafle wody (rzeka nie zostaje zagrodzona, także przez budynek po drugiej stronie), nie mogą zająć toru wodnego, miejsca cumowania ani odciąć łodzi od morza. Pod rzędem nad wodą jest pomost na palach, rysowany tym samym kodem co pomosty.
- Zapis bez zmian (v21): to tylko wygląd i reguła stawiania.
- Testy: `tests/scenario/test_b1_shore.gd`.
- Zrzuty: brzeg przed i po `game_shot.tscn -- --map=coast --tile=66,60 --zoom=2 [--hard_shore]` (też `--map=lakeland --tile=82,36 --zoom=1`, `--map=islands --tile=70,84 --zoom=1`); budynki na palach `--map=coast --tile=62,58 --zoom=2 --stilts=fishing_hut,clay_pit,fishing_hut`.
- Do sprawdzenia na laptopie: płynność (shader liczy więcej przy brzegu).

**Podział: 2 części, ocena po każdej.**
- **Część 1: most.** Most przez rzekę (i bród, i wąskie miejsce jeziora), po którym chodzą ludzie i jeżdżą wózki i wozy. Stawiany jak droga: przeciągnięcie od brzegu do brzegu, budowniczy kładzie kafel po kaflu, tragarze noszą materiał. Zapis v21.
- **Część 2: łagodniejszy brzeg.** Linia brzegu morza, jeziora i rzeki rysowana miękko, bez „schodków” po kaflach; budynki na brzegu mogą częściowo stać nad wodą (zasady według ankiety).

**Wartości wyjściowe (do strojenia przy realizacji):**
- most drewniany: 3 deski na kafel; most kamienny: 4 kamienie na kafel,
- tylko na wodzie rzeki, brodzie i jeziorze (nie na morzu: tam są nabrzeża N1), najwyżej 8 kafli wody między brzegami (krok po skosie liczy się jako 1), oba końce na lądzie; w 8 kierunkach (skos z klinami); szerokość 1 kafel, rzędy obok siebie łączą się w szerszy most,
- ludzie chodzą po moście jak po drodze ubitej (drewniany) albo bruku (kamienny); most jest drogą także dla wózków i wozów,
- na moście nie stawia się budynków, pól ani murów; rozbiórka całego mostu albo od końca,
- budowa jak bruk i nabrzeża: budowniczy stoi na brzegu albo na ułożonym kawałku i kładzie 6 s na kafel,
- grafika rysowana kodem, jak nabrzeża (`QuayLayer`): pomost drewniany na palach z poręczami albo kamienny z łukami, które schodzą do wody; pokład na wysokości lądu, więc ludzie i wozy chodzą na tej samej wysokości co na brzegu,
- zapis: v21 (część 1); część 2 bez zmiany formatu (tylko wygląd i reguła stawiania).

**Zakres:**
- część 1: warstwa mostów w siatce, przejezdność dla ludzi i wozów (siatki ruchu), polecenie budowy i rozbiórki, plac budowy mostu (jak bruk i nabrzeża), narzędzie w pasku budowy z podglądem na zielono albo czerwono i kosztem, panel kafla mostu, most w trybie uproszczonym (czeka jak bruk, ARCHITECTURE §7), grafika kodem z przypadkami sortowania w `test_sorting.gd`, zapis v21 z migracją, fixturą i testami, teksty PL i EN, aktualizacja GDD, ARCHITECTURE §5.3 i ART_SPEC,
- część 2: miękka linia brzegu w shaderze terenu (morze, jezioro, rzeka: zaokrąglone narożniki, skos zamiast schodków; piana, płycizna i skarpa idą za nową linią), budynki przy wodzie (wędkarz, glinianka, dźwig, magazyn portowy) z 1 rzędem na palach nad płytką wodą (pale tym samym kodem co pomost), zrzuty przed i po na „Wybrzeżu”, „Pojezierzu” i „Wyspach”.

**Poza zakresem:** mosty na morzu i zwodzone, burzenie mostów przez wroga i bitwy o most, łodzie i statki na rzekach, przewozy promem, zmiana kształtu map w danych (ankieta 2026-11-08), inne budynki nad wodą.

**Ryzyka etapu:**
- most zmienia siatki ruchu ludzi i wozów; ostrożnie z bramami i murami (mur nie może odciąć miasta) i z wyliczaniem zasięgu usług. Ochrona: testy siatek i ścieżek wozów,
- miękki brzeg w widoku nie pokrywa się dokładnie z kaflami: postać może wyglądać, jakby stała na wodzie, albo budynek wisiał nad nią. Ochrona: brzeg miękki tylko w pasie ok. pół kafla, zrzuty z postaciami przy brzegu,
- wydajność shadera terenu na laptopie (więcej próbek przy brzegu). Ochrona: tani test „czy blisko brzegu” przed dokładnym liczeniem, jak przy ujściach rzek.

**DoD:**
- [x] Most stawia się przeciągnięciem od brzegu do brzegu, budowa idzie przez budowniczego i tragarzy; ludzie i wozy chodzą po moście (testy ścieżek).
- [x] Na „Wybrzeżu” most skraca drogę na wschód mapy (zrzut i test ścieżki: z 23 do 13 kroków przy moście w rzędzie 35).
- [x] Zapis v21 z migracją; stare zapisy wczytują się bez mostów (test na zapisie v16; osobna fixtura v21 niepotrzebna, bo zapis mostu sprawdza test zapisu i odczytu).
- [x] Brzeg morza, jeziora i rzeki jest miękki, bez schodków po kaflach (zrzuty przed i po).
- [x] Wędkarz, glinianka, dźwig i magazyn portowy stoją 1 rzędem na palach nad płytką wodą (testy reguły, zrzuty).
- [x] UI w PL i EN, nowe teksty przez klucze tłumaczeń.
- [ ] **Twoja ocena gry** (po każdej części).

---

## W1 — Nowe wybrzeże na mapie „Wybrzeże”

**Status: gotowy i scalony do `main` 2026-11-08 na prośbę właściciela, przed oceną** (plan zaakceptowany 2026-11-08, ankieta: zatoka szeroka i zaokrąglona, jak podkowa). Prośba właściciela 2026-11-08; ankieta: **teraz, mały etap** (przed oceną M7 i B1), przed J1, bo większe okręty z J1 potrzebują szerszej zatoki.

**Stan (2026-11-08):**
- Brzeg morza na południu i wschodzie to łagodne zakola i cyple (szum w dwóch skalach) zamiast prostych odcinków ze schodkami; wschodni brzeg zakręca w południowy łukiem.
- Zatoka jak podkowa: ok. 26 kafli szerokości (dotąd 13) i ok. 22 długości (dotąd 32), z płaskim dnem (ok. 16 kafli) i zaokrąglonymi rogami. Płaskie dno jest celowe: przystań rybacka i stocznia nie obracają się na wodzie i potrzebują prostego brzegu (znalazły go dzięki temu przy dnie zatoki). Rzeka wpada w róg dna zatoki.
- Lądowanie: koga kotwiczy w (75, 86), plaża w (70, 86), tuż pod placem miasta; za plażą jest otwarta łąka (bez lasu) aż do placu.
- Automatyczny gracz z portem: stocznia na brzegu morza na wschód od wejścia do zatoki (zachodnią stronę zajmuje miasto), ponawia próbę, gdy ktoś stoi w miejscu budowy. Testy znające stare miejsca szukają ich teraz same.
- Zapis bez zmian (stare gry mają stary teren).
- Zrzut: `game_shot.tscn -- --map=coast --tile=76,90 --zoom=0 --advance=20`; mapa: `python3 tools/generate_coast_map.py`.

**Cel:** linia brzegowa „Wybrzeża” jest bardziej naturalna, a zatoka szersza i krótsza, nie prostokątna. Jedna część, ocena po niej.

**Zakres:**
- generator mapy (`tools/generate_coast_map.py`): brzeg morza z łagodnych zakoli i cypli zamiast prostych odcinków ze schodkami; zatoka mniej więcej dwa razy szersza i o jedną trzecią krótsza, zaokrąglona, z ujściem rzeki; płycizna i głębina według odległości od lądu jak dotąd; ławice w morzu,
- przestawienie wszystkiego, co zależy od kształtu mapy: miejsce kotwiczenia kogi i plaża lądowania (start ze statku), plac miasta, wejście z zachodu, ławice, automatyczny gracz z portem (`harbour_bot`), testy i zrzuty, które używają konkretnych kafli „Wybrzeża”,
- zrzuty przed i po (mapa w całości i zatoka z bliska).

**Poza zakresem:** zmiana innych map, zmiana zasad stawiania portu i nabrzeży.

**Ryzyka:** automatyczny gracz i testy lądowania znają dzisiejsze miejsca; po zmianie trzeba je przestawić i sprawdzić długimi testami. Stare zapisy nie zmieniają się (zapis pamięta swój teren); nowy kształt widać w nowej grze.

**DoD:**
- [x] Zatoka szersza i krótsza, zaokrąglona; brzeg morza bez prostych odcinków ze schodkami (zrzuty przed i po).
- [x] Start ze statku działa: koga kotwiczy w zatoce, osadnicy brodzą na plażę (test lądowania).
- [x] Automatyczny gracz z portem buduje port, nabrzeża, dźwig i kogę (długi test).
- [x] `tools/run_tests.sh --all` przechodzi.
- [ ] **Twoja ocena gry.**

---

## J1 — Nowe jednostki i okręty

**Status: plan zaakceptowany 2026-11-08 (ankiety); część 1 gotowa i scalona do `main` 2026-11-08 na prośbę właściciela (przed oceną); część 2 gotowa i scalona do `main` 2026-11-08 (przed oceną); część 3 zaakceptowana i scalona do `main` 2026-11-09; etap J1 zamknięty.** Prośba właściciela 2026-11-08; ankieta: **teraz, przed oceną M7** (świadome ryzyko: jeśli ocena M7 zmieni zasady walki, część wartości trzeba będzie poprawić). Start po W1.

**Cel (prośba właściciela):**
- jednostki: **halabardnik w zbroi płytowej**, **kusznik**, **ciężki zbrojny z morgensternem**, **lekka jazda**, **ruchoma balista**,
- **3 nowe okręty**, każdy w wersji cywilnej (handel, ładownia) i wojennej (żołnierze, walka automatyczna), każdy większy od poprzedniego (w granicach rozsądku; koga zostaje najmniejszym statkiem pełnomorskim),
- **duża stocznia**, w której powstają nowe okręty.

**Część 1, stan (2026-11-08): gotowa, czeka na ocenę właściciela.**
- Jednostki: halabardnik, kusznik, ciężki zbrojny, lekka jazda (wartości jak w tabeli wyżej); rekrutuje się je w koszarach jak dotąd (przyciski pojawiają się same, szare, gdy brak broni). Lekka jazda bierze konia ze stadniny i włócznię.
- Broń: kowal ma 4 wyroby (włócznie, miecze, halabardy, morgensterny) albo „na zmianę”; łuczarz łuki albo kusze (albo na zmianę); kusznik zanosi najpierw deski do warsztatu, potem idzie po żelazo (jak kowal przy włóczniach). Zbroja: kolczuga ma teraz nazwę „zbroja”.
- Grafika kodem: postacie i ruchy walki (ART_SPEC §10.17), kawałki broni, stosy, ikony i broń w rękach.
- Tabela bitew uzupełniona: halabardnicy zatrzymują jeźdźców, lekka jazda rozbija kuszników, ciężcy zbrojni biją tylu samo mieczników, kusze przebijają zbroje, jeźdźcy biją lekką jazdę.
- Zapis bez zmian (nowe dane, ten sam format).
- Testy: `tests/scenario/test_j1_units.gd`, `tests/unit/sim/military/test_battle_resolver.gd`.
- Zrzuty: `game_shot.tscn -- --map=lakeland --tile=84,64 --zoom=3 --m7=army2 [--drill]`, panele `--zoom=1 --m7=finished --select=blacksmith|bowyer|barracks`.
- Uwaga: łuczarz i kowal „na zmianę” robią teraz też nową broń. Kusza potrzebuje żelaza: bez żelaza kolejka na kuszę się nie udaje i łuczarz traci chwilę, a łuki dalej powstają. Kto chce samych łuków, wybiera „Robienie łuków”.

**Część 2, stan (2026-11-08): gotowa, scalona do `main` przed oceną.**
- **Balista:** zamawia się ją w warsztacie oblężniczym obok taranu i drabiniarza (16 desek, 4 żelaza, obsługa 2 wolnych mieszkańców, 45 s). Wychodzi jako jedna machina pod rozkazami gracza, jedzie wolno (0,4).
- **Walka:** strzela jak łucznik, ale z 10 kafli, ciężkim bełtem (60 co 5 s), ×3 przeciw taranom i innym balistom; sama dostaje od strzał połowę obrażeń. Rozkaz „rozbij” na mur albo bramę: balista staje w zasięgu i strzela z daleka, bełt w mur liczy się jako 1/5 (12). Napady bandytów jej nie używają.
- **Bitwy automatyczne:** balista strzela w salwach jak łucznik, nie liczy się do ucieczki wojska (jak taran), w oblężeniu powoli kruszy mur albo bramę. Tabela bitew: dwie balisty przechylają równą walkę, balisty z ludźmi biorą palisadę.
- **Wygląd (kod, `SiegeLayer`):** wielka kusza na dwóch kołach ze szprychami, kozioł pod nosem, ramiona wiązane żelazem, cięciwa naciągnięta do kołowrotu z bełtem w rowku, po strzale prosta; dwóch obsługujących za kołowrotem (pchają przy jeździe, kręcą po strzale), proporczyk. Bełt w locie jest długi i gruby, leci płasko.
- **Zapis v22** (bełty w locie: „b” i „w”; migracja bez zmian).
- Testy: `tests/scenario/test_j1_ballista.gd`, tabela w `test_battle_resolver.gd`.
- Zrzut: `game_shot.tscn -- --map=lakeland --tile=78,66 --focus=80,67 --zoom=2 --m7=ballista --raid_seconds=5.3`.

**Część 3, stan (2026-11-08): zaakceptowana 2026-11-09 i scalona do `main`** (wygląd według referencji właściciela: karawela Pinta, karaka Victoria, galeon).
- **Duża stocznia** (zakładka „Morze i statki”): 6×6, pochylnia trzy rzędy w głąb wody między dwoma pasami nabrzeża, szopa na kamiennym podmurowaniu, dwa dźwigi; 30 desek, 30 drewna, 20 kamieni, 150 zł; 2 cieśli. Buduje tylko nowe okręty (koga i okręt wojenny dalej w zwykłej stoczni). Potrzebuje prostego brzegu na 6 kafli i głębokiej wody przed pochylnią: na „Wybrzeżu” mieści się na południowym brzegu morza (nie w zatoce).
- **Okręty** (każdy w 4 etapach jak koga): karawela (ładownia 6 pól, najszybsza, 1,5), karaka (9 pól, 1,1), galeon (12 pól, 1,2); handlowe pływają w rejsy i szlaki jak koga. Wojenne: 40, 60 i 90 żołnierzy; w bitwie morskiej kadłub 1000, 1600, 2400 i bełty 40, 60, 90 (okręt wojenny: 800 i 30). Koszty: `data/ships/`.
- **Bitwa morska po rodzajach okrętów:** armia na morzu pamięta swoją flotę (ile jakich okrętów), bitwa liczy kadłub, bełty i miejsce na żołnierzy każdego rodzaju; **zatopione okręty nie wracają** (dotąd wracały wszystkie, luka z M7 część 3).
- **Grafika kodem** (`tools/render_cog.py --type=caravel|carrack|galleon`, ART_SPEC §10.18): okrągłe, wysokie kadłuby z burtami zwężającymi się ku górze, dziób i rufa wystające nad wodę, kasztele wyrastające z kadłuba (galeon i karaka w dwóch kondygnacjach), ochrowe relingi z tralkami, ciemne listwy, okna rufowe, furty galeonu; maszty z żaglami jeden nad drugim, bocianie gniazda, żagle łacińskie na tylnych masztach, bukszpryt z żaglem, proporce; krzyż w barwie frakcji na żaglach. Wersje wojenne z tarczami w czerwieni.
- **Zapis v23** (flota armii; starsze armie miały same okręty wojenne).
- Testy: `tests/scenario/test_j1_ships.gd`.
- Zrzut: `game_shot.tscn -- --map=coast --tile=27,100 --focus=26,107 --zoom=1 --j1ships`.

**Podział (propozycja): 3 części, ocena po każdej.**
1. **Piechota i jazda:** nowe towary i ich wytwarzanie (halabarda, kusza, morgenstern, zbroja płytowa), rekrutacja w koszarach, wartości walki w widoku prowincji i w rozstrzyganiu automatycznym, postacie z animacjami.
2. **Ruchoma balista:** budowa w warsztacie oblężniczym, obsługa, strzał z daleka (ludzie, machiny, mury i bramy), rozstawianie i przetaczanie.
3. **Duża stocznia i 3 okręty:** budowa etapami jak koga, wersje cywilne (większa ładownia, szlaki i rejsy) i wojenne (więcej żołnierzy, siła w bitwie morskiej rozstrzyganej automatycznie), grafika coraz większych statków, sprawdzenie, że mieszczą się w zatoce i przy nabrzeżach.

**Decyzje (ankieta 2026-11-08):**
- **Okręty: karawela, karaka i galeon**, w tej kolejności rozmiaru (wybór kolejności zostawiony Claude): karawela lekka i szybka, trochę większa od kogi; karaka z wysokimi nadbudówkami i kilkoma masztami; galeon największy.
- **Broń z rozszerzonych warsztatów:** kowal robi też halabardy i morgensterny, łuczarz kusze. **Zbroja jedna dla wszystkich:** dzisiejsza kolczuga zostaje tym samym towarem (id `chainmail` bez zmian), ale dostaje ogólniejszą nazwę „zbroja”, pasującą do miecznika, jeźdźca, halabardnika i ciężkiego zbrojnego.

- **Balista (ankieta 2026-11-08):** buduje ją warsztat oblężniczy, obsługa 2 ludzi, pchana wolno; strzela daleko (ok. 10 kafli) ciężkim bełtem: zabija ludzi, mocno rani taran i inną balistę, mury i bramy uszkadza słabo.
- **Role jednostek (ankieta):** halabardnik dużo życia i ×2,5 przeciw jeździe, wolniejszy; kusznik strzela trochę bliżej niż łucznik, rzadziej, ale bardzo mocno i przebija zbroje; ciężki zbrojny z morgensternem najmocniejszy cios i dużo życia, wolny; lekka jazda najszybsza, tańsza, słabsza, ×2 przeciw łucznikom i kusznikom.
- **Okręty (ankieta):** liczby jak w tabeli niżej; koga zostaje w zwykłej stoczni, nowe okręty tylko w dużej.
- **Grafika (ankieta):** żołnierze, balista i okręty rysowane kodem, w stylu M7 (te same animacje).

**Wartości wyjściowe (do strojenia przy realizacji):**
- halabardnik: halabarda i zbroja, 80 zł, życie 180, cios 14 co 1,6 s, prędkość 0,9, ×2,5 przeciw jeźdźcowi i lekkiej jeździe,
- kusznik: kusza, 50 zł, życie 80, bełt 22 co 3,5 s, zasięg 6 kafli, prędkość 0,95, ×1,5 przeciw jednostkom w zbroi (miecznik, jeździec, halabardnik, ciężki zbrojny),
- ciężki zbrojny: morgenstern i zbroja, 90 zł, życie 220, cios 26 co 2 s, prędkość 0,8,
- lekka jazda: koń i włócznia, 60 zł, życie 120, cios 12 co 1,3 s, prędkość 2,4, ×2 przeciw łucznikowi i kusznikowi,
- broń: kowal robi też halabardy (żelazo i deska) i morgensterny (żelazo), łuczarz kusze (2 deski i żelazo); zbroja: dzisiejsza kolczuga pod nazwą „zbroja”,
- balista: 16 desek, 4 żelaza, obsługa 2, budowa 45 s, życie 300, bełt 60 co 5 s, zasięg 10 kafli, ×3 przeciw machinom, w mury ×0,2, prędkość 0,4,
- okręty (cywilny / wojenny): karawela ładownia 6 pól, szybkość 1,5 / 40 żołnierzy; karaka 9 pól, 1,1 / 60 żołnierzy; galeon 12 pól, 1,2 / 90 żołnierzy; siła w bitwie morskiej rośnie z rozmiarem; duża stocznia z głęboką wodą przy pochylni.

**Ryzyka:** dużo grafiki (5 nowych postaci z animacjami walki, 6 wersji okrętów, duża stocznia); balans walki przed oceną M7; większe okręty a szerokość zatoki i torów wodnych (dlatego W1 najpierw); zapis: nowa wersja na każdą część ze zmianą formatu.

**DoD (wstępne):**
- [ ] 4 nowe jednostki rekrutuje się w koszarach z nowej broni i zbroi; walczą w widoku prowincji i w rozstrzyganiu automatycznym (testy tabeli).
- [ ] Ruchoma balista powstaje w warsztacie i strzela z daleka do ludzi, machin i murów.
- [ ] Duża stocznia buduje 3 okręty w wersji cywilnej i wojennej; każdy większy od poprzedniego; cywilne handlują, wojenne wożą wojsko i walczą automatycznie.
- [ ] Zapisy z migracjami, teksty PL i EN.
- [ ] **Twoja ocena gry** (po każdej części).

---

## P2 — Port 2: słupki, dokerzy, wojsko na statki, ikonki i podatki

**Status: plan zaakceptowany 2026-11-09 (ankieta); część 1 zaakceptowana i scalona do `main` 2026-11-09; część 2 zaakceptowana i scalona do `main` 2026-11-09; część 3 zaakceptowana i scalona do `main` 2026-11-09; etap P2 zamknięty.** Prośba właściciela 2026-11-09, przed oceną M7, B1, W1 i J1 (ocena i pomiar odłożone). Ankieta: **3 części, ocena po każdej**; słupek **tylko na kamiennym nabrzeżu**; **port zostawia swoich 2 dokerów**, a magazyny portowe tracą tragarzy; **wspólny podatek, 5 poziomów**. Dopisek właściciela: budynki portowe stawiane **bardziej na wodzie** i z **dwoma wejściami** (od lądu i od nabrzeża), żeby budowa przy nabrzeżach nie sprawiała kłopotów (także automatycznemu graczowi).

**Część 1: logistyka portu**
- [x] Słupek do cumowania (1 kafel na kamiennym nabrzeżu, przy głębokiej wodzie, ludzie przechodzą obok): statek cumuje przy nim, żeby handlować, rozładować i załadować towar. Słupek nie ma magazynu: towar idzie do najbliższego magazynu portowego (do 12 kafli) i stamtąd wraca; **magazyn portowy w pobliżu nie jest wymagany** (decyzja właściciela 2026-11-09): bez niego towar idzie prosto do zwykłych magazynów i z nich. Obsługują go portowcy z portu albo z domów portowców w pobliżu.
- [x] 2 mniejsze magazyny portowe (obok obecnego 3×3): mały i średni. Magazyny portowe nie mają własnej obsługi (bez tragarzy).
- [x] 2 domy dokerów (mały i duży, różna liczba dokerów). Dokerzy sami podejmują prace portowe (rozładunek, załadunek, noszenie między statkiem, słupkiem, portem i magazynem) i chodzą po nabrzeżach. Port zostawia swoich 2 dokerów.
- [x] Budynki portowe bardziej na wodzie i z 2 wejściami (od lądu i od nabrzeża); automatyczny gracz stawia je bez kłopotów.
- [x] Szczegółowa grafika z bogatą bryłą: słupek, 2 magazyny portowe, 2 domy dokerów. Zapis: nowa wersja z migracją (tragarze magazynów znikają).

**Część 1, stan (2026-11-09): zaakceptowana („Jest super!”) i scalona do `main`.** Poprawki z oceny: dom portowców całą powierzchnią na kamiennym nabrzeżu, łączy się z nabrzeżem obok; deska trapu idzie z kadłubem od krawędzi nabrzeża do burty. Słupek (`bollard`, 1×1, na kamiennym nabrzeżu, przechodni; towar do najbliższego magazynu portowego albo prosto do magazynów), skład portowy (`port_store`, 1×1, 2 miejsca), mały magazyn portowy (`port_warehouse_small`, 2×2, 4 miejsca), duży bez tragarzy i do 2 rzędów na palach; chata portowców (`docker_hut`, 2×2, 2 portowców) i dom portowców (`docker_house`, 3×3, 4 portowców, 2 rzędy nad wodą na kamiennym nabrzeżu, które łączy się z kamiennym nabrzeżem obok: prośba właściciela 2026-11-09); obaj z 2 wejściami. Portowcy z domów obsługują każdy statek przy porcie, miejscu cumowania i słupku do 12 kafli i pomagają nosić towar z i do budynków portowych. Budynek portowy, który nie mieści się na palach, prosi o nabrzeże (`needs_quay`) zamiast „za dużo wody”: na tym potykał się automatyczny gracz; teraz stawia też chatę portowców. Zapis v24. Testy: `tests/scenario/test_p2_port.gd`, długi `test_n1_harbour_bot.gd`. Zrzut: `game_shot.tscn -- --map=coast --tile=30,98 --focus=33,106 --zoom=1 --p2 [--p2_seconds=<s>]`.

**Część 2: statki i wojsko**
- [x] Statek bez miejsca sam cumuje do wolnego słupka lub miejsca cumowania.
- [x] Załadunek wojska: zaznaczone jednostki + prawy przycisk na okręt → okręt cumuje, żołnierze idą na nabrzeże i wchodzą na pokład (w granicach miejsca dla wojska); rozładunek z panelu statku. Decyzje (ankieta 2026-11-09): po załadunku okręt **odpływa na kotwicę** i zwalnia nabrzeże; wojsko na okręcie **na razie nie liczy się** przy wysyłaniu armii morzem z mapy świata (później, np. M8).
- [x] Panel statku: siatka miejsc ładowni, puste albo z ikoną towaru (lub oddziału) i liczbą.

**Część 2, stan (2026-11-09): zaakceptowana („Super!”) i scalona do `main`.** Zaznaczeni żołnierze + prawy przycisk na własnym okręcie wojennym: okręt, który nie stoi przy nabrzeżu, płynie do najbliższego wolnego miejsca (port, miejsce cumowania, słupek), cumuje, żołnierze idą do niego i wchodzą na pokład jeden po drugim (najwyżej tylu, ile mieści okręt), potem okręt odpływa na kotwicę. „Wysadź wojsko” w panelu statku: ta sama droga z powrotem, żołnierze stają przy nabrzeżu. Żołnierzy na pokładzie nie widać, nie da się ich zaznaczyć i nie walczą; inny rozkaz zdejmuje żołnierza z drogi na pokład; okręt z wojskiem nie odpływa z armią z mapy świata. Panel statku: ładownia jako siatka miejsc (puste albo ikona towaru z liczbą). **Miejsca na wojsko** (prośba i ankieta właściciela 2026-11-09): okręt wojenny ma osobny rząd miejsc obok ładowni, po 10 żołnierzy jednego rodzaju w miejscu (okręt wojenny 3, karawela 4, karaka 6, galeon 9), z ikonką żołnierza i liczbą; na pokład wchodzi tylko tyle, ile się zmieści w tych miejscach. Ikonki: `python3 tools/make_unit_icons.py` (popiersia z postaci). Zapis v25. Testy: `tests/scenario/test_p2_troops.gd`. Zrzut: `game_shot.tscn -- --map=coast --tile=30,98 --focus=31,106 --zoom=2 --p2 --p2troops=<s> [--select=warship|caravel]`.

**Część 3: miasto i wygląd**
- [x] Chata budowniczych: więcej budowniczych w mieście (pomysł z IDEAS).
- [x] Panel budynku produkcyjnego: ikonki towarów, które wytwarza i których potrzebuje.
- [x] Panel domu: potrzeby jako ikonki; suwak podatku (wspólny dla miasta, 5 poziomów od „brak” do „bardzo wysoki”, ten sam w ratuszu).
- [x] Nowa grafika magazynów: zwykły na drewnianej podłodze, portowe na kamiennej.

**Część 3, stan (2026-11-09): zaakceptowana i scalona do `main`; etap P2 zamknięty.** Chata budowniczych (`builders_hut`, 2×2, 2 budowniczych, zakładka „Magazyny”; 4 studnie stają ok. 25% szybciej, resztę ogranicza noszenie drewna). Panel warsztatu: rzędy ikonek „Potrzebuje” i „Wytwarza” z przepisu; panel domu: rząd ikonek potrzeb (zielona ramka: jest, czerwona i przygaszona: brak; potrzeby-usługi z ikoną budynku). Podatek: 5 poziomów (brak 0×/+20 zadowolenia, niskie 0,5×/+10, normalne 1×/0, wysokie 1,5×/−15, bardzo wysokie 2×/−35), suwak w panelu ratusza, obozu pionierów i każdego domu; zapis v26 (stare poziomy przesunięte o 1). Podłogi: zwykły magazyn na drewnianym podeście z desek na legarach, magazyny portowe na kamiennych płytach z krawężnikiem. Testy: `tests/scenario/test_p2_town.gd`. Zrzuty: `town_shot.tscn -- --minutes=40 --select=bakery|hut|stockpile [--zoom=2]`, `game_shot.tscn -- --map=coast --tile=30,98 --focus=30,104 --zoom=2 --p2`.

**DoD:** każda część ma testy symulacji, `tools/run_tests.sh --all` przechodzi, zrzuty w grze, ocena właściciela po każdej części.

## M8 — Przeciwnicy i sandbox

**Zakres:**
- władcy AI (gospodarka uproszczona, decyzje strategiczne, poziomy trudności),
- bandyci,
- konfiguracja sandboxa i warunki zwycięstwa,
- generator lub zestaw map świata.

**DoD:**
- [ ] Pełna partia sandbox od startu do zwycięstwa lub porażki.
- [ ] AI zasiedla, handluje i atakuje.
- [ ] Brak błędów blokujących w 3 partiach testowych.

**Status: plan do akceptacji (2026-11-09).** Ankieta właściciela 2026-11-09: **generator światów**; **1–3 władców komputerowych do wyboru, 3 poziomy trudności**; warunki zwycięstwa: **podbój, liczba prowincji, liczba patrycjuszy, gra wolna** (wszystkie cztery); **3 części, ocena po każdej**. **Scenariusze** (prośba i ankieta właściciela 2026-11-09): **Kolonizacja** (bazowy: prawie wszystkie prowincje puste, gracz i rywale zasiedlają kontynent), **Podzielony kontynent** (wszystkie prowincje zajęte przez władców i osady neutralne, gracz zaczyna od jednej i wszystko wywalcza albo wykupuje), **Kupieckie wyspy** (świat z wysp i wybrzeży, wygrywa, kto pierwszy zbierze wybraną sumę złota), **Najazd z morza** (przetrwać 60 minut coraz silniejszych fal najeźdźców z morza); Kolonizacja w części 1, pozostałe w części 3. Start przed oceną M7, B1, W1, J1 i P2 (odłożona przez właściciela).

**Część 1: świat i nowa gra**
- [ ] Generator światów z ziarna (ten sam numer daje ten sam świat): 16–30 prowincji na pergaminie, granice lądowe i wybrzeża, wyspy osiągalne tylko morzem; każda prowincja to wariant jednej z 4 map (Wybrzeże, Wyspy, Pojezierze, Kraina rzek) z bogactwem surowców i czasem rzadkim surowcem; kilka osad neutralnych; miejsca startu gracza i władców daleko od siebie.
- [ ] Ekran „Nowa gra”: scenariusz (w części 1 Kolonizacja), numer świata (albo losowy), liczba władców (1–3), poziom trudności, warunek zwycięstwa (z progiem dla liczby prowincji i patrycjuszy). „Królestwo” zostaje jako gotowy świat do wyboru.
- [ ] Władcy na mapie świata już są (herb, kolor, prowincja startowa z gotowym miasteczkiem), ale jeszcze nic nie robią.
- [ ] Zwycięstwo i porażka: sprawdzane na bieżąco, okno z wynikiem; porażka, gdy gracz straci wszystkie prowincje. Zapis gry: ustawienia partii i władcy.

**Część 2: władcy budują, zasiedlają i handlują**
- [ ] Prowincje władców żyją w trybie uproszczonym; „planista” stawia im budynki według planu rozwoju (jak automatyczny gracz z testów), od chat i drwali do warsztatów, portu i koszar.
- [ ] Władca wysyła wyprawy osadników do pustych prowincji (lądem i morzem), wykupuje osady neutralne, prowadzi szlaki handlowe między swoimi prowincjami.
- [ ] Wejście do prowincji władcy pokazuje jego miasto (oglądanie, bez budowania).

**Część 3: władcy zbroją się i atakują**
- [ ] Władca szkoli wojsko i buduje okręty wojenne, ocenia siłę sąsiadów i atakuje słabsze prowincje: innych władców, osady neutralne i gracza (oblężenie na żywo, gdy gracz ogląda prowincję, inaczej rozstrzygnięcie automatyczne); broni się przed graczem.
- [ ] Poziomy trudności: tempo rozwoju, wielkość armii, jak często i jak śmiało atakują.
- [ ] Scenariusze: **Podzielony kontynent** (miasta władców i osad na start „przewija” planista z części 2), **Kupieckie wyspy** (generator z samych wysp i wybrzeży, zwycięstwo za złoto), **Najazd z morza** (fale najeźdźców z morza co kilka minut, coraz silniejsze; zwycięstwo po 60 minutach).
- [ ] 3 pełne partie testowe (automatyczny gracz przeciwko władcom) bez błędów blokujących, od startu do zwycięstwa lub porażki.

**Ryzyko:** część 3 jest duża (wojna, trudności i 3 scenariusze); jeśli się rozrośnie, scenariusze trafią do osobnej części 4 (ankieta).

**Do ustalenia w trakcie (ankiety):** szczegóły oblężenia miasta gracza przez władcę (część 3), herby i kolory władców, czy władcy mogą zawierać rozejmy (dyplomacja jest [PÓŹNIEJ]).

---

## M9 — Produkcja grafik (równolegle, od M4)

Partiami, w kolejności etapów: najpierw grafiki slice’a, potem M4, M5 itd. Każda partia przechodzi przez przepływ z ART_SPEC §10 i kryteria akceptacji.

**Stan (2026-11-05):** budynki slice’a i M4a są rysowane kodem (`tools/generate_art.gd`, ART_SPEC §10.3). Postacie w strojach zawodów też (`tools/generate_characters.gd`, ART_SPEC §10.4). Towary (stosy, w rękach, ikony), skały i drzewa też (`tools/generate_goods.gd`, ART_SPEC §10.5).

---

## M10 — Wersja 1.0

- balans,
- dźwięk i muzyka,
- dopracowanie UI,
- samouczek (prosty, kontekstowy),
- opcje (grafika, dźwięk, klawisze),
- stabilność,
- eksport na Windows.

---

## Po wersji 1.0 [PÓŹNIEJ]

| Etap | Zawartość |
|---|---|
| **P1 — Bitwy morskie** (zaplanowane) | interaktywna walka okrętów na wodach prowincji (blokada portu, atak na port, desant), AI walki okrętów, animacje ostrzału i abordażu. Architektura jest przygotowana od M5 i M7. |
| P2 | kampania fabularna |
| P3 | pory roku i sezonowość upraw, cykl dnia i nocy |
| P4 | pożary, choroby, przestępczość |
| P5 | dyplomacja |
| P6 | katapulty i trebusze, bramy po przekątnej |

---

## Ryzyka

| # | Ryzyko | Typ | Wpływ | Wczesne sprawdzenie | Kiedy |
|---|---|---|---|---|---|
| R1 | **Sortowanie głębi** postaci przy budynkach wielokaflowych i murach ukośnych daje artefakty | tech | wysoki (immersja, czytelność) | scena testowa sortowania z 8 stron, cięcie na paski, rezerwa: sortowanie topologiczne | M1 |
| R2 | **Mury w 8 kierunkach**: szczeliny w połączeniach ukośnych, „dziurawe” przekątne w pathfindingu | tech + grafika | wysoki | składanie z półsegmentów, testy maski, test przejścia przez przekątną | M1 |
| R3 | **Wydajność** przy 500 postaciach (pathfinding, GDScript) | tech | wysoki | benchmark w M1, budżet zapytań, rezerwy z ARCHITECTURE §9.2 (flow fields, GDExtension) | M1, M4 |
| R4 | **Zakleszczenia logistyki** (rezerwacje, pełne magazyny, zburzone cele) | tech | wysoki (gra „staje”) | testy ścieżek błędów, 2-godzinne testy headless przy 4× | M2, M3 |
| R5 | **PixelLab nie utrzyma spójności** postaci między wieloma animacjami albo nie da docelowego rozmiaru lub pivotu | grafika | wysoki (koszt grafik) | pilot A1. Odbicia i animacje zależne od punktu pracy ograniczają liczbę klatek. Nakładki towarów zamiast wariantów | M1/A1 |
| R6 | **Nakładki niesionych towarów** wymagają punktów zaczepienia, których narzędzie nie daje | grafika | średni | porównanie wariantów A i B w M1, narzędzie półautomatyczne do punktów | M1/A1 |
| R7 | **Widoczna praca jest nudna** albo zbyt wolna do obserwowania; gra się „ślimaczy” | projekt | **krytyczny** | vertical slice M3 i Twoja ocena. Strojenie czasów kroków, prędkości i liczby postaci | M3 |
| R8 | **Rozjazd trybów symulacji** (prowincja nieoglądana produkuje inaczej) | tech + projekt | średni | test spójności ±15%, kalibracja czasem transportu | M6 |
| R9 | **Rozrost zakresu** (dwie warstwy gry, wojsko, morze, AI) | projekt | **krytyczny** | sztywne DoD, IDEAS.md jako poczekalnia, kolejność etapów, interaktywne bitwy morskie dopiero po 1.0 | stale |
| R10 | **Złożoność ekonomii**: za trudna dla gracza albo nieczytelna | projekt | średni | nakładki potrzeb, panel budynku z powodem przestoju, stopniowe odblokowywanie budynków | M3, M4 |
| R11 | **Zgodność zapisów** po zmianach formatu | tech | średni | wersja zapisu, migracje i fixtury od M2 | M2+ |
| R12 | **Pixel art przy 0,5×** (niecałkowity zoom) wygląda źle | grafika | niski | test w M1. Rezerwa: zestaw przeglądowy lub mipmapy | M1 |
| R13 | **Długie teksty PL** rozpychają UI | UI | niski | kontenery automatyczne, pseudolokalizacja | M3 |

---

## Kontrola zakresu: co świadomie odkładamy

- **Do wersji 1.0 nie wchodzi:**
  - interaktywne bitwy morskie (P1, zaplanowane),
  - kampania,
  - pory roku,
  - dzień i noc,
  - pożary, choroby, przestępczość,
  - dyplomacja,
  - katapulty,
  - bramy ukośne,
  - premie za kamienice,
  - solone produkty,
  - desant w czasie rzeczywistym.
- **Wykluczone:** multiplayer, obrót kamery, 3D, mobile i konsole.
- **Reguła:** każda nowa funkcja trafia najpierw do [IDEAS.md](IDEAS.md). Do roadmapy przenosimy ją tylko za Twoją zgodą, wskazując etap i to, co ewentualnie wypada.
