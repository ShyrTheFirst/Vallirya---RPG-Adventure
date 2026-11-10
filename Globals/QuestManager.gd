extends Node

# Dicionário central de todas as quests do jogo carregadas por ID
# Ex: "quest_tutorial": QuestData (recurso .tres)
var quests_database: Dictionary = {}

func _ready() -> void:
	# Carrega automaticamente os recursos de missões da pasta de quests (ajuste o caminho se necessário)
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
	else:
		# Fallback caso a pasta não exista ou usemos carregamento manual via preload
		print("[QUEST MANAGER] Aviso: Pasta de quests não encontrada em %s. Usando registro manual se necessário." % path)

# --- 1. ATRIBUIR UMA QUEST AO JOGADOR ---
func assign_quest(player: Node3D, quest_id: String) -> void:
	if not player or not "active_quests" in player:
		return

	if player.active_quests.has(quest_id) or (player.completed_quests is Array and player.completed_quests.has(quest_id)):
		return

	# Se a quest não estiver no banco dinâmico, você pode definir fallback ou carregar direto
	var quest_data: QuestData = quests_database.get(quest_id, null)
	if not quest_data:
		print("[QUEST MANAGER] Erro: Quest ID '%s' não foi encontrada no banco de dados!" % quest_id)
		return

	# Adiciona ao dicionário de missões ativas do player
	player.active_quests[quest_id] = {
		"title": quest_data.title,
		"description": quest_data.description,
		"current": 0,
		"required": quest_data.required_amount,
		"completed": false
	}

	print("[QUEST] Missão aceita: ", quest_data.title)
	_update_player_quest_hud(player)

# --- 2. PROGRESSO: MONSTRO DERROTADO ---
func on_monster_killed(player: Node3D, monster_name: String) -> void:
	if not player or not "active_quests" in player:
		return

	for q_id in player.active_quests.keys():
		var quest_entry = player.active_quests[q_id]
		if quest_entry.get("completed", false):
			continue

		var quest_data: QuestData = quests_database.get(q_id, null)
		if quest_data and quest_data.quest_type == QuestData.QuestType.KILL_MONSTERS:
			# Compara se o alvo bate com o monstro derrotado
			if quest_data.target_id.to_lower() in monster_name.to_lower():
				quest_entry["current"] = min(quest_data.required_amount, quest_entry["current"] + 1)
				
				if quest_entry["current"] >= quest_data.required_amount:
					quest_entry["completed"] = true
					print("[QUEST] Objetivo alcançado! Pronto para entregar: ", quest_data.title)

				_update_player_quest_hud(player)

# --- 3. PROGRESSO: CONVERSA COM NPC ---
func on_npc_talked(player: Node3D, npc_id: String) -> void:
	if not player or not "active_quests" in player:
		return

	for q_id in player.active_quests.keys():
		var quest_entry = player.active_quests[q_id]
		if quest_entry.get("completed", false):
			continue

		var quest_data: QuestData = quests_database.get(q_id, null)
		if quest_data and quest_data.quest_type == QuestData.QuestType.TALK_TO_NPC:
			if quest_data.target_id == npc_id:
				quest_entry["current"] = quest_data.required_amount
				quest_entry["completed"] = true
				print("[QUEST] Conversa concluída! Pronto para entregar: ", quest_data.title)
				_update_player_quest_hud(player)

# --- 4. PROGRESSO: INVENTÁRIO / COLETA DE ITENS ---
func on_inventory_updated(player: Node3D) -> void:
	if not player or not "active_quests" in player or not "inventory_items" in player:
		return

	for q_id in player.active_quests.keys():
		var quest_entry = player.active_quests[q_id]
		if quest_entry.get("completed", false):
			continue

		var quest_data: QuestData = quests_database.get(q_id, null)
		if quest_data and quest_data.quest_type == QuestData.QuestType.COLLECT_ITEMS:
			# Conta quantos itens com o resource_path ou ID alvo o player possui
			var count = 0
			for slot in player.inventory_items:
				if slot != null and slot is Dictionary:
					var item: ItemData = slot.get("item", null)
					if item and (item.id == quest_data.target_id or item.resource_path == quest_data.target_id):
						count += slot.get("amount", 1)

			quest_entry["current"] = min(quest_data.required_amount, count)
			if quest_entry["current"] >= quest_data.required_amount:
				quest_entry["completed"] = true
				print("[QUEST] Itens coletados com sucesso! Pronto para entregar: ", quest_data.title)

			_update_player_quest_hud(player)

# --- 5. CONCLUIR E ENTREGAR A QUEST ---
func complete_and_turn_in_quest(player: Node3D, quest_id: String) -> void:
	if not player or not "active_quests" in player:
		return

	if not player.active_quests.has(quest_id):
		return

	var quest_entry = player.active_quests[quest_id]
	if not quest_entry.get("completed", false):
		return

	var quest_data: QuestData = quests_database.get(quest_id, null)
	if not quest_data:
		return

	# 1. Remove das ativas e adiciona nas concluídas
	player.active_quests.erase(quest_id)
	if not player.completed_quests.has(quest_id):
		player.completed_quests.append(quest_id)

	# 2. Concede as recompensas de XP
	if quest_data.reward_xp > 0 and player.has_method("add_experience"):
		player.add_experience(quest_data.reward_xp)

	# 3. CONcede a recompensa de ITEM (Corrigido aqui!)
	if quest_data.reward_item and quest_data.reward_item_amount > 0:
		if player.has_method("add_item_to_inventory"):
			player.add_item_to_inventory(quest_data.reward_item, quest_data.reward_item_amount)
			print("[QUEST] Item de recompensa adicionado ao inventário: ", quest_data.reward_item.name)

	print("[QUEST!] Recompensas entregues com sucesso para a missão: ", quest_data.title)
	_update_player_quest_hud(player)

# Atualiza visualmente o rastreador de missões na tela do player
func _update_player_quest_hud(player: Node3D) -> void:
	# Converte o dicionário de ativas em um Array legível para o HUD do player
	var active_list = []
	for q_id in player.active_quests.keys():
		var q_data = player.active_quests[q_id]
		active_list.append({
			"id": q_id,
			"title": q_data["title"],
			"current": q_data["current"],
			"required": q_data["required"],
			"completed": q_data["completed"]
		})

	# Atualiza a variável local do player e redesenha o tracker
	player.client_active_quests = active_list
	if player.has_method("update_quest_tracker_ui"):
		player.update_quest_tracker_ui()

# Sincroniza o estado das quests ao carregar o save do player
func sync_player_quests(player: Node3D) -> void:
	_update_player_quest_hud(player)
