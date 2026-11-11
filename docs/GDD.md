# Your Kingdom — Game Design Document

> Status: **wersja 0.1 (do zatwierdzenia)** · data: 2026-11-04
> Powiązane: [ARCHITECTURE.md](ARCHITECTURE.md) · [ROADMAP.md](ROADMAP.md) · [ART_SPEC.md](ART_SPEC.md)

Oznaczenia zakresu używane w całym dokumencie:
- **[SLICE]** — wchodzi do pierwszego grywalnego fragmentu (vertical slice),
- **[1.0]** — wchodzi do pierwszej pełnej wersji,
- **[PÓŹNIEJ]** — odłożone poza wersję 1.0,
- **[WYKLUCZONE]** — świadomie poza projektem.

---

## 1. Wizja

Strategia ekonomiczno-wojskowa w izometrycznym 2D, inspirowana Twierdzą (Stronghold) i serią Anno. Gracz buduje średniowieczne królestwo złożone z prowincji: rozwija gospodarkę, zasiedla nowe ziemie, handluje i zdobywa cudze grody.

**Najważniejsza jest immersja.** Gracz widzi, jak działa jego królestwo: każdy towar ktoś wytwarza, niesie i odkłada. Każdy etap pracy jest widoczny jako osobna czynność.

### 1.1 Filary projektu

1. **Widoczna praca.** Produkcja to ciąg czynności wykonywanych przez konkretne postacie, a nie licznik. Nic nie pojawia się w magazynie „magicznie”.
2. **Fizyczne towary.** Towary leżą w magazynach jako stosy, są noszone w rękach, ładowane na wozy i statki. Stan na ekranie i stan w interfejsie wynikają z tych samych danych.
3. **Czytelna złożoność.** Gospodarka jest bogatsza niż w Twierdzy (kilka klas mieszkańców, dłuższe łańcuchy, rzadkie surowce, logistyka między prowincjami), ale prostsza niż w Anno: mniej towarów, krótsze łańcuchy, brak mikrozarządzania wpływami.
4. **Dwie skale, jedna symulacja.** Mapa świata i widok prowincji działają na wspólnym zegarze. Decyzje strategiczne wynikają z tego, co dzieje się w prowincjach, i na odwrót.

### 1.2 Ramy

| Element | Decyzja |
|---|---|
| Silnik | Godot 4.7, GDScript ze statycznym typowaniem |
| Platforma | PC (Windows), jeden gracz. Multiplayer: **[WYKLUCZONE]** |
| Czas | rzeczywisty, z pauzą i prędkościami 1×/2×/4×, jeden zegar dla całej gry |
| Perspektywa | izometria 2D 2:1, stała kamera bez obrotu, zoom 0,5×/1×/2×/3× |
| Grafika | pixel art: najpierw placeholdery, docelowo grafiki z PixelLab |
| Świat | fikcyjny, w stylu ogólnego europejskiego średniowiecza (XII–XIV w.), bez wyraźnych akcentów narodowych (decyzja 2026-11-05) |
| Języki | polski (domyślny), angielski |
| Tryb gry | sandbox [1.0], kampania [PÓŹNIEJ] |

---

## 2. Struktura gry: dwie warstwy

### 2.1 Mapa królestwa (świata)

- Świat to **graf prowincji**: 20–40 prowincji na mapę sandbox, połączonych granicami lądowymi i strefami morskimi.
- Każda prowincja ma:
  - **typ mapy**: kontynentalna (opcjonalnie z rzeką lub jeziorem), przybrzeżna, wyspowa,
  - **bogactwo surowców** (np. żyzność gleby, lasy, kamień, ryby): wartości 1–3 wpływające na liczbę i wydajność złóż w widoku prowincji,
  - opcjonalnie **surowiec rzadki**: ruda żelaza, sól, winorośl lub pastwiska koni,
  - opcjonalnie **cechy** (E3, ankieta 2026-11-11), niezależne od rzadkiego surowca: **bogata w kamień** (odkrywka, która się nie kończy), **bogata w żelazo** (każda prowincja z rudą★: głęboka kopalnia, która się nie kończy), w części 4 żyzna ziemia i bogata w zwierzynę. W świecie „Królestwo” bogate w kamień jest Bursztynowe Wybrzeże. W losowym świecie (E3, część 3, ankieta 2026-11-11) bogata w kamień jest mniej więcej co dziesiąta prowincja, nigdy start gracza, a jedna zawsze blisko niego (sąsiad albo sąsiad sąsiada); bogate w żelazo są te z rudą★. Cechy widać na mapie świata (znaczek przy nazwie, linia „Cechy:” w panelu prowincji),
  - **właściciela**: gracz, władca AI, osada neutralna albo prowincja pusta.
- Na mapie świata poruszają się **armie** (lądem), **floty** (strefami morskimi) i **konwoje handlowe** (wozy lub statki).
- Ruch odbywa się w czasie rzeczywistym, po krawędziach grafu, a czas przejścia zależy od dystansu i rodzaju jednostki.
- **M6, część 2 (2026-11-06):** wyprawa osadników wyrusza z prowincji z ratuszem. **Przebieg (decyzja 2026-11-06, ankieta):** w panelu ratusza albo w panelu swojej prowincji na mapie świata gracz wybiera tylko rodzaj, „Wyprawa lądowa” albo „Wyprawa morska”, bez celu. Po zbiórce gotowa wyprawa czeka w mieście: wóz przed ratuszem, koga przy nabrzeżu z osadnikami na pokładzie. Na mapie świata stoi przy swoim mieście. Gracz klika ją, a potem prawym przyciskiem klika pustą prowincję (zielona linia: można tam ruszyć, czerwona: nie). Złoto płaci się dopiero przy wysłaniu. Przed wysłaniem wyprawę można rozwiązać: osadnicy wracają do domów, zestaw do magazynów, a koga na kotwicę. Wyprawa kosztuje 100 zł, zabiera 6 mieszkańców (budowniczego i tragarzy) i zestaw 90 drewna i 20 chleba. Widać zbiórkę (decyzja 2026-11-06): osadnicy wychodzą z domów, tragarze znoszą zestaw na wóz osadników przed ratuszem albo na nabrzeże, a portowcy wnoszą go na twoją kogę (jej ładownia mieści wtedy cały zestaw). Morzem płynie się między wybrzeżami i na wyspy (na wyspę tylko statkiem), lądem tylko do sąsiada. Na mapie świata widać kogi i wozy w drodze. Wyprawa czeka przy granicy, aż gracz wejdzie do nowej prowincji (decyzja 2026-11-06), i dopiero wtedy ląduje: kogą jak start na „Wybrzeżu”, wozem od krawędzi mapy. Nowa osada zaczyna od obozu pionierów, a koga wraca potem do portu (decyzja 2026-11-06). Każda prowincja gra wariant szablonu: odbity lustrzanie albo nie, z mniejszą lub większą ilością drewna, kamienia i ryb według bogactwa. Nowa mapa „Wyspy”: duża wyspa z zatoką na port i dwie wysepki. **Ratusz to siedziba prowincji:** najwyżej jeden na prowincję, tylko z niego wysyła się wyprawy, a mieszczanie i patrycjusze płacą swój podatek tylko tam, gdzie stoi (bez niego płacą jak chłopi).
- **M6, część 3 (2026-11-06):** osady neutralne Żelazny Gród i Końska Przystań to gotowe miasteczka (ok. 35 budynków, 70–85 mieszkańców), które czekają, nie żyjąc. Każda żąda złota i towarów w 20 minut (300 zł i 40 chleba; 300 zł, 25 chleba i 15 desek). Złoto płaci się w panelu osady na mapie świata, towary dowozi się szlakiem handlowym albo kogą z celem „do mojej prowincji”. Gdy wszystko dotrze na czas, osada przechodzi do gracza z mieszkańcami i budynkami. Gdy czas minie, dane złoto i towary przepadają, a po 10 minutach przychodzi żądanie o 25% droższe. Prowincje z winoroślą (Winne Wzgórza, Mewia Wyspa) mają łaty ziemi winnej. Winnicę stawia się wszędzie w takiej prowincji, a na ziemi winnej krzewy rosną o połowę szybciej (zmiana 2026-11-07).
- **M6, część 1 (2026-11-06):** pierwszy świat „Królestwo” ma 9 ręcznie ułożonych prowincji (dane w `data/provinces/` i `data/worlds/`): Zatoka Lądowania (start), Bursztynowe Wybrzeże, Wierzbowa Dolina, Lustrzane Jeziora, Winne Wzgórza (winorośl), Mewia Wyspa (winorośl), Solna Wyspa (sól), oraz osady neutralne Żelazny Gród (ruda żelaza) i Końska Przystań (pastwiska koni). Wóz jedzie do sąsiada ok. 2–3 minuty gry, koga między portami 3–6 minut. Mapa świata to osobny ekran (klawisz M albo przycisk „Mapa”): pergamin rysowany kodem, granice, kolor i herb właściciela, miasta, rzadkie surowce; kliknięta prowincja pokazuje panel z właścicielem, mieszkańcami, zapasami i przyciskiem „Wejdź”. W menu „Nowa gra” startuje w świecie, a „Pojedyncza prowincja: …” na starych mapach.

#### Zdobywanie prowincji

| Sposób | Opis | Zakres |
|---|---|---|
| Zasiedlenie | Do pustej prowincji wysyłamy **osadników**: jednostkę z prowincji macierzystej, która zabiera ze sobą ludzi i zestaw startowy (drewno, żywność, narzędzia). Po dotarciu powstaje osada z ratuszem i magazynem. **Plan M6 (2026-11-06):** wyprawę wysyła się z prowincji z ratuszem, morzem kogą (lądowanie jak na „Wybrzeżu”) albo lądem wozem osadników do sąsiada; nowa osada zaczyna od obozu pionierów. | [1.0] |
| Wykup osady neutralnej | Osada neutralna przyłącza się za złoto i dostawy towarów (np. przez określony czas). | [1.0] |
| Oblężenie | Armia dochodzi do prowincji przeciwnika i rozpoczyna oblężenie. W widoku prowincji walka toczy się w czasie rzeczywistym (§8). Gdy prowincja nie jest oglądana, wynik oblężenia jest rozstrzygany automatycznie. | [1.0] |
| Dyplomacja (sojusze, wasalizacja) | — | [PÓŹNIEJ] |

