class_name EnemySpawner
extends Area3D

@export var spawn_entries: Array[SpawnEntry] = []
@export var height_offset: float = 0.05
@export var spawn_on_ready: bool = true

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	if spawn_on_ready:
		# Aguarda um frame para garantir que a árvore e o mundo carregaram totalmente
		await get_tree().process_frame
		start_spawning(get_tree().current_scene)

# Chamado para iniciar o spawn dos inimigos no mapa local
func start_spawning(world: Node3D) -> void:
	if not collision_shape or not (collision_shape.shape is BoxShape3D):
		print("[SPAWNER] Aviso: %s precisa de um CollisionShape3D com BoxShape3D." % name)
		return

	var box = collision_shape.shape as BoxShape3D
	var half_size = box.size * 0.5

	for entry in spawn_entries:
		if not entry or not entry.scene:
			continue

		for i in range(entry.count):
			var local_pos = Vector3(
				randf_range(-half_size.x, half_size.x),
				height_offset,
				randf_range(-half_size.z, half_size.z)
			)
			var global_spawn_pos = collision_shape.global_transform * local_pos
			var m_level = randi_range(entry.min_level, entry.max_level)
			
			# Sorteia a raridade localmente (se o mundo tiver a função, senão usa "Normal")
			var m_rarity = "Normal"
			if world and world.has_method("roll_monster_rarity"):
				m_rarity = world.roll_monster_rarity()

			# Instancia o monstro diretamente de forma local
			_spawn_monster_instance(entry.scene, global_spawn_pos, m_level, m_rarity, world)

func _spawn_monster_instance(monster_scene: PackedScene, spawn_pos: Vector3, m_level: int, m_rarity: String, world: Node3D) -> void:
	var monster_instance = monster_scene.instantiate() as MonsterBase
	if not monster_instance:
		return

	# Adiciona o monstro na cena atual (ou no container de monstros do mundo)
	var container = world.find_child("MonstersContainer", true, false)
	if container:
		container.add_child(monster_instance)
	else:
		world.add_child(monster_instance)

	monster_instance.global_position = spawn_pos
	monster_instance.spawn_origin = spawn_pos
	monster_instance.origin_area = self

	if monster_instance.has_method("setup_stats"):
		monster_instance.setup_stats(m_level, m_rarity)

# Chamado pelo monstro ao renascer para obter nova posição e nível dentro da zona
func get_respawn_data() -> Dictionary:
	var respawn_pos = global_position
	var assigned_level = 1

	if collision_shape and collision_shape.shape is BoxShape3D:
		var box = collision_shape.shape as BoxShape3D
		var half_extents = box.size * 0.5
		
		var rx = randf_range(-half_extents.x, half_extents.x)
		var rz = randf_range(-half_extents.z, half_extents.z)
		respawn_pos = global_position + Vector3(rx, 0.5, rz)

	if not spawn_entries.is_empty():
		var entry = spawn_entries[randi() % spawn_entries.size()]
		assigned_level = randi_range(entry.min_level, entry.max_level)

	return {
		"pos": respawn_pos,
		"level": assigned_level
	}
