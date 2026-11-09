# Poczekalnia pomysłów

Tu trafiają pomysły, które **nie są jeszcze ustalone**. Do [ROADMAP.md](ROADMAP.md) przenosimy je wyłącznie za zgodą właściciela projektu, wskazując etap.

Format: `- [źródło: gracz/Claude] krótki opis — (opcjonalnie) ocena: koszt, ryzyko, dopasowanie`

## Mechaniki

- [gracz, ocena M5 2026-11-07] **Most przez rzekę i mniej kanciaste wybrzeże:** most, po którym chodzą ludzie i jeżdżą wozy (na „Wybrzeżu” rzeka odcina wschód mapy), oraz łagodniejsza linia brzegu, na której budynki nadmorskie mogą leżeć częściowo na wodzie.
  - Ocena (Claude): mocno poprawi grę na mapach z rzeką. Most zmienia siatkę ruchu (kafel przejezdny dla ludzi, a pod nim woda dla łodzi albo blokada), sortowanie i budowanie; brzeg to zmiana terenu i reguł stawiania. **Decyzja właściciela (ankieta 2026-11-07): osobny mały etap po M7**, jak N1. **Ankieta 2026-11-08: wybrany jako następny etap po M7 (ROADMAP, B1).**
- [gracz, ocena M5 2026-11-07] **Rejsy za horyzont w oknie mapy świata**, obok szlaków handlowych: gracz ustawia rejs, a gra sama wybiera wolną kogę i magazyn.
  - Ocena (Claude): wygodne przy wielu portach i prowincjach, mało ryzykowne (okno szlaków już istnieje). **Decyzja właściciela (ankieta 2026-11-07): na później, po M7.**

- [gracz] **Grube mury jak w Twierdzy:** dwa lub więcej równoległych rzędów muru zlewa się w jeden gruby, jednolity mur. Do tego wyższy typ muru z **blankami**, później **hurdycje**. Jednostki mogą wchodzić na mury.
  - Ocena (Claude):
    - **Wykonalne bez zmniejszania kratki.** Dla muru kamiennego trzeba przejść z obecnego modelu „linii” (filar + półsegmenty) na model **bryłowy**: każdy kafel muru to pełny blok, a ściany rysujemy tylko tam, gdzie sąsiad nie jest murem. Sąsiednie bloki same zlewają się w jedną masę dowolnej grubości. Sortowanie to po prostu bloki 1×1, które M1 już sprawdził testem.
    - Blanki i hurdycje to **ulepszenie kafla muru** rysowane na odsłoniętych krawędziach korony, z premią obronną dla łuczników.
    - Chodzenie po murach to osobna warstwa nawigacji na koronie, z wejściem przez schody i baszty (już przewidziane w ARCHITECTURE §6.3).
    - Koszt: średni. Ryzyko: mury ukośne w modelu bryłowym wychodzą „schodkowe”. Pomóc mogą trójkątne kawałki wypełniające narożniki, do sprawdzenia w prototypie.
    - Odradzam zmniejszanie kratki: 4× więcej komórek nawigacji, zmiana rozmiarów budynków i grafik, a zysk niewielki, bo przy kaflu 64 px i postaci 42 px na koronie szerokości 1 kafla mieszczą się 1–2 osoby, a przy 2 rzędach ok. 3–4.
    - Propozycja: palisada zostaje w obecnym modelu „linii” (pasuje do drewnianego płotu), a mury kamienne przechodzą na model bryłowy.
  - **Zatwierdzone 2026-11-04:** model bryłowy z przekątnymi „prosto”. Zapisane w ARCHITECTURE §6.3, ART_SPEC §6 i GDD §5.3. Blanki na koronie są w prototypie. Hurdycje i chodzenie po murach czekają na M7.
  - Prototyp (2026-11-04, `src/prototype/walls/`, do oceny przez właściciela):
    - Model bryłowy działa: 2 i 3 rzędy zlewają się w jedną masę, narożniki i trójniki bez szczelin, blanki tylko na odsłoniętych krawędziach korony.
    - Sortowanie postaci na ziemi: 0 błędów w 15 układach × 3 warianty przekątnych (`sort_check.gd`, ta sama metoda co `test_sorting.gd`).
    - Strażnicy na koronie sortują się przez regułę „rysuj po kaflu, na którym stoisz” (`crown_sort_key`). Sprawdzone tylko na zrzutach.
    - Przekątne, trzy warianty (klawisz V):
      - **schodki:** rząd „baszt”, najprostsze,
      - **ścięcie ½:** kliny o przyprostokątnej ½ kafla, wychodzi poszarpane,
      - **prosto:** kliny o przyprostokątnej 1 kafla. Wygląda najczyściej, ale mur ukośny jest √2 grubszy i blokuje połówki sąsiednich kafli.
    - Brama w modelu bryłowym to tunel: dwa filary i pomost niosący koronę. Postać w przejściu jest zasłonięta pomostem. Słabo widać, że to brama, więc przy grafikach docelowych przyda się wyraźny portal.
    - Blanki (2026-11-05, według zdjęcia makiety od właściciela projektu): przedpiersie 16 px będące przedłużeniem lica muru, na nim blanki 14 px, trzy na krawędź kafla, tak szerokie jak przerwy, a w każdym zewnętrznym narożniku blanka narożna w kształcie litery L. Strażnik chowa się do ramion.
    - Grafiki docelowe dałoby się składać z kawałków: wierzch bloku, 2 przednie ściany, 4 krawędzie korony z blankami i kliny.

