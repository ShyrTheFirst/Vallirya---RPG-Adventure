class_name GatherableProp
extends Node3D

@export_category("Configuração de Coleta")
@export var item_to_give: ItemData        # O ItemData que o player vai receber
@export var gathering_animation: String = "Armature|Pegando" # Animação no AnimationTree
@export var gathering_health: int = 1      # Quantas vezes pode ser coletado antes de sumir (ex: Galho = 1, Árvore = 5)
@export_enum("auto", "none", "axe", "pickaxe") var required_tool: String = "auto" # Ferramenta que aparece na mão
@export var animation_duration: float = 0.7 # Tempo (em segundos) que a animação leva para terminar

@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_prompt: Node3D = $InteractionPrompt

var player_in_range: CharacterBody3D = null
var spawner_reference: Node3D = null # Referência ao spawner que criou este prop
var is_being_gathered: bool = false  # Evita cliques duplos enquanto a animação roda neste prop

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_player_entered)
		interaction_area.body_exited.connect(_on_player_exited)
		
	if interaction_prompt:
		interaction_prompt.visible = false

func interact(player_node: CharacterBody3D) -> void:
	if is_being_gathered or gathering_health <= 0:
		return

	if not player_node or global_position.distance_to(player_node.global_position) > 4.5:
		return

	if not item_to_give:
		print("[GATHERING] Erro: Nenhum ItemData configurado!")
		return

	if player_node.has_method("gathering"):
		# Chama a função do Player; se retornar 'false', o player está em cooldown (30s) ou ocupado!
		var started: bool = player_node.gathering(item_to_give, gathering_animation, required_tool, animation_duration)
		if not started:
			return
			
		is_being_gathered = true
		if is_instance_valid(interaction_prompt):
			interaction_prompt.visible = false
			
		# Reduz a durabilidade/vida do prop
		gathering_health -= 1
		print("[GATHERING] Restam %d coletas neste prop." % gathering_health)
		
		# Aguarda a animação da picareta/machado terminar para a árvore/pedra não sumir no meio da batida!
		await get_tree().create_timer(animation_duration).timeout
		is_being_gathered = false

		# Se a vida do prop esgotou, ele é destruído após a animação terminar
		if gathering_health <= 0:
			if spawner_reference and spawner_reference.has_method("on_prop_destroyed"):
				spawner_reference.on_prop_destroyed()
				
			queue_free()
		else:
			# Se ainda tem cargas (ex: Árvore com 5 de vida) e o player continua perto, reexibe o prompt
			if is_instance_valid(player_in_range) and is_instance_valid(interaction_prompt):
				interaction_prompt.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_being_gathered and event.is_action_pressed("Interagir"):
		interact(player_in_range)
		get_viewport().set_input_as_handled()

func _on_player_entered(body: Node3D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		player_in_range = body
		if interaction_prompt and not is_being_gathered and gathering_health > 0:
			interaction_prompt.visible = true

func _on_player_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
		if interaction_prompt:
			interaction_prompt.visible = false
