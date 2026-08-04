extends Node
## Persistent background music player - autoload, survives every scene
## change. Starts once at boot and loops forever.

@onready var player: AudioStreamPlayer = $Player

func _ready() -> void:
	player.finished.connect(func(): player.play())
	player.play()