### 2.2 Widok prowincji (właściwa rozgrywka)

- Mapa kafelkowa o rozmiarze 96–192 kafli na bok, zależnie od typu mapy.
- Tu budujemy, produkujemy, rekrutujemy, budujemy okręty i bronimy się.
- **Szczegółowo** (z postaciami) symulowana jest tylko prowincja oglądana. Pozostałe działają w trybie uproszczonym; ich wyniki są spójne z trybem szczegółowym (zob. ARCHITECTURE §7). Otwarcie mapy świata nie przełącza trybu: ostatnio oglądana prowincja dalej żyje z postaciami, dopóki gracz nie wejdzie do innej (decyzja 2026-11-06). Przy wyjściu z prowincji to, co trwa, kończy się od razu: lądowanie (osadnicy stoją na plaży), statki w drodze stają u celu, łodzie rybaków wracają do przystani (decyzja 2026-11-06).

#### Typy map prowincji

| Typ | Cechy | Zakres |
|---|---|---|
| Kontynentalna | Bez morza. Opcjonalnie z rzeką (rybołówstwo, młyn wodny, przeprawa) lub jeziorem. Nie ma portu morskiego. | [SLICE] tylko wariant z rzeką · M4b-3: „Pojezierze” 128×128 (jezioro z trzcinami, rzeka z brodami, kamieniste wzgórze ze skałami); mapę wybiera się w menu przy nowej grze · [1.0] wszystkie |
| Przybrzeżna | Ląd z linią brzegową: port, stocznia, rybołówstwo morskie. | M5 (plan 2026-11-06): „Wybrzeże” 128×128 (morze płytkie i głębokie, plaża, zatoka (W1, 2026-11-08: szeroka podkowa z płaskim dnem, naturalny brzeg z zakolami), rzeka do morza, ławice ryb; część 1 gotowa), start ze statku (część 3: koga rzuca kotwicę w zatoce, 6 osadników brodzi na plażę, zestaw startowy leży na plaży, najpierw obóz pionierów) · [1.0] wszystkie |
| Wyspowa | Jedna lub kilka wysp. Do wyspy można dotrzeć wyłącznie statkiem. | [1.0] |

---

## 3. Mieszkańcy i potrzeby

### 3.1 Klasy mieszkańców

Są trzy klasy. Każda mieszka w innym poziomie domu.

| Poziom | Klasa | Dom | Pojemność |
|---|---|---|---|
| 1 | **Chłopi** | chata | 4 |
| 2 | **Mieszczanie** | dom mieszczański (łączy się w pierzeje kamienic) | 8 |
| 3 | **Patrycjusze** | kamienica patrycjuszowska | 12 |

### 3.2 Potrzeby

Potrzeby dzielą się na **podstawowe**, bez których dom traci mieszkańców i nie może awansować, oraz **dodatkowe**, które zwiększają zadowolenie i podatki.

| Klasa | Potrzeby podstawowe | Potrzeby dodatkowe |
|---|---|---|
| Chłopi | żywność (dowolna z: chleb, jabłka, ryby), drewno opałowe, studnia w zasięgu | kaplica w zasięgu |
| Mieszczanie | chleb **oraz** (mięso lub ryby), piwo, drewno opałowe, studnia w zasięgu | kościół, targowisko w zasięgu |
| Patrycjusze | jak mieszczanie + ubrania, miód pitny | tawerna w zasięgu (+ kościół, targowisko), wino (M6) |

Zasady:
- **Dostarczanie towarów do domów jest widoczne.** Domownik idzie do najbliższego magazynu lub targowiska po zapasy i niesie je do domu. Dom ma mały zapas, np. na 2–3 cykle konsumpcji. [SLICE]: zaopatrzenie z magazynu. **Od M4b-2** targowisko ma 2 straganiarzy: noszą z magazynów na kramy chleb, ryby, mięso, piwo, miód pitny, ubrania i drewno (do 6 sztuk każdego), a domownik z domu w zasięgu targowiska kupuje na kramach, gdy jest tam towar. Targowisko działa w zasięgu tylko wtedy, gdy kramy mają towar.
- **Usługi** (studnia, kaplica, kościół, tawerna) działają przez **zasięg** liczony długością ścieżki od budynku usługowego.
- **Stan w M4a (2026-11-05):** chłopi jedzą chleb albo ryby (jabłka później). Wagi: chłopi żywność 35, opał 25, studnia 25, kaplica 15. Mieszczanie chleb 20, ryby 15, piwo 15, opał 15, studnia 15, kościół 10, targowisko 10. Mięso dojdzie w M4b. Targowisko w M4a to usługa z zasięgiem, bez straganiarzy.
- **Stan w M4b-2 (decyzje 2026-11-05):** mieszczanie i patrycjusze jedzą mięso albo ryby (jedna potrzeba „ryby lub mięso”).
- **Stan w E2, część 1 (2026-11-11):** chłopi jedzą chleb, ryby albo jabłka z sadu (zapis v36: spiżarnie, kramy targu i spiżarnie koszar mają miejsce na jabłka).
- **Stan w E2, część 3 (ankieta 2026-11-11): dieta i punkty z progiem. Ta reguła zastępuje tabelę wyżej i wagi z M4a, M4b-1 i M4b-2.**
  - **Jedzenie (dieta):** jedna potrzeba „jedzenie” z 4 rodzajami: chleb, ryby, mięso, jabłka (0,1 sztuki na mieszkańca na minutę). Dom zjada swoje rodzaje po kolei, więc schodzą po równo, a ostatnią sztukę rodzaju zjada dopiero wtedy, gdy nie ma nic innego. Minimum różnych rodzajów w spiżarni: **chłopi 1, mieszczanie 2, patrycjusze 3**. Za mało rodzajów albo pusta spiżarnia: dom jest **głodny**.
  - **Punkty:** każda spełniona potrzeba daje swoje punkty (razem 100). Chłopi: jedzenie 40, opał 25, studnia 20, kaplica 15. Mieszczanie: jedzenie 35, piwo 15, opał 15, studnia 15, kościół 10, targowisko 10. Patrycjusze: jedzenie 30, ubrania 15, piwo 10, miód pitny 10, opał 10, studnia 10, tawerna 5, kościół 5, targowisko 5 (+ wino jak w M6). Głodny dom traci punkty jedzenia zamiast je dostać.
  - **Spokój od 60 punktów** (i bez głodu): zadowolenie spada wolno, nikt się nie wyprowadza, przychodzą nowi. Poniżej 60 albo w głodzie działa łagodna kara z §3.3.
  - **Podatek za nadwyżkę:** każdy rodzaj jedzenia ponad minimum +10% podatku domu, każde pełne 10 punktów ponad 60 +5% (np. 90 punktów: +15%). Wino dalej +25%.
  - **Widać to w grze:** buźka nad domem (czerwona: głodny albo poniżej 60, żółta: spokojny, zielona: może awansować); niezadowolone domy pokazują ją zawsze, wszystkie po kliknięciu „Zadowolenie” na górnym pasku. Panel domu ma pasek punktów z kreskami przy 60 i 85, liczbę rodzajów jedzenia i dodatek do podatku.
- **Stan w M4b-1 (decyzje 2026-11-05):** tawerna zamiast łaźni. Karczmarz przynosi piwo i miód pitny, a tawerna działa w zasięgu tylko wtedy, gdy niedawno podawała napitki. Wagi patrycjuszy: chleb 15, ubrania 15, ryby 10, piwo 10, miód pitny 10, opał 10, studnia 10, tawerna 10, kościół 5, targowisko 5. Awans do kamienicy kosztuje 6 cegieł i 4 deski.
- **Stan w M6, część 3 (2026-11-06):** wino to dodatkowa potrzeba patrycjuszy poza 100 punktami poziomu: gdy dom ma wino, dostaje +10 zadowolenia (najwyżej do 100) i płaci o 25% większy podatek; bez wina nic się nie zmienia (stare mapy bez winorośli działają jak dotąd).
- **Zadowolenie** domu (0–100) wynika ze spełnienia potrzeb (proste punkty: każda spełniona potrzeba daje swoją część, w slice’ie chleb 40, opał 30, studnia 30; zadowolenie dochodzi do celu płynnie, decyzja 2026-11-05) i wpływa na:
  - podatki,
  - napływ nowych mieszkańców (gdy w domu są wolne miejsca),
  - wydajność pracowników (do −20% tempa pracy poniżej 50; premia za wysokie zadowolenie później).

### 3.3 Rozwój domów

