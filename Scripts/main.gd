extends Node3D

@onready var level_container: Node3D = $LevelContainer

func _ready() -> void:
	# Puxa o mapa inicial automaticamente assim que a cena Main entra na árvore
	print("[MAIN] Cena principal carregada. Inicializando mapa inicial...")
	
	# Garante que o LevelManager sabe qual mapa carregar
	if LevelManager.has_method("load_map_into_container"):
		LevelManager.load_map_into_container("ilha_inicial", "SpawnPoint")
