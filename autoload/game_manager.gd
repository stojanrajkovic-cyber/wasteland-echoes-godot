extends Node
## GameManager (Autoload / Singleton)
##
## Ported from the iOS Swift version's GameManager.swift + GameModels.swift.
## This is the data-driven story engine: it loads prompts.json, tracks
## stats/flags/time, and resolves choices into the next prompt.
##
## Fixes applied during the port (see MIGRATION_NOTES.md for full detail):
##  1. requiredIntFlags on "hp"/"sta"/"mor"/"elapsedTime" now read the REAL
##     player stats instead of a flags-dictionary entry that was never set
##     (this silently broke every HP-gated choice on iOS).
##  2. The two choices that were special-cased by matching literal button
##     text ("Offer the battery in trade.", "Offer a rare item.") are now
##     driven by a generic "branchOnFlag" field in the JSON. Rename the
##     button text now and the branch still works.
##  3. The Day-3 HQ timeout is a generic "timeoutRedirect" on the prompt
##     itself, evaluated on entry, instead of a hardcoded prompt-id==28
##     check. This also fixes a soft-lock where running out of time left
##     the player with zero available choices.

signal game_state_changed(new_state: int)
signal prompt_changed(prompt: Dictionary)
signal stats_changed
signal narrative_outcome(text: String)
signal minigame_requested(minigame_type: String, config: Dictionary)

enum GameState { SPLASH, MAIN_MENU, PLAYING, SETTINGS, GAME_OVER, GAME_WON }

const MAX_STAT := 100
const SAVE_PATH := "user://savegame.json"
const PROMPTS_PATH := "res://data/prompts.json"
const STARTING_PROMPT_ID := 1

var current_state: int = GameState.SPLASH
var can_continue: bool = false

var stats: Dictionary = {"hp": 50, "sta": 40, "mor": 50}
var elapsed_time: int = 0
var flags: Dictionary = {}

var current_prompt_id: int = STARTING_PROMPT_ID
var current_prompt: Dictionary = {}
var all_prompts: Dictionary = {}
var last_narrative_outcome: String = ""

var _pending_minigame: Dictionary = {}


func _ready() -> void:
	_load_prompts_from_json(PROMPTS_PATH)
	can_continue = FileAccess.file_exists(SAVE_PATH)


# ---------------------------------------------------------------- Loading --

