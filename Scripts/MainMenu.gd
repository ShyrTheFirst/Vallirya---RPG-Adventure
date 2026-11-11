extends Node3D

@export var main_game_scene: PackedScene = preload("res://Scenes/Main.tscn")
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

# Caminho onde os saves dos personagens são armazenados localmente
const ACCOUNTS_DIR = "user://accounts/"

# Referências aos nós da sua interface
@onready var line_edit_username: LineEdit = $CanvasLayer/CenterContainer/OfflinePanel/VBoxContainer/LineEditUsername
@onready var btn_new_character: Button = $CanvasLayer/CenterContainer/OfflinePanel/VBoxContainer/BtnNewCharacter
@onready var character_list_container: VBoxContainer = $CanvasLayer/CenterContainer/OfflinePanel/VBoxContainer/CharacterScrollContainer/CharacterListContainer

var selected_character_name: String = ""

func _ready() -> void:
	_random_select_bgm()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Garante que a pasta de contas existe
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("accounts"):
		dir.make_dir("accounts")

	# Conecta os sinais dos botões
	if btn_new_character:
		btn_new_character.pressed.connect(_on_btn_new_character_pressed)

	# Atualiza a lista de personagens salvos ao abrir o menu
	refresh_character_list()

# Lê a pasta de saves e preenche a lista com os personagens existentes
func refresh_character_list() -> void:
	if not character_list_container:
		return

	for child in character_list_container.get_children():
		child.queue_free()

	var dir = DirAccess.open(ACCOUNTS_DIR)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "json":
			var char_name = file_name.get_basename()
			var char_level = _get_character_level(char_name)
			_create_character_row(char_name, char_level)
		file_name = dir.get_next()
	dir.list_dir_end()

func _get_character_level(char_name: String) -> int:
	var file_path = ACCOUNTS_DIR + char_name + ".json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			if data is Dictionary:
				return int(data.get("level", 1))
	return 1

func _create_character_row(char_name: String, char_level: int) -> void:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 40)
	hbox.add_theme_constant_override("separation", 10)

	# Botão principal para selecionar o personagem e jogar
	var btn_play = Button.new()
	btn_play.text = "⚔️ %s [Nv. %d]" % [char_name, char_level]
	btn_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_play.focus_mode = Control.FOCUS_NONE
	btn_play.pressed.connect(func():
		_launch_game_with_character(char_name)
	)
	hbox.add_child(btn_play)

	# Botão de excluir save (Lixeira / Deletar)
	var btn_delete = Button.new()
	btn_delete.text = " 🗑️ Excluir "
	btn_delete.modulate = Color(1.0, 0.4, 0.4)
	btn_delete.focus_mode = Control.FOCUS_NONE
	btn_delete.pressed.connect(func():
		_delete_character_save(char_name)
	)
	hbox.add_child(btn_delete)

	character_list_container.add_child(hbox)

func _delete_character_save(char_name: String) -> void:
	var file_path = ACCOUNTS_DIR + char_name + ".json"
	var dir = DirAccess.open(ACCOUNTS_DIR)
	if dir and FileAccess.file_exists(file_path):
		dir.remove(file_path)
		print("[MENU] Save do personagem '%s' excluído com sucesso." % char_name)
		refresh_character_list()

# Cria um botão na interface para cada personagem encontrado
func _create_character_list_button(char_name: String) -> void:
	var btn = Button.new()
	btn.text = "🎮 " + char_name
	btn.custom_minimum_size = Vector2(0, 40)
	btn.focus_mode = Control.FOCUS_NONE
	
	# Ao clicar no botão do personagem, inicia o jogo carregando este save
	btn.pressed.connect(func():
		_launch_game_with_character(char_name)
	)
	
	character_list_container.add_child(btn)

# Botão "Adicionar Novo Personagem" / Criar
func _on_btn_new_character_pressed() -> void:
	if not line_edit_username:
		return

	var char_name = line_edit_username.text.strip_edges()
	if char_name == "":
		print("[MENU] Digite um nome válido para o personagem!")
		return

	var file_path = ACCOUNTS_DIR + char_name + ".json"
	if FileAccess.file_exists(file_path):
		print("[MENU] Já existe um personagem com este nome!")
		return

	# Cria um arquivo de save inicial básico em JSON para o novo herói
	_create_new_character_save(char_name)
	
	# Limpa o campo e atualiza a lista
	line_edit_username.text = ""
	refresh_character_list()
	
	print("[MENU] Novo personagem criado com sucesso: ", char_name)

# Gera a estrutura inicial do arquivo JSON de save para o novo herói
func _create_new_character_save(char_name: String) -> void:
	var default_data = {
		"username": char_name,
		"level": 1,
		"current_xp": 0,
		"required_xp": 100,
		"unspent_points": 3,
		"stats": { "str": 5, "agi": 5, "vit": 5, "int": 5 },
		"inventory": [],
		"equipment": {},
		"weapon_mesh_path": "",
		"last_position": { "x": 0, "y": 1, "z": 0 },
		"active_quests": {},
		"completed_quests": []
	}

	var file = FileAccess.open(ACCOUNTS_DIR + char_name + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(default_data, "\t"))
		file.close()

func _launch_game_with_character(char_name: String) -> void:
	print("[MENU] Iniciando o jogo com o herói: ", char_name)
	
	# Salva o nome escolhido
	LevelManager.current_player_name = char_name
	
	# Abre a cena Main. O próprio script da Main vai cuidar de puxar o mapa.
	get_tree().change_scene_to_packed(main_game_scene)

func _random_select_bgm():
	var bgm_list = [
	"res://ASSETS/SFX/Fantasy Ambient Music/1. Moonspire.mp3",
	"res://ASSETS/SFX/Fantasy Ambient Music/2. Winds of Valor.mp3",
	"res://ASSETS/SFX/Fantasy Ambient Music/3. Darkwood Path.mp3",
	"res://ASSETS/SFX/Fantasy Ambient Music/4. Frostbound.mp3",
	"res://ASSETS/SFX/Fantasy Ambient Music/5. Emberlight.mp3",
	"res://ASSETS/SFX/Fantasy Ambient Music/6. Silverbrook.mp3",
	"res://ASSETS/SFX/Fantasy Ambient Music/7. Mystic Grove.mp3",
	"res://ASSETS/SFX/Fantasy Ambient Music/8. Throne of Storms.mp3",
	"res://ASSETS/SFX/Fantasy Ambient Music/9. Sorrow’s Edge.mp3",
	"res://ASSETS/SFX/Fantasy Ambient Music/10. Elven Dawn.mp3"
	]
	var pick_bgm = bgm_list.pick_random()
	bgm_player.stream = load(pick_bgm)
	bgm_player.play()
	