- Dom **awansuje**, gdy przez określony czas (domyślnie 60 s czasu gry) ma **co najmniej 85 punktów i nie jest głodny** (E2, część 3; wcześniej: wszystkie potrzeby podstawowe swojej klasy), a materiały na ulepszenie zostaną **fizycznie dostarczone** (np. deski, cegły). W czasie ulepszenia na domu pojawia się rusztowanie. Chata → dom mieszczański kosztuje 4 deski (M4a). **„Rozbuduj teraz” (E1, ankieta 2026-11-10):** gdy dom spełnia warunki awansu (wszystkie potrzeby podstawowe i towary nowej klasy w magazynach), gracz może zacząć rozbudowę od razu przyciskiem w panelu domu, bez czekania 60 s; materiały i tak muszą dojechać.
- **Awans czeka na towary nowej klasy (M4a, potwierdzone 2026-11-05):** dom zaczyna awans dopiero wtedy, gdy w magazynach jest po pełnej spiżarni każdego towaru podstawowego następnej klasy (np. 4 piwa, 4 ryby, 4 chleby). Od E2, część 3: jedzenie liczy się jako tyle rodzajów, ile wymaga następna klasa (mieszczanie 2, patrycjusze 3), każdy po pełnej spiżarni. Panel domu mówi wtedy, na co czeka. Bez tej reguły domy awansowały, po 3 minutach bez piwa spadały i deski przepadały.
- **Dom nigdy nie cofa się o poziom** (decyzja 2026-11-05, wniosek z gry: cofanie było zbyt surowe, a materiały na awans przepadały). Brak potrzeby podstawowej ma inne, łagodne skutki:
  - **Łagodna kara zamiast pustoszenia (decyzja 2026-11-06, wniosek z gry: mieszkańcy odchodzili za szybko, nikt nie przychodził do domu z brakiem, więc łatwo było utknąć w błędnym kole „brak → mniej ludzi → mniej pracy → większy brak”):**
  - brakująca potrzeba podstawowa odejmuje od zadowolenia swoją wagę (zamiast cięcia do 20), więc im więcej brakuje, tym niższe zadowolenie; spada powoli (1 pkt/s),
  - główna kara to **mniejszy podatek** (zależy od zadowolenia) i **wolniejsza praca**: mieszkańcy domu z zadowoleniem poniżej 50 pracują wolniej, liniowo do −20% przy zadowoleniu 0 (w trybie uproszczonym liczy się średnia prowincji); premia za wysokie zadowolenie później,
  - nowi mieszkańcy przychodzą do każdego wolnego miejsca przy zadowoleniu od 50, a przy zadowoleniu od 30 do połowy miejsc domu,
  - po 60 s gracz dostaje ostrzeżenie,
  - po 5 min braku, jeśli zadowolenie jest poniżej 40, co 3 min wyprowadza się jeden mieszkaniec, ale **połowa miejsc domu (trzon) zostaje zawsze**. Dom zostaje na swoim poziomie. Gdy potrzeby wrócą, zadowolenie rośnie i dom się zapełnia.
- **Czas ochronny na start (ankieta 2026-11-07, wniosek z oceny M5: start był za trudny):** przez pierwsze **15 minut** nowej gry i każdej świeżo zasiedlonej prowincji zadowolenie mieszkańców nie spada, nie ma ostrzeżeń o braku i nikt się nie wyprowadza. Licznik „Ochrona mm:ss” widać na górnym pasku. Przybysze przychodzą tak, jak do domu bez ochrony: dom z brakiem, którego zadowolenie bez ochrony spadłoby poniżej 50, przyjmuje ich tylko do połowy miejsc, żeby miasto nie zapełniło się ludźmi bez jedzenia. Po końcu ochrony liczenie braku zaczyna się od zera.
- **Łączenie w kamienice** (od poziomu 2): domy tego samego poziomu, ustawione obok siebie w jednej linii wzdłuż osi siatki i równo wyrównane, wizualnie łączą się w pierzeję. Zamiast osobnych budynków widać fragmenty: koniec lewy, środek i koniec prawy. Łączenie jest **wyłącznie wizualne** i nie zmienia symulacji. Rozważymy później premię (np. mniejsze zużycie opału) [PÓŹNIEJ]. Od M4b-1.5 łączą się tylko domy patrzące w tę samą stronę, dom na styku dwóch rzędów pod kątem prostym staje się narożnikiem, a dwa rzędy mogą stać plecami do siebie, każdy przodem do swojej drogi. **Kamienice stoją szczytem do ulicy** (szkic właściciela 2026-11-05): każdy dom pokazuje ulicy własny szczyt (prosty, wygięty albo schodkowy, według położenia), kalenica biegnie w głąb działki, a dachy sąsiadów stykają się koszami. Dom na rogu ma dwa szczyty, po jednym na każdą ulicę, a często ścięty róg z bramą pod ukośnym szczytem. Na jednej działce stoi kilka węższych domów (mieszczanie 1–3, patrycjusze 1–2) o różnych kolorach i lekko przesuniętych frontach; dla symulacji to nadal jeden dom.

### 3.4 Ludność i praca

- Liczba mieszkańców to suma ludności domów. **Siła robocza** to ok. 50% mieszkańców (pozostali to dzieci, starzy i domownicy).
- **Każdy zatrudniony pracownik jest widoczną postacią.** Pozostali mieszkańcy nie mają stałych postaci. Wyjątkiem są domownicy, którzy pojawiają się na czas wyjścia po zapasy, oraz kilku przechodniów dla ożywienia ulic.
- Pracownik ma przypisany dom i miejsce pracy. Przy zatrudnieniu wychodzi z domu i idzie do pracy, potem już tam pozostaje. Nie ma cyklu dnia i nocy.
- Brak siły roboczej oznacza, że budynki stoją puste i pokazują ikonę braku pracowników.
- Priorytety zatrudnienia ustawia się na poziomie budynku: wysoki, normalny, niski. Budynek z wyższym priorytetem dostaje ludzi pierwszy, a gdy brakuje wolnych, zabiera pracownika budynkowi z niższym priorytetem. [M4a]

### 3.5 Podatki i złoto

- Domy płacą podatek okresowo, zależnie od klasy i zadowolenia. Gracz ustawia stawkę: niska, normalna, wysoka. Stawka wpływa na zadowolenie.
- **Stan w M4a:** podatek liczony co sekundę: chłop 0,25, mieszczanin 0,6 złota na minutę przy pełnym zadowoleniu. Stawka mnoży to przez 0,5 / 1 / 1,5 i zmienia zadowolenie o +10 / 0 / −15. Stawkę ustawia się w panelu ratusza. Na start 100 złota. Złotem płaci się za kaplicę (10), browar (30), targowisko (40) i kościół (60).
- Złoto wydajemy na budowę części budynków, rekrutację, handel, wykup osad i utrzymanie wojska.
- Złoto jest pulą globalną królestwa. To jedyny zasób globalny.
- **Plan M6 (2026-11-06):** ratusz jest siedzibą prowincji. Mieszczanie i patrycjusze płacą pełny podatek tylko w prowincji z ratuszem (bez niego płacą jak chłopi), a wyprawę osadników wysyła się tylko z prowincji z ratuszem. Najwyżej jeden ratusz na prowincję.

---

## 4. Ekonomia

### 4.1 Zasady

1. **Każda prowincja ma własne magazyny.** Nie ma globalnej puli towarów. Towary między prowincjami przewożą konwoje i statki (§4.5).
2. **Magazyn to fizyczne miejsce.** Plac składowy ma sloty. Każdy slot przechowuje jeden rodzaj towaru do określonej ilości i jest pokazany stosem w jednej z kilku faz zapełnienia. Pojemność magazynu wynika z liczby slotów. **E1 (ankieta 2026-11-10):** plac składowy i magazyny portowe mieszczą w każdym miejscu **2 × więcej** niż zwykły stos (np. 40 drewna zamiast 20), a stos rośnie wtedy wyżej; zbrojownia, podwórka warsztatów, kramy i ładownie bez zmian. **Chata tragarzy** (2×2, 4 tragarzy, do 2 wózków) i **dom tragarzy** (3×3, 6 tragarzy, do 3 wózków) to osobne miejsca pracy tragarzy: noszą w całej prowincji tak jak tragarze magazynów, więc mniej placów nie znaczy mniej rąk do noszenia.
3. **Model transportu jest zbliżony do Twierdzy.** Pracownik budynku produkcyjnego sam przynosi surowce z magazynu i sam odnosi wyroby do magazynu. Tragarze magazynów zajmują się dostawami na budowy, przewozem między magazynami (później także wozami) i portem. W M4a każdy magazyn ma 2 miejsca dla tragarzy, a ratusz 2 tragarzy i budowniczego.
5. **Opał przed budową (M4a):** budowy nie biorą z magazynu ostatnich 5 sztuk drewna. Ta rezerwa zostaje dla domów. Gracz zmienia ją suwakiem w panelu magazynu (0–60).
6. **Zapas na budowy (M4a, wniosek z testów 2026-11-05):** gracz ustawia, ile sztuk towaru warsztaty mają zostawić w całym królestwie (np. tartak nie zje całego drewna). To jedno ustawienie na towar dla całej prowincji, a suwak jest w panelu warsztatu, który ten towar pobiera (0–60, domyślnie 0). Warsztat bierze tylko ponad ten zapas. Budowy i domy mogą brać do zera.
7. **Stos przy budynku (M4b-2, decyzja 2026-11-05):** gdy żaden magazyn nie ma miejsca, pracownik odkłada wyrób na stos przy swoim budynku (pół pola magazynu, np. 10 drewna). Gdy stos jest pełny, pracownik czeka przy budynku. Ze stosu każdy może brać jak z magazynu (warsztaty, domownicy, budowy, kupiec), a tragarze odnoszą go do magazynu, gdy zwolni się miejsce. Na ziemi nie lądują wyroby z produkcji.
4. **Każdy cykl produkcji składa się z etapów** zdefiniowanych w danych: przejście, pobranie, czynność z animacją, wytworzenie, odniesienie.

### 4.2 Lista towarów [1.0] (ok. 30)

| Grupa | Towary |
|---|---|
| Budulec | drewno, deski, kamień, glina, cegły |
| Żywność | zboże, mąka, chleb, jabłka, ryby, świnie (żywiec), mięso |
| Napoje | chmiel, piwo, miód, miód pitny, winogrona ★, wino |
| Opał i rzemiosło | drewno opałowe, węgiel drzewny, smoła |
| Tekstylia | wełna, sukno, ubrania, skóry |
| Metal | ruda żelaza ★, żelazo, narzędzia |
| Wojsko | łuki, włócznie, miecze, zbroje skórzane, kolczugi, konie ★ |
| Inne | sól ★ (przetwarzanie ryb i mięsa na solone, potrzeba patrycjuszy [PÓŹNIEJ]) |

