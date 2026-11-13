class_name SpellDecal
extends Node3D

@export var max_range: float = 12.0 # Distância máxima que o player pode mirar
var current_player: CharacterBody3D = null

func _ready() -> void:
	current_player = get_tree().current_scene.find_child("Player", true, false)

func _process(_delta: float) -> void:
	if not current_player:
		return
		
	# Faz um Raycast da câmera até a posição do mouse no mundo 3D
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 100.0)
	# Opcional: filtre para colidir apenas com o terreno/chão (Layer 1)
	query.collision_mask = 1 
	
	var result = space_state.intersect_ray(query)
	if result:
		var hit_point = result["position"]
		
		# Limita a distância máxima de alcance a partir do Soki
		var dist_to_player = (hit_point - current_player.global_position).length()
		if dist_to_player <= max_range:
			global_position = hit_point
		else:
			# Se passar do alcance, trava no limite máximo na direção do mouse
			var dir = (hit_point - current_player.global_position).normalized()
			global_position = current_player.global_position + (dir * max_range)
			
		# Garante que o decal grude bem rente ao chão ignorando pequenas elevações Y
		global_position.y = result["position"].y + 0.05
