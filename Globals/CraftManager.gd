class_name CraftingManager
extends Node

# --- CONTROLE DE PROGRESSÃO E ESPECIALIZAÇÃO ---
# Estrutura dos dados salvos por tipo de equipamento e nível:
# equipment_progress[tipo_equipamento][nivel] = quantidade de itens craftados
# Exemplo: equipment_progress["elmo"][1] = 8 (significa que fez 8 elmos de nível 1)
var equipment_progress: Dictionary = {
	"armadura": {},
	"elmo": {},
	"bota": {},
	"espada": {},
	"lanca": {},
	"machado": {},
	"cajado": {},
	"barras": {},
	"tabuas": {}
}

# Quantidade de itens do tier atual necessários para subir de nível de maestria (5 itens = 100% XP)
const CRAFTS_REQUIRED_FOR_NEXT_TIER: int = 5
const XP_PER_LEVEL: float = 100.0
const MAX_MASTERY_LEVEL: int = 50

func _ready() -> void:
	initialize_progress_tables()

func initialize_progress_tables() -> void:
	for type in equipment_progress.keys():
		if not equipment_progress[type].has("mastery_level"):
			equipment_progress[type]["mastery_level"] = 1
		if not equipment_progress[type].has("mastery_xp"):
			equipment_progress[type]["mastery_xp"] = 0.0
		for lvl in range(1, 11): # Níveis de 1 a 10
			if not equipment_progress[type].has(lvl):
				equipment_progress[type][lvl] = {
					"total_crafted": 0
				}

# --- VALIDAÇÃO DE DESBLOQUEIO DE NÍVEL (GATING) ---
func can_craft_item(equipment_type: String, target_level: int) -> bool:
	if equipment_type == "outros" or target_level <= 1:
		return true
	if not equipment_progress.has(equipment_type):
		return false
	var current_mastery_level: int = int(equipment_progress[equipment_type].get("mastery_level", 1))
	return target_level <= current_mastery_level

# --- CÁLCULO DE ESPECIALISTA (SORTE NO SACO DE PROBABILIDADES) ---
func get_custom_probability_bag(equipment_type: String, tier_level: int) -> Array[String]:
	var mastery_rank: int = 0
	if equipment_progress.has(equipment_type):
		mastery_rank = max(0, int(equipment_progress[equipment_type].get("mastery_level", 1)) - 1)
	
	var bag: Array[String] = []
	var lendario_count = 1
	var epico_count = 5
	var raro_count = 24
	var incomum_count = 35
	var comum_count = 35
	
	# Bônus de Especialista: Adiciona mais cartas raras/lendárias no saco de 100
	lendario_count += mastery_rank
	epico_count += mastery_rank * 2
	
	for i in range(lendario_count): bag.append("lendario")
	for i in range(epico_count): bag.append("epico")
	for i in range(raro_count): bag.append("raro")
	for i in range(incomum_count): bag.append("incomum")
	for i in range(comum_count): bag.append("comum")
	
	bag.shuffle()
	return bag

func draw_rarity_with_specialization(equipment_type: String, tier_level: int) -> String:
	var bag = get_custom_probability_bag(equipment_type, tier_level)
	return bag.pop_front()

# --- REGISTRO DE PROGRESSO APÓS O CRAFT ---
func register_successful_craft(equipment_type: String, tier_level: int, player: CharacterBody3D = null) -> void:
	if not equipment_progress.has(equipment_type):
		return

	if equipment_progress[equipment_type].has(tier_level):
		equipment_progress[equipment_type][tier_level]["total_crafted"] += 1

	var current_level: int = int(equipment_progress[equipment_type].get("mastery_level", 1))
	if current_level >= MAX_MASTERY_LEVEL:
		return

	# Tier atual: 5 crafts = 100% (20.0 XP por craft).
	# Tiers anteriores: 25% de eficiência por nível de diferença (ex: T1 no Nv2 dá 5.0 XP, 5 crafts = 25%).
	var base_xp: float = XP_PER_LEVEL / float(CRAFTS_REQUIRED_FOR_NEXT_TIER)
	var level_diff: int = max(0, current_level - tier_level)
	var gained_xp: float = base_xp * pow(0.25, level_diff)

	var current_xp: float = float(equipment_progress[equipment_type].get("mastery_xp", 0.0)) + gained_xp
	while current_xp >= XP_PER_LEVEL and current_level < MAX_MASTERY_LEVEL:
		current_xp -= XP_PER_LEVEL
		current_level += 1
		if player:
			play_level_up_sound(player)
			if player.has_method("send_message_HUD"):
				player.send_message_HUD("¡Novo Nível de Craft Desbloqueado!", Color.GOLD)

	equipment_progress[equipment_type]["mastery_level"] = current_level
	equipment_progress[equipment_type]["mastery_xp"] = current_xp
