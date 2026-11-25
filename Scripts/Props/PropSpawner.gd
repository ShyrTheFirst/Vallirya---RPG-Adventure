class_name PropSpawner
extends Node3D

@export var prop_scenes: Array[PackedScene] = []
@export var spawn_count: int = 15
@export var height_offset: float = 0.0
@export var snap_to_ground: bool = true 
@export var allow_random_rotation: bool = true
@export var min_spacing: float = 2.5
@export var max_spawn_attempts: int = 15

@export_category("Configuração de Respawn")
@export var enable_respawn: bool = true
@export var respawn_cooldown: float = 30.0

@export_category("Configuração de Mineração Opcional")
@export var forced_mineral_index: int = -1

@onready var collision_shapes: Array[CollisionShape3D] = []
var active_spawned_props: int = 0
var spawned_positions: Array[Vector3] = []

func _ready() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			collision_shapes.append(child)
			
	# Aguarda o frame de física para garantir que o chão do novo mapa já esteja ativo no PhysicsServer3D!
	await get_tree().physics_frame
	await get_tree().physics_frame
	start_spawning()

func start_spawning() -> void:
	if prop_scenes.is_empty() or collision_shapes.is_empty():
		return

	for i in range(spawn_count):
		spawn_single_prop()

	call_deferred("_bake_navigation_mesh")

func spawn_single_prop() -> void:
	var selected_scene = prop_scenes.pick_random()
	if not selected_scene:
		return

	var spawn_pos: Vector3 = Vector3.ZERO
	var found_valid_pos: bool = false

	for attempt in range(max_spawn_attempts):
		var candidate = get_random_point_in_area()
		if snap_to_ground:
			var ground_hit: Dictionary = _get_ground_hit(candidate)
			if not ground_hit["valid"]:
				continue
			candidate = ground_hit["position"]

		var too_close: bool = false
		for existing_pos in spawned_positions:
			var dist_xz: float = Vector2(candidate.x - existing_pos.x, candidate.z - existing_pos.z).length()
			if dist_xz < min_spacing:
				too_close = true
				break

		if not too_close:
			spawn_pos = candidate
			found_valid_pos = true
			break

	if not found_valid_pos:
		return

	spawned_positions.append(spawn_pos)
	var rand_rot_y = randf_range(0.0, TAU) if allow_random_rotation else 0.0

	var prop_instance = selected_scene.instantiate()
	if prop_instance:
		if prop_instance is MiningRock and forced_mineral_index >= 0:
			prop_instance.forced_mineral_index = forced_mineral_index

		if "spawner_reference" in prop_instance:
			prop_instance.spawner_reference = self

		# Preserva a rotação X e Z original da cena (ex: -90 graus da grama) e gira apenas o Y
		var original_rot: Vector3 = prop_instance.rotation
		var final_rot := Vector3(original_rot.x, rand_rot_y, original_rot.z)

		get_parent().call_deferred("add_child", prop_instance)
		prop_instance.set_deferred("global_position", spawn_pos - Vector3(0, height_offset, 0))
		prop_instance.set_deferred("rotation", final_rot)
		
		active_spawned_props += 1

func on_prop_destroyed() -> void:
	active_spawned_props = max(0, active_spawned_props - 1)
	
	if not enable_respawn:
		return

	get_tree().create_timer(respawn_cooldown).timeout.connect(func():
		if is_inside_tree():
			spawn_single_prop()
			call_deferred("_bake_navigation_mesh")
	)

func get_random_point_in_area() -> Vector3:
	if collision_shapes.is_empty():
		return global_position

	var shape_node = collision_shapes.pick_random()
	var shape = shape_node.shape
	var local_pos = Vector3.ZERO

	if shape is BoxShape3D:
		var half_size = shape.size * 0.5
		local_pos = Vector3(
			randf_range(-half_size.x, half_size.x),
			0,
			randf_range(-half_size.z, half_size.z)
		)
	elif shape is CylinderShape3D:
		var radius = shape.radius
		var angle = randf() * TAU
		var dist = sqrt(randf()) * radius
		local_pos = Vector3(
			cos(angle) * dist,
			0,
			sin(angle) * dist
		)
	else:
		local_pos = Vector3.ZERO

	return shape_node.global_transform * local_pos

func get_ground_position(pos: Vector3) -> Vector3:
	var hit := _get_ground_hit(pos)
	return hit["position"] if hit["valid"] else pos

func _get_ground_hit(pos: Vector3) -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	var ray_origin = pos + Vector3(0, 50.0, 0)
	var ray_target = pos - Vector3(0, 50.0, 0)

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	# Ignora áreas (como o InteractionArea do portal ou zonas de aggro) para bater só em chão sólido
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)

	if result and result.has("position"):
		var collider: Object = result.get("collider", null)
		if _is_prop_collider(collider):
			return {"valid": false, "position": pos}
		return {"valid": true, "position": result["position"]}
	
	return {"valid": false, "position": pos}

func _is_prop_collider(collider: Object) -> bool:
	if not collider or not (collider is Node):
		return false
	var node: Node = collider as Node
	while node:
		if node is MiningRock or "spawner_reference" in node:
			return true
		if node.is_in_group("Props") or node.is_in_group("Trees") or node.is_in_group("Rocks") or node.is_in_group("Harvestable"):
			return true
		node = node.get_parent()
	return false

func _bake_navigation_mesh() -> void:
	await get_tree().create_timer(0.5).timeout
	var root_scene = get_tree().current_scene
	if not root_scene:
		return
	var nav_region = root_scene.find_child("NavigationRegion3D", true, false)
	if nav_region and nav_region is NavigationRegion3D:
		nav_region.bake_navigation_mesh()
