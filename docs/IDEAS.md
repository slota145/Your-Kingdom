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

## Klimat i immersja

- [Claude] **Życie przy bramie:** strażnik obsługuje kołowrót przy podnoszeniu brony, a wozy zatrzymują się czasem do kontroli. Właściciel projektu jest na tak (2026-11-04). Kiedy: razem z wieżą bramną w M7.

## Animacje i detale
