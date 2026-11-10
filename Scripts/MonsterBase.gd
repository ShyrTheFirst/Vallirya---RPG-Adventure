class_name MonsterBase
extends CharacterBody3D

@export_category("Configurações da Criatura")
@export var monster_name: String = "Criatura"
@export var speed: float = 2.8
@export var leash_radius: float = 8.5
@export var base_attack_range: float = 1.4
@export var mesh_base_y: float = -1.28
@export var health_bar_height: float = 1.8

@export_category("Sistema de Loot / Drops")
@export var drop_table: Array[MonsterDrop] = []

var level: int = 1
var rarity: String = "Normal"
var max_hp: int = 50
var hp: int = 50
var attack_damage: int = 10

var is_dead: bool = false
var spawn_origin: Vector3 = Vector3.ZERO

var combat_reset_timer: float = 0.0
const COMBAT_TIMEOUT: float = 10.0

var ai_timer: float = 0.0
var move_dir: Vector3 = Vector3.ZERO
var attack_cooldown: float = 0.0
var origin_area: Area3D = null
var current_target_player: CharacterBody3D = null
var current_anim_state: String = ""

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var anim_tree: AnimationTree = $AnimationTree
var attacks_playback: AnimationNodeStateMachinePlayback

@onready var health_bar_sprite: Sprite3D = $HealthBarSprite
@onready var sub_viewport: SubViewport = $HealthBarSprite/SubViewport
@onready var name_label: Label = $HealthBarSprite/SubViewport/VBoxContainer/NameLabel
@onready var health_bar: ProgressBar = $HealthBarSprite/SubViewport/VBoxContainer/ProgressBar

@onready var hit_audio: AudioStreamPlayer3D = $HitAudio
@onready var attack_audio: AudioStreamPlayer3D = $AttackAudio
var floating_damage_scene = preload("res://Scenes/FloatingDamage.tscn")

func _ready() -> void:
	add_to_group("Monsters")
	if spawn_origin == Vector3.ZERO:
		spawn_origin = global_position

	apply_rarity_effects()

	if health_bar_sprite and sub_viewport:
		health_bar_sprite.texture = sub_viewport.get_texture()
		update_display()

	if anim_tree:
		anim_tree.active = true
		attacks_playback = anim_tree.get("parameters/AttacksCombo/playback")

func update_display() -> void:
	if not health_bar or not name_label: return
	health_bar.max_value = max_hp
	health_bar.value = hp

	match rarity:
		"Épico":
			name_label.text = "[Nv. %d] %s Epico" % [level, monster_name]
			name_label.modulate = Color(1.0, 0.65, 0.0)
		"Raro":
			name_label.text = "[Nv. %d] %s Raro" % [level, monster_name]
			name_label.modulate = Color(0.25, 0.65, 1.0)
		_:
			name_label.text = "[Nv. %d] %s" % [level, monster_name]
			name_label.modulate = Color(1.0, 0.324, 0.259, 1.0)

func setup_stats(new_level: int, new_rarity: String) -> void:
	level = new_level
	rarity = new_rarity
	var hp_mult = 1.0
	var dmg_mult = 1.0

	match rarity:
		"Épico":
			hp_mult = 5.0
			dmg_mult = 3.2
		"Raro":
			hp_mult = 2.8
			dmg_mult = 2.2

	max_hp = int((40 + level * 15) * hp_mult)
	hp = max_hp
	attack_damage = int((8 + level * 3) * dmg_mult)
	
	apply_rarity_effects()
	update_display()

func _process(delta: float) -> void:
	if not is_dead:
		update_animations()

func update_animations() -> void:
	if not anim_tree or not anim_tree.active or is_dead: return

	# Detecta movimento localmente comparando a velocidade ou deslocamento
	var is_moving: bool = velocity.length() > 0.1
	var target_state: String = "state_1" if is_moving else "state_0"

	if current_anim_state != target_state:
		current_anim_state = target_state
		anim_tree.set("parameters/locomotion/transition_request", target_state)

func _physics_process(delta: float) -> void:
	if is_dead: return

	if not is_on_floor(): velocity.y -= 9.8 * delta
	else: velocity.y = 0.0

	ai_timer -= delta
	attack_cooldown -= delta

	if combat_reset_timer > 0.0:
		combat_reset_timer -= delta
		if combat_reset_timer <= 0.0:
			reset_combat_state()

	var players = get_tree().get_nodes_in_group("Players")
	var valid_target: CharacterBody3D = null
	var min_dist: float = 999.0

	if is_instance_valid(current_target_player) and not current_target_player.is_dead:
		var d = global_position.distance_to(current_target_player.global_position)
		if d < 9.0 and global_position.distance_to(spawn_origin) < (leash_radius + 4.0):
			valid_target = current_target_player
			min_dist = d
		else:
			current_target_player = null

	if not valid_target:
		for p in players:
			if not p.is_dead:
				var d = global_position.distance_to(p.global_position)
				if d < min_dist:
					min_dist = d
					valid_target = p
		current_target_player = valid_target

	var attack_range = base_attack_range

	if valid_target and min_dist <= attack_range:
		velocity.x = 0; velocity.z = 0
		var look_dir = (valid_target.global_position - global_position).normalized()
		rotation.y = atan2(-look_dir.x, -look_dir.z)

		if attack_cooldown <= 0.0:
			execute_attack(valid_target, attack_range)
			attack_cooldown = 1.8
	elif valid_target and min_dist < 8.5 and global_position.distance_to(spawn_origin) < (leash_radius + 4.0):
		var dir = (valid_target.global_position - global_position).normalized()
		velocity.x = dir.x * speed; velocity.z = dir.z * speed
		rotation.y = atan2(-dir.x, -dir.z)
	else:
		if global_position.distance_to(spawn_origin) > leash_radius:
			var return_dir = (spawn_origin - global_position).normalized()
			velocity.x = return_dir.x * (speed * 0.6)
			velocity.z = return_dir.z * (speed * 0.6)
			rotation.y = atan2(-return_dir.x, -return_dir.z)
		else:
			if ai_timer <= 0.0:
				ai_timer = randf_range(2.0, 4.0)
				move_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() if randf() > 0.4 else Vector3.ZERO
			velocity.x = move_dir.x * (speed * 0.5)
			velocity.z = move_dir.z * (speed * 0.5)
			if move_dir.length() > 0.1: rotation.y = atan2(-move_dir.x, -move_dir.z)

	move_and_slide()

