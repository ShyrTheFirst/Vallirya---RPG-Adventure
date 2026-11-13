class_name MonsterBase
extends CharacterBody3D

@export_category("Configurações da Criatura")
@export var monster_name: String = "Criatura"
@export var speed: float = 3.0
@export var leash_radius: float = 10.0
@export var base_attack_range: float = 1.5
@export var mesh_base_y: float = -1.28
@export var health_bar_height: float = 1.8

@export_category("Sistema de Loot / Drops")
@export var drop_table: Array[MonsterDrop] = []

# Estados da Inteligência Artificial
enum State { IDLE, PATROL, CHASE, ATTACK, RETURN }
var current_state: State = State.IDLE

var level: int = 1
var rarity: String = "Normal"
var max_hp: int = 50
var hp: int = 50
var attack_damage: int = 10

var is_dead: bool = false
var spawn_origin: Vector3 = Vector3.ZERO
var origin_area: Area3D = null
var current_target_player: CharacterBody3D = null

# Timers e Controle de Estados
var state_timer: float = 0.0
var attack_cooldown: float = 0.0
var combat_reset_timer: float = 0.0
const COMBAT_TIMEOUT: float = 10.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
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

	# Configurações iniciais do agente de navegação
	if nav_agent:
		nav_agent.path_desired_distance = 0.5
		nav_agent.target_desired_distance = base_attack_range

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

func _physics_process(delta: float) -> void:
	if is_dead: return

	if not is_on_floor(): 
		velocity.y -= 9.8 * delta
	else: 
		velocity.y = 0.0

	attack_cooldown -= delta
	state_timer -= delta

	if combat_reset_timer > 0.0:
		combat_reset_timer -= delta
		if combat_reset_timer <= 0.0:
			reset_combat_state()

	# Executa a Máquina de Estados da IA
	update_ai_state(delta)
	update_animations()
	move_and_slide()

# --- MÁQUINA DE ESTADOS DA IA ---
func update_ai_state(delta: float) -> void:
	var players = get_tree().get_nodes_in_group("Player")
	var nearest_player: CharacterBody3D = null
	var min_dist: float = 999.0

	# Procura o player mais próximo
	for p in players:
		if is_instance_valid(p) and not p.is_dead:
			var d = global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				nearest_player = p

	# Transições de Estado Globais
	if is_instance_valid(current_target_player) and current_target_player.is_dead:
		current_target_player = null

	# Se tomou dano ou o player está dentro do raio de aggro (ex: 8 metros)
	if not is_instance_valid(current_target_player) and nearest_player and min_dist <= 8.0:
		if global_position.distance_to(spawn_origin) < (leash_radius + 4.0):
			current_target_player = nearest_player
			current_state = State.CHASE

	# Se o alvo fugiu para muito longe do spawn original, ativa o estado de Retorno
	if is_instance_valid(current_target_player):
		if global_position.distance_to(spawn_origin) > (leash_radius + 6.0) or global_position.distance_to(current_target_player.global_position) > 14.0:
			reset_combat_state()
			current_state = State.RETURN

	# Comportamento específico por Estado
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, speed * delta)
			velocity.z = move_toward(velocity.z, 0, speed * delta)
			
			if state_timer <= 0.0:
				state_timer = randf_range(3.0, 6.0)
				# Decide se vai patrulhar ou continuar ocioso
				if randf() > 0.4:
					current_state = State.PATROL
					_pick_new_patrol_destination()

			if is_instance_valid(current_target_player):
				current_state = State.CHASE

		State.PATROL:
			# Se o agente terminou a rota de patrulha ou chegou perto do destino, volta para o IDLE
			var dist_to_patrol = global_position.distance_to(nav_agent.target_position)
			if nav_agent.is_navigation_finished() or dist_to_patrol < 1.0:
				current_state = State.IDLE
				state_timer = randf_range(2.0, 4.0)
			else:
				var next_pos = nav_agent.get_next_path_position()
				var dir = global_position.direction_to(next_pos)
				
				# Rede de segurança para patrulha caso o nav_agent dê stall
				if global_position.distance_to(next_pos) < 0.1:
					dir = (nav_agent.target_position - global_position).normalized()
					dir.y = 0.0

				velocity.x = dir.x * (speed * 0.5)
				velocity.z = dir.z * (speed * 0.5)
				
				if dir.length() > 0.1:
					rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 6.0)

			# Se o player chegar perto enquanto ele patrulha, ativa o CHASE na hora
			if is_instance_valid(current_target_player):
				current_state = State.CHASE

		State.CHASE:
			if not is_instance_valid(current_target_player):
				current_state = State.RETURN
				return

			var dist_to_target = global_position.distance_to(current_target_player.global_position)
			
			if dist_to_target <= base_attack_range:
				current_state = State.ATTACK
			else:
				# Tenta usar o nav_agent se ele estiver mapeado, senão vai direto no player
				var target_pos = current_target_player.global_position
				var move_dir = Vector3.ZERO
				
				if nav_agent and nav_agent.is_target_reachable():
					nav_agent.target_position = target_pos
					var next_pos = nav_agent.get_next_path_position()
					move_dir = global_position.direction_to(next_pos)
				else:
					# FALLBACK DIRETO: Se o nav_agent não achou o mapa, o monstro vai direto em linha reta
					move_dir = (target_pos - global_position).normalized()
					move_dir.y = 0.0

				velocity.x = move_dir.x * speed
				velocity.z = move_dir.z * speed
				
				if move_dir.length() > 0.1:
					rotation.y = lerp_angle(rotation.y, atan2(-move_dir.x, -move_dir.z), delta * 10.0)

		State.ATTACK:
			velocity.x = 0; velocity.z = 0
			if is_instance_valid(current_target_player):
				var look_dir = (current_target_player.global_position - global_position).normalized()
				rotation.y = lerp_angle(rotation.y, atan2(-look_dir.x, -look_dir.z), delta * 12.0)

				var dist = global_position.distance_to(current_target_player.global_position)
				if dist > base_attack_range + 0.3:
					current_state = State.CHASE
				elif attack_cooldown <= 0.0:
					execute_attack(current_target_player, base_attack_range)
					attack_cooldown = 1.8
			else:
				current_state = State.RETURN

		State.RETURN:
			nav_agent.target_position = spawn_origin
			var dist_to_spawn = global_position.distance_to(spawn_origin)
			
			# Se chegou perto do ponto de spawn original, volta para o IDLE e recupera a vida
			if dist_to_spawn < 1.5 or nav_agent.is_navigation_finished():
				current_state = State.IDLE
				state_timer = 2.0
				reset_combat_state()
			else:
				var next_pos = nav_agent.get_next_path_position()
				var dir = global_position.direction_to(next_pos)
				
				# Rede de segurança para o retorno
				if global_position.distance_to(next_pos) < 0.1:
					dir = (spawn_origin - global_position).normalized()
					dir.y = 0.0

				velocity.x = dir.x * (speed * 0.7)
				velocity.z = dir.z * (speed * 0.7)
				
				if dir.length() > 0.1:
					rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 8.0)