- [gracz] **Bramy większe od muru (wieża bramna):** brama to masywny budynek wyższy i szerszy od muru, jak w średniowieczu i w Twierdzy. Ma dwie flankujące wieże i portal z broną.
  - Ocena (Claude): pasuje i rozwiązuje słaby punkt z prototypu, w którym brama w grubym murze była słabo widoczna. Technicznie to budynek wielokaflowy, np. 3×2 lub 4×3, z przejściem przez środek. Wieże tniemy przez `BuildingSlicer`, a przejście i pomost działają jak w prototypie. Koszt: średni (grafika + sortowanie przejścia). Kiedy: M7, razem z basztami.
  - Prototyp kodem (2026-11-04, klawisz H w piaskownicy murów), według zrzutu z Twierdzy podesłanego przez właściciela projektu:
    - bryła 3×3 kafle, o 32 px wyższa od muru, drewniany dach z blankami dookoła, łukowe przejście z podniesioną broną i krzyżowe strzelnice,
    - bez wieżyczek: baszty gracz stawia sam, jako osobne budynki (decyzja właściciela projektu),
    - tylko 2 orientacje, przejście wzdłuż osi siatki, jak w Twierdzy,
    - mury dowolnej grubości dochodzą do boków bez szczelin; sortowanie ze sprawdzeniem automatycznym: 0 błędów, także w przejściu.

- [gracz] **Wysokość terenu (wysokie klify, płaskowyże, wodospady):** mapa nie powinna być płaska. Teren ma kilka poziomów oddzielonych skalnymi ścianami, a rzeka spada z wyższego poziomu wodospadem. Właściciel projektu uważa, że kiedyś trzeba to dodać (2026-11-05).
  - Ocena (Claude):
    - Pasuje do gry z oblężeniami: obrona na wzgórzu, wąskie przejścia, naturalne mury. Daje też dużo klimatu.
    - To osobna mechanika, nie sam tileset. Klif blokuje ruch, więc postacie i tragarze muszą go obchodzić albo wchodzić po zboczach i schodach. Budynki nie mogą stać na krawędzi. Dochodzą zasłanianie postaci przez wyższy teren, sortowanie głębi na kilku poziomach i generator mapy, który układa płaskowyże z sensem.
    - Grafika jest tania: ściana klifu w kawałkach (proste w obu skosach, narożniki wypukłe i wklęsłe) i animowany wodospad to ok. 60–100 generacji PixelLab.
    - Koszt: duży (nawigacja, sortowanie, generator). Ryzyko: średnie. Kiedy: osobny etap po rdzeniu symulacji, przed generatorem map.
  - Niski brzeg rzeki (woda kilka pikseli poniżej trawy, ziemna skarpa wzdłuż brzegu) to **tylko grafika** i nie wymaga tej mechaniki. ART_SPEC §3.1 już przewiduje takie kafle (64×48).