★ oznacza surowiec rzadki, dostępny tylko w części prowincji.

### 4.3 Łańcuchy produkcji (wybrane)

```
[SLICE]
zboże (farma + pola) ──► młyn ──► mąka ──► piekarnia ──► chleb ──► magazyn ──► dom
drwal ──► drewno ──► magazyn ──► budowy / dom (drewno opałowe w slice = drewno)
studnia (usługa, bez towaru)

[M4a]
drewno ──► tartak ──► deski (1 kłoda = 2 deski)
skały na mapie ──► kamieniołom ──► kamień
[E3] prowincja bogata w kamień: odkrywka przy skałach (3 kamieniarzy, nie zużywa skał) ──► kamień
wędkarz (nad rzeką) ──► ryby (później kutry na morzu, IDEAS)
chmielnik + pola ──► chmiel
zboże + chmiel ──► browar ──► piwo (1 + 1 = 2 beczki)

[M4b-1]
glinianka (nad wodą) ──► glina; glina + drewno ──► cegielnia ──► cegły
owczarnia z zagrodą (owce, para na start) ──► wełna (szybciej przy większym stadzie) ──► tkalnia ──► sukno ──► krawiec ──► ubrania
pasieka z ulami (do 8, szybciej przy większej liczbie uli) ──► miód ──► miodosytnia ──► miód pitny
leśniczy sadzi sadzonki ──► drzewa (dla drwala)

[M4b-2]
chlew z zagrodą (stado, od 2 świń rośnie samo) ──► świnia ──► rzeźnia ──► 2 mięsa + 1 skóra
zagroda z kratek (2 świnie na kratkę, do 12 kratek); pierwsza kratka przynosi parę świń (Z1),
kupiec wędrowny sprzedaje więcej (30 złota sztuka); suwak „zostaw do rozmnażania” (od 2)

[1.0]
sad ──► jabłka
winnica★ ──► winogrona ──► winiarnia ──► wino   ← od M6 (tłocznia)
drewno ──► węglarz ──► węgiel drzewny
kopalnia (żyły rudy na każdej mapie, dużo w prowincji z rudą★; decyzja 2026-11-07) ──► ruda żelaza + węgiel ──► huta ──► żelazo ──► kowal ──► narzędzia / miecze / włócznie
[E3] prowincja bogata w żelazo (ruda★): głęboka kopalnia przy żyle (3 górników, nie zużywa żył) ──► ruda żelaza
drewno ──► łuczarz ──► łuki
skóry ──► garbarz-płatnerz ──► zbroje skórzane · żelazo ──► płatnerz ──► kolczugi
stadnina★ z zagrodą (para na start, 1 koń na kratkę, do 10 koni) ──► konie
drewno ──► smolarnia ──► smoła (stocznia)   ← od M5
```

[M6, część 3]
```
prowincja z winoroślą★ ──► winnica 3×3 (12 pól; na ziemi winnej krzewy rosną o połowę szybciej) ──► winogrona
3 kosze winogron ──► tłocznia 2×2 (ok. 40 s) ──► beczka wina (dodatkowa potrzeba patrycjuszy)
```

[M5, część 1]
```
drewno (2) ──► smolarnia ──► smoła (1 beczka)
deski + smoła ──► stocznia ──► łódź rybacka (6 desek, 2 smoły)
ławica ryb na morzu ──► przystań rybacka (łódź) ──► ryby (6 na rejs)
```

### 4.4 Widoczna praca: przykłady etapów

| Budynek | Etapy cyklu |
|---|---|
| Farma zbożowa | rolnik orze pole (kafel po kaflu) → sieje → **całe pole zaczyna rosnąć dopiero po zasianiu ostatniej kratki** (E1, 2026-11-10; tak samo chmiel, winnica i przyszły sad; kratka czeka najwyżej 3 minuty, gdyby rolnik nie mógł dojść do reszty) → zboże rośnie razem (zmiana wyglądu kafli w 3 fazach), a rolnik w tym czasie pieli motyką kratkę po kratce → żniwa sierpem → wiąże snop → niesie snopy do magazynu. Większy plon na wyrównanie: średnio 0,2 jednostki więcej z kratki (co piąta kratka daje 2 snopy), więc farma daje tyle co przed zmianą albo trochę więcej |
| Młyn | młynarz bierze zboże z magazynu i niesie worek → wsypuje do kosza (śmigło się kręci) → napełnia worek mąki → niesie mąkę do magazynu |
| Piekarnia | piekarz przynosi mąkę → zagniata ciasto przy stole → wsadza je łopatą do pieca (dym z komina) → wyjmuje chleb → niesie kosz chleba do magazynu |
| Wędkarz | idzie na pomost lub brzeg rzeki → zarzuca wędkę → czeka na branie → wyciąga rybę → po kilku rybach niesie kosz do magazynu |
| Kowal | przynosi żelazo i węgiel → rozgrzewa w palenisku → kuje na kowadle (iskry) → hartuje w wodzie → niesie broń do zbrojowni |
| Port | portowcy przenoszą skrzynie i beczki z placu portowego na statek po trapie, sztuka po sztuce. Ładunek statku rośnie w interfejsie i jest widoczny na pokładzie. |
| Budowa | tragarze przynoszą materiały na plac budowy (widoczny stos) → budowniczy pracuje młotkiem → rusztowanie → budynek gotowy |

Ikona nad budynkiem i panel budynku pokazują, co aktualnie się dzieje, np. „Piekarz: piecze chleb (60%)”, „Czeka na mąkę”.

### 4.5 Logistyka między prowincjami [1.0]

- **Szlak handlowy** łączy dwie prowincje (A→B), określa towar, ilość i próg, np. „wożę chleb, gdy w B jest mniej niż 20”.
- Wozy kursują lądem, statki morzem. Na mapie świata widać ich ruch.
- W widoku prowincji tragarze ładują i rozładowują wozy w magazynie, a portowcy statki w porcie.
- **Stan w M6, część 3 (decyzje 2026-11-06):** okno „Szlaki handlowe” (przycisk „Szlaki” na górze ekranu i w panelu prowincji na mapie świata) zbiera wszystkie szlaki królestwa. Szlak ma kierunek A→B, pojazd z prowincji A wybrany z listy (wolna koga z portu albo wóz ze stajni) i do 3 towarów; przy każdym ilość na kurs i próg („gdy tam mniej niż N”). Gdy w B brakuje towaru, a w A on jest, pojazd rusza: wóz staje przed stajnią i tragarze go ładują, koga cumuje i ładują ją portowcy; potem wóz wyjeżdża za krawędź mapy, a koga odpływa za horyzont. Wóz jedzie tylko do sąsiada (ok. 3 minuty), koga między wybrzeżami (3–6 minut). W B wóz wjeżdża i tragarze go rozładowują, a ładunek kogi pojawia się przy porcie. W prowincji, na którą gracz nie patrzy, załadunek i rozładunek dzieją się od razu. Wóz szlaku wiezie 12 sztuk, koga 4 miejsca po 10. Wóz ze stajni jest pożyczony: stajnia ma o jeden wóz mniej do pracy w mieście. Szlak można wstrzymać i usunąć (w drodze kończy się po powrocie). W panelu portu cel rejsu „do mojej prowincji” wiezie plan sprzedaży do innej prowincji gracza zamiast za horyzont. Na mapie świata szlaki są kropkowane, a pojazdy jadą po nich.
- **Zmiana 2026-11-07 (ankieta):** szlaki lądowe obsługuje **wóz kupiecki** ze **składu kupieckiego** (nowy budynek 3×3, jeden wóz z płóciennym dachem na 40 sztuk, o 25% wolniejszy od zwykłego wozu, jeździ tylko szlakami). Stajnie zostają przy pracy w mieście. Jeden kurs mieści całe żądanie osady neutralnej.

### 4.6 Handel zewnętrzny [1.0]

- **Kupcy wędrowni** odwiedzają targowisko lub port co pewien czas, z ograniczoną ofertą kupna i sprzedaży.
- **Stan w M4b-2 (decyzje 2026-11-05):** kupiec przyjeżdża z krawędzi mapy co ok. 10 minut gry i stoi 3 minuty przy targowisku (bez targowiska nie przyjeżdża). Kupuje po stałych cenach (cena bazowa towaru) wszystko, co magazyny mają ponad próg ustawiony przez gracza przy towarze w oknie „Zapasy królestwa”; domyślnie nic. Tragarze noszą towar do jego wozu. Sprzedaje tylko świnie (4 na wizytę, 30 złota), które tragarz prowadzi do chlewu.
- **Stan w M5, część 2 (2026-11-06):** kupiec morski przypływa obcą kogą zza krawędzi morza co ok. 12 minut gry do portu z wolnym nabrzeżem (bez portu nie przypływa) i stoi 4 minuty. Kupuje do 40 sztuk nadwyżek po cenie bazowej według tych samych progów „sprzedaj ponad N” co kupiec wędrowny, ale nie kupuje towarów, które sam sprzedaje. Przywozi 20 desek, 10 smoły i 10 sukna i sprzedaje je po cenie bazowej +50%, dopóki królestwo ma mniej, niż gracz ustawił w oknie „Zapasy królestwa” w kolumnie „Kupno z morza” (próg „kupuj do N”), i dopóki starcza złota. Każdą sztukę portowcy niosą po trapie, a złoto przechodzi z rąk do rąk przy każdej sztuce.
- **Stan w M5, część 3 (2026-11-06):** własna koga gracza odbywa **rejsy za horyzont**. W panelu portu gracz układa plan: towary na sprzedaż (po 5 sztuk, do 4 miejsc w ładowni po 10) i zamówienie z oferty kupca morskiego (deski, smoła, sukno). Koga czeka na kotwicy w zatoce, na rozkaz podpływa do nabrzeża, portowcy ładują towar po trapie, a ona wypływa za krawędź mapy. Za horyzontem sprzedaje ładunek po cenie bazowej +25% i kupuje zamówienie po cenie kupca morskiego (złoto na zamówienie bierze ze skarbca przy wypłynięciu, „sakiewka”). Wraca po ok. 6 minutach; złoto ze sprzedaży wpływa po zacumowaniu, a portowcy znoszą zamówienie na plac. Przycisk „Odpłyń teraz” wysyła kogę z tym, co już załadowano.
- W prowincjach z portem dostępny jest handel z obcymi portami: stałe ceny z wahaniami.

