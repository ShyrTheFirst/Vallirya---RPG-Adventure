class_name NpcComerciante
extends NpcBase

@export_category("Configuração de Comércio")
@export var merchant_name: String = "Comerciante Silas"
@export var merchant_stock: Array[ItemData] = [] # Itens à venda

@export_category("Configuração de Missões do Comerciante")
@export var managed_quests: Array[QuestData] = [] # Fila de missões

var shop_window: Control = null
var active_player: CharacterBody3D = null
var stored_action_type: String = ""
var stored_quest_to_action: String = ""
var is_turn_in_action: bool = false

func get_current_quest_status() -> QuestStatus:
	var player = get_tree().get_first_node_in_group("Player")
	if not player or managed_quests.is_empty():
		return QuestStatus.NONE

	for q_data in managed_quests:
		if not q_data:
			continue
		var q_id = q_data.quest_id
		
		if player.completed_quests.has(q_id):
			continue
			
		var is_active = false
		var is_completed = false
		for active_q in player.client_active_quests:
			if active_q.get("id", "") == q_id:
				is_active = true
				is_completed = active_q.get("completed", false)
				break

		if is_active:
			if q_data.quest_type == QuestData.QuestType.TALK_TO_NPC or is_completed:
				return QuestStatus.READY_TO_TURN_IN
			return QuestStatus.IN_PROGRESS
		else:
			return QuestStatus.AVAILABLE

	return QuestStatus.NONE

func handle_npc_dialogue_flow(player: CharacterBody3D) -> void:
	if not active_ui_instance:
		return

	if not active_ui_instance.is_connected("continue_dialogue_pressed", _on_continue_pressed):
		active_ui_instance.continue_dialogue_pressed.connect(_on_continue_pressed)
	if not active_ui_instance.is_connected("quest_accepted", _on_quest_accepted):
		active_ui_instance.quest_accepted.connect(_on_quest_accepted)
	if not active_ui_instance.is_connected("quest_denied", _on_quest_denied):
		active_ui_instance.quest_denied.connect(_on_quest_denied)

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
			QuestManager.on_npc_talked(player, npc_id)
			target_quest = q_data
			quest_state = "turn_in"
			break
		else:
			target_quest = q_data
			quest_state = "available"
			break

	if quest_state == "turn_in":
		active_ui_instance.set_message(npc_name, "Ah, um novo aventureiro na guilda! Dê uma olhada nas minhas mercadorias quando precisar de suprimentos.", "Abrir Loja")
		stored_quest_to_action = target_quest.quest_id
		is_turn_in_action = false
		stored_action_type = "open_shop"
	elif quest_state == "available" and target_quest:
		active_ui_instance.set_quest_offer(npc_name, "Tenho um negócio lucrativo para você, aventureiro:", target_quest, true)
		stored_quest_to_action = ""
		is_turn_in_action = false
		stored_action_type = ""
	else:
		active_ui_instance.set_message(
			npc_name, 
			"Ah, um viajante! Tenho as melhores mercadorias de Kalythra à venda, ou posso comprar seus achados.", 
			"Abrir Loja"
		)
		stored_quest_to_action = ""
		is_turn_in_action = false
		stored_action_type = "open_shop"

func _on_continue_pressed() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	var should_open_shop = (stored_action_type == "open_shop")

	if player and stored_quest_to_action != "" and is_turn_in_action:
		var has_it = false
		for q in player.client_active_quests:
			if q.get("id", "") == stored_quest_to_action:
				has_it = true
				break
		if not has_it:
			QuestManager.assign_quest(player, stored_quest_to_action)
		
		var q_data = QuestManager.quests_database.get(stored_quest_to_action, null)
		if q_data and q_data.quest_type == QuestData.QuestType.TALK_TO_NPC:
			QuestManager.on_npc_talked(player, npc_id)

		QuestManager.complete_and_turn_in_quest(player, stored_quest_to_action)
		stored_quest_to_action = ""
		is_turn_in_action = false
	
	stored_action_type = ""
	close_dialogue_ui()
	update_visual_quest_status()

	if should_open_shop and player:
		toggle_shop_window(player)

