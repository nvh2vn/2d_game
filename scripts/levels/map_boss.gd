class_name MapBossLevel
extends "res://scripts/levels/pixel_level.gd"

## Script điều khiển màn đấu Boss Soul Master:
## 1. Pre-Boss Cutscene:
##    - BossTriggerArea nhận diện Player bước vào phòng.
##    - Khóa quyền điều khiển của Player, ẩn tạm thời HUD / TouchControls.
##    - Camera2D dịch chuyển (Pan) mượt mà về phía Soul Master đang lơ lửng.
##    - Hiển thị hộp thoại mở màn phong cách Hollow Knight (SOUL MASTER).
##    - Sau khi dứt thoại: Mở lại điều khiển, hiện HUD, phát nhạc chiến đấu tearcity_boss.mp3
##      và kích hoạt AI chiến đấu kèm thanh máu Boss.
## 2. Outro Transition:
##    - Bắt sự kiện Soul Master tử trận (boss_defeated).
##    - Fade out nhạc, mờ dần màn hình về màu đen (Fade to Black).
##    - Chuyển scene sang outro_cutscene.tscn.

@export_group("Boss Battle Configuration")
@export var outro_scene_path: String = "res://scenes/menu/outro_cutscene.tscn"
@export var boss_battle_bgm: AudioStream = preload("res://assets/audio/tearcity_boss.mp3")
@export var trajan_font: FontFile = preload("res://assets/ui/TrajanPro.ttf")

@export_group("Dialogue Content")
@export var boss_name_text: String = "SOUL MASTER"
@export var boss_subtitle_text: String = "BẬC THẦY LINH HỒN"
@export_multiline var dialogue_text: String = "Ngươi bước vào thánh đường của ta với chút sinh khí yếu ớt đó sao? Thật hoàn hảo... Một linh hồn thuần khiết, ngoan cường! Hãy dâng hiến cơ thể và dòng tơ của ngươi, để trở thành một phần trong sự bất tử vĩ đại của ta!"
@export var typing_speed: float = 30.0 # Ký tự mỗi giây

@onready var boss_trigger_area: Area2D = get_node_or_null("BossTriggerArea")
@onready var soul_master: SoulMaster = get_node_or_null("SoulMaster")
@onready var player_node: Node2D = get_node_or_null("PlayerController")
@onready var dialogue_layer: CanvasLayer = get_node_or_null("DialogueLayer")
@onready var dialogue_panel: Control = get_node_or_null("%DialoguePanel")
@onready var dialogue_text_label: Label = get_node_or_null("%DialogueTextLabel")
@onready var dialogue_name_label: Label = get_node_or_null("%DialogueNameLabel")
@onready var dialogue_hint_label: Label = get_node_or_null("%DialogueHintLabel")

var is_cutscene_active: bool = false
var has_triggered_intro: bool = false
var is_typing: bool = false
var dialogue_fully_revealed: bool = false
var type_tween: Tween = null
var pan_camera: Camera2D = null


func _ready() -> void:
	super._ready()
	
	# Đảm bảo Soul Master chờ lệnh kích hoạt từ Cutscene thay vì tự bật theo tầm nhìn
	if soul_master and is_instance_valid(soul_master):
		soul_master.wait_for_trigger = true
		if not soul_master.boss_defeated.is_connected(_on_soul_master_defeated):
			soul_master.boss_defeated.connect(_on_soul_master_defeated)
			
	# Kiểm tra nếu Boss đã bị hạ từ trước đó (World State)
	if SaveManager.instance and SaveManager.instance.is_event_completed("soul_master_defeated"):
		if soul_master and is_instance_valid(soul_master):
			soul_master.queue_free()
		if boss_trigger_area and is_instance_valid(boss_trigger_area):
			boss_trigger_area.set_deferred("monitoring", false)
		return

	# Khởi tạo hoặc tìm kiếm BossTriggerArea
	_setup_trigger_area()
	
	# Khởi tạo DialogueLayer nếu chưa có sẵn trong Scene
	_setup_dialogue_ui()


# ==============================================================================
# THIẾT LẬP VÙNG KÍCH HOẠT & UI HỘP THOẠI
# ==============================================================================

