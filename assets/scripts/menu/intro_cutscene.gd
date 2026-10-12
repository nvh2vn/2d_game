class_name IntroCutscene
extends Control

## Màn mở đầu dẫn truyện (Intro Cutscene / Slideshow) phong cách Hollow Knight.
## Trình chiếu 5 khung tranh nghệ thuật kèm hiệu ứng mờ dần (Fade in/out),
## hiệu ứng Ken Burns (Pan/Zoom chậm) và nhạc nền tearcity_i.mp3.
## Hỗ trợ:
## - Chạm màn hình / Click chuột / Space / Enter: Sang khung hình kế tiếp (Next Frame on Tap).
## - Nút "BỎ QUA >>" hoặc phím ESC: Bỏ qua toàn bộ intro và vào game ngay.

@export_group("Paths & Sequences")
@export_dir var cutscene_folder: String = "res://assets/art/2d/intro cutscene/"
@export_file("*.tscn") var next_scene_path: String = "res://assets/scenes/levels/map_1.tscn"

@export_group("Timing Configuration")
## Thời gian hiển thị tối đa mỗi bức ảnh khi không chạm (giây)
@export var slide_display_time: float = 5.0
## Thời gian mờ dần khi chuyển giữa các bức ảnh (Fade In / Fade Out)
@export var fade_duration: float = 0.85
## Thời gian mờ dần khi người chơi chủ động chạm sang cảnh tiếp theo (giây)
@export var tap_advance_fade_duration: float = 0.45
## Thời gian nghỉ màn hình đen giữa 2 bức ảnh
@export var black_pause_duration: float = 0.18

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
@onready var subtitle_container: MarginContainer = get_node_or_null("%SubtitleContainer")
@onready var subtitle_label: Label = get_node_or_null("%SubtitleLabel")

@export_group("Subtitles (Phụ Đề Dẫn Truyện)")
@export var slide_subtitles: Array[String] = [
	"Tại vương quốc Pharloom xa xôi, một bài ca cổ xưa đang vẫy gọi...",
	"Bị giam cầm trong lồng sắt, kẻ lữ hành dệt tơ thức tỉnh giữa miền đất lạ.",
	"Tơ nhện quấn quanh lưỡi kim, báo hiệu cuộc trốn chạy định mệnh.",
	"Vượt qua ngàn hiểm nguy và cạm bẫy dưới đáy vực sâu...",
	"Hornet bước lên đỉnh cao, khám phá bí mật của vương quốc tơ lụa!"
]

enum SlideState {
	IDLE,
	FADING_IN,
	DISPLAYING,
	FADING_OUT,
	PAUSED_BETWEEN
}

var slide_textures: Array[Texture2D] = []
var current_slide_index: int = 0
var current_state: SlideState = SlideState.IDLE
var is_transitioning: bool = false
var can_skip: bool = false

var fade_tween: Tween = null
var auto_advance_tween: Tween = null
var ken_burns_tween: Tween = null


func _ready() -> void:
	# Đảm bảo game không bị pause từ các menu trước
	get_tree().paused = false
	
	# Khởi tạo trạng thái hiển thị ban đầu
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate.a = 0.0
	if slide_image:
		slide_image.modulate.a = 0.0
		
	# Cấu hình nút Bỏ qua
	if skip_button:
		skip_button.pressed.connect(skip_cutscene)
		_setup_skip_button_hover()
		
	# Cập nhật pivot center khi thay đổi kích thước màn hình
	resized.connect(_on_resized)
	_on_resized()
	
	# Khởi tạo nhạc nền BGM với fade in nhẹ nhàng
	_start_bgm()
	
	# Nạp danh sách hình ảnh cắt cảnh
	_load_slides()
	
	# Khoảng đệm an toàn 0.35s tránh bị tap/skip ngoài ý muốn do click từ Main Menu
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
	_update_safe_area_margins()


