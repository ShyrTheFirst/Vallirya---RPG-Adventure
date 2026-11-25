class_name CraftingStation
extends Node3D

@export_category("Configuração da Bancada")
@export var station_name: String = "Mesa de Carpintaria"
@export var station_recipes: Array[CraftData] = [] # Receitas configuráveis no Inspetor

@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_prompt: Node3D = $InteractionPrompt # O sprite/ícone 'E' flutuante

var crafting_window: Control = null
var active_player: CharacterBody3D = null
var player_in_range: bool = false

func _ready() -> void:
	if interaction_area:
		interaction_area.body_entered.connect(_on_player_entered)
		interaction_area.body_exited.connect(_on_player_exited)
		
	if interaction_prompt:
		interaction_prompt.visible = false

# --- ENTRADA DE INPUT PARA INTERAGIR COM A TECLA (E) ---
func _unhandled_input(event: InputEvent) -> void:
	# Como é singleplayer local, se o player está no alcance e apertou o botão de interagir, abre/fecha a bancada!
	if player_in_range and active_player and event.is_action_pressed("Interagir"):
		print("Interagiu")
		interact(active_player)
		get_viewport().set_input_as_handled() # Consome o evento para evitar conflitos

# --- PADRÃO DE INTERAÇÃO COMPATÍVEL COM OS NPCS ---
func interact(player_node: CharacterBody3D) -> void:
	if not player_node or global_position.distance_to(player_node.global_position) > 4.5:
		return

	active_player = player_node
	print(active_player)
	print("Abriu?")
	toggle_station_window()

func _on_player_entered(body: Node3D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		player_in_range = true
		active_player = body
		if interaction_prompt:
			interaction_prompt.visible = true

func _on_player_exited(body: Node3D) -> void:
	if body.is_in_group("Player") or body.name == "Player":
		player_in_range = false
		active_player = null
		if interaction_prompt:
			interaction_prompt.visible = false
			
		# Se o player se afastar com a janela aberta, fecha automaticamente
		if active_player == body and is_instance_valid(crafting_window):
			toggle_station_window()

func toggle_station_window() -> void:
	if is_instance_valid(crafting_window):
		crafting_window.queue_free()
		crafting_window = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		active_player = null
		print("[STATION] Janela de %s fechada." % station_name)
	else:
		create_station_ui()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("[STATION] Janela de %s aberta." % station_name)

# --- CONSTRUÇÃO DA INTERFACE VISUAL (LAYOUT DO PRINT) ---
# --- CONSTRUÇÃO DA INTERFACE VISUAL DA BANCADA ---
# --- CONSTRUÇÃO DA INTERFACE VISUAL DA BANCADA ---
func create_station_ui() -> void:
	if is_instance_valid(crafting_window):
		crafting_window.queue_free()

	crafting_window = Control.new()
	crafting_window.name = "CraftingWindow"
	crafting_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crafting_window.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().current_scene.add_child(crafting_window)

	# Fundo escuro translúcido
	var bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.7)
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crafting_window.add_child(bg_overlay)

	# Painel central da bancada
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

	# Cabeçalho
	var title_lbl = Label.new()
	title_lbl.text = "--- %s ---" % station_name.to_upper()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	# Lista de Receitas com Scroll
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(610, 400)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.name = "RecipeList"
	list_vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(list_vbox)

	# Popula com as receitas cadastradas no Inspetor (@export)
	for recipe in station_recipes:
		if not recipe or not recipe.result_item:
			continue
			
		# Card Individual da Receita
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

		# 1. COLUNA DA ESQUERDA: Nome do Item em cima + Ícone 3D embaixo
		var item_col_vbox = VBoxContainer.new()
		item_col_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		item_col_vbox.add_theme_constant_override("separation", 4)
		recipe_hbox.add_child(item_col_vbox)

		# Nome do Item em cima da caixa 3D
		var item_name_lbl = Label.new()
		item_name_lbl.text = "%dx %s" % [recipe.result_quantity, recipe.result_item.name]
		item_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_name_lbl.add_theme_font_size_override("font_size", 13)
		item_col_vbox.add_child(item_name_lbl)

		# Container do Ícone 3D (SubViewport Container)
		if recipe.result_item and recipe.result_item.mesh_scene:
			var icon_3d = create_item_3d_viewport(recipe.result_item.mesh_scene, recipe.result_item, Vector2(90, 90))
			item_col_vbox.add_child(icon_3d)
		else:
			var placeholder = Control.new()
			placeholder.custom_minimum_size = Vector2(90, 90)
			item_col_vbox.add_child(placeholder)

		# 2. REQUISITOS POR ESCRITO (No meio - Empilhados)
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

		# 3. BOTÃO DE CRIAR (À direita)
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

	# Rodapé / Botão Fechar
	var close_btn = Button.new()
	close_btn.text = "Fechar Janela"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func():
		toggle_station_window()
	)
	vbox.add_child(close_btn)