---

## 5. Budowanie

### 5.1 Zasady ogólne

- Budynki zajmują prostokątny obszar kafli (footprint). Mają **wejście** na wskazanym kaflu krawędzi, w które postacie wchodzą i z którego wychodzą, zawsze przez kafel przed drzwiami. Magazyny mają drzwi z każdej strony, inne budynki oprócz domów także z tyłu; wystarczy jedne drzwi z wolnym przejściem (M4b-1.5). Postawiony budynek można obrócić w jego panelu.
- Budowa jest fizyczna: plac budowy, dostawa materiałów przez tragarzy, praca budowniczego i fazy budowy.
- Budynku nie da się postawić tam, gdzie ludzie nie dojdą, ani tak, żeby odciął drogę do wejścia innego budynku, towarów na ziemi albo ludzi (decyzja 2026-11-05: zamurowany plac budowy blokował tragarzy i budowniczych). Budowniczy, który nie może dojść do placu, idzie na następny. Gdy wejście wypadłoby od strony wody (np. chata rybaka obrócona drzwiami do rzeki), gracz dostaje osobny komunikat.
- **Obracanie (M4b-1.5, decyzja 2026-11-05):** gracz wybiera, z której strony budynek ma wejście. Domy mają 4 strony, pozostałe budynki 2 (wejście zawsze od strony kamery, żeby praca była widoczna). Podgląd sam obraca wejście do przylegającej drogi, a klawisz R zmienia stronę ręcznie.
- Rozbiórka zwraca część materiałów, które trafiają na plac budowy i stamtąd są odnoszone do magazynu.

### 5.2 Drogi

**Drogi są opcjonalne.** Budynki działają bez nich, a postacie chodzą też po terenie otwartym. Drogi dają:

| Korzyść | Wartość wyjściowa (do strojenia) |
|---|---|
| Szybszy ruch pieszych | droga ubita +50% (darmowa, od razu), brukowana +80% (M4b-3: 1 kamień na kafel, tragarze przynoszą kamień, budowniczy układa kafel po kaflu; do tego czasu kafel jest drogą ubitą) |
| **Wozy** (tylko po drogach) | stopnie transportu: tragarz niesie **1** sztukę, mały **wózek ręczny 3**, duży **wóz konny 5–6** (tylko po drogach); przewozy między magazynami, szlaki handlowe. **Wózek (M4b-3):** sprzęt tragarza magazynu, kupowany w panelu magazynu za 3 deski (najwyżej 2 na magazyn); tragarz bierze go do zleceń od 2 sztuk; na drodze jedzie jak pieszy, poza drogą 0,7× szybkości; załadunek i rozładunek trwają 1 s na sztukę. **Wóz konny (M4b-3):** stajnia (3×3, 12 drewna, 8 desek, 40 złota) ma 2 woźniców, każdy z wozem; wóz wiezie do 6 sztuk tylko po drogach, 1,3× szybciej niż pieszy; bierze zlecenia od 4 sztuk, gdy oba końce mają drogę przed drzwiami, są od siebie o co najmniej 10 kafli i łączy je droga; ładuje na drodze przed drzwiami, a między kursami wraca do stajni |
| Zasięg usług | liczony długością ścieżki, więc drogi pośrednio poszerzają zasięg studni, targu i kościoła; drzewa go nie skracają (M4b-3, do potwierdzenia przy ocenie) |
| Dla obu stron | wrogie wojsko i bandyci też szybciej poruszają się po drogach, co jest decyzją taktyczną |

Teren też ma koszt ruchu: las i pole spowalniają, a woda, skały i budynki blokują przejście. **Kamienisty grunt (M4b-3):** chodzi się 1,2× wolniej, można budować i kłaść drogi, ale nie da się założyć pola; wydobyta skała zostawia kamienisty grunt. **Jezioro** działa dla wędkarza i glinianki jak rzeka. **Drzewa da się przejść (M4b-2):** przez las idzie się 1,5× wolniej niż po trawie, także przez drzewa posadzone na trawie. Leśniczy sadzi kafel w kafel, bez limitu drzew, ale nigdy na drogach, polach ani tuż przy budynkach.

### 5.3 Mury i fortyfikacje [1.0, prototyp wcześniej]

- Mury można stawiać w **8 kierunkach**: wzdłuż obu osi siatki i po przekątnych. Każdy segment muru zajmuje kafel.
- Połączenia i narożniki dobierane są automatycznie na podstawie sąsiadów w 8 kierunkach (zob. ARCHITECTURE §6.3, ART_SPEC §6).
- Elementy fortyfikacji:
  - palisada (drewno),
  - mur kamienny: można go stawiać w kilku równoległych rzędach, które zlewają się w jeden gruby mur (decyzja 2026-11-04, ARCHITECTURE §6.3),
  - brama: w dwóch orientacjach osiowych [1.0], po przekątnej [PÓŹNIEJ],
  - baszty,
  - schody na mur.
- Po murach chodzą żołnierze i łucznicy. [1.0]
- Przekątny mur jest szczelny: nie da się prześlizgnąć przez styk dwóch kafli narożnikami.

### 5.4 Porty i okręty [1.0]

- **Port** (na brzegu) to nabrzeże z placem portowym i miejscami cumowania. Portowcy fizycznie ładują i rozładowują statki.
- **Stocznia** ma pochylnię. Statek powstaje etapami: szkielet, poszycie, maszt, wodowanie. Potrzebuje desek, smoły i sukna (na żagle).
- Rodzaje statków:

| Statek | Zastosowanie |
|---|---|
| Łódź rybacka | lokalna, przypisana do rybaka |
| Koga | transport i handel |
| Okręt wojenny | transport wojsk i walka |

**Port (M5, część 2):** 4×4, dwa rzędy lądu (plac portowy na 6 stosów) i dwa rzędy nabrzeża na palach nad wodą; jedno miejsce cumowania przed nabrzeżem, z torem wodnym do głębokiej wody. Statek płynący do portu rezerwuje miejsce przy nabrzeżu. Dwóch portowców nosi towar sztuka po sztuce: od wejścia przez nabrzeże i po trapie na statek albo ze statku na plac. Plac portowy jest prywatny: tragarze przynoszą na niego towar tylko na załadunek, a to, co czeka bez statku (np. kupione od kupca), odnoszą do magazynów.

**Koga gracza (M5, część 3):** stocznia buduje kogę w 4 widocznych etapach: szkielet (8 desek), poszycie (10 desek, 4 smoły), maszt z żaglem (2 deski, 4 sukna) i wodowanie (2 smoły), każdy ok. 1 minuty pracy cieśli. Po wodowaniu koga szuka portu (jedna koga na port) i czeka na kotwicy w zatoce, żeby nabrzeże zostało wolne dla kupca morskiego. Rejsy: §4.6.

**Nabrzeża (N1, ankieta 2026-11-07):** gracz stawia linią, jak mury w 8 kierunkach (także po skosie), drewniane pomosty i kamienne nabrzeża w głąb morza, a także do 2 kafli na lądzie przy brzegu; są wysokie nad wodą i widać, jak schodzą pod wodę; rzędy zlewają się w jedno nabrzeże, ludzie po nim chodzą, statki nie. Miejsce cumowania na krawędzi nabrzeża przyjmuje kolejny statek. Część budynków nad wodą (port, stocznia, przystań) to ten sam pas nabrzeża, więc razem z nabrzeżem gracza tworzą jedną bryłę portu, jak w Anno; te budynki można też stawiać na nabrzeżu. **Dźwig przeładunkowy** (część 2, ankieta 2026-11-07) stoi na nabrzeżu najwyżej 2 kafle od miejsca, gdzie cumuje statek: dźwigowy chodzi w kole deptakowym, a ramię przenosi po 3 sztuki w siatce między placem a statkiem, obok portowców (sam ok. 2× tyle co dwóch portowców, razem statek ładuje się ok. 3× szybciej). **Magazyn portowy** to zwykły magazyn stojący na nabrzeżu, najbliżej statków. Wartości: ROADMAP, N1.

**Mosty (B1, ankieta 2026-11-08):** drewniany (3 deski na kafel) albo kamienny z łukami (4 kamienie na kafel) most przez rzekę, bród albo jezioro gracz przeciąga od brzegu do brzegu, jak nabrzeże, prosto albo po skosie w 8 kierunkach, najwyżej 8 kafli wody. Most zaczyna się i kończy rampą na lądzie: boki i poręcze schodzą do ziemi (prośba właściciela 2026-11-08). Ludzie chodzą po nim jak po drodze (drewniany) albo bruku (kamienny), jeżdżą po nim też wózki i wozy. Buduje go budowniczy od bliższego brzegu, tragarze noszą materiał. Rozbiórka zabiera cały most. Na moście i rampach nie stawia się budynków, dróg, pól ani drzew; drzewo na miejscu rampy jest ścinane przy budowie. Droga przeciągnięta przez rzekę sama zamawia most drewniany, a bruk most kamienny (prośba właściciela 2026-11-08).

