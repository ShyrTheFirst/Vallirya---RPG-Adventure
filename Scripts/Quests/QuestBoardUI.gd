class_name QuadroAvisosUI
extends PanelContainer

@export var quest_info_scene: PackedScene = preload("res://Scenes/UI/quest_info_container.tscn")

@onready var btn_close: Button = $VBoxContainer/BtnClose
@onready var btn_main_tab: Button = $VBoxContainer/QuestTypeSelector/BtnPrincipais # Quests Urgentes
@onready var btn_village_tab: Button = $VBoxContainer/QuestTypeSelector/BtnSecundarias # Quests da Vila
@onready var grid_container: GridContainer = $VBoxContainer/QuestsContainer

var current_tab: String = "urgent" # "urgent" ou "village"

func _ready() -> void:
	if btn_close and not btn_close.pressed.is_connected(_on_btn_close_pressed):
		btn_close.pressed.connect(_on_btn_close_pressed)
		
	if btn_main_tab and not btn_main_tab.pressed.is_connected(func(): switch_tab("urgent")):
		btn_main_tab.pressed.connect(func(): switch_tab("urgent"))
		
	if btn_village_tab and not btn_village_tab.pressed.is_connected(func(): switch_tab("village")):
		btn_village_tab.pressed.connect(func(): switch_tab("village"))

	refresh_board_ui()

func switch_tab(tab_name: String) -> void:
	current_tab = tab_name
	refresh_board_ui()

func refresh_board_ui() -> void:
	if not grid_container:
		return

	for child in grid_container.get_children():
		child.queue_free()

	var player = get_tree().get_first_node_in_group("Player")
	if player:
		QuestManager.sync_main_story_progress(player)

	if current_tab == "urgent":
		# ABA: Quests Urgentes (Exibe a missão principal atual do progresso)
		var main_q_id = "main_story_%d" % QuestManager.main_story_progress
		if QuestManager.quests_database.has(main_q_id):
			var q_data: QuestData = QuestManager.quests_database[main_q_id]
			var main_dict = {
				"id": main_q_id,
				"title": q_data.title,
				"description": q_data.description,
				"reward_xp": q_data.reward_xp,
				"turn_in_npc": q_data.turn_in_npc_id,
				"is_main_story": true,
				"turned_in": player and player.completed_quests.has(main_q_id)
			}
			
			if quest_info_scene:
				var card = quest_info_scene.instantiate() as QuestInfoContainer
				grid_container.add_child(card)
				card.setup_quest_card(main_dict, true, self)

	elif current_tab == "village":
		# ABA: Quests da Vila (Exibe os 6 contratos secundários persistentes)
		for bounty in QuestManager.village_bounties:
			if quest_info_scene:
				var card = quest_info_scene.instantiate() as QuestInfoContainer
				grid_container.add_child(card)
				card.setup_quest_card(bounty, false, self)

func _on_btn_close_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
