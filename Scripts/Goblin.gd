extends MonsterBase

# Variáveis para criar o arco de emboscada (flank) do goblin
var flank_timer: float = 0.0
var flank_direction: int = 1

func _ready() -> void:
	monster_name = "Goblin Errante"
	speed = 3.8
	base_attack_range = 1.2
	mesh_base_y = 0
	health_bar_height = 1.5
	super._ready()
	
	# Sorteia se esse goblin vai tentar rodar pela esquerda ou pela direita
	flank_direction = 1 if randf() > 0.5 else -1
	
	if anim_tree:
		attacks_playback = anim_tree.get("parameters/AttacksCombo/playback")

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

# SOBRESCREVENDO O COMPORTAMENTO DE PERSEGUIÇÃO (CHASE) PARA FAZER EMBOSCADA
func _physics_process(delta: float) -> void:
	# Deixa o MonsterBase rodar a máquina de estados principal e a física padrão
	super._physics_process(delta)

	# Se o goblin estiver no estado de perseguição (CHASE), aplicamos o desvio tático de flanco
	if current_state == State.CHASE and is_instance_valid(current_target_player) and nav_agent:
		flank_timer -= delta
		if flank_timer <= 0.0:
			flank_timer = randf_range(3.0, 6.0)
			flank_direction *= -1 # Inverte o lado de vez em quando para confundir o alvo

		var player_pos = current_target_player.global_position
		var to_player = global_position - player_pos
		to_player.y = 0.0
		
		# Cria um ponto ao lado do player (perpendicular) para formar um arco de cerco
		var tangent = Vector3(-to_player.z, 0, to_player.x).normalized() * flank_direction
		var flank_target = player_pos + (to_player.normalized() * 1.8) + (tangent * 2.5)
		
		# Atualiza o destino do agente de navegação fazendo uma curva em vez de ir reto
		nav_agent.target_position = flank_target

func execute_attack(target: CharacterBody3D, range_dist: float) -> void:
	perform_cleave_attack(range_dist)
	
	var combo_step = randi_range(1, 5)
	var anim_name = "Armature|Ataque %d" % combo_step
	
	play_goblin_attack(anim_name)

func play_goblin_attack(anim_name: String) -> void:
	# 1. Dispara a animação na StateMachine de combos (que é o que realmente toca o ataque)
	if attacks_playback:
		attacks_playback.start(anim_name)
		
	# 2. Se o seu AnimationTree realmente usa o OneShot, chamamos direto sem o 'has_parameter'
	if anim_tree:
		anim_tree.set("parameters/attack_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
	# 3. Toca o som de ataque
	if attack_audio and attack_audio.stream:
		attack_audio.play()
