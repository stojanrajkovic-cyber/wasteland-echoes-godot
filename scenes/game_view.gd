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
const PROMPT_PANEL_MAX_HEIGHT_RATIO := 0.4
const REVEAL_FADE_TIME := 0.12
const BASE_TOP_MARGIN := 40
const BASE_BOTTOM_MARGIN := 50

@onready var background: TextureRect = $Background
@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var main_vbox: VBoxContainer = $MainVBox
@onready var top_bar_margin: MarginContainer = $MainVBox/TopBarMargin
@onready var bottom_margin: MarginContainer = $MainVBox/BottomMargin
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
@onready var main_menu_button: Button = $MainVBox/BottomMargin/BottomVBox/MainMenuButton
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer
@onready var long_press_timer: Timer = $LongPressTimer
@onready var bag_button: Button = $MainVBox/TopBarMargin/TopBar/BagButton
@onready var inventory_modal: Control = $InventoryModal
@onready var items_grid: GridContainer = $InventoryModal/PopupCenter/InventoryPanel/InventoryVBox/ItemsGrid
@onready var inventory_close_button: Button = $InventoryModal/PopupCenter/InventoryPanel/InventoryVBox/CloseButton

const MINIGAME_SCENES := {
	"radio_tuning": "res://scenes/minigames/radio_tuning.tscn",
	"keypad_entry": "res://scenes/minigames/keypad_entry.tscn",
}

const INVENTORY_ITEMS := [
	{"key": "hasFood", "label": "Food", "type": "int", "icon": "icon_food.png"},
	{"key": "hasWater", "label": "Water", "type": "int", "icon": "icon_water.png"},
	{"key": "hasMedkit", "label": "Medkit", "type": "bool", "icon": "icon_medkit.png"},
	{"key": "hasBattery", "label": "Battery", "type": "bool", "icon": "icon_battery.png"},
	{"key": "hasWeapon", "label": "Weapon", "type": "bool", "icon": "icon_weapon.png"},
	{"key": "hasMap", "label": "Map", "type": "bool", "icon": "icon_map.png"},
	{"key": "hasRope", "label": "Rope", "type": "bool", "icon": "icon_rope.png"},
	{"key": "hasLighter", "label": "Lighter", "type": "bool", "icon": "icon_lighter.png"},
	{"key": "hasFlashlight", "label": "Flashlight", "type": "bool", "icon": "icon_flashlight.png"},
	{"key": "hasKnife", "label": "Knife", "type": "bool", "icon": "icon_knife.png"},
	{"key": "scrap", "label": "Scrap", "type": "int", "icon": "icon_scrap.png"},
]

var _reveal_active := false


