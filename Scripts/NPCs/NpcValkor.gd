class_name NpcValkor
extends NpcBase

@export_category("Configuração do Clímax (O Falso Lich)")
@export var boss_fight_quest_id: String = "main_story_73"
@export var boss_arena_scene: PackedScene = preload("res://Scenes/Mapas/BossArenaLich.tscn")

var stored_action_type: String = "" # "assign" ou "turn_in"
var stored_target_quest_id: String = ""

# 1. Define visualmente o ícone flutuante (?, !, verde) baseado estritamente na quest atual do player
func get_current_quest_status() -> QuestStatus:
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return QuestStatus.NONE

	# Checagem do Clímax do Lich (fase final)
	if _has_active_quest(player, boss_fight_quest_id):
		var entry = _get_active_quest_entry(player, boss_fight_quest_id)
		if entry.get("completed", false):
			return QuestStatus.READY_TO_TURN_IN
		return QuestStatus.IN_PROGRESS

	# --- ETAPA 1: Main Story 1 (Boas-Vindas a Kalythra) ---
	if not player.completed_quests.has("main_story_1"):
		if _has_active_quest(player, "main_story_1"):
			# Como é TALK_TO_NPC, ao ter ativa, já está pronta para entregar no Valkor
			return QuestStatus.READY_TO_TURN_IN
		else:
			# Se ainda não pegou, o Valkor tem a quest disponível para dar
			return QuestStatus.AVAILABLE

	# --- ETAPA 2: Main Story 2 (Kit de Sobrevivência - Falar com outros NPCs e voltar) ---
	if player.completed_quests.has("main_story_1") and not player.completed_quests.has("main_story_2"):
		if _has_active_quest(player, "main_story_2"):
			var entry = _get_active_quest_entry(player, "main_story_2")
			# Só fica verde (pronta para entregar) se o player conversou com os 3 NPCs exigidos
			if entry.get("completed", false):
				return QuestStatus.READY_TO_TURN_IN
			else:
				return QuestStatus.IN_PROGRESS # Laranja (em andamento, visitando ferreiro/feiticeira/mercador)
		else:
			return QuestStatus.AVAILABLE # Disponível para pegar com o Valkor

	# --- ADICIONE AQUI AS PRÓXIMAS ETAPAS DA HISTÓRIA DO VALKOR NO MESMO PADRÃO ---
	# Exemplo:
	# if player.completed_quests.has("main_story_2") and not player.completed_quests.has("main_story_X"):
	#     ...

	return QuestStatus.NONE

# 2. Controla exatamente o que acontece a cada clique no Valkor baseado no progresso real
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

	# --- CLÍMAX DO LICH ---
	var climax_entry = _get_active_quest_entry(player, boss_fight_quest_id)
	if not climax_entry.is_empty():
		if climax_entry.get("completed", false):
			active_ui_instance.set_message(npc_name, "Impossível... Como uma mera cria da guilda ousou me superar?")
			await get_tree().create_timer(2.5).timeout
			QuestManager.complete_and_turn_in_quest(player, boss_fight_quest_id)
			queue_free()
			active_ui_instance.queue_free()
		else:
			active_ui_instance.set_message(npc_name, "Insolente! A guilda recolhe os tributos para o meu império! Prepare-se!")
			await get_tree().create_timer(3.0).timeout
			active_ui_instance.queue_free()
			_transport_to_boss_arena(player)
		return

	# --- FLUXO RÍGIDO DA HISTÓRIA DO VALKOR ---

	# ETAPA 1: Main Story 1
	if not player.completed_quests.has("main_story_1"):
		if _has_active_quest(player, "main_story_1"):
			# Pronto para entregar a Main Story 1
			active_ui_instance.set_message(npc_name, "Excelente registro, aventureiro! Bem-vindo oficial à guilda de Kalythra.", "Concluir Inscrição")
			stored_target_quest_id = "main_story_1"
			stored_action_type = "turn_in"
		else:
			# Oferece a Main Story 1
			var q_data = QuestManager.quests_database.get("main_story_1", null)
			if q_data:
				active_ui_instance.set_quest_offer(npc_name, "Saudações a Kalythra! Eu sou o Mestre da Guilda. Apresente-se para formalizar seu registro:", q_data, false)
				stored_target_quest_id = "main_story_1"
				stored_action_type = "assign"
		return

	# ETAPA 2: Main Story 2 (Kit de Sobrevivência)
	if player.completed_quests.has("main_story_1") and not player.completed_quests.has("main_story_2"):
		if _has_active_quest(player, "main_story_2"):
			var entry = _get_active_quest_entry(player, "main_story_2")
			if entry.get("completed", false):
				# Já falou com os NPCs e voltou para entregar a Main Story 2
				active_ui_instance.set_message(npc_name, "Vejo que conversou com os mestres da cidade. Aqui está seu kit inicial de caçada!", "Receber Kit")
				stored_target_quest_id = "main_story_2"
				stored_action_type = "turn_in"
			else:
				# Ainda está fazendo (faltou falar com algum NPC)
				active_ui_instance.set_message(npc_name, "Você precisa visitar o Ferreiro, a Feiticeira e o Comerciante na praça antes de receber seu kit.", "Fechar")
				stored_target_quest_id = ""
				stored_action_type = ""
		else:
			# Oferece a Main Story 2 logo após terminar a 1
			var q_data = QuestManager.quests_database.get("main_story_2", null)
			if q_data:
				active_ui_instance.set_quest_offer(npc_name, "Para iniciar suas caçadas com segurança, conheça os mestres da cidade:", q_data, true)
				stored_target_quest_id = "main_story_2"
				stored_action_type = "assign"
		return

	# --- ESPAÇO LIVRE PARA ADICIONAR AS PRÓXIMAS QUESTS DA HISTÓRIA DO VALKOR ---
	# Exemplo para a Main Story X:
	# if player.completed_quests.has("main_story_2") and not player.completed_quests.has("main_story_X"):
	#     ...

	# Caso padrão (Sem missões ativas com ele no momento)
	active_ui_instance.set_message(npc_name, "Visite o Quadro de Missões na praça central para novos trabalhos da guilda, aventureiro.", "Fechar")
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

func _transport_to_boss_arena(player: CharacterBody3D) -> void:
	if not boss_arena_scene:
		return
	var arena_instance = boss_arena_scene.instantiate()
	get_tree().root.add_child(arena_instance)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = arena_instance
	if player.has_method("save_player_account"):
		player.save_player_account()