**Budynki na palach (B1, ankieta 2026-11-08):** chata wędkarza, glinianka, dźwig i magazyn portowy mogą stać jednym skrajnym rzędem nad płytką wodą (płytkie morze, jezioro, rzeka), na palach; reszta budynku na lądzie (dźwig i magazyn portowy na nabrzeżu), wejście od lądu. Za palami zostają co najmniej 2 kafle wody; budynek nie może odciąć łodzi od morza. Brzeg wody jest rysowany miękko, bez schodków po kaflach.

**Port 2 (P2, część 1, ankieta 2026-11-09):** **słupek cumowniczy** (1 kafel, tylko na kamiennym nabrzeżu, ludzie przechodzą obok) przyjmuje statek do handlu, rozładunku i załadunku; nie ma własnego placu: towar idzie do najbliższego magazynu portowego (do 12 kafli), a bez niego prosto do zwykłych magazynów (magazyn w pobliżu nie jest wymagany, decyzja właściciela 2026-11-09). Magazyny portowe w trzech rozmiarach: skład 1×1 (2 miejsca), mały 2×2 (4), duży 3×3 (8); nie mają własnej obsługi. **Chata portowców** (2×2, 2 portowców) i **dom portowców** (3×3, 4 portowców, wieżyczka z wypatrywaczem) to osobne miejsca pracy portowców: obsługują statki przy każdym porcie, miejscu cumowania i słupku w odległości do 12 kafli i pomagają tragarzom nosić towar z i do budynków portowych. Port zostawia swoich 2 portowców. Budynki portowe mają 2 wejścia (od lądu i od wody) i mogą stać na palach nad wodą do 2 rzędów (dom portowców, duży magazyn portowy), także nad głęboką wodą; gdy się nie mieszczą, gra prosi o nabrzeże pod budynkiem.

**Wojsko na okrętach (P2, część 2, ankieta 2026-11-09):** zaznaczeni żołnierze i prawy przycisk na własnym okręcie wojennym: okręt płynie do wolnego miejsca przy nabrzeżu (port, miejsce cumowania, słupek), żołnierze wchodzą na pokład (tylu, ilu mieści okręt), potem okręt odpływa na kotwicę i zwalnia nabrzeże. Przycisk „Wysadź wojsko” w panelu statku wysadza ich tak samo przy wolnym nabrzeżu. Na razie wojsko na okręcie nie odpływa z armią z mapy świata (później, np. M8). Panel statku pokazuje ładownię jako siatkę miejsc z ikonami towarów i liczbami. Okręt wojenny ma osobne miejsca na wojsko, po 10 żołnierzy jednego rodzaju w miejscu, z ikonką żołnierza (ankieta 2026-11-09); na pokład wchodzi tylko tylu, ilu zmieszczą te miejsca.

**Miasto (P2, część 3, ankieta 2026-11-09):** **chata budowniczych** (2×2, 2 budowniczych) daje miastu więcej budowniczych; można ich postawić kilka. **Podatek** ma 5 poziomów, jeden dla całego miasta (brak, niskie, normalne, wysokie, bardzo wysokie: 0×, 0,5×, 1×, 1,5×, 2× złota; +20, +10, 0, −15, −35 zadowolenia), ustawiany suwakiem w panelu ratusza i każdego domu. Panele pokazują ikonki: warsztat, czego potrzebuje i co wytwarza; dom, które potrzeby ma spełnione.

**Plan M5 (decyzje 2026-11-06, szczegóły w ROADMAP):** w M5 tylko łódź rybacka i koga. Łódź pracuje dla nowej **przystani rybackiej** nad morzem (połów z ławic, więcej niż wędkarz, który zostaje). Statki powstają z desek, smoły (nowa **smolarnia**: drewno → smoła) i sukna. **Kupiec morski** przypływa obcą kogą do portu. Własna koga gracza odbywa **rejsy handlowe za horyzont** (wraca ze złotem i zamówionymi towarami). Na „Wybrzeżu” gra zaczyna się od kogi, która wyładowuje osadników na plaży. Reszta drzewka okrętów (IDEAS) później.

### 5.5 Lista budynków [SLICE]

| Budynek | Rozmiar (kafle) | Funkcja |
|---|---|---|
| Ratusz | 4×4 | start osady, siedziba tragarzy |
| Obóz pionierów (M5, część 3) | 3×3 | pierwszy budynek po starcie ze statku: budowniczy i 2 tragarzy, podatki do czasu ratusza; najwyżej jeden na prowincję |
| Magazyn (plac składowy) | 4×4, 15 slotów (od M4b-1; wcześniej 12) | składowanie towarów |
| Chata | 2×2 | dom poziomu 1 → 2 |
| Studnia | 1×1 | usługa w zasięgu |
| Drwal | 2×2 | drewno (ścina drzewa, wiąże kłody, niesie) |
| Farma zbożowa | 2×2 + do 16 kafli pola 1×1 stawianych osobno w zasięgu farmy (decyzja 2026-11-05) | zboże |
| Sad [E2] | 2×2 + do 12 kratek jabłoni w zasięgu 4 kafli, 6 drewna, sadownik | jabłonie rosną razem jak łan (E1), sadownik pieli i zrywa jabłka do kosza (śr. 1,2 kosza z drzewa); jabłka to jedzenie chłopów (obok chleba i ryb), są na targu i w koszarach; jedzenie na start na mapie bez wody |
| Chata myśliwego [E2] | 2×2, 6 drewna, myśliwy, poluje do 20 kafli od chaty | sarny i dziki żyją stadami (2–5 sztuk) na łąkach przy skraju lasu, wędrują, powoli się rozmnażają, nowe stada wychodzą z lasu, gdy jest ich mniej, niż las wykarmi (1 stado na 150 kafli lasu i łąk, 2–8 na mapę), a od miasta trzymają się z daleka; myśliwy podchodzi na 3 kafle, celuje, strzela z łuku (reszta stada ucieka), niesie tuszę na plecach do chaty, oprawia ją na 2 mięsa i zdejmuje skórę |
| Młyn | 2×2 | mąka |
| Piekarnia | 2×2 | chleb |
| Tartak [M4a] | 2×2 | deski |
| Kamieniołom [M4a] | 2×2, skały w zasięgu 12 | kamień |
| Odkrywka [E3] | 3×3, skała w zasięgu 4, tylko w prowincji bogatej w kamień; 8 drewna, 6 desek, 6 kamienia, 50 złota; 3 kamieniarzy | kamień bez końca (na kamieniarza tyle co kamieniołom: 13 wobec 15 sztuk w 10 minut) |
| Głęboka kopalnia [E3] | 3×3, żyła rudy w zasięgu 4, tylko w prowincji bogatej w żelazo (ruda★); 10 drewna, 6 desek, 6 kamienia, 60 złota; 3 górników | ruda żelaza bez końca (na górnika tyle co zwykła kopalnia: 9 wobec 9 sztuk w 10 minut) |
| Chata wędkarza [M4a] | 2×2, woda w zasięgu 5 | ryby |
| Chmielnik [M4a] | 2×2 + do 12 kafli pola | chmiel |
| Browar [M4a] | 2×2, 30 złota | piwo |
| Kaplica [M4a] | 2×2, 10 złota | usługa w zasięgu (chłopi) |
| Kościół [M4a] | 3×3, 60 złota | usługa w zasięgu (mieszczanie) |
| Targowisko [M4a] | 3×3, 40 złota | usługa w zasięgu (mieszczanie); od M4b-2 2 straganiarzy i kramy, przy nim staje kupiec |
| Leśniczówka [M4b-1] | 2×2, zasięg 8 | sadzi drzewa |
| Glinianka [M4b-1] | 2×2, woda w zasięgu 5 | glina |
| Cegielnia [M4b-1] | 2×2 | cegły |
| Owczarnia [M4b-1, Z1] | 2×2 i zagroda z kratek (do 12, 2 owce na kratkę) | wełna (tym szybciej, im więcej owiec) |
| Tkalnia [M4b-1] | 2×2 | sukno |
| Krawiec [M4b-1] | 2×2, 20 złota | ubrania |
| Pasieka [M4b-1, Z1] | 2×2 i ule stawiane jak kratki (do 8) | miód (tym szybciej, im więcej uli) |
| Miodosytnia [M4b-1] | 2×2, 30 złota | miód pitny |
| Tawerna [M4b-1] | 2×2, 40 złota | usługa w zasięgu (patrycjusze), zużywa piwo i miód pitny |
| Chlew [M4b-2, Z1] | 2×2 i zagroda z kratek (do 12, 2 świnie na kratkę) | świnie (świniarz karmi stado w zagrodzie) |
| Rzeźnia [M4b-2] | 2×2 | mięso i skóry ze świni |
| Stajnia [M4b-3] | 3×3, 40 złota | 2 wozy konne z woźnicami |
| Smolarnia [M5] | 2×2 | smoła z drewna |
| Stocznia [M5] | 4×4 (pochylnia na 2 rzędach wody), 30 złota | statki na zamówienie (w części 1 łódź rybacka) |
| Przystań rybacka [M5] | 3×3 (pomost na wodzie) | ryby z ławic, łódź ze stoczni |
| Port [M5] | 4×4 (nabrzeże na 2 rzędach wody), 40 złota | plac portowy, 2 portowców, 1 miejsce cumowania; tu cumuje kupiec morski |
| Pomost / nabrzeże [N1] | kafel na morzu, linią; 2 deski albo 3 kamienie | ludzie chodzą, statki nie; najwyżej 8 kafli od brzegu; port, stocznia i przystań mogą na nim stać |
| Miejsce cumowania [N1] | 2×2 na nabrzeżu, 4 deski | kolejne miejsce dla statku i mały plac na 3 stosy; obsługują je portowcy portu w zasięgu 12 kafli |
| Dźwig przeładunkowy [N1] | 2×2 na nabrzeżu, 12 desek i 4 kamienie, 1 dźwigowy | najwyżej 2 kafle od miejsca cumowania (portu albo miejsca cumowania); przenosi po 3 sztuki między placem a statkiem, obok portowców |
| Magazyn portowy [N1] | 3×3 na nabrzeżu, 8 desek i 4 kamienie, 2 tragarzy | zwykły magazyn na 8 stosów, najbliżej statków |

