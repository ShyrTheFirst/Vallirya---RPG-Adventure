class_name Player
extends CharacterBody3D

@export var mouse_sensitivity: float = 0.003
@export var attack_reach: float = 3.0
@export var combo_window_time: float = 1.0
@export var max_targets_per_hit: int = 4

# Identificação e Atributos Base
var player_name: String = "Aventureiro"
var stat_str: int = 5
var stat_agi: int = 5
var stat_vit: int = 5
var stat_int: int = 5

# Atributos Derivados e Status
var speed: float = 5.5
@export var jump_velocity: float = 4.8
var max_hp: int = 150
var hp: int = 150
var bonus_hp: int = 0

var max_mana: int = 100
var mana: int = 100
var bonus_mana: int = 0

var attack_damage: int = 19
var magic_damage: int = 10
var defense: int = 5
var bonus_defense: int = 0
var evasion: float = 5.0 # Porcentagem (máx 40.0%)

var attack_cooldown_time: float = 0.45

# --- SISTEMA DE MISSÕES (QUESTS) ---
var active_quests: Dictionary = {} # q_id -> {"current_amount": int, "is_completed": bool}
var completed_quests: Array = []   # Lista de IDs completos
var client_active_quests: Array = [] # Lista formatada para HUD
var quest_board_ui_scene = preload("res://Scenes/UI/QuestBoardUI.tscn")
var active_board_ui: Control = null

# Variáveis do Painel de Diálogo
var ui_dialogue_panel: PanelContainer = null
var ui_dialogue_npc_name: Label = null
var ui_dialogue_text_label: Label = null
var ui_dialogue_close_btn: Button = null
var ui_quest_panel: PanelContainer = null
var ui_quest_list_container: VBoxContainer = null

# --- SISTEMA DE SKILLS, MANA E COOLDOWNS ---
var skills_data: Dictionary = {
	1: { "name": "Bola de Fogo", "mana_cost": 25, "cooldown": 1.2, "timer": 0.0, "requires_staff": true },
	2: { "name": "Lança de Gelo", "mana_cost": 20, "cooldown": 1.0, "timer": 0.0, "requires_staff": true },
	3: { "name": "Nova Arcana", "mana_cost": 45, "cooldown": 3.0, "timer": 0.0, "requires_staff": true },
	4: { "name": "Cura", "mana_cost": 30, "cooldown": 4.0, "timer": 0.0, "requires_staff": false },
	5: { "name": "Relâmpago", "mana_cost": 35, "cooldown": 2.0, "timer": 0.0, "requires_staff": true },
	6: { "name": "Escudo Mágico", "mana_cost": 50, "cooldown": 6.0, "timer": 0.0, "requires_staff": false }
}

# --- EQUIPAMENTOS ATIVOS ---
var equipped_items: Dictionary = {
	"helm": null,
	"armor": null,
	"boots": null,
	"weapon": null
}
var current_weapon_mesh_path: String = ""

# --- INVENTÁRIO (32 SLOTS) ---
const INVENTORY_CAPACITY: int = 32
var inventory_items: Array = []

# Progressão
var player_level: int = 1
var current_xp: int = 0
var required_xp: int = 100
var unspent_points: int = 0

var is_dead: bool = false

# Inputs e combo
var attack_timer: float = 0.0
var combo_step: int = 1
var combo_reset_timer: float = 0.0

# Animações e passos
var current_locomotion_state: String = ""
var step_timer: float = 0.0
const STEP_INTERVAL: float = 0.38

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

@onready var anim_tree: AnimationTree = $AnimationTree
var attacks_playback: AnimationNodeStateMachinePlayback
@onready var slashes_container: Node3D = get_node_or_null("Slashes")

# Interface 3D do Personagem
@onready var player_info_sprite: Sprite3D = $PlayerInfoSprite
@onready var sub_viewport: SubViewport = $PlayerInfoSprite/SubViewport
@onready var name_label: Label = $PlayerInfoSprite/SubViewport/VBoxContainer/NameLabel
@onready var health_bar: ProgressBar = $PlayerInfoSprite/SubViewport/VBoxContainer/ProgressBar

# Áudios e Efeitos Visuais
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio
@onready var attack_audio: AudioStreamPlayer3D = $AttackAudio
@onready var step_audio: AudioStreamPlayer3D = $StepAudio
@onready var levelup_audio: AudioStreamPlayer3D = get_node_or_null("LevelUpAudio")
@onready var levelup_beam: MeshInstance3D = get_node_or_null("LevelUpBeam")

var floating_damage_scene = preload("res://Scenes/FloatingDamage.tscn")
var death_screen_layer: CanvasLayer = null
var hud_layer: CanvasLayer = null

var custom_theme = load("res://ASSETS/VFX/Themes/ValliryaTheme_Final.tres")

# Elementos de UI
var ui_level_label: Label
var ui_xp_bar: ProgressBar
var ui_attr_panel: PanelContainer
var ui_status_panel: PanelContainer
var ui_inventory_panel: PanelContainer
var ui_equipment_panel: PanelContainer
var ui_inv_grid: GridContainer
var equipment_slot_nodes: Dictionary = {}

var ui_quest_tracker: PanelContainer = null
var ui_quest_list_vbox: VBoxContainer = null

var ui_points_label: Label
var ui_lbl_str: Label
var ui_lbl_agi: Label
var ui_lbl_vit: Label
var ui_lbl_int: Label
var ui_btn_str: Button
var ui_btn_agi: Button
var ui_btn_vit: Button
var ui_btn_int: Button

var lbl_hp_status: Label
var lbl_mana_status: Label
var lbl_evasion_status: Label
var lbl_speed_status: Label
var lbl_def_status: Label
var lbl_atk_status: Label
var lbl_matk_status: Label

var item_context_menu: PopupMenu = null
var item_tooltip_panel: PanelContainer = null
var selected_slot_index: int = -1
var selected_item_data: ItemData = null

var active_inventory_slot: int = -1
var active_equipment_slot: String = ""

@onready var right_hand_bone: BoneAttachment3D = get_node_or_null("Personagem (IK)/Armature/Skeleton3D/RightHand")

func _init() -> void:
	inventory_items.resize(INVENTORY_CAPACITY)

func _ready() -> void:
	add_to_group("Player")
	
	# 1. Cria a HUD primeiro para todos os painéis e botões existirem na memória
	setup_local_hud()

	# 2. Depois carrega o save do herói (os botões já estão prontos para receber os ícones)
	if "current_player_name" in LevelManager and LevelManager.current_player_name != "":
		player_name = LevelManager.current_player_name
		load_player_save(player_name)
	else:
		recalculate_derived_stats()

	hp = max_hp
	mana = max_mana

	if player_info_sprite and sub_viewport:
		player_info_sprite.texture = sub_viewport.get_texture()
		health_bar.max_value = max_hp
		health_bar.value = hp

	if anim_tree:
		anim_tree.active = true
		attacks_playback = anim_tree.get("parameters/AttacksCombo/playback")

	if slashes_container:
		for slash in slashes_container.get_children():
			slash.visible = false

	if camera:
		camera.current = true
		camera.make_current()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if name_label:
		name_label.text = "%s [Nv. %d]" % [player_name, player_level]
		name_label.modulate = Color(0.4, 0.9, 1.0)

