class_name Cavalo
extends CharacterBody3D

@export var interact_distance: float = 3.0
@export var saddle_offset: Vector3 = Vector3(0.0, 1.1, 0.0)
@export var horse_gravity: float = 24.0

var is_occupied: bool = false
var rider: CharacterBody3D = null
var rider_body_bone: Node3D = null
var player_in_range: CharacterBody3D = null
@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer", true, false)
@onready var interaction_prompt: Node3D = get_node_or_null("InteractionPrompt")

func _ready() -> void:
	visible = false
	if interaction_prompt:
		interaction_prompt.visible = false
	add_to_group("PlayerHorse")
	floor_snap_length = 0.5
	floor_stop_on_slope = true
	floor_block_on_wall = true
	floor_max_angle = deg_to_rad(45.0)
	call_deferred("_init_horse_state")

func _init_horse_state() -> void:
	if is_occupied and is_instance_valid(rider):
		return
	for p in get_tree().get_nodes_in_group("Player"):
		if "is_mounted" in p and p.is_mounted:
			return
	var root_scene := get_tree().current_scene
	if is_instance_valid(root_scene) and get_parent() != root_scene:
		reparent(root_scene)
	reset_to_initial_position()

func on_map_changed(_map_key: String) -> void:
	if is_occupied and is_instance_valid(rider):
		global_position = rider.global_position
		visible = true
		return
	reset_to_initial_position()
@onready var player_place: Marker3D = $Player_Place

func _apply_horse_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= horse_gravity * delta
		# Impede que colisões com objetos pequenos lancem o cavalo para cima
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y = -0.1

func _physics_process(delta: float) -> void:
	if is_occupied and is_instance_valid(rider):
		if interaction_prompt:
			interaction_prompt.visible = false
		_apply_horse_gravity(delta)
		velocity.x = rider.velocity.x
		velocity.z = rider.velocity.z
		rotation.y = rider.rotation.y
		move_and_slide()
		if not is_on_floor() and velocity.y > 0.0:
			velocity.y = 0.0

		if "player_place" in self and is_instance_valid(self.player_place):
			rider.global_position = self.player_place.global_position
		else:
			rider.global_position = global_position + Vector3(0.0, 1.2, 0.0)
		rider.velocity.y = 0.0
		_update_horse_animation()
		return

	_apply_horse_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	if not is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0
	if anim_player and anim_player.has_animation("Armature|Idle") and anim_player.current_animation != "Armature|Idle":
		anim_player.play("Armature|Idle")

	var players = get_tree().get_nodes_in_group("Player")
	player_in_range = null
	for p in players:
		if p is CharacterBody3D and not p.is_dead:
			if global_position.distance_to(p.global_position) <= interact_distance:
				player_in_range = p
				break
	if interaction_prompt:
		interaction_prompt.visible = visible and is_instance_valid(player_in_range) and not is_occupied

func _update_horse_animation() -> void:
	if not anim_player or not is_instance_valid(rider):
		return
	var is_moving: bool = Vector2(rider.velocity.x, rider.velocity.z).length() > 0.2
	if is_moving:
		var anim_name: String = "Armature|Running" if anim_player.has_animation("Armature|Running") else ("Armature|Walk" if anim_player.has_animation("Walk") else "")
		if anim_name != "" and anim_player.current_animation != anim_name:
			anim_player.play(anim_name)
	else:
		if anim_player.has_animation("Armature|Idle") and anim_player.current_animation != "Armature|Idle":
			anim_player.play("Armature|Idle")

	var players = get_tree().get_nodes_in_group("Player")
	player_in_range = null
	for p in players:
		if p is CharacterBody3D and not p.is_dead:
			if global_position.distance_to(p.global_position) <= interact_distance:
				player_in_range = p
				break
	if interaction_prompt:
		interaction_prompt.visible = visible and is_instance_valid(player_in_range) and not is_occupied

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Montar"):
		if is_occupied and is_instance_valid(rider):
			if rider.has_method("dismount_horse"):
				rider.dismount_horse()
		elif visible and is_instance_valid(player_in_range) and global_position.distance_to(player_in_range.global_position) <= interact_distance:
			if player_in_range.has_method("mount_horse"):
				player_in_range.mount_horse(self)

func reset_to_initial_position() -> void:
	is_occupied = false
	rider = null
	velocity = Vector3.ZERO
	if LevelManager.current_map_key == "ilha_inicial" and is_instance_valid(LevelManager.current_map_instance):
		var horse_place := LevelManager.current_map_instance.find_child("Horse_place", true, false) as Marker3D
		if is_instance_valid(horse_place):
			global_position = horse_place.global_position
			visible = true
			return
	visible = false

func take_damage(amount: int) -> void:
	if is_occupied and is_instance_valid(rider):
		var current_rider := rider
		if current_rider.has_method("dismount_horse"):
			current_rider.dismount_horse()
		if current_rider.has_method("take_damage"):
			current_rider.take_damage(amount)
		reset_to_initial_position()