func _on_quest_accepted(quest_data: QuestData) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and quest_data:
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
#  LÓGICA DA JANELA DE COMPRA E VENDA DO COMERCIANTE
# =====================================================================

func toggle_shop_window(player_node: CharacterBody3D) -> void:
	if is_instance_valid(shop_window):
		shop_window.queue_free()
		shop_window = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		active_player = null
	else:
		active_player = player_node
		create_shop_ui()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func create_shop_ui(default_tab: int = 0) -> void:
	if is_instance_valid(shop_window):
		shop_window.queue_free()

	shop_window = Control.new()
	shop_window.name = "ShopWindow"
	shop_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_window.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().current_scene.add_child(shop_window)

	var bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.75)
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_window.add_child(bg_overlay)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(750, 580)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -375
	panel.offset_right = 375
	panel.offset_top = -290
	panel.offset_bottom = 290
	
	var theme = load("res://ASSETS/VFX/Themes/ValliryaTheme_Final.tres")
	if theme:
		panel.theme = theme
	shop_window.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "--- LOJA: %s ---" % merchant_name.to_upper()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var balance_lbl = Label.new()
	balance_lbl.text = "Seu Saldo: %s" % format_bronze_to_text(get_player_total_bronze())
	balance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_lbl.modulate = Color(1.0, 0.85, 0.3)
	balance_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(balance_lbl)

	var tab_container = TabContainer.new()
	tab_container.custom_minimum_size = Vector2(710, 440)
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tab_container)

	# --- ABA 1: COMPRAR ---
	var buy_scroll = ScrollContainer.new()
	buy_scroll.name = "Comprar"
	tab_container.add_child(buy_scroll)

	var buy_grid = GridContainer.new()
	buy_grid.columns = 4
	buy_grid.add_theme_constant_override("h_separation", 16)
	buy_grid.add_theme_constant_override("v_separation", 16)
	buy_scroll.add_child(buy_grid)

	populate_buy_grid(buy_grid)

	# --- ABA 2: VENDER ---
	var sell_scroll = ScrollContainer.new()
	sell_scroll.name = "Vender"
	tab_container.add_child(sell_scroll)

	var sell_grid = GridContainer.new()
	sell_grid.columns = 4
	sell_grid.add_theme_constant_override("h_separation", 16)
	sell_grid.add_theme_constant_override("v_separation", 16)
	sell_scroll.add_child(sell_grid)

	populate_sell_grid(sell_grid)

	tab_container.current_tab = default_tab

	var close_btn = Button.new()
	close_btn.text = "Fechar Loja"
	close_btn.custom_minimum_size = Vector2(0, 35)
	close_btn.pressed.connect(func(): toggle_shop_window(null))
	vbox.add_child(close_btn)

func create_item_3d_viewport(mesh_scene: PackedScene, item_data: ItemData = null) -> Control:
	var icon_scene = preload("res://Scenes/Inventario/item_icon_3d.tscn")
	var icon_instance = icon_scene.instantiate() as Control
	icon_instance.custom_minimum_size = Vector2(60, 60)
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
		ItemData.Rarity.UNCOMMON: return Color(0.2, 0.8, 0.2)  # Verde
		ItemData.Rarity.RARE: return Color(0.2, 0.5, 1.0)      # Azul
		ItemData.Rarity.EPIC: return Color(0.6, 0.2, 0.8)      # Roxo
		ItemData.Rarity.LEGENDARY: return Color(1.0, 0.6, 0.1) # Laranja
	return Color.TRANSPARENT