func _update_safe_area_margins() -> void:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var win_size: Vector2i = DisplayServer.window_get_size()
	var bottom_padding: int = 56
	if win_size.y > 0 and safe_area.size.y > 0 and safe_area.size.y < win_size.y:
		var inset_bottom: int = win_size.y - (safe_area.position.y + safe_area.size.y)
		var vp_height: float = get_viewport_rect().size.y
		var scale_ratio: float = vp_height / float(win_size.y)
		bottom_padding = maxi(56, int(56 + inset_bottom * scale_ratio))
	if subtitle_container and is_instance_valid(subtitle_container):
		subtitle_container.add_theme_constant_override("margin_bottom", bottom_padding)


# ==============================================================================
# BẮT SỰ KIỆN CHẠM / CLICK ĐỂ SANG CẢNH KẾ TIẾP (NEXT FRAME ON TAP)
# ==============================================================================

func _gui_input(event: InputEvent) -> void:
	if _handle_tap_or_key_input(event):
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _handle_tap_or_key_input(event):
		get_viewport().set_input_as_handled()


func _handle_tap_or_key_input(event: InputEvent) -> bool:
	if not can_skip or is_transitioning:
		return false
		
	# 1. Phím ESC: Bỏ qua toàn bộ intro vào game ngay
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			skip_cutscene()
			return true
			
	# 2. Bỏ qua nếu chạm/click trúng vị trí nút "BỎ QUA >>" (để nút tự xử lý skip_cutscene)
	if skip_button and is_instance_valid(skip_button) and skip_button.is_visible_in_tree():
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			var click_pos: Vector2 = event.position
			if skip_button.get_global_rect().has_point(click_pos):
				return false
				
	# 3. Nhận diện thao tác người chơi muốn sang khung ảnh tiếp theo
	var is_advance_action: bool = false
	
	# Bấm phím Space / Enter
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			is_advance_action = true
			
	# Chuột trái
	elif event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_advance_action = true
			
	# Màn hình cảm ứng Mobile
	elif event is InputEventScreenTouch and event.is_pressed():
		is_advance_action = true
		
	if is_advance_action:
		next_frame()
		return true
		
	return false


## Kích hoạt chuyển sang khung tranh kế tiếp khi người chơi chạm màn hình
func next_frame() -> void:
	if not can_skip or is_transitioning:
		return
		
	# 1. Nếu đang fade in: Hoàn tất fade in ngay lập tức để ảnh hiện rõ
	if current_state == SlideState.FADING_IN:
		if fade_tween and fade_tween.is_valid():
			fade_tween.kill()
		slide_image.modulate.a = 1.0
		if subtitle_container and subtitle_container.visible:
			subtitle_container.modulate.a = 1.0
		current_state = SlideState.DISPLAYING
		return
		
	# 2. Nếu đang trong quá trình fade out hoặc nghỉ đen giữa 2 ảnh: Bỏ qua chống spam input
	if current_state == SlideState.FADING_OUT or current_state == SlideState.PAUSED_BETWEEN:
		return
		
	# 3. Nếu đang hiển thị khung ảnh (DISPLAYING): Sang ảnh tiếp theo ngay lập tức
	if current_state == SlideState.DISPLAYING:
		_transition_to_next_slide()


# ==============================================================================
# LOGIC CHUYỂN CẢNH TRÌNH CHIẾU
# ==============================================================================

