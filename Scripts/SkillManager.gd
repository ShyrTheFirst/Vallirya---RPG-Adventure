class_name SkillManager
extends Node3D

@export var player: CharacterBody3D

@export_category("Banco de Dados de Habilidades")
@export var register_skills: Array[SkillData] = []

var skill_cooldowns: Dictionary = {}

# Dicionário mestre de habilidades baseadas na String ID do SkillData
var available_skills: Dictionary = {}

# --- DADOS DE PROGRESSÃO DE HABILIDADES (Salvamento) ---
var unlocked_skills: Array[String] = [] # IDs das skills já compradas (Azul)
var pending_purchase_skill_id: String = "" # ID selecionada aguardando confirmação (Laranja)

var total_points_earned: int = 0
var spent_skill_points: int = 0
var pending_skill_points: int = 0 # Pontos em espera para gastar

# Referência da UI da Árvore de Habilidades (Janela gerada ou instanciada)
var skill_tree_window: Control = null

# Variáveis de controle de mira (Decal)
var is_targeting_spell: bool = false
var pending_skill_data: SkillData = null
var active_spell_decal: Node3D = null
var spell_decal_scene = preload("res://Scenes/SpellDecal.tscn")

func _ready() -> void:
	if not player:
		player = get_tree().current_scene.find_child("Player", true, false)
	load_all_skills()

func _process(delta: float) -> void:
	if player:
		update_skill_points_calculation()
	
	for s_id in skill_cooldowns:
		if skill_cooldowns[s_id] > 0.0:
			skill_cooldowns[s_id] -= delta
			if skill_cooldowns[s_id] < 0.0:
				skill_cooldowns[s_id] = 0.0

# --- GERENCIAMENTO INTELIGENTE DE PONTOS DE HABILIDADE ---
func update_skill_points_calculation() -> void:
	if not player:
		return
		
	var current_level = 1
	if player.has_method("get_level"):
		current_level = player.get_level()
	elif "level" in player and player.get("level") != null:
		current_level = int(player.get("level"))
		
	# Calcula quantos pontos o jogador tem direito no nível atual (Nível / 3)
	var earned_points = int(current_level / 3)
	
	# Regra solicitada: Se (pontos gastos + pontos em espera) for diferente do total ganho, calcula o novo ponto em espera
	if (spent_skill_points + pending_skill_points) != earned_points:
		var _diff = earned_points - (spent_skill_points + spent_skill_points) # Ajuste de cálculo para a diferença
		# Garante que os pontos pendentes absorvam a nova diferença de nível
		pending_skill_points = max(0, earned_points - spent_skill_points - (pending_skill_points - (pending_skill_points if pending_skill_points > 0 else 0)))
		# Simplificando a lógica de incremento seguro:
		pending_skill_points = earned_points - spent_skill_points
		if pending_skill_points < 0:
			pending_skill_points = 0

# --- CARREGAMENTO DO BANCO DE DADOS VIA @EXPORT ---
func load_all_skills() -> void:
	available_skills.clear()
	for skill_data in register_skills:
		if skill_data and skill_data.id != "":
			available_skills[skill_data.id] = skill_data
			print("[SKILL MANAGER] Skill carregada via Inspetor: ", skill_data.skill_name)

# --- LÓGICA DE VALIDAÇÃO DE COMPRA E ESTADOS (Cores) ---
func get_skill_state(skill_id: String) -> String:
	if unlocked_skills.has(skill_id):
		return "Habilitada" # Azul
		
	if pending_purchase_skill_id == skill_id:
		return "Pendente" # Laranja
		
	# Verifica se há pontos disponíveis em espera para gastar
	if pending_skill_points <= 0:
		return "Nao pode comprar" # Cinza
	
	var skill_data: SkillData = available_skills.get(skill_id, null)
	if not skill_data:
		return "Nao pode comprar" # Cinza
		
	var player_lvl = player.get("level") if player and "level" in player else 1
	var req_lvl = skill_data.required_level if "required_level" in skill_data else 1
	var req_skill = skill_data.required_skill_id if "required_skill_id" in skill_data else ""
	
	var has_level = player_lvl >= req_lvl
	var has_prereq = true
	if req_skill != "" and req_skill != null:
		has_prereq = unlocked_skills.has(req_skill)
		if pending_skill_points > 0:
			if has_level and has_prereq:
				return "Disponivel" # Verde
			else:
				return "Requirimentos nao alcançados" # Vermelho (tem pontos, mas falta nível ou pré-requisito)
		
		else:
			if has_level and has_prereq:
				return "Nao pode comprar" # Cinza
			else:
				return "Requirimentos nao alcançados"
			
	# Skills padrão liberadas se tiver pontos
	return "Disponivel" # Verde

