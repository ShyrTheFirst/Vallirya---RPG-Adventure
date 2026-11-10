class_name QuestBoardWorld
extends StaticBody3D

@export var quest_board_ui_scene: PackedScene = preload("res://Scenes/UI/QuestBoardUI.tscn")
var active_ui: Control = null
var player_in_range: bool = false

@onready var interaction_prompt: Sprite3D = $InteractionPrompt


func _on_player_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		interaction_prompt.show()
		player_in_range = true
		print("[QUEST BOARD] Pressione E para abrir o Quadro de Missões.")

func _on_player_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		interaction_prompt.hide()
		player_in_range = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("Interagir"): # Certifique-se de ter a ação "interagir" no Input Map
		toggle_quest_board()

func toggle_quest_board() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	
	if active_ui and is_instance_valid(active_ui):
		active_ui.queue_free()
		active_ui = null
		if player:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		if quest_board_ui_scene:
			active_ui = quest_board_ui_scene.instantiate()
			# Adiciona a UI direto na HUD do player ou na árvore atual
			if player and player.has_node("CanvasLayer"):
				player.get_node("CanvasLayer").add_child(active_ui)
			else:
				get_tree().current_scene.add_child(active_ui)
			
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