---

## 6. Jednostki i wojsko [1.0]

### 6.1 Rekrutacja

- Jednostkę rekrutuje się w **koszarach**. Potrzebny jest wolny mieszkaniec z puli siły roboczej, broń i pancerz ze zbrojowni oraz złoto.
- Rekrut fizycznie przychodzi do koszar, odbiera broń i zmienia wygląd.
- **Plan M7 (ankieta 2026-11-07):** rekrut wyprowadza się z domu i mieszka w koszarach (dom przyjmuje przybysza), je z magazynu. Żołdu nie ma (zmiana 2026-11-08, jak w Twierdzy i Anno), za to rekrutacja jest droższa. Ruda żelaza ma małe żyły na każdej mapie, a dużo w prowincji z rudą; konie tylko ze stadniny w prowincji z pastwiskami. Wartości: ROADMAP, M7.

### 6.2 Typy jednostek

| Jednostka | Wymagania |
|---|---|
| Włócznik | włócznia |
| Łucznik | łuk |
| Miecznik | miecz + zbroja |
| Jeździec | koń + miecz + zbroja |
| Halabardnik [J1] | halabarda + zbroja (wytrzymały, ×2,5 przeciw jeździe) |
| Kusznik [J1] | kusza (6 kafli, rzadko i mocno, przebija zbroje) |
| Ciężki zbrojny [J1] | morgenstern + zbroja (najmocniejszy cios, wolny) |
| Lekka jazda [J1] | koń + włócznia (najszybsza, ×2 przeciw strzelcom) |
| Osadnicy | ludzie + towary startowe |
| Taran | oblężnicza |
| Okręty [J1] | duża stocznia: karawela, karaka, galeon, każdy handlowy albo wojenny (40, 60, 90 żołnierzy) |
| Balista [J1] | oblężnicza: warsztat oblężniczy, 16 desek, 4 żelaza, obsługa 2; strzela na 10 kafli w ludzi i machiny, mury słabo |
| Drabiny | oblężnicze |
| Katapulta | oblężnicza [PÓŹNIEJ] |

### 6.3 Armie na mapie świata

- Oddziały z koszar łączą się w armię, która wychodzi na mapę świata przez krawędź prowincji.
- Armia zużywa żywność: nosi zapas, a w prowincjach gracza uzupełnia go z magazynu.
- **M7, część 3 (2026-11-08):** „Wymarsz” w panelu wojska: zaznaczeni żołnierze wychodzą krawędzią mapy i tworzą armię przy mieście; na mapie świata klik na armię, prawy przycisk na prowincję (idzie przez sąsiadów, morzem tylko okrętami wojennymi). 1 chleb na 10 żołnierzy na minutę, zapas na 10 minut; głodna walczy słabiej. U siebie wraca do koszar. Szczegóły i wartości: ROADMAP M7, „Część 3, stan”.

---

## 7. Ruch na mapie świata

- **Bitwy polowe** (dwie armie spotykają się poza oblężeniem): rozstrzygane automatycznie. Wynik zależy od siły, typów jednostek (przewagi), terenu i zaopatrzenia. Gracz dostaje raport z przebiegiem bitwy. [1.0]
- **M7, część 3:** bitwę polową (armia gracza z bandytami, rozbicie obozu bandytów) rozstrzyga `BattleResolver`; raport (etapy i straty) jest w panelu prowincji na mapie świata.
- **M8, część 2 (ankieta 2026-11-09):** armie i floty idą prawym przyciskiem w dowolne miejsce mapy świata (armia po lądzie, flota po morzu) i mogą stanąć wszędzie, także w cudzej prowincji. Wrogie armie, które się spotkają, walczą: gdy to armia gracza, gra staje i pyta, czy walczyć na żywo na mapie pola (teren prowincji bez miasta), czy rozstrzygnąć od razu (z szansami). Floty walczą od razu bitwą morską, z animacją na mapie świata i raportem. Okręty wojenne wypływają na mapę świata z panelu okrętu albo całą flotą z panelu prowincji, razem z wojskiem na pokładzie; flota wysadza wojsko na lądzie i wraca do portu. Szczegóły: ROADMAP M8, „Część 2, stan”.
- **Bitwy morskie**:
  - rozstrzygane automatycznie, tak jak polowe [1.0],
  - **interaktywne bitwy morskie [PÓŹNIEJ, zaplanowane]**: walka okrętów w czasie rzeczywistym na wodach prowincji przybrzeżnej lub wyspowej, np. atak na port, blokada albo desant. Architektura jednostek i walki od początku uwzględnia okręty jako jednostki bojowe (ARCHITECTURE §10), aby ten etap nie wymagał przebudowy.

---

## 8. Oblężenia [1.0]

- Armia wkracza w widok prowincji obrońcy przez krawędź mapy (lub desant z morza [PÓŹNIEJ]).
- Walka toczy się w czasie rzeczywistym, w lekkim stylu RTS:
  - zaznaczanie i rozkazy: idź, atakuj, utrzymaj pozycję,
  - łucznicy na murach mają przewagę zasięgu,
  - taran niszczy bramę, drabiny pozwalają wejść na mur,
  - mury i bramy mają wytrzymałość.
- Cywile uciekają do ratusza lub twierdzy. Produkcja w zagrożonej strefie staje.
- **Plan M7 (ankieta 2026-11-07):** sterowanie jak w Twierdzy (klik albo ramka, prawy przycisk: idź albo atakuj, grupy Ctrl+1..9, postawy). Ratusz ma drzwi z wytrzymałością: napastnik najpierw je rozbija, a gdy przy ratuszu nie ma obrońców, zajmuje prowincję. W M7 atakują bandyci, a gracz może zdobyć siłą osadę neutralną (mury i straż).
- **Stan M7, część 2 (2026-11-08):** bandyci łupią i odchodzą (nie zajmują prowincji), taran i drabiny buduje warsztat oblężniczy, napady rzadkie z ostrzeżeniem (ROADMAP M7, „Część 2, stan”).
- **Stan M7, część 3 (2026-11-08):** osady neutralne mają mury (Żelazny Gród kamienny z basztami, Końska Przystań palisadę), bramę i straż. Armia czeka u granic, gracz wybiera walkę na żywo albo rozstrzygnięcie automatyczne (z szansami). Napady bandytów wychodzą z obozu na mapie świata (ROADMAP M7, „Część 3, stan”).
- **Zwycięstwo atakującego** to zajęcie ratusza (twierdzy) i brak obrońców. Prowincja przechodzi wtedy do atakującego, a mieszkańcy zostają, z karą do zadowolenia.
- Gdy gracz nie ogląda oblężenia, wynik jest rozstrzygany automatycznie. Uwzględnia mury, garnizon i machiny oblężnicze.

---

## 9. Przeciwnicy i tryb sandbox

- **Władcy AI** (2–4) [1.0]:
  - prowadzą gospodarkę w modelu uproszczonym, tym samym co nieoglądane prowincje gracza,
  - podejmują decyzje strategiczne: zasiedlanie, budowa armii, ataki na słabsze prowincje, handel,
  - mają poziomy trudności.
- **Bandyci** [1.0]: okresowe najazdy na prowincje gracza, które grają rolę zagrożenia przed spotkaniem z AI. **M7, część 3:** obóz bandytów stoi w pustej prowincji na mapie świata, napady idą z niego widocznie po mapie, armia gracza może go rozbić (odzyskuje łup; obóz wraca po 30 minutach gdzie indziej).
- **Osady neutralne**: można je wykupić. Nie atakują.
- **Sandbox** [1.0]: wybór mapy lub ziarna generatora, liczby i trudności AI oraz warunku zwycięstwa. Warunki zwycięstwa:
  - podbój,
  - liczba patrycjuszy,
  - posiadanie X prowincji,
  - brak warunku (gra wolna).