func select_skill_for_purchase(skill_id: String) -> void:
	var state = get_skill_state(skill_id)
	if state == "Disponivel":
		pending_purchase_skill_id = skill_id
		print("[SKILL TREE] Skill selecionada para compra (Pendente): ", skill_id)

func confirm_skill_purchase() -> void:
	if pending_purchase_skill_id == "":
		print("[SKILL TREE] Nenhuma habilidade foi selecionada para compra!")
		return
		
	if pending_skill_points <= 0:
		print("[SKILL TREE] Pontos de Habilidade insuficientes! Suba de nível para ganhar pontos.")
		return
		
	var skill_id = pending_purchase_skill_id
	var state = get_skill_state(skill_id)
	
	if state == "Disponivel" or state == "Pendente":
		unlocked_skills.append(skill_id)
		pending_skill_points -= 1
		spent_skill_points += 1
		pending_purchase_skill_id = ""
		print("[SKILL TREE] Habilidade comprada com sucesso: ", skill_id)
		refresh_tree_display()
		
		if is_instance_valid(skill_tree_window) and skill_tree_window.has_method("refresh_tree_display"):
			skill_tree_window.refresh_tree_display()
	else:
		print("[SKILL TREE] Não é possível comprar esta skill. Estado atual: ", state)

# --- PERSISTÊNCIA (SALVAR E CARREGAR) ---
func get_save_data() -> Dictionary:
	return {
		"unlocked_skills": unlocked_skills,
		"spent_skill_points": spent_skill_points,
		"pending_skill_points": pending_skill_points
	}

func load_saved_data(saved_data: Dictionary) -> void:
	if saved_data.has("unlocked_skills"):
		unlocked_skills = Array(saved_data["unlocked_skills"], TYPE_STRING, "", null)
	if saved_data.has("spent_skill_points"):
		spent_skill_points = int(saved_data["spent_skill_points"])
	if saved_data.has("pending_skill_points"):
		pending_skill_points = int(saved_data["pending_skill_points"])
	print("[SKILL MANAGER] Dados de habilidades carregados com sucesso!")

# --- INTERFACE VISUAL DA ÁRvore DE HABILIDADES (GRIMÓRIO) ---

func _unhandled_input(event: InputEvent) -> void:
	if not player or player.is_dead:
		return
	
	if is_targeting_spell:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			confirm_targeted_cast()
			get_viewport().set_input_as_handled()
			return
	
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			cancel_targeting()
			get_viewport().set_input_as_handled()
			return
	
		return
		
	if event is InputEventKey and event.pressed and (event.keycode == KEY_B):
		toggle_skill_tree_window()
		get_viewport().set_input_as_handled()

func toggle_skill_tree_window() -> void:
	if is_instance_valid(skill_tree_window):
		skill_tree_window.queue_free()
		skill_tree_window = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("[SKILL TREE] Janela fechada.")
	else:
		create_skill_tree_ui()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("[SKILL TREE] Janela aberta.")

