class_name QuestInfoContainer
extends PanelContainer

@onready var name_label: Label = $VBoxContainer/QNameLabel
@onready var desc_label: Label = $VBoxContainer/QDescLabel
@onready var btn_action: Button = $VBoxContainer/BtnTurnIn

var current_quest_data: Dictionary = {}
var is_main_quest: bool = false
var board_ui_reference: Control = null

func setup_quest_card(quest_dict: Dictionary, main: bool, ui_ref: Control) -> void:
	current_quest_data = quest_dict
	is_main_quest = main
	board_ui_reference = ui_ref
	
	if name_label:
		name_label.text = quest_dict.get("title", "Missão")
	if desc_label:
		desc_label.text = quest_dict.get("description", "Detalhes da missão.")

	_apply_rarity_border(int(quest_dict.get("rarity", ItemData.Rarity.COMMON)))
		
	update_button_state()

func _apply_rarity_border(rarity: int) -> void:
	var border_color := Color(0.8, 0.8, 0.8)
	if is_main_quest:
		border_color = Color(0.9, 0.2, 0.2)
	else:
		match rarity:
			ItemData.Rarity.UNCOMMON: border_color = Color(0.2, 0.8, 0.2)
			ItemData.Rarity.RARE: border_color = Color(0.2, 0.5, 1.0)
			ItemData.Rarity.EPIC: border_color = Color(0.6, 0.2, 0.8)
			ItemData.Rarity.LEGENDARY: border_color = Color(1.0, 0.6, 0.1)

	var base_style := get_theme_stylebox("panel")
	var style: StyleBoxFlat
	if base_style is StyleBoxFlat:
		style = base_style.duplicate() as StyleBoxFlat
	else:
		style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
		style.set_corner_radius_all(6)

	style.set_border_width_all(2)
	style.border_color = border_color
	add_theme_stylebox_override("panel", style)

func update_button_state() -> void:
	if not btn_action:
		return
		
	# Desconecta sinais anteriores para evitar duplicidade
	if btn_action.pressed.is_connected(_on_action_pressed):
		btn_action.pressed.disconnect(_on_action_pressed)

	var player = get_tree().get_first_node_in_group("Player")
	var q_id = current_quest_data.get("id", "")
	
	var is_active = false
	var is_completed = false
	
	if player and "client_active_quests" in player:
		for q in player.client_active_quests:
			if q.get("id") == q_id:
				is_active = true
				is_completed = q.get("completed", false)
				break

	if current_quest_data.get("turned_in", false):
		btn_action.text = "  Concluída  "
		btn_action.disabled = true
	elif is_completed:
		var turn_in_npc = current_quest_data.get("turn_in_npc", "")
		if turn_in_npc != "":
			btn_action.text = "  Entregar com NPC  "
			btn_action.disabled = true # Só entrega falando com o NPC no mundo
		else:
			btn_action.text = "  Entregar  "
			btn_action.disabled = false
			btn_action.pressed.connect(_on_action_pressed)
	elif is_active:
		btn_action.text = "  Em Andamento...  "
		btn_action.disabled = true
	else:
		btn_action.text = "  Aceitar Quest  "
		btn_action.disabled = false
		btn_action.pressed.connect(_on_action_pressed)

func _on_action_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	var q_id = current_quest_data.get("id", "")
	
	var is_completed = false
	if player and "client_active_quests" in player:
		for q in player.client_active_quests:
			if q.get("id") == q_id and q.get("completed", false):
				is_completed = true
				break

	if is_completed:
		# Entrega no quadro
		QuestManager.complete_and_turn_in_quest(player, q_id)
		current_quest_data["turned_in"] = true
	else:
		# Aceita a quest
		QuestManager.assign_quest(player, q_id)
		current_quest_data["accepted"] = true

	if board_ui_reference and board_ui_reference.has_method("refresh_board_ui"):
		board_ui_reference.refresh_board_ui()