- **M8 (ankiety 2026-11-09):** świat generowany z numeru (16–30 prowincji, ten sam numer daje ten sam świat) albo gotowe „Królestwo”; 1–3 władców komputerowych, 3 poziomy trudności; scenariusze: Kolonizacja (bazowy), Podzielony kontynent, Kupieckie wyspy, Najazd z morza; porażka, gdy gracz straci wszystkie prowincje. Armie i floty idą prawym przyciskiem w dowolne miejsce mapy świata i przechwytują wrogów w drodze (bitwa lądowa na żywo na mapie pola albo automatycznie, morska automatycznie). Szczegóły i stan: ROADMAP, M8.
- **Władcy budują, zasiedlają i handlują (M8, część 3, ankieta 2026-11-10):** każdy władca ma własny skarbiec z podatków swoich mieszkańców. Jego miasta rosną według planu rozwoju (od chat i drwali do warsztatów, portu i koszar; od E2, część 4, także sad i chata myśliwego, a gdy brakuje jedzenia, najpierw one); osady neutralne też mają sad i myśliwego; od E3, część 3: w prowincji bogatej w kamień zamiast drugiego kamieniołomu odkrywka (gdy kamienia robi się mało), w bogatej w żelazo na koniec planu głęboka kopalnia, a rudę sprzedają tam, gdzie handlują; Żelazny Gród i osada w prowincji bogatej w kamień mają gotową głęboką kopalnię albo odkrywkę; na łatwym ok. 40% wolniej, na trudnym ok. 30% szybciej i z małym zapasem na start. Wysyła wyprawy osadników (lądem wozem, morzem kogą), wykupuje osady neutralne i wozi chleb i drewno do młodych prowincji. O puste prowincje i osady ściga się z graczem: kto pierwszy, ten lepszy (spóźniona wyprawa wraca z ludźmi i towarem, wpłaty przegranych przepadają). Jego wozy, kogi i szlaki widać na mapie świata w jego kolorze. Do miasta władcy można wejść i je oglądać (bez budowania), a panel prowincji na mapie świata mówi, co władca buduje, dokąd wysyła osadników i co wykupuje.
- **Władcy zbroją się i atakują (M8, część 4, ankieta 2026-11-10):** władca werbuje żołnierzy w swoich koszarach za złoto (2× cena gracza, bez kowala i łuczarza) i jednego mieszkańca, buduje okręty wojenne. Co kilka sekund „dowódca” waży siłę najbliższych miast (żołnierze, mury) i maszeruje tylko tam, gdzie ma dobre szanse: na innego władcę, osadę neutralną albo gracza; lądem albo na swoich okrętach. Miasto gracza oglądane w tej chwili broni się na żywo (jak przed bandytami, z ostrzeżeniem); inne rozstrzyga się od razu. Zdobyty ratusz bez obrońców = miasto zmienia właściciela, budynki i ludzie zostają. Władca broni się: zawraca wojsko i robi wypad na armię gracza czekającą u jego granicy. Gracz zdobywa miasta władców jak osady neutralne (bronią ich żołnierze z koszar). Władca bez prowincji odpada z gry. Trudność: pierwszy atak po 45/30/20 minutach, wojsko 12/20/30, odwaga (potrzebne szanse) 80/65/50%. **Poziom pokojowy:** władcy rosną jak na łatwym i walczą ze sobą i z osadami, ale nigdy nie atakują gracza (zamiast rozejmów; dyplomacja [PÓŹNIEJ]).
- **Scenariusze (M8, część 5, ankieta 2026-11-10):** we wszystkich gracz ląduje ze statku na wybrzeżu. **Kolonizacja:** prawie wszystko puste. **Podzielony kontynent:** każdy władca ma od razu kilka prowincji z gotowymi miastami (stolica z koszarami), reszta to osady neutralne; gracz zajmuje ostatnią wolną i wszystko wywalcza albo wykupuje. **Kupieckie wyspy:** świat z wysp po 1–3 prowincje; wygrywa, kto pierwszy ma w skarbcu wybraną sumę (2 000–100 000, domyślnie 10 000 zł); władcy też się ścigają (mniej wojska, sprzedają nadwyżki), a gdy władca zbierze ją pierwszy, gracz przegrywa. **Najazd z morza:** bez władców; od 20. minuty co 5 minut 8 coraz silniejszych fal najeźdźców (od 6 do 40 ludzi, później z taranem) przypływa z krawędzi mapy świata na nadmorskie miasta gracza; flotę widać i można ją przechwycić okrętami wojennymi; wygrana fala zajmuje miasto (gracz może je odbić); statek gracza przywozi 6 żołnierzy; zwycięstwo po 60 minutach. Pierwsze fale (do wyboru: brak, 1–5 albo wszystkie, domyślnie 2) tylko łupią jak bandyci i odpływają. Tryb **Przetrwanie**: fale bez końca (do 120 ludzi, potem lepsze jednostki), wynikiem jest liczba odpartych fal i rekord. Bez ratusza napastnicy idą na obóz pionierów.
- **Kampania fabularna**: [PÓŹNIEJ].

---

## 10. Interfejs

- **Pasek górny**:
  - złoto,
  - ludność według klas,
  - zadowolenie,
  - data i prędkość gry (**UI-1, 2026-11-07:** na środku paska zegar i ikony ‖ ▶ ▶▶ ▶▶▶; aktywna świeci złotem).
- **Menu budowy** pogrupowane w kategorie: mieszkalne, żywność, surowce, rzemiosło, usługi, wojsko, fortyfikacje, port.
- **Panel budynku**:
  - stan i bieżący etap pracy,
  - pracownicy,
  - zapasy wejściowe i wyjściowe,
  - priorytet,
  - pauza produkcji.
- **Panel magazynu**: lista towarów z ilościami, zgodna z tym, co widać na placu. Filtry i dopuszczenie lub zablokowanie poszczególnych towarów.
- **Panel mieszkańca**:
  - kliknięcie postaci pokazuje imię, zawód, bieżącą czynność, niesiony towar oraz dom i miejsce pracy,
  - tryb **„śledź”**, w którym kamera podąża za postacią. To element immersji.
- **Nakładki**:
  - zasięg usług,
  - niespełnione potrzeby,
  - zadowolenie,
  - siatka.
- **Powiadomienia**: brak surowca, dom traci mieszkańców, wróg u granic.
- **Mapa świata**: osobny ekran z przełączaniem prowincji, armiami, flotami i szlakami handlowymi. **M6:** panel prowincji (właściciel, mieszkańcy, zapasy, rzadki surowiec, „Wejdź”, wyprawy, „Szlaki handlowe”), panel osady neutralnej z żądaniami, licznikiem czasu i przyciskiem „Zapłać”.
- **Okno „Szlaki handlowe” (M6, część 3)**: lista szlaków z kierunkiem, pojazdem, stanem i towarami (ilość na kurs, próg), przyciski „Wstrzymaj” i „Usuń”, a pod spodem nowy szlak: skąd, dokąd, wóz albo koga, pojazd i pierwszy towar.
- Interfejs mieści dłuższe teksty polskie (+30–40% względem angielskich). Wszystkie kontenery rozciągają się automatycznie.

---

## 11. Zakres

### 11.1 Vertical slice (pierwszy grywalny fragment)

Szczegóły i kryteria ukończenia: [ROADMAP.md](ROADMAP.md), etap M3. W skrócie:
- jedna prowincja kontynentalna z rzeką,
- łańcuch zboże → mąka → chleb → magazyn → dom, drwal i studnia,
- budowa z fizyczną dostawą materiałów,
- dom 1 → 2,
- zapis i odczyt gry,
- PL i EN,
- wszystko na placeholderach, ale w docelowej skali.

**Wnioski z gry właściciela projektu (2026-11-05, M3 i M4a):**
- **M3: 5/5.** „Super się ogląda”, jak mieszkańcy chodzą i wykonują swoje zadania. Filar „widoczna praca” (§1.1) działa i zostaje głównym źródłem frajdy.
- W 20–30 minut da się dojść do 6 domów poziomu 2. Łańcuch chleba widać w trybie „śledź” od pola do kosza. Opis postaci zawsze zgadza się z tym, co robi. Teksty w PL i EN bez uwag.
- **M4a: 4/5.** Mieszczanie, ryby, piwo i logistyka działają. Brakuje „autentyczności”, bo grafiki to wciąż placeholdery. To nie jest problem rozgrywki, tylko grafiki: wzmacnia sens etapu M9 (produkcja grafik, ROADMAP).
- **M4b-1: 4/5, wygląd kamienic 2/5.** Patrycjusze osiągalne, tawerna działa. Wnioski: miasto ma wyglądać jak zwarte pierzeje z narożnikami, domy przodem do drogi (etap M4b-1.5), a gospodarka potrzebuje ujścia nadwyżek i podglądu zapasów oraz produkcji (M4b-2).
- **M4b-2: 5/5 (2026-11-07).** Gęsty las, świnie, kupiec i okno „Zapasy” działają i są czytelne. Brak drewna nie przeszkadza. Do poprawki: stos przy budynku leży na kaflach budynku i wystaje zza jego ścian (drwal, rybak). Decyzja: budynki ze stosem dostają **podwórko**, czyli wolne pole przed wejściem, na którym rośnie stos. Targ: **więcej straganiarzy**, bo 2 nie nadążają w dużym mieście.
- **M4b-3: 5/5 (2026-11-07).** Bruk, wózki, woźnice z wozami, wędkarz, glinianka i kamieniołom działają („woźnica działa!”). Do poprawki: wyraźny znacznik zaplanowanego bruku z możliwością anulowania, obracające się koła wózków i wozów, powtarzalny wzór jeziora i kamienistego gruntu (szwy), sztuczne przejścia rzeka–jezioro i rzeka–morze, zacięcia (duże miasto i podgląd zasięgu przy stawianiu kaplicy lub studni).
- **M5 część 3: 5/5 (2026-11-07).** Start z obozem pionierów „bardzo dobry”, budowa kogi „prawie idealna”, plan rejsu zrozumiały. Do poprawki: koga na starcie od razu czeka w zatoce, osadnicy rozchodzą się po plaży, płynne wodowanie, a start jest za trudny, więc dostaje **czas ochronny** (mieszkańcy się nie złoszczą i nie odchodzą). Most i łagodniejsze wybrzeże: osobny mały etap po M7 (IDEAS).
- **M6: 5/5 (2026-11-07).** Mapa świata, tryb uproszczony, wyprawy, szlaki i wino działają. Do poprawki: przy wykupie osady „Wyślij towar” od razu wybiera żądane towary, a winnica dostaje wygląd prawdziwej winnicy (pale z linkami i krzewy winorośli).
- **UI-1 (wygląd): 5/5 (2026-11-07).** Styl „pergamin i drewno” ładny i czytelny, pasek u góry wygodny. Menu główne do dopracowania: pasek na niebie po linach żagla, warstwy wychodzą poza obraz przy ruchu w dół, ruch mógłby być płynniejszy.

### 11.2 Odłożone [PÓŹNIEJ]

- interaktywne bitwy morskie (zaplanowane jako osobny etap po 1.0),
- kampania fabularna,
- dyplomacja,
- pory roku i sezonowość upraw,
- cykl dnia i nocy (wizualny),
- pożary i choroby,
- przestępczość i bunty,
- katapulty i trebusze,
- bramy po przekątnej,
- premie za łączenie kamienic,
- solone ryby i mięso,
- desant z morza w czasie rzeczywistym.

### 11.3 Wykluczone [WYKLUCZONE]

- multiplayer,
- obrót kamery,
- grafika 3D,
- platformy mobilne i konsole (na tym etapie).
