class_name FallZone
extends Area3D

@export var damage_percent: float = 0.15 # O player perde 15% do HP máximo ao cair

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	var target_player: CharacterBody3D = null
	var target_horse: CharacterBody3D = null

	if body.is_in_group("Player") and body is CharacterBody3D:
		target_player = body
	elif body.is_in_group("PlayerHorse") and body is CharacterBody3D and body.get("is_occupied") and is_instance_valid(body.get("rider")):
		target_horse = body
		target_player = body.get("rider") as CharacterBody3D

	if target_player:
		# 1. Zera a velocidade para o player/cavalo não nascer caindo embalado
		target_player.velocity = Vector3.ZERO
		if target_horse:
			target_horse.velocity = Vector3.ZERO
		
		# 2. Aplica um dano de queda (opcional, para punir a bobeira)
		if "hp" in target_player and "max_hp" in target_player:
			var fall_damage = int(target_player.max_hp * damage_percent)
			target_player.hp = max(1, target_player.hp - fall_damage) # Nunca mata direto, deixa com pelo menos 1 de HP
			if target_player.has_method("show_damage_effect"):
				target_player.show_damage_effect(fall_damage, target_player.hp)
			if target_player.has_method("update_hud_display"):
				target_player.update_hud_display()
				
		# 3. Teleporta de volta para o último local seguro ou para o SpawnPoint do mapa
		_respawn_player_safely(target_player, target_horse)

func _respawn_player_safely(player: CharacterBody3D, horse: CharacterBody3D = null) -> void:
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
		
	# Procura o SpawnPoint mais próximo ou o padrão do mapa atual
	var spawn_node = current_scene.find_child("SpawnPoint", true, false)
	var respawn_pos := Vector3(0, 5, 0)
	if spawn_node and spawn_node is Node3D:
		respawn_pos = spawn_node.global_position
		print("[FALL ZONE] Jogador caiu no abismo e foi retornado ao SpawnPoint.")

	player.global_position = respawn_pos
	if horse:
		horse.global_position = respawn_pos
