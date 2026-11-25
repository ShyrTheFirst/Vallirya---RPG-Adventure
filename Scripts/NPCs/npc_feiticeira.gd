class_name NpcFeiticeira
extends NpcBase

@export_category("Fila de Missões da Feiticeira")
@export var managed_quests: Array[QuestData] = [] # Arraste aqui todas as quests em ordem que ela participa

@export_category("Configuração de Crafting da Feiticeira")
@export var station_name: String = "Bancada de Alquimia"
@export var station_recipes: Array[CraftData] = [] # Receitas de poções configuráveis no Inspetor

var crafting_window: Control = null
var active_player: CharacterBody3D = null
var stored_action_type: String = "" # "open_craft" ou ""
var stored_quest_to_action: String = ""
var is_turn_in_action: bool = false

# 1. Define o ícone flutuante (?, !, verde) baseado estritamente na fila de missões dela
func get_current_quest_status() -> QuestStatus:
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return QuestStatus.NONE

	for q_data in managed_quests:
		if not q_data:
			continue
		var q_id = q_data.quest_id
		
		# Se já concluiu esta da fila, pula para a próxima
		if player.completed_quests.has(q_id):
			continue
			
		# Verifica se já está ativa no cliente
		var is_active = false
		var is_completed = false
		for active_q in player.client_active_quests:
			if active_q.get("id", "") == q_id:
				is_active = true
				is_completed = active_q.get("completed", false)
				break

		if is_active:
			if (q_data.quest_type == QuestData.QuestType.TALK_TO_NPC and q_data.target_ids.has(npc_id)) or (is_completed and q_data.turn_in_npc_id == npc_id):
				return QuestStatus.READY_TO_TURN_IN # ! Verde (Pronta para entregar/conversar)
			return QuestStatus.IN_PROGRESS # ! Laranja (Em andamento)
		elif q_data.start_npc_id == npc_id:
			return QuestStatus.AVAILABLE # ? Amarelo (Disponível para pegar)

	return QuestStatus.NONE

# 2. Controla o fluxo de conversa e decide se abre diálogo de entrega/aceite ou a bancada de poções
func handle_npc_dialogue_flow(player: CharacterBody3D) -> void:
	if not active_ui_instance:
		return

	if not active_ui_instance.is_connected("continue_dialogue_pressed", _on_continue_pressed):
		active_ui_instance.continue_dialogue_pressed.connect(_on_continue_pressed)
	if not active_ui_instance.is_connected("quest_accepted", _on_quest_accepted):
		active_ui_instance.quest_accepted.connect(_on_quest_accepted)
	if not active_ui_instance.is_connected("quest_denied", _on_quest_denied):
		active_ui_instance.quest_denied.connect(_on_quest_denied)

	# --- VARREDURA DA FILA DE MISSÕES ---
	var target_quest: QuestData = null
	var quest_state = "none"

	for q_data in managed_quests:
		if not q_data:
			continue
		var q_id = q_data.quest_id
		
		if player.completed_quests.has(q_id):
			continue

		var active_entry = _get_active_quest_entry(player, q_id)
		if not active_entry.is_empty():
			if q_data.quest_type == QuestData.QuestType.TALK_TO_NPC and q_data.target_ids.has(npc_id):
				QuestManager.on_npc_talked(player, npc_id)
			
			target_quest = q_data
			quest_state = "turn_in"
			break
		elif q_data.start_npc_id == npc_id:
			target_quest = q_data
			quest_state = "available"
			break

	if quest_state == "turn_in":
		active_ui_instance.set_message(npc_name, "Excelente! Vejo que concluiu sua tarefa com os elixires e conhecimentos arcanos.", "Concluir Missão")
		stored_quest_to_action = target_quest.quest_id
		is_turn_in_action = false
		stored_action_type = "open_craft"
	elif quest_state == "available" and target_quest:
		active_ui_instance.set_quest_offer(npc_name, "As energias místicas fluem por aqui. Aceite esta nova diretriz arcana:", target_quest, true)
		stored_quest_to_action = ""
		is_turn_in_action = false
		stored_action_type = ""
	else:
		# Sem quests ativas com ela no momento: Abre a janela de Alquimia / Crafting de Poções!
		active_ui_instance.set_message(
			npc_name, 
			"As energias místicas fluem por aqui. Precisa de poções para suas jornadas?", 
			"Abrir Alquimia"
		)
		stored_quest_to_action = ""
		is_turn_in_action = false
		stored_action_type = "open_craft"

