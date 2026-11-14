# Praca w chmurze (Claude Code na claude.ai/code)

Repozytorium jest przygotowane do pracy w chmurze:
- hook `SessionStart` w `.claude/settings.json` uruchamia `tools/cloud_session_start.sh`,
- skrypt instaluje Godota 4.7.2 dla Linuksa (jeśli go brakuje), ustawia zmienną `GODOT` i robi pierwszy import projektu,
- na komputerze lokalnym hook nic nie robi,
- `tools/run_tests.sh` sam znajdzie albo pobierze Godota.

## Jednorazowa konfiguracja środowiska

1. Wejdź na **claude.ai/code** i połącz konto z GitHubem, jeśli jeszcze nie jest połączone. Repozytorium `slota145/Your-Kingdom` jest publiczne, ale do **wysyłania** zmian Claude potrzebuje dostępu. Zainstaluj aplikację Claude na GitHubie (https://github.com/apps/claude/installations/new) i wybierz to repozytorium.
2. Na ekranie nowej sesji kliknij **wybór środowiska** (pierwszy przycisk pod polem wiadomości) i wybierz **New environment**.
3. Wypełnij pola:
   - **Name:** `Your Kingdom (Godot)`
   - **Network access:** `Trusted` (domyślne). Obejmuje github.com i serwery wydań GitHuba, z których pobieramy Godota.
   - **Environment variables:** dłuższe limity czasu dla poleceń (import i testy Godota potrafią trwać kilka minut):
     ```
     BASH_DEFAULT_TIMEOUT_MS=300000
     BASH_MAX_TIMEOUT_MS=600000
     ```
   - **Setup script:** wklej skrypt poniżej. Instaluje Godota do `/opt/godot`. Środowisko zapamiętuje wynik, więc kolejne sesje nie pobierają go od nowa.
     ```bash
     #!/bin/bash
     GODOT_DIR=/opt/godot
     BIN="$GODOT_DIR/Godot_v4.7.2-stable_linux.x86_64"
     if [ ! -x "$BIN" ]; then
       mkdir -p "$GODOT_DIR" && cd "$GODOT_DIR" || exit 0
       curl -fsSL -o godot.zip "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip" \
         && python3 -m zipfile -e godot.zip . && rm -f godot.zip && chmod 755 "$BIN" \
         || echo "Godot download failed" >&2
     fi
     exit 0
     ```
4. Kliknij **Add environment**.
5. Rozpocznij sesję z repozytorium `slota145/Your-Kingdom` i tym środowiskiem. Na start poproś na przykład: „Uruchom `tools/run_tests.sh` i powiedz, czy wszystko przechodzi”.

Setup script jest opcjonalny. Bez niego hook i tak pobierze Godota (78 MB) na początku każdej sesji, tylko wolniej.

## Co działa w chmurze, a co nie

| Działa | Nie działa (robimy lokalnie, na laptopie) |
|---|---|
| testy (`tools/run_tests.sh`, długie: `--long`) | benchmark wydajności (brak karty graficznej, wyniki byłyby nieporównywalne) |
| generator placeholderów | ocena „na oko” w oknie gry, granie |
| import i walidacja projektu | edytor Godota |
| zrzuty ekranu z `--write-movie` (*do sprawdzenia: wymaga renderowania bez ekranu*) | |
| commity i wysyłanie gałęzi na GitHuba | |
| eksport gry i próba wyeksportowanej wersji (M10 część 2): `python3 tools/get_export_templates.py` (raz, pobiera z 1,3 GB tylko szablony Linux i Windows), potem `tools/export_game.sh [linux\|windows]` | uruchomienie `.exe` (plik ma ok. 190 MB, za duży do repozytorium; na laptopie buduje go `eksportuj.ps1`) |

Sesja w chmurze pracuje na **osobnej gałęzi** i może otworzyć pull request. Żeby zobaczyć jej pracę na laptopie, scal PR na GitHubie albo przenieś sesję poleceniem `claude --teleport` (wymaga czystego stanu gita lokalnie).

## Wydania dla graczy (M10, decyzja właściciela 2026-11-14)

Gra dla kolegów to `.exe` z publicznego repozytorium **`slota145/YourKingdom-Releases`** (kod, grafiki i historia zostają prywatne). Gra w `.exe` przy starcie pyta to repozytorium o najnowsze wydanie i sama się aktualizuje (autoload `Updates`, ARCHITECTURE §14).

**Jednorazowo (właściciel):** publiczne repozytorium `YourKingdom-Releases` z README; token *fine-grained* tylko do niego z uprawnieniem *Contents: Read and write*; w `Your-Kingdom` sekret Actions `RELEASES_TOKEN` z tym tokenem.

**Nowa wersja (może ją zrobić sesja Claude):**
1. Podbij `config/version` w `project.godot` (np. `0.9.0` → `0.9.1`) w zmianie, która trafia do `main` (wersja jest numerem wydania, `v0.9.1`; to samo wydanie drugi raz się nie utworzy).
2. Uruchom workflow **Release** na `main` (GitHub: Actions → Release → Run workflow, z polem „Co nowego”; z sesji: narzędzie GitHuba do uruchamiania workflowów). Buduje on grę na Linuksie GitHuba, robi próbę `--smoke`, buduje `.exe`, liczy SHA-256 i publikuje wydanie z plikami `YourKingdom.exe` i `YourKingdom.exe.sha256`.
3. Gry kolegów przy następnym starcie pokażą „Nowa wersja 0.9.1: pobierz i uruchom”.