- [gracz] **Scenariusz kolonizacji:** podstawowy start gry to lądowanie statkiem na dziewiczym kontynencie z zamiarem jego skolonizowania (fikcyjne średniowiecze, więc wolno). Statek przypływa do brzegu i wyładowuje osadników z zestawem startowym (2026-11-05).
  - Ocena (Claude):
    - Pasuje do inspiracji Anno i do istniejącego zasiedlania pustych prowincji (GDD §2.1): kolejne prowincje zasiedlamy tak samo, tylko pierwsza przychodzi z morza.
    - Wymaga mapy przybrzeżnej i statku na starcie. Dziś pierwszy grywalny kawałek ma mapę śródlądową z rzeką, a morze i statki są w M5.
    - Najtańsza wersja: statek przy brzegu tylko wyładowuje osadników (animacja), bez portu i handlu. Pełna wersja przychodzi razem z M5.
    - Do przemyślenia: czy kontynent jest zupełnie pusty, czy są na nim osady neutralne i władcy AI, którzy przybyli wcześniej.
    - Koszt: mały do średniego (zależy od tego, kiedy). Ryzyko: małe.
  - Decyzja właściciela projektu (2026-11-05): na razie tylko pomysł, bez zmian w planie.
  - **Przyjęte częściowo do M5 (ankieta 2026-11-06):** prosty start ze statku na mapie „Wybrzeże” (koga wyładowuje osadników i zestaw, gracz stawia ratusz). Kolonizacja kolejnych prowincji w M6.

- [gracz] **Fikcyjne okręty w stylu Anno i drzewko rozwoju okrętów:** zamiast samej kogi mamy okręty fikcyjne, inspirowane prawdziwymi okresami: od kogi przez karawelę i karakę aż po duży okręt podobny do galeonu. Zamiast armat ma balisty i skorpiony. Na koniec drzewka mógłby się pojawić galeon z armatami (2026-11-05). Bez decyzji.
  - Ocena (Claude):
    - Fikcyjne okręty pasują: świat jest fikcyjny, a karawele i karaki to XV wiek, czyli jeszcze średniowiecze. Do tego właśnie takimi statkami kolonizowano nowe lądy, więc dobrze łączą się ze scenariuszem kolonizacji.
    - Drzewko rozwoju daje graczowi cel na długą grę. Propozycja: łódź rybacka → koga (tania, na start) → karawela (szybka, do zwiadu i zasiedlania) → karaka (duża, handel i wojsko) → wielki okręt z balistami i skorpionami.
    - **Uwaga na armaty:** jeśli są na okręcie, gracz zapyta, czemu nie ma ich w zamku. Proch zmienia też sens murów i oblężeń, czyli serca gry. Bezpieczniej zakończyć drzewko wielkim okrętem z ciężkimi balistami, a armaty potraktować jako osobną, późną decyzję dla całej gry (ląd i morze razem).
    - Koszt: średni (każdy okręt to grafika z animacją kołysania, budowa w stoczni etapami i dane jednostki). Kiedy: M5.
    - Zmieni GDD §5.4 (rodzaje statków), gdy właściciel projektu zdecyduje.
  - **M5 (ankieta 2026-11-06):** tylko łódź rybacka i koga. Karawela, karaka i wielki okręt czekają na decyzję o kolejnym etapie.
  - Prototyp (2026-11-05, `src/prototype/ships/`): koga narysowana kodem w 8 kierunkach (bryły 3D „fotografowane” w rzucie izometrycznym), z kasztelem z blankami, tarczami i pasiastym żaglem w kolorze frakcji (magenta). Wszystkie kierunki są spójne, a kolejne okręty drzewka da się zrobić, zmieniając wymiary i części w skrypcie.

