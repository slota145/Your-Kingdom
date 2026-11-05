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
- [x] Od startu, bez kodów, da się w ~20–30 minut doprowadzić do co najmniej 6 domów poziomu 2 zaopatrywanych w chleb. Automatyczny gracz (`tests/support/slice_bot.gd`, tylko komendy) osiąga to w **20. minucie** (`tests/scenario/test_slice_dod.gd`). Od M4a mieszczanie potrzebują też ryb i piwa, więc ten sam test sprawdza teraz cel M4a. Właściciel projektu doszedł do celu w czasie (2026-11-05).
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
- [x] Automatyczny gracz od startu dochodzi do 6 domów mieszczan ze wszystkimi potrzebami podstawowymi (chleb, ryby, piwo, opał, studnia) w **38. minucie** (`tests/scenario/test_slice_dod.gd`, limit 50 minut).
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
- **M4b-2:** mięso (chlew, rzeźnik, skóry), straganiarze na targowisku, kupiec wędrowny, który skupuje nadwyżki (ujście towarów z pełnych magazynów), okno „Zapasy królestwa” (suma ze wszystkich magazynów) oraz produkcja i zużycie na minutę (decyzja 2026-11-05).
- **M4b-3:** wozy i bruk, nowe tereny (jezioro, skały), duże miasto 400+ postaci i wydajność.

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
- [ ] **Twoja ocena gry** na laptopie, w tym wygląd kamienic (poprzednio 2/5).

**Ustalone przy realizacji (2026-11-05, do zmiany na prośbę):**
- **Drzwi:** postacie wchodzą i wychodzą tylko przez kafel przed drzwiami. Przy stawianiu musi on być wolny (inaczej „ludzie nie dojdą” albo „wejście na wodę”) i potem nie da się go zabudować. W starych zapisach, gdzie jest zastawiony, ludzie używają innego wolnego boku wejścia.
- **Podgląd:** półprzezroczysty budynek w wybranej orientacji i zaznaczony kafel przed drzwiami. Wybór klawiszem R trwa do zmiany narzędzia (wygodne przy stawianiu całego rzędu). Bez drogi obok zostaje strona ostatnio postawionego budynku.
- **Kamienice szczytem do ulicy** (poprawka właściciela po pierwszej wersji, szkic 2026-11-05): kalenica w głąb działki, szczyty od ulicy w 3 kształtach (mieszczanie: szachulec, wygięty, schodkowy; patrycjusze: ceglany schodkowy z blendami, wygięty, prosty). Sąsiedzi dostają różne szczyty według położenia. Róg ma dwa szczyty, u patrycjuszy wykusz z wieżyczką. Tył: prosty szczyt, tylne drzwi, beczka i drewno. Podcienia patrycjuszy na obu ulicach rogu.
- **Działki z kilkoma domami** (druga poprawka właściciela, ankieta 2026-11-05): na działce 2×2 mieszczan stoją 1–3 węższe domy, na działce patrycjuszy 1–2 domy różnej wysokości. Fronty nie stoją w jednej linii (część domów lekko cofnięta). Między działkami mieszczan wąskie przerwy, całość na bruku; patrycjusze tworzą zwartą pierzeję. Każdy dom ma własny odcień z surowszej palety. Dachy: patrycjusze ciemny łupek, mieszczanie przygaszona dachówka, czasem łupek. Narożnik: ścięty róg z bramą i ukośnym szczytem nad nią (u patrycjuszy jeden z trzech wyglądów ma zamiast tego wykusz z wieżyczką). Dla gry to nadal jeden dom 2×2.
- **Po pierwszej grze właściciela (ankieta 2026-11-05):** narożnik powstaje też wtedy, gdy dom z sąsiadem w rzędzie ma drogę przed drzwiami i drogę przy wolnym końcu. Podgląd stawiania wybiera stronę z drogą, a wśród nich tę, przy której dom tworzy rząd z sąsiadem; bez drogi bierze kierunek sąsiada w rzędzie. Postawiony dom bez drogi przed drzwiami sam obraca się do nowej drogi obok (domy z drogą nie obracają się). Wygląd domu: klawisz T przy stawianiu i przycisk „Zmień wygląd” w panelu; wybór zapisuje się w grze (`look`, zapis v6).
- **Wejścia (druga gra właściciela, 2026-11-05):** magazyny mają drzwi z każdej strony, pozostałe budynki oprócz domów także po przeciwnej stronie (z tyłu, więc bez nowych grafik; wyjątek: ratusz ma drzwi narysowane tylko z jednej strony). Do stawiania i działania wystarczy jedne drzwi z wolnym kaflem przed nimi; ludzie wybierają drzwi bliższe celu. Cały budynek, także kafle wejść, jest nieprzechodni: na wejście wchodzi się tylko z kafla przed drzwiami, więc nikt nie skraca drogi przez róg budynku (ludzie „znikali pod budynkiem”). Panel budynku ma przycisk „Obróć”.
- **Tawerna:** test daje 3 minuty na 2 podania zamiast 2,5 (droga przez drzwi jest odrobinę dłuższa).

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
