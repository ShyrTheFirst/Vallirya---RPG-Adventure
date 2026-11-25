class_name MiningRock
extends GatherableProp

const T1_MINERIO_LATAO: ItemData = preload("uid://blfaim5yty8ht")
const T2_MINERIO_BRONZE: ItemData = preload("uid://cwauw6d5qa763")
const T3_MINERIO_PRATA: ItemData = preload("uid://duiwvns1nqfy7")
const T4_MINERIO_OURO: ItemData = preload("uid://cdn1wjptk6sm3")
const T5_MINERIO_PLACADRACO: ItemData = preload("uid://dnhdvds0yrptq")
const T6_MINERIO_CELESTIAL: ItemData = preload("uid://bueniuanx367f")

const MINERAL_TIERS: Array[Dictionary] = [
	{"node_name": "Mineral_Latao", "item": T1_MINERIO_LATAO},
	{"node_name": "Mineral_Bronze", "item": T2_MINERIO_BRONZE},
	{"node_name": "Mineral_Prata", "item": T3_MINERIO_PRATA},
	{"node_name": "Mineral_Ouro", "item": T4_MINERIO_OURO},
	{"node_name": "Mineral_Placadraco", "item": T5_MINERIO_PLACADRACO},
	{"node_name": "Mineral_Celestial", "item": T6_MINERIO_CELESTIAL},
]

# Variável que o PropSpawner define ao instanciar (0=Latão, 1=Bronze, 2=Prata, 3=Ouro, 4=Placadraco, 5=Celestial)
var forced_mineral_index: int = -1

func _ready() -> void:
	gathering_animation = "Armature|Minerar"
	if required_tool == "auto":
		required_tool = "pickaxe"
	super._ready()
	setup_mineral()

func setup_mineral() -> void:
	var minerais_root: Node3D = get_node_or_null("Minerais") as Node3D
	if not minerais_root:
		return

	# 1. Esconde todos os nós Node3D dentro de Minerais
	for child in minerais_root.get_children():
		if child is Node3D:
			child.visible = false

	# 2. Escolhe o índice (forçado pelo PropSpawner ou aleatório entre os disponíveis)
	var chosen_index: int = forced_mineral_index
	if chosen_index < 0 or chosen_index >= MINERAL_TIERS.size():
		chosen_index = randi() % MINERAL_TIERS.size()

	var tier_data: Dictionary = MINERAL_TIERS[chosen_index]
	var target_node: Node3D = minerais_root.get_node_or_null(tier_data["node_name"]) as Node3D

	# 3. Torna visível apenas o mineral escolhido e define o ItemData correspondente
	if target_node:
		target_node.visible = true
	item_to_give = tier_data["item"]