- [gracz] **Nabrzeża budowane w głąb morza i budynki portowe na nich (2026-11-06):** drewniane pomosty i kamienne nabrzeża stawiane kafel po kaflu w głąb morza, działające jak dzisiejsze mury (rysowanie linią, łączenie się w ciągi, pogrubianie rzędami). Na nabrzeżach stawiamy miejsca cumowania statków i inne budynki portowe: dźwig przeładunkowy, dźwig naprawczy, dodatkowe magazyny portowe, stanowiska balist portowych, wieże portowe, może latarnię morską (gracz nie jest pewien). Do tego większa chata rybaka nadmorskiego z dużym kutrem, który wypływa daleko w morze. Budynki nabrzeżne mogą stać w 2/3 albo w całości na wodzie, co rozwiązuje problem krzywych brzegów. Bez decyzji.
  - Opinia Claude:
    - Bardzo dobry kierunek: to rozwiązuje najsłabsze miejsce M5 (przystań, stocznia i port mieszczą się tylko na prostym brzegu) i daje graczowi własny, rosnący port zamiast gotowego budynku. Pasuje do immersji jak mury.
    - Dobra wiadomość: mamy już prawie wszystko pod spodem. Mury w 8 kierunkach (łączenie, rzędy), budynki częściowo na wodzie, rezerwacja miejsca przy nabrzeżu, portowcy i trap. Nabrzeże to „mur, po którym się chodzi, stawiany na wodzie”.
    - Ryzyka: (1) chodzenie po wodzie: kafle nabrzeża muszą być przejezdne dla ludzi, a zamknięte dla statków, i nie mogą odciąć statkom drogi do morza (to sprawdzenie przy stawianiu, jak dziś dla murów i dróg); (2) sortowanie głębi dużych statków przy długich pomostach (R1); (3) budynek „cały na wodzie” musi mieć dojście po nabrzeżu, więc reguła stawiania zmienia się z „część kafli na lądzie” na „wejście od lądu albo od nabrzeża”.
    - Propozycja kolejności: najpierw pomost drewniany i kamienne nabrzeże (stawianie linią, chodzenie, blokada dla statków) oraz „miejsce cumowania” jako mały budynek na nabrzeżu; port z placem zostaje jako budynek lądowy. Potem dźwigi (przeładunek szybszy niż portowcy na plecach, naprawa uszkodzonych statków po bitwach P1), magazyn portowy, większa chata rybacka z kutrem (kuter: nowy statek, dalsze ławice). Balisty i wieże portowe razem z walką okrętów (M7, P1). Latarnia: tani, ładny detal; mogłaby pozwalać statkom pływać nocą albo przy mgle, jeśli kiedyś będzie pogoda, więc na razie tylko jako ozdoba.
    - Koszt: duży (to osobny etap, wielkości M4b-3). Kiedy: po M5, najlepiej przed M7 (walka okrętów i oblężenia od morza).
  - **Przyjęte jako etap N1 „Nabrzeża i port” przed M7 (ankieta 2026-11-07), wersja średnia:** pomost, nabrzeże kamienne, miejsce cumowania, budynki nad wodą na nabrzeżu i wtopione w nie jak w Anno (pomysł właściciela), potem dźwig przeładunkowy i magazyn portowy. Kuter, latarnia, dźwig naprawczy, balisty i wieże portowe czekają tutaj. Szczegóły w ROADMAP (N1).
- [Claude] **Port po N1, część 2 (pomysły z realizacji, 2026-11-07):**
  - **Koga szuka wolnego miejsca:** dziś koga gracza czeka na kotwicy, gdy kupiec zajął jej port, nawet jeśli obok stoi wolne miejsce cumowania. Mogłaby cumować przy dowolnym wolnym miejscu swojego portu. Koszt mały, ryzyko: rejs zaczyna się wtedy z innego placu.
  - **Dźwig wybiera statek:** dźwig dziś obsługuje jedno najbliższe miejsce; przy dwóch miejscach w zasięgu mógłby obracać się do tego, przy którym jest więcej ładunku.
  - **Obracające się koło:** koło deptakowe w grafice stoi; mogłoby mieć 4 klatki obrotu, gdy dźwigowy w nim idzie. Koszt mały (grafika i widok).
  - **Skrzynie i beczki na linie:** zamiast ikon towaru w siatce osobne rysunki ładunku (skrzynia, beczka, wiązka desek).

