extends Node2D

@onready var top_left: Marker2D = find_child("TopLeft", true, false)
@onready var bottom_right: Marker2D = find_child("BottomRight", true, false)

# Tùy chọn tọa độ mặc định nếu không tìm thấy Marker2D
@export_group("Camera Limits Fallback")
@export var fallback_limit_left: int = -380
@export var fallback_limit_right: int = 2000
@export var fallback_limit_top: int = -600
@export var fallback_limit_bottom: int = 200


@export_group("Background Motion")
@export var auto_scroll_background: bool = true
@export var auto_scroll_speed: float = 15.0

@onready var parallax_bg: ParallaxBackground = find_child("ParallaxBackground", true, false)


func _ready() -> void:
	# Lưu lại màn chơi hiện tại cho tính năng CONTINUE
	if scene_file_path != "":
		SaveManager.save_last_level(scene_file_path)
	
	# Đợi 1 frame để Camera của Player khởi tạo hoàn tất
	await get_tree().process_frame
	update_camera_limits()


func _process(delta: float) -> void:
	# Cuộn nền tự động tạo chuyển động mượt mà liên tục (Slide 20_Module 4.1)
	if auto_scroll_background and parallax_bg:
		parallax_bg.scroll_offset.x += auto_scroll_speed * delta


func update_camera_limits() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if not cam:
		cam = find_child("Camera2D", true, false)
	
	if cam:
		if top_left and bottom_right:
			cam.limit_left = int(top_left.global_position.x)
			cam.limit_top = int(top_left.global_position.y)
			cam.limit_right = int(bottom_right.global_position.x)
			cam.limit_bottom = int(bottom_right.global_position.y)
		else:
			cam.limit_left = fallback_limit_left
			cam.limit_top = fallback_limit_top
			cam.limit_right = fallback_limit_right
			cam.limit_bottom = fallback_limit_bottom