func _on_continue_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	var should_open_craft = (stored_action_type == "open_craft")

	if player and stored_quest_to_action != "" and is_turn_in_action:
		var has_it = false
		for q in player.client_active_quests:
			if q.get("id", "") == stored_quest_to_action:
				has_it = true
				break
		if not has_it:
			QuestManager.assign_quest(player, stored_quest_to_action)
		
		var q_data = QuestManager.quests_database.get(stored_quest_to_action, null)
		if q_data and q_data.quest_type == QuestData.QuestType.TALK_TO_NPC and q_data.target_ids.has(npc_id):
			QuestManager.on_npc_talked(player, npc_id)

		if q_data and q_data.turn_in_npc_id == npc_id:
			QuestManager.complete_and_turn_in_quest(player, stored_quest_to_action)
		stored_quest_to_action = ""
		is_turn_in_action = false
	
	stored_action_type = ""
	close_dialogue_ui()
	update_visual_quest_status()

	if should_open_craft and player:
		toggle_station_window(player)

func _on_quest_accepted(quest_data: QuestData) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and quest_data and quest_data.start_npc_id == npc_id:
		QuestManager.assign_quest(player, quest_data.quest_id)
	close_dialogue_ui()
	update_visual_quest_status()

func _on_quest_denied() -> void:
	close_dialogue_ui()

func _get_active_quest_entry(player: Node, qid: String) -> Dictionary:
	for q in player.client_active_quests:
		if q.get("id", "") == qid:
			return q
	return {}


# =====================================================================
#  LÓGICA DE CRAFTING DE POÇÕES
# =====================================================================