func create_skill_tree_ui() -> void:
	if is_instance_valid(skill_tree_window):
		skill_tree_window.queue_free()

	skill_tree_window = Control.new()
	skill_tree_window.name = "SkillTreeWindow"
	skill_tree_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_tree_window.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().current_scene.add_child(skill_tree_window)

	var bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.6)
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_tree_window.add_child(bg_overlay)

	var panel = PanelContainer.new()
	panel.name = "SkillTreePanel"
	panel.custom_minimum_size = Vector2(500, 450)

	# Centraliza perfeitamente os âncoras no meio da tela
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5

	# Puxa a metade da largura e altura para trás para o pivô ficar no centro exato
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -225
	panel.offset_bottom = 225
	
	var theme = load("res://ASSETS/VFX/Themes/ValliryaTheme_Final.tres")
	if theme:
		panel.theme = theme
	skill_tree_window.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	# --- CABEÇALHO ---
	var header_hbox = HBoxContainer.new()
	vbox.add_child(header_hbox)

	var title_lbl = Label.new()
	title_lbl.text = "--- GRIMÓRIO DE HABILIDADES ---"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	var points_lbl = Label.new()
	points_lbl.name = "PointsLabel"
	points_lbl.text = "Pontos Disponíveis (SP): %d" % pending_skill_points
	header_hbox.add_child(points_lbl)

	# --- GRID DE HABILIDADES ---
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var grid = GridContainer.new()
	grid.name = "SkillsGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	scroll.add_child(grid)

	for s_id in available_skills:
		var skill_data: SkillData = available_skills[s_id]
		var state = get_skill_state(s_id)

		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(80, 80)
		slot_btn.tooltip_text = "%s\nMana: %d | CD: %.1fs\nEstado: %s" % [skill_data.skill_name, skill_data.mana_cost, skill_data.cooldown, state]

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
		style.set_corner_radius_all(6)
		style.set_border_width_all(8)

		match state:
			"Habilitada":
				style.border_color = Color(0.2, 0.5, 1.0) # Azul (Já possui)
			"Pendente":
				style.border_color = Color(1.0, 0.6, 0.0) # Laranja (Pendente)
			"Disponivel":
				style.border_color = Color(0.2, 0.8, 0.3) # Verde (Pode comprar)
			"Requirimentos nao alcançados":
				style.border_color = Color(0.9, 0.2, 0.2) # Vermelho (Falta nível/requisito)
			_:
				style.border_color = Color(0.4, 0.4, 0.4) # Cinza (Bloqueada)

		slot_btn.add_theme_stylebox_override("normal", style)

		if skill_data.icon:
			# MarginContainer interno para dar espaço para a borda do botão aparecer
			var margin = MarginContainer.new()
			margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			margin.add_theme_constant_override("margin_left", 6)
			margin.add_theme_constant_override("margin_right", 6)
			margin.add_theme_constant_override("margin_top", 6)
			margin.add_theme_constant_override("margin_bottom", 6)
			margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot_btn.add_child(margin)

			var icon_rect = TextureRect.new()
			icon_rect.texture = skill_data.icon
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			margin.add_child(icon_rect)
		else:
			slot_btn.text = skill_data.skill_name

		slot_btn.pressed.connect(func():
			if state == "Habilitada":
				open_skill_shortcut_menu(skill_data, slot_btn)
				print("[SKILL TREE] Skill já adquirida. Pronto para cascata de atalho.")
			else:
				select_skill_for_purchase(s_id)
				refresh_tree_display()
		)

		grid.add_child(slot_btn)

	# --- RODAPÉ ---
	var footer_hbox = HBoxContainer.new()
	footer_hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(footer_hbox)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirmar Compra"
	confirm_btn.pressed.connect(func():
		confirm_skill_purchase()
	)
	footer_hbox.add_child(confirm_btn)

	var close_btn = Button.new()
	close_btn.text = "Fechar"
	close_btn.pressed.connect(func():
		toggle_skill_tree_window()
	)
	footer_hbox.add_child(close_btn)

func refresh_tree_display() -> void:
	if is_instance_valid(skill_tree_window):
		create_skill_tree_ui()

# --- SISTEMA DE LANÇAMENTO E CAST ---
func try_cast(skill_data: SkillData) -> void:
	if not player or player.is_dead or not skill_data:
		return

	if not unlocked_skills.has(skill_data.id):
		print("[MAGIA] Você ainda não aprendeu a habilidade: ", skill_data.skill_name)
		return

	var remaining_cd = skill_cooldowns.get(skill_data.id, 0.0)
	if remaining_cd > 0.0:
		print("[MAGIA] Habilidade em recarga! Aguarde %.1f segundos." % remaining_cd)
		return

	if skill_data.requires_staff:
		var weapon: ItemData = player.equipped_items.get("weapon", null)
		if not weapon or weapon.weapon_type != ItemData.WeaponType.STAFF:
			print("[MAGIA] Você precisa de um Cajado equipado para lançar %s!" % skill_data.skill_name)
			return

	if player.mana < skill_data.mana_cost:
		print("[MAGIA] Mana insuficiente!")
		return
	

	if skill_data.type == "area" or skill_data.type == "Area":
		prepare_spell_targeting(skill_data)
	else:
		execute_spell(skill_data, player.global_position)

