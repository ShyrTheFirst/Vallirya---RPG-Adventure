class_name NpcBase
extends CharacterBody3D

@export_category("Configurações do NPC")
@export var npc_id: String = "NPC"
@export var npc_name: String = "NPC"

@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_prompt: Sprite3D = get_node_or_null("InteractionPrompt") 
@onready var name_sprite: Sprite3D = get_node_or_null("NameSprite")
@onready var name_label: Label = get_node_or_null("NameSprite/SubViewport/Label") 
@onready var quest_status_icon: Sprite3D = get_node_or_null("QuestStatusIcon")
@onready var quest_status_label: Label = get_node_or_null("QuestStatusIcon/SubViewport/Label") # Ou o nó de texto dentro do ícone

var player_in_range: CharacterBody3D = null

# Pré-carrega a cena unificada de diálogo e quests que você criou
@export var message_quest_ui_scene: PackedScene = preload("res://Scenes/NPCs/UI/message_quest_ui.tscn")
var active_ui_instance: Control = null


enum QuestStatus { NONE, AVAILABLE, IN_PROGRESS, READY_TO_TURN_IN }

func _ready() -> void:
	add_to_group("NPCs")
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_player_entered)
		interaction_area.body_exited.connect(_on_player_exited)
	
	if name_label:
		name_label.text = npc_name
		
	if name_sprite:
		name_sprite.visible = true # Nome sempre visível acima do NPC

	if interaction_prompt:
		interaction_prompt.visible = false

	update_visual_quest_status()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("Interagir"):
		interact(player_in_range)

func _on_player_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("Player"):
		player_in_range = body
		if interaction_prompt:
			interaction_prompt.visible = true

func _on_player_exited(body: Node3D) -> void:
	if body == player_in_range:
		player_in_range = null
		if interaction_prompt:
			interaction_prompt.visible = false
		close_dialogue_ui()

# --- ATUALIZAÇÃO DOS ÍCONES FLUTUANTES (? / !) ---
func update_visual_quest_status() -> void:
	if not quest_status_icon:
		return

	var status = get_current_quest_status()
	
	match status:
		QuestStatus.AVAILABLE:
			# Quests disponíveis: Amarelo com "?"
			quest_status_icon.visible = true
			quest_status_icon.modulate = Color(1.0, 0.85, 0.1) # Amarelo
			if quest_status_label: quest_status_label.text = "?"
			
		QuestStatus.IN_PROGRESS:
			# Quests em progresso: Laranja com "!"
			quest_status_icon.visible = true
			quest_status_icon.modulate = Color(1.0, 0.5, 0.0) # Laranja
			if quest_status_label: quest_status_label.text = "!"
			
		QuestStatus.READY_TO_TURN_IN:
			# Quests prontas para entregar: Verde com "!"
			quest_status_icon.visible = true
			quest_status_icon.modulate = Color(0.2, 1.0, 0.3) # Verde
			if quest_status_label: quest_status_label.text = "!"
			
		_:
			# Sem quests: Invisível
			quest_status_icon.visible = false

# Método que pode ser sobrescrito pelos scripts filhos (ex: NpcFerreiro, NpcValkor)
func get_current_quest_status() -> QuestStatus:
	return QuestStatus.NONE

func interact(player_node: CharacterBody3D) -> void:
	if not player_node or global_position.distance_to(player_node.global_position) > 4.5:
		return

	# Instancia a UI de diálogo caso ela não esteja aberta
	if not active_ui_instance or not is_instance_valid(active_ui_instance):
		if message_quest_ui_scene:
			active_ui_instance = message_quest_ui_scene.instantiate()
			if player_node.has_node("CanvasLayer"):
				player_node.get_node("CanvasLayer").add_child(active_ui_instance)
			else:
				get_tree().current_scene.add_child(active_ui_instance)
			
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Deixa a cargo do script filho (NPC específico) passar o conteúdo e controlar as falas/quests
	handle_npc_dialogue_flow(player_node)

# Método base para ser sobrescrito nos NPCs específicos
func handle_npc_dialogue_flow(player: CharacterBody3D) -> void:
	pass

# --- MÉTODOS DE CONTROLE DA UI QUE OS FILHOS VÃO CHAMAR ---

# Exibe apenas a parte de baixo (Mensagem do NPC)
func show_npc_message(npc_title: String, message_text: String, button_text: String = "Continuar [T]") -> void:
	if not active_ui_instance:
		return
	
	var msg_panel = active_ui_instance.find_child("MessageUIPanel", true, false)
	var quest_container = active_ui_instance.find_child("AcceptQuestUIContainer", true, false)
	
	if msg_panel: msg_panel.visible = true
	if quest_container: quest_container.visible = false # Esconde o centro se não houver quest
	
	var name_lbl = active_ui_instance.find_child("NameLabel", true, false) # Nome do NPC na caixa de texto
	var text_lbl = active_ui_instance.find_child("TexLabel", true, false) # O texto da mensagem
	var btn_close = active_ui_instance.find_child("BtnClose", true, false) # Botão de continuar/fechar
	
	if name_lbl: name_lbl.text = npc_title
	if text_lbl: text_lbl.text = message_text
	if btn_close: btn_close.text = button_text

# Exibe a parte de baixo E o painel central de aceitar/recusar quest
func show_npc_quest_offer(npc_title: String, message_text: String, quest_data: QuestData) -> void:
	if not active_ui_instance:
		return
		
	var msg_panel = active_ui_instance.find_child("MessageUIPanel", true, false)
	var quest_container = active_ui_instance.find_child("AcceptQuestUIContainer", true, false)
	
	if msg_panel: msg_panel.visible = true
	if quest_container: quest_container.visible = true # MOSTRA O CENTRO POIS HÁ UMA QUEST!
	
	# Preenche o diálogo inferior
	var name_lbl = active_ui_instance.find_child("NameLabel", true, false)
	var text_lbl = active_ui_instance.find_child("TexLabel", true, false)
	if name_lbl: name_lbl.text = npc_title
	if text_lbl: text_lbl.text = message_text
	
	# Preenche o painel central de aceitar quest
	var q_name_lbl = active_ui_instance.find_child("QNameLabel", true, false)
	var q_desc_lbl = active_ui_instance.find_child("QDescLabel", true, false)
	var btn_accept = active_ui_instance.find_child("BtnAccept", true, false)
	var btn_deny = active_ui_instance.find_child("BtnDeny", true, false)
	
	if q_name_lbl: q_name_lbl.text = quest_data.title
	if q_desc_lbl: q_desc_lbl.text = quest_data.description
	
	# Conecta os botões de Aceitar / Recusar de forma limpa
	if btn_accept:
		if btn_accept.pressed.is_connected(_on_accept_quest_pressed):
			btn_accept.pressed.disconnect(_on_accept_quest_pressed)
		btn_accept.pressed.connect(func(): _on_accept_quest_pressed(quest_data))
		
	if btn_deny:
		if btn_deny.pressed.is_connected(close_dialogue_ui):
			btn_deny.pressed.disconnect(close_dialogue_ui)
		btn_deny.pressed.connect(close_dialogue_ui)

func _on_accept_quest_pressed(quest_data: QuestData) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and quest_data:
		QuestManager.assign_quest(player, quest_data.quest_id)
		print("[NPC] Quest '%s' aceita pelo jogador!" % quest_data.title)
	close_dialogue_ui()
	update_visual_quest_status()

func close_dialogue_ui() -> void:
	if active_ui_instance and is_instance_valid(active_ui_instance):
		active_ui_instance.queue_free()
		active_ui_instance = null
		
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
