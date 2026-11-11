extends Control #################################################################

@onready var slider_master: HSlider = $Panel/VBoxContainer/SliderMaster
@onready var slider_bgm: HSlider = $Panel/VBoxContainer/SliderBGM
@onready var slider_enemy_sfx: HSlider = $Panel/VBoxContainer/SliderEnemySFX
@onready var slider_world_sfx: HSlider = $Panel/VBoxContainer/SliderWorldSFX

func _ready() -> void:
	# Configura o valor padrão dos sliders (máximo 1.0, mínimo 0.0, step 0.01)
	for slider in [slider_master, slider_bgm, slider_enemy_sfx, slider_world_sfx]:
		if slider:
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.01
			slider.value = 1.0 # Começa no talo por padrão

	# Conecta o sinal de arrastar a barra diretamente ao AudioManager em tempo real
	if slider_master:
		slider_master.value_changed.connect(AudioManager.set_master_volume)
	if slider_bgm:
		slider_bgm.value_changed.connect(AudioManager.set_music_volume)
	if slider_enemy_sfx:
		slider_enemy_sfx.value_changed.connect(AudioManager.set_enemy_sfx_volume)
	if slider_world_sfx:
		slider_world_sfx.value_changed.connect(AudioManager.set_world_sfx_volume)