func prepare_spell_targeting(skill_data: SkillData) -> void:
	pending_skill_data = skill_data
	is_targeting_spell = true
	
	if is_instance_valid(active_spell_decal):
		active_spell_decal.queue_free()
		
	active_spell_decal = spell_decal_scene.instantiate()
	get_tree().current_scene.add_child(active_spell_decal)
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("[MAGIA] Aguardando o jogador escolher o local da magia: ", skill_data.skill_name)

func confirm_targeted_cast() -> void:
	if not is_instance_valid(active_spell_decal) or not pending_skill_data:
		cancel_targeting()
		return
		
	var target_pos = active_spell_decal.global_position
	var skill_to_execute = pending_skill_data
	
	# 1. Limpa o estado de mira imediatamente
	is_targeting_spell = false
	pending_skill_data = null
	if is_instance_valid(active_spell_decal):
		active_spell_decal.queue_free()
		active_spell_decal = null
		
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# 2. Ativa a trava de segurança no player (ignora cliques por 0.15 segundos)
	if player and "spell_cast_lockout" in player:
		player.spell_cast_lockout = 0.15
	
	# 3. Executa a magia e a animação
	execute_spell(skill_to_execute, target_pos)

func cancel_targeting() -> void:
	if not is_targeting_spell: return
	
	pending_skill_data = null
	if is_instance_valid(active_spell_decal):
		active_spell_decal.queue_free()
		active_spell_decal = null
		
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("[MAGIA] Lançamento cancelado pelo jogador.")
	is_targeting_spell = false

func execute_spell(skill_data: SkillData, target_position: Vector3) -> void:
	player.mana -= skill_data.mana_cost
	skill_cooldowns[skill_data.id] = skill_data.cooldown
	print("[MAGIA] Executando %s nas coordenadas %s" % [skill_data.skill_name, str(target_position)])

	if skill_data.animation_name != "" and player.has_method("play_spell_animation"):
		player.play_spell_animation(skill_data.animation_name)
	
	if skill_data.id == "Cura":
		player.magic_heal(skill_data.damage)
	else:
		var dmg = skill_data.damage if "damage" in skill_data else 40
		var eff = skill_data.effect_type if "effect_type" in skill_data else "queimadura"
		apply_aoe_damage(target_position, 3.0, dmg, eff)
		
	player.update_hud_display()

func apply_aoe_damage(center: Vector3, radius: float, damage: int, effect: String) -> void:
	var monsters = get_tree().get_nodes_in_group("Monsters")
	for m in monsters:
		if is_instance_valid(m) and not m.is_dead:
			var dist = (m.global_position - center).length()
			if dist <= radius:
				if m.has_method("take_damage"):
					m.take_damage(damage, player)
				print("[COMBAT] Monstro atingido pela magia! Efeito aplicado: ", effect)

# Exibe o menu em cascata (PopupMenu) para escolher o atalho (1 a 5) da skill já desbloqueada
func open_skill_shortcut_menu(skill_data: SkillData, button_node: Control) -> void:
	# Cria ou reutiliza um PopupMenu temporário
	var shortcut_menu = PopupMenu.new()
	shortcut_menu.name = "SkillShortcutPopup"
	
	for i in range(1, 6):
		shortcut_menu.add_item("Definir no Atalho [%d]" % i, i)
		
	# Conecta o sinal de seleção do menu
	shortcut_menu.id_pressed.connect(func(slot_index: int):
		assign_skill_to_hud_slot(slot_index, skill_data)
		shortcut_menu.queue_free()
	)
	
	# Adiciona à cena atual e exibe na posição global do botão clicado
	get_tree().current_scene.add_child(shortcut_menu)
	shortcut_menu.position = Vector2i(button_node.global_position) + Vector2i(80, 0) # Exibe ao lado do botão
	shortcut_menu.popup()

# Envia a ordem para o HUD equipar a skill no atalho escolhido
func assign_skill_to_hud_slot(slot_index: int, skill_data: SkillData) -> void:
	var hud = get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("assign_skill_to_action_bar"):
		hud.assign_skill_to_action_bar(slot_index, skill_data)
		print("[SKILL TREE] Habilidade %s alocada com sucesso no atalho [%d]!" % [skill_data.skill_name, slot_index])
		# Opcional: Fecha a janela da árvore de skills após equipar
		toggle_skill_tree_window()
	else:
		print("[SKILL TREE] Erro: HUD ou método assign_skill_to_action_bar não encontrado!")
