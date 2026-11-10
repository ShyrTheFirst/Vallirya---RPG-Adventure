class_name BaseMap
extends Node3D

@onready var monsters_container: Node3D = $MonstersContainer
@onready var items_container: Node3D = get_node_or_null("ItemsContainer")
@onready var spawn_point: Node3D = get_node_or_null("SpawnPoint")
@onready var monster_spawn_areas: Node3D = get_node_or_null("MonsterSpawnAreas")
@onready var prop_spawn_areas: Node3D = get_node_or_null("PropSpawnAreas")
@onready var props_container: Node3D = get_node_or_null("PropsContainer")

var default_drop_scene = preload("res://Resources/Scenes/drop.tscn")

func _ready() -> void:
	# Garante que os containers essenciais existam na cena
	if not props_container:
		props_container = Node3D.new()
		props_container.name = "PropsContainer"
		add_child(props_container)

	if not items_container:
		items_container = Node3D.new()
		items_container.name = "ItemsContainer"
		add_child(items_container)

	# Como o LevelManager já posiciona o player no SpawnPoint ao carregar o mapa,
	# aqui nós apenas disparamos a criação procedural local dos monstros e props!
	trigger_all_spawners()
	trigger_all_prop_spawners()
	
	print("[MAPA] Cenário carregado e populado localmente com sucesso.")

# Dispara os spawners de monstros locais
func trigger_all_spawners() -> void:
	if not monster_spawn_areas:
		return

	for child in monster_spawn_areas.get_children():
		if child.has_method("start_spawning"):
			child.start_spawning(self)

# Dispara os spawners de props locais (árvores, pedras, etc.)
func trigger_all_prop_spawners() -> void:
	if not prop_spawn_areas:
		return

	for child in prop_spawn_areas.get_children():
		if child.has_method("start_spawning"):
			child.start_spawning()

# Sistema local de drop de itens no chão
func server_spawn_world_item(res_path: String, pos: Vector3) -> void:
	if not ResourceLoader.exists(res_path):
		return

	var item_res: ItemData = load(res_path)
	if not item_res:
		return

	var drop_node = default_drop_scene.instantiate()
	drop_node.item_data = item_res
	
	items_container.add_child(drop_node)
	drop_node.global_position = pos

	if drop_node is RigidBody3D:
		var impulse = Vector3(randf_range(-0.5, 0.5), 1.5, randf_range(-0.5, 0.5))
		drop_node.apply_central_impulse(impulse)
	
	if drop_node.has_method("update_mesh_visual"):
		drop_node.update_mesh_visual()

# Sorteia raridades para os monstros de forma local
func roll_monster_rarity() -> String:
	var roll = randf()
	if roll > 0.95:
		return "Épico"
	elif roll > 0.75:
		return "Raro"
	return "Normal"

# Retorna a posição de spawn segura no mapa
func get_player_spawn_position() -> Vector3:
	if spawn_point:
		return spawn_point.global_position
	return Vector3(0, 1, 0)
