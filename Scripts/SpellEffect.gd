class_name SpellEffect
extends Node3D

@export_category("Configuração da Magia Instantânea")
@export var duration: float = 1.0 # Tempo antes da magia sumir (queue_free)

var stored_damage: int = 0
var stored_effect: String = ""
var caster_node: CharacterBody3D = null

@onready var damage_area: Area3D = find_damage_area()
@onready var effect_sound: AudioStreamPlayer3D = get_node_or_null("EffectSound")

func setup(damage_amount: int, effect_type: String, caster: CharacterBody3D) -> void:
	stored_damage = damage_amount
	stored_effect = effect_type
	caster_node = caster

func _ready() -> void:
	if effect_sound and effect_sound.stream:
		effect_sound.pitch_scale = randf_range(0.95, 1.05) # Pequena variação natural no pitch
		effect_sound.play()

	# Como o efeito é instantâneo, aplica o dano logo no primeiro frame de física
	apply_instant_damage()

	# Timer para destruir a magia após o tempo de duração visual
	get_tree().create_timer(duration).timeout.connect(func():
		queue_free()
	)

func find_damage_area() -> Area3D:
	for child in get_children():
		if child is Area3D:
			return child
	return get_node_or_null("Area3D") as Area3D

func apply_instant_damage() -> void:
	if not damage_area:
		apply_aoe_fallback()
		return

	# Garante que a física calculou as posições atuais
	await get_tree().physics_frame

	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return

	var col_shape: CollisionShape3D = null
	for child in damage_area.get_children():
		if child is CollisionShape3D:
			col_shape = child
			break

	if not col_shape or not col_shape.shape:
		return

	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = col_shape.shape
	query.transform = col_shape.global_transform
	query.collision_mask = 4 

	var results = space_state.intersect_shape(query)
	print("[SPELL DEBUG] Monstros na área da explosão instantânea: ", results.size())

	for result in results:
		var collider = result.get("collider")
		if is_instance_valid(collider) and collider.is_in_group("Monsters") and not collider.get("is_dead"):
			
			# Aplica o dano diretamente sem travas de metatag
			if collider.has_method("take_damage"):
				collider.take_damage(stored_damage, caster_node)
				
			if stored_effect != "" and collider.has_method("apply_status_effect"):
				collider.apply_status_effect(stored_effect, float(stored_damage) * 0.5, 3.0)
				
			print("[SPELL] Dano aplicado instantaneamente em: %s | Dano: %d" % [collider.name, stored_damage])

func apply_aoe_fallback() -> void:
	var monsters = get_tree().get_nodes_in_group("Monsters")
	for m in monsters:
		if is_instance_valid(m) and not m.get("is_dead"):
			if global_position.distance_to(m.global_position) <= 3.0:
				if m.has_method("take_damage"):
					m.take_damage(stored_damage, caster_node)
				if stored_effect != "" and m.has_method("apply_status_effect"):
					m.apply_status_effect(stored_effect, float(stored_damage) * 0.5, 3.0)
