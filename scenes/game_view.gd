extends Control
## Port of GameView.swift - the core gameplay screen. Renders the current
## prompt, dynamically builds choice buttons, shows stats, and displays a
## modal popup (dismissed by tapping Continue) for narrativeOutcome text.
##
## Background images: looks for res://assets/backgrounds/{imageName}.jpg
## (or .png). If a prompt's imageName isn't found yet, falls back to a
## plain dark color so the story is fully playable while art is ported
## separately.

const BACKGROUND_DIR := "res://assets/backgrounds/"

@onready var background: TextureRect = $Background
@onready var day_label: Label = $MainVBox/TopBarMargin/TopBar/DayLabel
@onready var hp_label: Label = $MainVBox/TopBarMargin/TopBar/StatsBox/HPBadge/HPLabel
@onready var sta_label: Label = $MainVBox/TopBarMargin/TopBar/StatsBox/StaBadge/StaLabel
@onready var mor_label: Label = $MainVBox/TopBarMargin/TopBar/StatsBox/MorBadge/MorLabel
@onready var outcome_modal: Control = $OutcomeModal
@onready var outcome_label: Label = $OutcomeModal/PopupCenter/OutcomePanel/OutcomeVBox/OutcomeLabel
@onready var outcome_button: Button = $OutcomeModal/PopupCenter/OutcomePanel/OutcomeVBox/OutcomeButton
@onready var prompt_label: Label = $MainVBox/BottomMargin/BottomVBox/PromptPanel/PromptLabel
@onready var choices_container: VBoxContainer = $MainVBox/BottomMargin/BottomVBox/ChoicesContainer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer


func _ready() -> void:
	GameManager.prompt_changed.connect(_on_prompt_changed)
	GameManager.stats_changed.connect(_on_stats_changed)
	GameManager.narrative_outcome.connect(_on_narrative_outcome)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	outcome_button.pressed.connect(_on_outcome_dismissed)

	outcome_modal.visible = false
	_on_stats_changed()
	_on_prompt_changed(GameManager.current_prompt)  # render whatever's already current


func _on_stats_changed() -> void:
	hp_label.text = "HP %d" % GameManager.stats.get("hp", 0)
	sta_label.text = "STA %d" % GameManager.stats.get("sta", 0)
	mor_label.text = "MOR %d" % GameManager.stats.get("mor", 0)


func _on_narrative_outcome(text: String) -> void:
	if text == "":
		return
	outcome_label.text = text
	outcome_modal.visible = true


func _on_outcome_dismissed() -> void:
	sfx_player.play()
	outcome_modal.visible = false


func _on_prompt_changed(prompt: Dictionary) -> void:
	day_label.text = prompt.get("day", "")
	prompt_label.text = prompt.get("text", "")
	_update_background(prompt.get("imageName", ""))
	_rebuild_choices(prompt.get("choices", []))


func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.MAIN_MENU:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _update_background(image_name: String) -> void:
	if image_name == "":
		background.texture = null
		return
	for ext in ["jpg", "png"]:
		var path := "%s%s.%s" % [BACKGROUND_DIR, image_name, ext]
		if ResourceLoader.exists(path):
			background.texture = load(path)
			return
	background.texture = null  # not ported yet - BackgroundFallback color shows through


func _rebuild_choices(choices: Array) -> void:
	for child in choices_container.get_children():
		child.queue_free()

	for choice in choices:
		if not GameManager.is_choice_available(choice):
			continue
		var button := Button.new()
		button.text = choice.get("text", "")
		button.custom_minimum_size = Vector2(0, 96)
		button.add_theme_stylebox_override("normal", _make_button_style())
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(_on_choice_pressed.bind(choice))
		choices_container.add_child(button)


func _on_choice_pressed(choice: Dictionary) -> void:
	sfx_player.play()
	GameManager.select_choice(choice)


func _make_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.65)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 24
	style.content_margin_top = 14
	style.content_margin_right = 24
	style.content_margin_bottom = 14
	return style
