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

var _quit_dialog: ConfirmationDialog = null
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit_game()

func request_quit_game() -> void:
	if is_instance_valid(_quit_dialog):
		return

	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_quit_dialog = ConfirmationDialog.new()
	_quit_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	var theme_res := load("res://Assets/VFX/Themes/ValliryaTheme_Final.tres") as Theme
	if theme_res:
		_quit_dialog.theme = theme_res
	_quit_dialog.title = LanguageManager.tr_key("quit_confirm_title", "Confirmar Saída")
	_quit_dialog.dialog_text = LanguageManager.tr_key("quit_confirm_text", "Tem certeza que deseja sair do jogo?")
	_quit_dialog.ok_button_text = LanguageManager.tr_key("quit_confirm_ok", "Sair")
	_quit_dialog.cancel_button_text = LanguageManager.tr_key("quit_confirm_cancel", "Cancelar")
	_quit_dialog.confirmed.connect(_on_quit_confirmed)
	_quit_dialog.canceled.connect(_on_quit_canceled)
	_quit_dialog.close_requested.connect(_on_quit_canceled)

	get_tree().root.add_child(_quit_dialog)
	_quit_dialog.popup_centered()

func _on_quit_canceled() -> void:
	if is_instance_valid(_quit_dialog):
		_quit_dialog.queue_free()
		_quit_dialog = null
	if not get_tree().paused:
		Input.mouse_mode = _previous_mouse_mode

func _on_quit_confirmed() -> void:
	if is_instance_valid(_quit_dialog):
		_quit_dialog.queue_free()
		_quit_dialog = null
	await quit_game_cleanly()

func quit_game_cleanly() -> void:
	get_tree().call_group("NPCs", "close_dialogue_ui")

	var root = get_tree().root
	if root:
		for child in root.get_children():
			if child == self or child == QuestManager or child == AudioManager or child == CraftManager:
				continue
			if child is CanvasLayer or child is Window:
				child.queue_free()

	var current_scene = get_tree().current_scene
	if current_scene:
		for node in current_scene.find_children("*", "Control", true, false):
			if node.name.contains("QuestBoard") or node.name.contains("Crafting") or node.name.contains("Shop"):
				node.queue_free()

	await get_tree().process_frame
	get_tree().quit()

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

	var fade_rect: ColorRect = main_scene.find_child("Fade", true, false) as ColorRect
	if fade_rect:
		fade_rect.visible = true
		if is_instance_valid(current_map_instance):
			fade_rect.modulate.a = 0.0
			var fade_out_tween = create_tween()
			fade_out_tween.tween_property(fade_rect, "modulate:a", 1.0, 0.3)
			await fade_out_tween.finished
		else:
			fade_rect.modulate.a = 1.0
		
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

	for horse in get_tree().get_nodes_in_group("PlayerHorse"):
		if horse.has_method("on_map_changed"):
			horse.on_map_changed(map_key)

	if fade_rect:
		var fade_in_tween = create_tween()
		fade_in_tween.tween_property(fade_rect, "modulate:a", 0.0, 0.4)
		await fade_in_tween.finished
		fade_rect.visible = false

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
