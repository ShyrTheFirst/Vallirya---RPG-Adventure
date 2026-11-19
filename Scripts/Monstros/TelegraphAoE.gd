extends Area3D

@onready var visual_mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func trigger_telegraph(skill: BossSkillData, caster: Node3D, target: Node3D = null) -> void:
	# 1. Isola o material do shader
	var base_mat = visual_mesh.material_override
	if not base_mat:
		base_mat = visual_mesh.get_surface_override_material(0)
		
	var mat: ShaderMaterial = null
	if base_mat and base_mat is ShaderMaterial:
		mat = base_mat.duplicate() as ShaderMaterial
		visual_mesh.material_override = mat
	
	# 2. Define o ponto de origem (Boss ou Pé do Player)
	var forward_dir = -caster.global_transform.basis.z.normalized()
	global_rotation = caster.global_rotation
	
	var base_pos = caster.global_position
	if skill.origin_type == BossSkillData.OriginType.TARGET and is_instance_valid(target):
		base_pos = target.global_position

	# 3. Configura Escala, Posição e Colisão
	if skill.shape_type == BossSkillData.ShapeType.RECTANGLE:
		scale = Vector3(skill.area_size.x * 0.5, 1.0, skill.area_size.y * 0.5)
		
		if skill.origin_type == BossSkillData.OriginType.TARGET:
			global_position = base_pos + Vector3(0, 0.05, 0)
		else:
			var center_distance = (skill.area_size.y * 0.5) + skill.forward_offset
			global_position = base_pos + (forward_dir * center_distance) + Vector3(0, 0.05, 0)
		
		var box = BoxShape3D.new()
		box.size = Vector3(2.0, 2.0, 2.0)
		collision_shape.shape = box
	else:
		scale = Vector3(skill.area_size.x, 1.0, skill.area_size.y)
		
		if skill.origin_type == BossSkillData.OriginType.TARGET:
			global_position = base_pos + Vector3(0, 0.05, 0)
		else:
			global_position = base_pos + (forward_dir * skill.forward_offset) + Vector3(0, 0.05, 0)
		
		var cyl = CylinderShape3D.new()
		cyl.radius = 1.0
		cyl.height = 2.0
		collision_shape.shape = cyl

	# Configura os parâmetros iniciais do Shader
	if mat:
		mat.set_shader_parameter("shape_type", int(skill.shape_type))
		mat.set_shader_parameter("cone_angle", skill.cone_angle)
		mat.set_shader_parameter("progress", 0.0)
	
	# 4. Anima o preenchimento durante o cast_time
	var tween = create_tween()
	tween.tween_method(
		func(val: float): 
			if mat: mat.set_shader_parameter("progress", val),
		0.0, 1.0, skill.cast_time
	)
	
	await tween.finished
	
	if not is_instance_valid(caster) or caster.is_dead:
		queue_free()
		return
		
	# 5. APLICAÇÃO DE DANO ROBUSTA (Garante detecção imediata)
	# Força um frame de atualização física para o motor registrar os corpos dentro da área
	await get_tree().physics_frame
	
	var overlapping_bodies = get_overlapping_bodies()
	
	# Fallback de segurança caso o motor ainda não tenha populado a lista por conta da escala
	if overlapping_bodies.is_empty():
		for node in get_tree().get_nodes_in_group("Player"):
			if node is CharacterBody3D and not node.is_dead:
				# Verifica a distância em relação ao centro do telegraph baseado no raio/tamanho da skill
				var max_radius = max(skill.area_size.x, skill.area_size.y)
				if global_position.distance_to(node.global_position) <= max_radius:
					overlapping_bodies.append(node)

	for body in overlapping_bodies:
		if body.is_in_group("Player") and body.has_method("take_damage"):
			if skill.shape_type == BossSkillData.ShapeType.CONE:
				var dir_to_player = (body.global_position - global_position)
				dir_to_player.y = 0.0
				if dir_to_player.length() > 0.01:
					var angle_to_player = rad_to_deg(forward_dir.angle_to(dir_to_player.normalized()))
					if angle_to_player > (skill.cone_angle * 0.5):
						continue
						
			var final_dmg: int = int(skill.damage)
			if is_instance_valid(caster) and "attack_damage" in caster:
				final_dmg = int(max(skill.damage, caster.attack_damage * 1.4))
			body.take_damage(final_dmg)
			
	# 6. Instancia o VFX do golpe
	if skill.vfx_scene:
		var vfx = skill.vfx_scene.instantiate()
		get_tree().current_scene.add_child(vfx)
		vfx.global_position = global_position
		vfx.global_rotation = global_rotation
		
	queue_free()
