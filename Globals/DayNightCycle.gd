class_name DayNightCycle
extends Node

@export_category("Configurações do Tempo")
@export var day_duration_seconds: float = 120.0 
@export var directional_light: DirectionalLight3D
@export var world_environment: WorldEnvironment

var time_progress: float = 0.25 

# Variáveis para armazenar as cores atuais e fazer a interpolação suave (lerp)
var current_top_col: Color = Color.BLACK
var current_hor_col: Color = Color.BLACK
var current_light_col: Color = Color.BLACK
var current_ambient_col: Color = Color.BLACK
var current_cloud_col: Color = Color.BLACK

func _process(delta: float) -> void:
	if day_duration_seconds <= 0.0: return
	
	time_progress += delta / day_duration_seconds
	if time_progress >= 1.0:
		time_progress = 0.0 
		
	update_celestial_bodies(delta)

func update_celestial_bodies(delta: float) -> void:
	if not directional_light: return
	
	var sun_angle = time_progress * TAU
	directional_light.rotation.x = sun_angle - PI / 2.0
	
	var sun_height = sin(sun_angle)
	
	# Mantém a luz direcional fraca à noite (simulando a Lua) em vez de apagar 100%
	if sun_height < -0.05:
		directional_light.light_energy = 0.25 # Luar suave para iluminar o cenário
	else:
		directional_light.light_energy = clamp(sun_height * 1.2, 0.1, 1.2)
		
	update_lighting_and_atmosphere(sun_height, delta)

func update_lighting_and_atmosphere(sun_height: float, delta: float) -> void:
	if not world_environment or not world_environment.environment: return
	
	var env = world_environment.environment
	var sky_material = env.sky.sky_material as ShaderMaterial
	if not sky_material: return
	
	var target_top: Color
	var target_hor: Color
	var target_light: Color
	var target_ambient: Color
	var target_cloud: Color
	
	# Define as cores-alvo dependendo da altura do sol (com faixas de transição suaves)
	if sun_height > 0.15:
		# --- DIA ---
		target_top = Color(0.15, 0.45, 0.85)
		target_hor = Color(0.5, 0.7, 0.95)
		target_light = Color(1.0, 0.98, 0.9)
		target_ambient = Color(0.4, 0.5, 0.6) # Luz ambiente clara do dia
		target_cloud = Color(0.95, 0.98, 1.0, 0.85)
		
	elif sun_height <= 0.15 and sun_height >= -0.15:
		# --- AMANHECER / PÔR DO SOL (Transição) ---
		target_top = Color(0.35, 0.2, 0.4)
		target_hor = Color(0.9, 0.45, 0.2)
		target_light = Color(1.0, 0.55, 0.2)
		target_ambient = Color(0.3, 0.2, 0.25)
		target_cloud = Color(1.0, 0.7, 0.4, 0.75)
		
	else:
		# --- NOITE (Ajustada para ter boa visibilidade e jogabilidade) ---
		target_top = Color(0.05, 0.08, 0.18)      # Azul escuro suave no topo
		target_hor = Color(0.15, 0.22, 0.35)      # Horizonte mais claro para recortar o cenário
		target_light = Color(0.3, 0.4, 0.6)       # Luar azulado mais forte para iluminar os monstros e árvores
		target_ambient = Color(0.25, 0.3, 0.42)   # Luz ambiente generosa para enxergar caminhos e inimigos
		target_cloud = Color(0.2, 0.25, 0.38, 0.4)# Nuvens discretas e visíveis à noite

	# Se for o primeiro frame, inicializa as cores
	if current_top_col == Color.BLACK:
		current_top_col = target_top
		current_hor_col = target_hor
		current_light_col = target_light
		current_ambient_col = target_ambient
		current_cloud_col = target_cloud

	# --- INTERPOLAÇÃO SUAVE (LERP) ---
	# O delta * 0.5 define a velocidade da transição de cor (quanto maior, mais rápido)
	var lerp_speed = delta * 0.8
	current_top_col = current_top_col.lerp(target_top, lerp_speed)
	current_hor_col = current_hor_col.lerp(target_hor, lerp_speed)
	current_light_col = current_light_col.lerp(target_light, lerp_speed)
	current_ambient_col = current_ambient_col.lerp(target_ambient, lerp_speed)
	current_cloud_col = current_cloud_col.lerp(target_cloud, lerp_speed)

	# Aplica os valores suavizados no ambiente, luz e shader
	directional_light.light_color = current_light_col
	env.ambient_light_color = current_ambient_col
	
	sky_material.set_shader_parameter("sky_top_color", current_top_col)
	sky_material.set_shader_parameter("sky_horizon_color", current_hor_col)
	sky_material.set_shader_parameter("ground_bottom_color", current_top_col)
	sky_material.set_shader_parameter("ground_horizon_color", current_hor_col)
	sky_material.set_shader_parameter("cloud_color", current_cloud_col)