- [gracz] **Stopnie transportu:** tragarz niesie 1 sztukę, mały wózek ręczny 3, duży wóz konny 5–6.
  - **Zatwierdzone 2026-11-05 (ładowności):** zapisane w GDD §5.2. Szybkości, czas załadunku i reguły dyspozytora z oceny poniżej czekają na decyzję (M4).
  - **Przyjęte do M4b-3 (ankieta 2026-11-05):** wózek jako sprzęt tragarza magazynu (kupowany za deski), wóz konny ze stajnią i woźnicą (koń bez hodowli), wozy do dużych zleceń tragarzy, załadunek ok. 1 s na sztukę. Szczegóły w ROADMAP (M4b-3).
  - Ocena (Claude):
    - Dobre stopniowanie, widać postęp i pasuje do klimatu. Wózek ręczny to fajny etap pośredni, którego w GDD brakuje.
    - Sama ładowność wozu (6 przy tragarzu 1) to niewielki zysk wobec kosztu (drogi, koń, stajnia). Wóz zarabia na długich trasach, więc warto mu dać szybkość na drodze (np. 1,5× tragarza), a wózkowi ręcznemu odrobinę mniejszą niż pieszemu (np. 0,9×).
    - Załadunek i rozładunek powinny trwać widocznie (np. 1 s na sztukę), bo to immersja, a przy okazji uczciwy koszt.
    - Dyspozytor musi wiedzieć, kogo wysłać: wóz do zleceń od ~4 sztuk na dalsze trasy, tragarz do małych i krótkich. Inaczej wozy jeżdżą z jedną kłodą.
    - Technicznie to niedrogie: `TransportRequest` już dzieli zlecenie na ładunki, więc dochodzi pojemność i prędkość nośnika oraz ograniczenie wozów do dróg. Naturalny etap to M4 (drogi i wozy są tam w zakresie).

- [Claude] **Leśnik i odrastanie lasu:** pniak po czasie zamienia się w sadzonkę, a ta w drzewo (fazy `growing_1..3` z ART_SPEC §8). Leśnik sadzi drzewa w promieniu chaty. W M2 drzewa nie odrastają (3 kłody, potem pniak).
  - Ocena: koszt mały (`ResourceField` ma już stan węzła, potrzebny jest licznik wzrostu w systemie „czas i wzrost” z §4.2). Bez tego las w długiej grze się kończy, więc warto to mieć najpóźniej w M4.

- [gracz] **Skąd biorą się nowi mieszkańcy:** docelowo przybywają do miasta razem z okresami handlowymi (np. z kupcami) oraz przez symulowany przyrost naturalny. W M3 po prostu przychodzą pieszo z krawędzi mapy, gdy w domu jest wolne miejsce (decyzja 2026-11-05).
  - Ocena (Claude): pasuje do klimatu i daje graczowi rytm („przyjechała karawana, przybyło 6 osób”). Przyrost naturalny łatwo policzyć na domach (np. szansa na dziecko zależna od zadowolenia), a dzieci dorastają w siłę roboczą po czasie. Naturalny etap: M4 (kupiec wędrowny) i M6 (ruch między prowincjami).

- [Claude] **Opał przed budową:** automatyczny gracz pokazał, że przy jednym drwalu place budowy wyciągają z magazynu całe drewno, a domy marzną i podupadają. Pomysł: domownicy mają pierwszeństwo przy ostatnich sztukach drewna (np. budowy nie biorą ostatnich 5 kłód), albo gracz ustawia rezerwę w panelu magazynu.
  - **Przyjęte do M4a (2026-11-05):** rezerwa 5 sztuk drewna i suwak w panelu magazynu (ROADMAP, M4).
- [Claude] **Tragarze także w magazynach:** dziś tragarze pracują tylko w ratuszu (2 osoby). Przy kilku placach budowy naraz to wąskie gardło. GDD §4.1 mówi o „tragarzach magazynów”, więc każdy magazyn mógłby mieć 1–2 miejsca dla tragarzy.
  - **Przyjęte do M4a (2026-11-05):** 2 tragarzy na magazyn (ROADMAP, M4).
- [gracz] **Kutry rybackie na morzu:** w M4a ryby łowi wędkarz przy rzece. Później chcę też kutry na morzu, wydajniejsze od wędkarza (2026-11-05).
  - Ocena (Claude): dobra ścieżka rozwoju: tani wędkarz na start, droższy kuter z portem i stocznią dla większego miasta. Naturalny etap: M5 (woda, porty i statki). Zmieni GDD §5.4 (dziś jest tam „łódź rybacka” przypisana do rybaka).
  - **Przyjęte do M5 (ankieta 2026-11-06):** przystań rybacka nad morzem z łodzią ze stoczni; wędkarz zostaje.

