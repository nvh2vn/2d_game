class_name IntroCutscene
extends Control

## Màn mở đầu dẫn truyện (Intro Cutscene / Slideshow) phong cách Hollow Knight.
## Trình chiếu 5 khung tranh nghệ thuật kèm hiệu ứng mờ dần (Fade in/out),
## hiệu ứng Ken Burns (Pan/Zoom chậm) và nhạc nền tearcity_i.mp3.
## Hỗ trợ nút Bỏ qua (Skip / Touch / Key) và chuyển cảnh sang Map khởi đầu.

@export_group("Paths & Sequences")
@export_dir var cutscene_folder: String = "res://assets/art/2d/intro cutscene/"
@export_file("*.tscn") var next_scene_path: String = "res://assets/scenes/levels/map_1.tscn"

@export_group("Timing Configuration")
## Thời gian hiển thị mỗi bức ảnh (giây) - chuẩn Hollow Knight (4.5s - 5.5s)
@export var slide_display_time: float = 5.0
## Thời gian mờ dần khi chuyển giữa các bức ảnh (Fade In / Fade Out)
@export var fade_duration: float = 0.85
## Thời gian nghỉ màn hình đen giữa 2 bức ảnh
@export var black_pause_duration: float = 0.2

@export_group("Audio")
@export var bgm_stream: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/tearcity_i.mp3")
@export var bgm_volume_db: float = 0.0
@export var bgm_fade_in_time: float = 1.2
@export var bgm_fade_out_time: float = 0.5

@onready var bg_color: ColorRect = %BackgroundColor
@onready var slide_image: TextureRect = %SlideImage
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var bgm_player: AudioStreamPlayer = %BGMPlayer
@onready var skip_container: MarginContainer = %SkipContainer
@onready var skip_button: Button = %SkipButton
@onready var skip_hint_label: Label = %SkipHintLabel

var slide_textures: Array[Texture2D] = []
var current_slide_index: int = 0
var current_tween: Tween = null
var is_transitioning: bool = false
var can_skip: bool = false


func _ready() -> void:
	# Đảm bảo game không bị pause từ các menu trước
	get_tree().paused = false
	
	# Khởi tạo trạng thái ban đầu của màn hình
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate.a = 0.0
	if slide_image:
		slide_image.modulate.a = 0.0
		
	# Cấu hình nút Skip
	if skip_button:
		skip_button.pressed.connect(skip_cutscene)
		_setup_skip_button_hover()
		
	# Cập nhật pivot center khi thay đổi kích thước cửa sổ
	resized.connect(_on_resized)
	_on_resized()
	
	# Khởi tạo nhạc nền BGM với fade in nhẹ nhàng
	_start_bgm()
	
	# Nạp danh sách hình ảnh cắt cảnh
	_load_slides()
	
	# Khoảng đệm an toàn 0.35s tránh bị skip ngoài ý muốn do click từ Main Menu
	get_tree().create_timer(0.35).timeout.connect(func():
		can_skip = true
	)
	
	# Bắt đầu trình chiếu slideshow
	if not slide_textures.is_empty():
		_show_slide(0)
	else:
		push_warning("[IntroCutscene] Không tìm thấy ảnh trong: " + cutscene_folder)
		_finish_cutscene()


func _on_resized() -> void:
	if slide_image and is_instance_valid(slide_image):
		slide_image.pivot_offset = slide_image.size * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if not can_skip or is_transitioning:
		return
	# Phím bấm bất kỳ trên bàn phím, click chuột, hoặc chạm cảm ứng đều cho phép bỏ qua
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		if event is InputEventKey and event.is_echo():
			return
		skip_cutscene()


