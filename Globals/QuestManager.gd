extends Node

var quests_database: Dictionary = {}
var village_bounties: Array = [] # Armazena os 6 contratos gerados da Vila para persistência

var main_story_progress: int = 1

func _ready() -> void:
	_load_quests_from_directory("res://Resources/Quests/")
	generate_initial_village_bounties()
	print("[QUEST MANAGER] Inicializado com sucesso.")

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

# --- GERAÇÃO DOS 6 CONTRATOS DA VILA (Misturando Caçada e Coleta) ---
func _get_rarity_from_level(lvl: int) -> int:
	if lvl <= 20:
		return ItemData.Rarity.COMMON
	elif lvl <= 50:
		return ItemData.Rarity.UNCOMMON
	elif lvl <= 100:
		return ItemData.Rarity.RARE
	elif lvl <= 150:
		return ItemData.Rarity.EPIC
	return ItemData.Rarity.LEGENDARY

func _scan_tres_recursive(dir_path: String, results: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan_tres_recursive(dir_path.path_join(file_name), results)
		elif file_name.ends_with(".tres"):
			results.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

func _get_bounty_monsters() -> Array[Dictionary]:
	var paths: Array[String] = []
	_scan_tres_recursive("res://Resources/SpawnEntries", paths)
	var monsters: Array[Dictionary] = []
	for p in paths:
		var entry = load(p)
		if entry and "monster_name" in entry and entry.monster_name != "":
			var min_lvl: int = int(entry.min_level) if "min_level" in entry else 1
			var max_lvl: int = int(entry.max_level) if "max_level" in entry else min_lvl
			monsters.append({
				"name": entry.monster_name,
				"min_level": min_lvl,
				"max_level": max_lvl,
				"rarity": _get_rarity_from_level(max_lvl)
			})
	return monsters

func _get_bounty_items() -> Array[Dictionary]:
	var folders = [
		{"path": "res://Resources/Items/6 - Drops", "default_rarity": ItemData.Rarity.UNCOMMON, "check_special": true},
		{"path": "res://Resources/Items/5 - BasePocoes", "default_rarity": ItemData.Rarity.RARE, "check_special": false},
		{"path": "res://Resources/Items/4 - Tabuas", "default_rarity": ItemData.Rarity.RARE, "check_special": false},
		{"path": "res://Resources/Items/1 - Barras", "default_rarity": ItemData.Rarity.RARE, "check_special": false}
	]
	var items: Array[Dictionary] = []
	for folder in folders:
		var paths: Array[String] = []
		_scan_tres_recursive(folder["path"], paths)
		for p in paths:
			var item_res = load(p) as ItemData
			if not item_res:
				continue
			var rarity: int = folder["default_rarity"]
			if folder["check_special"]:
				var fname = p.get_file()
				if "Dragao" in fname:
					rarity = ItemData.Rarity.EPIC
				elif "Essencia_Eterea" in fname or "Po_Estrela" in fname:
					rarity = ItemData.Rarity.LEGENDARY
			items.append({
				"name": item_res.name if item_res.name != "" else p.get_file().get_basename(),
				"path": p,
				"rarity": rarity,
				"is_drop": folder["check_special"]
			})
	return items

func _get_player_level() -> int:
	var player = get_tree().get_first_node_in_group("Player")
	if player and "player_level" in player:
		return max(1, int(player.player_level))
	return 1

func _pick_monster_for_level(possible_monsters: Array[Dictionary], min_lvl: int, max_lvl: int) -> Dictionary:
	var filtered: Array[Dictionary] = []
	for m in possible_monsters:
		if m["max_level"] >= min_lvl and m["min_level"] <= max_lvl:
			filtered.append(m)
	if not filtered.is_empty():
		return filtered[randi() % filtered.size()]
	return possible_monsters[randi() % possible_monsters.size()]

func _create_random_village_bounty(id_prefix: String, player_level: int = 1, is_challenge: bool = false) -> Dictionary:
	var possible_monsters = _get_bounty_monsters()
	var possible_items = _get_bounty_items()

	var quest_type_roll = randi() % 2
	if quest_type_roll == 1 and possible_items.is_empty():
		quest_type_roll = 0
	elif quest_type_roll == 0 and possible_monsters.is_empty():
		quest_type_roll = 1

	if quest_type_roll == 0 and not possible_monsters.is_empty():
		var target_min: int = max(1, player_level + 6) if is_challenge else max(1, player_level - 5)
		var target_max: int = (player_level + 20) if is_challenge else (player_level + 5)
		var m = _pick_monster_for_level(possible_monsters, target_min, target_max)
		var amount = randi_range(5, 12)
		var rarity: int = m["rarity"]
		var rarity_mult: int = rarity + 1
		var avg_level: int = int((m["min_level"] + m["max_level"]) / 2.0)
		var xp_per_monster: int = 15 + avg_level * 8
		return {
			"id": "village_hunt_%s_%d" % [id_prefix, randi()],
			"title": "Caçada" if not is_challenge else "Caçada (Desafio)",
			"description": "Elimine %d %s (Nv. %d-%d) na região para garantir a segurança da vila." % [amount, m["name"], m["min_level"], m["max_level"]],
			"target_ids": [m["name"]],
			"required": amount,
			"current": 0,
			"reward_xp": amount * xp_per_monster,
			"reward_gold_value_in_bronze": amount * 25 * rarity_mult,
			"rarity": rarity,
			"turn_in_npc": "",
			"quest_type": 0, # KILL_MONSTERS
			"accepted": false,
			"completed": false,
			"turned_in": false
		}
	elif not possible_items.is_empty():
		var item_info = possible_items[randi() % possible_items.size()]
		var amount = randi_range(3, 8)
		var rarity: int = item_info["rarity"]
		var rarity_mult: int = rarity + 1
		var quest_title: String = "Mãos Leves" if item_info.get("is_drop", false) else "Coleta"
		var xp_per_item: int = (25 + player_level * 3) * rarity_mult
		return {
			"id": "village_gather_%s_%d" % [id_prefix, randi()],
			"title": quest_title,
			"description": "Colete %d unidades de %s e traga para o quadro de suprimentos." % [amount, item_info["name"]],
			"target_ids": [item_info["path"]],
			"required": amount,
			"current": 0,
			"reward_xp": amount * xp_per_item,
			"reward_gold_value_in_bronze": amount * 35 * rarity_mult,
			"rarity": rarity,
			"turn_in_npc": "",
			"quest_type": 1, # COLLECT_ITEMS
			"accepted": false,
			"completed": false,
			"turned_in": false
		}
	return {}

func generate_initial_village_bounties() -> void:
	if not village_bounties.is_empty():
		return

	var p_level: int = _get_player_level()
	village_bounties.clear()
	for i in range(6):
		var is_challenge: bool = i >= 4 # 4 na faixa do jogador, 2 de desafio
		var q = _create_random_village_bounty(str(i), p_level, is_challenge)
		if not q.is_empty():
			village_bounties.append(q)

func shuffle_village_bounties() -> void:
	var p_level: int = _get_player_level()
	if village_bounties.is_empty():
		generate_initial_village_bounties()
		return

	for i in range(village_bounties.size()):
		var b = village_bounties[i]
		# Mantém contratos que o jogador já aceitou e ainda não entregou
		if b.get("accepted", false) and not b.get("turned_in", false):
			continue
		var is_challenge: bool = i >= 4
		var q = _create_random_village_bounty("%d_%d" % [i, Time.get_ticks_msec()], p_level, is_challenge)
		if not q.is_empty():
			village_bounties[i] = q
	get_tree().call_group("NPCs", "update_visual_quest_status")

func _replace_completed_village_bounty(index: int) -> void:
	var p_level: int = _get_player_level()
	var is_challenge: bool = index >= 4
	var q = _create_random_village_bounty(str(Time.get_ticks_msec()), p_level, is_challenge)
	if not q.is_empty():
		village_bounties[index] = q

func assign_quest(player: Node, quest_id: String) -> void:
	if not player or not "client_active_quests" in player:
		return

	# Verifica se é uma quest da vila (dicionário) ou da história (.tres)
	var quest_dict = {}
	for b in village_bounties:
		if b["id"] == quest_id:
			quest_dict = b
			break

	if not quest_dict.is_empty():
		for q in player.client_active_quests:
			if q.get("id") == quest_id:
				return
		var copy = quest_dict.duplicate()
		copy["accepted"] = true
		player.client_active_quests.append(copy)
		quest_dict["accepted"] = true
		print("[QUEST] Contrato da Vila aceito: ", copy["title"])
	else:
		# É missão principal (.tres)
		for q in player.client_active_quests:
			if q.get("id") == quest_id:
				return
		if "completed_quests" in player and player.completed_quests.has(quest_id):
			return

		var quest_data: QuestData = quests_database.get(quest_id, null)
		if not quest_data:
			return

		var new_quest = {
			"id": quest_id,
			"title": quest_data.title,
			"description": quest_data.description,
			"target_ids": quest_data.target_ids,
			"required": quest_data.required_amount,
			"current": 0,
			"reward_xp": quest_data.reward_xp,
			"reward_gold_value_in_bronze": quest_data.reward_gold_value_in_bronze,
			"turn_in_npc": quest_data.turn_in_npc_id,
			"quest_type": quest_data.quest_type,
			"accepted": true,
			"completed": false
		}
		player.client_active_quests.append(new_quest)
		print("[QUEST] Missão Principal aceita: ", quest_data.title)

	if player.has_method("update_quest_tracker_ui"):
		player.update_quest_tracker_ui()
	get_tree().call_group("NPCs", "update_visual_quest_status")

# --- PROGRESSO (Monstros, NPCs, Inventário) ---
func on_monster_killed(player: Node, monster_name: String) -> void:
	if not player or not "client_active_quests" in player:
		return

	for q in player.client_active_quests:
		if q.get("completed", false):
			continue
		var targets = q.get("target_ids", [])
		for t in targets:
			if t != "" and t.to_lower() in monster_name.to_lower():
				q["current"] = min(int(q.get("required", 1)), int(q.get("current", 0)) + 1)
				if int(q.get("current", 0)) >= int(q.get("required", 1)):
					q["completed"] = true
				break

	# Atualiza também nos contratos da vila ativos
	for b in village_bounties:
		if b["accepted"] and not b.get("completed", false):
			for t in b.get("target_ids", []):
				if t.to_lower() in monster_name.to_lower():
					b["current"] = min(b["required"], b["current"] + 1)
					if b["current"] >= b["required"]:
						b["completed"] = true
					break

	if player.has_method("update_quest_tracker_ui"):
		player.update_quest_tracker_ui()
	get_tree().call_group("NPCs", "update_visual_quest_status")

func on_npc_talked(player: Node, npc_id: String) -> void:
	if not player or not "client_active_quests" in player:
		return

	for q in player.client_active_quests:
		if q.get("completed", false):
			continue
			
		var target_ids = q.get("target_ids", [])
		# Se o ID do NPC conversado está nos alvos desta missão
		if npc_id in target_ids:
			if not q.has("talked_npcs"):
				q["talked_npcs"] = []
			
			# Adiciona o NPC à lista de conversados se ainda não foi computado
			if not npc_id in q["talked_npcs"]:
				q["talked_npcs"].append(npc_id)
			
			var total_required = max(int(q.get("required", 1)), target_ids.size())
			q["current"] = q["talked_npcs"].size()
			
			# Só marca como concluída quando visitar todos os NPCs exigidos
			if q["current"] >= total_required:
				q["completed"] = true

	if player.has_method("update_quest_tracker_ui"):
		player.update_quest_tracker_ui()
	get_tree().call_group("NPCs", "update_visual_quest_status")
	if player.has_method("populate_quest_log_ui"):
		player.populate_quest_log_ui()
	get_tree().call_group("NPCs", "update_visual_quest_status")

# --- CONCLUIR E ENTREGAR (Com Sistema de Moedas de Ouro, Prata e Bronze) ---
func complete_and_turn_in_quest(player: Node, quest_id: String) -> void:
	if not player or not "client_active_quests" in player:
		return

	var quest_index = -1
	var quest_entry = {}
	
	for i in range(player.client_active_quests.size()):
		if player.client_active_quests[i]["id"] == quest_id:
			quest_index = i
			quest_entry = player.client_active_quests[i]
			break

	if quest_index == -1 or not quest_entry.get("completed", false):
		return

	# Verifica se é uma quest da vila ou principal para pegar a recompensa correta
	var reward_xp = int(quest_entry.get("reward_xp", 50))
	var reward_bronze_total = int(quest_entry.get("reward_gold_value_in_bronze", 0))
	
	var quest_data: QuestData = quests_database.get(quest_id, null)
	if quest_data:
		reward_xp = quest_data.reward_xp
		reward_bronze_total = quest_data.reward_gold_value_in_bronze

	# 1. Remove das ativas do player e marca concluída
	player.client_active_quests.remove_at(quest_index)
	if not player.completed_quests.has(quest_id):
		player.completed_quests.append(quest_id)
	
	sync_main_story_progress(player)

	# Se for contrato da vila, marca como turned_in e regenera um novo no lugar para manter 6
	for i in range(village_bounties.size()):
		if village_bounties[i]["id"] == quest_id:
			village_bounties[i]["turned_in"] = true
			_replace_completed_village_bounty(i)
			break

	# 2. Concede XP
	if reward_xp > 0 and player.has_method("add_experience"):
		player.add_experience(reward_xp)

	# 3. CONVERSÃO DE MOEDAS (1 Ouro = 100 Prata = 10000 Bronze / Ajuste conforme sua proporção)
	# Assumindo: 1 Prata = 100 Bronze | 1 Ouro = 100 Prata (10.000 Bronze)
	if reward_bronze_total > 0 and player.has_method("add_item_to_inventory"):
		var gold_coins = int(reward_bronze_total / 10000)
		var remainder = reward_bronze_total % 10000
		var silver_coins = int(remainder / 100)
		var bronze_coins = remainder % 100

		if gold_coins > 0:
			var item_gold = load("res://Resources/Items/Moeda_Ouro_1.tres")
			if item_gold: player.add_item_to_inventory(item_gold, gold_coins)
		if silver_coins > 0:
			var item_silver = load("res://Resources/Items/Moeda_Prata_1.tres")
			if item_silver: player.add_item_to_inventory(item_silver, silver_coins)
		if bronze_coins > 0:
			var item_bronze = load("res://Resources/Items/Moeda_Bronze_1.tres")
			if item_bronze: player.add_item_to_inventory(item_bronze, bronze_coins)

	print("[QUEST!] Quest '%s' entregue com sucesso!" % quest_id)
	if player.has_method("update_quest_tracker_ui"):
		player.update_quest_tracker_ui()
	get_tree().call_group("NPCs", "update_visual_quest_status")
	get_tree().call_group("NPCs", "update_visual_quest_status")

# Calcula em qual missão principal o jogador está com base nas concluídas
func sync_main_story_progress(player: Node) -> void:
	if not player or not "completed_quests" in player:
		return

	var step: int = 1
	while quests_database.has("main_story_%d" % step):
		if player.completed_quests.has("main_story_%d" % step):
			step += 1
		else:
			break

	main_story_progress = step
	print("[QUEST MANAGER] Progresso da história principal sincronizado no passo: ", main_story_progress)
