class_name NpcBase
extends CharacterBody3D

@export_category("Configurações do NPC")
@export var npc_id: String = "npc_base"
@export var npc_name: String = "NPC"

@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_prompt: Sprite3D = get_node_or_null("InteractionPrompt") # Referência ao ícone flutuante
@onready var name_label: Label = get_node_or_null("NameSprite/SubViewport/Label") # Referência opcional ao label do nome
var player_in_range: CharacterBody3D = null

func _ready() -> void:
	add_to_group("NPCs")
	if interaction_area:
		interaction_area.body_entered.connect(_on_player_entered)
		interaction_area.body_exited.connect(_on_player_exited)
	
	# Atualiza o texto do nome caso o label exista
	if name_label:
		name_label.text = npc_name

	if interaction_prompt:
		interaction_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Como é singleplayer local, se o player está no alcance e apertou o botão, interage direto!
	if player_in_range and event.is_action_pressed("Interagir"):
		interact(player_in_range)

func _on_player_entered(body: Node3D) -> void:
	# No singleplayer, qualquer nó no grupo "Players" ativa o prompt
	if body is CharacterBody3D and body.is_in_group("Player"):
		player_in_range = body
		if interaction_prompt:
			interaction_prompt.visible = true

func _on_player_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
		if interaction_prompt:
			interaction_prompt.visible = false

func interact(player_node: CharacterBody3D) -> void:
	if not player_node or global_position.distance_to(player_node.global_position) > 4.5:
		return

	# Notifica automaticamente o QuestManager caso o player esteja em uma quest de conversa com este NPC
	if has_node("/root/QuestManager"):
		QuestManager.on_npc_talked(player_node, npc_id)

	# Executa a lógica customizada do NPC específico (como o NpcValkor)
	handle_npc_interaction(player_node)

func handle_npc_interaction(player: CharacterBody3D) -> void:
	pass # Sobrescrito nas subclasses

func open_dialogue(npc_title: String, message: String) -> void:
	# Abre a janela de diálogo diretamente no player local
	if player_in_range and player_in_range.has_method("open_dialogue_window"):
		player_in_range.open_dialogue_window(npc_title, message)
