extends BossBase

func _ready() -> void:
	hp_factor = 3.0
	atk_factor = 1.2
	def_factor = 1.5
	super._ready()

func _cast_boss_skill(skill: BossSkillData, target: CharacterBody3D) -> void:
	if skill.animation_name == "Armature|Tremor" and anim_tree:
		# Inicia a animação e pausa em 0.1s (pose com as mãos para o alto) para o player reagir
		var pause_delay: float = 0.1
		var hold_duration: float = max(0.1, skill.cast_time - pause_delay)
		get_tree().create_timer(pause_delay).timeout.connect(func():
			if is_instance_valid(self) and not is_dead and anim_tree:
				anim_tree.set("parameters/TimeScale/scale", 0.0)
				get_tree().create_timer(hold_duration).timeout.connect(func():
					if is_instance_valid(self) and anim_tree:
						anim_tree.set("parameters/TimeScale/scale", 1.0)
				)
		)
	await super._cast_boss_skill(skill, target)
