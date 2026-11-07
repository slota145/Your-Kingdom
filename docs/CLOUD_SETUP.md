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

Sesja w chmurze pracuje na **osobnej gałęzi** i może otworzyć pull request. Żeby zobaczyć jej pracę na laptopie, scal PR na GitHubie albo przenieś sesję poleceniem `claude --teleport` (wymaga czystego stanu gita lokalnie).
