class_name Cavalo
extends CharacterBody3D

@export var interact_distance: float = 3.0
@export var saddle_offset: Vector3 = Vector3(0.0, 1.1, 0.0)

var is_occupied: bool = false
var rider: CharacterBody3D = null
var rider_body_bone: Node3D = null
var player_in_range: CharacterBody3D = null
@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer", true, false)

func _ready() -> void:
	for p in get_tree().get_nodes_in_group("Player"):
		if "is_mounted" in p and p.is_mounted:
			queue_free()
			return
	add_to_group("PlayerHorse")
@onready var player_place: Marker3D = $Player_Place

func _physics_process(delta: float) -> void:
	if is_occupied and is_instance_valid(rider):
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		else:
			velocity.y = 0.0
		velocity.x = rider.velocity.x
		velocity.z = rider.velocity.z
		rotation.y = rider.rotation.y
		move_and_slide()

		if "player_place" in self and is_instance_valid(self.player_place):
			rider.global_position = self.player_place.global_position
		else:
			rider.global_position = global_position + Vector3(0.0, 1.2, 0.0)
		rider.velocity.y = 0.0
		_update_horse_animation()
		return

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	if anim_player and anim_player.has_animation("Armature|Idle") and anim_player.current_animation != "Armature|Idle":
		anim_player.play("Armature|Idle")

	var players = get_tree().get_nodes_in_group("Player")
	player_in_range = null
	for p in players:
		if p is CharacterBody3D and not p.is_dead:
			if global_position.distance_to(p.global_position) <= interact_distance:
				player_in_range = p
				break

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if is_occupied and is_instance_valid(rider):
			if rider.has_method("dismount_horse"):
				rider.dismount_horse()
		elif is_instance_valid(player_in_range) and global_position.distance_to(player_in_range.global_position) <= interact_distance:
			if player_in_range.has_method("mount_horse"):
				player_in_range.mount_horse(self)
