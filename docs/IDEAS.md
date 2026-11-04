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

## Klimat i immersja

## Animacje i detale
