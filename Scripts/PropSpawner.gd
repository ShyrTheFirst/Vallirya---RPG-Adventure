class_name PropSpawner
extends Area3D

@export var prop_scenes: Array[PackedScene] = []
@export var spawn_count: int = 5
@export var spawn_on_ready: bool = true

var collision_shapes: Array[CollisionShape3D] = []

func _ready() -> void:
	# Coleta todos os CollisionShape3D que estão dentro desta Area3D
	for child in get_children():
		if child is CollisionShape3D and child.shape != null:
			collision_shapes.append(child)

	# Se ativado, espalha os props automaticamente assim que o mapa carregar
	if spawn_on_ready:
		# Aguarda um frame para garantir que a física do terreno já carregou na árvore
		await get_tree().process_frame
		start_spawning()

func start_spawning() -> void:
	if prop_scenes.is_empty():
		return

	if collision_shapes.is_empty():
		print("[PROP_SPAWNER] Nenhum CollisionShape3D encontrado em: ", name)
		return

	for i in range(spawn_count):
		var selected_scene = prop_scenes.pick_random()
		if not selected_scene:
			continue

		var spawn_pos = get_random_point_in_area()
		var rand_rot_y = randf_range(0.0, TAU)

		# Instancia o prop diretamente na cena de forma local (Singleplayer)
		var prop_instance = selected_scene.instantiate() as Node3D
		if prop_instance:
			# Adiciona o prop como filho do pai do spawner (ex: o mapa atual)
			get_parent().add_child(prop_instance)
			prop_instance.global_position = spawn_pos
			prop_instance.rotation.y = rand_rot_y

# Sorteia um dos shapes disponíveis e ajusta a altura na superfície do chão via Raycast
func get_random_point_in_area() -> Vector3:
	var chosen_shape_node: CollisionShape3D = collision_shapes.pick_random()
	var shape = chosen_shape_node.shape
	var origin = chosen_shape_node.global_position

	var rand_x: float = 0.0
	var rand_z: float = 0.0

	if shape is BoxShape3D:
		var size = shape.size
		rand_x = randf_range(-size.x / 2.0, size.x / 2.0)
		rand_z = randf_range(-size.z / 2.0, size.z / 2.0)
	elif shape is CylinderShape3D or shape is SphereShape3D:
		var radius = shape.radius
		var angle = randf() * TAU
		var dist = sqrt(randf()) * radius
		rand_x = cos(angle) * dist
		rand_z = sin(angle) * dist

	var base_x = origin.x + rand_x
	var base_z = origin.z + rand_z
	var ray_start_y = origin.y + 20.0 # Começa 20m acima para garantir o raio

	return _snap_to_ground(Vector3(base_x, ray_start_y, base_z))

# Dispara um raio físico vertical para baixo para colidir no terreno
func _snap_to_ground(start_pos: Vector3) -> Vector3:
	var space_state = get_world_3d().direct_space_state
	var end_pos = start_pos + Vector3(0.0, -80.0, 0.0)

	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 1 # Camada do terreno/chão

	var result = space_state.intersect_ray(query)
	if result:
		return result.position

	return start_pos - Vector3(0.0, 20.0, 0.0)
