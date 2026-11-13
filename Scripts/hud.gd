class_name HUD
extends Control

@export_category("Referências de UI")
@export var inventory_button: Button
@export var status_button: Button
@export var quest_button: Button

var potion_cooldown_timer: float = 0.0
const POTION_COOLDOWN_DURATION: float = 1.5 # Segundos de espera entre poções


# Variáveis para guardar os dados salvos caso o player ainda não exista no _ready
var pending_saved_skills: Dictionary = {}
var pending_saved_potions: Dictionary = {}
var pending_all_skills_dict: Dictionary = {}
var has_pending_load: bool = false

# Dicionário que guarda qual SkillData está em qual atalho (1 a 5)
var equipped_skill_slots: Dictionary = {
	1: null,
	2: null,
	3: null,
	4: null,
	5: null
}

# Dicionário que guarda o ItemData específico atribuído aos atalhos de poção ("hp" e "mp")
var equipped_potion_items: Dictionary = {
	"hp": null, # ItemData da poção de HP escolhida (Atalho Z)
	"mp": null  # ItemData da poção de MP escolhida (Atalho X)
}

# Referências visuais geradas por código para os contadores e slots
var hp_count_label: Label = null
var mp_count_label: Label = null
var hp_slot_container: Control = null
var mp_slot_container: Control = null

@onready var player_ref: CharacterBody3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	setup_menu_buttons()
	build_action_bar_ui()
	update_potion_display()

func _process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().current_scene.find_child("Player", true, false)
	else:
		if has_pending_load and "inventory_items" in player_ref:
			load_saved_data(pending_saved_skills, pending_saved_potions, pending_all_skills_dict)
		update_potion_display()
	
	if potion_cooldown_timer > 0.0:
		potion_cooldown_timer -= delta
	
	update_action_bar_cooldown_displays(delta)

func setup_menu_buttons() -> void:
	if inventory_button:
		inventory_button.pressed.connect(func():
			if is_instance_valid(player_ref) and player_ref.has_method("toggle_inventory_window"):
				player_ref.toggle_inventory_window()
		)
	
	if status_button:
		status_button.pressed.connect(func():
			if is_instance_valid(player_ref) and player_ref.has_method("toggle_attribute_window"):
				player_ref.toggle_attribute_window()
		)
		
	if quest_button:
		quest_button.pressed.connect(func():
			if is_instance_valid(player_ref) and player_ref.has_method("toggle_quest_window"):
				player_ref.toggle_quest_window()
		)

