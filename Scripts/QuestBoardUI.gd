class_name QuestBoard
extends PanelContainer

signal quest_accepted(quest_data: Dictionary)

var available_bounties: Array = []


func generate_random_quests() -> void:
	available_bounties.clear()
	
	var possible_targets = ["Orc Guerreiro", "Goblin", "Aranha"]
	var verbs = ["Caçar", "Expurgar", "Eliminar ameaças de"]
	
	# Gera 3 missões aleatórias para o quadro
	for i in range(3):
		var target = possible_targets[randi() % possible_targets.size()]
		var amount = randi_range(3, 8)
		var gold_reward = amount * 15
		var xp_reward = amount * 25
		
		var quest = {
			"id": "bounty_%d_%d" % [i, Time.get_ticks_msec()],
			"title": "Patrulha: %s %d %ss" % [verbs[randi() % verbs.size()], amount, target],
			"target_enemy": target,
			"required": amount,
			"current": 0,
			"reward_xp": xp_reward,
			"reward_gold": gold_reward,
			"completed": false
		}
		available_bounties.append(quest)
	
	refresh_board_ui()

func refresh_board_ui() -> void:
	# Aqui você atualiza os botões/labels na sua UI do Quadro de Missões
	print("[QUEST BOARD] Missões geradas no quadro:")
	for q in available_bounties:
		print(" - ", q["title"], " (Recompensa: ", q["reward_xp"], " XP)")

func accept_bounty(index: int) -> void:
	if index >= 0 and index < available_bounties.size():
		var quest = available_bounties[index]
		emit_signal("quest_accepted", quest)
		print("[QUEST BOARD] Missão aceita pelo jogador: ", quest["title"])
		available_bounties.remove_at(index)
		refresh_board_ui()

func _on_btn_close_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
