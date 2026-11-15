class_name CraftData
extends Resource

@export_category("Classificação do Craft")
@export var equipment_type: String = "armadura" # Ex: "armadura", "elmo", "bota", "arma", "cajado"
@export var recipe_level: int = 1               # Nível do item (1 a 10)

@export_category("Ingredientes de Entrada")
@export var input_item_1: ItemData
@export var input_quantity_1: int = 1

@export var input_item_2: ItemData 
@export var input_quantity_2: int = 0

@export_category("Resultado do Craft")
@export var result_item: ItemData
@export var result_quantity: int = 1