func _setup_trigger_area() -> void:
	if not boss_trigger_area:
		boss_trigger_area = get_node_or_null("BossTriggerArea")
		
	if not boss_trigger_area:
		boss_trigger_area = Area2D.new()
		boss_trigger_area.name = "BossTriggerArea"
		boss_trigger_area.position = Vector2(480, 530)
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(50, 300)
		col.shape = rect
		boss_trigger_area.add_child(col)
		add_child(boss_trigger_area)
		
	boss_trigger_area.collision_layer = 0
	boss_trigger_area.collision_mask = 255
	
	if not boss_trigger_area.body_entered.is_connected(_on_boss_trigger_entered):
		boss_trigger_area.body_entered.connect(_on_boss_trigger_entered)


func _setup_dialogue_ui() -> void:
	if not dialogue_layer:
		dialogue_layer = get_node_or_null("DialogueLayer")
		
	if not dialogue_layer:
		dialogue_layer = CanvasLayer.new()
		dialogue_layer.name = "DialogueLayer"
		dialogue_layer.layer = 80
		add_child(dialogue_layer)
		
	dialogue_layer.visible = false
	
	if not dialogue_panel:
		dialogue_panel = dialogue_layer.get_node_or_null("%DialoguePanel")
		
	if not dialogue_panel:
		# Tạo khung giao diện hộp thoại Hollow Knight
		var panel := PanelContainer.new()
		panel.name = "DialoguePanel"
		panel.unique_name_in_owner = true
		panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
		panel.anchor_top = 1.0
		panel.anchor_right = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_left = 120.0
		panel.offset_top = -185.0
		panel.offset_right = -120.0
		panel.offset_bottom = -35.0
		
		# Stylebox chuẩn Hollow Knight: Khung đen mờ viền xám bạc ánh kim
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.05, 0.08, 0.92)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.8, 0.72, 0.55, 0.85)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_right = 6
		sb.corner_radius_bottom_left = 6
		panel.add_theme_stylebox_override("panel", sb)
		
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 26)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_right", 26)
		margin.add_theme_constant_override("margin_bottom", 16)
		panel.add_child(margin)
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		margin.add_child(vbox)
		
		# Tên Boss
		var name_lbl := Label.new()
		name_lbl.name = "DialogueNameLabel"
		name_lbl.unique_name_in_owner = true
		name_lbl.text = "%s (%s)" % [boss_name_text, boss_subtitle_text]
		if trajan_font:
			name_lbl.add_theme_font_override("font", trajan_font)
		name_lbl.add_theme_font_size_override("font_size", 19)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55, 1.0))
		name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		name_lbl.add_theme_constant_override("outline_size", 4)
		vbox.add_child(name_lbl)
		dialogue_name_label = name_lbl
		
		# Nội dung thoại
		var txt_lbl := Label.new()
		txt_lbl.name = "DialogueTextLabel"
		txt_lbl.unique_name_in_owner = true
		txt_lbl.text = dialogue_text
		txt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if trajan_font:
			txt_lbl.add_theme_font_override("font", trajan_font)
		txt_lbl.add_theme_font_size_override("font_size", 15)
		txt_lbl.add_theme_color_override("font_color", Color(0.92, 0.93, 0.96, 1.0))
		txt_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		txt_lbl.add_theme_constant_override("outline_size", 3)
		vbox.add_child(txt_lbl)
		dialogue_text_label = txt_lbl
		
		# Gợi ý bấm tiếp tục
		var hint_lbl := Label.new()
		hint_lbl.name = "DialogueHintLabel"
		hint_lbl.unique_name_in_owner = true
		hint_lbl.text = "▼ Chạm màn hình hoặc bấm Enter / Space / E để tiếp tục"
		hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if trajan_font:
			hint_lbl.add_theme_font_override("font", trajan_font)
		hint_lbl.add_theme_font_size_override("font_size", 12)
		hint_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.75))
		vbox.add_child(hint_lbl)
		dialogue_hint_label = hint_lbl
		
		dialogue_layer.add_child(panel)
		dialogue_panel = panel


# ==============================================================================
# TIẾN TRÌNH PRE-BOSS CUTSCENE (TRIGGER & CAMERA PAN)
# ==============================================================================