func _start_bgm() -> void:
	if not bgm_player:
		return
	bgm_player.bus = &"Music"
	if bgm_stream:
		bgm_player.stream = bgm_stream
		if bgm_player.stream is AudioStreamMP3:
			bgm_player.stream.loop = true
	
	bgm_player.volume_db = -40.0
	bgm_player.play()
	
	var tw = create_tween()
	tw.tween_property(bgm_player, "volume_db", bgm_volume_db, bgm_fade_in_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _load_slides() -> void:
	slide_textures.clear()
	var loaded_paths: Array[String] = []
	
	# 1. Thử quét động từ thư mục cutscene_folder
	var dir = DirAccess.open(cutscene_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and not file_name.ends_with(".import"):
				var ext = file_name.get_extension().to_lower()
				if ext in ["png", "jpg", "jpeg", "webp"]:
					loaded_paths.append(cutscene_folder.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
		
		# Sắp xếp thứ tự tự nhiên (1.png, 2.png, ..., 5.png)
		loaded_paths.sort_custom(func(a: String, b: String) -> bool:
			var a_num = a.get_file().get_basename()
			var b_num = b.get_file().get_basename()
			if a_num.is_valid_int() and b_num.is_valid_int():
				return a_num.to_int() < b_num.to_int()
			return a < b
		)
		
	# 2. Fallback đường dẫn tĩnh nếu quét thư mục rỗng
	if loaded_paths.is_empty():
		for i in range(1, 6):
			var fallback_path = cutscene_folder.path_join("%d.png" % i)
			if ResourceLoader.exists(fallback_path):
				loaded_paths.append(fallback_path)
				
	# 3. Nạp tài nguyên Texture2D
	for path in loaded_paths:
		var tex = load(path) as Texture2D
		if tex:
			slide_textures.append(tex)
			
	print("[IntroCutscene] Loaded %d slide frames for cutscene." % slide_textures.size())


func _show_slide(index: int) -> void:
	if is_transitioning:
		return
	if index >= slide_textures.size():
		_finish_cutscene()
		return
		
	current_slide_index = index
	var tex = slide_textures[index]
	slide_image.texture = tex
	slide_image.modulate.a = 0.0
	slide_image.pivot_offset = slide_image.size * 0.5
	slide_image.position = Vector2.ZERO
	slide_image.scale = Vector2.ONE
	
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	current_tween = create_tween()
	
	# --- 1. Hiệu ứng Ken Burns (Pan & Zoom chậm tạo cảm giác điện ảnh) ---
	_apply_ken_burns(index, current_tween)
	
	# --- 2. Chu kỳ sáng / tối (Fade In -> Hold -> Fade Out) ---
	# Fade In từ đen lên ảnh (0.85s)
	current_tween.parallel().tween_property(slide_image, "modulate:a", 1.0, fade_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
		
	# Thời gian giữ ảnh rõ ràng
	var hold_time = maxf(0.5, slide_display_time - (fade_duration * 2.0))
	current_tween.tween_interval(hold_time)
	
	# Fade Out về màu đen mượt mà (0.85s)
	current_tween.tween_property(slide_image, "modulate:a", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
		
	await current_tween.finished
	if is_transitioning:
		return
		
	# Nếu còn ảnh tiếp theo, dừng 0.2s trong bóng tối rồi chuyển tiếp
	if index + 1 < slide_textures.size():
		await get_tree().create_timer(black_pause_duration).timeout
		if is_transitioning:
			return
		_show_slide(index + 1)
	else:
		_finish_cutscene()


func _apply_ken_burns(index: int, tw: Tween) -> void:
	var style = index % 5
	match style:
		0:
			# Khung 1: Zoom in nhẹ nhàng từ 1.0 lên 1.045
			slide_image.scale = Vector2.ONE
			slide_image.position = Vector2.ZERO
			tw.parallel().tween_property(slide_image, "scale", Vector2(1.045, 1.045), slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		1:
			# Khung 2: Bắt đầu hơi phóng to và thu về 1.0, lướt chậm lên trên
			slide_image.scale = Vector2(1.045, 1.045)
			slide_image.position = Vector2.ZERO
			tw.parallel().tween_property(slide_image, "scale", Vector2.ONE, slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.parallel().tween_property(slide_image, "position:y", -10.0, slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		2:
			# Khung 3: Zoom in 1.0 lên 1.05, lướt nhẹ sang phải
			slide_image.scale = Vector2.ONE
			slide_image.position = Vector2.ZERO
			tw.parallel().tween_property(slide_image, "scale", Vector2(1.05, 1.05), slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.parallel().tween_property(slide_image, "position:x", 12.0, slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		3:
			# Khung 4: Thu nhỏ nhẹ nhàng 1.04 về 1.0, lướt chậm xuống dưới
			slide_image.scale = Vector2(1.04, 1.04)
			slide_image.position = Vector2.ZERO
			tw.parallel().tween_property(slide_image, "scale", Vector2.ONE, slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.parallel().tween_property(slide_image, "position:y", 10.0, slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		4:
			# Khung 5 (Đỉnh điểm): Zoom in kịch tính từ 1.0 lên 1.055
			slide_image.scale = Vector2.ONE
			slide_image.position = Vector2.ZERO
			tw.parallel().tween_property(slide_image, "scale", Vector2(1.055, 1.055), slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func skip_cutscene() -> void:
	if not can_skip or is_transitioning:
		return
	is_transitioning = true
	
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		
	# Màn hình fade nhanh về màu đen (0.4s) và giảm âm lượng BGM
	var tw = create_tween().set_parallel(true)
	if fade_overlay:
		tw.tween_property(fade_overlay, "modulate:a", 1.0, 0.4)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
	if bgm_player:
		tw.tween_property(bgm_player, "volume_db", -60.0, 0.4)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)
			
	await tw.finished
	_go_to_gameplay()


func _finish_cutscene() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	
	# Màn hình đã đen sẵn sau frame cuối; giảm dần âm lượng nhạc nền
	if bgm_player:
		var tw = create_tween()
		tw.tween_property(bgm_player, "volume_db", -60.0, bgm_fade_out_time)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)
			
	# Khoảng nghỉ ngắn 0.35s trong bóng tối trước khi nạp thế giới game
	await get_tree().create_timer(0.35).timeout
	_go_to_gameplay()


func _go_to_gameplay() -> void:
	if bgm_player and bgm_player.playing:
		bgm_player.stop()
		
	get_tree().paused = false
	
	var target_scene = next_scene_path
	if target_scene == "" or not ResourceLoader.exists(target_scene):
		target_scene = "res://assets/scenes/levels/map_1.tscn"
		
	print("[IntroCutscene] Transitioning to starting level: ", target_scene)
	get_tree().change_scene_to_file(target_scene)


func _setup_skip_button_hover() -> void:
	if not skip_button:
		return
	skip_button.mouse_entered.connect(func():
		var tw = create_tween()
		tw.tween_property(skip_button, "modulate", Color(1.3, 1.3, 1.2, 1.0), 0.1)
	)
	skip_button.mouse_exited.connect(func():
		var tw = create_tween()
		tw.tween_property(skip_button, "modulate", Color.WHITE, 0.15)
	)
