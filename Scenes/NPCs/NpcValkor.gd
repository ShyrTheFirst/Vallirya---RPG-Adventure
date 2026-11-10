class_name NpcValkor
extends NpcBase

@export_category("Missões do Tutorial")
@export var first_quest: QuestData
@export var second_quest: QuestData

func handle_npc_interaction(player: CharacterBody3D) -> void:
	var q1_id = first_quest.quest_id if first_quest else ""
	var q2_id = second_quest.quest_id if second_quest else ""

	# Funções auxiliares para checar o estado no client_active_quests do player
	var has_active_quest = func(qid: String) -> bool:
		for q in player.client_active_quests:
			if q.get("id") == qid:
				return true
		return false

	var get_active_quest_entry = func(qid: String) -> Dictionary:
		for q in player.client_active_quests:
			if q.get("id") == qid:
				return q
		return {}

	# --- 1. TRATAMENTO DA PRIMEIRA QUEST ---
	if q1_id != "" and not player.completed_quests.has(q1_id):
		if has_active_quest.call(q1_id):
			var entry = get_active_quest_entry.call(q1_id)
			if entry.get("completed", false):
				# CHAMA O QUEST MANAGER PARA ENTREGAR XP E O ITEM DE RECOMPENSA (A Espada!)
				QuestManager.complete_and_turn_in_quest(player, q1_id)
				open_dialogue(npc_name, "Excelente trabalho! Tome sua espada de ferro.")
			else:
				open_dialogue(npc_name, "Você ainda não concluiu a missão: %s" % first_quest.title)
		else:
			# Atribui a quest usando exclusivamente o QuestManager
			QuestManager.assign_quest(player, q1_id)
			
			if first_quest.quest_type == QuestData.QuestType.TALK_TO_NPC:
				QuestManager.on_npc_talked(player, npc_id)
				QuestManager.complete_and_turn_in_quest(player, q1_id)
				open_dialogue(npc_name, "Saudações, aventureiro! Tome sua espada de ferro.")
			else:
				open_dialogue(npc_name, "Saudações, aventureiro! \n%s" % first_quest.description)
		return

	# --- 2. TRATAMENTO DA SEGUNDA QUEST ---
	if q2_id != "" and player.completed_quests.has(q1_id):
		if not player.completed_quests.has(q2_id):
			if has_active_quest.call(q2_id):
				var entry = get_active_quest_entry.call(q2_id)
				if entry.get("completed", false):
					QuestManager.complete_and_turn_in_quest(player, q2_id)
					open_dialogue(npc_name, "Incrível! Você concluiu todas as tarefas iniciais do tutorial.")
				else:
					open_dialogue(npc_name, "Continue focado na sua segunda missão: %s" % second_quest.title)
			else:
				QuestManager.assign_quest(player, q2_id)
				if second_quest.quest_type == QuestData.QuestType.TALK_TO_NPC:
					QuestManager.on_npc_talked(player, npc_id)
					QuestManager.complete_and_turn_in_quest(player, q2_id)
				open_dialogue(npc_name, "Agora encare este próximo desafio:\n%s" % second_quest.description)
			return

	# --- 3. TUDO CONCLUÍDO ---
	open_dialogue(npc_name, "Você já completou todo o treinamento inicial por aqui. Visite o Quadro de Missões na praça para novos trabalhos!")