- [Claude] **Leśniczy (sadzenie drzew):** automatyczny gracz w M4a pokazał, że lasy przy mieście znikają po ok. 45 minutach, a drwale stoją („brak drzew”). Leśniczy sadzi sadzonki w zasięgu, które po kilku minutach rosną w drzewa.
  - Ocena: koszt średni (nowy krok „sadź”, wzrost węzła jak pole). Bardzo pasuje do immersji i daje graczowi decyzję o lesie.
  - **Przyjęte do M4b (2026-11-05).**
- [Claude] **Wstrzymanie produkcji:** dziś budynek pracuje zawsze. Tartak i kamieniołom zapełniają magazyny deskami i kamieniem, aż zabraknie miejsca na inne towary. Przycisk „wstrzymaj” w panelu budynku (pracownik zostaje, ale nie zaczyna cyklu) albo limit („pracuj, gdy w magazynie mniej niż N”).
  - Ocena: koszt mały. Ważne przy większym mieście.
  - **Przyjęte do M4b (2026-11-05).**
- [Claude] **Straganiarze na targowisku:** w M4a targowisko jest tylko usługą z zasięgiem. Docelowo (GDD §3.2) straganiarze przynoszą towary z magazynu na kramy, a domownicy kupują na targu zamiast chodzić do magazynu.
  - Ocena: koszt średni. Dużo życia na ulicach.
  - **Przyjęte do M4b (2026-11-05).** Zrobione w M4b-2: 2 straganiarzy, kramy z jedzeniem, napitkami, ubraniami i opałem.
- [Claude] **Na co wydawać złoto:** w M4a złota szybko przybywa (po godzinie ok. 1000), a wydaje się je tylko na 4 budynki. Kupiec wędrowny (M4b) i utrzymanie budynków dadzą mu sens.
  - Ocena: do strojenia razem z kupcem w M4b.
  - M4b-2: kupiec kupuje nadwyżki (złoto przybywa) i sprzedaje świnie po 30 złota (złoto ubywa). Utrzymanie budynków nadal czeka.
- [Właściciel] **Pola przy pasiece i owczarni** (2026-11-05): tak jak farma, pasieka i owczarnia stawiają kafelki 1×1 w swoim zasięgu. Pasieka stawia ule, a owczarnia kawałki zagrody z owcami. Sąsiednie kafelki owczarni łączą się w jedną zagrodę z płotem tylko na obwodzie.
  - Otwarte: czy owce pojawiają się same, czy trzeba je kupić od kupca wędrownego (M4b-2).
  - [Właściciel] **Świnie w zagrodach** (2026-11-05): świnie żyją w zagrodach jak owce. Na start kupujemy od kupca co najmniej 2 świnie, potem się rozmnażają; więcej świń = szybsze rozmnażanie, można dokupić. Suwak „ile świń zostawiamy do rozmnażania”. Rzeźnik albo kupiec zabiera dorosłą świnię.
    - **Przyjęte częściowo do M4b-2 (ankieta 2026-11-05):** wersja prosta (chlew jako żywy magazyn świń, rozmnażanie do pojemności chlewu, kupno od kupca, ostatnie 2 świnie zostają, rzeźnik prowadzi świnię). Zagrody kafelkami z płotem, zwierzęta chodzące po zagrodzie i suwak stada: osobny etap razem z owcami.
    - Ocena (Claude): suwak stada to zabezpieczenie przed wybiciem stada, a rozmnażanie musi mieć górną granicę (pojemność zagrody). Zagrody wspólne dla świń i owiec: robimy raz, używamy dwa razy.
  - Ocena (Claude): dobrze pasuje do „widocznej pracy”. Pasterz chodzi między owcami w zagrodzie, a pszczelarz od ula do ula. Kafelki to te same pola co przy farmie, więc reszta logiki jest gotowa. Nowe są grafiki ula i zagrody (płot łączony jak mury) oraz owce jako małe postacie, które chodzą po zagrodzie. Koszt średni. Propozycja do decyzji: owce rozmnażają się same w zagrodzie, a pierwsze 2 owce przynosi kupiec. Wtedy kupiec ma sens, a gracz nie musi ich ciągle dokupywać. Kiedy: razem z M4b-2 (kupiec) albo zaraz po M4b-1.5.

