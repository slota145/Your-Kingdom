# Poczekalnia pomysłów

Tu trafiają pomysły, które **nie są jeszcze ustalone**. Do [ROADMAP.md](ROADMAP.md) przenosimy je wyłącznie za zgodą właściciela projektu, wskazując etap. Gdy pomysł wejdzie do gry, przenosimy go krótko do sekcji „Zrealizowane” na końcu (szczegóły są w ROADMAP).

Format: `- [źródło: gracz/Claude] krótki opis — (opcjonalnie) ocena: koszt, ryzyko, dopasowanie`

Porządki 2026-11-11: zrealizowane pomysły przeniesione na koniec pliku, w poczekalni zostały tylko otwarte.

## Poprawki właściciela (2026-11-13, do zaplanowania)

Lista z rozmowy po G3 część 2b. **Ankieta 2026-11-13: wszystkie punkty weszły do etapu UI-2 (ROADMAP), decyzje tam.** Oceny zostają tu dla historii.

1. [właściciel] **Budowa drogi z dwóch kliknięć:** pierwsze kliknięcie zaczyna drogę, potem podgląd ciągnie się do kursora, a drugie kliknięcie ją stawia (zamiast „rysowania” po mapie). To samo dla bruku, a może i murów.
   - Ocena (Claude): koszt mały, tylko narzędzie budowy (widok i interfejs), bez zmian w symulacji. Pytanie do ustalenia: trasa w kształcie „L” (najpierw w jedną stronę, potem w drugą) czy najkrótsza droga omijająca przeszkody. Polecam „L”, bo jest przewidywalne i takie jest w Anno i Twierdzy; prawy przycisk albo Esc anuluje.
2. [właściciel] **Przezroczyste budynki przy budowaniu:** gdy stawiamy drogę albo budynek za budynkami, te z przodu robią się półprzezroczyste.
   - Ocena (Claude): koszt mały. Wariant „przezroczystość” był już w planie widoczności za budynkami (ROADMAP M1, wariant a). Przezroczyste tylko budynki zasłaniające kursor (w promieniu kilku kafli), nie wszystkie.
3. [właściciel] **Zapis, wczytanie, język i powrót do menu w menu pauzy pod Esc** zamiast przycisków na górze ekranu.
   - Ocena (Claude): koszt mały, czysty interfejs; pasek u góry się odchudza. Esc dziś zdejmuje narzędzie budowy: najpierw zdejmuje narzędzie, a dopiero drugie Esc otwiera menu pauzy (gra stoi, gdy menu jest otwarte).
4. [właściciel] **Lepszy start kolonizacji:** dziś na początku nie da się nic postawić, bo tragarze najpierw noszą towary ze startu do magazynu, a budowniczy czeka.
   - Ocena (Claude): prawdopodobna przyczyna: tragarze biorą zlecenia po kolei od najstarszego, więc przenosiny ładunku startowego idą przed budową. Naprawa: zlecenia dla budów mają pierwszeństwo, a budowa może brać prosto z obozu pionierów (nie musi czekać, aż towar trafi do magazynu). Koszt mały do średniego, zmiana w symulacji z testami; trzeba sprawdzić automatycznego gracza i władców (ich czasy budowy się skrócą).
5. [właściciel] **Pracownik zawsze odkłada wyrób na stos przy swoim budynku**, a do magazynu niosą go tragarze (dziś sadownik i inni noszą sami do magazynu, co obniża wydajność).
   - Ocena (Claude): stos przy budynku już jest (M4b-2), ale używany tylko przy pełnych magazynach, więc to głównie zmiana reguły. Pasuje do Anno i Twierdzy, a pracownik dłużej pracuje. Ryzyka: więcej pracy dla tragarzy (może ich zabraknąć na starcie), zmiana balansu całej ekonomii (automatyczny gracz, władcy, testy czasów), stos musi pomieścić co najmniej jedną partię. Koszt średni. Warto razem z punktem 4.