# --- GERAÇÃO VISUAL DA BARRA DE AÇÃO E HABILIDADES POR CÓDIGO ---
func build_action_bar_ui() -> void:
	var existing_bar = get_node_or_null("ActionBarPanel")
	if existing_bar:
		existing_bar.queue_free()

	var action_bar_panel = PanelContainer.new()
	action_bar_panel.name = "ActionBarPanel"
	action_bar_panel.custom_minimum_size = Vector2(440, 75)
	
	var custom_theme = load("res://ASSETS/VFX/Themes/ValliryaTheme_Final.tres")
	if custom_theme: 
		action_bar_panel.theme = custom_theme
		
	add_child(action_bar_panel)
	
	action_bar_panel.anchor_left = 0.5
	action_bar_panel.anchor_right = 0.5
	action_bar_panel.anchor_top = 1.0
	action_bar_panel.anchor_bottom = 1.0
	
	action_bar_panel.offset_left = -220
	action_bar_panel.offset_right = 220
	action_bar_panel.offset_top = -95
	action_bar_panel.offset_bottom = -20

	var bar_hbox = HBoxContainer.new()
	bar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_hbox.add_theme_constant_override("separation", 10)
	action_bar_panel.add_child(bar_hbox)

	# --- GRUPO DE POÇÕES (Z para HP e X para MP) ---
	var potion_container = HBoxContainer.new()
	potion_container.add_theme_constant_override("separation", 6)
	bar_hbox.add_child(potion_container)

	var potion_slots_data = [
		{"key": "hp", "label": "Z", "color": Color(0.8, 0.2, 0.2)},
		{"key": "mp", "label": "X", "color": Color(0.2, 0.4, 0.9)}
	]

	for p_data in potion_slots_data:
		var slot_vbox = VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 2)
		
		var slot_btn = Button.new()
		slot_btn.name = "PotionSlot_" + p_data["key"]
		slot_btn.custom_minimum_size = Vector2(50, 50)
		slot_btn.focus_mode = Control.FOCUS_NONE
		slot_btn.clip_contents = true
		
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
		p_style.set_corner_radius_all(4)
		p_style.set_border_width_all(1)
		p_style.border_color = p_data["color"]
		slot_btn.add_theme_stylebox_override("normal", p_style)

		# Container interno para receber o modelo 3D da poção atribuída
		var item_place_node = Control.new()
		item_place_node.name = "ItemPlace"
		item_place_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		item_place_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(item_place_node)

		# --- RÓTULO DE COOLDOWN DA POÇÃO ---
		var cd_lbl = Label.new()
		cd_lbl.name = "CooldownLabel"
		cd_lbl.text = ""
		cd_lbl.add_theme_font_size_override("font_size", 16)
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2)) # Amarelo destaque
		cd_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		cd_lbl.add_theme_constant_override("outline_size", 3)
		cd_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(cd_lbl)

		# Label com a quantidade da poção específica em cima do botão
		var count_lbl = Label.new()
		count_lbl.text = "0"
		count_lbl.add_theme_font_size_override("font_size", 11)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		count_lbl.add_theme_constant_override("outline_size", 2)
		
		if p_data["key"] == "hp":
			hp_count_label = count_lbl
			hp_slot_container = item_place_node
		else:
			mp_count_label = count_lbl
			mp_slot_container = item_place_node
			
		slot_btn.add_child(count_lbl)
		count_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		count_lbl.offset_right = -4
		count_lbl.offset_bottom = -2

		var key_lbl = Label.new()
		key_lbl.text = p_data["label"]
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.modulate = Color(0.8, 0.8, 0.8)
		
		slot_vbox.add_child(slot_btn)
		slot_vbox.add_child(key_lbl)
		potion_container.add_child(slot_vbox)

	var sep = VSeparator.new()
	bar_hbox.add_child(sep)

	# --- GRUPO DE HABILIDADES (1 a 5) ---
	var skill_container = HBoxContainer.new()
	skill_container.add_theme_constant_override("separation", 6)
	bar_hbox.add_child(skill_container)

	for i in range(1, 6):
		var slot_vbox = VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 2)
		
		var slot_btn = Button.new()
		slot_btn.name = "SkillSlot_" + str(i)
		slot_btn.custom_minimum_size = Vector2(50, 50)
		slot_btn.focus_mode = Control.FOCUS_NONE
		slot_btn.clip_contents = true
		
		var s_style = StyleBoxFlat.new()
		s_style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
		s_style.set_corner_radius_all(4)
		s_style.set_border_width_all(1)
		s_style.border_color = Color(0.5, 0.4, 0.2)
		slot_btn.add_theme_stylebox_override("normal", s_style)

		# TextureRect interno para receber o ícone da SkillData
		var icon_rect = TextureRect.new()
		icon_rect.name = "IconRect"
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(icon_rect)

		# --- RÓTULO DE COOLDOWN DA SKILL ---
		var cd_lbl = Label.new()
		cd_lbl.name = "CooldownLabel"
		cd_lbl.text = ""
		cd_lbl.add_theme_font_size_override("font_size", 16)
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2)) # Amarelo destaque
		cd_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		cd_lbl.add_theme_constant_override("outline_size", 3)
		cd_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_btn.add_child(cd_lbl)

		var key_lbl = Label.new()
		key_lbl.text = str(i)
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.modulate = Color(0.8, 0.8, 0.8)
		
		slot_vbox.add_child(slot_btn)
		slot_vbox.add_child(key_lbl)
		skill_container.add_child(slot_vbox)

# Atalhos de teclado
func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player_ref) or player_ref.is_dead:
		return

	if event.is_action_pressed("Magia1"): use_skill_slot(1)
	elif event.is_action_pressed("Magia2"): use_skill_slot(2)
	elif event.is_action_pressed("Magia3"): use_skill_slot(3)
	elif event.is_action_pressed("Magia4"): use_skill_slot(4)
	elif event.is_action_pressed("Magia5"): use_skill_slot(5)
	
	elif event.is_action_pressed("HPPotion") or (event is InputEventKey and event.pressed and event.keycode == KEY_Z): use_potion("hp")
	elif event.is_action_pressed("MPPotion") or (event is InputEventKey and event.pressed and event.keycode == KEY_X): use_potion("mp")

func use_skill_slot(slot_index: int) -> void:
	var skill_data: SkillData = equipped_skill_slots.get(slot_index, null)
	if not skill_data:
		print("[HUD] Atalho ", slot_index, " está vazio!")
		return
		
	if is_instance_valid(player_ref) and player_ref.has_method("try_cast_spell"):
		player_ref.try_cast_spell(skill_data)

