extends Node
## Autoload "Updates" (M10, owner's idea 2026-11-14, IDEAS "Przycisk Aktualizuj grę"). Two
## ways, both offered by a button in the main menu:
## - the owner's game folder on Windows (run from the repository): asks GitHub in the
##   background whether `main` has something new; the update closes the game, runs
##   aktualizuj.ps1 in its own window (git pull, art import) and starts the game again;
## - the exported game (.exe for players, owner's choice 2026-11-14): asks the public
##   repository of releases for the newest one; the update downloads the new .exe next to the
##   running one with a progress bar, checks its SHA-256 against the release's .sha256 file,
##   puts it in the running one's place (a running .exe can be renamed on Windows), starts it
##   and quits. The old file is deleted at the next start. Saves live elsewhere and stay.

signal checked(behind: int)
## The public repository has a newer version than this game.
signal release_found(version: String)
## Downloading the new version: 0..1.
signal download_progressed(fraction: float)
## The download or the swap did not work ([member release_page] is the way out).
signal download_failed(reason: String)

const SCRIPT := "aktualizuj.ps1"
## The public repository of releases (built by .github/workflows/release.yml).
const RELEASES_REPO := "slota145/YourKingdom-Releases"
const LATEST_URL := "https://api.github.com/repos/%s/releases/latest" % RELEASES_REPO
const EXE_ASSET := "YourKingdom.exe"
const SHA_ASSET := "YourKingdom.exe.sha256"
const HEADERS: PackedStringArray = ["User-Agent: YourKingdom-Updater", "Accept: application/vnd.github+json"]

## The newer version found in the public repository ("" = none, or not checked).
var release_version: String = ""
## Its page (the way out when the download fails: the player downloads by hand).
var release_page: String = "https://github.com/%s/releases/latest" % RELEASES_REPO
var downloading: bool = false

var _release: Dictionary = {}
var _http: HTTPRequest

## Commits on GitHub's main that this folder does not have yet; -1 = not known (not checked,
## no git, no network, or not the owner's folder).
var behind: int = -1

var _thread: Thread


func _ready() -> void:
	if releases_available():
		_remove_old_exe()
		_ask_latest_release.call_deferred()
		return
	if not available():
		return
	_thread = Thread.new()
	_thread.start(_check)


## Whether this is the exported game for players on Windows (updates from the public
## repository of releases).
static func releases_available() -> bool:
	return OS.get_name() == "Windows" and OS.has_feature("template")


## Whether version [param remote] ("v0.9.1" or "0.9.1") is newer than [param local].
static func is_newer(remote: String, local: String) -> bool:
	var a := remote.trim_prefix("v").split(".")
	var b := local.trim_prefix("v").split(".")
	for i: int in maxi(a.size(), b.size()):
		var x := int(a[i]) if i < a.size() else 0
		var y := int(b[i]) if i < b.size() else 0
		if x != y:
			return x > y
	return false


