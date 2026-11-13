class_name WorldItem
extends RigidBody3D

var item_id = -1
@export var item_data: ItemData

@onready var item_place: Node3D = get_node_or_null("ItemPlace")
@onready var area_col: Area3D = get_node_or_null("Area3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("Forma")

var is_collected: bool = false
@onready var collected_audio: AudioStreamPlayer3D = $CollectedAudio

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

func setup(new_item_data: ItemData) -> void:
	item_data = new_item_data
	if item_data:
		item_id = item_data.id if "id" in item_data else -1
	
	update_mesh_visual()

func update_mesh_visual() -> void:
	if not item_place:
		return

	for child in item_place.get_children():
		child.queue_free()

	if item_data and item_data.mesh_scene:
		var visual = item_data.mesh_scene.instantiate()
		item_place.add_child(visual)
		
		# Ajusta a colisão com base na malha do item instanciado
		update_collision_shape(visual)

func update_collision_shape(visual_node: Node3D) -> void:
	if not collision_shape:
		return

	# Procura por um MeshInstance3D dentro da cena do item para extrair o tamanho
	var mesh_instance: MeshInstance3D = null
	if visual_node is MeshInstance3D:
		mesh_instance = visual_node
	else:
		# Varre os filhos caso seja um Node3D composto
		for child in visual_node.find_children("*", "MeshInstance3D", true, false):
			if child is MeshInstance3D:
				mesh_instance = child
				break

	if mesh_instance and mesh_instance.mesh:
		# Se encontrou a malha, cria uma forma de colisão baseada na caixa delimitadora (AABB) da malha
		var aabb = mesh_instance.get_aabb()
		var box_shape = BoxShape3D.new()
		box_shape.size = aabb.size * mesh_instance.scale
		
		collision_shape.shape = box_shape
		# Ajusta a posição da colisão para o centro geométrico do item
		collision_shape.position = aabb.position + (aabb.size / 2.0)
	else:
		# Fallback: Se não achar malha, garante uma caixinha padrão em vez de esfera redonda
		if not collision_shape.shape is BoxShape3D:
			var default_box = BoxShape3D.new()
			default_box.size = Vector3(0.4, 0.4, 0.4)
			collision_shape.shape = default_box

func _on_body_entered(body: Node3D) -> void:
	if is_collected or not is_instance_valid(body):
		return

	if body.is_in_group("Player"):
		if not item_data:
			return
			
		is_collected = true # Trava o item imediatamente
		collected_audio.play()
		
		# Desliga a colisão para evitar novas interações físicas instantâneas
		collision_layer = 0
		collision_mask = 0
		if area_col:
			area_col.monitoring = false

		# Adiciona o item ao inventário do player
		if body.has_method("add_item_to_inventory"):
			var success = body.add_item_to_inventory(item_data, 1)
			if success:
				# Salva o jogo de forma segura
				if body.has_method("save_player_account"):
					body.save_player_account()
				call_deferred("queue_free")
			else:
				# Se o inventário estiver cheio, destrava para permitir tentar de novo depois
				is_collected = false
