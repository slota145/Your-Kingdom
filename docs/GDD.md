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
| Świat | fikcyjny, w stylu środkowoeuropejskiego średniowiecza (XII–XIV w.), z delikatnym słowiańskim klimatem |
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
  - **właściciela**: gracz, władca AI, osada neutralna albo prowincja pusta.
- Na mapie świata poruszają się **armie** (lądem), **floty** (strefami morskimi) i **konwoje handlowe** (wozy lub statki).
- Ruch odbywa się w czasie rzeczywistym, po krawędziach grafu, a czas przejścia zależy od dystansu i rodzaju jednostki.

#### Zdobywanie prowincji

| Sposób | Opis | Zakres |
|---|---|---|
| Zasiedlenie | Do pustej prowincji wysyłamy **osadników**: jednostkę z prowincji macierzystej, która zabiera ze sobą ludzi i zestaw startowy (drewno, żywność, narzędzia). Po dotarciu powstaje osada z ratuszem i magazynem. | [1.0] |
| Wykup osady neutralnej | Osada neutralna przyłącza się za złoto i dostawy towarów (np. przez określony czas). | [1.0] |
| Oblężenie | Armia dochodzi do prowincji przeciwnika i rozpoczyna oblężenie. W widoku prowincji walka toczy się w czasie rzeczywistym (§8). Gdy prowincja nie jest oglądana, wynik oblężenia jest rozstrzygany automatycznie. | [1.0] |
| Dyplomacja (sojusze, wasalizacja) | — | [PÓŹNIEJ] |

### 2.2 Widok prowincji (właściwa rozgrywka)

- Mapa kafelkowa o rozmiarze 96–192 kafli na bok, zależnie od typu mapy.
- Tu budujemy, produkujemy, rekrutujemy, budujemy okręty i bronimy się.
- **Szczegółowo** (z postaciami) symulowana jest tylko prowincja oglądana. Pozostałe działają w trybie uproszczonym; ich wyniki są spójne z trybem szczegółowym (zob. ARCHITECTURE §7).

#### Typy map prowincji

| Typ | Cechy | Zakres |
|---|---|---|
| Kontynentalna | Bez morza. Opcjonalnie z rzeką (rybołówstwo, młyn wodny, przeprawa) lub jeziorem. Nie ma portu morskiego. | [SLICE] tylko wariant z rzeką · [1.0] wszystkie |
| Przybrzeżna | Ląd z linią brzegową: port, stocznia, rybołówstwo morskie. | [1.0] |
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
| Mieszczanie | chleb **oraz** (mięso lub ryby), piwo, drewno opałowe | kościół, targowisko w zasięgu |
| Patrycjusze | jak mieszczanie + ubrania, wino lub miód pitny | łaźnia lub tawerna |

Zasady:
- **Dostarczanie towarów do domów jest widoczne.** Domownik idzie do najbliższego magazynu lub targowiska po zapasy i niesie je do domu. Dom ma mały zapas, np. na 2–3 cykle konsumpcji. [SLICE]: zaopatrzenie z magazynu. Targowisko z zasięgiem i straganiarzami: [1.0].
- **Usługi** (studnia, kaplica, kościół, łaźnia) działają przez **zasięg** liczony długością ścieżki od budynku usługowego.
- **Zadowolenie** domu (0–100) wynika ze spełnienia potrzeb i wpływa na:
  - podatki,
  - napływ nowych mieszkańców (gdy w domu są wolne miejsca),
  - wydajność pracowników (±20% tempa pracy).

### 3.3 Rozwój domów

- Dom **awansuje**, gdy przez określony czas (domyślnie 60 s czasu gry) spełnia **wszystkie potrzeby podstawowe** swojej klasy, a materiały na ulepszenie zostaną **fizycznie dostarczone** (np. deski, cegły). W czasie ulepszenia na domu pojawia się rusztowanie.
- Dom **cofa się** o poziom, jeśli potrzeby podstawowe nie są spełniane przez dłuższy czas (domyślnie 180 s). Wcześniej gracz dostaje ostrzeżenie.
- **Łączenie w kamienice** (od poziomu 2): domy tego samego poziomu, ustawione obok siebie w jednej linii wzdłuż osi siatki i równo wyrównane, wizualnie łączą się w pierzeję. Zamiast osobnych budynków widać fragmenty: koniec lewy, środek i koniec prawy. Łączenie jest **wyłącznie wizualne** i nie zmienia symulacji. Rozważymy później premię (np. mniejsze zużycie opału) [PÓŹNIEJ].

### 3.4 Ludność i praca

