extends Control
## Radio Tuning minigame - first concrete minigame built on the generic
## launchMinigame protocol (see GameManager.minigame_requested /
## resolve_minigame). Player drags a slider to find a hidden target
## frequency within a tolerance before a countdown timer runs out.
##
## Config keys (all optional): targetFrequency (float, 0-100 internal
## range), tolerance (float, default 3), timeLimit (seconds, default 25).

const DEFAULT_TOLERANCE := 3.0
const DEFAULT_TIME_LIMIT := 25.0
const LOW_TIME_THRESHOLD := 5.0
const FREQ_MIN_MHZ := 88.0
const FREQ_MHZ_RANGE := 20.0  # 88.0-108.0 MHz
const TARGET_RANDOM_MIN := 15.0
const TARGET_RANDOM_MAX := 85.0

const NORMAL_TIMER_COLOR := Color(0.95, 0.95, 0.9, 1)
const LOW_TIMER_COLOR := Color(1, 0.35, 0.3, 1)

@onready var timer_label: Label = $CenterContainer/MainPanel/ContentVBox/TimerLabel
@onready var signal_label: Label = $CenterContainer/MainPanel/ContentVBox/SignalLabel
@onready var frequency_label: Label = $CenterContainer/MainPanel/ContentVBox/FrequencyLabel
@onready var freq_slider: HSlider = $CenterContainer/MainPanel/ContentVBox/FreqSlider
@onready var lock_button: Button = $CenterContainer/MainPanel/ContentVBox/LockButton
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer

var _target_frequency: float
var _tolerance: float
var _time_remaining: float
var _resolved := false


func _ready() -> void:
	var config := GameManager.pending_minigame_config()

	var configured_target = config.get("targetFrequency")
	_target_frequency = float(configured_target) if configured_target != null \
		else randf_range(TARGET_RANDOM_MIN, TARGET_RANDOM_MAX)
	_tolerance = float(config.get("tolerance", DEFAULT_TOLERANCE))
	_time_remaining = float(config.get("timeLimit", DEFAULT_TIME_LIMIT))

	freq_slider.value = 50.0
	freq_slider.value_changed.connect(_on_freq_changed)
	lock_button.pressed.connect(_on_lock_pressed)

	_update_frequency_display(freq_slider.value)
	_update_timer_display()


func _process(delta: float) -> void:
	if _resolved:
		return

	_time_remaining = max(_time_remaining - delta, 0.0)
	_update_timer_display()

	if _time_remaining <= 0.0:
		_resolve(false)


func _on_freq_changed(value: float) -> void:
	_update_frequency_display(value)


func _update_frequency_display(value: float) -> void:
	var mhz := FREQ_MIN_MHZ + (value / 100.0) * FREQ_MHZ_RANGE
	frequency_label.text = "%.1f MHz" % mhz
	signal_label.text = _signal_feedback(value)


func _signal_feedback(value: float) -> String:
	var distance := absf(value - _target_frequency)
	if distance <= _tolerance:
		return "Signal locked. This is it."
	elif distance <= _tolerance * 3.0:
		return "Getting warmer - almost there."
	elif distance <= _tolerance * 8.0:
		return "Faint signal, still searching."
	else:
		return "Just static."


func _update_timer_display() -> void:
	var seconds_left := ceili(_time_remaining)
	timer_label.text = str(seconds_left)
	timer_label.add_theme_color_override(
		"font_color",
		LOW_TIMER_COLOR if _time_remaining <= LOW_TIME_THRESHOLD else NORMAL_TIMER_COLOR
	)


func _on_lock_pressed() -> void:
	if _resolved:
		return
	sfx_player.play()
	var success := absf(freq_slider.value - _target_frequency) <= _tolerance
	_resolve(success)


func _resolve(success: bool) -> void:
	if _resolved:
		return
	_resolved = true
	lock_button.disabled = true
	freq_slider.editable = false
	GameManager.resolve_minigame(success)
	SceneTransition.change_scene("res://scenes/game_view.tscn")