func recalculate_derived_stats() -> void:
	var old_max_hp = max_hp
	max_hp = 100 + (player_level * 15) + (stat_vit * 12) + bonus_hp
	max_mana = 80 + (player_level * 10) + (stat_int * 15) + bonus_mana
	attack_damage = 10 + (player_level * 2) + int(stat_str * 1.5)
	magic_damage = 12 + (player_level * 2) + int(stat_int * 2.0)
	defense = 4 + int(stat_vit * 0.8) + bonus_defense
	speed = clamp(5.5 + (stat_agi * 0.05), 5.5, 12.0)
	evasion = min(40.0, 3.0 + (stat_agi * 0.02))
	attack_cooldown_time = clamp(0.5 - (stat_agi * 0.012), 0.22, 0.55)

	if max_hp > old_max_hp and hp > 0:
		hp += (max_hp - old_max_hp)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return

	if event.is_action_pressed("Magia1"): try_cast_spell(1)
	elif event.is_action_pressed("Magia2"): try_cast_spell(2)
	elif event.is_action_pressed("Magia3"): try_cast_spell(3)
	elif event.is_action_pressed("Magia4"): try_cast_spell(4)
	elif event.is_action_pressed("Magia5"): try_cast_spell(5)

	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		toggle_attribute_window()

	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		toggle_inventory_window()

	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		toggle_quest_window()

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if ui_dialogue_panel and ui_dialogue_panel.visible:
			close_dialogue_window()
			get_viewport().set_input_as_handled()
			return
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var viewport = get_viewport()
		if viewport and not viewport.gui_get_hovered_control():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if Input.is_action_just_pressed("Ataque") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		try_perform_local_attack()

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if spring_arm:
			spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
			spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-65.0), deg_to_rad(30.0))

func try_cast_spell(skill_id: int) -> void:
	if not skills_data.has(skill_id) or is_dead:
		return

	var skill = skills_data[skill_id]
	if skill.get("requires_staff", false):
		var weapon: ItemData = equipped_items.get("weapon", null)
		if not weapon or weapon.weapon_type != ItemData.WeaponType.STAFF:
			print("[MAGIA] Você precisa de um Cajado equipado para lançar %s!" % skill["name"])
			return

	if skill["timer"] > 0.0 or mana < skill["mana_cost"]:
		return

	mana -= skill["mana_cost"]
	skill["timer"] = skill["cooldown"]
	print("Usou a skill %d (%s)" % [skill_id, skill["name"]])
	update_hud_display()

func try_perform_local_attack() -> void:
	if attack_timer > 0.0 or is_dead:
		return

	var current_weapon: ItemData = equipped_items.get("weapon", null)
	if not current_weapon:
		return

	attack_timer = attack_cooldown_time
	combo_reset_timer = combo_window_time

	var anim_name = ""
	match current_weapon.weapon_type:
		ItemData.WeaponType.SWORD:
			anim_name = "Armature|Ataque %d" % combo_step
			combo_step = 1 if combo_step >= 5 else combo_step + 1
		ItemData.WeaponType.STAFF:
			anim_name = "Armature|Cajado 1"
			combo_step = 1
		ItemData.WeaponType.AXE:
			anim_name = "Armature|Machado %d" % combo_step
			combo_step = 1 if combo_step >= 3 else combo_step + 1
		_:
			anim_name = "Armature|Ataque %d" % combo_step
			combo_step = 1 if combo_step >= 5 else combo_step + 1

	play_attack_visuals(anim_name)
	perform_melee_hit()

func perform_melee_hit() -> void:
	var forward_dir = -global_transform.basis.z.normalized()
	var monsters = get_tree().get_nodes_in_group("Monsters")
	var hit_count: int = 0

	for m in monsters:
		if is_instance_valid(m) and not m.is_dead and m.hp > 0:
			var diff = m.global_position - global_position
			diff.y = 0.0
			var dist = diff.length()

			if dist <= attack_reach:
				var dir_to_monster = diff.normalized()
				var dot_prod = forward_dir.dot(dir_to_monster)

				if dot_prod >= 0.15:
					var monster_evasion = m.evasion if "evasion" in m else 5.0
					if randf() * 100.0 < monster_evasion:
						if m.has_method("show_damage_effect"):
							m.show_damage_effect(0, m.hp)
					else:
						m.take_damage(attack_damage, self)

					hit_count += 1
					if hit_count >= max_targets_per_hit:
						break

func _process(delta: float) -> void:
	for s_id in skills_data:
		if skills_data[s_id]["timer"] > 0.0:
			skills_data[s_id]["timer"] -= delta

	update_client_visuals(delta)

