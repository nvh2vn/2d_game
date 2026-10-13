class_name OutroCutscene
extends Control

## Màn kết thúc dẫn truyện (Outro Cutscene / Slideshow) phong cách Hollow Knight.
## Trình chiếu 3 khung tranh nghệ thuật sau khi tiêu diệt Boss Soul Master:
## - outro_1.png: Đánh bại ác ma, kết thúc trận chiến định mệnh.
## - outro_2.png: Vương quốc được giải thoát, các linh hồn tìm lại tự do.
## - outro_3.png: Nhân vật nhìn về chân trời mới, hành trình tiếp diễn.
## Kèm hiệu ứng Ken Burns (Pan/Zoom chậm), Crossfade mượt mà, BGM tearcity_o.mp3,
## xử lý Safe Area cho Android, nút "BỎ QUA >>" và màn hình kết thúc "THE END".

@export_group("Paths & Sequences")
@export_dir var cutscene_folder: String = "res://assets/art/2d/outro cutscene/"
@export_file("*.tscn") var main_menu_path: String = "res://assets/scenes/menu/main_menu.tscn"

@export_group("Timing Configuration")
## Thời gian hiển thị tối đa mỗi bức ảnh khi không chạm (giây)
@export var slide_display_time: float = 6.0
## Thời gian mờ dần khi chuyển giữa các bức ảnh (Fade In / Fade Out)
@export var fade_duration: float = 0.9
## Thời gian mờ dần khi người chơi chủ động chạm sang cảnh tiếp theo (giây)
@export var tap_advance_fade_duration: float = 0.5
## Thời gian nghỉ màn hình đen giữa 2 bức ảnh
@export var black_pause_duration: float = 0.25

@export_group("Audio")
@export var bgm_stream: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/tearcity_o.mp3")
@export var bgm_volume_db: float = 0.0
@export var bgm_fade_in_time: float = 1.4
@export var bgm_fade_out_time: float = 0.7

@export_group("Subtitles (Phụ Đề Dẫn Truyện)")
@export var slide_subtitles: Array[String] = [
	"Ác mộng sâu thẳm tan biến khi Bậc Thầy Linh Hồn gục ngã. Tiếng thét của sự bất tử giả tạo lịm dần vào cõi hư vô...",
	"Những dòng linh hồn bị cầm tù bấy lâu nay tìm lại tự do, thắp sáng màn đêm tăm tối từng bao phủ khắp cõi Pharloom...",
	"Lưỡi kim lại tra vào vỏ, kẻ dệt tơ bước tiếp trên con đường vô định. Một hành trình khép lại, nhưng truyền kỳ chỉ mới bắt đầu."
]

@onready var bg_color: ColorRect = %BackgroundColor
@onready var slide_image: TextureRect = %SlideImage
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var bgm_player: AudioStreamPlayer = %BGMPlayer
@onready var skip_container: MarginContainer = %SkipContainer
@onready var skip_button: Button = %SkipButton
@onready var subtitle_container: MarginContainer = get_node_or_null("%SubtitleContainer")
@onready var subtitle_label: Label = get_node_or_null("%SubtitleLabel")
@onready var the_end_container: Control = get_node_or_null("%TheEndContainer")
@onready var the_end_label: Label = get_node_or_null("%TheEndLabel")
@onready var thank_you_label: Label = get_node_or_null("%ThankYouLabel")
@onready var return_menu_button: Button = get_node_or_null("%ReturnMenuButton")

enum SlideState {
	IDLE,
	FADING_IN,
	DISPLAYING,
	FADING_OUT,
	PAUSED_BETWEEN,
	THE_END
}

var slide_textures: Array[Texture2D] = []
var current_slide_index: int = 0
var current_state: SlideState = SlideState.IDLE
var is_transitioning: bool = false
var can_input: bool = false

var fade_tween: Tween = null
var auto_advance_tween: Tween = null
var ken_burns_tween: Tween = null


