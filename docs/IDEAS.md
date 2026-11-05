# Poczekalnia pomysłów

Tu trafiają pomysły, które **nie są jeszcze ustalone**. Do [ROADMAP.md](ROADMAP.md) przenosimy je wyłącznie za zgodą właściciela projektu, wskazując etap.

Format: `- [źródło: gracz/Claude] krótki opis — (opcjonalnie) ocena: koszt, ryzyko, dopasowanie`

## Mechaniki

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

- [gracz] **Fikcyjne okręty w stylu Anno i drzewko rozwoju okrętów:** zamiast samej kogi mamy okręty fikcyjne, inspirowane prawdziwymi okresami: od kogi przez karawelę i karakę aż po duży okręt podobny do galeonu. Zamiast armat ma balisty i skorpiony. Na koniec drzewka mógłby się pojawić galeon z armatami (2026-11-05). Bez decyzji.
  - Ocena (Claude):
    - Fikcyjne okręty pasują: świat jest fikcyjny, a karawele i karaki to XV wiek, czyli jeszcze średniowiecze. Do tego właśnie takimi statkami kolonizowano nowe lądy, więc dobrze łączą się ze scenariuszem kolonizacji.
    - Drzewko rozwoju daje graczowi cel na długą grę. Propozycja: łódź rybacka → koga (tania, na start) → karawela (szybka, do zwiadu i zasiedlania) → karaka (duża, handel i wojsko) → wielki okręt z balistami i skorpionami.
    - **Uwaga na armaty:** jeśli są na okręcie, gracz zapyta, czemu nie ma ich w zamku. Proch zmienia też sens murów i oblężeń, czyli serca gry. Bezpieczniej zakończyć drzewko wielkim okrętem z ciężkimi balistami, a armaty potraktować jako osobną, późną decyzję dla całej gry (ląd i morze razem).
    - Koszt: średni (każdy okręt to grafika z animacją kołysania, budowa w stoczni etapami i dane jednostki). Kiedy: M5.
    - Zmieni GDD §5.4 (rodzaje statków), gdy właściciel projektu zdecyduje.
  - Prototyp (2026-11-05, `src/prototype/ships/`): koga narysowana kodem w 8 kierunkach (bryły 3D „fotografowane” w rzucie izometrycznym), z kasztelem z blankami, tarczami i pasiastym żaglem w kolorze frakcji (magenta). Wszystkie kierunki są spójne, a kolejne okręty drzewka da się zrobić, zmieniając wymiary i części w skrypcie.

- [gracz] **Stopnie transportu:** tragarz niesie 1 sztukę, mały wózek ręczny 3, duży wóz konny 5–6.
  - **Zatwierdzone 2026-11-05 (ładowności):** zapisane w GDD §5.2. Szybkości, czas załadunku i reguły dyspozytora z oceny poniżej czekają na decyzję (M4).
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

- [Claude] **Leśniczy (sadzenie drzew):** automatyczny gracz w M4a pokazał, że lasy przy mieście znikają po ok. 45 minutach, a drwale stoją („brak drzew”). Leśniczy sadzi sadzonki w zasięgu, które po kilku minutach rosną w drzewa.
  - Ocena: koszt średni (nowy krok „sadź”, wzrost węzła jak pole). Bardzo pasuje do immersji i daje graczowi decyzję o lesie.
  - **Przyjęte do M4b (2026-11-05).**
- [Claude] **Wstrzymanie produkcji:** dziś budynek pracuje zawsze. Tartak i kamieniołom zapełniają magazyny deskami i kamieniem, aż zabraknie miejsca na inne towary. Przycisk „wstrzymaj” w panelu budynku (pracownik zostaje, ale nie zaczyna cyklu) albo limit („pracuj, gdy w magazynie mniej niż N”).
  - Ocena: koszt mały. Ważne przy większym mieście.
  - **Przyjęte do M4b (2026-11-05).**
- [Claude] **Straganiarze na targowisku:** w M4a targowisko jest tylko usługą z zasięgiem. Docelowo (GDD §3.2) straganiarze przynoszą towary z magazynu na kramy, a domownicy kupują na targu zamiast chodzić do magazynu.
  - Ocena: koszt średni. Dużo życia na ulicach.
  - **Przyjęte do M4b (2026-11-05).**
- [Claude] **Na co wydawać złoto:** w M4a złota szybko przybywa (po godzinie ok. 1000), a wydaje się je tylko na 4 budynki. Kupiec wędrowny (M4b) i utrzymanie budynków dadzą mu sens.
  - Ocena: do strojenia razem z kupcem w M4b.

- [Claude] **Obracanie budynków (np. klawisz R):** gracz sam wybiera, z której strony budynek ma wejście. Pomysł powstał po błędzie z chatą rybaka, która stała drzwiami do rzeki (2026-11-05). Właściciel projektu chce go zapisać.
  - Ocena (Claude): wygodne, ale kosztowne. Każdy budynek potrzebuje grafik z 2 albo 4 stron, a do tego trzeba obrócić obrys i wejście w danych, w zapisie gry i w cięciu do sortowania (`BuildingSlicer`). Na razie wystarcza komunikat „Wejście wychodzi na wodę” i przesunięcie budynku. Tańszy wariant: tylko 2 orientacje (odbicie lustrzane), bo grafikę da się wtedy odwrócić bez rysowania nowej. Kiedy: najwcześniej przy grafikach docelowych budynków.

## Klimat i immersja

- [Claude] **Efekty przy pracy:** dym z komina piekarni tylko wtedy, gdy piekarz piecze, śmigło młyna kręci się tylko przy mieleniu, a z pola przy żniwach lecą źdźbła. Widok ma już czynność postaci, więc efekt można włączać po `activity`. Koszt mały, a dużo daje dla „żywego” miasta.

- [Właściciel] **Obracanie kamery** (2026-11-05): żeby zobaczyć, co jest za budynkami. Najpierw wersja bez obróconych grafik, tylko żeby działało. Ocena (Claude): w izometrii 2D każdy budynek i postać potrzebuje wtedy grafik z 4 stron, czyli ok. 4× więcej rysowania. Tańsza alternatywa: przezroczyste budynki przy kursorze albo przycisk „ukryj budynki”. Kiedy: po M4b-1.5, gdy ustalimy nowy wygląd miasta.

- [Claude] **Życie przy bramie:** strażnik obsługuje kołowrót przy podnoszeniu brony, a wozy zatrzymują się czasem do kontroli. Właściciel projektu jest na tak (2026-11-04). Kiedy: razem z wieżą bramną w M7.

## Animacje i detale
