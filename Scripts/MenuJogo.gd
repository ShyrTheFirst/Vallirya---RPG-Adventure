extends Control

@export var main_menu_scene: PackedScene = preload("res://Scenes/MainMenu.tscn")

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Se houver painéis de diálogo ou inventário abertos, deixa eles tratarem o ESC primeiro
		toggle_pause_menu()

func toggle_pause_menu() -> void:
	visible = not visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true # Pausa a física do jogo
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false # Retoma o jogo

# Botão: Salvar Jogo Manualmente
func _on_btn_save_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("save_player_account"):
		player.save_player_account()

# Botão: Sair do Jogo
func _on_btn_quit_pressed() -> void:
	get_tree().quit()
