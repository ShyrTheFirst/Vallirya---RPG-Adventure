class_name MonsterDrop
extends Resource

@export var item_data: ItemData
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.5 # 0.0 (0%) a 1.0 (100%)
