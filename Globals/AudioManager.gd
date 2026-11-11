extends Node

# Os nomes aqui devem ser IDÊNTICOS aos nomes dos barramentos no seu painel de áudio do Godot
const BUS_MASTER: String = "Master"
const BUS_BGM: String = "BGM"
const BUS_ENEMY_SFX: String = "Enemy Player SFX"
const BUS_WORLD_SFX: String = "World SFX"

# Função universal para ajustar o volume de qualquer barramento via slider (valor de 0.0 a 1.0)
func set_bus_volume(bus_name: String, value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		print("[AUDIO MANAGER] Erro: Barramento '%s' não encontrado!" % bus_name)
		return

	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		# linear_to_db converte a escala de 0.0-1.0 para decibéis de forma auditiva natural
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

# Funções auxiliares específicas para cada slider chamar diretamente
func set_master_volume(value: float) -> void:
	set_bus_volume(BUS_MASTER, value)

func set_music_volume(value: float) -> void:
	set_bus_volume(BUS_BGM, value)

func set_enemy_sfx_volume(value: float) -> void:
	set_bus_volume(BUS_ENEMY_SFX, value)

func set_world_sfx_volume(value: float) -> void:
	set_bus_volume(BUS_WORLD_SFX, value)