# Funções virtuais para sobrescrever nas subclasses (Orc, Aranha, etc.)
func execute_attack(target: CharacterBody3D, range_dist: float) -> void:
	pass

func apply_rarity_effects() -> void:
	pass

func perform_cleave_attack(range_dist: float) -> void:
	var forward_dir = -global_transform.basis.z.normalized()
	for p in get_tree().get_nodes_in_group("Players"):
		if not p.is_dead:
			var diff = p.global_position - global_position
			diff.y = 0.0
			if diff.length() <= range_dist + 0.3:
				if forward_dir.dot(diff.normalized()) >= 0.3:
					p.take_damage(attack_damage)

func reset_combat_state() -> void:
	if hp < max_hp and not is_dead:
		hp = max_hp
		current_target_player = null
		show_damage_effect(0, hp)

func take_damage(amount: int, attacker: CharacterBody3D = null) -> void:
	if is_dead: return
	combat_reset_timer = COMBAT_TIMEOUT
	if is_instance_valid(attacker) and randf() < 0.65:
		current_target_player = attacker

	hp = max(0, hp - amount)
	show_damage_effect(amount, hp)

	if hp <= 0:
		is_dead = true
		set_physics_process(false)
		velocity = Vector3.ZERO
		
		var rarity_mult = 1.0 if rarity == "Normal" else (1.6 if rarity == "Raro" else 2.8)
		var total_exp = int((15 + level * 8) * rarity_mult)
		
		_roll_loot_drops()
		
		# Concede XP diretamente ao player local (ou ao atacante)
		if is_instance_valid(attacker) and attacker.has_method("add_experience"):
			attacker.add_experience(total_exp)
		else:
			# Fallback para o player principal da cena
			var players = get_tree().get_nodes_in_group("Players")
			if players.size() > 0 and players[0].has_method("add_experience"):
				players[0].add_experience(total_exp)

		if has_node("/root/QuestManager") and is_instance_valid(attacker):
			QuestManager.on_monster_killed(attacker, monster_name)

		rpc_despawn()

		# Timer de Respawn Local
		get_tree().create_timer(3.5).timeout.connect(func():
			var world = get_tree().current_scene
			var new_pos = spawn_origin
			var new_lvl = level
			var new_rarity = rarity

			if origin_area and origin_area.has_method("get_respawn_data"):
				var r_data = origin_area.get_respawn_data()
				new_pos = r_data["pos"]
				new_lvl = r_data["level"]
			elif origin_area and origin_area.has_method("get_safe_spawn_point"):
				new_pos = world.get_safe_spawn_point(origin_area)

			setup_stats(new_lvl, new_rarity)
			current_target_player = null
			combat_reset_timer = 0.0
			is_dead = false
			global_position = new_pos
			spawn_origin = new_pos
			set_physics_process(true)
			rpc_respawn(new_pos, hp, max_hp, level, rarity)
		)

func show_damage_effect(amount: int, current_hp: int) -> void:
	hp = current_hp
	if health_bar: health_bar.value = hp
	if hit_audio and hit_audio.stream and amount > 0: hit_audio.play()
	if amount > 0:
		var dmg_lbl = floating_damage_scene.instantiate()
		var world = get_tree().current_scene
		if world:
			world.add_child(dmg_lbl)
		else:
			get_parent().add_child(dmg_lbl)
		dmg_lbl.global_position = global_position + Vector3(0, health_bar_height, 0)
		if dmg_lbl.has_method("setup"): dmg_lbl.setup(amount, Color(1.0, 0.2, 0.2))

func rpc_despawn() -> void:
	visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func rpc_respawn(pos: Vector3, new_hp: int, new_max_hp: int, new_lvl: int, new_rarity: String) -> void:
	global_position = pos
	hp = new_hp
	max_hp = new_max_hp
	level = new_lvl
	rarity = new_rarity
	visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	update_display()

func _roll_loot_drops() -> void:
	# Como é singleplayer, podemos instanciar o item dropado direto no mundo ou via método local
	for drop_entry in drop_table:
		if not drop_entry or not drop_entry.item_data:
			continue

		var item_res: ItemData = drop_entry.item_data
		var chance: float = drop_entry.drop_chance

		if randf() <= chance:
			var drop_pos = global_position + Vector3(randf_range(-0.6, 0.6), 0.4, randf_range(-0.6, 0.6))
			var world = get_tree().current_scene
			if world and world.has_method("server_spawn_world_item"):
				world.server_spawn_world_item(item_res.resource_path, drop_pos)
