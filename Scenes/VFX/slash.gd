extends Node3D

@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	visible = false
	if anim:
		anim.animation_finished.connect(_on_animation_finished)

func trigger() -> void:
	visible = true
	var mesh: MeshInstance3D = get_node_or_null("Slash")
	if mesh:
		var mat := mesh.get_surface_override_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("Gradient_1_slider", 0.0)
			mat.set_shader_parameter("Gradient_2_slider", 0.0)
	if anim and anim.has_animation("Slash"):
		anim.stop()
		anim.play("Slash")

func _on_animation_finished(_anim_name: StringName) -> void:
	visible = false
