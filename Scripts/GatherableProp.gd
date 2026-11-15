class_name GatherableProp
extends Node3D

@export_category("Configuração de Coleta")
@export var item_to_give: ItemData        # O ItemData que o player vai receber
@export var gathering_animation: String = "Armature|Pegando" # Animação no AnimationTree
@export var gathering_health: int = 1      # Quantas vezes pode ser coletado antes de sumir (ex: Galho = 1, Árvore = 5)

@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_prompt: Node3D = $InteractionPrompt

var player_in_range: CharacterBody3D = null
var spawner_reference: Node3D = null # Referência ao spawner que criou este prop

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_player_entered)
		interaction_area.body_exited.connect(_on_player_exited)
		
	if interaction_prompt:
		interaction_prompt.visible = false

func interact(player_node: CharacterBody3D) -> void:
	if not player_node or global_position.distance_to(player_node.global_position) > 4.5:
		return

	if not item_to_give:
		print("[GATHERING] Erro: Nenhum ItemData configurado!")
		return

	if player_node.has_method("gathering"):
		player_node.gathering(item_to_give, gathering_animation)
		
		# Reduz a durabilidade/vida do prop
		gathering_health -= 1
		print("[GATHERING] Restam %d coletas neste prop." % gathering_health)
		
		# Feedback visual ou sonoro de golpe/coleta parcial se desejar aqui...

		# Se a vida do prop esgotou, ele é destruído
		if gathering_health <= 0:
			if is_instance_valid(interaction_prompt):
				interaction_prompt.visible = false
				
			# Notifica o spawner de que este prop foi destruído para gatilho de respawn
			if spawner_reference and spawner_reference.has_method("on_prop_destroyed"):
				spawner_reference.on_prop_destroyed()
				
			queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("Interagir"):
		interact(player_in_range)
		get_viewport().set_input_as_handled()

func _on_player_entered(body: Node3D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		player_in_range = body
		if interaction_prompt:
			interaction_prompt.visible = true

func _on_player_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
		if interaction_prompt:
			interaction_prompt.visible = false