func assign_skill_to_action_bar(slot_index: int, skill_data: SkillData) -> void:
	if equipped_skill_slots.has(slot_index):
		equipped_skill_slots[slot_index] = skill_data
		print("[HUD] Habilidade %s equipada no atalho %d" % [skill_data.skill_name, slot_index])
		
		# Atualiza o ícone visual na barra rápida
		var action_bar = get_node_or_null("ActionBarPanel")
		if action_bar:
			var slot_btn = action_bar.find_child("SkillSlot_" + str(slot_index), true, false)
			if slot_btn:
				var icon_rect = slot_btn.get_node_or_null("IconRect") as TextureRect
				if icon_rect and skill_data.icon:
					icon_rect.texture = skill_data.icon

# --- ATRIBUIÇÃO DE POÇÕES ESPECÍFICAS (Z / X) ---
func assign_potion_to_slot(potion_type: String, item_data: ItemData) -> void:
	if not equipped_potion_items.has(potion_type):
		return
		
	equipped_potion_items[potion_type] = item_data
	print("[HUD] Poção %s atribuída ao atalho %s" % [item_data.name if item_data else "Nenhuma", potion_type.to_upper()])
	
	# Atualiza o visual 3D da poção no slot correspondente
	var container = hp_slot_container if potion_type == "hp" else mp_slot_container
	if container:
		for child in container.get_children():
			child.queue_free()
			
		if item_data and item_data.mesh_scene and is_instance_valid(player_ref) and player_ref.has_method("create_item_3d_viewport"):
			var icon_3d = player_ref.create_item_3d_viewport(item_data.mesh_scene, item_data)
			icon_3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			container.add_child(icon_3d)

	update_potion_display()

# --- CONTAGEM E USO DAS POÇÕES ESPECÍFICAS ---
func update_potion_display() -> void:
	if not is_instance_valid(player_ref) or not "inventory_items" in player_ref:
		return
		
	# Calcula quantidade da poção de HP atribuída
	var hp_item: ItemData = equipped_potion_items.get("hp", null)
	var hp_count = 0
	if hp_item:
		for slot in player_ref.inventory_items:
			if slot != null and slot is Dictionary:
				var item: ItemData = slot.get("item", null)
				if item and item.id == hp_item.id:
					hp_count += int(slot.get("amount", 1))
	if hp_count_label:
		hp_count_label.text = str(hp_count)

	# Calcula quantidade da poção de MP atribuída
	var mp_item: ItemData = equipped_potion_items.get("mp", null)
	var mp_count = 0
	if mp_item:
		for slot in player_ref.inventory_items:
			if slot != null and slot is Dictionary:
				var item: ItemData = slot.get("item", null)
				if item and item.id == mp_item.id:
					mp_count += int(slot.get("amount", 1))
	if mp_count_label:
		mp_count_label.text = str(mp_count)

func use_potion(type: String) -> void:
	if not is_instance_valid(player_ref) or not "inventory_items" in player_ref: 
		return

	if potion_cooldown_timer > 0.0:
		print("[HUD] Poção em recarga! Aguarde um instante.")
		return
		
	var target_item: ItemData = equipped_potion_items.get(type, null)
	if not target_item:
		print("[HUD] Nenhuma poção atribuída ao atalho %s!" % type.to_upper())
		return

	var target_id = str(target_item.id).strip_edges()

	# Varre o inventário em busca do slot que contenha o item com o mesmo ID (String)
	for i in range(player_ref.inventory_items.size()):
		var slot = player_ref.inventory_items[i]
		if slot != null and slot is Dictionary:
			var item: ItemData = slot.get("item", null)
			if item and str(item.id).strip_edges() == target_id:
				
				# Executa a animação e o efeito de cura/mana no player
				if type == "hp":
					if player_ref.has_method("drink_potion"):
						player_ref.drink_potion(item)
					player_ref.heal(item.bonus_hp if item.bonus_hp > 0 else 50, item)
					potion_cooldown_timer = POTION_COOLDOWN_DURATION
				else:
					if player_ref.has_method("drink_potion"):
						player_ref.drink_potion(item)
					player_ref.restore_mana(item.bonus_mana if item.bonus_mana > 0 else 30, item)
					potion_cooldown_timer = POTION_COOLDOWN_DURATION
				
				# Reduz a quantidade daquele slot específico
				slot["amount"] -= 1
				if slot["amount"] <= 0:
					player_ref.inventory_items[i] = null
					# Se acabaram as unidades, limpa o atalho do HUD
					equipped_potion_items[type] = null
				
				if player_ref.has_method("update_inventory_display"):
					player_ref.update_inventory_display()
					
				update_potion_display()
				return
				
	print("[HUD] Acabaram as unidades da poção atribuída no atalho %s!" % type.to_upper())
	equipped_potion_items[type] = null
	update_potion_display()

