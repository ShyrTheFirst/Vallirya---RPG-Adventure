class_name Portal
extends Node3D

@export_category("Configuração do Portal")
@export var target_map_key: String = "ilha_inicial" # A chave correspondente no dicionário MAPS do LevelManager
@export var target_spawn_name: String = "SpawnPoint" # O nome do nó de destino no novo mapa

@onready var interaction_area: Area3D = $Area3D

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		print("[PORTAL] Viajando para o mapa: ", target_map_key)
		
		# Pede para o LevelManager carregar o novo mapa e teletransportar o player para o spawn de destino
		LevelManager.load_map_into_container(target_map_key, target_spawn_name, true)