func _load_prompts_from_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("GameManager: could not find %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_ARRAY:
		push_error("GameManager: prompts.json did not parse as an array")
		return false

	all_prompts.clear()
	for prompt in parsed:
		all_prompts[int(prompt["id"])] = prompt

	print("GameManager: loaded %d prompts" % all_prompts.size())
	return true


# ------------------------------------------------------------- Game flow --

func start_game() -> void:
	stats = {"hp": 50, "sta": 40, "mor": 50}
	elapsed_time = 0
	flags.clear()
	_delete_saved_game()
	_go_to_prompt(STARTING_PROMPT_ID)
	_set_state(GameState.PLAYING)


func continue_game() -> void:
	if _load_game():
		_set_state(GameState.PLAYING)
	else:
		start_game()


func select_choice(choice: Dictionary) -> void:
	# A minigame choice hands control to a minigame scene instead of resolving
	# immediately - the outcome (and its own nextPromptId) arrives later via
	# resolve_minigame() once the player has won or lost.
	if choice.has("launchMinigame"):
		var launch: Dictionary = choice["launchMinigame"]
		_pending_minigame = launch
		minigame_requested.emit(launch.get("type", ""), launch.get("config", {}))
		return

	var next_id: int = int(choice.get("nextPromptId", 0))

	# Sentinel return-to-menu signals
	if next_id == -1000:
		_return_to_main_menu(true, false)
		return
	if next_id == -2000:
		_return_to_main_menu(false, true)
		return
	if next_id == -3000:  # "end of written content" - not a death, just a stop
		_return_to_main_menu(false, false, true)
		return

	# 1. Apply stat/time consequence (always, regardless of branch)
	if choice.has("consequence"):
		_apply_change(choice["consequence"])

	# 2. Apply unconditional setFlags
	if choice.has("setFlags"):
		_apply_set_flags(choice["setFlags"])

	last_narrative_outcome = choice.get("narrativeOutcome", "")

	# 3. Resolve branchOnFlag (replaces iOS's text-matching special cases)
	if choice.has("branchOnFlag"):
		var branch: Dictionary = choice["branchOnFlag"]
		var flag_name: String = branch.get("flag", "")
		var condition_met: bool

		if branch.has("min") or branch.has("max"):
			# Threshold mode - for numeric flags like trust/relationship scores.
			var value := _resolve_int_value(flag_name)
			condition_met = true
			if branch.has("min") and value < int(branch["min"]):
				condition_met = false
			if branch.has("max") and value > int(branch["max"]):
				condition_met = false
		else:
			# Exact-match mode (original behavior) - for bool/string flags.
			var expected = branch.get("value", true)
			var actual = flags.get(flag_name, false)
			condition_met = (actual == expected)

		var outcome: Dictionary = branch["ifTrue"] if condition_met else branch["ifFalse"]

		next_id = int(outcome.get("nextPromptId", next_id))
		if outcome.has("narrativeOutcome"):
			last_narrative_outcome = outcome["narrativeOutcome"]
		if outcome.has("consequence"):
			_apply_change(outcome["consequence"])
		if outcome.has("setFlags"):
			_apply_set_flags(outcome["setFlags"])

	if last_narrative_outcome != "":
		narrative_outcome.emit(last_narrative_outcome)

	# 4. Game-over checks use the REAL stat values (this was the broken part on iOS)
	if stats["hp"] < 5:
		_trigger_game_over(
			"Your wounds are grievous, vision blurring. The strength to go on has fled. Darkness consumes you.",
			"prompt_game_over_death")
		return
	if stats["sta"] < 5:
		_trigger_game_over(
			"An overwhelming weariness drags you down. Each breath is a monumental effort. You collapse, unable to move another step.",
			"prompt_game_over_exhaustion")
		return
	if stats["mor"] < 5:
		_trigger_game_over(
			"The weight of this broken world crushes your spirit. Hope is a forgotten word. You find a quiet place and simply... stop.",
			"prompt_game_over_despair")
		return

	# 5. Move to the next prompt
	_go_to_prompt(next_id)

	if current_prompt.get("id", 0) == 201:  # Haven / win condition
		_set_state(GameState.GAME_WON)

	_save_game()


## Called by a minigame scene once it's done, in place of select_choice().
## Applies the onSuccess/onFailure branch of the launchMinigame that's still
## pending, the same way branchOnFlag's ifTrue/ifFalse is applied above.
## The config sub-dict for the minigame that was just requested, so the
## minigame scene (which arrives via a scene change and can't receive
## constructor args) can pull its setup after minigame_requested fires.
func pending_minigame_config() -> Dictionary:
	return _pending_minigame.get("config", {})


func resolve_minigame(success: bool) -> void:
	if _pending_minigame.is_empty():
		push_error("GameManager: resolve_minigame() called with no pending minigame")
		return

	var launch := _pending_minigame
	_pending_minigame = {}

	var outcome: Dictionary = launch.get("onSuccess", {}) if success else launch.get("onFailure", {})
	var next_id: int = int(outcome.get("nextPromptId", 0))

	last_narrative_outcome = outcome.get("narrativeOutcome", "")
	if outcome.has("consequence"):
		_apply_change(outcome["consequence"])
	if outcome.has("setFlags"):
		_apply_set_flags(outcome["setFlags"])

	if last_narrative_outcome != "":
		narrative_outcome.emit(last_narrative_outcome)

	if stats["hp"] < 5:
		_trigger_game_over(
			"Your wounds are grievous, vision blurring. The strength to go on has fled. Darkness consumes you.",
			"prompt_game_over_death")
		return
	if stats["sta"] < 5:
		_trigger_game_over(
			"An overwhelming weariness drags you down. Each breath is a monumental effort. You collapse, unable to move another step.",
			"prompt_game_over_exhaustion")
		return
	if stats["mor"] < 5:
		_trigger_game_over(
			"The weight of this broken world crushes your spirit. Hope is a forgotten word. You find a quiet place and simply... stop.",
			"prompt_game_over_despair")
		return

	_go_to_prompt(next_id)

	if current_prompt.get("id", 0) == 201:  # Haven / win condition
		_set_state(GameState.GAME_WON)

	_save_game()


func _go_to_prompt(id: int) -> void:
	if not all_prompts.has(id):
		push_error("GameManager: prompt id %d not found" % id)
		current_prompt = {
			"id": 0, "day": "Error", "text": "Error: prompt %d not found." % id,
			"choices": [{"text": "Return to Main Menu", "nextPromptId": -3000}]
		}
		current_prompt_id = id
		prompt_changed.emit(current_prompt)
		return

	var prompt: Dictionary = all_prompts[id]

	# Generic prompt-entry timeout redirect (replaces the hardcoded id==28 check)
	if prompt.has("timeoutRedirect"):
		var redirect: Dictionary = prompt["timeoutRedirect"]
		var value := _resolve_int_value(redirect.get("flag", "elapsedTime"))
		var triggered := false
		if redirect.has("min") and value >= int(redirect["min"]):
			triggered = true
		if redirect.has("max") and value <= int(redirect["max"]):
			triggered = true
		if triggered:
			_go_to_prompt(int(redirect["redirectToPromptId"]))
			return

	current_prompt = prompt
	current_prompt_id = id
	prompt_changed.emit(current_prompt)


# --------------------------------------------------------- Stats / flags --

func _apply_change(change: Dictionary) -> void:
	stats["hp"] = clampi(stats["hp"] + int(change.get("hpDelta", 0)), 0, MAX_STAT)
	stats["sta"] = clampi(stats["sta"] + int(change.get("staDelta", 0)), 0, MAX_STAT)
	stats["mor"] = clampi(stats["mor"] + int(change.get("morDelta", 0)), 0, MAX_STAT)
	elapsed_time += int(change.get("timeDelta", 0))
	stats_changed.emit()


func _apply_set_flags(set_flags: Dictionary) -> void:
	for key in set_flags.keys():
		var wrapper = set_flags[key]
		if typeof(wrapper) == TYPE_DICTIONARY and wrapper.has("value"):
			flags[key] = wrapper["value"]
		else:
			flags[key] = wrapper


func is_choice_available(choice: Dictionary) -> bool:
	if choice.has("requiredBoolFlags"):
		for key in choice["requiredBoolFlags"].keys():
			if flags.get(key, false) != choice["requiredBoolFlags"][key]:
				return false
	if choice.has("requiredStringFlags"):
		for key in choice["requiredStringFlags"].keys():
			if flags.get(key, "") != choice["requiredStringFlags"][key]:
				return false
	if choice.has("requiredIntFlags"):
		for key in choice["requiredIntFlags"].keys():
			var req: Dictionary = choice["requiredIntFlags"][key]
			var value := _resolve_int_value(key)
			if req.has("min") and value < int(req["min"]):
				return false
			if req.has("max") and value > int(req["max"]):
				return false
	return true


# "hp" / "sta" / "mor" / "elapsedTime" resolve to the real live values.
# Anything else falls back to the flags dictionary (int flags like
# "daysWithoutWater"). This is the fix for the broken HP-gating bug.
func _resolve_int_value(key: String) -> int:
	match key:
		"hp": return stats["hp"]
		"sta": return stats["sta"]
		"mor": return stats["mor"]
		"elapsedTime": return elapsed_time
		_: return int(flags.get(key, 0))


func flag_bool(key: String) -> Variant:
	return flags[key] if flags.has(key) and typeof(flags[key]) == TYPE_BOOL else null


func flag_string(key: String) -> Variant:
	return flags[key] if flags.has(key) and typeof(flags[key]) == TYPE_STRING else null


func flag_int(key: String) -> Variant:
	return flags[key] if flags.has(key) and typeof(flags[key]) == TYPE_INT else null


# ---------------------------------------------------------------- States --

func _trigger_game_over(text: String, image_name: String) -> void:
	current_prompt = {
		"id": -1, "day": "Error", "text": text, "imageName": image_name,
		"choices": [{"text": "Accept Fate & Return to Menu", "nextPromptId": -1000}]
	}
	prompt_changed.emit(current_prompt)
	_set_state(GameState.GAME_OVER)


func quit_to_main_menu() -> void:
	_return_to_main_menu(false, false, false)


func _return_to_main_menu(from_game_over: bool = false, from_game_won: bool = false, from_end_of_content: bool = false) -> void:
	if current_state == GameState.PLAYING and not from_game_over and not from_game_won and not from_end_of_content:
		_save_game()
	if from_game_over or from_game_won or from_end_of_content:
		_reset_session()
	if from_game_won:
		_delete_saved_game()
	_set_state(GameState.MAIN_MENU)


func _reset_session() -> void:
	stats = {"hp": 50, "sta": 40, "mor": 50}
	elapsed_time = 0
	flags.clear()
	current_prompt_id = STARTING_PROMPT_ID


func go_to_settings() -> void:
	_set_state(GameState.SETTINGS)


func _set_state(new_state: int) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)


# ------------------------------------------------------------- Save/load --

func _save_game() -> void:
	var data := {
		"stats": stats,
		"elapsed_time": elapsed_time,
		"flags": flags,
		"current_prompt_id": current_prompt_id,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	can_continue = true


func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		can_continue = false
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_delete_saved_game()
		return false

	var loaded_id := int(parsed.get("current_prompt_id", STARTING_PROMPT_ID))
	if not all_prompts.has(loaded_id):
		_delete_saved_game()
		return false

	stats = parsed.get("stats", stats)
	elapsed_time = int(parsed.get("elapsed_time", 0))
	flags = parsed.get("flags", {})
	_go_to_prompt(loaded_id)
	can_continue = true
	return true


func _delete_saved_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	can_continue = false