func toggle_station_window(player_node: CharacterBody3D) -> void:
	if is_instance_valid(crafting_window):
		crafting_window.queue_free()
		crafting_window = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		active_player = null
	else:
		active_player = player_node
		create_station_ui()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func create_station_ui() -> void:
	if is_instance_valid(crafting_window):
		crafting_window.queue_free()

	crafting_window = Control.new()
	crafting_window.name = "CraftingWindow"
	crafting_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crafting_window.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().current_scene.add_child(crafting_window)

	var bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.7)
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crafting_window.add_child(bg_overlay)

	var panel = PanelContainer.new()
	panel.name = "StationPanel"
	panel.custom_minimum_size = Vector2(650, 540)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -325
	panel.offset_right = 325
	panel.offset_top = -270
	panel.offset_bottom = 270
	
	var theme = load("res://ASSETS/VFX/Themes/ValliryaTheme_Final.tres")
	if theme:
		panel.theme = theme
	crafting_window.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "--- %s ---" % station_name.to_upper()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(610, 400)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.name = "RecipeList"
	list_vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(list_vbox)

	for recipe in station_recipes:
		if not recipe or not recipe.result_item:
			continue
			
		var recipe_panel = PanelContainer.new()
		recipe_panel.custom_minimum_size = Vector2(590, 110)

		var can_craft: bool = _can_craft_recipe(recipe)
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.1, 0.1, 0.12, 0.85)
		card_style.set_border_width_all(2)
		card_style.set_corner_radius_all(6)
		card_style.set_content_margin_all(10)
		card_style.border_color = Color(0.2, 0.85, 0.3, 1.0) if can_craft else Color(0.9, 0.25, 0.25, 1.0)
		recipe_panel.add_theme_stylebox_override("panel", card_style)

		list_vbox.add_child(recipe_panel)

		var recipe_hbox = HBoxContainer.new()
		recipe_hbox.add_theme_constant_override("separation", 20)
		recipe_panel.add_child(recipe_hbox)

		var item_col_vbox = VBoxContainer.new()
		item_col_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		item_col_vbox.add_theme_constant_override("separation", 4)
		recipe_hbox.add_child(item_col_vbox)

		var item_name_lbl = Label.new()
		item_name_lbl.text = "%dx %s" % [recipe.result_quantity, recipe.result_item.name]
		item_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_name_lbl.add_theme_font_size_override("font_size", 13)
		item_col_vbox.add_child(item_name_lbl)

		if recipe.result_item and recipe.result_item.mesh_scene:
			var icon_3d = create_item_3d_viewport(recipe.result_item.mesh_scene, recipe.result_item, Vector2(90, 90))
			item_col_vbox.add_child(icon_3d)
		else:
			var placeholder = Control.new()
			placeholder.custom_minimum_size = Vector2(90, 90)
			item_col_vbox.add_child(placeholder)

		var requirements_vbox = VBoxContainer.new()
		requirements_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		requirements_vbox.add_theme_constant_override("separation", 8)
		requirements_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		recipe_hbox.add_child(requirements_vbox)

		var tier_lbl = Label.new()
		tier_lbl.text = "Categoria: %s (Nv. %d)" % [CraftData.get_equipment_type_label(recipe.equipment_type), recipe.recipe_level]
		tier_lbl.add_theme_font_size_override("font_size", 13)
		requirements_vbox.add_child(tier_lbl)

		for ing in recipe.get_ingredients():
			var req_lbl = Label.new()
			req_lbl.text = "• %d %s" % [ing["quantity"], ing["item"].name]
			req_lbl.add_theme_font_size_override("font_size", 14)
			requirements_vbox.add_child(req_lbl)

		var btn_container = VBoxContainer.new()
		btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
		recipe_hbox.add_child(btn_container)

		var craft_btn = Button.new()
		craft_btn.text = "CRIAR"
		craft_btn.custom_minimum_size = Vector2(110, 45)
		craft_btn.pressed.connect(func():
			try_execute_craft(recipe)
		)
		btn_container.add_child(craft_btn)

	var close_btn = Button.new()
	close_btn.text = "Fechar Janela"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func():
		toggle_station_window(null)
	)
	vbox.add_child(close_btn)

func _can_craft_recipe(recipe: CraftData) -> bool:
	if not active_player or not "inventory_items" in active_player:
		return false
	var crafting_manager = get_node_or_null("/root/CraftManager")
	if not crafting_manager:
		return false
	var eq_type_key: String = CraftData.get_equipment_type_key(recipe.equipment_type)
	if not crafting_manager.can_craft_item(eq_type_key, recipe.recipe_level):
		return false
	for ing in recipe.get_ingredients():
		var target_item: ItemData = ing["item"]
		var req_qty: int = ing["quantity"]
		var total: int = 0
		for slot in active_player.inventory_items:
			if slot != null and slot is Dictionary:
				var item_in_slot: ItemData = slot.get("item", null)
				if item_in_slot and item_in_slot.id == target_item.id:
					total += int(slot.get("amount", 1))
		if "equipped_items" in active_player:
			for eq_item in active_player.equipped_items.values():
				if eq_item is ItemData and eq_item.id == target_item.id:
					total += 1
		if "equipped_tools" in active_player:
			for tool_item in active_player.equipped_tools.values():
				if tool_item is ItemData and tool_item.id == target_item.id:
					total += 1
		if total < req_qty:
			return false
	return true

