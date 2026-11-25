class_name ForgeWithFlame
extends CraftingStation

@export_category("Luz da Forja")
@export var flame_light_path: NodePath
@export var base_energy: float = 2.2
@export var flicker_amplitude: float = 0.45
@export var flicker_speed: float = 9.0

@onready var flame_light: OmniLight3D =$FlameLight

var _time_acc: float = 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(flame_light):
		return

	_time_acc += delta * flicker_speed

	# Combina duas ondas senoidais para evitar um piscar robótico e repetitivo
	var wave = sin(_time_acc) * 0.65 + sin(_time_acc * 2.37 + 1.1) * 0.35
	flame_light.light_energy = max(0.0, base_energy + wave * flicker_amplitude)
