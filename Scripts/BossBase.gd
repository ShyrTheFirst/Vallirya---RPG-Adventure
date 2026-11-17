class_name BossBase
extends MonsterBase

@export_category("Configurações de Boss")
@export var boss_skills: Array[BossSkillData] = []
# Coloque aqui "Armature|Basico Direito" e "Armature|Basico Esquerdo" no Inspetor:
@export var basic_attack_anims: Array[String] = ["Armature|Basico Direito", "Armature|Basico Esquerdo"]
@export var hud_visibility_radius: float = 25.0 # Distância em metros para a barra aparecer na HUD
@export var telegraph_scene: PackedScene = preload("res://Scenes/VFX/TelegraphAoE.tscn")

var skill_cooldowns: Dictionary = {}
var is_casting_skill: bool = false
var is_showing_on_hud: bool = false

func _ready() -> void:
	super._ready()
	# Esconde a barra de vida 3D em cima da cabeça pois o Boss é gigante
	if health_bar_sprite:
		health_bar_sprite.visible = false
		
	for skill in boss_skills:
		if skill:
			skill_cooldowns[skill] = 0.0

func _physics_process(delta: float) -> void:
	if is_dead:
		if is_showing_on_hud:
			_set_boss_hud_visible(false)
		return
	
	# 1. Verifica distância do Player para mostrar/esconder a barra na HUD
	_check_hud_proximity()
	
	# 2. Atualiza os cooldowns das skills
	for skill in skill_cooldowns.keys():
		if skill_cooldowns[skill] > 0.0:
			skill_cooldowns[skill] -= delta
			
	# 3. Se estiver conjurando uma skill, trava no lugar na pose de combate (state_2)
	if is_casting_skill:
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		else:
			velocity.y = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		update_animations()
		update_status_effects(delta)
		return
		
	# 4. Durante a perseguição (CHASE), checa se alguma skill de distância está pronta
	if current_state == State.CHASE and is_instance_valid(current_target_player) and attack_cooldown <= 0.0:
		var dist = global_position.distance_to(current_target_player.global_position)
		var ready_skill = _get_available_skill(dist)
		if ready_skill:
			_cast_boss_skill(ready_skill, current_target_player)
			return

	super._physics_process(delta)

func is_busy_in_combat() -> bool:
	return is_casting_skill

# --- ATAQUES BÁSICOS (MÃO DIREITA / ESQUERDA) E SKILLS ---
func execute_attack(target: CharacterBody3D, range_dist: float) -> void:
	if is_casting_skill: return
	
	var dist = global_position.distance_to(target.global_position)
	var ready_skill = _get_available_skill(dist)
	
	if ready_skill:
		_cast_boss_skill(ready_skill, target)
	else:
		# Sorteia ou alterna entre os ataques básicos da lista (Direito / Esquerdo)
		if attacks_playback and basic_attack_anims.size() > 0:
			var chosen_basic = basic_attack_anims.pick_random()
			attacks_playback.start(chosen_basic)
		if anim_tree:
			anim_tree.set("parameters/attack_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		perform_cleave_attack(range_dist)

func _get_available_skill(dist: float) -> BossSkillData:
	for skill in boss_skills:
		if skill and skill_cooldowns.get(skill, 0.0) <= 0.0:
			if dist >= skill.min_range and dist <= skill.max_range:
				return skill
	return null

func _cast_boss_skill(skill: BossSkillData, target: CharacterBody3D) -> void:
	is_casting_skill = true
	skill_cooldowns[skill] = skill.cooldown
	attack_cooldown = skill.cast_time + 1.0
	
	var look_dir = (target.global_position - global_position).normalized()
	if look_dir.length() > 0.01:
		rotation.y = atan2(-look_dir.x, -look_dir.z)
		
	velocity = Vector3.ZERO
	update_animations()
	
	if skill.animation_name != "" and attacks_playback:
		attacks_playback.start(skill.animation_name)
		if anim_tree:
			anim_tree.set("parameters/attack_shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			
	if telegraph_scene:
		var telegraph = telegraph_scene.instantiate()
		get_tree().current_scene.add_child(telegraph)
		if telegraph.has_method("trigger_telegraph"):
			telegraph.trigger_telegraph(skill, self, target)
			
	await get_tree().create_timer(skill.cast_time + 0.4).timeout
	is_casting_skill = false

# --- SINCRONIZAÇÃO COM A BARRA DE VIDA NA HUD ---
func _check_hud_proximity() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	var player_near: bool = false
	
	for p in players:
		if is_instance_valid(p) and not p.is_dead:
			if global_position.distance_to(p.global_position) <= hud_visibility_radius:
				player_near = true
				break
				
	if player_near and not is_showing_on_hud:
		_set_boss_hud_visible(true)
	elif not player_near and is_showing_on_hud:
		_set_boss_hud_visible(false)

func _set_boss_hud_visible(show_bar: bool) -> void:
	is_showing_on_hud = show_bar
	var hud = get_tree().get_first_node_in_group("Player").hud_ref
	if not hud: return
	
	if show_bar and hud.has_method("show_or_update_boss_hud"):
		var title = "[Nv. %d] %s" % [level, monster_name]
		hud.show_or_update_boss_hud(self, title, hp, max_hp)
	elif not show_bar and hud.has_method("hide_boss_hud"):
		hud.hide_boss_hud(self)

# Sobrescreve as funções do MonsterBase para manter a HUD sempre atualizada quando levar dano ou resetar
func show_damage_effect(amount: int, current_hp: int) -> void:
	super.show_damage_effect(amount, current_hp)
	if is_showing_on_hud and not is_dead:
		_set_boss_hud_visible(true)

func update_display() -> void:
	super.update_display()
	if is_showing_on_hud and not is_dead:
		_set_boss_hud_visible(true)

func rpc_despawn() -> void:
	super.rpc_despawn() # Esconde o modelo e desativa a colisão normalmente
	
	# 1. Garante que a barra na HUD mostre 0 de vida imediatamente
	if is_showing_on_hud:
		var hud = get_tree().get_first_node_in_group("HUD")
		if hud and hud.has_method("show_or_update_boss_hud"):
			var title = "[Nv. %d] %s" % [level, monster_name]
			hud.show_or_update_boss_hud(self, title, 0, max_hp)
			
		# 2. Aguarda 3 segundos para o player ver a barra zerada antes de sumir
		await get_tree().create_timer(3.0).timeout
		
		# 3. Se o boss ainda estiver morto após os 3s, esconde a barra da HUD
		if is_dead:
			_set_boss_hud_visible(false)
