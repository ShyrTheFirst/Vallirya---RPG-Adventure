extends Label3D

func setup(value: Variant, custom_color: Color = Color.WHITE) -> void:
	text = str(value)
	modulate = custom_color

	var tween = create_tween()
	tween.set_parallel(true)
	
	# Sobe suavemente
	tween.tween_property(self, "position:y", position.y + 0.8, 0.7)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Fade-out da transparência
	tween.tween_property(self, "modulate:a", 0.0, 0.7)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Destrói o nó ao terminar
	tween.chain().tween_callback(queue_free)
