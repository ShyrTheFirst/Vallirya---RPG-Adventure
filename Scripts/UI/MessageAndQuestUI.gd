class_name MessageAndQuestUI
extends Control

@onready var message_panel: Panel = $MessageUIPanel
@onready var quest_panel: PanelContainer = $AcceptQuestUIContainer
@onready var name_label: Label = $MessageUIPanel/NameLabel
@onready var text_label: Label = $MessageUIPanel/TextLabel
@onready var btn_close: Button = $MessageUIPanel/BtnClose

@onready var q_name_label: Label = $AcceptQuestUIContainer/VBoxContainer/QNameLabel
@onready var q_desc_label: Label = $AcceptQuestUIContainer/VBoxContainer/QDescLabel
@onready var btn_accept: Button = $AcceptQuestUIContainer/HBoxContainer/BtnAccept
@onready var btn_deny: Button = $AcceptQuestUIContainer/HBoxContainer/BtnDeny

# Sinais para notificar o NPC sobre as ações do jogador
signal continue_dialogue_pressed
signal quest_accepted(quest_data)
signal quest_denied

var current_quest: QuestData = null

func _ready() -> void:
	if btn_close:
		if not btn_close.pressed.is_connected(_on_close_clicked):
			btn_close.pressed.connect(_on_close_clicked)
	if btn_accept:
		if not btn_accept.pressed.is_connected(_on_accept_clicked):
			btn_accept.pressed.connect(_on_accept_clicked)
	if btn_deny:
		if not btn_deny.pressed.is_connected(_on_deny_clicked):
			btn_deny.pressed.connect(_on_deny_clicked)

# Fecha com a tecla T do teclado caso queira manter o atalho
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		emit_signal("continue_dialogue_pressed")
		get_viewport().set_input_as_handled()

func set_message(npc_title: String, message: String, button_text: String = "Fechar") -> void:
	if message_panel: message_panel.visible = true
	if quest_panel: quest_panel.visible = false
	
	if name_label: name_label.text = npc_title
	if text_label: text_label.text = message
	if btn_close: btn_close.text = button_text

func set_quest_offer(npc_title: String, message: String, quest_data: QuestData, allow_deny: bool = true) -> void:
	current_quest = quest_data
	if message_panel: message_panel.visible = true
	if quest_panel: quest_panel.visible = true
	
	if name_label: name_label.text = npc_title
	if text_label: text_label.text = message
	
	if q_name_label: q_name_label.text = quest_data.title
	if q_desc_label: q_desc_label.text = quest_data.description
	
	if btn_deny:
		btn_deny.visible = allow_deny
		btn_deny.disabled = not allow_deny

func _on_close_clicked() -> void:
	emit_signal("continue_dialogue_pressed")

func _on_accept_clicked() -> void:
	if current_quest:
		emit_signal("quest_accepted", current_quest)

func _on_deny_clicked() -> void:
	emit_signal("quest_denied")
