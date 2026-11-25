class_name NpcFloresta
extends NpcBase

var stored_action_type: String = "" # "assign" ou "turn_in"
var stored_target_quest_id: String = ""

# 1. Define visualmente o ícone flutuante (?, !, verde) baseado estritamente na quest atual do player
func get_current_quest_status() -> QuestStatus:
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return QuestStatus.NONE

	# --- ETAPA 1: Main Story 1 (Boas-Vindas a Kalythra) ---
	if not player.completed_quests.has("main_story_5"):
		if _has_active_quest(player, "main_story_5"):
			return QuestStatus.READY_TO_TURN_IN

	return QuestStatus.NONE

func handle_npc_dialogue_flow(player: CharacterBody3D) -> void:
	if not active_ui_instance:
		return

	# Conecta os sinais dos botões da UI
	if not active_ui_instance.is_connected("continue_dialogue_pressed", _on_continue_pressed):
		active_ui_instance.continue_dialogue_pressed.connect(_on_continue_pressed)
	if not active_ui_instance.is_connected("quest_accepted", _on_quest_accepted):
		active_ui_instance.quest_accepted.connect(_on_quest_accepted)
	if not active_ui_instance.is_connected("quest_denied", _on_quest_denied):
		active_ui_instance.quest_denied.connect(_on_quest_denied)


	# --- FLUXO RÍGIDO DA HISTÓRIA ---

	if player.completed_quests.has("main_story_4") and not player.completed_quests.has("main_story_5"):
		if _has_active_quest(player, "main_story_5"):
			var entry = _get_active_quest_entry(player, "main_story_5")
			if entry.get("completed", false):
				active_ui_instance.set_message(npc_name, "Voce ja esta cansado de matar tantos monstros, nao e? Parece que eles nunca vao embora, nao importa o que a gente faça...", "Continuar")
				stored_target_quest_id = "main_story_5"
				stored_action_type = "turn_in"
			else:
				# Ainda está fazendo (faltou falar com algum NPC)
				active_ui_instance.set_message(npc_name, "Voce pelo jeito ainda nao matou os Goblins para liberar o portal, ne?!", "Fechar")
				stored_target_quest_id = ""
				stored_action_type = ""
		return

	# --- ESPAÇO LIVRE PARA ADICIONAR AS PRÓXIMAS QUESTS DA HISTÓRIA DO VALKOR ---
	# Exemplo para a Main Story X:
	# if player.completed_quests.has("main_story_2") and not player.completed_quests.has("main_story_X"):
	#     ...

	# Caso padrão (Sem missões ativas com ele no momento)
	active_ui_instance.set_message(npc_name, "Matar, matar... So matamos tudo que se move...", "Fechar")
	stored_target_quest_id = ""
	stored_action_type = ""


# 3. Funções de clique dos botões da UI
func _on_continue_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and stored_action_type == "turn_in" and stored_target_quest_id != "":
		# Se for do tipo TALK_TO_NPC, garante que registra a conversa antes de entregar
		var q_data = QuestManager.quests_database.get(stored_target_quest_id, null)
		if q_data and q_data.quest_type == QuestData.QuestType.TALK_TO_NPC:
			QuestManager.on_npc_talked(player, npc_id)
			
		QuestManager.complete_and_turn_in_quest(player, stored_target_quest_id)
		stored_target_quest_id = ""
		stored_action_type = ""
	
	close_dialogue_ui()
	update_visual_quest_status()

func _on_quest_accepted(quest_data: QuestData) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and quest_data:
		QuestManager.assign_quest(player, quest_data.quest_id)
	close_dialogue_ui()
	update_visual_quest_status()

func _on_quest_denied() -> void:
	close_dialogue_ui()

# --- Funções auxiliares de busca ---
func _has_active_quest(player: Node, qid: String) -> bool:
	for q in player.client_active_quests:
		if q.get("id", "") == qid:
			return true
	return false

func _get_active_quest_entry(player: Node, qid: String) -> Dictionary:
	for q in player.client_active_quests:
		if q.get("id", "") == qid:
			return q
	return {}
