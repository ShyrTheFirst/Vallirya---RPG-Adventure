extends Node

# Banco de dados de recursos .tres carregados automaticamente
var quests_database: Dictionary = {}

# Estado do Quadro de Missões gerenciado globalmente
var board_quests: Array = []
var main_story_progress: int = 1

func _ready() -> void:
	_load_quests_from_directory("res://Resources/Quests/")
	print("[QUEST MANAGER] Inicializado com sucesso. Quests carregadas: ", quests_database.keys())

func _load_quests_from_directory(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var file_path = path + "/" + file_name
				if file_path.get_extension() == "tres" or file_path.get_extension() == "res":
					var quest_res = load(file_path) as QuestData
					if quest_res and quest_res.quest_id != "":
						quests_database[quest_res.quest_id] = quest_res
			file_name = dir.get_next()
		dir.list_dir_end()

# --- 1. ATRIBUIR UMA QUEST AO JOGADOR ---
func assign_quest(player: Node3D, quest_id: String) -> void:
	if not player or not "client_active_quests" in player:
		return

	# Verifica se já tem ativa ou concluída
	for q in player.client_active_quests:
		if q.get("id") == quest_id:
			return
	if "completed_quests" in player and player.completed_quests.has(quest_id):
		return

	var quest_data: QuestData = null
	for key in quests_database.keys():
		if key.to_lower() == quest_id.to_lower():
			quest_data = quests_database[key]
			break
	if not quest_data:
		print("[QUEST MANAGER] Erro: Quest ID '%s' não encontrada no banco de dados!" % quest_id)
		return

	var new_quest = {
		"id": quest_id,
		"title": quest_data.title,
		"description": quest_data.description,
		"target_enemy": quest_data.target_id if "target_id" in quest_data else "",
		"required": quest_data.required_amount if "required_amount" in quest_data else 1,
		"current": 0,
		"reward_xp": quest_data.reward_xp,
		"reward_gold": quest_data.reward_gold if "reward_gold" in quest_data else 50,
		"is_main_story": true,
		"accepted": true,
		"completed": false
	}

	player.client_active_quests.append(new_quest)
	print("[QUEST] Missão atribuída: ", quest_data.title)
	
	if player.has_method("update_quest_tracker_ui"):
		player.update_quest_tracker_ui()

# --- 2. PROGRESSO: MONSTRO DERROTADO ---
func on_monster_killed(player: Node3D, monster_name: String) -> void:
	if not player or not "client_active_quests" in player:
		return

	for q in player.client_active_quests:
		if q.get("completed", false):
			continue

		var q_id = q.get("id", "")
		var quest_data: QuestData = quests_database.get(q_id, null)
		
		# Verifica se é missão de matar monstro (via QuestData ou via target_enemy procedural)
		var target = q.get("target_enemy", "")
		if quest_data and quest_data.quest_type == QuestData.QuestType.KILL_MONSTERS:
			target = quest_data.target_id

		if target != "" and target.to_lower() in monster_name.to_lower():
			q["current"] = min(int(q.get("required", 1)), int(q.get("current", 0)) + 1)
			
			if int(q.get("current", 0)) >= int(q.get("required", 1)):
				q["completed"] = true
				print("[QUEST] Objetivo alcançado! Pronto para entregar: ", q.get("title", ""))

	if player.has_method("update_quest_tracker_ui"):
		player.update_quest_tracker_ui()

# --- 3. PROGRESSO: CONVERSA COM NPC ---
func on_npc_talked(player: Node3D, npc_id: String) -> void:
	if not player or not "client_active_quests" in player:
		return

	for q in player.client_active_quests:
		if q.get("completed", false):
			continue

		var q_id = q.get("id", "")
		var quest_data: QuestData = quests_database.get(q_id, null)
		if quest_data and quest_data.quest_type == QuestData.QuestType.TALK_TO_NPC:
			if quest_data.target_id == npc_id:
				q["current"] = quest_data.required_amount
				q["completed"] = true
				print("[QUEST] Conversa concluída com o NPC %s! Pronto para entregar: " % npc_id, q.get("title", ""))

	if player.has_method("update_quest_tracker_ui"):
		player.update_quest_tracker_ui()

# --- 4. CONCLUIR E ENTREGAR A QUEST (Recompensas de XP e Itens) ---
func complete_and_turn_in_quest(player: Node3D, quest_id: String) -> void:
	if not player or not "client_active_quests" in player:
		return

	var quest_index = -1
	var quest_entry = {}
	
	for i in range(player.client_active_quests.size()):
		if player.client_active_quests[i]["id"] == quest_id:
			quest_index = i
			quest_entry = player.client_active_quests[i]
			break

	if quest_index == -1:
		print("[QUEST] Erro: Quest '%s' não encontrada nas ativas do player para entrega." % quest_id)
		return

	if not quest_entry.get("completed", false):
		print("[QUEST] Tentou entregar a quest '%s', mas ela ainda não está concluída!" % quest_id)
		return

	var quest_data: QuestData = null
	for key in quests_database.keys():
		if key.to_lower() == quest_id.to_lower():
			quest_data = quests_database[key]
			break

	# 1. Remove das ativas e adiciona nas concluídas do player
	player.client_active_quests.remove_at(quest_index)
	if "completed_quests" in player and not player.completed_quests.has(quest_id):
		player.completed_quests.append(quest_id)

	# 2. Concede Recompensa de Experiência (XP)
	var reward_xp = quest_data.reward_xp if quest_data else int(quest_entry.get("reward_xp", 50))
	if reward_xp > 0 and player.has_method("add_experience"):
		player.add_experience(reward_xp)
		print("[RECOMPENSA] +", reward_xp, " XP concedidos.")

	# 3. Concede Recompensa de Item (Como a Espada de Ferro do Tutorial!)
	if quest_data and quest_data.reward_item and quest_data.reward_item_amount > 0:
		if player.has_method("add_item_to_inventory"):
			player.add_item_to_inventory(quest_data.reward_item, quest_data.reward_item_amount)
			print("[RECOMPENSA] Item adicionado ao inventário: ", quest_data.reward_item.name)

	print("[QUEST!] Quest '%s' entregue com sucesso!" % quest_id)
	
	if player.has_method("update_quest_tracker_ui"):
		player.update_quest_tracker_ui()
	if player.has_method("populate_quest_log_ui"):
		player.populate_quest_log_ui()

# --- GERAÇÃO DAS 6 MISSÕES DO QUADRO (5 Procedurais + 1 Principal) ---
func generate_board_quests() -> void:
	board_quests.clear()
	
	var possible_targets = ["Orc Guerreiro", "Goblin Errante", "Aranha"]
	var verbs = ["Caçar", "Expurgar", "Eliminar ameaças de"]
	
	for i in range(5):
		var target = possible_targets[randi() % possible_targets.size()]
		var amount = randi_range(5, 12)
		var gold_reward = amount * 15
		var xp_reward = amount * 25
		
		var quest = {
			"id": "bounty_%d_%d_%d" % [i, Time.get_ticks_msec(), randi()],
			"title": "%s %d %s" % [verbs[randi() % verbs.size()], amount, target],
			"description": "Ajude a guilda eliminando criaturas na região. Derrote %d %ss." % [amount, target],
			"target_enemy": target,
			"required": amount,
			"current": 0,
			"reward_xp": xp_reward,
			"reward_gold": gold_reward,
			"is_main_story": false,
			"accepted": false,
			"turned_in": false,
			"completed": false
		}
		board_quests.append(quest)
	
	var main_quest = _get_main_story_by_progress(main_story_progress)
	if not main_quest.is_empty():
		board_quests.append(main_quest)
	else:
		var target = possible_targets[randi() % possible_targets.size()]
		var amount = randi_range(5, 12)
		var extra_bounty = {
			"id": "bounty_extra_%d_%d" % [Time.get_ticks_msec(), randi()],
			"title": "Patrulha: Caçar %d %s" % [amount, target],
			"description": "Elimine ameaças extras na região. Derrote %d %ss." % [amount, target],
			"target_enemy": target,
			"required": amount,
			"current": 0,
			"reward_xp": amount * 25,
			"reward_gold": amount * 15,
			"is_main_story": false,
			"accepted": false,
			"turned_in": false,
			"completed": false
		}
		board_quests.append(extra_bounty)

func _get_main_story_by_progress(step: int) -> Dictionary:
	var q_id = "main_story_%d" % step
	if quests_database.has(q_id):
		var q_data: QuestData = quests_database[q_id]
		return {
			"id": q_id,
			"title": q_data.title,
			"description": q_data.description,
			"target_enemy": q_data.target_id if "target_id" in q_data else "",
			"required": q_data.required_amount if "required_amount" in q_data else 1,
			"current": 0,
			"reward_xp": q_data.reward_xp,
			"reward_gold": q_data.reward_gold if "reward_gold" in q_data else 50,
			"is_main_story": true,
			"accepted": false,
			"turned_in": false,
			"completed": false
		}
	return {}

func try_refresh_board(player: Node3D) -> bool:
	if not player or not "client_active_quests" in player:
		return false

	for active_q in player.client_active_quests:
		if not active_q.get("completed", false):
			return false

	main_story_progress += 1
	generate_board_quests()
	sync_board_with_player(player)
	return true

func sync_board_with_player(player: Node3D) -> void:
	if board_quests.is_empty():
		generate_board_quests()
		
	if not player:
		return

	for b in board_quests:
		if "client_active_quests" in player:
			for active_q in player.client_active_quests:
				if active_q["id"] == b["id"]:
					b["accepted"] = true
					b["completed"] = active_q.get("completed", false)
					
		if "completed_quests" in player and player.completed_quests.has(b["id"]):
			b["accepted"] = true
			b["turned_in"] = true

# --- PERSISTÊNCIA UNIFICADA DENTRO DO SAVE DO PLAYER ---
func save_quest_board_data(player_name: String, account_data: Dictionary) -> void:
	# Embuti os dados do quadro diretamente no dicionário principal da conta do player!
	account_data["quest_board_data"] = {
		"main_story_progress": main_story_progress,
		"board_quests": board_quests
	}

func load_quest_board_data_from_json(json_data: Dictionary) -> void:
	# Lê os dados do quadro diretamente de dentro do save unificado do player
	var board_data = json_data.get("quest_board_data", null)
	if board_data is Dictionary:
		main_story_progress = int(board_data.get("main_story_progress", 1))
		board_quests = board_data.get("board_quests", [])
	else:
		main_story_progress = 1
		generate_board_quests()
		
	if board_quests.is_empty():
		generate_board_quests()
