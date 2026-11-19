class_name NpcArmazem
extends NpcBase

@export_category("Configuração do Armazém")
@export var warehouse_name: String = "Armazém Central"
@export var warehouse_capacity: int = 64 # Capacidade generosa para guardar recursos e moedas

var warehouse_window: Control = null
var active_player: CharacterBody3D = null

func _ready() -> void:
	add_to_group("NPCs")
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_player_entered)
		interaction_area.body_exited.connect(_on_player_exited)
	
	if name_label:
		name_label.text = npc_name
		
	if name_sprite:
		name_sprite.visible = false

	if interaction_prompt:
		interaction_prompt.visible = false

	update_visual_quest_status()

# Pula a fala e abre direto o armazém ao interagir
func interact(player_node: CharacterBody3D) -> void:
	if not player_node or global_position.distance_to(player_node.global_position) > 4.5:
		return

	active_player = player_node
	toggle_warehouse_window()

func toggle_warehouse_window() -> void:
	if is_instance_valid(warehouse_window):
		warehouse_window.queue_free()
		warehouse_window = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# Salva o inventário do armazém no player e atualiza o arquivo JSON da conta
		if active_player and active_player.has_method("save_player_account"):
			active_player.save_player_account()
			
		active_player = null
	else:
		if active_player:
			create_warehouse_ui()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func create_warehouse_ui() -> void:
	if is_instance_valid(warehouse_window):
		warehouse_window.queue_free()

	warehouse_window = Control.new()
	warehouse_window.name = "WarehouseWindow"
	warehouse_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warehouse_window.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().current_scene.add_child(warehouse_window)

	var bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.75)
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warehouse_window.add_child(bg_overlay)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(800, 520)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -260
	panel.offset_bottom = 260
	
	var theme = load("res://ASSETS/VFX/Themes/ValliryaTheme_Final.tres")
	if theme:
		panel.theme = theme
	warehouse_window.add_child(panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	var title_lbl = Label.new()
	title_lbl.text = "--- %s ---" % warehouse_name.to_upper()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(1.0, 0.85, 0.3)
	main_vbox.add_child(title_lbl)

	# Container de Abas ou Lado a Lado (Armazém / Inventário)
	var split_hbox = HBoxContainer.new()
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(split_hbox)

	# --- COLUNA ESQUERDA: ITENS NO ARMAZÉM ---
	var w_vbox = VBoxContainer.new()
	w_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_hbox.add_child(w_vbox)

	var w_lbl = Label.new()
	w_lbl.text = "Itens Guardados (Clique para retirar)"
	w_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w_lbl.add_theme_font_size_override("font_size", 11)
	w_vbox.add_child(w_lbl)

	var w_scroll = ScrollContainer.new()
	w_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	w_vbox.add_child(w_scroll)

	var w_grid = GridContainer.new()
	w_grid.columns = 4
	w_grid.add_theme_constant_override("h_separation", 10)
	w_grid.add_theme_constant_override("v_separation", 10)
	w_scroll.add_child(w_grid)
	populate_warehouse_grid(w_grid)

	# --- COLUNA DIREITA: INVENTÁRIO DO PLAYER ---
	var p_vbox = VBoxContainer.new()
	p_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_hbox.add_child(p_vbox)

	var p_lbl = Label.new()
	p_lbl.text = "Seu Inventário (Clique para guardar)"
	p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl.add_theme_font_size_override("font_size", 11)
	p_vbox.add_child(p_lbl)

	var p_scroll = ScrollContainer.new()
	p_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p_vbox.add_child(p_scroll)

	var p_grid = GridContainer.new()
	p_grid.columns = 4
	p_grid.add_theme_constant_override("h_separation", 10)
	p_grid.add_theme_constant_override("v_separation", 10)
	p_scroll.add_child(p_grid)
	populate_player_grid(p_grid)

	# Rodapé
	var close_btn = Button.new()
	close_btn.text = "Fechar Armazém"
	close_btn.custom_minimum_size = Vector2(0, 35)
	close_btn.pressed.connect(toggle_warehouse_window)
	main_vbox.add_child(close_btn)

func create_item_3d_viewport(mesh_scene: PackedScene, item_data: ItemData = null, size: Vector2 = Vector2(60, 60)) -> Control:
	var icon_scene = preload("res://Scenes/Inventario/item_icon_3d.tscn")
	var icon_instance = icon_scene.instantiate() as Control
	icon_instance.custom_minimum_size = size
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

func get_rarity_color(rarity) -> Color:
	match rarity:
		ItemData.Rarity.UNCOMMON: return Color(0.2, 0.8, 0.2)
		ItemData.Rarity.RARE: return Color(0.2, 0.5, 1.0)
		ItemData.Rarity.EPIC: return Color(0.6, 0.2, 0.8)
		ItemData.Rarity.LEGENDARY: return Color(1.0, 0.6, 0.1)
	return Color.TRANSPARENT

# Preenche a grade do Armazém
func populate_warehouse_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()

	if not active_player or not "warehouse_items" in active_player:
		return

	# Garante o tamanho correto do array no player
	if active_player.warehouse_items.is_empty():
		active_player.warehouse_items.resize(warehouse_capacity)

	for i in range(active_player.warehouse_items.size()):
		var slot_data = active_player.warehouse_items[i]
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(60, 60)
		slot_btn.focus_mode = Control.FOCUS_NONE
		slot_btn.clip_contents = true

		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.12, 0.15, 0.18, 0.8)
		slot_style.set_corner_radius_all(4)

		if slot_data != null and slot_data is Dictionary:
			var item: ItemData = slot_data.get("item", null)
			var amount = int(slot_data.get("amount", 1))
			if item:
				var r_color = get_rarity_color(item.rarity)
				if r_color != Color.TRANSPARENT:
					slot_style.border_color = r_color
					slot_style.set_border_width_all(1)

				if item.mesh_scene:
					var icon = create_item_3d_viewport(item.mesh_scene, item)
					slot_btn.add_child(icon)
				if amount > 1:
					var lbl = Label.new()
					lbl.text = str(amount)
					lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
					lbl.offset_right = -4
					lbl.offset_bottom = -2
					lbl.add_theme_font_size_override("font_size", 10)
					slot_btn.add_child(lbl)
					
				var idx = i
				slot_btn.pressed.connect(func(): show_warehouse_quantity_dialog(item, idx, amount, false))

		slot_btn.add_theme_stylebox_override("normal", slot_style)
		grid.add_child(slot_btn)