6. [właściciel] **Okno nowej gry z podglądem świata na żywo:** wybór „Nowa gra” otwiera osobne okno, w którym zmiana opcji (wielkość, liczba władców, cechy…) od razu zmienia podgląd tworzonego świata.
   - Ocena (Claude): koszt średni. Świat losuje się szybko, a mapa świata już jest rysowana, więc podgląd to głównie mały widok mapy w oknie i ponowne losowanie przy każdej zmianie (z tym samym ziarnem, żeby świat nie skakał przy każdym kliknięciu).
7. [właściciel] **Napisy nachodzą na siebie** w menu budowy i przy otwarciu mapy świata.
   - Ocena (Claude): to błąd, nie pomysł; do poprawienia od razu (zrzuty z chmury pokażą, gdzie się nakładają, ocena na laptopie w 1920×1080).
8. [właściciel] **Niektóre budynki w menu budowy mają ikonę z etapu budowy** zamiast gotowego budynku.
   - Ocena (Claude): błąd, mały koszt; prawdopodobnie ikona czyta zły plik dla budynków ze SpriteKiln. Do poprawienia od razu.
9. [właściciel] **Ikony zamiast napisów** dla narzędzi: droga, bruk, burzenie itp. (napisy zajmują dużo miejsca).
   - Ocena (Claude): koszt mały; ikony z podpowiedzią po najechaniu myszą (nazwa i skrót klawisza), żeby nie zgadywać. Ikony narysować w stylu reszty interfejsu.

## Ekonomia (pomysły po UI-2)

- [właściciel, 2026-11-13] **Limit towaru w magazynie:** dla każdego towaru gracz ustawia limit (np. 100 desek); po jego osiągnięciu warsztaty, które go robią, przestają pracować, dopóki zapas nie spadnie poniżej limitu.
  - Ocena (Claude): dobry pomysł, znany z Anno i Settlersów: drewno nie idzie w niepotrzebne deski, a gracz panuje nad łańcuchami. Koszt średni: limit w zapisie (nowa wersja z migracją), sprawdzenie przed cyklem warsztatu (jak dziś „stos pełny”), powód w panelu („czeka: limit desek”), suwaki w oknie „Zapasy królestwa” (obok progu sprzedaży kupcowi i rezerwy na budowy). Uwaga: stojący warsztat to bezczynni pracownicy, więc domyślnie bez limitu. Automatyczni gracze i władcy mogą zostać bez niego. **Ankieta 2026-11-13: po części 3 UI-2, jako krótki osobny kawałek przed G3. Plan: ROADMAP, E5.**

## Zamek i wojsko

- [gracz] **Hurdycje na murach:** drewniane galerie na koronie muru kamiennego, następny stopień po blankach (pomysł z „Grubych murów jak w Twierdzy”, których reszta weszła w M7).
  - Ocena (Claude): ulepszenie kafla muru rysowane na odsłoniętych krawędziach korony, z premią obronną dla łuczników. W M7 świadomie odłożone („hurdycje później”).

- [Claude] **Życie przy bramie:** strażnik obsługuje kołowrót przy podnoszeniu brony, a wozy zatrzymują się czasem do kontroli. Właściciel projektu jest na tak (2026-11-04). Wieża bramna weszła w M7, ten detal jeszcze nie.

- [Claude, 2026-11-09] **Barwy wojsk władców:** żołnierze władców i straż osad wyglądają tak samo jak żołnierze gracza, więc na mapie pola trudno odróżnić swoich od wrogów. Tarcze, proporce albo pasy na ubraniu w kolorze właściciela (gracz czerwony, władcy niebieski, zielony, fioletowy).
  - Ocena: grafika postaci w kilku kolorach (podmiana palety przy wczytaniu, bez nowych rysunków), mało pracy w kodzie. W ROADMAP (M8) „herby i kolory władców” są dalej do ustalenia.