func populate_buy_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()

	var player_total_bronze = get_player_total_bronze()

	for item in merchant_stock:
		if not item:
			continue

		var item_vbox = VBoxContainer.new()
		item_vbox.custom_minimum_size = Vector2(155, 115)
		item_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		item_vbox.add_theme_constant_override("separation", 4)

		var name_lbl = Label.new()
		name_lbl.text = item.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		item_vbox.add_child(name_lbl)

		var center_box = CenterContainer.new()
		item_vbox.add_child(center_box)

		var icon_btn = Button.new()
		icon_btn.custom_minimum_size = Vector2(60, 60)
		icon_btn.focus_mode = Control.FOCUS_NONE
		icon_btn.clip_contents = true

		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.18, 0.18, 0.2, 0.8)
		slot_style.set_corner_radius_all(4)
		
		var r_color = get_rarity_color(item.rarity)
		if r_color != Color.TRANSPARENT:
			slot_style.border_color = r_color
			slot_style.set_border_width_all(1)

		icon_btn.add_theme_stylebox_override("normal", slot_style)
		
		if item.mesh_scene:
			var icon_3d = create_item_3d_viewport(item.mesh_scene, item)
			icon_btn.add_child(icon_3d)

		center_box.add_child(icon_btn)

		var price_lbl = Label.new()
		price_lbl.text = "%d Bronze" % item.sell_price
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_lbl.add_theme_font_size_override("font_size", 11)

		if player_total_bronze >= item.sell_price:
			price_lbl.modulate = Color.WHITE
			icon_btn.pressed.connect(func(): show_quantity_dialog(item, true, -1, 99999))
		else:
			price_lbl.modulate = Color.RED
			icon_btn.pressed.connect(func():
				if active_player and active_player.has_method("send_message_HUD"):
					active_player.send_message_HUD("Moedas insuficientes!", Color.RED)
			)

		item_vbox.add_child(price_lbl)
		grid.add_child(item_vbox)

func populate_sell_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()

	if not active_player or not "inventory_items" in active_player:
		return

	for i in range(active_player.inventory_items.size()):
		var slot = active_player.inventory_items[i]
		if slot == null or not slot is Dictionary:
			continue

		var item: ItemData = slot.get("item", null)
		var amount: int = int(slot.get("amount", 1))
		if not item:
			continue

		var path_lower = item.resource_path.to_lower()
		if "moeda_bronze" in path_lower or "moeda_prata" in path_lower or "moeda_ouro" in path_lower:
			continue
		if "is_quest_item" in item and item.is_quest_item:
			continue

		var item_vbox = VBoxContainer.new()
		item_vbox.custom_minimum_size = Vector2(155, 115)
		item_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		item_vbox.add_theme_constant_override("separation", 4)

		var name_lbl = Label.new()
		name_lbl.text = "%s (x%d)" % [item.name, amount] if amount > 1 else item.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		item_vbox.add_child(name_lbl)

		var center_box = CenterContainer.new()
		item_vbox.add_child(center_box)

		var icon_btn = Button.new()
		icon_btn.custom_minimum_size = Vector2(60, 60)
		icon_btn.focus_mode = Control.FOCUS_NONE
		icon_btn.clip_contents = true

		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.18, 0.18, 0.2, 0.8)
		slot_style.set_corner_radius_all(4)
		
		var r_color = get_rarity_color(item.rarity)
		if r_color != Color.TRANSPARENT:
			slot_style.border_color = r_color
			slot_style.set_border_width_all(1)

		icon_btn.add_theme_stylebox_override("normal", slot_style)
		
		if item.mesh_scene:
			var icon_3d = create_item_3d_viewport(item.mesh_scene, item)
			icon_btn.add_child(icon_3d)

		center_box.add_child(icon_btn)

		var sell_value = max(1, int(item.sell_price * 0.75))
		var price_lbl = Label.new()
		price_lbl.text = "Vender: %d Bronze" % sell_value
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_lbl.add_theme_font_size_override("font_size", 11)
		price_lbl.modulate = Color(1.0, 0.85, 0.3)

		var slot_idx = i
		icon_btn.pressed.connect(func(): show_quantity_dialog(item, false, slot_idx, amount))

		item_vbox.add_child(price_lbl)
		grid.add_child(item_vbox)