func _show_slide(index: int) -> void:
	if is_transitioning:
		return
	if index >= slide_textures.size():
		_finish_cutscene()
		return
		
	current_slide_index = index
	current_state = SlideState.FADING_IN
	_kill_active_tweens()
	
	var tex = slide_textures[index]
	slide_image.texture = tex
	slide_image.modulate.a = 0.0
	slide_image.pivot_offset = slide_image.size * 0.5
	slide_image.position = Vector2.ZERO
	slide_image.scale = Vector2.ONE
	
	# 1. Hiệu ứng Ken Burns (Pan & Zoom chậm rãi tạo chiều sâu điện ảnh)
	ken_burns_tween = create_tween()
	_apply_ken_burns(index, ken_burns_tween)
	
	# 2. Fade In từ đen lên ảnh (fade_duration = 0.85s)
	fade_tween = create_tween().set_parallel(true)
	fade_tween.tween_property(slide_image, "modulate:a", 1.0, fade_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	# 2.1 Cập nhật và Fade In phụ đề dẫn truyện (nếu có)
	if subtitle_container and subtitle_label:
		if index < slide_subtitles.size() and slide_subtitles[index] != "":
			subtitle_label.text = slide_subtitles[index]
			subtitle_container.visible = true
			subtitle_container.modulate.a = 0.0
			fade_tween.tween_property(subtitle_container, "modulate:a", 1.0, fade_duration)\
				.set_trans(Tween.TRANS_SINE)\
				.set_ease(Tween.EASE_OUT)
		else:
			subtitle_container.visible = false

	await fade_tween.finished
	
	if is_transitioning or current_slide_index != index:
		return
		
	current_state = SlideState.DISPLAYING
	
	# 3. Đếm ngược thời gian hiển thị tự động nếu người chơi không chạm
	var hold_time = maxf(0.5, slide_display_time - (fade_duration * 2.0))
	auto_advance_tween = create_tween()
	auto_advance_tween.tween_interval(hold_time)
	await auto_advance_tween.finished
	
	if is_transitioning or current_slide_index != index or current_state != SlideState.DISPLAYING:
		return
		
	# Hết giờ hiển thị tự động -> chuyển sang cảnh kế
	_transition_to_next_slide()


func _transition_to_next_slide() -> void:
	if current_state == SlideState.FADING_OUT or current_state == SlideState.PAUSED_BETWEEN:
		return
	if is_transitioning:
		return
		
	# Nếu đang ở bức ảnh cuối cùng (khung 5): Chạm sẽ kết thúc intro và vào game
	if current_slide_index >= slide_textures.size() - 1:
		_finish_cutscene()
		return
		
	current_state = SlideState.FADING_OUT
	_kill_active_tweens()
	
	# Mờ dần ảnh hiện tại (fade out mượt mà ~0.45s)
	var tw_fade_out = create_tween().set_parallel(true)
	tw_fade_out.tween_property(slide_image, "modulate:a", 0.0, tap_advance_fade_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	if subtitle_container and subtitle_container.visible:
		tw_fade_out.tween_property(subtitle_container, "modulate:a", 0.0, tap_advance_fade_duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)

	await tw_fade_out.finished
	
	if is_transitioning:
		return
		
	current_state = SlideState.PAUSED_BETWEEN
	var tw_pause = create_tween()
	tw_pause.tween_interval(black_pause_duration)
	await tw_pause.finished
	
	if is_transitioning:
		return
		
	_show_slide(current_slide_index + 1)


func _kill_active_tweens() -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	if auto_advance_tween and auto_advance_tween.is_valid():
		auto_advance_tween.kill()
	if ken_burns_tween and ken_burns_tween.is_valid():
		ken_burns_tween.kill()


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


# ==============================================================================
# BỎ QUA VÀ KẾT THÚC CUTSCENE
# ==============================================================================

func skip_cutscene() -> void:
	if not can_skip or is_transitioning:
		return
	is_transitioning = true
	_kill_active_tweens()
	
	# Màn hình fade nhanh về màu đen (0.4s) và giảm âm lượng BGM
	var tw = create_tween().set_parallel(true)
	if fade_overlay:
		tw.tween_property(fade_overlay, "modulate:a", 1.0, 0.4)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
	if subtitle_container:
		tw.tween_property(subtitle_container, "modulate:a", 0.0, 0.3)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)
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
	_kill_active_tweens()
	
	# Màn hình fade out về màu đen và giảm dần âm lượng nhạc nền
	var tw = create_tween().set_parallel(true)
	if fade_overlay:
		tw.tween_property(fade_overlay, "modulate:a", 1.0, 0.5)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
	if subtitle_container:
		tw.tween_property(subtitle_container, "modulate:a", 0.0, 0.4)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)
	if bgm_player:
		tw.tween_property(bgm_player, "volume_db", -60.0, bgm_fade_out_time)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)
			
	await tw.finished
	await get_tree().create_timer(0.2).timeout
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


# ==============================================================================
# TIỆN ÍCH & NẠP TÀI NGUYÊN
# ==============================================================================

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
	
	# 1. Quét động từ thư mục cutscene_folder
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
		
	# 2. Fallback tĩnh nếu quét thư mục rỗng
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