func _on_boss_trigger_entered(body: Node2D) -> void:
	if has_triggered_intro or is_cutscene_active:
		return
	if not _is_player(body):
		return
		
	has_triggered_intro = true
	is_cutscene_active = true
	
	if boss_trigger_area:
		boss_trigger_area.set_deferred("monitoring", false)
		
	if not player_node:
		player_node = body
		
	_start_pre_boss_cutscene()


func _is_player(node: Node2D) -> bool:
	if not node:
		return false
	return node.is_in_group("player") or node.name == "PlayerController" or node.name.begins_with("Player")


func _start_pre_boss_cutscene() -> void:
	print_rich("[color=yellow][MapBoss][/color] Bắt đầu Pre-Boss Cutscene: Gặp gỡ Soul Master!")
	
	# 1. Khóa điều khiển Player và ẩn cụm Touch Controls / HUD
	if player_node:
		if player_node.has_method("set_cutscene_locked"):
			player_node.set_cutscene_locked(true)
		if player_node.has_method("set_hud_visible"):
			player_node.set_hud_visible(false)
			
	TouchControls.hide_interact(get_tree())
	
	# 2. Tìm Camera2D của Player
	pan_camera = get_viewport().get_camera_2d()
	if not pan_camera and player_node:
		pan_camera = player_node.get_node_or_null("%Camera2D")
		
	# 3. Dịch chuyển (Pan) Camera nhẹ nhàng về phía Soul Master
	if pan_camera and soul_master and player_node:
		# Tính độ lệch giữa Boss và Player (nâng nhẹ lên trục Y để đóng khung bao quát)
		var target_offset: Vector2 = (soul_master.global_position - player_node.global_position) + Vector2(0, -60)
		var pan_tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pan_tw.tween_property(pan_camera, "offset", target_offset, 1.6)
		await pan_tw.finished
	else:
		await get_tree().create_timer(1.0).timeout
		
	# Soul Master quay mặt nhìn về phía Player
	if soul_master and soul_master.has_method("_look_at_player"):
		soul_master._look_at_player()
		
	# 4. Hiển thị hộp thoại mở màn
	_display_dialogue()


func _display_dialogue() -> void:
	if not dialogue_layer or not dialogue_panel:
		_end_dialogue_and_start_fight()
		return
		
	dialogue_layer.visible = true
	dialogue_panel.modulate.a = 0.0
	
	# Hiệu ứng mờ dần hiện hộp thoại
	var fade_tw := create_tween()
	fade_tw.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
	await fade_tw.finished
	
	# Hiệu ứng Typewriter gõ từng chữ
	if dialogue_text_label:
		dialogue_text_label.visible_characters = 0
		var total_chars: int = dialogue_text.length()
		var duration: float = float(total_chars) / maxf(1.0, typing_speed)
		
		is_typing = true
		dialogue_fully_revealed = false
		
		type_tween = create_tween()
		type_tween.tween_property(dialogue_text_label, "visible_characters", total_chars, duration)
		await type_tween.finished
		
		is_typing = false
		dialogue_fully_revealed = true
		
	# Bật hiệu ứng nhấp nháy cho nhãn gợi ý bấm tiếp
	_start_hint_pulse()


func _start_hint_pulse() -> void:
	if not dialogue_hint_label:
		return
	var tw := create_tween().set_loops()
	tw.tween_property(dialogue_hint_label, "modulate:a", 0.3, 0.6)
	tw.tween_property(dialogue_hint_label, "modulate:a", 1.0, 0.6)


# ==============================================================================
# XỬ LÝ NHẬN INPUT LƯỚT QUA LỜI THOẠI
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not is_cutscene_active:
		return
		
	var is_advance_action: bool = (
		event.is_action_pressed("ui_accept") or
		event.is_action_pressed("interact") or
		event.is_action_pressed("jump") or
		event.is_action_pressed("attack") or
		(event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E, KEY_W, KEY_UP, KEY_Z, KEY_J]) or
		(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or
		(event is InputEventScreenTouch and event.pressed)
	)
	
	if is_advance_action:
		_handle_dialogue_advance()
		get_viewport().set_input_as_handled()


