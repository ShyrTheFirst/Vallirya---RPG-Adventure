class_name WorldItem
extends RigidBody3D

var item_id: int = -1
@export var item_data: ItemData

@onready var item_place: Node3D = get_node_or_null("ItemPlace")
@onready var area_col: Area3D = get_node_or_null("Area3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("Forma")

func _ready() -> void:
	linear_damp = 2.5
	angular_damp = 4.0

	update_mesh_visual()

	if area_col:
		if not area_col.body_entered.is_connected(_on_body_entered):
			area_col.body_entered.connect(_on_body_entered)
	else:
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)

func update_mesh_visual() -> void:
	if not item_place:
		return

	for child in item_place.get_children():
		child.queue_free()

	if item_data and item_data.mesh_scene:
		var visual = item_data.mesh_scene.instantiate()
		item_place.add_child(visual)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		# Adiciona o item diretamente ao inventário do player local
		if body.has_method("add_item_to_inventory"):
			var success = body.add_item_to_inventory(item_data, 1)
			if success:
				if has_node("/root/QuestManager"):
					QuestManager.on_inventory_updated(body)
				if body.has_method("save_player_account"):
					body.save_player_account()
				queue_free() # Remove o item do chão