- Liczba mieszkańców to suma ludności domów. **Siła robocza** to ok. 50% mieszkańców (pozostali to dzieci, starzy i domownicy).
- **Każdy zatrudniony pracownik jest widoczną postacią.** Pozostali mieszkańcy nie mają stałych postaci. Wyjątkiem są domownicy, którzy pojawiają się na czas wyjścia po zapasy, oraz kilku przechodniów dla ożywienia ulic.
- Pracownik ma przypisany dom i miejsce pracy. Przy zatrudnieniu wychodzi z domu i idzie do pracy, potem już tam pozostaje. Nie ma cyklu dnia i nocy.
- Brak siły roboczej oznacza, że budynki stoją puste i pokazują ikonę braku pracowników.
- Priorytety zatrudnienia ustawia się na poziomie budynku: wysoki, normalny, niski. [1.0]

### 3.5 Podatki i złoto

- Domy płacą podatek okresowo, zależnie od klasy i zadowolenia. Gracz ustawia stawkę: niska, normalna, wysoka. Stawka wpływa na zadowolenie.
- Złoto wydajemy na budowę części budynków, rekrutację, handel, wykup osad i utrzymanie wojska.
- Złoto jest pulą globalną królestwa. To jedyny zasób globalny.

---

## 4. Ekonomia

### 4.1 Zasady

1. **Każda prowincja ma własne magazyny.** Nie ma globalnej puli towarów. Towary między prowincjami przewożą konwoje i statki (§4.5).
2. **Magazyn to fizyczne miejsce.** Plac składowy ma sloty. Każdy slot przechowuje jeden rodzaj towaru do określonej ilości i jest pokazany stosem w jednej z kilku faz zapełnienia. Pojemność magazynu wynika z liczby slotów.
3. **Model transportu jest zbliżony do Twierdzy.** Pracownik budynku produkcyjnego sam przynosi surowce z magazynu i sam odnosi wyroby do magazynu. Tragarze magazynów zajmują się dostawami na budowy, przewozem między magazynami (później także wozami) i portem.
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