# =====================================================================
#  JANELA CUSTOMIZADA DE SELEÇÃO DE QUANTIDADE (COMPRA / VENDA)
# =====================================================================

func show_quantity_dialog(item: ItemData, is_buying: bool, slot_idx: int, max_limit: int) -> void:
	if not shop_window:
		return

	var unit_price = item.sell_price if is_buying else max(1, int(item.sell_price * 0.75))
	
	var popup_panel = PopupPanel.new()
	popup_panel.title = "Comprar Item" if is_buying else "Vender Item"
	popup_panel.size = Vector2i(320, 200)
	
	var theme = load("res://ASSETS/VFX/Themes/ValliryaTheme_Final.tres")
	if theme:
		popup_panel.theme = theme
	shop_window.add_child(popup_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 15
	vbox.offset_right = -15
	vbox.offset_top = 15
	vbox.offset_bottom = -15
	popup_panel.add_child(vbox)

	var title_action = Label.new()
	title_action.text = ("Comprar: %s" % item.name) if is_buying else ("Vender: %s" % item.name)
	title_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_action.modulate = Color(1.0, 0.85, 0.3)
	vbox.add_child(title_action)

	# Linha do LineEdit para quantidade
	var qty_hbox = HBoxContainer.new()
	qty_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(qty_hbox)

	var qty_label = Label.new()
	qty_label.text = "Quantidade:"
	qty_hbox.add_child(qty_label)

	var qty_input = LineEdit.new()
	qty_input.custom_minimum_size = Vector2(80, 35)
	qty_input.text = "1"
	qty_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_hbox.add_child(qty_input)

	# Linha do Valor Total
	var total_lbl = Label.new()
	total_lbl.text = "Valor total: %d moedas" % unit_price
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(total_lbl)

	# Atualiza o preço total dinamicamente conforme o player digita
	qty_input.text_changed.connect(func(new_text):
		var typed_qty = int(new_text)
		if typed_qty < 1:
			typed_qty = 1
		if typed_qty > max_limit:
			typed_qty = max_limit
			qty_input.text = str(max_limit)
		var total_cost = typed_qty * unit_price
		total_lbl.text = "Valor total: %d moedas" % total_cost
	)

	# Botões Comprar/Vender e Cancelar
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 15)
	vbox.add_child(btn_hbox)

	var confirm_btn = Button.new()
	confirm_btn.text = "Comprar" if is_buying else "Vender"
	confirm_btn.custom_minimum_size = Vector2(100, 35)
	btn_hbox.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.custom_minimum_size = Vector2(100, 35)
	btn_hbox.add_child(cancel_btn)

	confirm_btn.pressed.connect(func():
		var final_qty = int(qty_input.text)
		if final_qty > 0:
			if is_buying:
				buy_item_quantity(item, final_qty)
			else:
				sell_item_quantity(slot_idx, final_qty, unit_price)
		popup_panel.queue_free()
	)

	cancel_btn.pressed.connect(func():
		popup_panel.queue_free()
	)

	popup_panel.popup_centered()


# =====================================================================
#  TRANSAÇÕES EM LOTE (QUANTIDADE ESPECIFICADA)
# =====================================================================

func buy_item_quantity(item: ItemData, quantity: int) -> void:
	if not active_player or not active_player.has_method("add_item_to_inventory"):
		return

	var total_cost = item.sell_price * quantity
	if deduct_player_bronze(total_cost):
		active_player.add_item_to_inventory(item, quantity)
		if active_player.has_method("send_message_HUD"):
			active_player.send_message_HUD("Comprou %dx %s!" % [quantity, item.name], Color(0.4, 1.0, 0.4))
		if active_player.has_method("save_player_account"):
			active_player.save_player_account()
		create_shop_ui(0)
	else:
		if active_player.has_method("send_message_HUD"):
			active_player.send_message_HUD("Moedas insuficientes para essa quantidade!", Color.RED)