func _ready() -> void:
	# Đảm bảo bỏ trạng thái pause game nếu có
	get_tree().paused = false
	
	# Khởi tạo trạng thái giao diện ban đầu
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate.a = 0.0
	if slide_image:
		slide_image.modulate.a = 0.0
	if the_end_container:
		the_end_container.visible = false
		the_end_container.modulate.a = 0.0
		
	# Cấu hình nút Bỏ qua
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
		_setup_button_hover(skip_button)
		
	# Cấu hình nút Về Menu Chính
	if return_menu_button:
		return_menu_button.pressed.connect(_on_return_menu_pressed)
		_setup_button_hover(return_menu_button)
		
	# Cập nhật padding Safe Area cho màn hình điện thoại
	resized.connect(_on_resized)
	_on_resized()
	
	# Bắt đầu phát BGM outro với fade in nhẹ nhàng
	_start_bgm()
	
	# Nạp 3 hình ảnh cắt cảnh outro
	_load_slides()
	
	# Khoảng đệm an toàn 0.4s tránh bị double-tap ngoài ý muốn từ màn đánh Boss
	get_tree().create_timer(0.4).timeout.connect(func():
		can_input = true
	)
	
	# Bắt đầu trình chiếu slideshow
	if not slide_textures.is_empty():
		_show_slide(0)
	else:
		push_warning("[OutroCutscene] Không tìm thấy ảnh outro trong: " + cutscene_folder)
		_show_the_end_screen()


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
# XỬ LÝ SỰ KIỆN NHẬP (TAP / CLICK / KEYBOARD)
# ==============================================================================

func _gui_input(event: InputEvent) -> void:
	if _handle_tap_or_key_input(event):
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _handle_tap_or_key_input(event):
		get_viewport().set_input_as_handled()


func _handle_tap_or_key_input(event: InputEvent) -> bool:
	if not can_input or is_transitioning:
		return false
		
	# Nếu đang ở màn hình THE END thì không nhận chạm để chuyển slide nữa
	if current_state == SlideState.THE_END:
		return false
		
	# 1. Phím ESC: Bỏ qua trực tiếp tới màn hình kết thúc
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			_on_skip_pressed()
			return true
			
	# 2. Bỏ qua nếu chạm/click trúng vị trí nút "BỎ QUA >>"
	if skip_button and is_instance_valid(skip_button) and skip_button.is_visible_in_tree():
		if event is InputEventMouseButton or event is InputEventScreenTouch:
			var click_pos: Vector2 = event.position
			if skip_button.get_global_rect().has_point(click_pos):
				return false
				
	# 3. Nhận diện thao tác muốn chuyển sang cảnh tiếp theo
	var is_advance_action: bool = false
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_W, KEY_UP]:
			is_advance_action = true
	elif event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		is_advance_action = true
	elif event is InputEventScreenTouch and event.is_pressed():
		is_advance_action = true
		
	if is_advance_action:
		next_frame()
		return true
		
	return false


func next_frame() -> void:
	if not can_input or is_transitioning:
		return
		
	# 1. Nếu đang fade in: Hoàn tất fade in ngay lập tức
	if current_state == SlideState.FADING_IN:
		if fade_tween and fade_tween.is_valid():
			fade_tween.kill()
		slide_image.modulate.a = 1.0
		if subtitle_container and subtitle_container.visible:
			subtitle_container.modulate.a = 1.0
		current_state = SlideState.DISPLAYING
		return
		
	# 2. Nếu đang trong quá trình fade out hoặc nghỉ đen giữa 2 ảnh: Chờ xong
	if current_state == SlideState.FADING_OUT or current_state == SlideState.PAUSED_BETWEEN:
		return
		
	# 3. Nếu đang hiển thị khung ảnh (DISPLAYING): Sang ảnh tiếp theo
	if current_state == SlideState.DISPLAYING:
		_transition_to_next_slide()