func try_execute_craft(recipe: CraftData) -> void:
	if not active_player or not "inventory_items" in active_player:
		return
		
	var crafting_manager = get_node_or_null("/root/CraftManager")
	if not crafting_manager:
		return
		
	var eq_type_key: String = CraftData.get_equipment_type_key(recipe.equipment_type)
	if not crafting_manager.can_craft_item(eq_type_key, recipe.recipe_level):
		if active_player.has_method("send_message_HUD"):
			active_player.send_message_HUD("Bloqueado! Suba sua maestria para o nível %d." % recipe.recipe_level, Color.RED)
		return

	var count_player_item = func(target_item: ItemData) -> int:
		if not target_item: return 0
		var total = 0
		for slot in active_player.inventory_items:
			if slot != null and slot is Dictionary:
				var item_in_slot: ItemData = slot.get("item", null)
				if item_in_slot and item_in_slot.id == target_item.id:
					total += int(slot.get("amount", 1))
		return total

	var ingredients: Array[Dictionary] = recipe.get_ingredients()
	var has_all_ingredients: bool = true
	for ing in ingredients:
		if count_player_item.call(ing["item"]) < ing["quantity"]:
			has_all_ingredients = false
			break

	if has_all_ingredients:
		var remove_player_item = func(target_item: ItemData, qty_to_remove: int) -> void:
			if not target_item or qty_to_remove <= 0: return
			var remaining = qty_to_remove
			for i in range(active_player.inventory_items.size()):
				var slot = active_player.inventory_items[i]
				if slot != null and slot is Dictionary:
					var item_in_slot: ItemData = slot.get("item", null)
					if item_in_slot and item_in_slot.id == target_item.id:
						var current_amt = int(slot.get("amount", 1))
						if current_amt <= remaining:
							remaining -= current_amt
							active_player.inventory_items[i] = null
						else:
							slot["amount"] = current_amt - remaining
							remaining = 0
							break
			if active_player.has_method("update_inventory_display"):
				active_player.update_inventory_display()

		for ing in ingredients:
			query_remove_item(ing["item"], ing["quantity"], remove_player_item)

		var produced_item = crafting_manager.execute_station_craft(eq_type_key, recipe.recipe_level, recipe.result_item)
		
		if produced_item and active_player.has_method("add_item_to_inventory"):
			active_player.add_item_to_inventory(produced_item, recipe.result_quantity)
			if active_player.has_method("send_message_HUD"):
				var rarity_color = Color.WHITE
				match produced_item.rarity:
					produced_item.Rarity.UNCOMMON: rarity_color = Color.GREEN
					produced_item.Rarity.RARE: rarity_color = Color.DODGER_BLUE
					produced_item.Rarity.EPIC: rarity_color = Color.PURPLE
					produced_item.Rarity.LEGENDARY: rarity_color = Color.GOLD
				active_player.send_message_HUD("Criado: %s!" % produced_item.name, rarity_color)
			create_station_ui()
	else:
		if active_player.has_method("send_message_HUD"):
			active_player.send_message_HUD("Materiais Insuficientes!", Color.RED)

func query_remove_item(item: ItemData, qty: int, callback: Callable) -> void:
	callback.call(item, qty)

func create_item_3d_viewport(mesh_scene: PackedScene, item_data: ItemData = null, icon_size: Vector2 = Vector2(90, 90)) -> Control:
	var icon_scene = preload("res://Scenes/Inventario/item_icon_3d.tscn")
	var icon_instance = icon_scene.instantiate() as Control
	icon_instance.custom_minimum_size = icon_size
	icon_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var anchor = icon_instance.get_node_or_null("SubViewport/MeshAnchor")
	if anchor and mesh_scene:
		for child in anchor.get_children():
			child.queue_free()
		var m = mesh_scene.instantiate()
		anchor.add_child(m)
		
		if item_data:
			m.rotation_degrees = item_data.inventory_rotation
			m.scale = item_data.inventory_scale
			m.position = item_data.inventory_offset
		else:
			m.rotation_degrees = Vector3(-90.0, 45.0, 0.0)
			m.scale = Vector3.ONE
			m.position = Vector3.ZERO

	return icon_instance
