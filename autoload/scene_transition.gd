extends CanvasLayer
## Global scene-transition fader - fade to black, swap scene, fade back in.
## Autoloaded so it persists across scene changes and renders above
## everything (layer 100, set in the .tscn). Use SceneTransition.change_scene(path)
## instead of get_tree().change_scene_to_file() anywhere a transition should
## fade rather than cut hard.

const FADE_TIME := 0.18

@onready var fade_rect: ColorRect = $FadeRect

var _busy := false


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # block taps mid-transition

	var fade_out := create_tween()
	fade_out.tween_property(fade_rect, "color:a", 1.0, FADE_TIME)
	await fade_out.finished

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame  # let the new scene finish entering the tree

	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "color:a", 0.0, FADE_TIME)
	await fade_in.finished

	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
