extends Control

@export_file("*.tscn") var next_scene_path: String = "res://assets/scenes/menu/main_menu.tscn"
@onready var background: TextureRect = $Background

var is_transitioning: bool = false


func _ready() -> void:
	# Khởi tạo toàn bộ màn hình ở độ mờ 0
	modulate.a = 0.0
	start_splash_sequence()


func _unhandled_input(event: InputEvent) -> void:
	# Bấm bất kỳ phím nào hoặc chuột để bỏ qua Splash Screen
	if not is_transitioning and (event is InputEventKey or event is InputEventMouseButton):
		if event.is_pressed():
			skip_splash()


func start_splash_sequence() -> void:
	is_transitioning = true
	var tween = create_tween()
	
	# Fade In Splash Screen (0.8 giây)
	tween.tween_property(self, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Giữ màn hình hiển thị (1.2 giây)
	tween.tween_interval(1.2)
	
	# Fade Out Splash Screen (0.6 giây)
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Đợi hoàn tất và chuyển scene
	await tween.finished
	go_to_main_menu()


func skip_splash() -> void:
	is_transitioning = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween.finished
	go_to_main_menu()


func go_to_main_menu() -> void:
	if next_scene_path != "":
		get_tree().change_scene_to_file(next_scene_path)