# Preenche a grade do Inventário do Player
func populate_player_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()

	if not active_player or not "inventory_items" in active_player:
		return

	for i in range(active_player.inventory_items.size()):
		var slot_data = active_player.inventory_items[i]
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(60, 60)
		slot_btn.focus_mode = Control.FOCUS_NONE
		slot_btn.clip_contents = true

		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.18, 0.18, 0.2, 0.8)
		slot_style.set_corner_radius_all(4)

		if slot_data != null and slot_data is Dictionary:
			var item: ItemData = slot_data.get("item", null)
			var amount = int(slot_data.get("amount", 1))
			if item:
				var r_color = get_rarity_color(item.rarity)
				if r_color != Color.TRANSPARENT:
					slot_style.border_color = r_color
					slot_style.set_border_width_all(1)

				if item.mesh_scene:
					var icon = create_item_3d_viewport(item.mesh_scene, item)
					slot_btn.add_child(icon)
				if amount > 1:
					var lbl = Label.new()
					lbl.text = str(amount)
					lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
					lbl.offset_right = -4
					lbl.offset_bottom = -2
					lbl.add_theme_font_size_override("font_size", 10)
					slot_btn.add_child(lbl)
					
				var idx = i
				slot_btn.pressed.connect(func(): show_warehouse_quantity_dialog(item, idx, amount, true))

		slot_btn.add_theme_stylebox_override("normal", slot_style)
		grid.add_child(slot_btn)

