class_name FallZone
extends Area3D

@export var damage_percent: float = 0.15 # O player perde 15% do HP máximo ao cair

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and body is CharacterBody3D:
		# 1. Zera a velocidade para o player não nascer caindo embalado
		body.velocity = Vector3.ZERO
		
		# 2. Aplica um dano de queda (opcional, para punir a bobeira)
		if "hp" in body and "max_hp" in body:
			var fall_damage = int(body.max_hp * damage_percent)
			body.hp = max(1, body.hp - fall_damage) # Nunca mata direto, deixa com pelo menos 1 de HP
			if body.has_method("show_damage_effect"):
				body.show_damage_effect(fall_damage, body.hp)
			if body.has_method("update_hud_display"):
				body.update_hud_display()
				
		# 3. Teleporta de volta para o último local seguro ou para o SpawnPoint do mapa
		_respawn_player_safely(body)

func _respawn_player_safely(player: CharacterBody3D) -> void:
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
		
	# Procura o SpawnPoint mais próximo ou o padrão do mapa atual
	var spawn_node = current_scene.find_child("SpawnPoint", true, false)
	if spawn_node and spawn_node is Node3D:
		player.global_position = spawn_node.global_position
		print("[FALL ZONE] Jogador caiu no abismo e foi retornado ao SpawnPoint.")
	else:
		# Fallback de segurança caso não ache o spawn
		player.global_position = Vector3(0, 5, 0)