- [Claude] **Obracanie budynków (np. klawisz R):** gracz sam wybiera, z której strony budynek ma wejście. Pomysł powstał po błędzie z chatą rybaka, która stała drzwiami do rzeki (2026-11-05). Właściciel projektu chce go zapisać.
  - Ocena (Claude): wygodne, ale kosztowne. Każdy budynek potrzebuje grafik z 2 albo 4 stron, a do tego trzeba obrócić obrys i wejście w danych, w zapisie gry i w cięciu do sortowania (`BuildingSlicer`). Na razie wystarcza komunikat „Wejście wychodzi na wodę” i przesunięcie budynku. Tańszy wariant: tylko 2 orientacje (odbicie lustrzane), bo grafikę da się wtedy odwrócić bez rysowania nowej. Kiedy: najwcześniej przy grafikach docelowych budynków.
  - **Przyjęte do M4b-1.5 (2026-11-05):** domy 4 orientacje, reszta 2 lustrzane, automatyczny wybór strony do drogi i klawisz R. Szczegóły w ROADMAP (M4b-1.5).

- [gracz] **Ratusz jako budynek na później, obóz pionierów na start (2026-11-06):** ratusz przesuwa się na późniejszą część gry i dostaje nowe funkcje, a jego dzisiejsze zadanie (budowniczy i tragarze) przejmuje obóz pionierów albo dom pionierów.
  - **Przyjęte częściowo do M5, część 3 (ankieta 2026-11-06):** obóz pionierów (budowniczy + 2 tragarzy, 10 drewna, najwyżej jeden na prowincję, w menu na każdej mapie) jest pierwszym budynkiem po starcie ze statku na „Wybrzeżu”. Ratusz na razie działa jak dawniej; jego przesunięcie i nowe funkcje czekają na wspólne ustalenie.
  - **Przyjęte do M6 (ankieta 2026-11-06):** ratusz = siedziba prowincji (podatki mieszczan i patrycjuszy tylko przy ratuszu, wymóg wysłania wyprawy osadników, jeden na prowincję). Szczegóły w ROADMAP (M6).
  - Propozycje funkcji ratusza (Claude, do wyboru): podatki tylko z ratuszem (obóz daje niższą stawkę albo tylko ryczałt), awans domów do patrycjuszy wymaga ratusza w zasięgu, ratusz odblokowuje okno „Zapasy królestwa” i progi kupców, a później (M6) jest siedzibą zarządcy prowincji i wymogiem do kolonizacji następnej. Ocena: najprostsza i czytelna dla gracza jest para „ratusz = podatki od mieszczan i patrycjuszy + siedziba prowincji w M6”.
- [gracz] **Dom budowniczych (2026-11-06):** budynek, który zwiększa liczbę budowniczych (np. +2), żeby duże miasto nie czekało na jednego budowniczego z obozu.
  - Ocena (Claude): mały koszt (nowy budynek z pracownikami `builder`, cała logika budowy już działa dla wielu budowniczych). Pasuje razem z przesunięciem ratusza. Warto rozważyć limit (np. jeden na 20 domów), żeby nie zastępował planowania.
- [Claude] **Rejsy w kółko (M5, część 3):** przełącznik „powtarzaj rejs” w panelu portu: koga po rozładunku od razu ładuje ten sam plan i znów wypływa. Ocena: koszt mały, wygoda duża, gdy gracz ma stałą nadwyżkę (np. desek do sprzedania). Do decyzji po ocenie części 3.
  - **Przyjęte do M6 (ankieta 2026-11-06) jako część szlaków handlowych:** szlak to rejs (albo kurs wozu) powtarzany w kółko według progu.
