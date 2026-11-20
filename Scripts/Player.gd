class_name Player
extends CharacterBody3D

@export var mouse_sensitivity: float = 0.003
@export var attack_reach: float = 3.0
@export var combo_window_time: float = 1.0
@export var max_targets_per_hit: int = 4
@export var hud_ref : HUD

var spell_cast_lockout: float = 0.0

@onready var skill_manager = $SkillManager
@onready var equipment_manager: EquipmentManager = $EquipmentManager

# --- SISTEMA DE STATUS E EFEITOS ---
var active_player_status: String = ""
var player_status_timer: float = 0.0
var player_status_tick: float = 0.0
var player_status_damage: int = 0
var base_player_speed: float = 5.5
@onready var venom_effect: GPUParticles3D = $VenomEffect
@onready var fire_effect: GPUParticles3D = $FireEffect
@onready var frost_effect: GPUParticles3D = $FrostEffect

# Identificação e Atributos Base
var player_name: String = "Aventureiro"
var stat_str: int = 5
var stat_agi: int = 5
var stat_vit: int = 5
var stat_int: int = 5

# Atributos Derivados e Status
var speed: float = 5.5
var is_running: bool = false
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
var evasion: float = 5.0

var attack_cooldown_time: float = 0.45

# --- SISTEMA DE MISSÕES (QUESTS) ---
var client_active_quests: Array = [] # Lista formatada para HUD
var completed_quests: Array = []     # Lista de IDs completos
var quest_board_ui_scene = preload("res://Scenes/UI/QuestBoardUI.tscn")
var active_board_ui: Control = null

# Variáveis do Painel de Diálogo
var ui_dialogue_panel: PanelContainer = null
var ui_dialogue_npc_name: Label = null
var ui_dialogue_text_label: Label = null
var ui_dialogue_close_btn: Button = null
var ui_quest_panel: PanelContainer = null
var ui_quest_list_container: VBoxContainer = null
var ui_mastery_panel: PanelContainer = null
var ui_mastery_list_container: VBoxContainer = null

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

@export var WAREHOUSE_CAPACITY: int = 4096
var warehouse_items: Array = []

# UI do Baú e Coleta
var ui_chest_panel: PanelContainer = null
var ui_chest_list_vbox: VBoxContainer = null
var active_chest_ref: Node3D = null

@export_category("Ferramentas de Coleta (Meshes)")
@export var axe_tool_mesh: PackedScene
@export var pickaxe_tool_mesh: PackedScene
@export var gather_cooldown_duration: float = 30.0
var gather_cooldown_timer: float = 0.0
var is_gathering_locked: bool = false

# Progressão
var player_level: int = 1
var current_xp: int = 0
var required_xp: int = 100
var unspent_points: int = 0

# --- SISTEMA DE CONQUISTAS E ESTATÍSTICAS (Expansível) ---
const SAVE_ENCRYPTION_KEY: String = "Vallirya_2026_Secure_Save_Key_#91"
var achievements_stats: Dictionary = {
	"total_monsters_killed": 0,
	"monsters_killed_by_id": {},
	"side_quests_completed": 0,
	"main_story_progress": 0,
	"total_items_collected": 0,
	"items_collected_by_id": {}
}

var is_dead: bool = false

# Inputs e combo
var attack_timer: float = 0.0
var combo_step: int = 1
var combo_reset_timer: float = 0.0

#Magias
var is_targeting_spell: bool = false
var pending_spell_id: int = -1
var active_spell_decal: Node3D = null
var spell_decal_scene = preload("res://Scenes/VFX/SpellDecal.tscn") 

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
@onready var mana_bar: ProgressBar = $PlayerInfoSprite/SubViewport/VBoxContainer/ManaBar

# Áudios e Efeitos Visuais
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio
@onready var attack_audio: AudioStreamPlayer3D = $AttackAudio
@onready var step_audio: AudioStreamPlayer3D = $StepAudio
@onready var levelup_audio: AudioStreamPlayer3D = get_node_or_null("LevelUpAudio")
@onready var levelup_beam: MeshInstance3D = get_node_or_null("LevelUpBeam")

var floating_damage_scene = preload("res://Scenes/VFX/FloatingDamage.tscn")
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

@onready var right_hand_bone: BoneAttachment3D = $"Personagem (IK)/Armature/Skeleton3D/RightHand"
@onready var left_hand_bone: BoneAttachment3D = $"Personagem (IK)/Armature/Skeleton3D/LeftHand"
@onready var head_bone: BoneAttachment3D = $"Personagem (IK)/Armature/Skeleton3D/Head"
@onready var chest_bone: BoneAttachment3D = $"Personagem (IK)/Armature/Skeleton3D/Chest"
@onready var torso_bone: BoneAttachment3D = $"Personagem (IK)/Armature/Skeleton3D/Torso"
@onready var left_feet_bone: BoneAttachment3D = $"Personagem (IK)/Armature/Skeleton3D/LeftFeet"
@onready var right_feet_bone: BoneAttachment3D = $"Personagem (IK)/Armature/Skeleton3D/RightFeet"
@onready var horse_place: BoneAttachment3D = $"Personagem (IK)/Armature/Skeleton3D/Body"

@onready var torch_light: OmniLight3D = $TorchLight

var out_of_combat_timer: float = 0.0
const COMBAT_COOLDOWN_DURATION: float = 10.0
var regen_tick_timer: float = 0.0

func _init() -> void:
	inventory_items.resize(INVENTORY_CAPACITY)

func _ready() -> void:
	add_to_group("Player")
	setup_local_hud()
	warehouse_items.resize(WAREHOUSE_CAPACITY)

	if "current_player_name" in LevelManager and LevelManager.current_player_name != "":
		player_name = LevelManager.current_player_name
		load_player_save(player_name)
	else:
		recalculate_derived_stats()

	hp = max_hp
	mana = max_mana
	base_player_speed = speed

	if player_info_sprite and sub_viewport:
		player_info_sprite.texture = sub_viewport.get_texture()
		health_bar.max_value = max_hp
		health_bar.value = hp
		mana_bar.max_value = max_mana
		mana_bar.value = mana

	if anim_tree:
		anim_tree.active = true
	var player_col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if player_col:
		player_col.disabled = false
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
	# Reseta os bônus derivados para calcular do zero com base nos atributos base + equipamentos
	var base_atk = 8 + int(stat_str * 0.5)
	var base_def = stat_vit * 1
	
	var eq_atk = 0
	var eq_def = 0
	var eq_hp = 0
	var eq_mana = 0

	for slot_key in equipped_items.keys():
		var eq_item: ItemData = equipped_items[slot_key]
		if eq_item:
			eq_atk += int(eq_item.bonus_attack)
			eq_def += int(eq_item.bonus_defense)
			eq_hp += int(eq_item.bonus_hp)
			eq_mana += int(eq_item.bonus_mana)

	attack_damage = base_atk + eq_atk
	magic_damage = 10 + int(stat_int * 1.5)
	defense = base_def + eq_def
	evasion = min(35.0, 5.0 + (stat_agi * 0.4))
	max_hp = 100 + (stat_vit * 10) + eq_hp
	max_mana = 100 + (stat_int * 10) + eq_mana

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event.is_action_pressed("Correr"):
		is_running = not is_running
		if is_mounted:
			var player_run_speed: float = base_player_speed * 1.45
			var horse_walk_speed: float = player_run_speed * 1.5
			speed = horse_walk_speed * 2.0 if is_running else horse_walk_speed
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			toggle_achievements_window()

	if skill_manager and skill_manager.is_targeting_spell:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				skill_manager.confirm_targeted_cast()
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_RIGHT or event.is_action_pressed("ui_cancel"):
				skill_manager.cancel_targeting()
				get_viewport().set_input_as_handled()
				return
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_C:
		toggle_attribute_window()

	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		toggle_inventory_window()

	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		toggle_quest_window()

	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if ui_dialogue_panel and ui_dialogue_panel.visible:
			close_dialogue_window()
			get_viewport().set_input_as_handled()
			return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_K:
		toggle_mastery_window()

	if event is InputEventKey and event.pressed and (event.keycode == KEY_CTRL):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	if Input.is_action_just_pressed("Ataque") or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE):
		if skill_manager and skill_manager.is_targeting_spell:
			skill_manager.confirm_targeted_cast()
			return
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			try_perform_local_attack()

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if spring_arm:
			spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
			spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(-65.0), deg_to_rad(30.0))

