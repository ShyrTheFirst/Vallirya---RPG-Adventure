class_name QuestData
extends Resource

enum QuestType { KILL_MONSTERS, COLLECT_ITEMS, TALK_TO_NPC }

@export var quest_id: String = "quest_01"
@export var title: String = "Limpeza na Floresta"
@export_multiline var description: String = "Derrote 5 Orcs na floresta inicial."
@export var quest_type: QuestType = QuestType.KILL_MONSTERS

# Requisitos
@export var target_id: String = "Orc" # Nome do monstro ou resource_path do item
@export var required_amount: int = 5

# Recompensas
@export var reward_xp: int = 250
@export var reward_item: ItemData = null
@export var reward_item_amount: int = 1
