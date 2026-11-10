extends Node3D

@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	visible = false
	if anim:
		anim.animation_finished.connect(_on_animation_finished)

func trigger() -> void:
	visible = true
	if anim:
		anim.stop()
		anim.play("Slash")

func _on_animation_finished(_anim_name: StringName) -> void:
	visible = false
