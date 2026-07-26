extends Control
## Port of GameView.swift - the core gameplay screen. Renders the current
## prompt, dynamically builds choice buttons, shows stats, and displays a
## modal popup (dismissed by tapping Continue) for narrativeOutcome text.
##
## Background images: looks for res://assets/backgrounds/{imageName}.jpg
## (or .png). If a prompt's imageName isn't found yet, falls back to a
## plain dark color so the story is fully playable while art is ported
## separately.
##
## PromptPanel grows with the text, capped at 50% of screen height - past
## that, it scrolls internally instead of pushing choices off-screen.
##
## Long-press anywhere on the background (not on a button) hides all UI so
## the player can see the full art; release to bring it back.

const BACKGROUND_DIR := "res://assets/backgrounds/"
const PROMPT_PANEL_MAX_HEIGHT_RATIO := 0.5
const REVEAL_FADE_TIME := 0.12

@onready var background: TextureRect = $Background
@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var main_vbox: VBoxContainer = $MainVBox
@onready var day_label: Label = $MainVBox/TopBarMargin/TopBar/DayLabel
@onready var hp_label: Label = $MainVBox/TopBarMargin/TopBar/StatsBox/HPBadge/HPLabel
@onready var sta_label: Label = $MainVBox/TopBarMargin/TopBar/StatsBox/StaBadge/StaLabel
@onready var mor_label: Label = $MainVBox/TopBarMargin/TopBar/StatsBox/MorBadge/MorLabel
@onready var outcome_modal: Control = $OutcomeModal
@onready var outcome_label: Label = $OutcomeModal/PopupCenter/OutcomePanel/OutcomeVBox/OutcomeLabel
@onready var outcome_button: Button = $OutcomeModal/PopupCenter/OutcomePanel/OutcomeVBox/OutcomeButton
@onready var prompt_scroll: ScrollContainer = $MainVBox/BottomMargin/BottomVBox/PromptPanel/PromptScroll
@onready var prompt_label: Label = $MainVBox/BottomMargin/BottomVBox/PromptPanel/PromptScroll/PromptLabel
@onready var choices_container: VBoxContainer = $MainVBox/BottomMargin/BottomVBox/ChoicesContainer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer
@onready var long_press_timer: Timer = $LongPressTimer

var _reveal_active := false


func _ready() -> void:
	print("[GameView] _ready() called - script is attached and running")
	GameManager.prompt_changed.connect(_on_prompt_changed)
	GameManager.stats_changed.connect(_on_stats_changed)
	GameManager.narrative_outcome.connect(_on_narrative_outcome)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	outcome_button.pressed.connect(_on_outcome_dismissed)
	long_press_timer.timeout.connect(_on_long_press_timeout)

	outcome_modal.visible = false
	_on_stats_changed()
	_render_prompt(GameManager.current_prompt)  # first paint - no flash, the scene-level fade already covers entry


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
	SceneTransition.flash_update(func(): _render_prompt(prompt))


func _render_prompt(prompt: Dictionary) -> void:
	day_label.text = prompt.get("day", "")
	prompt_label.text = prompt.get("text", "")
	_update_background(prompt.get("imageName", ""))
	_rebuild_choices(prompt.get("choices", []))
	_resize_prompt_panel()


func _resize_prompt_panel() -> void:
	# Let the label finish laying out at its new text/width before measuring.
	await get_tree().process_frame
	var max_height := get_viewport_rect().size.y * PROMPT_PANEL_MAX_HEIGHT_RATIO
	var natural_height := prompt_label.get_combined_minimum_size().y
	prompt_scroll.custom_minimum_size.y = min(natural_height, max_height)


func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameManager.GameState.MAIN_MENU:
		SceneTransition.change_scene("res://scenes/main_menu.tscn")


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


# ---------------------------------------------------- Long-press reveal --
# _unhandled_input fires for any press/release that no Control (button,
# scrollbar, etc.) already consumed - so this naturally only triggers on
# empty background area, with zero need to manage mouse_filter by hand.

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		print("[RAW _input] mouse button, pressed=", event.pressed)
	elif event is InputEventScreenTouch:
		print("[RAW _input] screen touch, pressed=", event.pressed)


func _unhandled_input(event: InputEvent) -> void:
	var is_press_event := false
	var pressed := false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_press_event = true
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		is_press_event = true
		pressed = event.pressed

	if not is_press_event:
		return

	print("[LongPress] unhandled_input reached - pressed=", pressed)

	if pressed:
		long_press_timer.start()
		print("[LongPress] timer started")
	else:
		long_press_timer.stop()
		print("[LongPress] released, reveal_active was ", _reveal_active)
		if _reveal_active:
			_set_reveal(false)


func _on_long_press_timeout() -> void:
	print("[LongPress] TIMER FIRED - activating reveal")
	_set_reveal(true)


func _set_reveal(active: bool) -> void:
	print("[LongPress] _set_reveal(", active, ") called")
	_reveal_active = active
	var tween := create_tween()
	tween.tween_property(main_vbox, "modulate:a", 0.0 if active else 1.0, REVEAL_FADE_TIME)
	tween.parallel().tween_property(dark_overlay, "modulate:a", 0.0 if active else 1.0, REVEAL_FADE_TIME)
	if not active:
		main_vbox.visible = true
	tween.finished.connect(func():
		if active:
			main_vbox.visible = false
	, CONNECT_ONE_SHOT)