# --- EXECUÇÃO PRINCIPAL DO CRAFT ---
func execute_station_craft(equipment_type: String, recipe_tier: int, base_item: ItemData) -> ItemData:
	# 1. Valida se o player já liberou esse nível para esse tipo de equipamento
	if not can_craft_item(equipment_type, recipe_tier):
		print("[CRAFTING] Bloqueado! Você precisa craftar 10 itens de nível %d antes de liberar o nível %d de %s." % [recipe_tier - 1, recipe_tier, equipment_type])
		return null
		
	# 2. Sorteia a raridade influenciada pelo nível de especialista
	var selected_rarity = draw_rarity_with_specialization(equipment_type, recipe_tier)
	
	# 3. Cria e bonifica o item
	var crafted_item = base_item.duplicate() as ItemData
	crafted_item.level = recipe_tier # Ajustado de 'item_level' para 'level'
	if base_item.resource_path != "":
		crafted_item.resource_path = base_item.resource_path
		crafted_item.set_meta("source_path", base_item.resource_path)
	
	# Converte a string da raridade para o Enum correspondente do seu ItemData
	match selected_rarity:
		"comum": crafted_item.rarity = ItemData.Rarity.COMMON
		"incomum": crafted_item.rarity = ItemData.Rarity.UNCOMMON
		"raro": crafted_item.rarity = ItemData.Rarity.RARE
		"epico": crafted_item.rarity = ItemData.Rarity.EPIC
		"lendario": crafted_item.rarity = ItemData.Rarity.LEGENDARY
	
	apply_rarity_and_level_multipliers(crafted_item, recipe_tier, selected_rarity)
	
	# 4. Registra o progresso e a maestria
	register_successful_craft(equipment_type, recipe_tier)
	
	return crafted_item

## Calcula a quantidade final do craft, aplicando +1% de chance por nível de maestria
## a partir do nível 6 para produzir uma barra ou tábua adicional.
func roll_bonus_craft_quantity(equipment_type: String, _base_item: ItemData, base_quantity: int) -> int:
	if equipment_type != "barras" and equipment_type != "tabuas":
		return base_quantity
	var mastery_level: int = int(equipment_progress.get(equipment_type, {}).get("mastery_level", 1))
	if mastery_level < 6:
		return base_quantity
	var bonus_chance: float = float(mastery_level - 5) * 0.01
	if randf() < bonus_chance:
		return base_quantity + 1
	return base_quantity

# --- TABELA DE MULTIPLICADORES DE ATRIBUTOS (Mantida) ---
func apply_rarity_and_level_multipliers(item: ItemData, level: int, rarity: String) -> void:
	var multiplier = 1.0
	if level <= 8:
		match rarity:
			"comum": multiplier = 1.0
			"incomum": multiplier = 1.5
			"raro": multiplier = 2.0
			"epico": multiplier = 3.0
			"lendario": multiplier = 5.0
	elif level == 9:
		match rarity:
			"comum": multiplier = 1.5
			"incomum": multiplier = 3.0
			"raro": multiplier = 4.0
			"epico": multiplier = 6.0
			"lendario": multiplier = 10.0
	elif level >= 10:
		match rarity:
			"comum": multiplier = 2.0
			"incomum": multiplier = 4.0
			"raro": multiplier = 8.0
			"epico": multiplier = 12.0
			"lendario": multiplier = 20.0
			
	var base_val = 15.0
	var final_bonus = int(base_val * level * multiplier)
	
	# Aplica o bônus dinamicamente com base no que o item possui de atributo base
	if item.bonus_attack > 0:
		item.bonus_attack = int(item.bonus_attack * multiplier) # Ou usa o final_bonus como base
	if item.bonus_defense > 0:
		item.bonus_defense = int(item.bonus_defense * multiplier)
	if item.bonus_hp > 0:
		item.bonus_hp = int(item.bonus_hp * multiplier)
	if item.bonus_mana > 0:
		item.bonus_mana = int(item.bonus_mana * multiplier)
		
	# Fallback caso o item criado seja genérico (como poções ou consumíveis de teste)
	if item.bonus_attack == 0 and item.bonus_defense == 0 and item.bonus_hp == 0 and item.bonus_mana == 0:
		if item.item_type == ItemData.ItemType.ARMOR or item.item_type == ItemData.ItemType.HELM or item.item_type == ItemData.ItemType.BOOTS:
			item.bonus_defense = final_bonus
		elif item.item_type == ItemData.ItemType.WEAPON:
			item.bonus_attack = final_bonus
		else:
			item.bonus_hp = final_bonus # Consumíveis e outros ganham bônus de HP/Efeito

	# Ativa o efeito visual lendário se for o caso
	if "active_legendary" in item:
		item.active_legendary = (rarity == "lendario")

# --- PERSISTÊNCIA ---
func get_save_data() -> Dictionary:
	return { "equipment_progress": equipment_progress }

func load_saved_data(saved_data: Dictionary) -> void:
	if saved_data.has("equipment_progress") and typeof(saved_data["equipment_progress"]) == TYPE_DICTIONARY:
		var saved_dict = saved_data["equipment_progress"]
		for type in saved_dict.keys():
			if equipment_progress.has(type):
				var levels_dict = saved_dict[type]
				if levels_dict.has("mastery_level"):
					equipment_progress[type]["mastery_level"] = int(levels_dict["mastery_level"])
				if levels_dict.has("mastery_xp"):
					equipment_progress[type]["mastery_xp"] = float(levels_dict["mastery_xp"])
				for lvl_key in levels_dict.keys():
					if str(lvl_key).is_valid_int():
						var lvl_int = int(lvl_key)
						if equipment_progress[type].has(lvl_int):
							equipment_progress[type][lvl_int]["total_crafted"] = int(levels_dict[lvl_key].get("total_crafted", 0))
		print("[CRAFTING] Progresso e especializações de equipamentos carregados com sucesso!")

# Sinal ou função para tocar o som de conquista de nível/desbloqueio
func play_level_up_sound(player: CharacterBody3D) -> void:
	if player and player.has_node("CraftLevelUp"): 
		var audio = player.get_node("CraftLevelUp") as AudioStreamPlayer3D
		if audio and audio.stream:
			audio.play()

# Retorna uma cópia limpa do dicionário de progresso para a UI exibir
func get_all_progress_data() -> Dictionary:
	return equipment_progress
