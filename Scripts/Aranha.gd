extends MonsterBase

func _ready() -> void:
	monster_name = "Aranha"
	speed = 4.8
	base_attack_range = 5.1
	mesh_base_y = 0
	health_bar_height = 1.5
	super._ready()
	
	# Inicializa o playback da StateMachine de ataques do AnimationTree herdado do base
	if anim_tree:
		attacks_playback = anim_tree.get("parameters/AttacksCombo/playback")

# Aplica efeitos visuais de raridade (ex: cores da aura no Material Override)
func apply_rarity_effects() -> void:
	var epic_aura = get_node_or_null("EpicAura")
	var rare_aura = get_node_or_null("RareAura")
	if not epic_aura and not rare_aura:
		return

	match rarity:
		"Épico":
			epic_aura.visible = true
			rare_aura.visible = false
		"Raro":
			rare_aura.visible = true
			epic_aura.visible = false
		_:
			epic_aura.visible = false
			rare_aura.visible = false

func execute_attack(target: CharacterBody3D, range_dist: float) -> void:
	perform_cleave_attack(range_dist)
	
	# A aranha tem apenas 1 ataque principal (Ataque 1)
	var anim_name = "Armature|Ataque 1"
	play_spider_attack(anim_name)

func play_spider_attack(anim_name: String) -> void:
	# 1. Dispara a animação na StateMachine de combos (que é o que realmente toca o ataque)
	if attacks_playback:
		attacks_playback.start(anim_name)
		
	# 2. Se o seu AnimationTree realmente usa o OneShot, chamamos direto sem o 'has_parameter'
	if anim_tree:
		anim_tree.set("parameters/attack_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	# 3. Toca o som de ataque
	if attack_audio and attack_audio.stream:
		attack_audio.play()
