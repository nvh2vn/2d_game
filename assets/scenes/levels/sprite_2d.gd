extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var cam: Camera2D = get_node_or_null("PlayerController/CameraOffset/Camera2D")
	if not cam and owner:
		cam = owner.find_child("Camera2D", true, false)
	if not cam:
		cam = get_viewport().get_camera_2d()
	
	if cam:
		cam.limit_left = -200    # Tường trái
		cam.limit_right = 2000   # Tường phải
		cam.limit_top = -600     # Trần nhà
		cam.limit_bottom = 200   # Mép sàn


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
