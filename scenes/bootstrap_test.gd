extends Node
## Temporary smoke-test scene. Press Play in the Godot editor and check the
## Output panel - this proves the ported story engine (GameManager +
## prompts.json) works before any UI exists. Delete this once real scenes
## (Main Menu, Game View, etc.) are built, and update project.godot's
## run/main_scene to point at the real entry point.

func _ready() -> void:
	print("=== Wasteland Echoes: GameManager smoke test ===")
	GameManager.start_game()
	_print_current_prompt()


func _print_current_prompt() -> void:
	var p: Dictionary = GameManager.current_prompt
	print("\n[%s] (id %s)" % [p.get("day", "?"), str(p.get("id", "?"))])
	print(p.get("text", ""))
	for choice in p.get("choices", []):
		var available: bool = GameManager.is_choice_available(choice)
		var suffix := "" if available else "  (locked: %s)" % choice.get("disabledReason", "requirement not met")
		print(" - %s%s" % [choice.get("text", ""), suffix])
	print("\nStats: HP %d | STA %d | MOR %d | Time %d min" % [
		GameManager.stats["hp"], GameManager.stats["sta"], GameManager.stats["mor"], GameManager.elapsed_time
	])

	# To walk through the whole story from the console, uncomment below and
	# re-run - it will auto-pick the first available choice each time:
	# _auto_play()


func _auto_play() -> void:
	var prompt: Dictionary = GameManager.current_prompt
	var steps := 0
	while prompt.get("choices", []).size() > 0 and steps < 200:
		var picked: Dictionary = {}
		for c in prompt["choices"]:
			if GameManager.is_choice_available(c):
				picked = c
				break
		if picked.is_empty():
			print("No available choice - stuck.")
			break
		print(">> choosing: ", picked.get("text", ""))
		GameManager.select_choice(picked)
		prompt = GameManager.current_prompt
		_print_current_prompt()
		steps += 1
