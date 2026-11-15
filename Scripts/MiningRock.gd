class_name MiningRock
extends GatherableProp

@export_category("Configuração de Mineração da Pedra")
@export var mineral_mappings: Array[Dictionary] = [
	# Exemplo de preenchimento no Inspetor:
	# {"node_path": NodePath("Minerais/Mineral_Bronze"), "item_data": preload("res://Resources/Items/Moeda_Bronze.tres")}
]

# Variável que o PropSpawner pode definir ao instanciar se quiser forçar um minério específico
var forced_mineral_index: int = -1

func _ready() -> void:
	super._ready() # Executa o _ready() do GatherableProp (área de interação, prompt 'E', etc.)
	
	setup_random_or_forced_mineral()

func setup_random_or_forced_mineral() -> void:
	if mineral_mappings.is_empty():
		return

	# 1. Esconde todos os minerais filhos da pedra primeiro
	for mapping in mineral_mappings:
		var node_path = mapping.get("node_path", NodePath())
		if not node_path.is_empty():
			var node = get_node_or_null(node_path)
			if node and node is Node3D:
				node.visible = false

	# 2. Escolhe qual índice usar (por sorteio aleatório ou forçado pelo spawner)
	var chosen_index = forced_mineral_index
	if chosen_index < 0 or chosen_index >= mineral_mappings.size():
		chosen_index = randi() % mineral_mappings.size()

	# 3. Pega o mapeamento escolhido
	var selected_mapping = mineral_mappings[chosen_index]
	var target_path = selected_mapping.get("node_path", NodePath())
	var assigned_item = selected_mapping.get("item_data", null) as ItemData

	# 4. Ativa apenas o modelo 3D do minério sorteado
	if not target_path.is_empty():
		var active_node = get_node_or_null(target_path)
		if active_node and active_node is Node3D:
			active_node.visible = true
			
	# 5. Define automaticamente o ItemData que o player vai receber ao minerar
	if assigned_item:
		item_to_give = assigned_item