func _physics_process(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta

	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_step = 1

	if is_dead:
		return

	var move_vec = Input.get_vector("Esquerda", "Direita", "Frente", "Costas")
	var wants_jump = Input.is_action_just_pressed("Pular") and is_on_floor()

	if wants_jump:
		velocity.y = jump_velocity

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	elif not wants_jump:
		velocity.y = 0.0

	var local_dir = Vector3(move_vec.x, 0, move_vec.y).normalized()
	var world_dir = global_transform.basis * local_dir
	velocity.x = world_dir.x * speed
	velocity.z = world_dir.z * speed

	move_and_slide()

func update_client_visuals(delta: float) -> void:
	if not anim_tree or not anim_tree.active or is_dead:
		return

	var move_vec = Input.get_vector("Esquerda", "Direita", "Frente", "Costas")
	var is_moving: bool = move_vec.length() > 0.1

	var target_state: String = "state_1" if is_moving else "state_0"
	if current_locomotion_state != target_state:
		current_locomotion_state = target_state
		anim_tree.set("parameters/locomotion/transition_request", target_state)

	if is_moving:
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = STEP_INTERVAL
			if step_audio and step_audio.stream:
				step_audio.pitch_scale = randf_range(0.88, 1.12)
				step_audio.play()
	else:
		step_timer = 0.05

# --- PROGRESSÃO E EXPERIÊNCIA ---

func add_experience(amount: int) -> void:
	current_xp += amount
	var leveled_up = false

	while current_xp >= required_xp:
		current_xp -= required_xp
		player_level += 1
		unspent_points += 3
		required_xp = 100 + (player_level - 1) * 75 + int(pow(player_level, 1.5) * 10)
		leveled_up = true

	if leveled_up:
		recalculate_derived_stats()
		hp = max_hp
		mana = max_mana
		rpc_play_levelup_effect()
		save_player_account()

	update_hud_display()

func allocate_attribute(stat_name: String) -> void:
	if unspent_points <= 0:
		return

	match stat_name:
		"STR": stat_str += 1
		"AGI": stat_agi += 1
		"VIT": stat_vit += 1
		"INT": stat_int += 1
		_: return

	unspent_points -= 1
	recalculate_derived_stats()
	update_hud_display()

func play_attack_visuals(anim_name: String) -> void:
	if attacks_playback:
		attacks_playback.start(anim_name)

	if anim_tree:
		anim_tree.set("parameters/attack_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	if attack_audio and attack_audio.stream:
		attack_audio.pitch_scale = randf_range(0.93, 1.07)
		attack_audio.play()

	play_slash_effect(anim_name)

func play_slash_effect(anim_name: String) -> void:
	if not slashes_container:
		return

	var slash_target_name: String = ""
	match anim_name:
		"Armature|Ataque 1": slash_target_name = "Slash"
		"Armature|Ataque 2": slash_target_name = "Slash2"
		"Armature|Ataque 3": slash_target_name = "Slash3"
		"Armature|Ataque 4": slash_target_name = "Slash4"
		"Armature|Ataque 5": slash_target_name = "Slash5"

	if slash_target_name != "":
		var target_node = slashes_container.get_node_or_null(slash_target_name)
		if target_node and target_node.has_method("trigger"):
			target_node.trigger()

func show_damage_effect(amount: int, current_hp: int) -> void:
	hp = current_hp
	if health_bar:
		health_bar.value = hp

	update_hud_display()

	if hit_audio and hit_audio.stream:
		hit_audio.pitch_scale = randf_range(0.92, 1.08)
		hit_audio.play()

	var dmg_lbl = floating_damage_scene.instantiate()
	get_parent().add_child(dmg_lbl)
	dmg_lbl.global_position = global_position + Vector3(0, 1.5, 0)
	if dmg_lbl.has_method("setup"):
		if amount == 0:
			dmg_lbl.setup("MISS", Color(0.7, 0.7, 0.7))
		else:
			dmg_lbl.setup(amount, Color(1.0, 0.2, 0.2))

func take_damage(amount: int) -> void:
	if is_dead:
		return

	if randf() * 100.0 < evasion:
		show_damage_effect(0, hp)
		return

	var min_dmg = max(1, int(amount * 0.20))
	var mitigated_dmg = amount - int(defense * 0.5)
	var final_dmg = max(min_dmg, mitigated_dmg)

	hp = max(0, hp - final_dmg)
	show_damage_effect(final_dmg, hp)

	if hp <= 0:
		is_dead = true
		set_physics_process(false)
		velocity = Vector3.ZERO
		combo_step = 1
		rpc_player_death()

		get_tree().create_timer(3.0).timeout.connect(func():
			var world = get_tree().current_scene
			var spawn_pos = Vector3(0, 1, 0)
			if world and world.has_method("get_player_spawn_position"):
				spawn_pos = world.get_player_spawn_position()

			hp = max_hp
			mana = max_mana
			is_dead = false
			global_position = spawn_pos
			set_physics_process(true)
			rpc_player_respawn(spawn_pos, max_hp)
		)

func rpc_play_levelup_effect() -> void:
	if levelup_audio and levelup_audio.stream:
		levelup_audio.pitch_scale = randf_range(0.98, 1.02)
		levelup_audio.play()

	play_beam_animation()

	var lvl_lbl = floating_damage_scene.instantiate()
	get_parent().add_child(lvl_lbl)
	lvl_lbl.global_position = global_position + Vector3(0, 2.2, 0)
	if lvl_lbl.has_method("setup"):
		lvl_lbl.setup("+ LEVEL UP!", Color(1.0, 0.85, 0.1))

func play_beam_animation() -> void:
	if not levelup_beam:
		return

	levelup_beam.visible = true
	levelup_beam.scale = Vector3(0.2, 0.1, 0.2)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(levelup_beam, "scale", Vector3(1.3, 1.0, 1.3), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(levelup_beam, "scale", Vector3(0.05, 1.6, 0.05), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func(): levelup_beam.visible = false)

func rpc_player_death() -> void:
	is_dead = true
	visible = false
	collision_shape.set_deferred("disabled", true)

	if anim_tree:
		anim_tree.set("parameters/attack_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)

	show_death_ui()

func rpc_player_respawn(pos: Vector3, new_hp: int) -> void:
	is_dead = false
	hp = new_hp
	global_position = pos
	visible = true
	collision_shape.set_deferred("disabled", false)

	if health_bar:
		health_bar.value = new_hp

	if anim_tree:
		current_locomotion_state = "state_0"
		anim_tree.set("parameters/locomotion/transition_request", "state_0")

	update_hud_display()
	hide_death_ui()

func show_death_ui() -> void:
	if death_screen_layer:
		return

	death_screen_layer = CanvasLayer.new()
	var label = Label.new()
	label.text = "VOCÊ MORREU!\nRenascendo em instantes..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

	death_screen_layer.add_child(label)
	add_child(death_screen_layer)

func hide_death_ui() -> void:
	if death_screen_layer:
		death_screen_layer.queue_free()
		death_screen_layer = null

# --- INTERFACES LOCAIS (HUD, ATRIBUTOS, STATUS, INVENTÁRIO E EQUIPAMENTOS) ---

func setup_local_hud() -> void:
	if hud_layer:
		hud_layer.queue_free()

	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	# 1. BARRA DE XP (Inferior Esquerdo)
	var hud_box = VBoxContainer.new()
	hud_box.custom_minimum_size = Vector2(300, 45)
	hud_layer.add_child(hud_box)
	
	hud_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud_box.offset_left = 25
	hud_box.offset_bottom = -25
	hud_box.offset_top = -70
	hud_box.offset_right = 325

	ui_level_label = Label.new()
	ui_level_label.text = "Nível 1 (C: Atrib | I: Inv | Q: Quests)"
	ui_level_label.add_theme_font_size_override("font_size", 12)
	hud_box.add_child(ui_level_label)

	ui_xp_bar = ProgressBar.new()
	ui_xp_bar.custom_minimum_size = Vector2(300, 14)
	ui_xp_bar.show_percentage = false

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.92, 0.92, 0.94, 0.9)
	bg_style.set_corner_radius_all(3)
	ui_xp_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(1.0, 0.82, 0.1, 1.0)
	fill_style.set_corner_radius_all(3)
	ui_xp_bar.add_theme_stylebox_override("fill", fill_style)
	hud_box.add_child(ui_xp_bar)

	# 2. PAINEL DE ATRIBUTOS
	ui_attr_panel = PanelContainer.new()
	ui_attr_panel.custom_minimum_size = Vector2(260, 200)
	ui_attr_panel.visible = false
	if custom_theme: ui_attr_panel.theme = custom_theme
	hud_layer.add_child(ui_attr_panel)
	
	ui_attr_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui_attr_panel.offset_left = 25
	ui_attr_panel.offset_top = 80

	var p_box = VBoxContainer.new()
	p_box.add_theme_constant_override("separation", 6)
	ui_attr_panel.add_child(p_box)

	var p_title = Label.new()
	p_title.text = "--- ATRIBUTOS ---"
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_box.add_child(p_title)

	ui_points_label = Label.new()
	ui_points_label.text = "Pontos Disponíveis: 0"
	ui_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_points_label.modulate = Color(1.0, 0.85, 0.2)
	p_box.add_child(ui_points_label)

	var row_str = create_stat_row("Força", "STR")
	ui_lbl_str = row_str.label
	ui_btn_str = row_str.btn
	p_box.add_child(row_str.container)

	var row_agi = create_stat_row("Agilidade", "AGI")
	ui_lbl_agi = row_agi.label
	ui_btn_agi = row_agi.btn
	p_box.add_child(row_agi.container)

	var row_vit = create_stat_row("Vitalidade", "VIT")
	ui_lbl_vit = row_vit.label
	ui_btn_vit = row_vit.btn
	p_box.add_child(row_vit.container)

	var row_int = create_stat_row("Inteligência", "INT")
	ui_lbl_int = row_int.label
	ui_btn_int = row_int.btn
	p_box.add_child(row_int.container)

	# 3. PAINEL DE STATUS DERIVADOS
	ui_status_panel = PanelContainer.new()
	ui_status_panel.custom_minimum_size = Vector2(260, 210)
	ui_status_panel.visible = false
	if custom_theme: ui_status_panel.theme = custom_theme
	hud_layer.add_child(ui_status_panel)
	
	ui_status_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui_status_panel.offset_left = 25
	ui_status_panel.offset_top = 300

	var s_box = VBoxContainer.new()
	s_box.add_theme_constant_override("separation", 6)
	ui_status_panel.add_child(s_box)

	var s_title = Label.new()
	s_title.text = "--- STATUS ---"
	s_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_box.add_child(s_title)

	lbl_hp_status = Label.new()
	lbl_hp_status.add_theme_font_size_override("font_size", 12)
	s_box.add_child(lbl_hp_status)

	lbl_mana_status = Label.new()
	lbl_mana_status.add_theme_font_size_override("font_size", 12)
	s_box.add_child(lbl_mana_status)

	lbl_def_status = Label.new()
	lbl_def_status.add_theme_font_size_override("font_size", 12)
	s_box.add_child(lbl_def_status)

	lbl_atk_status = Label.new()
	lbl_atk_status.add_theme_font_size_override("font_size", 12)
	s_box.add_child(lbl_atk_status)

	lbl_matk_status = Label.new()
	lbl_matk_status.add_theme_font_size_override("font_size", 12)
	s_box.add_child(lbl_matk_status)

	lbl_speed_status = Label.new()
	lbl_speed_status.add_theme_font_size_override("font_size", 12)
	s_box.add_child(lbl_speed_status)

	lbl_evasion_status = Label.new()
	lbl_evasion_status.add_theme_font_size_override("font_size", 12)
	s_box.add_child(lbl_evasion_status)

	# 4. PAINEL DE INVENTÁRIO (32 SLOTS)
	ui_inventory_panel = PanelContainer.new()
	ui_inventory_panel.custom_minimum_size = Vector2(320, 320)
	ui_inventory_panel.visible = false
	if custom_theme: ui_inventory_panel.theme = custom_theme
	hud_layer.add_child(ui_inventory_panel)
	
	ui_inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ui_inventory_panel.offset_right = -25
	ui_inventory_panel.offset_left = -345
	ui_inventory_panel.offset_top = 80

	var inv_box = VBoxContainer.new()
	inv_box.add_theme_constant_override("separation", 8)
	ui_inventory_panel.add_child(inv_box)

	var inv_title = Label.new()
	inv_title.text = "--- INVENTÁRIO (32) ---"
	inv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_box.add_child(inv_title)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 260)
	inv_box.add_child(scroll)

	ui_inv_grid = GridContainer.new()
	ui_inv_grid.columns = 4
	ui_inv_grid.add_theme_constant_override("h_separation", 8)
	ui_inv_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(ui_inv_grid)

	# 5. PAINEL DE EQUIPAMENTOS
	ui_equipment_panel = PanelContainer.new()
	ui_equipment_panel.custom_minimum_size = Vector2(320, 150)
	ui_equipment_panel.visible = false
	if custom_theme: ui_equipment_panel.theme = custom_theme
	hud_layer.add_child(ui_equipment_panel)
	
	ui_equipment_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ui_equipment_panel.offset_right = -25
	ui_equipment_panel.offset_left = -345
	ui_equipment_panel.offset_top = 500

	var eq_box = VBoxContainer.new()
	eq_box.add_theme_constant_override("separation", 8)
	ui_equipment_panel.add_child(eq_box)

	var eq_title = Label.new()
	eq_title.text = "--- EQUIPAMENTOS ---"
	eq_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eq_box.add_child(eq_title)

	var eq_center = CenterContainer.new()
	eq_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eq_box.add_child(eq_center)

	var eq_grid = GridContainer.new()
	eq_grid.columns = 4
	eq_grid.add_theme_constant_override("h_separation", 12)
	eq_center.add_child(eq_grid)

	var slots_data = [
		{"name": "Elmo", "key": "helm"},
		{"name": "Armadura", "key": "armor"},
		{"name": "Bota", "key": "boots"},
		{"name": "Arma", "key": "weapon"}
	]

	for s_info in slots_data:
		var slot_vbox = VBoxContainer.new()
		var slot_lbl = Label.new()
		slot_lbl.text = s_info["name"]
		slot_lbl.add_theme_font_size_override("font_size", 10)
		slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_vbox.add_child(slot_lbl)

		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(60, 60)
		slot_btn.focus_mode = Control.FOCUS_NONE
		slot_btn.clip_contents = true

		var eq_style = StyleBoxFlat.new()
		eq_style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
		eq_style.set_corner_radius_all(4)
		eq_style.set_border_width_all(1)
		eq_style.border_color = Color(0.5, 0.4, 0.2)
		slot_btn.add_theme_stylebox_override("normal", eq_style)

		var key = s_info["key"]
		equipment_slot_nodes[key] = slot_btn
		slot_btn.pressed.connect(func(): _on_equipment_slot_clicked(key))

		slot_vbox.add_child(slot_btn)
		eq_grid.add_child(slot_vbox)

	# 6. RASTREADOR DE MISSÕES (HUD Lateral Direito)
	ui_quest_tracker = PanelContainer.new()
	ui_quest_tracker.custom_minimum_size = Vector2(240, 90)
	ui_quest_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var tracker_style = StyleBoxFlat.new()
	tracker_style.bg_color = Color(0.1, 0.1, 0.12, 0.65)
	tracker_style.set_corner_radius_all(4)
	tracker_style.set_border_width_all(1)
	tracker_style.border_color = Color(0.4, 0.35, 0.2, 0.8)
	ui_quest_tracker.add_theme_stylebox_override("panel", tracker_style)
	
	hud_layer.add_child(ui_quest_tracker)
	ui_quest_tracker.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ui_quest_tracker.offset_right = -25
	ui_quest_tracker.offset_left = -345
	ui_quest_tracker.offset_top = 670

	var tracker_main_vbox = VBoxContainer.new()
	tracker_main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker_main_vbox.add_theme_constant_override("separation", 6)
	ui_quest_tracker.add_child(tracker_main_vbox)

	var tracker_title = Label.new()
	tracker_title.text = "MISSÕES ATIVAS"
	tracker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tracker_title.add_theme_font_size_override("font_size", 11)
	tracker_title.modulate = Color(1.0, 0.85, 0.3)
	tracker_main_vbox.add_child(tracker_title)

	ui_quest_list_vbox = VBoxContainer.new()
	ui_quest_list_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_quest_list_vbox.add_theme_constant_override("separation", 8)
	tracker_main_vbox.add_child(ui_quest_list_vbox)

	# 7. PAINEL DE DIÁLOGO (NPC / QUESTS)
	ui_dialogue_panel = PanelContainer.new()
	ui_dialogue_panel.custom_minimum_size = Vector2(500, 140)
	ui_dialogue_panel.visible = false
	if custom_theme: ui_dialogue_panel.theme = custom_theme
	hud_layer.add_child(ui_dialogue_panel)

	ui_dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ui_dialogue_panel.offset_left = 250
	ui_dialogue_panel.offset_right = -250
	ui_dialogue_panel.offset_bottom = -30
	ui_dialogue_panel.offset_top = -170

	var d_vbox = VBoxContainer.new()
	d_vbox.add_theme_constant_override("separation", 8)
	ui_dialogue_panel.add_child(d_vbox)

	ui_dialogue_npc_name = Label.new()
	ui_dialogue_npc_name.text = "Nome do NPC"
	ui_dialogue_npc_name.add_theme_font_size_override("font_size", 14)
	ui_dialogue_npc_name.modulate = Color(1.0, 0.85, 0.3)
	d_vbox.add_child(ui_dialogue_npc_name)

	ui_dialogue_text_label = Label.new()
	ui_dialogue_text_label.text = "Mensagem do NPC vai aqui..."
	ui_dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_dialogue_text_label.custom_minimum_size = Vector2(460, 60)
	ui_dialogue_text_label.add_theme_font_size_override("font_size", 13)
	d_vbox.add_child(ui_dialogue_text_label)

	var d_hbox = HBoxContainer.new()
	d_hbox.alignment = BoxContainer.ALIGNMENT_END
	d_vbox.add_child(d_hbox)

	ui_dialogue_close_btn = Button.new()
	ui_dialogue_close_btn.text = "Fechar [ESC]"
	ui_dialogue_close_btn.custom_minimum_size = Vector2(100, 30)
	ui_dialogue_close_btn.pressed.connect(close_dialogue_window)
	d_hbox.add_child(ui_dialogue_close_btn)

	# 8. PAINEL DE DIÁRIO DE MISSÕES (Atalho Q)
	ui_quest_panel = PanelContainer.new()
	ui_quest_panel.custom_minimum_size = Vector2(340, 380)
	ui_quest_panel.visible = false
	if custom_theme: ui_quest_panel.theme = custom_theme
	hud_layer.add_child(ui_quest_panel)
	
	ui_quest_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ui_quest_panel.offset_left = -170
	ui_quest_panel.offset_right = 170
	ui_quest_panel.offset_top = -190
	ui_quest_panel.offset_bottom = 190

	var q_box = VBoxContainer.new()
	q_box.add_theme_constant_override("separation", 8)
	ui_quest_panel.add_child(q_box)

	var q_title = Label.new()
	q_title.text = "--- DIÁRIO DE MISSÕES ---"
	q_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_box.add_child(q_title)

	var q_scroll = ScrollContainer.new()
	q_scroll.custom_minimum_size = Vector2(320, 310)
	q_box.add_child(q_scroll)

	ui_quest_list_container = VBoxContainer.new()
	ui_quest_list_container.custom_minimum_size = Vector2(300, 300)
	ui_quest_list_container.add_theme_constant_override("separation", 10)
	q_scroll.add_child(ui_quest_list_container)

	update_hud_display()
	populate_inventory_ui()
	update_quest_tracker_ui()

func add_item_to_inventory(item: ItemData, quantity: int = 1) -> bool:
	print("[DEBUG] Item adicionado ao inventario : %s", item)
	if not item or quantity <= 0:
		return false

	var remaining = quantity

	if item.is_stackable:
		for i in range(INVENTORY_CAPACITY):
			var slot = inventory_items[i]
			if slot != null and slot["item"].id == item.id:
				var space_available = item.max_stack - slot["amount"]
				if space_available > 0:
					var to_add = min(remaining, space_available)
					slot["amount"] += to_add
					remaining -= to_add
					if remaining <= 0:
						break

	if remaining > 0:
		for i in range(INVENTORY_CAPACITY):
			if inventory_items[i] == null:
				var max_fit = item.max_stack if item.is_stackable else 1
				var to_add = min(remaining, max_fit)
				inventory_items[i] = {
					"item": item,
					"amount": to_add
				}
				remaining -= to_add
				if remaining <= 0:
					break

	update_inventory_display()
	return remaining == 0

func populate_inventory_ui() -> void:
	if not ui_inv_grid:
		return

	for child in ui_inv_grid.get_children():
		child.queue_free()

	for i in range(INVENTORY_CAPACITY):
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(60, 60)
		slot_btn.focus_mode = Control.FOCUS_NONE
		slot_btn.clip_contents = true

		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.18, 0.18, 0.2, 0.8)
		slot_style.set_corner_radius_all(4)

		var slot_data = inventory_items[i]
		if slot_data != null and slot_data is Dictionary:
			var item: ItemData = slot_data.get("item", null)
			var amount: int = int(slot_data.get("amount", 1))

			if item:
				if "is_quest_item" in item and item.is_quest_item:
					slot_style.border_color = Color(1.0, 0.82, 0.1, 1.0)
					slot_style.set_border_width_all(2)

				var icon_3d = create_item_3d_viewport(item.mesh_scene, item)
				slot_btn.add_child(icon_3d)

				if amount > 1:
					var count_lbl = Label.new()
					count_lbl.text = str(amount)
					count_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
					count_lbl.offset_left = -30
					count_lbl.offset_top = -20
					count_lbl.offset_right = -4
					count_lbl.offset_bottom = -2
					count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					count_lbl.add_theme_font_size_override("font_size", 12)
					count_lbl.add_theme_color_override("font_color", Color(0.52, 0.534, 0.519, 1.0))
					count_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
					count_lbl.add_theme_constant_override("outline_size", 2)
					slot_btn.add_child(count_lbl)

		slot_btn.add_theme_stylebox_override("normal", slot_style)

		var current_idx = i
		# Conexão direta com debug no clique do inventário
		slot_btn.pressed.connect(func():
			print("[DEBUG INVENTÁRIO] Botão do slot ", current_idx, " foi clicado!")
			_on_inventory_slot_clicked(current_idx, slot_btn)
		)
		slot_btn.mouse_entered.connect(func(): _show_item_tooltip(current_idx, slot_btn))
		slot_btn.mouse_exited.connect(_hide_item_tooltip)

		ui_inv_grid.add_child(slot_btn)

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

func _on_inventory_slot_clicked(slot_idx: int, _slot_node: Control) -> void:
	print("[DEBUG INVENTÁRIO] Analisando clique no índice: ", slot_idx)
	
	if slot_idx < 0 or slot_idx >= inventory_items.size():
		return

	var slot_data = inventory_items[slot_idx]
	if slot_data == null:
		print("[DEBUG INVENTÁRIO] O slot ", slot_idx, " está VAZIO (null).")
		return

	var item: ItemData = slot_data.get("item", null)
	if not item:
		return

	# Define exclusivamente o índice do inventário
	selected_slot_index = slot_idx
	active_equipment_slot = "" # Limpa o equipamento para evitar conflito

	if not item_context_menu:
		item_context_menu = PopupMenu.new()
		if not item_context_menu.id_pressed.is_connected(_on_context_menu_item_selected):
			item_context_menu.id_pressed.connect(_on_context_menu_item_selected)
		hud_layer.add_child(item_context_menu)

	item_context_menu.clear()
	
	if item.item_type == ItemData.ItemType.CONSUMABLE:
		item_context_menu.add_item("Usar", 0)
	elif item.item_type in [ItemData.ItemType.WEAPON, ItemData.ItemType.ARMOR, ItemData.ItemType.HELM, ItemData.ItemType.BOOTS]:
		item_context_menu.add_item("Equipar", 1)

	var is_quest = "is_quest_item" in item and item.is_quest_item
	if not is_quest:
		item_context_menu.add_separator()
		item_context_menu.add_item("Descartar", 2)

	item_context_menu.position = Vector2i(get_viewport().get_mouse_position())
	item_context_menu.reset_size()
	item_context_menu.popup()

func _on_context_menu_item_selected(id: int) -> void:
	print("[DIAGNÓSTICO] Menu acionado. ID: ", id, " | Inv Slot: ", selected_slot_index, " | Eq Slot: ", active_equipment_slot)

	# Se for comando de desequipar (ID 10)
	if id == 10 and active_equipment_slot != "":
		unequip_item(active_equipment_slot)
		active_equipment_slot = ""
		_hide_item_tooltip()
		return

	# Se for comandos do inventário (Usar, Equipar, Descartar)
	if selected_slot_index >= 0:
		if selected_slot_index >= inventory_items.size() or inventory_items[selected_slot_index] == null:
			print("[ERRO] Slot do inventário inválido ou vazio no momento da ação.")
			return

		var slot_data = inventory_items[selected_slot_index]
		var item: ItemData = slot_data.get("item", null)
		if not item:
			return

		match id:
			0:
				use_consumable(item, selected_slot_index)
			1:
				equip_item_from_inventory(item, selected_slot_index)
			2:
				discard_item(selected_slot_index)

		selected_slot_index = -1

	_hide_item_tooltip()

func equip_item_from_inventory(item: ItemData, slot_idx: int) -> void:
	print("[DIAGNÓSTICO EQUIPAR] Tentando equipar: ", item.name, " do slot inventário: ", slot_idx)
	if not item or slot_idx < 0 or slot_idx >= INVENTORY_CAPACITY:
		print("[ERRO EQUIPAR] Parâmetros inválidos.")
		return

	var slot_data = inventory_items[slot_idx]
	if slot_data != null and slot_data.get("amount", 1) > 1:
		print("[EQUIPAR] Separe o item antes de equipar!")
		return

	var target_slot_key = ""
	match item.item_type:
		ItemData.ItemType.WEAPON: target_slot_key = "weapon"
		ItemData.ItemType.ARMOR: target_slot_key = "armor"
		ItemData.ItemType.HELM: target_slot_key = "helm"
		ItemData.ItemType.BOOTS: target_slot_key = "boots"

	print("[DIAGNÓSTICO EQUIPAR] Slot de destino mapeado: ", target_slot_key)
	if target_slot_key == "":
		print("[ERRO EQUIPAR] Tipo de item desconhecido para equipamento.")
		return

	var old_item: ItemData = equipped_items.get(target_slot_key, null)
	if old_item:
		print("[DIAGNÓSTICO EQUIPAR] Substituindo item antigo: ", old_item.name)
		attack_damage -= old_item.bonus_attack
		defense -= old_item.bonus_defense
		bonus_hp -= old_item.bonus_hp
		bonus_mana -= old_item.bonus_mana
		inventory_items[slot_idx] = {"item": old_item, "amount": 1}
	else:
		print("[DIAGNÓSTICO EQUIPAR] Slot de destino estava vazio. Liberando inventário no slot: ", slot_idx)
		inventory_items[slot_idx] = null

	equipped_items[target_slot_key] = item
	attack_damage += item.bonus_attack
	defense += item.bonus_defense
	bonus_hp += item.bonus_hp
	bonus_mana += item.bonus_mana

	if target_slot_key == "weapon":
		current_weapon_mesh_path = item.mesh_scene.resource_path if item.mesh_scene else ""
		update_hand_visual(item.mesh_scene)

	update_equipment_slot_visual(target_slot_key, item)
	recalculate_derived_stats()
	update_inventory_display()
	update_hud_display()
	print("[DIAGNÓSTICO EQUIPAR] Sucesso! Item equipado com êxito.")

func unequip_item(slot_key: String) -> bool:
	if not equipped_items.has(slot_key) or equipped_items[slot_key] == null:
		print("[DEBUG] Tentou desequipar slot vazio ou inexistente: ", slot_key)
		return false

	var item: ItemData = equipped_items[slot_key]
	print("[DEBUG] Iniciando desequipamento do item: ", item.name, " do slot: ", slot_key)

	# Tenta adicionar o item de volta ao inventário
	var success = add_item_to_inventory(item, 1)
	if not success:
		print("[ERRO] Falha ao desequipar: Inventário cheio ou incapaz de receber o item!")
		return false

	# Remove os bônus
	attack_damage -= item.bonus_attack
	defense -= item.bonus_defense
	bonus_hp -= item.bonus_hp
	bonus_mana -= item.bonus_mana

	# Limpa o equipamento ativo
	equipped_items[slot_key] = null

	if slot_key == "weapon":
		current_weapon_mesh_path = ""
		update_hand_visual(null)

	recalculate_derived_stats()
	update_equipment_slot_visual(slot_key, null)
	update_inventory_display()
	update_hud_display()
	
	print("[EQUIPAMENTOS] Item desequipado com sucesso e transferido para o inventário!")
	return true

func _on_equipment_slot_clicked(slot_key: String) -> void:
	print("[DEBUG] Slot de equipamento clicado: ", slot_key)
	if not equipped_items.has(slot_key) or equipped_items[slot_key] == null:
		print("[DEBUG] Slot está vazio!")
		return

	active_equipment_slot = slot_key
	selected_slot_index = -1 # Reseta o inventário para evitar conflito

	if not item_context_menu:
		item_context_menu = PopupMenu.new()
		if not item_context_menu.id_pressed.is_connected(_on_context_menu_item_selected):
			item_context_menu.id_pressed.connect(_on_context_menu_item_selected)
		hud_layer.add_child(item_context_menu)

	item_context_menu.clear()
	item_context_menu.add_item("Desequipar", 10) # ID 10 exclusivo para desequipar

	item_context_menu.position = Vector2i(get_viewport().get_mouse_position())
	item_context_menu.reset_size()
	item_context_menu.popup()

func _on_equipment_menu_selected(_id: int) -> void:
	pass

func use_consumable(item: ItemData, slot_idx: int) -> void:
	hp = min(max_hp, hp + item.bonus_hp)
	mana = min(max_mana, mana + item.bonus_mana)
	
	if inventory_items[slot_idx] != null:
		inventory_items[slot_idx]["amount"] -= 1
		if inventory_items[slot_idx]["amount"] <= 0:
			inventory_items[slot_idx] = null

	recalculate_derived_stats()
	update_hud_display()
	update_inventory_display()

func update_equipment_slot_visual(slot_key: String, item_data: ItemData) -> void:
	if equipment_slot_nodes.is_empty() or not equipment_slot_nodes.has(slot_key):
		await get_tree().process_frame

	if not equipment_slot_nodes.has(slot_key):
		return

	var slot_btn: Control = equipment_slot_nodes[slot_key]
	if not is_instance_valid(slot_btn):
		return

	for child in slot_btn.get_children():
		child.queue_free()

	if item_data and item_data.mesh_scene:
		var icon_3d = create_item_3d_viewport(item_data.mesh_scene, item_data)
		slot_btn.add_child(icon_3d)

func _show_item_tooltip(slot_idx: int, slot_node: Control) -> void:
	var slot_data = inventory_items[slot_idx]
	if slot_data == null:
		return

	var item: ItemData = slot_data["item"]
	if not item:
		return

	if not item_tooltip_panel:
		item_tooltip_panel = PanelContainer.new()
		var t_style = StyleBoxFlat.new()
		t_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
		t_style.set_corner_radius_all(4)
		t_style.set_border_width_all(1)
		t_style.border_color = Color(0.6, 0.5, 0.2)
		item_tooltip_panel.add_theme_stylebox_override("panel", t_style)
		hud_layer.add_child(item_tooltip_panel)

	for child in item_tooltip_panel.get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	item_tooltip_panel.add_child(vbox)

	var title = Label.new()
	title.text = "%s (x%d)" % [item.name, slot_data["amount"]] if slot_data["amount"] > 1 else item.name
	title.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = item.description
	desc.add_theme_font_size_override("font_size", 11)
	desc.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(desc)

	if item.bonus_attack > 0:
		var lbl_atk = Label.new()
		lbl_atk.text = "+%d Ataque Físico" % item.bonus_attack
		lbl_atk.modulate = Color(0.9, 0.3, 0.3)
		vbox.add_child(lbl_atk)

	if item.bonus_defense > 0:
		var lbl_def = Label.new()
		lbl_def.text = "+%d Defesa" % item.bonus_defense
		lbl_def.modulate = Color(0.3, 0.6, 1.0)
		vbox.add_child(lbl_def)

	if "is_quest_item" in item and item.is_quest_item:
		var q_lbl = Label.new()
		q_lbl.text = "[ITEM DE MISSÃO - NÃO DESCARTÁVEL]"
		q_lbl.modulate = Color(1.0, 0.75, 0.1)
		q_lbl.add_theme_font_size_override("font_size", 10)
		vbox.add_child(q_lbl)

	item_tooltip_panel.visible = true
	item_tooltip_panel.position = slot_node.global_position + Vector2(65, 0)

func _hide_item_tooltip() -> void:
	if item_tooltip_panel:
		item_tooltip_panel.visible = false

func update_inventory_display() -> void:
	populate_inventory_ui()

# --- AUXILIARES E INTERFACE DE STATUS ---

func create_stat_row(title: String, stat_key: String) -> Dictionary:
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "%s: 5" % title
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var btn = Button.new()
	btn.text = " + "
	btn.pressed.connect(func():
		allocate_attribute(stat_key)
	)
	hbox.add_child(btn)

	return {"container": hbox, "label": lbl, "btn": btn}

func toggle_attribute_window() -> void:
	if not ui_attr_panel or not ui_status_panel:
		return
	var is_visible = not ui_attr_panel.visible
	ui_attr_panel.visible = is_visible
	ui_status_panel.visible = is_visible
	
	if is_visible or (ui_inventory_panel and ui_inventory_panel.visible):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_inventory_window() -> void:
	if not ui_inventory_panel or not ui_equipment_panel:
		return
	var is_visible = not ui_inventory_panel.visible
	ui_inventory_panel.visible = is_visible
	ui_equipment_panel.visible = is_visible
	
	if is_visible or (ui_attr_panel and ui_attr_panel.visible):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func update_hud_display() -> void:
	if not ui_level_label:
		return

	ui_level_label.text = "Nível %d (EXP: %d / %d) [C: Atrib | I: Inv]" % [player_level, current_xp, required_xp]
	ui_xp_bar.max_value = required_xp
	ui_xp_bar.value = current_xp
	ui_points_label.text = "Pontos Disponíveis: %d" % unspent_points

	ui_lbl_str.text = "Força: %d" % stat_str
	ui_lbl_agi.text = "Agilidade: %d" % stat_agi
	ui_lbl_vit.text = "Vitalidade: %d" % stat_vit
	ui_lbl_int.text = "Inteligência: %d" % stat_int

	var final_hp = (100 + (player_level * 15) + (stat_vit * 12)) + bonus_hp
	lbl_hp_status.text = "HP: %d / %d" % [hp, final_hp]

	var final_mana = (80 + (player_level * 10) + (stat_int * 15)) + bonus_mana
	lbl_mana_status.text = "Mana: %d / %d" % [mana, final_mana]

	var final_def = (4 + int(stat_vit * 0.8)) + bonus_defense
	lbl_def_status.text = "Defesa: %d" % final_def

	lbl_atk_status.text = "Ataque Físico: %d" % attack_damage
	lbl_matk_status.text = "Ataque Mágico: %d" % magic_damage
	lbl_speed_status.text = "Velocidade: %.1f m/s" % speed
	lbl_evasion_status.text = "Esquiva: %.1f %%" % evasion

	var can_spend = unspent_points > 0
	ui_btn_str.disabled = not can_spend
	ui_btn_agi.disabled = not can_spend
	ui_btn_vit.disabled = not can_spend
	ui_btn_int.disabled = not can_spend

func update_hand_visual(mesh_scene: PackedScene) -> void:
	if not right_hand_bone:
		return

	for child in right_hand_bone.get_children():
		child.queue_free()

	if mesh_scene:
		var item_instance = mesh_scene.instantiate()
		right_hand_bone.add_child(item_instance)
		item_instance.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		item_instance.scale = Vector3(0.01, 0.01, 0.01)
		item_instance.position = Vector3.ZERO

func discard_item(slot_idx: int) -> void:
	print("[DIAGNÓSTICO DESCARTAR] Tentando descartar do slot: ", slot_idx)
	if slot_idx < 0 or slot_idx >= INVENTORY_CAPACITY or inventory_items[slot_idx] == null:
		print("[ERRO DESCARTAR] Slot inválido ou vazio.")
		return

	var slot_data = inventory_items[slot_idx]
	var item_to_drop: ItemData = slot_data["item"]
	
	if not item_to_drop is ItemData or ("is_quest_item" in item_to_drop and item_to_drop.is_quest_item):
		print("[INVENTÁRIO] Descarte de item de missão impedido!")
		return

	slot_data["amount"] -= 1
	if slot_data["amount"] <= 0:
		inventory_items[slot_idx] = null

	print("[DIAGNÓSTICO DESCARTAR] Item descartado com sucesso do slot: ", slot_idx)
	update_inventory_display()

func open_dialogue_window(npc_title: String, text: String) -> void:
	if not ui_dialogue_panel:
		return

	ui_dialogue_npc_name.text = npc_title
	ui_dialogue_text_label.text = text
	ui_dialogue_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_dialogue_window() -> void:
	if not ui_dialogue_panel:
		return

	ui_dialogue_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_quest_window() -> void:
	if not ui_quest_panel:
		return
	
	var is_visible = not ui_quest_panel.visible
	ui_quest_panel.visible = is_visible
	
	if is_visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if (not ui_attr_panel or not ui_attr_panel.visible) and (not ui_inventory_panel or not ui_inventory_panel.visible):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func load_player_save(username: String) -> void:
	player_name = username
	var file_path = "user://accounts/" + username + ".json"

	if not FileAccess.file_exists(file_path):
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return

	var json_data = JSON.parse_string(file.get_as_text())
	file.close()

	if not json_data is Dictionary:
		return

	player_level = int(json_data.get("level", 1))
	current_xp = int(json_data.get("current_xp", 0))
	required_xp = int(json_data.get("required_xp", 100))
	unspent_points = int(json_data.get("unspent_points", 0))
	
	var pos_data = json_data.get("last_position", null)
	if pos_data is Dictionary:
		global_position = Vector3(pos_data.get("x", 0), pos_data.get("y", 1), pos_data.get("z", 0))

	var stats = json_data.get("stats", {}) as Dictionary
	stat_str = int(stats.get("str", 5))
	stat_agi = int(stats.get("agi", 5))
	stat_vit = int(stats.get("vit", 5))
	stat_int = int(stats.get("int", 5))

	var inv_data = json_data.get("inventory", []) as Array
	inventory_items.clear()
	inventory_items.resize(INVENTORY_CAPACITY)
	for i in range(min(inv_data.size(), INVENTORY_CAPACITY)):
		var entry = inv_data[i]
		if entry is Dictionary and entry.has("path"):
			var res_path = str(entry.get("path", ""))
			var amt = int(entry.get("amount", 1))
			if res_path != "" and ResourceLoader.exists(res_path):
				inventory_items[i] = {
					"item": load(res_path),
					"amount": amt
				}

	# Limpa os equipamentos antes de carregar para evitar sobreposição de bônus ou referências fantasmas
	for k in equipped_items.keys():
		equipped_items[k] = null

	var eq_data = json_data.get("equipment", {}) as Dictionary
	for slot_key in ["helm", "armor", "boots", "weapon"]:
		var eq_path = str(eq_data.get(slot_key, ""))
		if eq_path != "" and ResourceLoader.exists(eq_path):
			var item: ItemData = load(eq_path)
			equipped_items[slot_key] = item
			attack_damage += item.bonus_attack
			defense += item.bonus_defense
			bonus_hp += item.bonus_hp
			bonus_mana += item.bonus_mana

	current_weapon_mesh_path = str(json_data.get("weapon_mesh_path", ""))
	if current_weapon_mesh_path == "" and equipped_items.get("weapon") != null:
		var w_item: ItemData = equipped_items["weapon"]
		if w_item and w_item.mesh_scene:
			current_weapon_mesh_path = w_item.mesh_scene.resource_path

	active_quests = json_data.get("active_quests", {})
	completed_quests = json_data.get("completed_quests", [])

	recalculate_derived_stats()
	hp = max_hp
	mana = max_mana
	
	update_hud_display()
	update_inventory_display()
	
	# Garante a atualização visual correta de cada slot de equipamento ao iniciar o jogo
	for slot_key in ["helm", "armor", "boots", "weapon"]:
		var item: ItemData = equipped_items.get(slot_key, null)
		if item:
			update_equipment_slot_visual(slot_key, item)
			if slot_key == "weapon" and item.mesh_scene:
				update_hand_visual(item.mesh_scene)
		else:
			update_equipment_slot_visual(slot_key, null)

	if has_node("/root/QuestManager"):
		QuestManager.sync_player_quests(self)

func save_player_account() -> void:
	if player_name.is_empty():
		return

	var file_path = "user://accounts/" + player_name + ".json"
	var existing_pass_hash = ""

	if FileAccess.file_exists(file_path):
		var read_file = FileAccess.open(file_path, FileAccess.READ)
		if read_file:
			var old_data = JSON.parse_string(read_file.get_as_text())
			read_file.close()
			if old_data is Dictionary:
				existing_pass_hash = old_data.get("password_hash", "")

	var serialized_inventory: Array = []
	for slot in inventory_items:
		if slot != null and slot is Dictionary and slot.get("item") is ItemData:
			serialized_inventory.append({
				"path": slot["item"].resource_path,
				"amount": slot.get("amount", 1)
			})
		else:
			serialized_inventory.append(null)

	var serialized_equipment: Dictionary = {}
	for slot_key in equipped_items.keys():
		var eq_item = equipped_items[slot_key]
		if eq_item is ItemData and eq_item.resource_path != "":
			serialized_equipment[slot_key] = eq_item.resource_path
		else:
			serialized_equipment[slot_key] = ""

	var account_data = {
		"username": player_name,
		"password_hash": existing_pass_hash,
		"level": player_level,
		"current_xp": current_xp,
		"required_xp": required_xp,
		"unspent_points": unspent_points,
		"stats": {
			"str": stat_str,
			"agi": stat_agi,
			"vit": stat_vit,
			"int": stat_int
		},
		"inventory": serialized_inventory,
		"equipment": serialized_equipment,
		"weapon_mesh_path": current_weapon_mesh_path,
		"last_position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z
		},
		"active_quests": active_quests,
		"completed_quests": completed_quests
	}

	var write_file = FileAccess.open(file_path, FileAccess.WRITE)
	if write_file:
		write_file.store_string(JSON.stringify(account_data, "\t"))
		write_file.close()
		print("[SAVE] Progresso, inventário e missões salvos para o herói: ", player_name)