func _pick_new_patrol_destination() -> void:
	var random_angle = randf() * TAU
	var random_dist = randf_range(2.0, 5.0)
	var offset = Vector3(cos(random_angle) * random_dist, 0, sin(random_angle) * random_dist)
	var target_pos = spawn_origin + offset
	nav_agent.target_position = target_pos

func update_animations() -> void:
	if not anim_tree or not anim_tree.active or is_dead: return
	var is_moving: bool = velocity.length() > 0.1 and current_state != State.ATTACK
	var target_state: String = "state_1" if is_moving else "state_0"
	if current_anim_state != target_state:
		current_anim_state = target_state
		anim_tree.set("parameters/locomotion/transition_request", target_state)

var current_anim_state: String = ""

# Funções virtuais para sobrescrever nas subclasses (Orc, Aranha, etc.)
func execute_attack(target: CharacterBody3D, range_dist: float) -> void:
	pass

func apply_rarity_effects() -> void:
	pass

func perform_cleave_attack(range_dist: float) -> void:
	var forward_dir = -global_transform.basis.z.normalized()
	for p in get_tree().get_nodes_in_group("Player"):
		if is_instance_valid(p) and not p.is_dead:
			var diff = p.global_position - global_position
			diff.y = 0.0
			if diff.length() <= range_dist + 0.4:
				if forward_dir.dot(diff.normalized()) >= 0.2:
					p.take_damage(attack_damage)

func reset_combat_state() -> void:
	if hp < max_hp and not is_dead:
		hp = max_hp
		current_target_player = null
		show_damage_effect(0, hp)

func take_damage(amount: int, attacker: CharacterBody3D = null) -> void:
	if is_dead: return
	combat_reset_timer = COMBAT_TIMEOUT
	if is_instance_valid(attacker):
		current_target_player = attacker
		current_state = State.CHASE

	hp = max(0, hp - amount)
	show_damage_effect(amount, hp)

	if hp <= 0:
		is_dead = true
		set_physics_process(false)
		velocity = Vector3.ZERO
		
		var rarity_mult = 1.0 if rarity == "Normal" else (1.6 if rarity == "Raro" else 2.8)
		var total_exp = int((15 + level * 8) * rarity_mult)
		
		_roll_loot_drops()
		
		if is_instance_valid(attacker) and attacker.has_method("add_experience"):
			attacker.add_experience(total_exp)
		else:
			var players = get_tree().get_nodes_in_group("Player")
			if players.size() > 0 and players[0].has_method("add_experience"):
				players[0].add_experience(total_exp)

		if has_node("/root/QuestManager") and is_instance_valid(attacker):
			QuestManager.on_monster_killed(attacker, monster_name)

		rpc_despawn()

		get_tree().create_timer(3.5).timeout.connect(func():
			var world = get_tree().current_scene
			var new_pos = spawn_origin
			var new_lvl = level
			var new_rarity = rarity

			if origin_area and origin_area.has_method("get_respawn_data"):
				var r_data = origin_area.get_respawn_data()
				new_pos = r_data["pos"]
				new_lvl = r_data["level"]

			setup_stats(new_lvl, new_rarity)
			current_target_player = null
			combat_reset_timer = 0.0
			current_state = State.IDLE
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
	for drop_entry in drop_table:
		if not drop_entry or not drop_entry.item_data:
			continue
		var item_res: ItemData = drop_entry.item_data
		var chance: float = drop_entry.drop_chance

		if randf() <= chance:
			var drop_pos = global_position + Vector3(randf_range(-0.6, 0.6), 0.4, randf_range(-0.6, 0.6))
			var world_item_scene = load("res://Resources/Scenes/drop.tscn")
			if world_item_scene:
				var item_instance = world_item_scene.instantiate()
				var world = get_tree().current_scene
				if world:
					world.add_child(item_instance)
					item_instance.global_position = drop_pos
					if item_instance.has_method("setup"):
						item_instance.setup(item_res)