- [właściciel, 2026-11-10] **Katapulta:** nowa machina oblężnicza (zasięg, amunicja, koszt). Taran i balista ze SpriteKiln już są. W ROADMAP katapulty i trebusze są w „Po wersji 1.0” (P6).

- [właściciel, 2026-11-11] **Baraki i garnizon:**
  - **Baraki:** prosty budynek wojskowy, który daje tylko łóżka dla żołnierzy (bez rekrutacji). Więcej wojska bez stawiania kolejnych koszar.
  - **Garnizon:** budynek, w którym rekrutujemy żołnierzy trochę taniej, ale gracz nie może nimi dowodzić. Sami pilnują miasta: piechota patroluje ulice i obsadza bramy, a łucznicy i kusznicy patrolują mury i stoją na bramach i basztach.
  - Ocena (Claude): dobre, zwłaszcza garnizon, bo daje dużo immersji (strażnicy chodzą po murach) i realną obronę przed bandytami bez klikania. Ryzyka: patrole to nowe zachowanie żołnierzy (trasy po murach i ulicach, zmiany warty), a obsadzanie wież i bram trzeba połączyć z dzisiejszą walką na murach. Baraki są proste (budynek z łóżkami, jak koszary bez rekrutacji), ale ich sens trzeba sprawdzić przy balansie łóżek dużych koszar (30). Grafiki ze SpriteKiln w stylu nowych koszar.
  - Kiedy: do decyzji właściciela, najwcześniej po E4 (np. osobny mały etap wojskowy przed M10).

## Morze i statki

- [właściciel, 2026-11-09] **Bitwa morska na żywo:** po przechwyceniu wrogiej floty bitwa rozgrywa się na mapie pustego oceanu: okręty manewrują, strzelają i idą do abordażu.
  - Ocena (Claude): nowy system walki statków. Ankieta 2026-11-09: w M8 bitwa morska automatyczna z animacją i raportem (jest), bitwa na żywo jako osobny etap po M8.

- [gracz, 2026-11-06] **Sterowanie statkiem w prowincji:** zaznacz kogę, kliknij prawym na wodę, a koga tam płynie i rzuca kotwicę (np. żeby przestawić ją w inne miejsce). Dziś prawy przycisk działa tylko przy załadunku wojska na okręt (P2).
  - Ocena (Claude): koszt średnio-mały (siatka ruchu po wodzie i kotwiczenie już są).

- [gracz, ocena M5 2026-11-07] **Rejsy za horyzont w oknie mapy świata**, obok szlaków handlowych: gracz ustawia rejs, a gra sama wybiera wolny statek i magazyn.
  - Ocena (Claude): wygodne przy wielu portach i prowincjach, mało ryzykowne (okno szlaków już istnieje). Decyzja właściciela (2026-11-07): na później.

- [gracz, 2026-11-06] **Reszta portu z pomysłu na nabrzeża:** kuter z większą chatą rybacką (wypływa daleko w morze), latarnia morska (na razie ozdoba), dźwig naprawczy (naprawa statków po bitwach), balisty i wieże portowe.

- [Claude, 2026-11-07] **Drobiazgi w porcie:**
  - **Dźwig wybiera statek:** przy dwóch miejscach w zasięgu obraca się do tego, przy którym jest więcej ładunku.
  - **Obracające się koło deptakowe:** 4 klatki obrotu, gdy dźwigowy w nim idzie. Koszt mały (grafika i widok).
  - **Skrzynie i beczki na linie:** zamiast ikon towaru osobne rysunki ładunku (skrzynia, beczka, wiązka desek).

## Teren i mapa

