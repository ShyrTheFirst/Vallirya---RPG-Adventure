class_name MapPortal
extends StaticBody3D

@export_category("Destino do Portal")
# Nome exato da chave no dicionário MAPS do LevelManager ("floresta" ou "ilha_inicial")
@export var target_map_key: String = "floresta"
# Nome do nó Marker3D / Node3D dentro do mapa de destino onde o player vai nascer
@export var target_spawn_point: String = "SpawnPoint"

@export_category("Configuração de Interação")
@export var require_button_press: bool = true # true = aperta E | false = teleporta ao encostar
@export var interact_action: String = "Interagir"
@export var prompt_text: String = "E"

@export_category("Aparência do Portal")
@export var core_color: Color = Color(0.3, 0.85, 1.0, 1.0)
@export var swirl_color: Color = Color(0.1, 0.4, 1.0, 1.0)

@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_prompt: Sprite3D = $InteractionPrompt
@onready var sub_viewport: SubViewport = $InteractionPrompt/SubViewport
@onready var prompt_label: Label = $InteractionPrompt/SubViewport/Label

var player_in_range: CharacterBody3D = null
var is_teleporting: bool = false

func _ready() -> void:
	# Configura a textura do SubViewport no Sprite3D (resolve o aviso de Path no console)
	if interaction_prompt and sub_viewport:
		interaction_prompt.texture = sub_viewport.get_texture()
		interaction_prompt.visible = false
		
	if prompt_label:
		prompt_label.text = prompt_text

	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	_apply_portal_colors()

func _apply_portal_colors() -> void:
	var portal_mesh := find_child("Portal", true, false) as MeshInstance3D
	if not portal_mesh:
		return

	var mat := portal_mesh.get_surface_override_material(0) as ShaderMaterial
	if not mat:
		mat = portal_mesh.get_active_material(0) as ShaderMaterial
	if mat:
		var unique_mat := mat.duplicate() as ShaderMaterial
		portal_mesh.set_surface_override_material(0, unique_mat)
		unique_mat.set_shader_parameter("core_color", core_color)
		unique_mat.set_shader_parameter("swirl_color", swirl_color)

	for child in portal_mesh.get_children():
		if child is OmniLight3D:
			child.light_color = swirl_color

func _unhandled_input(event: InputEvent) -> void:
	if is_teleporting or not require_button_press or not is_instance_valid(player_in_range):
		return
		
	var pressed_interact: bool = false
	if interact_action != "" and InputMap.has_action(interact_action):
		pressed_interact = event.is_action_pressed(interact_action)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		pressed_interact = true
		
	if pressed_interact:
		_teleport_player()

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if is_teleporting:
		return
		
	var detected_player: CharacterBody3D = null
	if body.is_in_group("Player") and body is CharacterBody3D:
		detected_player = body
	elif body.is_in_group("PlayerHorse") and body.get("is_occupied") and is_instance_valid(body.get("rider")):
		detected_player = body.get("rider") as CharacterBody3D

	if detected_player:
		player_in_range = detected_player
		if require_button_press:
			if interaction_prompt:
				interaction_prompt.visible = true
		else:
			_teleport_player()

func _on_interaction_area_body_exited(body: Node3D) -> void:
	var is_same_player = (body == player_in_range) or (body.is_in_group("PlayerHorse") and body.get("rider") == player_in_range)
	if is_same_player:
		player_in_range = null
		if interaction_prompt:
			interaction_prompt.visible = false

func _teleport_player() -> void:
	if target_map_key == "":
		print("[PORTAL] Erro: 'target_map_key' está vazio no Inspetor!")
		return
		
	is_teleporting = true
	if interaction_prompt:
		interaction_prompt.visible = false
		
	# Procura o LevelManager como Autoload (/root/LevelManager) ou dentro da cena principal
	var lm = get_node_or_null("/root/LevelManager")
	if not lm and get_tree().current_scene:
		lm = get_tree().current_scene.find_child("LevelManager", true, false)
		
	if lm and lm.has_method("load_map_into_container"):
		lm.load_map_into_container(target_map_key, target_spawn_point, true)
	else:
		print("[PORTAL] Erro: LevelManager não encontrado!")
		is_teleporting = false
