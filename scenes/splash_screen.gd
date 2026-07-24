extends Control
## Splash screen: logo fades in centered, slides up to the 1/3-height line,
## then a START button fades in at the 2/3-height line. Tapping anywhere
## during the animation skips to the final state. START -> main menu.
## All positions are computed from the viewport size, so this works on any
## resolution/aspect ratio.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const LOGO_WIDTH_RATIO := 0.85     # logo width as fraction of screen width
const FADE_IN_TIME := 1.4
const HOLD_TIME := 0.4
const SLIDE_TIME := 0.9
const BUTTON_FADE_TIME := 0.6

@onready var logo: TextureRect = $TitleLogo
@onready var start_button: Button = $StartButton
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer

var _animation_done := false
var _tween: Tween


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)

	var vp := get_viewport_rect().size

	# Size the logo: 85% of screen width, keep source aspect ratio.
	var tex_size := logo.texture.get_size()
	var logo_w := vp.x * LOGO_WIDTH_RATIO
	var logo_h := logo_w * (tex_size.y / tex_size.x)
	logo.size = Vector2(logo_w, logo_h)

	# Start: centered on screen, invisible.
	var center_pos := Vector2((vp.x - logo_w) / 2.0, (vp.y - logo_h) / 2.0)
	# End: logo center sits on the 1/3-height line.
	var top_pos := Vector2((vp.x - logo_w) / 2.0, vp.y / 3.0 - logo_h / 2.0)
	logo.position = center_pos
	logo.modulate.a = 0.0

	# START button: centered on the 2/3-height line, invisible & inert for now.
	var btn_w := vp.x * 0.6
	start_button.size = Vector2(btn_w, start_button.custom_minimum_size.y)
	start_button.position = Vector2((vp.x - btn_w) / 2.0, vp.y * 2.0 / 3.0 - start_button.size.y / 2.0)
	start_button.modulate.a = 0.0
	start_button.disabled = true

	# Animation chain: fade in -> hold -> slide up -> button fade in.
	_tween = create_tween()
	_tween.tween_property(logo, "modulate:a", 1.0, FADE_IN_TIME)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(logo, "position", top_pos, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): start_button.disabled = false)
	_tween.tween_property(start_button, "modulate:a", 1.0, BUTTON_FADE_TIME)
	_tween.tween_callback(func(): _animation_done = true)

	# Store the end position for the skip path.
	set_meta("logo_top_pos", top_pos)


func _gui_input(event: InputEvent) -> void:
	# Tap anywhere mid-animation -> jump straight to the final state.
	if _animation_done:
		return
	if (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed):
		_skip_to_end()


func _skip_to_end() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	logo.modulate.a = 1.0
	logo.position = get_meta("logo_top_pos")
	start_button.modulate.a = 1.0
	start_button.disabled = false
	_animation_done = true


func _on_start_pressed() -> void:
	sfx_player.play()
	# Tiny delay so the tap sound is audible before the scene switches.
	await get_tree().create_timer(0.1).timeout
	SceneTransition.change_scene(MAIN_MENU_SCENE)