- [gracz, 2026-11-05] **Wysokość terenu (wysokie klify, płaskowyże, wodospady):** mapa nie powinna być płaska. Teren ma kilka poziomów oddzielonych skalnymi ścianami, a rzeka spada z wyższego poziomu wodospadem. Właściciel projektu uważa, że kiedyś trzeba to dodać.
  - Ocena (Claude):
    - Pasuje do gry z oblężeniami: obrona na wzgórzu, wąskie przejścia, naturalne mury. Daje też dużo klimatu.
    - To osobna mechanika, nie sam tileset. Klif blokuje ruch, więc postacie i tragarze muszą go obchodzić albo wchodzić po zboczach i schodach. Budynki nie mogą stać na krawędzi. Dochodzą zasłanianie postaci przez wyższy teren, sortowanie głębi na kilku poziomach i generator mapy, który układa płaskowyże z sensem.
    - Grafika jest tania: ściana klifu w kawałkach i animowany wodospad.
    - Koszt: duży (nawigacja, sortowanie, generator). Ryzyko: średnie.
  - Niski brzeg rzeki (woda kilka pikseli poniżej trawy, ziemna skarpa wzdłuż brzegu) to **tylko grafika** i nie wymaga tej mechaniki. ART_SPEC §3.1 już przewiduje takie kafle (64×48).

- [właściciel, 2026-11-10] **Dalej z mieszanym lasem** (5 gatunków drzew już jest): gatunki zależne od terenu (iglaste wyżej i na kamienistym gruncie, liściaste przy wodzie), skupiska jednego gatunku zamiast losowej mieszanki, różne drewno z różnych drzew (np. sosna na smołę), pora roku (jesienne liście).

## Ekonomia i miasto

- [gracz, 2026-11-05] **Skąd biorą się nowi mieszkańcy:** docelowo przybywają do miasta razem z okresami handlowymi (np. z kupcami) oraz przez symulowany przyrost naturalny. Dziś po prostu przychodzą pieszo z krawędzi mapy, gdy w domu jest wolne miejsce.
  - Ocena (Claude): pasuje do klimatu i daje graczowi rytm („przyjechała karawana, przybyło 6 osób”). Przyrost naturalny łatwo policzyć na domach (np. szansa na dziecko zależna od zadowolenia), a dzieci dorastają w siłę roboczą po czasie.

- [Claude, 2026-11-05] **Utrzymanie budynków:** złota dalej przybywa szybciej, niż jest na co je wydać. Kupiec i podatki już działają, utrzymanie budynków (koszt co minutę) czeka.

- [gracz, 2026-11-06] **Natychmiastowa budowa jako opcja gry:** w opcjach przełącznik „tryb immersyjny” (jak dziś, domyślny) albo „tryb uproszczony”, w którym budynek stoi od razu po kliknięciu, a materiały znikają z magazynów w tej samej chwili. Ankieta 2026-11-06: zrobić dużo później, przed 1.0 (razem z innymi ustawieniami gry).
  - Ocena (Claude): koszt mały do średniego. Ryzyka: dwie wersje gry do testowania przy każdym nowym budynku, balans (automatyczny gracz liczy czasy dla budowy z tragarzami), ustawienie musi trafić do zapisu gry. Łagodniejszy wariant: „szybka budowa” (widoczna, ale np. 5× szybciej). Tryb deweloperski z E4 buduje od razu, ale to narzędzie do testów, nie opcja gry.

## Klimat i immersja

- [Claude] **Efekty przy pracy:** dym z komina piekarni tylko wtedy, gdy piekarz piecze, śmigło młyna kręci się tylko przy mieleniu, a z pola przy żniwach lecą źdźbła. Widok ma już czynność postaci, więc efekt można włączać po `activity`. Koszt mały, a dużo daje dla „żywego” miasta.

- [właściciel, 2026-11-05] **Obracanie kamery:** żeby zobaczyć, co jest za budynkami.
  - Ocena (Claude): w izometrii 2D każdy budynek i postać potrzebuje wtedy grafik z 4 stron, czyli ok. 4× więcej rysowania. Tańsza alternatywa: przezroczyste budynki przy kursorze albo przycisk „ukryj budynki”.

