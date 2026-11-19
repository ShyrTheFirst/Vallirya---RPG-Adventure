class_name QuestData
extends Resource

enum QuestType { KILL_MONSTERS, COLLECT_ITEMS, TALK_TO_NPC, CRAFT_AND_UPGRADE }

@export var quest_id: String = "quest_01"
@export var title: String = "Título da Missão"
@export_multiline var description: String = "Descrição detalhada do objetivo."
@export var quest_type: QuestType = QuestType.KILL_MONSTERS

@export_category("Requisitos e Alvos Múltiplos")
@export var target_ids: Array[String] = ["Orc"]
@export var required_amount: int = 5

@export_category("Regras de Entrega e NPCs")
@export var start_npc_id: String = "npc_inicial"
@export var turn_in_npc_id: String = "" # Se vazio, entrega no próprio Quadro de Avisos
@export var item_required_to_turn_in: ItemData = null

@export_category("Recompensas (XP e Moedas em Valor Total de Bronze)")
@export var reward_xp: int = 250
@export var reward_gold_value_in_bronze: int = 150 # Ex: 150 moedas de bronze = 1 Prata e 50 Bronze
@export var reward_item: ItemData = null
@export var reward_item_amount: int = 1
@export var transformed_unique_item: ItemData = null
