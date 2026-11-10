class_name QuadroAvisosUI
extends PanelContainer

@onready var btn_close: Button = $VBoxContainer/HBoxContainer/BtnClose
@onready var btn_refresh: Button = $VBoxContainer/HBoxContainer/BtnRefreshBoard
@onready var grid_container: GridContainer = $VBoxContainer/GridContainer 

func _ready() -> void:
	if btn_close and not btn_close.pressed.is_connected(_on_btn_close_pressed):
		btn_close.pressed.connect(_on_btn_close_pressed)
		
	if btn_refresh and not btn_refresh.pressed.is_connected(_on_btn_refresh_board_pressed):
		btn_refresh.pressed.connect(_on_btn_refresh_board_pressed)

	var player = get_tree().get_first_node_in_group("Player")
	QuestManager.sync_board_with_player(player)
	refresh_board_ui()

func refresh_board_ui() -> void:
	if not grid_container:
		return

	for child in grid_container.get_children():
		child.queue_free()

	var player = get_tree().get_first_node_in_group("Player")
	var board_quests = QuestManager.board_quests

	for i in range(board_quests.size()):
		var q = board_quests[i]
		
		var card_box = HBoxContainer.new()
		card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var info_label = Label.new()
		var prefix = "⭐ [Principal] " if q.get("is_main_story", false) else "📜 "
		info_label.text = "%s%s (Recompensa: %d XP)" % [prefix, q["title"], q["reward_xp"]]
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_label.add_theme_font_size_override("font_size", 11)
		info_label.modulate = Color(1.0, 0.85, 0.3) if q.get("is_main_story", false) else Color(0.9, 0.9, 0.9)
		card_box.add_child(info_label)

		var btn_action = Button.new()
		btn_action.add_theme_font_size_override("font_size", 11)
		
		if q.get("turned_in", false):
			btn_action.text = " Concluída ✔️ "
			btn_action.disabled = true
			btn_action.modulate = Color(0.5, 1.0, 0.5)
		else:
			var is_active = false
			var is_ready = false
			if player and "client_active_quests" in player:
				for active_q in player.client_active_quests:
					if active_q["id"] == q["id"]:
						is_active = true
						if active_q.get("completed", false):
							is_ready = true
						break

			if is_ready:
				btn_action.text = " Entregar 🎁 "
				btn_action.modulate = Color(0.3, 1.0, 0.4)
				var q_id = q["id"]
				var q_index = i
				btn_action.pressed.connect(func():
					_on_turn_in_quest_clicked(q_id, q_index)
				)
			elif is_active or q.get("accepted", false):
				btn_action.text = " Em Andamento... "
				btn_action.disabled = true
			else:
				btn_action.text = " Aceitar "
				var q_index = i
				btn_action.pressed.connect(func():
					_on_accept_quest_clicked(q_index)
				)
			
		card_box.add_child(btn_action)
		grid_container.add_child(card_box)

func _on_accept_quest_clicked(index: int) -> void:
	var board_quests = QuestManager.board_quests
	if index < 0 or index >= board_quests.size():
		return

	var quest = board_quests[index]
	if quest.get("accepted", false):
		return

	var player = get_tree().get_first_node_in_group("Player")
	if player and "client_active_quests" in player:
		quest["accepted"] = true
		
		var player_quest_copy = quest.duplicate()
		player.client_active_quests.append(player_quest_copy)
		
		if player.has_method("update_quest_tracker_ui"):
			player.update_quest_tracker_ui()

	refresh_board_ui()

func _on_turn_in_quest_clicked(quest_id: String, board_index: int) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not "client_active_quests" in player:
		return

	for i in range(player.client_active_quests.size()):
		var q = player.client_active_quests[i]
		if q["id"] == quest_id and q.get("completed", false):
			var xp = q.get("reward_xp", 50)
			if player.has_method("add_experience"):
				player.add_experience(xp)

			player.client_active_quests.remove_at(i)
			if not player.completed_quests.has(quest_id):
				player.completed_quests.append(quest_id)
				
			if player.has_method("update_quest_tracker_ui"):
				player.update_quest_tracker_ui()
			break

	var board_quests = QuestManager.board_quests
	if board_index >= 0 and board_index < board_quests.size():
		board_quests[board_index]["turned_in"] = true

	refresh_board_ui()

func _on_btn_refresh_board_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if QuestManager.try_refresh_board(player):
		refresh_board_ui()
		print("[QUADRO] Mural renovado para o próximo nível de história!")
	else:
		print("[QUADRO] Conclua todas as missões ativas antes de renovar o mural!")

func _on_btn_close_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