# Janela customizada de quantidade (igualzinha à da loja) para mover itens
func show_warehouse_quantity_dialog(item: ItemData, slot_idx: int, max_limit: int, is_depositing: bool) -> void:
	if not warehouse_window:
		return

	var popup_panel = PopupPanel.new()
	popup_panel.title = "Guardar no Armazém" if is_depositing else "Retirar do Armazém"
	popup_panel.size = Vector2i(320, 180)
	
	var theme = load("res://ASSETS/VFX/Themes/ValliryaTheme_Final.tres")
	if theme:
		popup_panel.theme = theme
	warehouse_window.add_child(popup_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 15
	vbox.offset_right = -15
	vbox.offset_top = 15
	vbox.offset_bottom = -15
	popup_panel.add_child(vbox)

	var title_action = Label.new()
	title_action.text = ("Guardar: %s" % item.name) if is_depositing else ("Retirar: %s" % item.name)
	title_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_action.modulate = Color(1.0, 0.85, 0.3)
	vbox.add_child(title_action)

	var qty_hbox = HBoxContainer.new()
	qty_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(qty_hbox)

	var qty_label = Label.new()
	qty_label.text = "Quantidade:"
	qty_hbox.add_child(qty_label)

	var qty_input = LineEdit.new()
	qty_input.custom_minimum_size = Vector2(80, 35)
	qty_input.text = str(max_limit) # Começa sugerindo a quantidade máxima do slot
	qty_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_hbox.add_child(qty_input)

	qty_input.text_changed.connect(func(new_text):
		var typed_qty = int(new_text)
		if typed_qty < 1:
			typed_qty = 1
		if typed_qty > max_limit:
			qty_input.text = str(max_limit)
	)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(btn_hbox)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirmar"
	confirm_btn.custom_minimum_size = Vector2(100, 35)
	btn_hbox.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.custom_minimum_size = Vector2(100, 35)
	btn_hbox.add_child(cancel_btn)

	confirm_btn.pressed.connect(func():
		var final_qty = int(qty_input.text)
		if final_qty > 0:
			if is_depositing:
				transfer_player_to_warehouse(slot_idx, final_qty)
			else:
				transfer_warehouse_to_player(slot_idx, final_qty)
		popup_panel.queue_free()
	)

	cancel_btn.pressed.connect(func():
		popup_panel.queue_free()
	)

	popup_panel.popup_centered()

# Lógica de transferência: Player -> Armazém
func transfer_player_to_warehouse(player_slot_idx: int, quantity: int) -> void:
	var p_slot = active_player.inventory_items[player_slot_idx]
	if not p_slot: return
	
	var item = p_slot["item"]
	var available_amt = p_slot["amount"]
	var move_amt = min(quantity, available_amt)
	
	# 1. Tenta empilhar no armazém se o item for stackable
	var remaining = move_amt
	if item.is_stackable:
		for i in range(active_player.warehouse_items.size()):
			var w_slot = active_player.warehouse_items[i]
			if w_slot != null and w_slot["item"].id == item.id:
				w_slot["amount"] += remaining
				remaining = 0
				break
				
	# 2. Se sobrou quantidade, coloca em um slot vazio do armazém
	if remaining > 0:
		for i in range(active_player.warehouse_items.size()):
			if active_player.warehouse_items[i] == null:
				# Duplica o item mantendo os status/raridade intactos
				var copied_item = item.duplicate()
				active_player.warehouse_items[i] = {"item": copied_item, "amount": remaining}
				remaining = 0
				break
				
	# Subtrai do inventário do player o que foi efetivamente movido
	var successfully_moved = move_amt - remaining
	p_slot["amount"] -= successfully_moved
	if p_slot["amount"] <= 0:
		active_player.inventory_items[player_slot_idx] = null
		
	active_player.update_inventory_display()
	create_warehouse_ui() # Atualiza a UI do armazém

# Lógica de transferência: Armazém -> Player
func transfer_warehouse_to_player(warehouse_slot_idx: int, quantity: int) -> void:
	var w_slot = active_player.warehouse_items[warehouse_slot_idx]
	if not w_slot: return
	
	var item = w_slot["item"]
	var available_amt = w_slot["amount"]
	var move_amt = min(quantity, available_amt)
	
	# Tenta adicionar ao inventário do player
	var added_successfully = active_player.add_item_to_inventory(item, move_amt)
	
	# Se adicionou com sucesso (ou parcialmente), remove do armazém
	if added_successfully: # Se o inventário aceitou tudo
		w_slot["amount"] -= move_amt
		if w_slot["amount"] <= 0:
			active_player.warehouse_items[warehouse_slot_idx] = null
	else:
		# Se o inventário encheu no meio do processo, recalcula quanto coube
		# (Opcional: você pode ajustar o add_item_to_inventory para retornar a qtd exata adicionada)
		pass
		
	active_player.update_inventory_display()
	create_warehouse_ui()