func load_saved_data(saved_skills: Dictionary, saved_potions: Dictionary, all_skills_dict: Dictionary) -> void:
	if not is_instance_valid(player_ref) or not "inventory_items" in player_ref:
		has_pending_load = true
		pending_saved_skills = saved_skills
		pending_saved_potions = saved_potions
		pending_all_skills_dict = all_skills_dict
		return

# 1. Restaura as skills na barra rápida extraindo o caminho do recurso salvo
	for slot_key in saved_skills:
		var slot_idx = int(str(slot_key).strip_edges())
		var raw_skill_val = str(saved_skills[slot_key]).strip_edges()
		
		if raw_skill_val == "" or raw_skill_val == "null" or raw_skill_val == "-1" or raw_skill_val == "0":
			continue
			
		var skill_resource_path = ""
		if "res://" in raw_skill_val:
			var start_idx = raw_skill_val.find("res://")
			var end_idx = raw_skill_val.find(".tres")
			if start_idx != -1 and end_idx != -1:
				skill_resource_path = raw_skill_val.substr(start_idx, (end_idx + 5) - start_idx)
		
		if skill_resource_path != "" and ResourceLoader.exists(skill_resource_path):
			var loaded_skill = load(skill_resource_path) as SkillData
			if loaded_skill:
				assign_skill_to_action_bar(slot_idx, loaded_skill)

	# 2. Restaura as poções extraindo o caminho .tres de dentro da string salva
	for p_key in saved_potions:
		var raw_value = str(saved_potions[p_key]).strip_edges()
		
		if raw_value == "" or raw_value == "null" or raw_value == "-1":
			continue
			
		var resource_path = ""
		
		# Se a string contém o formato de recurso da Godot: "(res://caminho.tres):<Resource#...>"
		if "res://" in raw_value:
			var start_idx = raw_value.find("res://")
			var end_idx = raw_value.find(".tres")
			if start_idx != -1 and end_idx != -1:
				# Extrai exatamente a substring de "res://" até ".tres"
				resource_path = raw_value.substr(start_idx, (end_idx + 5) - start_idx)
		
		# Se conseguimos extrair um caminho .tres válido
		if resource_path != "" and ResourceLoader.exists(resource_path):
			var loaded_item = load(resource_path) as ItemData
			if loaded_item:
				# Atribui o item diretamente ao slot do HUD (Z ou X)
				assign_potion_to_slot(str(p_key), loaded_item)
				print("[HUD] Poção de %s carregada com sucesso via path: %s" % [p_key.to_upper(), resource_path])

	has_pending_load = false

func update_action_bar_cooldown_displays(_delta: float) -> void:
	var action_bar = get_node_or_null("ActionBarPanel")
	if not action_bar:
		return

	# Atualiza cooldown das poções (Z e X)
	for p_key in ["hp", "mp"]:
		var btn = action_bar.find_child("PotionSlot_" + p_key, true, false)
		if btn:
			var cd_lbl = btn.get_node_or_null("CooldownLabel") as Label
			if cd_lbl:
				if potion_cooldown_timer > 0.0:
					cd_lbl.text = "%.1f" % potion_cooldown_timer
					cd_lbl.visible = true
				else:
					cd_lbl.text = ""
					cd_lbl.visible = false

	# Atualiza cooldown das skills (1 a 5)
	var skill_manager = get_tree().current_scene.find_child("SkillManager", true, false)
	for i in range(1, 6):
		var btn = action_bar.find_child("SkillSlot_" + str(i), true, false)
		if btn:
			var cd_lbl = btn.get_node_or_null("CooldownLabel") as Label
			var skill_data: SkillData = equipped_skill_slots.get(i, null)
			
			if cd_lbl and skill_manager and skill_data:
				var rem_cd = skill_manager.skill_cooldowns.get(skill_data.id, 0.0)
				if rem_cd > 0.0:
					cd_lbl.text = "%.1f" % rem_cd
					cd_lbl.visible = true
				else:
					cd_lbl.text = ""
					cd_lbl.visible = false
