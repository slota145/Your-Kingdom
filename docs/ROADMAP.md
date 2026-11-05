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
                │              └─► M7 Wojsko, mury i oblężenia
                │                   └─► M8 Przeciwnicy i sandbox ──► M10 Wersja 1.0
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
- [ ] Gra przy 4× działa płynnie z 200 postaciami (tragarze z losowymi zleceniami). Headless: tick 1,1 ms przy 200 i 2,1 ms przy 500 tragarzach (ARCHITECTURE §9.3). **Czeka na pomiar FPS na laptopie** (`m2_bench.tscn`).

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
- [ ] Od startu, bez kodów, da się w ~20–30 minut doprowadzić do co najmniej 6 domów poziomu 2 zaopatrywanych w chleb. Automatyczny gracz (`tests/support/slice_bot.gd`, tylko komendy) osiąga to w **20. minucie** (`tests/scenario/test_slice_dod.gd`). Od M4a mieszczanie potrzebują też ryb i piwa, więc ten sam test sprawdza teraz cel M4a. **Czeka na Twoją grę.**
- [ ] **Każda jednostka chleba w magazynie jest wyprodukowana przez widoczną sekwencję:** pole → snop → młyn → worek mąki → piekarz → kosz chleba. Test z licznikami zdarzeń przechodzi (`tests/scenario/test_bread_chain.gd`). **Czeka na obserwację w trybie „śledź”.**
- [ ] Kliknięcie dowolnej postaci pokazuje, co robi, zgodnie z tym, co widać. Zrobione (`AgentDescriber`). **Czeka na Twoją ocenę.**
- [x] Lista w UI magazynu = stosy na placu, w każdej chwili. Oba czytają te same sloty (`Stockpile.totals`, `StockpileLayout`), test w `test_woodcutter.gd`.
- [x] Brak zakleszczeń przez 2 godziny gry przy 4× (test scenariuszowy headless, `test_slice_dod.gd`: żadna rezerwacja bez właściciela, żadne zadanie nie stoi 5 minut na jednym kroku). Tempo 4× nie zmienia ticków, więc test liczy po prostu 72 000 ticków.
- [x] Zapis w trakcie pracy (postacie niosą towary) → odczyt → wszystko kontynuuje bez utraty towaru (`test_save_round_trip.gd`: wioska z placem budowy, polami i domami, zapis v2, fixtura `v2_village.json`).
- [ ] UI w PL i EN bez obciętych tekstów, poprawne formy liczby mnogiej. Sprawdzone na zrzutach w chmurze (PL, EN, pseudolokalizacja F11). **Czeka na sprawdzenie na laptopie.**
- [ ] **Twoja ocena gry:** czy to jest fajne do oglądania? Wnioski zapisujemy w GDD przed M4.

**Balans wyjściowy (strojony automatycznym graczem, 2026-11-05):** drwal rąbie 4 s i wiąże 2 s, opał 0,03 na osobę na minutę, chleb 0,1 na osobę na minutę, na start 50 drewna i 12 chleba, 1 worek mąki = 2 chleby, pole dojrzewa 90 s. Wszystko jest w `data/`.

---

## M4 — Miasto i ekonomia

Podzielony na dwie części (decyzja 2026-11-05). Każda kończy się Twoją grą i oceną.

**Decyzje właściciela projektu (2026-11-05):**
- **Start bez oceny M3:** M4a robimy od razu, choć ocena M3 na laptopie jeszcze czeka. Świadome ryzyko: jeśli w M3 coś nie zagra, część M4a może wymagać poprawek.
- **Opał przed budową:** zlecenia budowy nie biorą ostatnich 5 sztuk drewna z magazynu (rezerwa dla domów). Gracz zmienia tę rezerwę suwakiem w panelu magazynu.
- **Tragarze w magazynach:** każdy magazyn ma 2 miejsca pracy dla tragarzy. Ratusz zostaje z 2 tragarzami i 1 budowniczym.
- **Białko dla mieszczan w M4a: ryby z wędkarzem** przy rzece. Mięso (chlew, rzeźnik) w M4b. Kutry na morzu później (IDEAS).
- **Opał:** domy dalej palą zwykłym drewnem. Osobnego drewna opałowego nie robimy.
- **Złoto:** część większych budynków (np. kościół, browar, targowisko) kosztuje też złoto.
- **Wozy:** w M4b razem z brukiem.

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

**DoD:**
- [x] Automatyczny gracz od startu dochodzi do 6 domów mieszczan ze wszystkimi potrzebami podstawowymi (chleb, ryby, piwo, opał, studnia) w **38. minucie** (`tests/scenario/test_slice_dod.gd`, limit 50 minut).
- [x] Każdy nowy łańcuch (deski, kamień, ryby, chmiel, piwo) ma test scenariuszowy z licznikami zdarzeń (`tests/scenario/test_m4a_chains.gd`).
- [x] Przy budowach domy nie tracą opału: budowy zostawiają rezerwę, domownicy ją biorą (`tests/unit/sim/economy/test_logistics.gd`, tam też priorytety, podatki i złoto).
- [x] Brak zakleszczeń przez 2 godziny przy 4× (`test_slice_dod.gd`). Po 2 godzinach mieszczanie wciąż są zaopatrzeni.
- [x] Zapis z M3 wczytuje się po migracji (v2 → v3) bez utraty towaru. Nowa fixtura `v3_town.json`.
- [ ] UI w PL i EN, nowe teksty przez klucze tłumaczeń. Klucze sprawdza test, panele sprawdzone na zrzutach w chmurze (PL). **Czeka na laptop.**
- [ ] **Twoja ocena gry.**

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

---

## M5 — Woda, porty i statki

**Zakres:**
- mapy przybrzeżne i wyspowe,
- rybak (rzeka, jezioro, morze),
- port z portowcami ładującymi skrzynie i beczki,
- stocznia z budową statku w etapach,
- łódź rybacka i koga,
- `NavGrid` wodny.

**DoD:**
- [ ] Widoczny załadunek i rozładunek sztuka po sztuce.
- [ ] Ładunek statku zgodny z UI.
- [ ] Statek budowany etapami do wodowania.
- [ ] Zapis i odczyt w trakcie załadunku.

---

## M6 — Mapa świata i prowincje

**Zakres:**
- graf prowincji, ekran mapy świata,
- przełączanie prowincji,
- **tryb uproszczony** z kalibracją i przełączaniem trybów (ARCHITECTURE §7),
- zasiedlanie przez osadników,
- wykup osad neutralnych,
- szlaki handlowe (wozy i statki),
- rzadkie surowce.

**DoD:**
- [ ] Test spójności trybów (±15%) przechodzi.
- [ ] Wejście i wyjście z prowincji nie gubi towarów.
- [ ] Gra z 5 prowincjami gracza działa płynnie.
- [ ] Zapis obejmuje cały świat.

---

## M7 — Wojsko, mury i oblężenia

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