- [gracz] **Sterowanie kogą w prowincji (2026-11-06):** zaznacz kogę, kliknij prawym na wodę, a koga tam płynie i rzuca kotwicę (np. żeby przestawić ją w inne miejsce). Ocena (Claude): koszt średnio-mały (siatka ruchu po wodzie i kotwiczenie już są). Decyzja właściciela: później, po części 3 M6.
- [gracz] **Natychmiastowa budowa jak w Anno (2026-11-06):** pomysł, żeby oszczędzić grafik budowy na PixelLabie. Ocena (Claude): odradzam, bo widoczna budowa z tragarzami to filar immersji; grafiki budowy i tak rysuje kod dla każdego budynku i rozmiaru, więc PixelLab potrzebny jest tylko do gotowych budynków. Budowa zostaje, grafikę budowy można później upiększyć (stosy desek, więcej rusztowań).
  - **Wersja z przełącznikiem (gracz, ankieta 2026-11-06): decyzja „natychmiastowa budowa” jako opcja gry, zrobić dużo później, przed 1.0** (razem z innymi ustawieniami gry). W opcjach gry jest przełącznik „tryb immersyjny” (jak dziś) albo „tryb uproszczony”. W trybie uproszczonym budynek stoi od razu po kliknięciu, a materiały znikają z magazynów w tej samej chwili (gdy ich brak, budynku nie da się postawić). Tryb immersyjny zostaje domyślny.
  - Ocena (Claude): koszt mały do średniego (jedna ścieżka w stawianiu budynku i dróg). Ryzyka: dwie wersje gry do testowania przy każdym nowym budynku, balans (automatyczny gracz i czasy z ROADMAP liczone są dla budowy z tragarzami), ustawienie musi trafić do zapisu gry. Rekomendowana wcześniej łagodniejsza wersja „szybka budowa” (widoczna budowa, ale np. 5× szybciej) zostaje jako możliwy wariant do rozważenia przy realizacji.

## Klimat i immersja

- [Claude] **Efekty przy pracy:** dym z komina piekarni tylko wtedy, gdy piekarz piecze, śmigło młyna kręci się tylko przy mieleniu, a z pola przy żniwach lecą źdźbła. Widok ma już czynność postaci, więc efekt można włączać po `activity`. Koszt mały, a dużo daje dla „żywego” miasta.

- [Właściciel] **Obracanie kamery** (2026-11-05): żeby zobaczyć, co jest za budynkami. Najpierw wersja bez obróconych grafik, tylko żeby działało. Ocena (Claude): w izometrii 2D każdy budynek i postać potrzebuje wtedy grafik z 4 stron, czyli ok. 4× więcej rysowania. Tańsza alternatywa: przezroczyste budynki przy kursorze albo przycisk „ukryj budynki”. Kiedy: po M4b-1.5, gdy ustalimy nowy wygląd miasta.

- [Claude] **Życie przy bramie:** strażnik obsługuje kołowrót przy podnoszeniu brony, a wozy zatrzymują się czasem do kontroli. Właściciel projektu jest na tak (2026-11-04). Kiedy: razem z wieżą bramną w M7.

## Animacje i detale

- [właściciel, 2026-11-08] **Nowe jednostki i okręty:** halabardnik w zbroi płytowej, kusznik, ciężki zbrojny z morgensternem, lekka jazda, ruchoma balista; 3 nowe okręty (każdy w wersji cywilnej i wojennej, każdy większy od poprzedniego) i duża stocznia; bardziej naturalne „Wybrzeże” z szerszą i krótszą zatoką.
  - Ocena (Claude): jednostki i okręty najlepiej po ocenie M7 (zasady walki), ale przed M8 (AI od razu z pełnym wojskiem); wybrzeże jest małe i niezależne. **Decyzja właściciela (ankieta 2026-11-08): oba teraz** — najpierw W1 (wybrzeże), potem J1 (jednostki i okręty), przed oceną M7 (ROADMAP, W1 i J1).

## Bitwa morska na żywo (właściciel, 2026-11-09)

- Pomysł właściciela: po przechwyceniu wrogiej floty bitwa rozgrywa się na mapie pustego oceanu: okręty manewrują, strzelają i idą do abordażu.
- Ocena (Claude): nowy system walki statków (dziś statki w widoku prowincji nie walczą). Ankieta 2026-11-09: w M8 bitwa morska automatyczna z animacją i raportem, bitwa na żywo jako osobny etap po M8.


## Barwy wojsk władców (Claude, 2026-11-09)

- Pomysł (Claude, przy M8 część 2): żołnierze władców i straż osad wyglądają dziś tak samo jak żołnierze gracza (te same postacie), więc na mapie pola trudno odróżnić swoich od wrogów. Tarcze, proporce albo pasy na ubraniu w kolorze właściciela (gracz czerwony, władcy niebieski, zielony, fioletowy). Ocena: grafika postaci w kilku kolorach (podmiana palety przy wczytaniu, bez nowych rysunków), mało pracy w kodzie. Kiedy: razem z częścią 4 (wojna władców) albo wcześniej, jeśli przeszkadza przy ocenie.
