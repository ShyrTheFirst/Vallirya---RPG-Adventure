class_name ItemData
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum ItemType { WEAPON, ARMOR, HELM, BOOTS, CONSUMABLE, MISC }
enum WeaponType { NONE, SWORD, STAFF, AXE }

@export var id: String = ""
@export var name: String = ""
@export var item_type: ItemType = ItemType.MISC
@export var rarity: Rarity = Rarity.COMMON
@export var weapon_type: WeaponType = WeaponType.NONE
@export_multiline var description: String = ""
@export var mesh_scene: PackedScene
@export var sell_price: int = 10

@export_category("Configurações do Ícone 3D (Inventário)")
@export var inventory_rotation: Vector3 = Vector3(0, 0, 0) # Rotação em Graus
@export var inventory_scale: Vector3 = Vector3(1, 1, 1)     # Escala do modelo no ícone
@export var inventory_offset: Vector3 = Vector3(0, 0, 0)    # Deslocamento X, Y, Z

@export var is_stackable: bool = true
@export var max_stack: int = 9999

# Atributos de combate
@export var bonus_attack: int = 0
@export var bonus_defense: int = 0
@export var bonus_hp: int = 0
@export var bonus_mana: int = 0

#Informaçoes de Quest
@export var is_quest_item: bool = false
@export var quest_id: String = "" # Identificador da missão relacionada (ex: "quest_coleta_ferro")

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.8, 0.8, 0.8)       # Branco/Cinza
		Rarity.UNCOMMON: return Color(0.2, 0.8, 0.2)     # Verde
		Rarity.RARE: return Color(0.2, 0.5, 1.0)         # Azul
		Rarity.EPIC: return Color(0.6, 0.2, 0.8)         # Roxo
		Rarity.LEGENDARY: return Color(1.0, 0.6, 0.1)    # Laranja/Lendário
	return Color.WHITE
