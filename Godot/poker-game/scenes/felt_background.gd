class_name FeltBackground
extends ColorRect
## Full-screen green card-table felt (see felt.gdshader), shared by every screen.

const FELT_SHADER := preload("res://scenes/felt.gdshader")


func _init() -> void:
	color = Color(0.09, 0.35, 0.2)  # fallback if shaders are unavailable
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = FELT_SHADER
	shader_material.set_shader_parameter("base_color", color)
	material = shader_material