# --- VERIFICAÇÃO RÁPIDA PARA BORDAS DA UI ---
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

# --- VALIDAÇÃO E EXECUÇÃO DO CRAFT INTEGRADA AO INVENTÁRIO DO PLAYER ---
func try_execute_craft(recipe: CraftData) -> void:
	if not active_player or not "inventory_items" in active_player:
		print("[STATION] Erro: Player ou inventário não encontrado.")
		return
		
	var crafting_manager = get_node_or_null("/root/CraftManager")
	if not crafting_manager:
		print("[STATION] Erro crítico: CraftManager não foi encontrado como Autoload!")
		return
		
	var eq_type_key: String = CraftData.get_equipment_type_key(recipe.equipment_type)

	# 1. Valida o gating de nível (precisa ter feito 10 do nível anterior)
	if not crafting_manager.can_craft_item(eq_type_key, recipe.recipe_level):
		var msg = "Bloqueado! Conclua 10 crafts do nível anterior."
		print("[STATION] ", msg)
		if active_player.has_method("send_message_HUD"):
			active_player.send_message_HUD(msg, Color.RED)
		return

	# 2. Função interna para contar quantos itens de um determinado ItemData o player possui (inventário + equipados)
	var count_player_item = func(target_item: ItemData) -> int:
		if not target_item: return 0
		var total = 0
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
		return total

	# 3. Valida se o player possui as quantidades de todos os ingredientes
	var ingredients: Array[Dictionary] = recipe.get_ingredients()
	var has_all_ingredients: bool = true
	for ing in ingredients:
		if count_player_item.call(ing["item"]) < ing["quantity"]:
			has_all_ingredients = false
			break

	if has_all_ingredients:
		# 4. Função interna para remover a quantidade correta do inventário do player
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
							active_player.inventory_items[i] = null # Esvazia o slot
						else:
							slot["amount"] = current_amt - remaining
							remaining = 0
							break
			if remaining > 0 and "equipped_items" in active_player:
				for slot_key in active_player.equipped_items.keys():
					var eq_item = active_player.equipped_items[slot_key]
					if eq_item is ItemData and eq_item.id == target_item.id:
						active_player.equipped_items[slot_key] = null
						if active_player.has_method("update_equipment_slot_visual"):
							active_player.update_equipment_slot_visual(slot_key, null)
						if active_player.has_method("recalculate_derived_stats"):
							active_player.recalculate_derived_stats()
						remaining -= 1
						if remaining <= 0:
							break
			if remaining > 0 and "equipped_tools" in active_player:
				for t_key in active_player.equipped_tools.keys():
					var t_item = active_player.equipped_tools[t_key]
					if t_item is ItemData and t_item.id == target_item.id:
						active_player.equipped_tools[t_key] = null
						if active_player.has_method("update_tool_slot_visual"):
							active_player.update_tool_slot_visual(t_key, null)
						remaining -= 1
						if remaining <= 0:
							break
			# Atualiza a interface visual do inventário do player
			if active_player.has_method("update_inventory_display"):
				active_player.update_inventory_display()

		# Consome os ingredientes
		for ing in ingredients:
			remove_player_item.call(ing["item"], ing["quantity"])

		# 5. Executa o craft no CraftManager (Sorteia raridade por especialista e registra progresso)
		var produced_item = crafting_manager.execute_station_craft(eq_type_key, recipe.recipe_level, recipe.result_item)
		
		if produced_item and active_player.has_method("add_item_to_inventory"):
			var final_qty: int = crafting_manager.roll_bonus_craft_quantity(eq_type_key, recipe.result_item, recipe.result_quantity)
			active_player.add_item_to_inventory(produced_item, final_qty)
			print("[STATION] Sucesso! Criado: %dx %s" % [final_qty, produced_item.name])
			
			if active_player.has_method("send_message_HUD"):
				var rarity_color = Color.WHITE
				match produced_item.rarity:
					produced_item.Rarity.UNCOMMON: rarity_color = Color.GREEN
					produced_item.Rarity.RARE: rarity_color = Color.DODGER_BLUE
					produced_item.Rarity.EPIC: rarity_color = Color.PURPLE
					produced_item.Rarity.LEGENDARY: rarity_color = Color.GOLD
				var hud_msg: String = "Criado: %s!" % produced_item.name
				if final_qty > recipe.result_quantity:
					hud_msg = "Criado: %dx %s! (+1 Bônus)" % [final_qty, produced_item.name]
				active_player.send_message_HUD(hud_msg, rarity_color)
			create_station_ui()
	else:
		print("[STATION] Materiais insuficientes no inventário!")
		if active_player.has_method("send_message_HUD"):
			active_player.send_message_HUD("Materiais Insuficientes!", Color.RED)

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