[1.0]
drewno ──► tartak ──► deski
glina + drewno opałowe ──► cegielnia ──► cegły
kamieniołom ──► kamień
sad ──► jabłka
rybak ──► ryby
chlew ──► świnie ──► rzeźnik ──► mięso + skóry
zboże + chmiel ──► browar ──► piwo
pasieka ──► miód ──► miodosytnia ──► miód pitny
winnica★ ──► winogrona ──► winiarnia ──► wino
owczarnia ──► wełna ──► tkalnia ──► sukno ──► krawiec ──► ubrania
drewno ──► węglarz ──► węgiel drzewny
kopalnia★ ──► ruda żelaza + węgiel ──► huta ──► żelazo ──► kowal ──► narzędzia / miecze / włócznie
drewno ──► łuczarz ──► łuki
skóry ──► garbarz-płatnerz ──► zbroje skórzane · żelazo ──► płatnerz ──► kolczugi
stadnina★ ──► konie
drewno ──► smolarnia ──► smoła (stocznia)
```

### 4.4 Widoczna praca: przykłady etapów

| Budynek | Etapy cyklu |
|---|---|
| Farma zbożowa | rolnik orze pole (kafel po kaflu) → sieje → zboże rośnie (zmiana wyglądu kafli w 3 fazach) → żniwa sierpem → wiąże snop → niesie snopy do magazynu |
| Młyn | młynarz bierze zboże z magazynu i niesie worek → wsypuje do kosza (śmigło się kręci) → napełnia worek mąki → niesie mąkę do magazynu |
| Piekarnia | piekarz przynosi mąkę → zagniata ciasto przy stole → wsadza je łopatą do pieca (dym z komina) → wyjmuje chleb → niesie kosz chleba do magazynu |
| Rybak | idzie na pomost lub do łodzi → zarzuca sieć → wyciąga ją → niesie kosz ryb |
| Kowal | przynosi żelazo i węgiel → rozgrzewa w palenisku → kuje na kowadle (iskry) → hartuje w wodzie → niesie broń do zbrojowni |
| Port | portowcy przenoszą skrzynie i beczki z placu portowego na statek po trapie, sztuka po sztuce. Ładunek statku rośnie w interfejsie i jest widoczny na pokładzie. |
| Budowa | tragarze przynoszą materiały na plac budowy (widoczny stos) → budowniczy pracuje młotkiem → rusztowanie → budynek gotowy |

Ikona nad budynkiem i panel budynku pokazują, co aktualnie się dzieje, np. „Piekarz: piecze chleb (60%)”, „Czeka na mąkę”.

### 4.5 Logistyka między prowincjami [1.0]

- **Szlak handlowy** łączy dwie prowincje (A→B), określa towar, ilość i próg, np. „wożę chleb, gdy w B jest mniej niż 20”.
- Wozy kursują lądem, statki morzem. Na mapie świata widać ich ruch.
- W widoku prowincji tragarze ładują i rozładowują wozy w magazynie, a portowcy statki w porcie.

### 4.6 Handel zewnętrzny [1.0]

- **Kupcy wędrowni** odwiedzają targowisko lub port co pewien czas, z ograniczoną ofertą kupna i sprzedaży.
- W prowincjach z portem dostępny jest handel z obcymi portami: stałe ceny z wahaniami.

---

## 5. Budowanie

### 5.1 Zasady ogólne

- Budynki zajmują prostokątny obszar kafli (footprint). Mają **wejście** na wskazanym kaflu krawędzi, w które postacie wchodzą i z którego wychodzą.
- Budowa jest fizyczna: plac budowy, dostawa materiałów przez tragarzy, praca budowniczego i fazy budowy.
- Rozbiórka zwraca część materiałów, które trafiają na plac budowy i stamtąd są odnoszone do magazynu.

### 5.2 Drogi

**Drogi są opcjonalne.** Budynki działają bez nich, a postacie chodzą też po terenie otwartym. Drogi dają:

| Korzyść | Wartość wyjściowa (do strojenia) |
|---|---|
| Szybszy ruch pieszych | droga ubita +50%, brukowana +80% |
| **Wozy** (tylko po drogach) | stopnie transportu: tragarz niesie **1** sztukę, mały **wózek ręczny 3**, duży **wóz konny 5–6** (tylko po drogach); przewozy między magazynami, szlaki handlowe |
| Zasięg usług | liczony długością ścieżki, więc drogi pośrednio poszerzają zasięg studni, targu i kościoła |
| Dla obu stron | wrogie wojsko i bandyci też szybciej poruszają się po drogach, co jest decyzją taktyczną |

Teren też ma koszt ruchu: las i pole spowalniają, a woda i budynki blokują przejście.

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

### 5.5 Lista budynków [SLICE]

| Budynek | Rozmiar (kafle) | Funkcja |
|---|---|---|
| Ratusz | 4×4 | start osady, siedziba tragarzy |
| Magazyn (plac składowy) | 4×4, 12 slotów | składowanie towarów |
| Chata | 2×2 | dom poziomu 1 → 2 |
| Studnia | 1×1 | usługa w zasięgu |
| Drwal | 2×2 | drewno (ścina drzewa, wiąże kłody, niesie) |
| Farma zbożowa | 2×2 + pola do 4×4 | zboże |
| Młyn | 2×2 | mąka |
| Piekarnia | 2×2 | chleb |

---

## 6. Jednostki i wojsko [1.0]

### 6.1 Rekrutacja

- Jednostkę rekrutuje się w **koszarach**. Potrzebny jest wolny mieszkaniec z puli siły roboczej, broń i pancerz ze zbrojowni oraz złoto.
- Rekrut fizycznie przychodzi do koszar, odbiera broń i zmienia wygląd.

### 6.2 Typy jednostek

| Jednostka | Wymagania |
|---|---|
| Włócznik | włócznia |
| Łucznik | łuk |
| Miecznik | miecz + kolczuga |
| Jeździec | koń + miecz + kolczuga |
| Osadnicy | ludzie + towary startowe |
| Taran | oblężnicza |
| Drabiny | oblężnicze |
| Katapulta | oblężnicza [PÓŹNIEJ] |

### 6.3 Armie na mapie świata

- Oddziały z koszar łączą się w armię, która wychodzi na mapę świata przez krawędź prowincji.
- Armia zużywa żywność: nosi zapas, a w prowincjach gracza uzupełnia go z magazynu.

---

## 7. Ruch na mapie świata

- **Bitwy polowe** (dwie armie spotykają się poza oblężeniem): rozstrzygane automatycznie. Wynik zależy od siły, typów jednostek (przewagi), terenu i zaopatrzenia. Gracz dostaje raport z przebiegiem bitwy. [1.0]
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
- **Zwycięstwo atakującego** to zajęcie ratusza (twierdzy) i brak obrońców. Prowincja przechodzi wtedy do atakującego, a mieszkańcy zostają, z karą do zadowolenia.
- Gdy gracz nie ogląda oblężenia, wynik jest rozstrzygany automatycznie. Uwzględnia mury, garnizon i machiny oblężnicze.

---

## 9. Przeciwnicy i tryb sandbox

- **Władcy AI** (2–4) [1.0]:
  - prowadzą gospodarkę w modelu uproszczonym, tym samym co nieoglądane prowincje gracza,
  - podejmują decyzje strategiczne: zasiedlanie, budowa armii, ataki na słabsze prowincje, handel,
  - mają poziomy trudności.
- **Bandyci** [1.0]: okresowe najazdy na prowincje gracza, które grają rolę zagrożenia przed spotkaniem z AI.
- **Osady neutralne**: można je wykupić. Nie atakują.
- **Sandbox** [1.0]: wybór mapy lub ziarna generatora, liczby i trudności AI oraz warunku zwycięstwa. Warunki zwycięstwa:
  - podbój,
  - liczba patrycjuszy,
  - posiadanie X prowincji,
  - brak warunku (gra wolna).
- **Kampania fabularna**: [PÓŹNIEJ].

---

## 10. Interfejs

- **Pasek górny**:
  - złoto,
  - ludność według klas,
  - zadowolenie,
  - data i prędkość gry.
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
- **Mapa świata**: osobny ekran z przełączaniem prowincji, armiami, flotami i szlakami handlowymi.
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
