extends Control

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		var player = get_tree().get_first_node_in_group("Player")
		if not player:
			return

		# 1. Se o player estiver no modo de mira de magia, cancela a mira primeiro
		if "skill_manager" in player and player.skill_manager and player.skill_manager.is_targeting_spell:
			player.skill_manager.cancel_targeting()
			get_viewport().set_input_as_handled()
			return

		# 2. Se alguma aba do player estiver aberta, fecha todas elas e mantém o jogo rodando
		var any_window_open = false
		if "ui_attr_panel" in player and player.ui_attr_panel and player.ui_attr_panel.visible:
			player.ui_attr_panel.visible = false
			any_window_open = true
		if "ui_status_panel" in player and player.ui_status_panel and player.ui_status_panel.visible:
			player.ui_status_panel.visible = false
			any_window_open = true
		if "ui_inventory_panel" in player and player.ui_inventory_panel and player.ui_inventory_panel.visible:
			player.ui_inventory_panel.visible = false
			any_window_open = true
		if "ui_equipment_panel" in player and player.ui_equipment_panel and player.ui_equipment_panel.visible:
			player.ui_equipment_panel.visible = false
			any_window_open = true
		if "ui_quest_panel" in player and player.ui_quest_panel and player.ui_quest_panel.visible:
			player.ui_quest_panel.visible = false
			any_window_open = true

		if any_window_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

		# 3. Se nada estava aberto, alterna o Menu de Pausa (Abre/Fecha)
		toggle_pause_menu()
		get_viewport().set_input_as_handled()

func toggle_pause_menu() -> void:
	visible = not visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true # Pausa a física do jogo
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false # Retoma o jogo

# Botão: Salvar Jogo Manualmente
func _on_btn_save_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("save_player_account"):
		player.save_player_account()

# Botão: Sair do Jogo
func _on_btn_quit_pressed() -> void:
	get_tree().quit()