func try_cast_spell(skill_id: SkillData) -> void:
	if skill_manager:
		skill_manager.try_cast(skill_id)

func try_perform_local_attack() -> void:
	if spell_cast_lockout > 0.0 or (skill_manager and skill_manager.is_targeting_spell):
		return

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
	update_client_visuals(delta)
	check_torch_status(delta)
	if spell_cast_lockout > 0.0:
		spell_cast_lockout -= delta
	if gather_cooldown_timer > 0.0:
		gather_cooldown_timer -= delta

func _physics_process(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta

	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_step = 1
	
	if out_of_combat_timer > 0.0:
		out_of_combat_timer -= delta
	else:
		regen_tick_timer += delta
		if regen_tick_timer >= 1.0:
			regen_tick_timer = 0.0
			apply_natural_regeneration()

	if is_dead:
		return

	var move_vec = Input.get_vector("Esquerda", "Direita", "Frente", "Costas")
	var is_moving: bool = move_vec.length() > 0.1 and is_on_floor()
	var wants_jump = Input.is_action_just_pressed("Pular") and is_on_floor()
	
	var current_move_speed = speed * 1.7 if (is_running and is_moving) else speed

	if wants_jump:
		velocity.y = jump_velocity

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	elif not wants_jump:
		velocity.y = 0.0

	var local_dir = Vector3(move_vec.x, 0, move_vec.y).normalized()
	var world_dir = global_transform.basis * local_dir
	velocity.x = world_dir.x * current_move_speed
	velocity.z = world_dir.z * current_move_speed

	move_and_slide()
	
	if active_player_status != "":
		player_status_timer -= delta
		player_status_tick -= delta
		if player_status_tick <= 0.0:
			player_status_tick = 1.0
			hp = max(0, hp - player_status_damage)
			show_damage_effect(player_status_damage, hp)
		if player_status_timer <= 0.0:
			remove_player_status()

func update_client_visuals(delta: float) -> void:
	if not anim_tree or not anim_tree.active or is_dead:
		return

	var move_vec = Input.get_vector("Esquerda", "Direita", "Frente", "Costas")
	var is_moving: bool = move_vec.length() > 0.1 and is_on_floor()

	var target_state: String = "state_1"
	if is_moving:
		if is_running:
			target_state = "state_2"
		else:
			target_state = "state_1"
	else:
		target_state = "state_0"

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
		if name_label:
			name_label.text = "%s [Nv. %d]" % [player_name, player_level]

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
	trigger_combat_state()

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
			rpc_player_respawn(spawn_pos, max_hp, max_mana)
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

func rpc_player_respawn(pos: Vector3, new_hp: int, new_mp: int) -> void:
	is_dead = false
	hp = new_hp
	mana = new_mp
	
	var current_scene = get_tree().current_scene
	var spawn_node = current_scene.find_child("SpawnPoint", true, false)
	
	if spawn_node and spawn_node is Node3D:
		global_position = spawn_node.global_position
	else:
		global_position = pos if pos != Vector3.ZERO else Vector3(0, 1, 0)

	visible = true
	collision_shape.set_deferred("disabled", false)

	if health_bar:
		health_bar.value = new_hp
	if mana_bar:
		mana_bar.value = new_mp

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

func setup_local_hud() -> void:
	if hud_layer:
		hud_layer.queue_free()

	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	var hud_box = VBoxContainer.new()
	hud_box.custom_minimum_size = Vector2(300, 45)
	hud_layer.add_child(hud_box)
	
	hud_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud_box.offset_left = 25
	hud_box.offset_bottom = -25
	hud_box.offset_top = -70
	hud_box.offset_right = 325

	ui_level_label = Label.new()
	ui_level_label.text = "Nível 1 (C: Atrib | I: Inv | Q: Quests | B: Hab. | K: Maestria)"
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

	var btn_sort_inv = Button.new()
	btn_sort_inv.text = "🔄 Reorganizar Itens"
	btn_sort_inv.custom_minimum_size = Vector2(0, 28)
	btn_sort_inv.focus_mode = Control.FOCUS_NONE
	btn_sort_inv.pressed.connect(sort_and_compact_inventory)
	inv_box.add_child(btn_sort_inv)

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
	ui_dialogue_close_btn.text = "Fechar [T]"
	ui_dialogue_close_btn.custom_minimum_size = Vector2(100, 30)
	ui_dialogue_close_btn.pressed.connect(close_dialogue_window)
	d_hbox.add_child(ui_dialogue_close_btn)

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
	
	ui_mastery_panel = PanelContainer.new()
	ui_mastery_panel.custom_minimum_size = Vector2(360, 400)
	ui_mastery_panel.visible = false
	if custom_theme: ui_mastery_panel.theme = custom_theme
	hud_layer.add_child(ui_mastery_panel)
	
	ui_mastery_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ui_mastery_panel.offset_left = -180
	ui_mastery_panel.offset_right = 180
	ui_mastery_panel.offset_top = -200
	ui_mastery_panel.offset_bottom = 200

	var m_box = VBoxContainer.new()
	m_box.add_theme_constant_override("separation", 8)
	ui_mastery_panel.add_child(m_box)

	var m_title = Label.new()
	m_title.text = "--- MAESTRIA DE OFÍCIOS ---"
	m_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_title.modulate = Color(1.0, 0.85, 0.3)
	m_box.add_child(m_title)

	var m_scroll = ScrollContainer.new()
	m_scroll.custom_minimum_size = Vector2(340, 330)
	m_box.add_child(m_scroll)

	ui_mastery_list_container = VBoxContainer.new()
	ui_mastery_list_container.custom_minimum_size = Vector2(320, 320)
	ui_mastery_list_container.add_theme_constant_override("separation", 10)
	m_scroll.add_child(ui_mastery_list_container)
	
	ui_chest_panel = PanelContainer.new()
	ui_chest_panel.custom_minimum_size = Vector2(300, 260)
	ui_chest_panel.visible = false
	if custom_theme: ui_chest_panel.theme = custom_theme
	hud_layer.add_child(ui_chest_panel)
	ui_chest_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ui_chest_panel.offset_left = -150
	ui_chest_panel.offset_right = 150
	ui_chest_panel.offset_top = -130
	ui_chest_panel.offset_bottom = 130

	var c_vbox = VBoxContainer.new()
	c_vbox.add_theme_constant_override("separation", 8)
	ui_chest_panel.add_child(c_vbox)

	var c_title = Label.new()
	c_title.text = "--- CONTEÚDO DO BAÚ ---"
	c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_title.modulate = Color(1.0, 0.85, 0.3)
	c_vbox.add_child(c_title)

	var c_scroll = ScrollContainer.new()
	c_scroll.custom_minimum_size = Vector2(280, 170)
	c_vbox.add_child(c_scroll)

	ui_chest_list_vbox = VBoxContainer.new()
	ui_chest_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_chest_list_vbox.add_theme_constant_override("separation", 6)
	c_scroll.add_child(ui_chest_list_vbox)

	var c_btn_hbox = HBoxContainer.new()
	c_btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	c_btn_hbox.add_theme_constant_override("separation", 12)
	c_vbox.add_child(c_btn_hbox)

	var btn_take_all = Button.new()
	btn_take_all.text = "Pegar Tudo"
	btn_take_all.pressed.connect(_on_chest_take_all_pressed)
	c_btn_hbox.add_child(btn_take_all)

	var btn_close_chest = Button.new()
	btn_close_chest.text = "Fechar"
	btn_close_chest.pressed.connect(close_chest_loot_window)
	c_btn_hbox.add_child(btn_close_chest)

	update_hud_display()
	populate_inventory_ui()
	update_quest_tracker_ui()

func add_item_to_inventory(item: ItemData, quantity: int = 1) -> bool:
	if not item or quantity <= 0:
		return false
	register_item_collected(item.id if item.id != "" else item.name, quantity)
	if item.id in ["Moeda_Bronze_1", "Moeda_Prata_1"]:
		call_deferred("_convert_inventory_coins")
	if not item or quantity <= 0:
		return false

	var remaining = quantity

	if item.is_stackable:
		for i in range(INVENTORY_CAPACITY):
			var slot = inventory_items[i]
			if slot != null and slot is Dictionary and slot["item"].id == item.id:
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
				# Define a cor da borda com base na raridade (Comum não tem borda ou é neutra)
				var rarity_color = Color.TRANSPARENT
				match item.rarity:
					ItemData.Rarity.UNCOMMON: rarity_color = Color(0.2, 0.8, 0.2)   # Verde
					ItemData.Rarity.RARE: rarity_color = Color(0.2, 0.5, 1.0)       # Azul
					ItemData.Rarity.EPIC: rarity_color = Color(0.6, 0.2, 0.8)       # Roxo
					ItemData.Rarity.LEGENDARY: rarity_color = Color(1.0, 0.6, 0.1)  # Laranja amarelado

				if rarity_color != Color.TRANSPARENT:
					slot_style.border_color = rarity_color
					slot_style.set_border_width_all(1) # Borda bem fina (1 pixel)

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
		slot_btn.pressed.connect(func():
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
	if slot_idx < 0 or slot_idx >= inventory_items.size():
		return

	var slot_data = inventory_items[slot_idx]
	if slot_data == null:
		return

	var item: ItemData = slot_data.get("item", null)
	if not item:
		return

	selected_slot_index = slot_idx
	active_equipment_slot = ""

	if not item_context_menu:
		item_context_menu = PopupMenu.new()
		if not item_context_menu.id_pressed.is_connected(_on_context_menu_item_selected):
			item_context_menu.id_pressed.connect(_on_context_menu_item_selected)
		hud_layer.add_child(item_context_menu)

	item_context_menu.clear()
	
	if item.item_type == ItemData.ItemType.CONSUMABLE:
		item_context_menu.add_item("Usar", 0)
		if item.bonus_hp > 0:
			item_context_menu.add_item("Atribuir ao Atalho Z", 100)
		elif item.bonus_mana > 0:
			item_context_menu.add_item("Atribuir ao Atalho X", 101)
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
	if id == 10 and active_equipment_slot != "":
		unequip_item(active_equipment_slot)
		active_equipment_slot = ""
		_hide_item_tooltip()
		return

	if selected_slot_index >= 0:
		if selected_slot_index >= inventory_items.size() or inventory_items[selected_slot_index] == null:
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
			100:
				var hud = get_tree().current_scene.find_child("HUD", true, false)
				if hud and hud.has_method("assign_potion_to_slot"):
					hud.assign_potion_to_slot("hp", item)
				_hide_item_tooltip()
				return
			101:
				var hud = get_tree().current_scene.find_child("HUD", true, false)
				if hud and hud.has_method("assign_potion_to_slot"):
					hud.assign_potion_to_slot("mp", item)
				_hide_item_tooltip()
				return

		selected_slot_index = -1

	_hide_item_tooltip()

func equip_item_from_inventory(item: ItemData, slot_idx: int) -> void:
	if not item or slot_idx < 0 or slot_idx >= INVENTORY_CAPACITY:
		return

	var slot_data = inventory_items[slot_idx]
	if slot_data != null and slot_data.get("amount", 1) > 1:
		return

	var target_slot_key = ""
	match item.item_type:
		ItemData.ItemType.WEAPON: target_slot_key = "weapon"
		ItemData.ItemType.ARMOR: target_slot_key = "armor"
		ItemData.ItemType.HELM: target_slot_key = "helm"
		ItemData.ItemType.BOOTS: target_slot_key = "boots"

	if target_slot_key == "":
		return

	# Se já houver um item equipado neste slot, devolvemos ele para o inventário
	var old_item: ItemData = equipped_items.get(target_slot_key, null)
	if old_item:
		equipped_items[target_slot_key] = null
		inventory_items[slot_idx] = {"item": old_item, "amount": 1}
	else:
		inventory_items[slot_idx] = null

	# Equipa o novo item
	equipped_items[target_slot_key] = item

	if target_slot_key == "weapon":
		current_weapon_mesh_path = item.mesh_scene.resource_path if item.mesh_scene else ""
		update_hand_visual(item.mesh_scene)

	update_equipment_slot_visual(target_slot_key, item)
	recalculate_derived_stats() # Recalcula considerando todos os itens em 'equipped_items'
	update_inventory_display()
	update_hud_display()

func unequip_item(slot_key: String) -> bool:
	if not equipped_items.has(slot_key) or equipped_items[slot_key] == null:
		return false

	var item: ItemData = equipped_items[slot_key]
	var success = add_item_to_inventory(item, 1)
	if not success:
		return false

	attack_damage -= item.bonus_attack
	defense -= item.bonus_defense
	bonus_hp -= item.bonus_hp
	bonus_mana -= item.bonus_mana

	equipped_items[slot_key] = null

	if slot_key == "weapon":
		current_weapon_mesh_path = ""
		update_hand_visual(null)

	recalculate_derived_stats()
	update_equipment_slot_visual(slot_key, null)
	update_inventory_display()
	update_hud_display()
	return true

func _on_equipment_slot_clicked(slot_key: String) -> void:
	if not equipped_items.has(slot_key) or equipped_items[slot_key] == null:
		return

	active_equipment_slot = slot_key
	selected_slot_index = -1

	if not item_context_menu:
		item_context_menu = PopupMenu.new()
		if not item_context_menu.id_pressed.is_connected(_on_context_menu_item_selected):
			item_context_menu.id_pressed.connect(_on_context_menu_item_selected)
		hud_layer.add_child(item_context_menu)

	item_context_menu.clear()
	item_context_menu.add_item("Desequipar", 10)

	item_context_menu.position = Vector2i(get_viewport().get_mouse_position())
	item_context_menu.reset_size()
	item_context_menu.popup()

func use_consumable(item: ItemData, slot_idx: int) -> void:
	if not item:
		return

	if item.bonus_hp > 0:
		heal(item.bonus_hp, item)
	if item.bonus_mana > 0:
		restore_mana(item.bonus_mana, item)

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

	# --- ADICIONA A RARIDADE COLORIDA NA DESCRIÇÃO ---
	var rarity_text = "Comum"
	var rarity_color = Color(0.8, 0.8, 0.8)
	match item.rarity:
		ItemData.Rarity.UNCOMMON:
			rarity_text = "Incomum"
			rarity_color = Color(0.2, 0.8, 0.2)
		ItemData.Rarity.RARE:
			rarity_text = "Raro"
			rarity_color = Color(0.2, 0.5, 1.0)
		ItemData.Rarity.EPIC:
			rarity_text = "Épico"
			rarity_color = Color(0.6, 0.2, 0.8)
		ItemData.Rarity.LEGENDARY:
			rarity_text = "Lendário"
			rarity_color = Color(1.0, 0.6, 0.1)

	var rarity_lbl = Label.new()
	rarity_lbl.text = "Qualidade: %s" % rarity_text
	rarity_lbl.modulate = rarity_color
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(rarity_lbl)
	# -----------------------------------------------

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
	var slot_pos = slot_node.global_position
	var screen_size = get_viewport().get_visible_rect().size
	if slot_pos.x > screen_size.x - 350:
		item_tooltip_panel.position = slot_pos + Vector2(-280, 0)
	else:
		item_tooltip_panel.position = slot_node.global_position + Vector2(65, 0)

func _hide_item_tooltip() -> void:
	if item_tooltip_panel:
		item_tooltip_panel.visible = false

func update_inventory_display() -> void:
	populate_inventory_ui()

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
	var is_Visible = not ui_attr_panel.visible
	ui_attr_panel.visible = is_Visible
	ui_status_panel.visible = is_Visible
	
	if is_Visible or (ui_inventory_panel and ui_inventory_panel.visible):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_inventory_window() -> void:
	if not ui_inventory_panel or not ui_equipment_panel:
		return
	var is_Visible = not ui_inventory_panel.visible
	ui_inventory_panel.visible = is_Visible
	ui_equipment_panel.visible = is_Visible
	
	if is_Visible or (ui_attr_panel and ui_attr_panel.visible):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func update_hud_display() -> void:
	if not ui_level_label:
		return

	ui_level_label.text = "Nível %d (EXP: %d / %d)" % [player_level, current_xp, required_xp]
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

func update_hand_visual(mesh_scene: PackedScene, custom_scale: Vector3 = Vector3(0.01, 0.01, 0.01), keep_scene_transform: bool = false) -> void:
	if not right_hand_bone:
		return

	for child in right_hand_bone.get_children():
		child.queue_free()

	if mesh_scene:
		var item_instance = mesh_scene.instantiate()
		right_hand_bone.add_child(item_instance)
		
		item_instance.scale = custom_scale
		if not keep_scene_transform:
			item_instance.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			item_instance.position = Vector3.ZERO

func discard_item(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= INVENTORY_CAPACITY or inventory_items[slot_idx] == null:
		return

	var slot_data = inventory_items[slot_idx]
	var item_to_drop: ItemData = slot_data["item"]
	
	if not item_to_drop is ItemData or ("is_quest_item" in item_to_drop and item_to_drop.is_quest_item):
		return

	slot_data["amount"] -= 1
	if slot_data["amount"] <= 0:
		inventory_items[slot_idx] = null

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
	
	var is_Visible = not ui_quest_panel.visible
	ui_quest_panel.visible = is_Visible
	
	if is_Visible:
		populate_quest_log_ui()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if (not ui_attr_panel or not ui_attr_panel.visible) and (not ui_inventory_panel or not ui_inventory_panel.visible):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _read_json_encrypted(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var file = FileAccess.open_encrypted_with_pass(file_path, FileAccess.READ, SAVE_ENCRYPTION_KEY)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			return parsed
	# Fallback para saves antigos não criptografados
	var plain_file = FileAccess.open(file_path, FileAccess.READ)
	if plain_file:
		var parsed_plain = JSON.parse_string(plain_file.get_as_text())
		plain_file.close()
		return parsed_plain
	return null

func _write_json_encrypted(file_path: String, data: Dictionary) -> void:
	var write_file = FileAccess.open_encrypted_with_pass(file_path, FileAccess.WRITE, SAVE_ENCRYPTION_KEY)
	if write_file:
		write_file.store_string(JSON.stringify(data))
		write_file.close()

func register_monster_kill(monster_id: String) -> void:
	achievements_stats["total_monsters_killed"] = int(achievements_stats.get("total_monsters_killed", 0)) + 1
	var by_id: Dictionary = achievements_stats.get("monsters_killed_by_id", {})
	by_id[monster_id] = int(by_id.get(monster_id, 0)) + 1
	achievements_stats["monsters_killed_by_id"] = by_id

func register_item_collected(item_id: String, quantity: int = 1) -> void:
	if item_id == "" or quantity <= 0:
		return
	achievements_stats["total_items_collected"] = int(achievements_stats.get("total_items_collected", 0)) + quantity
	var by_id: Dictionary = achievements_stats.get("items_collected_by_id", {})
	by_id[item_id] = int(by_id.get(item_id, 0)) + quantity
	achievements_stats["items_collected_by_id"] = by_id

func register_quest_completed(quest_id: String, is_main_story: bool = false) -> void:
	if is_main_story:
		achievements_stats["main_story_progress"] = int(achievements_stats.get("main_story_progress", 0)) + 1
	else:
		achievements_stats["side_quests_completed"] = int(achievements_stats.get("side_quests_completed", 0)) + 1

func load_player_save(username: String) -> void:
	player_name = username
	var file_path = "user://accounts/" + username + ".json"

	var json_data = _read_json_encrypted(file_path)
	if not json_data is Dictionary:
		return

	var loaded_stats = json_data.get("achievements_stats", {})
	if loaded_stats is Dictionary:
		for key in achievements_stats.keys():
			if loaded_stats.has(key):
				achievements_stats[key] = loaded_stats[key]

	if bool(json_data.get("is_mounted", false)):
		call_deferred("_restore_mounted_state")

	player_level = int(json_data.get("level", 1))
	current_xp = int(json_data.get("current_xp", 0))
	required_xp = int(json_data.get("required_xp", 100))
	unspent_points = int(json_data.get("unspent_points", 0))

	var pos_data = json_data.get("last_position", null)
	if pos_data is Dictionary:
		global_position = Vector3(pos_data.get("x", 0), pos_data.get("y", 1), pos_data.get("z", 0))
		velocity = Vector3.ZERO
	
	var saved_map = json_data.get("current_map", "ilha_inicial")
	var lm = get_node_or_null("/root/LevelManager")
	if not lm and get_tree().current_scene:
		lm = get_tree().current_scene.find_child("LevelManager", true, false)
	
	if lm and (not is_instance_valid(lm.current_map_instance) or lm.current_map_key != saved_map):
		lm.load_map_into_container(saved_map, "SpawnPoint", lm.is_new_game)

	var stats = json_data.get("stats", {}) as Dictionary
	stat_str = int(stats.get("str", 5))
	stat_agi = int(stats.get("agi", 5))
	stat_vit = int(stats.get("vit", 5))
	stat_int = int(stats.get("int", 5))
	
	if hud_ref and json_data.has("equipped_skills"):
		if skill_manager:
			hud_ref.load_saved_data(json_data.get("equipped_skills", {}), json_data.get("equipped_potions", {}), skill_manager.available_skills)
		
	if json_data.has("equipment_data") and equipment_manager:
		equipment_manager.load_saved_data(json_data["equipment_data"])

	var inv_data = json_data.get("inventory", []) as Array
	inventory_items.clear()
	inventory_items.resize(INVENTORY_CAPACITY)
	for i in range(min(inv_data.size(), INVENTORY_CAPACITY)):
		var entry = inv_data[i]
		if entry is Dictionary and entry.has("path"):
			var res_path = str(entry.get("path", ""))
			var amt = int(entry.get("amount", 1))
			if res_path != "" and ResourceLoader.exists(res_path):
				var base_item = load(res_path) as ItemData
				var loaded_item = base_item.duplicate() # Duplica para não corromper o .tres original
				
				# Restaura os dados salvos do item dinâmico
				if entry.has("rarity"):
					loaded_item.rarity = int(entry.get("rarity", 0))
				if entry.has("bonus_attack"):
					loaded_item.bonus_attack = int(entry.get("bonus_attack", loaded_item.bonus_attack))
				if entry.has("bonus_defense"):
					loaded_item.bonus_defense = int(entry.get("bonus_defense", loaded_item.bonus_defense))
				if entry.has("bonus_hp"):
					loaded_item.bonus_hp = int(entry.get("bonus_hp", loaded_item.bonus_hp))
				if entry.has("bonus_mana"):
					loaded_item.bonus_mana = int(entry.get("bonus_mana", loaded_item.bonus_mana))
				if entry.has("level") and "level" in loaded_item:
					loaded_item.level = int(entry.get("level", 1))
				
				inventory_items[i] = {
					"item": loaded_item,
					"amount": amt
				}
	
	var wh_data = json_data.get("warehouse", []) as Array
	warehouse_items.clear()
	warehouse_items.resize(WAREHOUSE_CAPACITY)
	for i in range(min(wh_data.size(), WAREHOUSE_CAPACITY)):
		var entry = wh_data[i]
		if entry is Dictionary and entry.has("path"):
			var res_path = str(entry.get("path", ""))
			var amt = int(entry.get("amount", 1))
			if res_path != "" and ResourceLoader.exists(res_path):
				var base_item = load(res_path) as ItemData
				var loaded_item = base_item.duplicate()
				
				if entry.has("rarity"): loaded_item.rarity = int(entry.get("rarity", 0))
				if entry.has("bonus_attack"): loaded_item.bonus_attack = int(entry.get("bonus_attack", 0))
				if entry.has("bonus_defense"): loaded_item.bonus_defense = int(entry.get("bonus_defense", 0))
				if entry.has("bonus_hp"): loaded_item.bonus_hp = int(entry.get("bonus_hp", 0))
				if entry.has("bonus_mana"): loaded_item.bonus_mana = int(entry.get("bonus_mana", 0))
				
				warehouse_items[i] = {
					"item": loaded_item,
					"amount": amt
				}
	
	if json_data.has("skills_data") and skill_manager:
		skill_manager.load_saved_data(json_data["skills_data"])

	for k in equipped_items.keys():
		equipped_items[k] = null

	var eq_data = json_data.get("equipment", {}) as Dictionary
	for slot_key in ["helm", "armor", "boots", "weapon"]:
		var eq_entry = eq_data.get(slot_key, null)
		
		# Compatibilidade retroativa caso o save antigo fosse apenas uma String (path)
		var eq_path = ""
		var saved_rarity = 0
		var saved_atk = 0
		var saved_def = 0
		var saved_hp = 0
		var saved_mana = 0
		var saved_lvl = 1
		
		if eq_entry is Dictionary:
			eq_path = str(eq_entry.get("path", ""))
			saved_rarity = int(eq_entry.get("rarity", 0))
			saved_atk = int(eq_entry.get("bonus_attack", 0))
			saved_def = int(eq_entry.get("bonus_defense", 0))
			saved_hp = int(eq_entry.get("bonus_hp", 0))
			saved_mana = int(eq_entry.get("bonus_mana", 0))
			saved_lvl = int(eq_entry.get("level", 1))
		elif eq_entry is String:
			eq_path = eq_entry

		if eq_path != "" and ResourceLoader.exists(eq_path):
			var base_item = load(eq_path) as ItemData
			var loaded_item = base_item.duplicate() # Duplica para preservar dados customizados
			
			if eq_entry is Dictionary:
				loaded_item.rarity = saved_rarity
				if saved_atk > 0: loaded_item.bonus_attack = saved_atk
				if saved_def > 0: loaded_item.bonus_defense = saved_def
				if saved_hp > 0: loaded_item.bonus_hp = saved_hp
				if saved_mana > 0: loaded_item.bonus_mana = saved_mana
				if "level" in loaded_item: loaded_item.level = saved_lvl
			
			equipped_items[slot_key] = loaded_item
			attack_damage += loaded_item.bonus_attack
			defense += loaded_item.bonus_defense
			bonus_hp += loaded_item.bonus_hp
			bonus_mana += loaded_item.bonus_mana

	current_weapon_mesh_path = str(json_data.get("weapon_mesh_path", ""))
	if current_weapon_mesh_path == "" and equipped_items.get("weapon") != null:
		var w_item: ItemData = equipped_items["weapon"]
		if w_item and w_item.mesh_scene:
			current_weapon_mesh_path = w_item.mesh_scene.resource_path

	var raw_active = json_data.get("client_active_quests", [])
	if raw_active is Array:
		client_active_quests = raw_active
	elif raw_active is Dictionary:
		client_active_quests = raw_active.values()
	else:
		client_active_quests = []

	var raw_completed = json_data.get("completed_quests", [])
	if raw_completed is Array:
		completed_quests = raw_completed
	elif raw_completed is Dictionary:
		completed_quests = raw_completed.keys()
	else:
		completed_quests = []

	recalculate_derived_stats()
	hp = max_hp
	mana = max_mana
	
	if has_node("/root/QuestManager"):
		QuestManager.sync_main_story_progress(self)
	
	update_hud_display()
	update_inventory_display()
	update_quest_tracker_ui()
	populate_quest_log_ui()

	for slot_key in ["helm", "armor", "boots", "weapon"]:
		var item: ItemData = equipped_items.get(slot_key, null)
		if item:
			update_equipment_slot_visual(slot_key, item)
			if slot_key == "weapon" and item.mesh_scene:
				update_hand_visual(item.mesh_scene)
		else:
			update_equipment_slot_visual(slot_key, null)

func save_player_account() -> void:
	if player_name.is_empty():
		return

	var file_path = "user://accounts/" + player_name + ".json"
	var existing_pass_hash = ""

	if FileAccess.file_exists(file_path):
		var old_data = _read_json_encrypted(file_path)
		if old_data is Dictionary:
			existing_pass_hash = old_data.get("password_hash", "")

	var serialized_inventory: Array = []
	for slot in inventory_items:
		if slot != null and slot is Dictionary and slot.get("item") is ItemData:
			var item_data: ItemData = slot["item"]
			var path = item_data.resource_path
			if path == "" and "id" in item_data and item_data.id != "":
				path = "res://Resources/Items/%s.tres" % item_data.id
				
			serialized_inventory.append({
				"path": path,
				"amount": slot.get("amount", 1),
				# Salva as propriedades dinâmicas do item encantado/craftado:
				"rarity": int(item_data.rarity),
				"bonus_attack": item_data.bonus_attack,
				"bonus_defense": item_data.bonus_defense,
				"bonus_hp": item_data.bonus_hp,
				"bonus_mana": item_data.bonus_mana,
				"level": item_data.level if "level" in item_data else 1
			})
		else:
			serialized_inventory.append(null)

	var serialized_equipment: Dictionary = {}
	for slot_key in equipped_items.keys():
		var eq_item = equipped_items[slot_key]
		if eq_item is ItemData:
			var path = eq_item.resource_path
			if path == "" and "id" in eq_item and eq_item.id != "":
				path = "res://Resources/Items/%s.tres" % eq_item.id
				
			serialized_equipment[slot_key] = {
				"path": path,
				"rarity": int(eq_item.rarity),
				"bonus_attack": eq_item.bonus_attack,
				"bonus_defense": eq_item.bonus_defense,
				"bonus_hp": eq_item.bonus_hp,
				"bonus_mana": eq_item.bonus_mana,
				"level": eq_item.level if "level" in eq_item else 1
			}
		else:
			serialized_equipment[slot_key] = null
	
	var serialized_warehouse: Array = []
	for slot in warehouse_items:
		if slot != null and slot is Dictionary and slot.get("item") is ItemData:
			var item_data: ItemData = slot["item"]
			var path = item_data.resource_path
			if path == "" and "id" in item_data and item_data.id != "":
				path = "res://Resources/Items/%s.tres" % item_data.id
				
			serialized_warehouse.append({
				"path": path,
				"amount": slot.get("amount", 1),
				"rarity": int(item_data.rarity),
				"bonus_attack": item_data.bonus_attack,
				"bonus_defense": item_data.bonus_defense,
				"bonus_hp": item_data.bonus_hp,
				"bonus_mana": item_data.bonus_mana,
				"level": item_data.level if "level" in item_data else 1
			})
		else:
			serialized_warehouse.append(null)

	var lm = get_node_or_null("/root/LevelManager")
	if not lm and get_tree().current_scene:
		lm = get_tree().current_scene.find_child("LevelManager", true, false)

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
		"client_active_quests": client_active_quests,
		"completed_quests": completed_quests,
		"equipped_skills": hud_ref.equipped_skill_slots if hud_ref else {},
		"equipped_potions": hud_ref.equipped_potion_items if hud_ref else {},
		"skills_data": skill_manager.get_save_data() if skill_manager else {},
		"equipment_data": equipment_manager.get_save_data() if equipment_manager else {},
		"current_map": lm.current_map_key if lm else "ilha_inicial",
		"warehouse": serialized_warehouse,
		"achievements_stats": achievements_stats,
		"is_mounted": is_mounted
	}

	_write_json_encrypted(file_path, account_data)

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
		var target_ids: Array = q.get("target_ids", [])
		var req: int = max(int(q.get("required", 1)), target_ids.size())
		var is_done: bool = bool(q.get("completed", false))

		var quest_entry_box = VBoxContainer.new()
		quest_entry_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quest_entry_box.add_theme_constant_override("separation", 2)

		var lbl_title = Label.new()
		lbl_title.text = "• %s" % q_title
		lbl_title.add_theme_font_size_override("font_size", 11)
		lbl_title.modulate = Color(1.0, 0.85, 0.3) if q.get("is_main_story", false) else Color(0.95, 0.95, 0.95)
		quest_entry_box.add_child(lbl_title)

		if is_done:
			var lbl_done = Label.new()
			lbl_done.add_theme_font_size_override("font_size", 10)
			lbl_done.text = "    Pronta para entregar!"
			lbl_done.modulate = Color(0.3, 1.0, 0.4)
			quest_entry_box.add_child(lbl_done)
		elif target_ids.size() > 1:
			var talked_list: Array = q.get("talked_npcs", [])
			for t_id in target_ids:
				var lbl_step = Label.new()
				lbl_step.add_theme_font_size_override("font_size", 10)
				var step_done: bool = t_id in talked_list
				var step_val: int = 1 if step_done else 0
				lbl_step.text = "    %s: %d / 1" % [str(t_id).capitalize(), step_val]
				lbl_step.modulate = Color(0.3, 1.0, 0.4) if step_done else Color(0.8, 0.8, 0.8)
				quest_entry_box.add_child(lbl_step)
		else:
			var lbl_progress = Label.new()
			lbl_progress.add_theme_font_size_override("font_size", 10)
			var target_name = target_ids[0] if not target_ids.is_empty() else "Objetivo"
			if target_name.begins_with("res://"):
				target_name = target_name.get_file().get_basename()
			lbl_progress.text = "    %s: %d / %d" % [target_name, cur, req]
			lbl_progress.modulate = Color(0.8, 0.8, 0.8)
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
		box.add_theme_constant_override("separation", 4)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var title_lbl = Label.new()
		var prefix = "⭐ " if q.get("is_main_story", false) else "📜 "
		title_lbl.text = "%s%s" % [prefix, q.get("title", "Missão")]
		title_lbl.modulate = Color(1.0, 0.85, 0.3) if q.get("is_main_story", false) else Color(0.9, 0.9, 0.9)
		title_lbl.add_theme_font_size_override("font_size", 13)
		box.add_child(title_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = q.get("description", "Complete o objetivo indicado.")
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(280, 0)
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		box.add_child(desc_lbl)

		var target_ids: Array = q.get("target_ids", [])
		var cur: int = int(q.get("current", 0))
		var req: int = max(int(q.get("required", 1)), target_ids.size())
		var is_done: bool = bool(q.get("completed", false))

		if is_done:
			var prog_lbl = Label.new()
			prog_lbl.text = "    Status: Concluído! Pronto para entregar."
			prog_lbl.modulate = Color(0.3, 1.0, 0.4)
			prog_lbl.add_theme_font_size_override("font_size", 11)
			box.add_child(prog_lbl)
		elif target_ids.size() > 1:
			var talked_list: Array = q.get("talked_npcs", [])
			for t_id in target_ids:
				var step_lbl = Label.new()
				var step_done: bool = t_id in talked_list
				var step_val: int = 1 if step_done else 0
				step_lbl.text = "    • %s: %d / 1" % [str(t_id).capitalize(), step_val]
				step_lbl.modulate = Color(0.3, 1.0, 0.4) if step_done else Color(1.0, 0.6, 0.2)
				step_lbl.add_theme_font_size_override("font_size", 11)
				box.add_child(step_lbl)
		else:
			var prog_lbl = Label.new()
			var target_name = target_ids[0] if not target_ids.is_empty() else "Alvo"
			if target_name.begins_with("res://"):
				target_name = target_name.get_file().get_basename()
			prog_lbl.text = "    Progresso (%s): %d / %d" % [target_name, cur, req]
			prog_lbl.modulate = Color(1.0, 0.6, 0.2)
			prog_lbl.add_theme_font_size_override("font_size", 11)
			box.add_child(prog_lbl)

		var sep = HSeparator.new()
		box.add_child(sep)

		ui_quest_list_container.add_child(box)

func _exit_tree() -> void:
	save_player_account()

func check_torch_status(delta: float) -> void:
	if not torch_light: return
	
	var main_node = get_tree().root.get_node_or_null("Main")
	if not main_node: return
	
	var day_night_node = main_node.find_child("Cycle", true, false)
	if day_night_node:
		var time_val = day_night_node.get("time_progress")
		if time_val != null:
			var is_night = (time_val >= 0.52 and time_val <= 0.98)
			if is_night:
				torch_light.visible = true
				torch_light.light_energy = move_toward(torch_light.light_energy, 1.2, delta * 2.0)
			else:
				torch_light.light_energy = move_toward(torch_light.light_energy, 0.0, delta * 2.0)
				if torch_light.light_energy <= 0.05:
					torch_light.visible = false

func heal(amount: int, Potion: ItemData) -> void:
	if is_dead: return 
	hp = min(hp + amount, max_hp) 
	if health_bar: health_bar.value = hp 
	play_drink_animation(Potion)
	show_heal_effect(amount, "HP")
	update_hud_display() 

func restore_mana(amount: int, Potion: ItemData) -> void:
	if is_dead: return
	mana = min(mana + amount, max_mana)
	if mana_bar: mana_bar.value = mana
	play_drink_animation(Potion)
	show_heal_effect(amount, "MP")
	update_hud_display()

func play_drink_animation(potion_item: ItemData) -> void:
	if potion_item.mesh_scene:
		update_hand_visual(potion_item.mesh_scene, Vector3(0.1 , 0.1 , 0.1))

	if attacks_playback:
		attacks_playback.start("Armature|Beber")

	if anim_tree:
		anim_tree.set("parameters/attack_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	get_tree().create_timer(1.2).timeout.connect(func():
		var active_weapon: ItemData = equipped_items.get("weapon", null)
		if active_weapon and active_weapon.mesh_scene:
			update_hand_visual(active_weapon.mesh_scene)
		else:
			update_hand_visual(null)
	)

func show_heal_effect(amount: int, type : String = "HP") -> void:
	var heal_lbl = floating_damage_scene.instantiate()
	get_parent().add_child(heal_lbl)
	heal_lbl.global_position = global_position + Vector3(0, 2.0, 0)
	if heal_lbl.has_method("setup"):
		if type == "HP":
			heal_lbl.setup("+%d" % amount, Color(0.2, 1.0, 0.3))
		elif type == "MP":
			heal_lbl.setup("+%d" % amount, Color(0.2, 0.243, 0.948, 1.0))

func get_level() -> int:
	return player_level

func magic_heal(amount: int) -> void:
	if is_dead: return 
	hp = min(hp + amount, max_hp) 
	if health_bar: health_bar.value = hp
	show_heal_effect(amount, "HP")
	update_hud_display() 

func play_spell_animation(anim_name: String) -> void:
	if attacks_playback:
		attacks_playback.travel("Armature|" + anim_name)

	if anim_tree:
		anim_tree.set("parameters/attack_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func send_message_HUD(message : String, color : Color):
	hud_ref.show_floating_message(message, color)

func toggle_mastery_window() -> void:
	if not ui_mastery_panel:
		return
	
	var is_visible = not ui_mastery_panel.visible
	ui_mastery_panel.visible = is_visible
	
	if is_visible:
		populate_mastery_ui()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if not (ui_inventory_panel and ui_inventory_panel.visible) and not (ui_attr_panel and ui_attr_panel.visible):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func populate_mastery_ui() -> void:
	if not ui_mastery_list_container:
		return

	for child in ui_mastery_list_container.get_children():
		child.queue_free()

	var craft_manager = get_node_or_null("/root/CraftManager")
	if not craft_manager or not "equipment_progress" in craft_manager:
		var lbl_err = Label.new()
		lbl_err.text = "Dados de maestria indisponíveis."
		ui_mastery_list_container.add_child(lbl_err)
		return

	var progress_data = craft_manager.equipment_progress as Dictionary

	for eq_type in progress_data.keys():
		var type_box = VBoxContainer.new()
		type_box.add_theme_constant_override("separation", 4)
		
		var type_title = Label.new()
		type_title.text = "🛠️ Categoria: %s" % eq_type.capitalize()
		type_title.add_theme_font_size_override("font_size", 13)
		type_title.modulate = Color(0.4, 0.9, 1.0)
		type_box.add_child(type_title)

		var levels_dict = progress_data[eq_type] as Dictionary
		for lvl in range(1, 11):
			if levels_dict.has(lvl):
				var info = levels_dict[lvl]
				var crafted = int(info.get("total_crafted", 0))
				var mastery = int(info.get("mastery_exp", 0))
				
				var row_lbl = Label.new()
				var status_text = ""
				
				if crafted >= 10:
					status_text = "Nível %d: [CONCLUÍDO] (Especialista XP: %d)" % [lvl, mastery]
					row_lbl.modulate = Color(0.3, 1.0, 0.4)
				else:
					status_text = "Nível %d: %d / 10 crafts" % [lvl, crafted]
					row_lbl.modulate = Color(0.9, 0.9, 0.9)
					
				row_lbl.text = "   • " + status_text
				row_lbl.add_theme_font_size_override("font_size", 11)
				type_box.add_child(row_lbl)

		var sep = HSeparator.new()
		ui_mastery_list_container.add_child(type_box)
		ui_mastery_list_container.add_child(sep)

func gathering(item_data: ItemData, anim_name: String, tool_type: String = "auto", anim_duration: float = 0.5) -> bool:
	if is_dead or not item_data:
		return false

	if is_gathering_locked or gather_cooldown_timer > 0.0:
		var wait_seconds = int(ceil(gather_cooldown_timer))
		send_message_HUD("Aguarde %ds para coletar novamente!" % wait_seconds, Color(1.0, 0.6, 0.2))
		return false

	is_gathering_locked = true
	gather_cooldown_timer = gather_cooldown_duration

	var tool_mesh: PackedScene = null
	var anim_lower = anim_name.to_lower()
	
	if tool_type == "axe" or (tool_type == "auto" and ("arvore" in anim_lower or "lenha" in anim_lower or "cortar" in anim_lower or "machado" in anim_lower)):
		tool_mesh = axe_tool_mesh
	elif tool_type == "pickaxe" or (tool_type == "auto" and ("minerar" in anim_lower or "pedra" in anim_lower or "picareta" in anim_lower or "minerio" in anim_lower)):
		tool_mesh = pickaxe_tool_mesh

	if tool_mesh:
		update_hand_visual(tool_mesh, Vector3(0.01, 0.01, 0.01), true)

	if attacks_playback and anim_name != "":
		attacks_playback.start(anim_name)
	if anim_tree and anim_name != "":
		anim_tree.set("parameters/attack_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	play_gathering_sound()

	get_tree().create_timer(anim_duration).timeout.connect(func():
		is_gathering_locked = false
		if is_dead:
			return

		var active_weapon: ItemData = equipped_items.get("weapon", null)
		if active_weapon and active_weapon.mesh_scene:
			update_hand_visual(active_weapon.mesh_scene)
		else:
			update_hand_visual(null)

		var added = add_item_to_inventory(item_data, 1)
		if added:
			send_message_HUD("Coletado: %s" % item_data.name, Color(0.4, 1.0, 0.4))
			save_player_account()
		else:
			send_message_HUD("Inventário Cheio!", Color.RED)
	)

	return true

func play_gathering_sound() -> void:
	var gather_audio = get_node_or_null("GatherAudio") as AudioStreamPlayer3D
	if gather_audio and gather_audio.stream:
		gather_audio.pitch_scale = randf_range(0.9, 1.1)
		gather_audio.play()
	elif hit_audio and hit_audio.stream:
		hit_audio.pitch_scale = 0.7
		hit_audio.play()

func apply_status_effect(effect_type: String, total_damage: int, duration: float) -> void:
	active_player_status = effect_type.to_lower()
	player_status_timer = duration
	player_status_tick = 1.0
	
	var effective_duration = min(duration, 3.0)
	player_status_damage = max(1, int(total_damage / effective_duration))
	
	match active_player_status:
		"envenenamento":
			send_message_HUD("Você foi envenenado!", Color.GREEN)
			venom_effect.emitting = true
		"queimadura":
			send_message_HUD("Você está queimando!", Color.RED)
			fire_effect.emitting = true
		"congelamento", "lentidao":
			speed = base_player_speed * 0.6
			send_message_HUD("Velocidade reduzida!", Color.BLUE)
			frost_effect.emitting = true

func remove_player_status() -> void:
	match active_player_status:
		"congelamento", "lentidao":
			speed = base_player_speed
			frost_effect.emitting = false
		"queimadura":
			fire_effect.emitting = false
		"envenenamento":
			venom_effect.emitting = false
	active_player_status = ""

func apply_natural_regeneration() -> void:
	if is_dead:
		return
		
	var hp_gain = int(max_hp * 0.05)
	var mana_gain = int(max_mana * 0.05)
	
	if hp < max_hp:
		hp = min(max_hp, hp + hp_gain)
		if health_bar:
			health_bar.max_value = max_hp
			health_bar.value = hp
		
	if mana < max_mana:
		mana = min(max_mana, mana + mana_gain)
		if mana_bar:
			mana_bar.max_value = max_mana
			mana_bar.value = mana

func trigger_combat_state() -> void:
	out_of_combat_timer = COMBAT_COOLDOWN_DURATION
	regen_tick_timer = 0.0

func sort_and_compact_inventory() -> void:
	var valid_entries: Array = []

	for i in range(INVENTORY_CAPACITY):
		var slot = inventory_items[i]
		if slot != null and slot is Dictionary and slot.get("item") is ItemData:
			var item: ItemData = slot["item"]
			var amt: int = int(slot.get("amount", 1))

			if item.is_stackable:
				for existing in valid_entries:
					if existing["item"].id == item.id and existing["amount"] < item.max_stack:
						var space = item.max_stack - existing["amount"]
						var transfer = min(amt, space)
						existing["amount"] += transfer
						amt -= transfer
						if amt <= 0:
							break
			if amt > 0:
				valid_entries.append({"item": item, "amount": amt})

	valid_entries.sort_custom(func(a, b):
		if a["item"].item_type != b["item"].item_type:
			return a["item"].item_type < b["item"].item_type
		return a["item"].name < b["item"].name
	)

	inventory_items.clear()
	inventory_items.resize(INVENTORY_CAPACITY)
	for i in range(valid_entries.size()):
		inventory_items[i] = valid_entries[i]

	update_inventory_display()
	save_player_account()
	send_message_HUD("Inventário reorganizado!", Color(0.4, 0.9, 1.0))

func open_chest_loot_window(chest: Node3D) -> void:
	if not ui_chest_panel:
		return
	active_chest_ref = chest
	ui_chest_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_chest_ui()

func close_chest_loot_window() -> void:
	if ui_chest_panel:
		ui_chest_panel.visible = false
	active_chest_ref = null
	if not (ui_inventory_panel and ui_inventory_panel.visible) and not (ui_attr_panel and ui_attr_panel.visible):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_chest_ui() -> void:
	if not ui_chest_list_vbox or not is_instance_valid(active_chest_ref):
		return

	for child in ui_chest_list_vbox.get_children():
		child.queue_free()

	var loot_list: Array = active_chest_ref.current_loot
	if loot_list.is_empty():
		close_chest_loot_window()
		# Verificação de segurança para evitar o erro caso o baú não tenha a propriedade
		if active_chest_ref and active_chest_ref.has_node("InteractionPrompt"):
			var prompt = active_chest_ref.get_node("InteractionPrompt")
			if prompt:
				prompt.visible = false
		elif active_chest_ref and "interaction_prompt" in active_chest_ref and active_chest_ref.interaction_prompt:
			active_chest_ref.interaction_prompt.visible = false
		return

	for i in range(loot_list.size()):
		var entry = loot_list[i]
		var item: ItemData = entry["item"]
		var amt: int = entry["amount"]

		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lbl = Label.new()
		lbl.text = "%s (x%d)" % [item.name, amt] if amt > 1 else item.name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn_take = Button.new()
		btn_take.text = "Pegar"
		var idx = i
		btn_take.pressed.connect(func(): _take_chest_item(idx))
		row.add_child(btn_take)

		ui_chest_list_vbox.add_child(row)

func _take_chest_item(idx: int) -> void:
	if not is_instance_valid(active_chest_ref):
		return
	var loot_list: Array = active_chest_ref.current_loot
	if idx < 0 or idx >= loot_list.size():
		return

	var entry = loot_list[idx]
	if add_item_to_inventory(entry["item"], entry["amount"]):
		send_message_HUD("Obtido: %s (x%d)" % [entry["item"].name, entry["amount"]], Color(0.4, 1.0, 0.4))
		loot_list.remove_at(idx)
		save_player_account()
		_refresh_chest_ui()
	else:
		send_message_HUD("Inventário Cheio!", Color.RED)

func _on_chest_take_all_pressed() -> void:
	if not is_instance_valid(active_chest_ref):
		return
	var loot_list: Array = active_chest_ref.current_loot
	for i in range(loot_list.size() - 1, -1, -1):
		var entry = loot_list[i]
		if add_item_to_inventory(entry["item"], entry["amount"]):
			loot_list.remove_at(i)
		else:
			send_message_HUD("Inventário Cheio!", Color.RED)
			break
	save_player_account()
	_refresh_chest_ui()

var ui_achievements_panel: PanelContainer = null
var ui_achievements_label: RichTextLabel = null

func _apply_standard_window_style(panel: PanelContainer) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.11, 0.94)
	style.border_color = Color(0.75, 0.60, 0.28, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func toggle_achievements_window() -> void:
	if not ui_achievements_panel:
		ui_achievements_panel = PanelContainer.new()
		ui_achievements_panel.custom_minimum_size = Vector2(440, 380)
		_apply_standard_window_style(ui_achievements_panel)
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_bottom", 14)
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		var title = Label.new()
		title.text = "Conquistas e Estatísticas (J)"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.modulate = Color(1.0, 0.85, 0.35)
		vbox.add_child(title)
		ui_achievements_label = RichTextLabel.new()
		ui_achievements_label.bbcode_enabled = true
		ui_achievements_label.fit_content = true
		ui_achievements_label.custom_minimum_size = Vector2(400, 300)
		vbox.add_child(ui_achievements_label)
		margin.add_child(vbox)
		ui_achievements_panel.add_child(margin)
		if hud_ref:
			hud_ref.add_child(ui_achievements_panel)
		else:
			get_tree().current_scene.add_child(ui_achievements_panel)
		ui_achievements_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
		ui_achievements_panel.visible = false

	ui_achievements_panel.visible = not ui_achievements_panel.visible
	if ui_achievements_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var txt: String = "[b]Monstros Derrotados (Total):[/b] %d\n" % int(achievements_stats.get("total_monsters_killed", 0))
		var m_by_id: Dictionary = achievements_stats.get("monsters_killed_by_id", {})
		for m_id in m_by_id.keys():
			txt += "  - %s: %d\n" % [m_id, int(m_by_id[m_id])]
		txt += "\n[b]Quests Secundárias Completas:[/b] %d\n" % int(achievements_stats.get("side_quests_completed", 0))
		txt += "[b]Progresso História Principal:[/b] %d\n" % int(achievements_stats.get("main_story_progress", 0))
		txt += "\n[b]Itens Coletados (Total):[/b] %d\n" % int(achievements_stats.get("total_items_collected", 0))
		var i_by_id: Dictionary = achievements_stats.get("items_collected_by_id", {})
		for i_id in i_by_id.keys():
			txt += "  - %s: %d\n" % [i_id, int(i_by_id[i_id])]
		ui_achievements_label.text = txt
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _convert_inventory_coins() -> void:
	_convert_coin_tier("Moeda_Bronze_1", "res://Resources/Items/Moeda_Prata_1.tres")
	_convert_coin_tier("Moeda_Prata_1", "res://Resources/Items/Moeda_Ouro_1.tres")

func _convert_coin_tier(source_id: String, target_path: String) -> void:
	var total: int = 0
	for slot in inventory_items:
		if slot is Dictionary and slot.get("item") is ItemData and slot["item"].id == source_id:
			total += int(slot.get("quantity", 0))
	if total < 100:
		return
	var to_add: int = total / 100
	var remainder: int = total % 100
	var kept_remainder: bool = false
	for i in range(inventory_items.size()):
		var slot = inventory_items[i]
		if slot is Dictionary and slot.get("item") is ItemData and slot["item"].id == source_id:
			if not kept_remainder and remainder > 0:
				slot["quantity"] = remainder
				kept_remainder = true
			else:
				inventory_items[i] = null
	var target_item: ItemData = load(target_path)
	if target_item and to_add > 0:
		add_item_to_inventory(target_item, to_add)

var is_mounted: bool = false
var mounted_horse: Node3D = null

func mount_horse(horse: Node3D) -> void:
	if is_mounted or not is_instance_valid(horse):
		return
	is_mounted = true
	mounted_horse = horse
	if get_parent() and horse.get_parent() != get_parent():
		horse.reparent(get_parent())
	if "is_occupied" in horse:
		horse.is_occupied = true
	if "rider" in horse:
		horse.rider = self
	if anim_tree:
		anim_tree.active = false
	var player_col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if player_col:
		player_col.disabled = true
	# Velocidade de andar do cavalo = 1.5x velocidade de correr do player
	# Velocidade de correr do cavalo = 2.0x velocidade de andar do cavalo
	var player_run_speed: float = base_player_speed * 1.45
	var horse_walk_speed: float = player_run_speed * 1.5
	speed = horse_walk_speed * 2.0 if is_running else horse_walk_speed
	global_position = horse.global_position + Vector3(0.0, 5.0, 0.0)

func dismount_horse() -> void:
	if not is_mounted:
		return
	var player_col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if player_col:
		player_col.disabled = false
	velocity = Vector3.ZERO
	if is_instance_valid(mounted_horse):
		global_position = mounted_horse.global_position + mounted_horse.global_transform.basis.x * 1.8 + Vector3(0.0, 3.0, 0.0)
		if "is_occupied" in mounted_horse:
			mounted_horse.is_occupied = false
		if "rider" in mounted_horse:
			mounted_horse.rider = null
	is_mounted = false
	mounted_horse = null
	speed = base_player_speed
	if anim_tree:
		anim_tree.active = true

func update_equipment_visuals(slot_key: String, mesh_scene: PackedScene) -> void:
	var clear_bone := func(bone: Node) -> void:
		if is_instance_valid(bone):
			for c in bone.get_children():
				c.queue_free()

	match slot_key:
		"helm":
			var bone = get("head_bone")
			clear_bone.call(bone)
			if mesh_scene and is_instance_valid(bone):
				bone.add_child(mesh_scene.instantiate())
		"offhand":
			var bone = get("left_hand_bone")
			clear_bone.call(bone)
			if mesh_scene and is_instance_valid(bone):
				bone.add_child(mesh_scene.instantiate())
		"armor":
			var t_bone = get("torso_bone")
			var c_bone = get("chest_bone")
			clear_bone.call(t_bone)
			clear_bone.call(c_bone)
			if mesh_scene:
				var inst = mesh_scene.instantiate()
				var torso_part = inst.find_child("torso_part", true, false)
				var chest_part = inst.find_child("chest_part", true, false)
				if torso_part and is_instance_valid(t_bone):
					torso_part.get_parent().remove_child(torso_part)
					t_bone.add_child(torso_part)
				if chest_part and is_instance_valid(c_bone):
					chest_part.get_parent().remove_child(chest_part)
					c_bone.add_child(chest_part)
				inst.queue_free()
		"boots":
			var lf_bone = get("left_feet_bone")
			var rf_bone = get("right_feet_bone")
			clear_bone.call(lf_bone)
			clear_bone.call(rf_bone)
			if mesh_scene:
				var inst = mesh_scene.instantiate()
				var left_feet = inst.find_child("left_feet", true, false)
				var right_feet = inst.find_child("right_feet", true, false)
				if left_feet and is_instance_valid(lf_bone):
					left_feet.get_parent().remove_child(left_feet)
					lf_bone.add_child(left_feet)
				if right_feet and is_instance_valid(rf_bone):
					right_feet.get_parent().remove_child(right_feet)
					rf_bone.add_child(right_feet)
				inst.queue_free()

func _restore_mounted_state() -> void:
	await get_tree().process_frame
	var horses = get_tree().get_nodes_in_group("PlayerHorse")
	if horses.size() > 0 and is_instance_valid(horses[0]):
		mount_horse(horses[0])
