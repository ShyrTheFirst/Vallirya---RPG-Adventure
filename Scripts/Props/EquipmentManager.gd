class_name EquipmentManager
extends Node3D

@export var player: CharacterBody3D

# Dicionário de equipamentos atualmente equipados no player
# Chaves: "armor", "helmet", "boots", "weapon"
var equipped_items: Dictionary = {
	"armor": null,
	"helmet": null,
	"boots": null,
	"weapon": null
}

# Atributos bônus concedidos pelos equipamentos e pelo Full Set
var bonus_max_hp: int = 0
var bonus_defense: int = 0
var bonus_physical_attack: int = 0
var bonus_magic_attack: int = 0

func _ready() -> void:
	if not player:
		player = get_tree().current_scene.find_child("Player", true, false)

# --- EQUIPAR / DESEQUIPAR ITENS ---
func equip_item(slot_name: String, item_data: ItemData) -> void:
	if not equipped_items.has(slot_name):
		print("[EQUIPMENT] Slot inválido: ", slot_name)
		return
		
	equipped_items[slot_name] = item_data
	print("[EQUIPMENT] Item equipado no slot [%s]: %s" % [slot_name, item_data.item_name if item_data else "Vazio"])
	
	# Recalcula todos os atributos e bônus passivos
	recalculate_equipment_stats()

func unequip_item(slot_name: String) -> ItemData:
	if not equipped_items.has(slot_name):
		return null
		
	var removed_item = equipped_items[slot_name]
	equipped_items[slot_name] = null
	print("[EQUIPMENT] Item removido do slot [%s]" % slot_name)
	
	recalculate_equipment_stats()
	return removed_item

# --- CÁLCULO DE ATRIBUTOS E BÔNUS DE CONJUNTO (FULL SET) ---
func recalculate_equipment_stats() -> void:
	# Reseta os bônus acumulados
	bonus_max_hp = 0
	bonus_defense = 0
	bonus_physical_attack = 0
	bonus_magic_attack = 0
	
	# 1. Soma os atributos individuais de cada peça equipada
	for slot in equipped_items:
		var item: ItemData = equipped_items[slot]
		if not item:
			continue
			
		match slot:
			"armor":
				bonus_defense += item.stat_bonus
			"helmet":
				bonus_max_hp += item.stat_bonus
			"boots":
				# Bota pode dar mana ou velocidade, mas vamos somar no HP/Defesa ou customizar se necessário
				pass
			"weapon":
				# Valida se a arma é um Cajado para aplicar Ataque Mágico, senão Ataque Físico
				if item.has_method("is_staff") or (item.has("weapon_type") and item.weapon_type == ItemData.WeaponType.STAFF):
					bonus_magic_attack += item.stat_bonus
				else:
					bonus_physical_attack += item.stat_bonus

	# 2. Verifica se há um Bônus de Conjunto (Full Set) ativo
	var set_status = check_full_set_bonus()
	if set_status["has_set"]:
		var rarity = set_status["rarity"]
		var level = set_status["level"]
		
		var set_hp = 0
		var set_attack = 0
		
		match rarity:
			"epico":
				set_hp = 500 + (level * 250)
				set_attack = 100 + (level * 25)
			"lendario":
				set_hp = 1000 + (level * 500)
				set_attack = 250 + (level * 50)
				
		bonus_max_hp += set_hp
		# Se estiver de cajado ativo, o bônus de ataque do set vai para mágico, senão físico
		var is_staff_equipped = is_weapon_a_staff()
		if is_staff_equipped:
			bonus_magic_attack += set_attack
		else:
			bonus_physical_attack += set_attack
			
		print("[FULL SET] Conjunto %s (Nv.%d) ativo! HP Bônus: +%d | Ataque Bônus: +%d (%s)" % [
			rarity.capitalize(), level, set_hp, set_attack, "Mágico" if is_staff_equipped else "Físico"
		])

	# 3. Atualiza os stats diretamente no Player
	apply_stats_to_player()

func is_weapon_a_staff() -> bool:
	var weapon: ItemData = equipped_items.get("weapon", null)
	if weapon and weapon.weapon_type == ItemData.WeaponType.STAFF:
		return true
	return false

func check_full_set_bonus() -> Dictionary:
	var required_slots = ["armor", "helmet", "boots", "weapon"]
	
	for slot in required_slots:
		if equipped_items[slot] == null:
			return {"has_set": false, "rarity": "", "level": 0}
			
	var first_item: ItemData = equipped_items["armor"]
	var target_rarity = first_item.rarity
	var target_level = first_item.item_level
	
	for slot in required_slots:
		var current_item: ItemData = equipped_items[slot]
		if current_item.rarity != target_rarity or current_item.item_level != target_level:
			return {"has_set": false, "rarity": "", "level": 0}
			
	return {
		"has_set": true,
		"rarity": target_rarity,
		"level": target_level
	}

func apply_stats_to_player() -> void:
	if not player:
		return
		
	# Atualiza as variáveis correspondentes no Player (garanta que o Player possua essas propriedades)
	if "equipment_bonus_hp" in player: player.equipment_bonus_hp = bonus_max_hp
	if "equipment_bonus_defense" in player: player.equipment_bonus_defense = bonus_defense
	if "equipment_bonus_physical_attack" in player: player.equipment_bonus_physical_attack = bonus_physical_attack
	if "equipment_bonus_magic_attack" in player: player.equipment_bonus_magic_attack = bonus_magic_attack
	
	if player.has_method("update_derived_stats"):
		player.update_derived_stats()

# --- PERSISTÊNCIA (SALVAR E CARREGAR) ---
# Dica: Salvamos os caminhos dos recursos (.tres) equipados para recarregar sem erros
func get_save_data() -> Dictionary:
	var saved_slots = {}
	for slot in equipped_items:
		var item: ItemData = equipped_items[slot]
		saved_slots[slot] = item.resource_path if (item and item.resource_path != "") else ""
	return saved_slots

func load_saved_data(saved_data: Dictionary) -> void:
	for slot in saved_data:
		if equipped_items.has(slot):
			var path = str(saved_data[slot]).strip_edges()
			if path != "" and ResourceLoader.exists(path):
				var loaded_item = load(path) as ItemData
				equipped_items[slot] = loaded_item
			else:
				equipped_items[slot] = null
	recalculate_equipment_stats()
	print("[EQUIPMENT] Dados de equipamentos carregados e aplicados!")
