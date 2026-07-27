extends Control
## Keypad Entry minigame - second minigame on the generic launchMinigame
## protocol (see GameManager.minigame_requested / resolve_minigame).
## Player enters a numeric code on a 0-9 keypad within a limited number
## of attempts.
##
## Config keys (all optional): codeLength (int, default 4), maxAttempts
## (int, default 3), code (string of digits - randomized if absent).

const DEFAULT_CODE_LENGTH := 4
const DEFAULT_MAX_ATTEMPTS := 3

@onready var display_label: Label = $CenterContainer/MainPanel/ContentVBox/DisplayLabel
@onready var message_label: Label = $CenterContainer/MainPanel/ContentVBox/MessageLabel
@onready var submit_button: Button = $CenterContainer/MainPanel/ContentVBox/Keypad/SubmitButton
@onready var clear_button: Button = $CenterContainer/MainPanel/ContentVBox/Keypad/ClearButton
@onready var digit_buttons: Array[Button] = [
	$CenterContainer/MainPanel/ContentVBox/Keypad/Digit1,
	$CenterContainer/MainPanel/ContentVBox/Keypad/Digit2,
	$CenterContainer/MainPanel/ContentVBox/Keypad/Digit3,
	$CenterContainer/MainPanel/ContentVBox/Keypad/Digit4,
	$CenterContainer/MainPanel/ContentVBox/Keypad/Digit5,
	$CenterContainer/MainPanel/ContentVBox/Keypad/Digit6,
	$CenterContainer/MainPanel/ContentVBox/Keypad/Digit7,
	$CenterContainer/MainPanel/ContentVBox/Keypad/Digit8,
	$CenterContainer/MainPanel/ContentVBox/Keypad/Digit9,
	$CenterContainer/MainPanel/ContentVBox/Keypad/Digit0,
]
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer

var _code_length: int
var _max_attempts: int
var _code: String
var _entered: String = ""
var _attempts_remaining: int
var _resolved := false


func _ready() -> void:
	var config := GameManager.pending_minigame_config()

	_code_length = int(config.get("codeLength", DEFAULT_CODE_LENGTH))
	_max_attempts = int(config.get("maxAttempts", DEFAULT_MAX_ATTEMPTS))
	_attempts_remaining = _max_attempts

	var configured_code = config.get("code")
	_code = str(configured_code) if configured_code != null else _random_code(_code_length)

	for i in range(digit_buttons.size()):
		var digit := i + 1 if i < 9 else 0  # Digit1..Digit9, then Digit0
		digit_buttons[i].pressed.connect(_on_digit_pressed.bind(digit))
	clear_button.pressed.connect(_on_clear_pressed)
	submit_button.pressed.connect(_on_submit_pressed)

	_update_display()
	_update_message()


func _random_code(length: int) -> String:
	var digits := ""
	for i in range(length):
		digits += str(randi() % 10)
	return digits


func _on_digit_pressed(digit: int) -> void:
	if _resolved or _entered.length() >= _code_length:
		return
	sfx_player.play()
	_entered += str(digit)
	_update_display()


func _on_clear_pressed() -> void:
	if _resolved:
		return
	sfx_player.play()
	_entered = ""
	_update_display()


func _on_submit_pressed() -> void:
	if _resolved or _entered.length() != _code_length:
		return
	sfx_player.play()

	if _entered == _code:
		_resolve(true)
		return

	_attempts_remaining -= 1
	_entered = ""
	_update_display()

	if _attempts_remaining <= 0:
		_resolve(false)
	else:
		message_label.text = "Incorrect. %d attempt%s remaining." % [
			_attempts_remaining, "" if _attempts_remaining == 1 else "s"
		]


func _update_display() -> void:
	var chars := []
	for i in range(_code_length):
		chars.append(_entered[i] if i < _entered.length() else "_")
	display_label.text = " ".join(chars)
	submit_button.disabled = _entered.length() != _code_length


func _update_message() -> void:
	message_label.text = "Enter the %d-digit code. %d attempt%s remaining." % [
		_code_length, _attempts_remaining, "" if _attempts_remaining == 1 else "s"
	]


func _resolve(success: bool) -> void:
	if _resolved:
		return
	_resolved = true
	for button in digit_buttons:
		button.disabled = true
	clear_button.disabled = true
	submit_button.disabled = true
	GameManager.resolve_minigame(success)
	SceneTransition.change_scene("res://scenes/game_view.tscn")
