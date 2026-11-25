extends Node3D

@export var speed: float = 18.0
@export var max_lifetime: float = 3.0

var direction: Vector3 = Vector3.FORWARD
var damage: int = 10
var caster: Node = null

@onready var area: Area3D = $Area3D

func _ready() -> void:
	if area:
		area.body_entered.connect(_on_body_entered)
	get_tree().create_timer(max_lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body == caster:
		return
	if body.is_in_group("Monsters") and body.has_method("take_damage"):
		body.take_damage(damage, caster)
	queue_free()
