class_name NpcQuestBoard
extends NpcBase

@export var quest_board_ui_scene: PackedScene = preload("res://Scenes/UI/QuestBoardUI.tscn")
var active_board_ui: Control = null

func _ready() -> void:
	add_to_group("NPCs")
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_player_entered)
		interaction_area.body_exited.connect(_on_player_exited)
	
	if name_label:
		name_label.text = npc_name
		
	if name_sprite:
		name_sprite.visible = false # Nome sempre visível acima do NPC

	if interaction_prompt:
		interaction_prompt.visible = false

	update_visual_quest_status()

# Sobrescreve o interact do NpcBase para NÃO abrir caixa de diálogo e ir direto para o QuestBoardUI
func interact(player_node: CharacterBody3D) -> void:
	if not player_node or global_position.distance_to(player_node.global_position) > 4.5:
		return

	toggle_quest_board(player_node)

func toggle_quest_board(player_node: CharacterBody3D) -> void:
	if active_board_ui and is_instance_valid(active_board_ui):
		active_board_ui.queue_free()
		active_board_ui = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		update_visual_quest_status()
	else:
		if quest_board_ui_scene:
			active_board_ui = quest_board_ui_scene.instantiate()
			if player_node.has_node("CanvasLayer"):
				player_node.get_node("CanvasLayer").add_child(active_board_ui)
			else:
				get_tree().current_scene.add_child(active_board_ui)
			
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			
			# Atualiza o ícone da cabeça do NPC assim que o jogador fechar o mural pelo botão da UI
			active_board_ui.tree_exited.connect(update_visual_quest_status)

# Quando o jogador se afasta, o NpcBase chama close_dialogue_ui() automaticamente.
# Sobrescrevemos aqui para garantir que o mural feche se o player sair andando.
func close_dialogue_ui() -> void:
	if active_board_ui and is_instance_valid(active_board_ui):
		active_board_ui.queue_free()
		active_board_ui = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	super.close_dialogue_ui()

# Opcional: Faz o ícone (?, !) na cabeça do NPC reagir às missões do mural
func get_current_quest_status() -> QuestStatus:
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not has_node("/root/QuestManager"):
		return QuestStatus.NONE

	var has_in_progress: bool = false
	var has_available: bool = false

	# 1. Verifica os contratos da vila que são entregues direto no mural
	for bounty in QuestManager.village_bounties:
		if bounty.get("turned_in", false):
			continue
		
		var b_id = bounty.get("id", "")
		var found_in_player: bool = false
		
		for active_q in player.client_active_quests:
			if active_q.get("id", "") == b_id:
				found_in_player = true
				if active_q.get("completed", false):
					return QuestStatus.READY_TO_TURN_IN # ! Verde (Tem contrato pronto para entregar no mural)
				else:
					has_in_progress = true
				break
				
		if not found_in_player:
			has_available = true

	# 2. Verifica se a missão urgente atual ainda não foi aceita nem concluída
	QuestManager.sync_main_story_progress(player)
	var main_q_id = "main_story_%d" % QuestManager.main_story_progress
	if QuestManager.quests_database.has(main_q_id) and not player.completed_quests.has(main_q_id):
		var main_active: bool = false
		for active_q in player.client_active_quests:
			if active_q.get("id", "") == main_q_id:
				main_active = true
				break
		if not main_active:
			has_available = true

	if has_in_progress:
		return QuestStatus.IN_PROGRESS # ! Laranja
	if has_available:
		return QuestStatus.AVAILABLE # ? Amarelo

	return QuestStatus.NONE