# ==============================================================================
# LOGIC TRÌNH CHIẾU SLIDESHOW & KEN BURNS EFFECT
# ==============================================================================

func _show_slide(index: int) -> void:
	if is_transitioning:
		return
	if index >= slide_textures.size():
		_show_the_end_screen()
		return
		
	current_slide_index = index
	current_state = SlideState.FADING_IN
	_kill_active_tweens()
	
	var tex: Texture2D = slide_textures[index]
	slide_image.texture = tex
	slide_image.modulate.a = 0.0
	slide_image.pivot_offset = slide_image.size * 0.5
	slide_image.position = Vector2.ZERO
	slide_image.scale = Vector2.ONE
	
	# 1. Hiệu ứng Ken Burns (Pan & Zoom chậm rãi)
	ken_burns_tween = create_tween()
	_apply_ken_burns(index, ken_burns_tween)
	
	# 2. Fade In từ đen lên ảnh
	fade_tween = create_tween().set_parallel(true)
	fade_tween.tween_property(slide_image, "modulate:a", 1.0, fade_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	# 2.1 Cập nhật và Fade In phụ đề dẫn truyện
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
	
	# 3. Đếm ngược tự động nếu người chơi không chạm
	var hold_time: float = maxf(1.0, slide_display_time - (fade_duration * 2.0))
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
		
	# Nếu đang ở bức ảnh thứ 3 (ảnh cuối cùng): Chuyển sang màn hình THE END
	if current_slide_index >= slide_textures.size() - 1:
		_show_the_end_screen()
		return
		
	current_state = SlideState.FADING_OUT
	_kill_active_tweens()
	
	# Mờ dần ảnh hiện tại (fade out mượt mà)
	var tw_fade_out: Tween = create_tween().set_parallel(true)
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
	var tw_pause: Tween = create_tween()
	tw_pause.tween_interval(black_pause_duration)
	await tw_pause.finished
	
	if is_transitioning:
		return
		
	_show_slide(current_slide_index + 1)


func _apply_ken_burns(index: int, tw: Tween) -> void:
	var style: int = index % 3
	match style:
		0:
			# Ảnh 1 (Hạ gục Boss): Phóng to nhẹ nhàng tạo sự kịch tính
			slide_image.scale = Vector2.ONE
			slide_image.position = Vector2.ZERO
			tw.parallel().tween_property(slide_image, "scale", Vector2(1.05, 1.05), slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		1:
			# Ảnh 2 (Linh hồn tự do): Thu phóng từ 1.05 về 1.01, lướt chậm sang phải
			slide_image.scale = Vector2(1.05, 1.05)
			slide_image.position = Vector2.ZERO
			tw.parallel().tween_property(slide_image, "scale", Vector2(1.01, 1.01), slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.parallel().tween_property(slide_image, "position:x", 12.0, slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		2:
			# Ảnh 3 (Chân trời mới): Zoom in chậm từ 1.0 lên 1.06, lướt nhẹ lên cao
			slide_image.scale = Vector2.ONE
			slide_image.position = Vector2.ZERO
			tw.parallel().tween_property(slide_image, "scale", Vector2(1.06, 1.06), slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.parallel().tween_property(slide_image, "position:y", -14.0, slide_display_time)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_active_tweens() -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	if auto_advance_tween and auto_advance_tween.is_valid():
		auto_advance_tween.kill()
	if ken_burns_tween and ken_burns_tween.is_valid():
		ken_burns_tween.kill()


# ==============================================================================
# MÀN HÌNH KẾT MÀN (THE END SCREEN)
# ==============================================================================

func _on_skip_pressed() -> void:
	if is_transitioning or current_state == SlideState.THE_END:
		return
	_show_the_end_screen()


func _show_the_end_screen() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	current_state = SlideState.THE_END
	_kill_active_tweens()
	
	# 1. Ẩn nút Bỏ qua
	if skip_container:
		var skip_tw: Tween = create_tween()
		skip_tw.tween_property(skip_container, "modulate:a", 0.0, 0.3)
		
	# 2. Fade Out ảnh và phụ đề về màn hình đen
	var fade_tw: Tween = create_tween().set_parallel(true)
	if slide_image:
		fade_tw.tween_property(slide_image, "modulate:a", 0.0, 0.7)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if subtitle_container:
		fade_tw.tween_property(subtitle_container, "modulate:a", 0.0, 0.5)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_tw.finished
	
	await get_tree().create_timer(0.4).timeout
	
	# 3. Hiển thị màn hình kết màn THE END
	if the_end_container:
		the_end_container.visible = true
		the_end_container.modulate.a = 0.0
		
		# Hiệu ứng Fade In và Scale nhẹ nhõm cho THE END
		var end_tw: Tween = create_tween()
		end_tw.tween_property(the_end_container, "modulate:a", 1.0, 1.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			
		if the_end_label:
			the_end_label.scale = Vector2(0.92, 0.92)
			var scale_tw: Tween = create_tween()
			scale_tw.tween_property(the_end_label, "scale", Vector2.ONE, 1.5)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				
	is_transitioning = false


func _on_return_menu_pressed() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	
	print("[OutroCutscene] Người chơi chọn Về Menu Chính.")
	
	# 1. Fade out BGM và màn hình về đen
	var exit_tw: Tween = create_tween().set_parallel(true)
	if bgm_player:
		exit_tw.tween_property(bgm_player, "volume_db", -60.0, bgm_fade_out_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate.a = 0.0
		exit_tw.tween_property(fade_overlay, "modulate:a", 1.0, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			
	await exit_tw.finished
	
	if bgm_player and bgm_player.playing:
		bgm_player.stop()
		
	get_tree().paused = false
	
	var target: String = main_menu_path
	if not ResourceLoader.exists(target):
		target = "res://assets/scenes/menu/main_menu.tscn"
		
	get_tree().change_scene_to_file(target)


# ==============================================================================
# QUẢN LÝ TÀI NGUYÊN & ÂM THANH
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
	
	var tw: Tween = create_tween()
	tw.tween_property(bgm_player, "volume_db", bgm_volume_db, bgm_fade_in_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _load_slides() -> void:
	slide_textures.clear()
	var loaded_paths: Array[String] = []
	
	# 1. Quét động từ thư mục cutscene_folder
	var dir := DirAccess.open(cutscene_folder)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and not file_name.ends_with(".import"):
				var ext: String = file_name.get_extension().to_lower()
				if ext in ["png", "jpg", "jpeg", "webp"]:
					loaded_paths.append(cutscene_folder.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
		
		# Sắp xếp đúng thứ tự (outro_1, outro_2, outro_3)
		loaded_paths.sort()
		
	# 2. Fallback tĩnh nếu quét thư mục rỗng
	if loaded_paths.is_empty():
		for i in range(1, 4):
			var fallback_path: String = cutscene_folder.path_join("outro_%d.png" % i)
			if ResourceLoader.exists(fallback_path):
				loaded_paths.append(fallback_path)
				
	# 3. Nạp Texture2D
	for path in loaded_paths:
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			slide_textures.append(tex)
			
	print("[OutroCutscene] Nạp thành công %d bức tranh outro." % slide_textures.size())


func _setup_button_hover(btn: Button) -> void:
	if not btn:
		return
	btn.mouse_entered.connect(func():
		var tw: Tween = create_tween()
		tw.tween_property(btn, "modulate", Color(1.25, 1.25, 1.15, 1.0), 0.1)
	)
	btn.mouse_exited.connect(func():
		var tw: Tween = create_tween()
		tw.tween_property(btn, "modulate", Color.WHITE, 0.15)
	)
