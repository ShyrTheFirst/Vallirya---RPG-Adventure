extends Node

const MAPS = {
	"ilha_inicial": preload("res://Scenes/Mapas/MapaInicial.tscn"),
	"floresta": preload("res://Scenes/Mapas/Mapa_02.tscn"),
	"BossGolem": preload("res://Scenes/Mapas/BossGolem.tscn"),
	"BossLich": preload("res://Scenes/Mapas/BossArenaLich.tscn")
}


var current_map_instance: Node3D = null
var current_map_key: String = "ilha_inicial"
var current_player_name: String = "Herói"
var is_new_game: bool = false

func load_map_into_container(map_key: String, spawn_point_name: String = "SpawnPoint", teleport_to_spawn: bool = false) -> void:
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
		
	if is_instance_valid(current_map_instance):
		container.remove_child(current_map_instance)
		current_map_instance.queue_free()
		
	current_map_key = map_key
	var map_scene_packed = MAPS[map_key]
	current_map_instance = map_scene_packed.instantiate()
	container.add_child(current_map_instance)
	
	print("[LEVEL MANAGER] Mapa carregado no container com sucesso: ", map_key)
	
	await get_tree().process_frame
	
	# Só teleporta para o SpawnPoint se for um personagem recém-criado OU se veio de um Portal (teleport_to_spawn = true)
	if is_new_game or teleport_to_spawn:
		is_new_game = false
		_teleport_player_to_spawn(main_scene, spawn_point_name)
	else:
		print("[LEVEL MANAGER] Teletransporte para o spawn ignorado (carregando posição salva do player).")

func _teleport_player_to_spawn(main_scene: Node, spawn_name: String) -> void:
	var player = main_scene.find_child("Player", true, false)
	
	if not is_instance_valid(current_map_instance) or not player:
		return
		
	var spawn_node = current_map_instance.find_child(spawn_name, true, false)
	if spawn_node:
		if player is CharacterBody3D:
			player.velocity = Vector3.ZERO
		player.global_position = spawn_node.global_position
		print("[LEVEL MANAGER] Player posicionado no spawn: ", spawn_name)
		
		# Salva imediatamente o novo mapa e a nova posição no JSON do Player
		if player.has_method("save_player_account"):
			player.save_player_account()
