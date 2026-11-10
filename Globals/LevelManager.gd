extends Node

const MAPS = {
	"ilha_inicial": preload("res://Scenes/MapaInicial.tscn")
}

var current_map_instance: Node3D = null
var current_player_name: String = "Herói"

func load_map_into_container(map_key: String, spawn_point_name: String = "SpawnPoint") -> void:
	if not MAPS.has(map_key):
		print("[LEVEL MANAGER] Erro: O mapa '%s' não existe no dicionário!" % map_key)
		return
		
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
		
	var container = main_scene.find_child("LevelContainer", true, false)
	if not container:
		print("[LEVEL MANAGER] Erro: Nó 'LevelContainer' não encontrado na cena principal!")
		return
		
	if current_map_instance:
		current_map_instance.queue_free()
		
	var map_scene_packed = MAPS[map_key]
	current_map_instance = map_scene_packed.instantiate()
	container.add_child(current_map_instance)
	
	print("[LEVEL MANAGER] Mapa carregado no container com sucesso: ", map_key)
	
	await get_tree().process_frame
	_teleport_player_to_spawn(main_scene, spawn_point_name)

func _teleport_player_to_spawn(main_scene: Node, spawn_name: String) -> void:
	var player = main_scene.find_child("Player", true, false)
	
	if not current_map_instance or not player:
		return
		
	var spawn_node = current_map_instance.find_child(spawn_name, true, false)
	if spawn_node:
		player.global_position = spawn_node.global_position
		print("[LEVEL MANAGER] Player posicionado no spawn: ", spawn_name)
