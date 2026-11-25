class_name CraftData
extends Resource

enum EquipmentType { ARMADURA, ELMO, BOTA, ESPADA, LANCA, MACHADO, CAJADO, BARRAS, TABUAS, OUTROS }

@export_category("Classificação do Craft")
@export var equipment_type: EquipmentType = EquipmentType.ARMADURA
@export var recipe_level: int = 1               # Nível do item (1 a 10)

static func get_equipment_type_key(type: EquipmentType) -> String:
	match type:
		EquipmentType.ARMADURA: return "armadura"
		EquipmentType.ELMO: return "elmo"
		EquipmentType.BOTA: return "bota"
		EquipmentType.ESPADA: return "espada"
		EquipmentType.LANCA: return "lanca"
		EquipmentType.MACHADO: return "machado"
		EquipmentType.CAJADO: return "cajado"
		EquipmentType.BARRAS: return "barras"
		EquipmentType.TABUAS: return "tabuas"
		EquipmentType.OUTROS: return "outros"
	return "outros"

static func get_equipment_type_label(type: EquipmentType) -> String:
	match type:
		EquipmentType.LANCA: return "Lança"
		EquipmentType.BARRAS: return "Barras"
		EquipmentType.TABUAS: return "Tábuas"
		_: return get_equipment_type_key(type).capitalize()

static func matches_equipment_type(item: ItemData, type: EquipmentType) -> bool:
	if not item:
		return false
	match type:
		EquipmentType.ARMADURA:
			return item.item_type == ItemData.ItemType.ARMOR
		EquipmentType.ELMO:
			return item.item_type == ItemData.ItemType.HELM
		EquipmentType.BOTA:
			return item.item_type == ItemData.ItemType.BOOTS
		EquipmentType.ESPADA:
			return item.item_type == ItemData.ItemType.WEAPON and item.weapon_type == ItemData.WeaponType.SWORD
		EquipmentType.LANCA:
			return item.item_type == ItemData.ItemType.WEAPON and item.weapon_type == ItemData.WeaponType.SPEAR
		EquipmentType.MACHADO:
			return item.item_type == ItemData.ItemType.WEAPON and item.weapon_type == ItemData.WeaponType.AXE
		EquipmentType.CAJADO:
			return item.item_type == ItemData.ItemType.WEAPON and item.weapon_type == ItemData.WeaponType.STAFF
		EquipmentType.OUTROS:
			return item.item_type in [ItemData.ItemType.CONSUMABLE, ItemData.ItemType.MISC, ItemData.ItemType.TOOL]
	return false

@export_category("Ingredientes de Entrada")
@export var input_items: Array[ItemData] = []
@export var input_quantities: Array[int] = []

## Retorna a lista de ingredientes válidos no formato [{"item": ItemData, "quantity": int}].
## Se input_quantities não possuir o índice correspondente, considera a quantidade como 1.
func get_ingredients() -> Array[Dictionary]:
	var ingredients: Array[Dictionary] = []
	for i in range(input_items.size()):
		var item: ItemData = input_items[i]
		if not item:
			continue
		var qty: int = input_quantities[i] if i < input_quantities.size() else 1
		if qty > 0:
			ingredients.append({"item": item, "quantity": qty})
	return ingredients

@export_category("Resultado do Craft")
@export var result_item: ItemData
@export var result_quantity: int = 1