- [Claude, 2026-11-11] **Wyższe kłosy na żyznej ziemi:** na polach w prowincji z żyzną ziemią zboże, chmiel i krzewy rosną wyżej i gęściej, a ziemia jest ciemniejsza. Gracz widzi cechę od razu, bez zaglądania do panelu farmy.
  - Ocena (Claude): logika już jest (+50% plonu), więc to tylko wygląd. Najtaniej przy G3 (nowe grafiki ze SpriteKiln), żeby nie rysować pól dwa razy. W ankiecie części 4 E3 właściciel wybrał na razie tylko linijkę w panelu.

- [Claude, 2026-11-11] **Dzieci chodzą do szkoły:** z domów mieszczan rano wychodzą dzieci, idą do szkoły, siedzą w ławkach na lekcji i po dzwonku wracają do domów.
  - Ocena (Claude): piękna immersja, ale to nowe małe postacie ze SpriteKiln, ławki z siedzącymi dziećmi (pierwsza próba na podwórku szkoły „nie wyglądała najlepiej”, właściciel 2026-11-11) i ruch w mieście. Najlepiej razem z G3. W ankiecie części 2 E4 właściciel wybrał szkołę bez uczniów.

- [Claude, 2026-11-10] **Detal w zagrodach:** zwierzęta podchodzą do płotu, świnie zbiegają się do koryta, gdy świniarz niesie paszę.

## Zrealizowane

Krótka lista pomysłów z tej poczekalni, które weszły do gry. Szczegóły w ROADMAP przy podanym etapie.

- **Grube mury jak w Twierdzy** (model bryłowy, blanki, chodzenie po murach) → prototyp 2026-11-04, M7. Hurdycje czekają wyżej.
- **Wieża bramna** (bryła 3×3, brona, przejście) → M7.
- **Scenariusz kolonizacji** (start ze statku na „Wybrzeżu”, zasiedlanie kolejnych prowincji) → M5 i M6.
- **Fikcyjne okręty** (łódź, koga, karawela, karaka, galeon, wersje wojenne) → M5 i J1.
- **Nabrzeża w głąb morza** (pomost, nabrzeże, miejsce cumowania, dźwig, magazyn portowy) → N1; słupki, dokerzy, statek sam szuka wolnego miejsca → P2.
- **Stopnie transportu** (tragarz, wózek, wóz konny) → M4b-3.
- **Leśniczy i odrastanie lasu** → M4b-1.
- **Opał przed budową** (rezerwa drewna) i **tragarze w magazynach** → M4a (tragarze magazynów później zastąpieni w P2).
- **Kutry rybackie** (przystań rybacka z łodzią) → M5.
- **Wstrzymanie produkcji** → M4b-1.
- **Straganiarze na targowisku** i **kupiec wędrowny** → M4b-2.
- **Zagrody kratkami** (świnie, owce, konie, ule przy pasiece) → Z1.
- **Obracanie budynków** (klawisz R) → M4b-1.5.
- **Obóz pionierów na start, ratusz jako siedziba prowincji** → M5 i M6.
- **Dom budowniczych** (chata budowniczych) → P2.
- **Rejsy w kółko** (szlaki handlowe) → M6.
- **Most przez rzekę i łagodniejszy brzeg** → B1.
- **Nowe jednostki i okręty** oraz nowe „Wybrzeże” → W1 i J1.
- **Bitwa morska automatyczna z raportem** → M8 (wersja na żywo czeka wyżej).
- **Mieszany las** (5 gatunków ze SpriteKiln) → 2026-11-10.
- **Taran i balista ze SpriteKiln** → 2026-11-10 (katapulta czeka wyżej).
- **Pakiet ekonomii z 2026-11-10:** większe stosy i dom tragarzy, pole rośnie po zasianiu całości, ręczny awans → E1; sad, myśliwy, dieta i nowe potrzeby → E2; cechy prowincji → E3; szkoła, uniwersytet, badania, małe i duże koszary → E4.
