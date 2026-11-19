extends MeshInstance3D

func _ready() -> void:
	# 1. Duplica o material para que esta nuvem seja 100% independente das outras
	var mat = get_surface_override_material(0)
	if not mat:
		mat = get_mesh().surface_get_material(0)
	
	if mat and mat is ShaderMaterial:
		var unique_mat = mat.duplicate() as ShaderMaterial
		set_surface_override_material(0, unique_mat)
		
		# 2. Se a textura do Noise for um NoiseTexture3D ou NoiseTexture2D:
		var noise_tex = unique_mat.get_shader_parameter("noise_texture")
		if noise_tex and noise_tex is NoiseTexture2D:
			# Cria uma cópia única do ruído para esta nuvem
			var unique_noise_tex = noise_tex.duplicate() as NoiseTexture2D
			var noise = unique_noise_tex.noise
			if noise and noise is FastNoiseLite:
				# Duplica o FastNoiseLite e muda a Semente (Seed) aleatoriamente!
				var unique_noise = noise.duplicate() as FastNoiseLite
				unique_noise.seed = randi() # Semente totalmente aleatória!
				unique_noise_tex.noise = unique_noise
			
			unique_mat.set_shader_parameter("noise_texture", unique_noise_tex)

		var rand_scale = randf_range(-1.0, 1.1)
		scale += Vector3(rand_scale, rand_scale, rand_scale)
