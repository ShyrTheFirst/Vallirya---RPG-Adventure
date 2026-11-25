class_name TreasureChest
extends StaticBody3D

@export_category("Itens do Baú")
@export var chest_id: String = "" # ID único para salvar quais itens já foram coletados
@export var chest_items: Array[ItemData] = []
@export var chest_quantities: Array[int] = [] # Opcional: quantidade de cada item no mesmo índice

@export_category("Interação")
@export var interact_action: String = "Interagir"
@export var prompt_text: String = "'E'"

@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_prompt: Sprite3D = $InteractionPrompt
@onready var sub_viewport: SubViewport = $InteractionPrompt/SubViewport
@onready var prompt_label: Label = $InteractionPrompt/SubViewport/Label
@onready var lid_mesh: MeshInstance3D = get_node_or_null("Bau_Superior")

var current_loot: Array = [] # Array de Dictionaries: {"item": ItemData, "amount": int}
var player_in_range: CharacterBody3D = null
var is_opened: bool = false

func _ready() -> void:
	if interaction_prompt and sub_viewport:
		interaction_prompt.texture = sub_viewport.get_texture()
		interaction_prompt.visible = false
	if prompt_label:
		prompt_label.text = prompt_text

	# Monta a lista interna de itens do baú
	for i in range(chest_items.size()):
		if chest_items[i] != null:
			var qtd = chest_quantities[i] if i < chest_quantities.size() and chest_quantities[i] > 0 else 1
			current_loot.append({"item": chest_items[i], "amount": qtd, "slot_index": i})

	call_deferred("_sync_loot_with_player")

	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _sync_loot_with_player() -> void:
	if chest_id == "":
		return
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not ("opened_chests" in player):
		return
	if not player.opened_chests.has(chest_id):
		return

	var collected_raw = player.opened_chests[chest_id]
	if not (collected_raw is Array):
		return

	var collected_indices: Array = []
	for idx_val in collected_raw:
		collected_indices.append(int(idx_val))

	for i in range(current_loot.size() - 1, -1, -1):
		var s_idx: int = int(current_loot[i].get("slot_index", -1))
		if s_idx in collected_indices:
			current_loot.remove_at(i)

	if current_loot.is_empty():
		is_opened = true
		if lid_mesh:
			lid_mesh.rotation_degrees.x -= 65.0

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(player_in_range):
		return

	var pressed_interact: bool = false
	if interact_action != "" and InputMap.has_action(interact_action):
		pressed_interact = event.is_action_pressed(interact_action)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		pressed_interact = true

	if pressed_interact:
		_open_chest()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and body is CharacterBody3D:
		player_in_range = body
		if interaction_prompt and not current_loot.is_empty():
			interaction_prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body == player_in_range:
		if player_in_range.has_method("close_chest_loot_window"):
			player_in_range.close_chest_loot_window()
		player_in_range = null
		if interaction_prompt:
			interaction_prompt.visible = false

func _open_chest() -> void:
	if current_loot.is_empty():
		if player_in_range.has_method("send_message_HUD"):
			player_in_range.send_message_HUD("O baú está vazio!", Color(0.8, 0.8, 0.8))
		return

	if not is_opened:
		is_opened = true
		# Anima a tampa do baú abrindo (se o pivô permitir, ajuste o eixo X ou Z conforme seu modelo)
		if lid_mesh:
			var t = create_tween()
			t.tween_property(lid_mesh, "rotation_degrees:x", lid_mesh.rotation_degrees.x - 65.0, 0.35).set_trans(Tween.TRANS_BACK)

	if player_in_range.has_method("open_chest_loot_window"):
		player_in_range.open_chest_loot_window(self)
