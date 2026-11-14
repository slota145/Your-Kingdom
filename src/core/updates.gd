extends Node
## Autoload "Updates" (M10, owner's idea 2026-11-14, IDEAS "Przycisk Aktualizuj grę", variant
## for the owner): when the game runs from its git folder on Windows (not an exported .exe),
## it asks GitHub in the background whether `main` has something new, and the main menu
## offers to update: the game closes, aktualizuj.ps1 runs in its own window (git pull, art
## import) and starts the game again.

signal checked(behind: int)

const SCRIPT := "aktualizuj.ps1"

## Commits on GitHub's main that this folder does not have yet; -1 = not known (not checked,
## no git, no network, or not the owner's folder).
var behind: int = -1

var _thread: Thread


func _ready() -> void:
	if not available():
		return
	_thread = Thread.new()
	_thread.start(_check)


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
