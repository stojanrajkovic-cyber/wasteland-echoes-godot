extends Control
## Port of MainMenuView.swift. Wires the menu buttons to GameManager and
## hands off to the next scene. Since GameView/Settings don't exist yet,
## both fall back to printing state to the console instead of crashing on
## a missing scene file - delete those fallback branches once those scenes
## are built.

const GAME_VIEW_SCENE := "res://scenes/game_view.tscn"
const SETTINGS_SCENE := "res://scenes/settings_view.tscn"

@onready var continue_button: Button = $Content/ContinueButton
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer


func _ready() -> void:
	continue_button.disabled = not GameManager.can_continue
	continue_button.modulate.a = 1.0 if GameManager.can_continue else 0.5

	$Content/NewGameButton.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	$Content/StoryButton.pressed.connect(_on_story_pressed)
	$Content/SettingsButton.pressed.connect(_on_settings_pressed)
	$Content/CreditsButton.pressed.connect(_on_credits_pressed)

	# Manual loop - simplest way to loop without touching .import metadata
	music_player.finished.connect(func(): music_player.play())


func _play_tap() -> void:
	sfx_player.play()


func _on_new_game_pressed() -> void:
	_play_tap()
	GameManager.start_game()
	_go_to_game_view()


func _on_continue_pressed() -> void:
	_play_tap()
	GameManager.continue_game()
	_go_to_game_view()


func _on_story_pressed() -> void:
	_play_tap()
	print("[MainMenu] Story/intro slideshow scene not built yet.")


func _on_settings_pressed() -> void:
	_play_tap()
	GameManager.go_to_settings()
	if ResourceLoader.exists(SETTINGS_SCENE):
		SceneTransition.change_scene(SETTINGS_SCENE)
	else:
		print("[MainMenu] Settings scene not built yet. GameManager.current_state -> ", GameManager.current_state)


func _on_credits_pressed() -> void:
	_play_tap()
	print("[MainMenu] Credits popup not built yet.")


func _go_to_game_view() -> void:
	SceneTransition.change_scene(GAME_VIEW_SCENE)