func _ready() -> void:
	_apply_safe_area_margins()

	GameManager.prompt_changed.connect(_on_prompt_changed)
	GameManager.stats_changed.connect(_on_stats_changed)
	GameManager.narrative_outcome.connect(_on_narrative_outcome)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.minigame_requested.connect(_on_minigame_requested)
	outcome_button.pressed.connect(_on_outcome_dismissed)
	long_press_timer.timeout.connect(_on_long_press_timeout)
	bag_button.pressed.connect(_on_bag_pressed)
	inventory_close_button.pressed.connect(_on_inventory_close_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

	outcome_modal.visible = false
	inventory_modal.visible = false
	_on_stats_changed()
	_render_prompt(GameManager.current_prompt)  # first paint - no flash, the scene-level fade already covers entry


func _apply_safe_area_margins() -> void:
	if OS.get_name() != "iOS" and OS.get_name() != "Android":
		return

	var screen_size := DisplayServer.screen_get_size()
	if screen_size.y <= 0:
		return

	var safe_area := DisplayServer.get_display_safe_area()
	var top_inset_native := safe_area.position.y
	var bottom_inset_native := screen_size.y - (safe_area.position.y + safe_area.size.y)
	if top_inset_native <= 0 and bottom_inset_native <= 0:
		return

	var scale_factor := get_viewport().get_visible_rect().size.y / float(screen_size.y)
	var top_inset_scaled := top_inset_native * scale_factor
	var bottom_inset_scaled := bottom_inset_native * scale_factor

	top_bar_margin.add_theme_constant_override("margin_top", BASE_TOP_MARGIN + int(top_inset_scaled))
	bottom_margin.add_theme_constant_override("margin_bottom", BASE_BOTTOM_MARGIN + int(bottom_inset_scaled))


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


func _on_bag_pressed() -> void:
	sfx_player.play()
	_rebuild_inventory()
	inventory_modal.visible = true


func _on_inventory_close_pressed() -> void:
	sfx_player.play()
	inventory_modal.visible = false


func _on_main_menu_pressed() -> void:
	sfx_player.play()
	GameManager.quit_to_main_menu()


func _rebuild_inventory() -> void:
	for child in items_grid.get_children():
		child.queue_free()

	for item in INVENTORY_ITEMS:
		var owned: bool
		var count_text := ""
		if item["type"] == "int":
			var count := int(GameManager.flags.get(item["key"], 0))
			owned = count > 0
			count_text = str(count)
		else:
			owned = GameManager.flags.get(item["key"], false) == true

		var cell := PanelContainer.new()
		var style := StyleBoxFlat.new()
		if owned:
			style.bg_color = Color(0.55, 0.3, 0.08, 0.6)
			style.border_color = Color(0.95, 0.65, 0.25, 0.9)
		else:
			style.bg_color = Color(0.06, 0.06, 0.06, 0.55)
			style.border_color = Color(0.3, 0.3, 0.3, 0.5)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 14
		style.corner_radius_top_right = 14
		style.corner_radius_bottom_left = 14
		style.corner_radius_bottom_right = 14
		style.content_margin_left = 12
		style.content_margin_top = 14
		style.content_margin_right = 12
		style.content_margin_bottom = 12
		cell.add_theme_stylebox_override("panel", style)
		cell.custom_minimum_size = Vector2(220, 160)

		var cell_vbox := VBoxContainer.new()
		cell_vbox.add_theme_constant_override("separation", 8)
		cell_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var icon_center := CenterContainer.new()
		var icon_rect := TextureRect.new()
		icon_rect.texture = load("res://assets/ui/icons/" + item["icon"])
		icon_rect.custom_minimum_size = Vector2(64, 64)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.modulate = Color(1, 1, 1, 1) if owned else Color(1, 1, 1, 0.3)
		icon_center.add_child(icon_rect)
		cell_vbox.add_child(icon_center)

		var label := Label.new()
		label.text = item["label"] if item["type"] == "bool" else "%s: %s" % [item["label"], count_text]
		label.add_theme_font_size_override("font_size", 28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate.a = 1.0 if owned else 0.45
		cell_vbox.add_child(label)

		cell.add_child(cell_vbox)
		items_grid.add_child(cell)


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


func _on_minigame_requested(minigame_type: String, _config: Dictionary) -> void:
	if not MINIGAME_SCENES.has(minigame_type):
		push_error("GameView: no scene registered for minigame type '%s'" % minigame_type)
		return
	SceneTransition.change_scene(MINIGAME_SCENES[minigame_type])


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
		button.custom_minimum_size = Vector2(0, 110)
		button.add_theme_stylebox_override("normal", _make_button_style())
		button.add_theme_font_size_override("font_size", 42)
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
# Using _input() directly - confirmed by testing to reliably receive events,
# unlike _gui_input/_unhandled_input which were being swallowed somewhere
# in the Control GUI layer despite mouse_filter settings. Debounced against
# duplicate mouse+touch events (emulate_touch_from_mouse fires both for a
# single physical click).

func _input(event: InputEvent) -> void:
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

	if pressed:
		if not long_press_timer.is_stopped():
			return  # already tracking a press - ignore the duplicate mouse/touch echo
		long_press_timer.start()
	else:
		if long_press_timer.is_stopped() and not _reveal_active:
			return  # duplicate/stray release - nothing to cancel
		long_press_timer.stop()
		if _reveal_active:
			_set_reveal(false)


func _on_long_press_timeout() -> void:
	_set_reveal(true)


func _set_reveal(active: bool) -> void:
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
