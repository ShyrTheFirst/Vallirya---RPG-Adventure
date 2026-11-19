class_name ItemDropEffect
extends Node3D

@onready var beam_particles: GPUParticles3D = $BeamParticles
@onready var base_ring: MeshInstance3D = $BaseRingMesh
@onready var sparkles: GPUParticles3D = $Sparkles

# Mapeamento de cores baseado no enum ItemData.Rarity
const RARITY_COLORS = {
	ItemData.Rarity.COMMON: Color(0.9, 0.9, 0.9, 1.0),      # Branco / Cinza claro
	ItemData.Rarity.UNCOMMON: Color(0.1, 0.9, 0.2, 1.0),   # Verde
	ItemData.Rarity.RARE: Color(0.2, 0.6, 1.0, 1.0),       # Azul
	ItemData.Rarity.EPIC: Color(0.8, 0.2, 1.0, 1.0),       # Roxo
	ItemData.Rarity.LEGENDARY: Color(1.0, 0.6, 0.1, 1.0)   # Laranja / Dourado
}

func setup_rarity(rarity_value: ItemData.Rarity) -> void:
	var selected_color = RARITY_COLORS.get(rarity_value, RARITY_COLORS[ItemData.Rarity.COMMON])
	
	# Aplica a cor nas partículas do feixe vertical
	if beam_particles and beam_particles.process_material is ParticleProcessMaterial:
		# Duplica o process_material para que partículas de drops diferentes não compartilhem a mesma cor
		beam_particles.process_material = beam_particles.process_material.duplicate()
		var mat = beam_particles.process_material as ParticleProcessMaterial
		mat.color = selected_color
		
	# Aplica a cor nas partículas de brilho (sparkles)
	if sparkles and sparkles.process_material is ParticleProcessMaterial:
		sparkles.process_material = sparkles.process_material.duplicate()
		var s_mat = sparkles.process_material as ParticleProcessMaterial
		s_mat.color = selected_color

	# Aplica a cor no material do Shader do anel da base de forma isolada
	if base_ring:
		var ring_mat = base_ring.get_surface_override_material(0)
		if ring_mat and ring_mat is ShaderMaterial:
			# --- O PULO DO GATO ---
			# Duplica o material do shader para que ele seja exclusivo deste item específico!
			var unique_mat = ring_mat.duplicate() as ShaderMaterial
			base_ring.set_surface_override_material(0, unique_mat)
			
			unique_mat.set_shader_parameter("aura_color", selected_color)

	# Animação rápida de escala do anel abrindo (efeito de impacto)
	base_ring.scale = Vector3(0.1, 0.1, 0.1)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(base_ring, "scale", Vector3(1.5, 1.5, 1.5), 0.4).from(Vector3(0.2, 0.2, 0.2))