func update_quest_tracker_ui() -> void:
	if not ui_quest_list_vbox or not ui_quest_tracker:
		return

	for child in ui_quest_list_vbox.get_children():
		child.queue_free()

	if client_active_quests.is_empty():
		ui_quest_tracker.visible = false
		return

	ui_quest_tracker.visible = true

	for q in client_active_quests:
		var q_title: String = q.get("title", "Missão")
		var cur: int = int(q.get("current", 0))
		var req: int = int(q.get("required", 1))
		var is_done: bool = bool(q.get("completed", false))

		var quest_entry_box = VBoxContainer.new()
		quest_entry_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var lbl_title = Label.new()
		lbl_title.text = "• %s" % q_title
		lbl_title.add_theme_font_size_override("font_size", 12)
		lbl_title.modulate = Color(0.95, 0.95, 0.95)
		quest_entry_box.add_child(lbl_title)

		var lbl_progress = Label.new()
		lbl_progress.add_theme_font_size_override("font_size", 11)

		if is_done:
			lbl_progress.text = "   Pronta para entregar!"
			lbl_progress.modulate = Color(0.3, 1.0, 0.4)
		else:
			lbl_progress.text = "   Progresso: %d / %d" % [cur, req]
			lbl_progress.modulate = Color(0.75, 0.75, 0.75)

		quest_entry_box.add_child(lbl_progress)
		ui_quest_list_vbox.add_child(quest_entry_box)