func _handle_dialogue_advance() -> void:
	# Nếu đang trong quá trình gõ chữ: Hiện toàn bộ chữ ngay lập tức
	if is_typing:
		if type_tween and type_tween.is_valid():
			type_tween.kill()
		if dialogue_text_label:
			dialogue_text_label.visible_characters = -1
		is_typing = false
		dialogue_fully_revealed = true
		return
		
	# Nếu chữ đã hiện đầy đủ: Kết thúc thoại và bắt đầu trận chiến!
	if dialogue_fully_revealed:
		dialogue_fully_revealed = false
		_end_dialogue_and_start_fight()


func _end_dialogue_and_start_fight() -> void:
	print_rich("[color=cyan][MapBoss][/color] Kết thúc hội thoại! Chuẩn bị bắt đầu trận chiến với Soul Master!")
	
	# 1. Ẩn hộp thoại
	if dialogue_panel:
		var fade_tw := create_tween()
		fade_tw.tween_property(dialogue_panel, "modulate:a", 0.0, 0.25)
		await fade_tw.finished
	if dialogue_layer:
		dialogue_layer.visible = false
		
	# 2. Dịch chuyển Camera2D trở lại tâm của Player
	if pan_camera:
		var return_tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return_tw.tween_property(pan_camera, "offset", Vector2.ZERO, 0.95)
		await return_tw.finished
		
	# 3. Mở lại quyền điều khiển cho Player và hiện lại HUD / Touch Controls
	if player_node:
		if player_node.has_method("set_cutscene_locked"):
			player_node.set_cutscene_locked(false)
		if player_node.has_method("set_hud_visible"):
			player_node.set_hud_visible(true)
			
	is_cutscene_active = false
	
	# 4. Phát nhạc nền chiến đấu Boss
	_play_boss_battle_music()
	
	# 5. Kích hoạt AI chiến đấu của Soul Master kèm thanh máu Boss
	if soul_master and is_instance_valid(soul_master):
		soul_master.start_encounter()


func _play_boss_battle_music() -> void:
	if not bgm_player:
		bgm_player = find_child("BGMPlayer", false, false)
	if not bgm_player:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.name = "BGMPlayer"
		bgm_player.bus = &"Music"
		add_child(bgm_player)
		
	if boss_battle_bgm:
		bgm_player.stream = boss_battle_bgm
		if bgm_player.stream is AudioStreamMP3:
			bgm_player.stream.loop = true
		bgm_player.volume_db = -4.0
		bgm_player.play()


# ==============================================================================
# OUTRO CUTSCENE TRIGGER (KHI TIÊU DIỆT SOUL MASTER)
# ==============================================================================

func _on_soul_master_defeated() -> void:
	print_rich("[color=gold][MapBoss][/color] Soul Master đã bị tiêu diệt! Chuẩn bị chuyển sang Outro Cutscene...")
	
	# 1. Giảm dần và ngắt nhạc chiến đấu
	if bgm_player and bgm_player.playing:
		var tw_bgm := create_tween()
		tw_bgm.tween_property(bgm_player, "volume_db", -60.0, 1.8)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			
	# 2. Đợi hoạt ảnh nổ tung và hấp thụ của Boss diễn ra trọn vẹn (~2.2s)
	await get_tree().create_timer(2.2).timeout
	
	# 3. Màn hình mờ dần về màu đen (Fade to Black)
	var fade_rect: ColorRect = null
	if player_node:
		fade_rect = player_node.find_child("FadeRect", true, false)
	if not fade_rect:
		fade_rect = find_child("FadeRect", true, false)
		
	if not fade_rect:
		# Tạo CanvasLayer phủ đen nếu chưa có FadeRect
		var overlay_layer := CanvasLayer.new()
		overlay_layer.name = "OutroFadeLayer"
		overlay_layer.layer = 120
		fade_rect = ColorRect.new()
		fade_rect.color = Color.BLACK
		fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_layer.add_child(fade_rect)
		add_child(overlay_layer)
		
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	var tw_fade := create_tween()
	tw_fade.tween_property(fade_rect, "modulate:a", 1.0, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_fade.finished
		
	# 4. Ngắt hẳn nhạc và chuyển scene sang outro_cutscene
	if bgm_player:
		bgm_player.stop()
		
	var target: String = outro_scene_path
	if not ResourceLoader.exists(target):
		target = "res://scenes/outro_cutscene.tscn"
		
	print_rich("[color=green][MapBoss][/color] Chuyển tiếp sang Outro Cutscene: %s" % target)
	get_tree().change_scene_to_file(target)
