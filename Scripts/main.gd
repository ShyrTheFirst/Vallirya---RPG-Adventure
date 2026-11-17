extends Node3D

@onready var level_container: Node3D = $LevelContainer

func _ready() -> void:
	print("[MAIN] Cena principal carregada.")
	
	# Só carrega a ilha_inicial como fallback se o Player ainda não tiver carregado o mapa do save dele
	if level_container and level_container.get_child_count() == 0:
		print("[MAIN] Nenhum mapa detectado no container. Inicializando mapa inicial padrão...")
		if LevelManager.has_method("load_map_into_container"):
			LevelManager.load_map_into_container("ilha_inicial", "SpawnPoint", LevelManager.is_new_game)