func populate_quest_log_ui() -> void:
	if not ui_quest_list_container:
		return

	for child in ui_quest_list_container.get_children():
		child.queue_free()

	if client_active_quests.is_empty():
		var lbl_empty = Label.new()
		lbl_empty.text = "Nenhuma missão registrada no momento."
		lbl_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_empty.modulate = Color(0.7, 0.7, 0.7)
		ui_quest_list_container.add_child(lbl_empty)
		return

	for q in client_active_quests:
		var box = VBoxContainer.new()
		
		var title_lbl = Label.new()
		title_lbl.text = "• %s" % q.get("title", "Missão")
		title_lbl.modulate = Color(1.0, 0.85, 0.3)
		title_lbl.add_theme_font_size_override("font_size", 13)
		box.add_child(title_lbl)

		var cur = int(q.get("current", 0))
		var req = int(q.get("required", 1))
		var is_done = bool(q.get("completed", false))

		var prog_lbl = Label.new()
		if is_done:
			prog_lbl.text = "   Status: Pronto para entregar ao NPC!"
			prog_lbl.modulate = Color(0.3, 1.0, 0.4)
		else:
			prog_lbl.text = "   Progresso: %d / %d" % [cur, req]
			prog_lbl.modulate = Color(0.8, 0.8, 0.8)
		prog_lbl.add_theme_font_size_override("font_size", 11)
		box.add_child(prog_lbl)

		ui_quest_list_container.add_child(box)

func _exit_tree() -> void:
	save_player_account()