## What matters in GitHub's answer about the latest release: {"version", "exe", "sha", "page"},
## or {} when it is not a usable release (no .exe or no checksum).
static func parse_release(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var release: Dictionary = data
	var result := {"version": String(release.get("tag_name", "")).trim_prefix("v"),
			"page": String(release.get("html_url", "")), "exe": "", "sha": ""}
	for asset: Variant in release.get("assets", []):
		if not asset is Dictionary:
			continue
		var name := String((asset as Dictionary).get("name", ""))
		var url := String((asset as Dictionary).get("browser_download_url", ""))
		if name == EXE_ASSET:
			result["exe"] = url
		elif name == SHA_ASSET:
			result["sha"] = url
	if result["version"] == "" or result["exe"] == "" or result["sha"] == "":
		return {}
	return result


## Where the new .exe is downloaded and where the running one goes, for [param exe].
static func swap_paths(exe: String) -> Dictionary:
	return {"new": exe + ".new", "old": exe.get_basename() + ".old.exe"}


## The checksum in a .sha256 file ("<64 hex digits>" or "<hex>  YourKingdom.exe").
static func parse_checksum(text: String) -> String:
	var first := text.strip_edges().get_slice(" ", 0).to_lower()
	return first if first.length() == 64 and first.is_valid_hex_number() else ""


## Starts downloading the new version (after [signal release_found]).
func download_release() -> void:
	if _release.is_empty() or downloading:
		return
	downloading = true
	var paths := swap_paths(OS.get_executable_path())
	DirAccess.remove_absolute(paths["new"])
	_http.download_file = paths["new"]
	_http.request_completed.connect(_on_exe_downloaded, CONNECT_ONE_SHOT)
	if _http.request(_release["exe"], HEADERS) != OK:
		_fail("request")


func _ask_latest_release() -> void:
	_http = HTTPRequest.new()
	_http.max_redirects = 8
	add_child(_http)
	_http.request_completed.connect(_on_latest_release, CONNECT_ONE_SHOT)
	if _http.request(LATEST_URL, HEADERS) != OK:
		print("updates: cannot ask for the latest release")


func _on_latest_release(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		print("updates: no answer about releases (%d, %d)" % [result, code])
		return
	_release = parse_release(JSON.parse_string(body.get_string_from_utf8()))
	if _release.is_empty():
		return
	release_page = _release["page"] if _release["page"] != "" else release_page
	var local := str(ProjectSettings.get_setting("application/config/version", "0"))
	print("updates: latest release %s, this game %s" % [_release["version"], local])
	if is_newer(_release["version"], local):
		release_version = _release["version"]
		release_found.emit(release_version)


func _process(_delta: float) -> void:
	if downloading and _http != null and _http.get_body_size() > 0:
		download_progressed.emit(clampf(float(_http.get_downloaded_bytes()) / _http.get_body_size(), 0.0, 1.0))


func _on_exe_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("download %d %d" % [result, code])
		return
	_http.download_file = ""
	_http.request_completed.connect(_on_checksum, CONNECT_ONE_SHOT)
	if _http.request(_release["sha"], HEADERS) != OK:
		_fail("checksum request")


func _on_checksum(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var paths := swap_paths(OS.get_executable_path())
	var expected := parse_checksum(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else ""
	if expected == "" or FileAccess.get_sha256(paths["new"]) != expected:
		DirAccess.remove_absolute(paths["new"])
		_fail("checksum")
		return
	var exe := OS.get_executable_path()
	DirAccess.remove_absolute(paths["old"])
	if DirAccess.rename_absolute(exe, paths["old"]) != OK:
		_fail("rename running")
		return
	if DirAccess.rename_absolute(paths["new"], exe) != OK:
		DirAccess.rename_absolute(paths["old"], exe)
		_fail("rename new")
		return
	print("updates: version %s in place, starting it" % _release["version"])
	OS.create_process(exe, [])
	get_tree().quit()


func _fail(reason: String) -> void:
	downloading = false
	push_warning("updates: %s" % reason)
	download_failed.emit(reason)


## The previous .exe, renamed at the last update (it could not be deleted while running).
func _remove_old_exe() -> void:
	var old: String = swap_paths(OS.get_executable_path())["old"]
	if FileAccess.file_exists(old):
		DirAccess.remove_absolute(old)


## Whether this game can update itself: on Windows, run from the folder with the repository
## and aktualizuj.ps1 (not an exported game).
static func available() -> bool:
	return OS.get_name() == "Windows" and not OS.has_feature("template") \
			and FileAccess.file_exists(folder().path_join(SCRIPT)) \
			and DirAccess.dir_exists_absolute(folder().path_join(".git"))


## The game's folder on disk.
static func folder() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


## The command that updates and restarts the game: aktualizuj.ps1 with -Restart and the Godot
## that runs now (so the same one starts again).
static func update_command(game_folder: String, godot: String) -> PackedStringArray:
	return PackedStringArray(["-ExecutionPolicy", "Bypass", "-File", game_folder.path_join(SCRIPT),
			"-Restart", "-Godot", godot])


## Closes the game and updates it in a window of its own; the script starts it again.
func update_now() -> void:
	OS.create_process("powershell.exe", update_command(folder(), OS.get_executable_path()), true)
	get_tree().quit()


## Number of commits in [param git_output] of `git rev-list --count`, -1 when it is not one.
static func parse_count(git_output: String) -> int:
	var text := git_output.strip_edges()
	return int(text) if text.is_valid_int() else -1


func _check() -> void:
	var out: Array = []
	if OS.execute("git", ["-C", folder(), "fetch", "--quiet", "origin", "main"], out, true) != 0:
		_done.call_deferred(-1)
		return
	out.clear()
	if OS.execute("git", ["-C", folder(), "rev-list", "--count", "HEAD..origin/main"], out, true) != 0:
		_done.call_deferred(-1)
		return
	_done.call_deferred(parse_count(str(out[0]) if not out.is_empty() else ""))


func _done(count: int) -> void:
	behind = count
	print("updates: %s" % ("%d new on GitHub" % count if count >= 0 else "not known"))
	checked.emit(count)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
