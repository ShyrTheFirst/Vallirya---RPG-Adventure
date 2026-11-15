extends SpellEffect

@onready var bola: MeshInstance3D = $Bola

func _process(delta: float) -> void:
	bola.position.y -= delta * 3
