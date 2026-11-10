class_name NpcValkor
extends NpcBase

@export_category("Missões do Tutorial")
@export var first_quest: QuestData
@export var second_quest: QuestData

func handle_npc_interaction(player: CharacterBody3D) -> void:
	var q1_id = first_quest.quest_id if first_quest else ""
	var q2_id = second_quest.quest_id if second_quest else ""

	# --- 1. TRATAMENTO DA PRIMEIRA QUEST ---
	if q1_id != "" and not player.completed_quests.has(q1_id):
		if player.active_quests.has(q1_id):
			var entry = player.active_quests[q1_id]
			# Se já está concluída (pronta para entregar), entrega a recompensa e o item!
			if entry.get("completed", false):
				QuestManager.complete_and_turn_in_quest(player, q1_id)
				open_dialogue(npc_name, "Excelente! Você concluiu a primeira tarefa. Aqui está sua recompensa!")
			else:
				# Se ainda está em Andamento (caso seja de matar monstros ou coletar)
				open_dialogue(npc_name, "Você ainda não concluiu a missão: %s" % first_quest.title)
		else:
			# Se o player ainda não tem a quest, atribui ela agora
			QuestManager.assign_quest(player, q1_id)
			
			# Se a quest for do tipo TALK_TO_NPC, ela se conclui no mesmo instante da conversa!
			if first_quest.quest_type == QuestData.QuestType.TALK_TO_NPC:
				QuestManager.on_npc_talked(player, npc_id)
				# Como concluiu na hora, já chamamos a entrega para dar a recompensa e o item já no primeiro papo
				QuestManager.complete_and_turn_in_quest(player, q1_id)
				open_dialogue(npc_name, "Saudações, aventureiro! \n%s\n\nMissão concluída! Tome sua espada de ferro." % first_quest.description)
			else:
				open_dialogue(npc_name, "Saudações, aventureiro! \n%s" % first_quest.description)
		return

	# --- 2. TRATAMENTO DA SEGUNDA QUEST (Só libera se a primeira foi concluída) ---
	if q2_id != "" and player.completed_quests.has(q1_id):
		if not player.completed_quests.has(q2_id):
			if player.active_quests.has(q2_id):
				var entry = player.active_quests[q2_id]
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
