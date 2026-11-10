class_name CraftingManager
extends Node

# Estrutura de uma receita de craft
# { "result_item": ItemData, "materials": { MaterialItemData: quantidade_necessaria } }

func craft_item(player: Node, recipe: Dictionary) -> bool:
	if not player or not "inventory_items" in player:
		return false

	var required_materials: Dictionary = recipe.get("materials", {})
	
	# 1. Verifica se o player possui todos os materiais no inventário
	for mat_item in required_materials.keys():
		var needed_qty = required_materials[mat_item]
		var owned_qty = 0
		
		for slot in player.inventory_items:
			if slot != null and slot["item"] == mat_item:
				owned_qty += slot["amount"]
		
		if owned_qty < needed_qty:
			print("[CRAFT] Materiais insuficientes para este item!")
			return false

	# 2. Consome os materiais do inventário
	for mat_item in required_materials.keys():
		var needed_qty = required_materials[mat_item]
		
		for i in range(player.inventory_items.size()):
			var slot = player.inventory_items[i]
			if slot != null and slot["item"] == mat_item:
				if slot["amount"] >= needed_qty:
					slot["amount"] -= needed_qty
					if slot["amount"] <= 0:
						player.inventory_items[i] = null
					needed_qty = 0
					break
				else:
					needed_qty -= slot["amount"]
					player.inventory_items[i] = null
			if needed_qty <= 0:
				break

	# 3. Gera o item craftado aplicando chances de raridade alta baseadas na sorte/craft
	var base_item: ItemData = recipe.get("result_item")
	if base_item:
		# Lógica de rolagem de raridade para itens craftados (permite épico e lendário)
		var crafted_item = _roll_crafted_rarity(base_item)
		player.add_item_to_inventory(crafted_item, 1)
		print("[CRAFT] Sucesso! Item fabricado: ", crafted_item.item_name)
		player.update_inventory_display()
		return true

	return false

func _roll_crafted_rarity(base: ItemData) -> ItemData:
	# Cria uma cópia duplicada do recurso para não alterar o original do disco
	var newItem: ItemData = base.duplicate()
	var roll = randf() * 100.0
	
	# Tabela de chances de raridade no Crafting:
	# 50% Comum | 30% Incomum | 15% Raro | 4% Épico | 1% Lendário
	if roll <= 1.0:
		newItem.rarity = ItemData.Rarity.LEGENDARY
		_scale_item_stats(newItem, 2.5) # Multiplicador de status lendário
	elif roll <= 5.0:
		newItem.rarity = ItemData.Rarity.EPIC
		_scale_item_stats(newItem, 1.9)
	elif roll <= 20.0:
		newItem.rarity = ItemData.Rarity.RARE
		_scale_item_stats(newItem, 1.4)
	elif roll <= 50.0:
		newItem.rarity = ItemData.Rarity.UNCOMMON
		_scale_item_stats(newItem, 1.15)
	else:
		newItem.rarity = ItemData.Rarity.COMMON
		
	return newItem

func _scale_item_stats(item: ItemData, multiplier: float) -> void:
	item.bonus_attack = int(item.bonus_attack * multiplier)
	item.bonus_defense = int(item.bonus_defense * multiplier)
	item.bonus_hp = int(item.bonus_hp * multiplier)
	item.bonus_mana = int(item.bonus_mana * multiplier)
