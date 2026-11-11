class_name PropSpawner
extends Node3D

@export var prop_scenes: Array[PackedScene] = []
@export var spawn_count: int = 15
@export var height_offset: float = 0.0
@export var snap_to_ground: bool = true # Ativa o ajuste de altura pelo chão

@onready var collision_shapes: Array[CollisionShape3D] = []

func _ready() -> void:
	# Coleta automaticamente todos os CollisionShape3D filhos
	for child in get_children():
		if child is CollisionShape3D:
			collision_shapes.append(child)
			
	# Inicia o spawn automaticamente ao carregar a cena
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

		# --- SNAP TO GROUND (Ajusta a altura perfeitamente ao relevo do terreno) ---
		if snap_to_ground:
			spawn_pos = get_ground_position(spawn_pos)

		# Instancia o prop diretamente na cena de forma local (Singleplayer)
		var prop_instance = selected_scene.instantiate() as Node3D
		if prop_instance:
			get_parent().call_deferred("add_child", prop_instance)
			prop_instance.global_position = spawn_pos + Vector3(0, height_offset, 0)
			prop_instance.rotation.y = rand_rot_y

	# --- AUTO-BAKE DO NAVIGATION MESH ---
	# Após espalhar todos os props pelo mapa, mandamos o NavigationRegion3D recalcular o mapa de calor!
	call_deferred("_bake_navigation_mesh")

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

# Função de Raycast para colar o prop perfeitamente na superfície do terreno
func get_ground_position(pos: Vector3) -> Vector3:
	var space_state = get_world_3d().direct_space_state
	var ray_origin = pos + Vector3(0, 50.0, 0) # Joga o raio lá do alto
	var ray_target = pos - Vector3(0, 50.0, 0) # Aponta para baixo

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	# Opcional: configure a collision_mask se quiser filtrar apenas o terreno
	var result = space_state.intersect_ray(query)

	if result and result.has("position"):
		return result["position"]
	
	return pos

# Função que atualiza o mapa de navegação automaticamente com os novos obstáculos
func _bake_navigation_mesh() -> void:
	# Pequeno delay para acumular todos os spawners e assar o navmesh apenas uma vez de forma limpa
	await get_tree().create_timer(0.5).timeout
	var root_scene = get_tree().current_scene
	var nav_region = root_scene.find_child("NavigationRegion3D", true, false)
	if nav_region and nav_region is NavigationRegion3D:
		nav_region.bake_navigation_mesh()
		print("[PROP_SPAWNER] NavigationMesh assado com sucesso!")
