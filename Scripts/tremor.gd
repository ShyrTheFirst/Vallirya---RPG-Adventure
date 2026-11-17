extends Node3D

@onready var debris_particles: GPUParticles3D = $DebrisParticles
@onready var dust_particles: GPUParticles3D = $DustParticles
@onready var rock_spikes_container: Node3D = $RockSpikes
@onready var impact_audio: AudioStreamPlayer3D = $ImpactAudio

func _ready() -> void:
	# 1. Dispara as partículas de pedregulhos e poeira
	if debris_particles:
		debris_particles.emitting = true
	if dust_particles:
		dust_particles.emitting = true
	if impact_audio and impact_audio.stream:
		impact_audio.play()
		
	# 2. Anima as pontas de rocha brotando do chão
	if rock_spikes_container:
		_animate_rock_spikes()
		
	# 3. Tremor de câmera no impacto
	_shake_active_camera(0.4, 0.25)
	
	# 4. Deleta o efeito após as rochas afundarem de volta (2.2s)
	await get_tree().create_timer(2.2).timeout
	queue_free()

func _animate_rock_spikes() -> void:
	for spike in rock_spikes_container.get_children():
		if not spike is Node3D: continue
		
		var target_y: float = spike.position.y
		var target_scale: Vector3 = spike.scale
		var hidden_y: float = target_y - 2.5 # Esconde 2.5m abaixo do solo
		
		# Estado inicial: escondida embaixo da terra e mais fina
		spike.position.y = hidden_y
		spike.scale = Vector3(target_scale.x * 0.2, target_scale.y * 0.2, target_scale.z * 0.2)
		
		# Calcula um pequeno atraso baseado na distância do centro (cria efeito de onda de dentro pra fora!)
		var dist_from_center = Vector2(spike.position.x, spike.position.z).length()
		var delay = clamp(dist_from_center * 0.04, 0.0, 0.2)
		
		var t = create_tween()
		t.tween_interval(delay)
		
		# Sobe rápido rasgando o chão (0.12s) com efeito elástico/forte (TRANS_BACK)
		t.tween_property(spike, "position:y", target_y, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(spike, "scale", target_scale, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# Fica exposta fora da terra por um curto período (0.6s a 0.9s)
		t.tween_interval(randf_range(0.6, 0.9))
		
		# Afunda de volta na terra suavemente (0.4s)
		t.tween_property(spike, "position:y", hidden_y, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(spike, "scale", Vector3.ZERO, 0.4)

func _shake_active_camera(duration: float, intensity: float) -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	
	var tween = create_tween()
	var steps = 8
	var step_time = duration / float(steps)
	
	for i in range(steps):
		var rand_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(cam, "h_offset", rand_offset.x, step_time * 0.5)
		tween.parallel().tween_property(cam, "v_offset", rand_offset.y, step_time * 0.5)
		
	tween.tween_property(cam, "h_offset", 0.0, step_time)
	tween.parallel().tween_property(cam, "v_offset", 0.0, step_time)