func sell_item_quantity(slot_idx: int, quantity: int, unit_payout: int) -> void:
	if not active_player or not "inventory_items" in active_player:
		return

	if slot_idx < 0 or slot_idx >= active_player.inventory_items.size():
		return

	var slot = active_player.inventory_items[slot_idx]
	if slot == null:
		return

	var current_amt = int(slot.get("amount", 1))
	var remove_amt = min(quantity, current_amt)

	slot["amount"] -= remove_amt
	if slot["amount"] <= 0:
		active_player.inventory_items[slot_idx] = null

	var total_payout = remove_amt * unit_payout
	var new_total_bronze = get_player_total_bronze() + total_payout
	set_player_total_bronze(new_total_bronze)

	if active_player.has_method("send_message_HUD"):
		active_player.send_message_HUD("Vendeu %dx itens por %d Bronze!" % [remove_amt, total_payout], Color(1.0, 0.85, 0.3))
	if active_player.has_method("save_player_account"):
		active_player.save_player_account()

	create_shop_ui(1)


# =====================================================================
#  SISTEMA DE MOEDAS E TROCO AUTOMÁTICO
# =====================================================================

func get_player_total_bronze() -> int:
	if not active_player or not "inventory_items" in active_player:
		return 0

	var total = 0
	for slot in active_player.inventory_items:
		if slot != null and slot is Dictionary:
			var item: ItemData = slot.get("item", null)
			var amt = int(slot.get("amount", 1))
			if item:
				var path = item.resource_path.to_lower()
				var item_name = item.name if "name" in item else ""
				
				if "Moeda_Bronze_1" in path or "Moeda de Bronze" in item_name or "Moeda_Bronze_1" in path:
					total += amt
				elif "Moeda_Prata_1" in path or "Moeda de Prata" in item_name or "Moeda_Prata_1" in path or "Moeda_Prata_1" in path:
					total += amt * 100
				elif "Moeda_Ouro_1" in path or "Moeda de Ouro" in item_name or "Moeda_Ouro_1" in path or "Moeda_Ouro_1" in path:
					total += amt * 10000
	return total

func deduct_player_bronze(cost_in_bronze: int) -> bool:
	var current_total = get_player_total_bronze()
	if current_total < cost_in_bronze:
		return false

	var remaining_balance = current_total - cost_in_bronze
	set_player_total_bronze(remaining_balance)
	return true

func set_player_total_bronze(total_bronze: int) -> void:
	if not active_player or not "inventory_items" in active_player:
		return

	for i in range(active_player.inventory_items.size()):
		var slot = active_player.inventory_items[i]
		if slot != null and slot is Dictionary:
			var item: ItemData = slot.get("item", null)
			if item:
				var path = item.resource_path.to_lower()
				if "moeda_bronze" in path or "moeda_prata" in path or "moeda_ouro" in path:
					active_player.inventory_items[i] = null

	var gold_coins = int(total_bronze / 10000)
	var remainder = total_bronze % 10000
	var silver_coins = int(remainder / 100)
	var bronze_coins = remainder % 100

	if gold_coins > 0:
		var item_gold = load("res://Resources/Items/Moeda_Ouro_1.tres")
		if item_gold:
			active_player.add_item_to_inventory(item_gold, gold_coins)
	if silver_coins > 0:
		var item_silver = load("res://Resources/Items/Moeda_Prata_1.tres")
		if item_silver:
			active_player.add_item_to_inventory(item_silver, silver_coins)
	if bronze_coins > 0:
		var item_bronze = load("res://Resources/Items/Moeda_Bronze_1.tres")
		if item_bronze:
			active_player.add_item_to_inventory(item_bronze, bronze_coins)

	if active_player.has_method("update_inventory_display"):
		active_player.update_inventory_display()

func format_bronze_to_text(total_bronze: int) -> String:
	var gold = int(total_bronze / 10000)
	var rem = total_bronze % 10000
	var silver = int(rem / 100)
	var bronze = rem % 100
	return "%d Ouro | %d Prata | %d Bronze" % [gold, silver, bronze]
