extends Control

@export_group("Sound Effects")
@export var game_over_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Player/sound_die.mp3")
@export var button_click_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Geo/geo_collect_0.mp3")
@export var button_hover_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Geo/geo_rock_hit_0.mp3")

@onready var replay_button: Button = %ReplayButton
@onready var home_button: Button = %HomeButton
@onready var settings_button: Button = %SettingsButton
@onready var warehouse_button: Button = %WarehouseButton

@onready var dark_overlay: ColorRect = %DarkOverlay
@onready var main_panel: PanelContainer = %MainPanel
@onready var cracked_mask: TextureRect = %CrackedMask
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var geo_label: Label = %GeoLabel
@onready var sfx_player: AudioStreamPlayer = %SFXPlayer

var current_level_path: String = "res://assets/scenes/levels/map_1.tscn"
var is_handling_action: bool = false


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_init_buttons()


func _init_buttons() -> void:
	if replay_button:
		replay_button.pressed.connect(_on_replay_pressed)
		_setup_button_hover(replay_button)
	if home_button:
		home_button.pressed.connect(_on_home_pressed)
		_setup_button_hover(home_button)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
		_setup_button_hover(settings_button)
	if warehouse_button:
		warehouse_button.pressed.connect(_on_warehouse_pressed)
		_setup_button_hover(warehouse_button)


const COLOR_NORMAL := Color(0.66, 0.67, 0.7, 0.95)   # #a8abb3 xám mờ / bạc tối
const COLOR_HOVER := Color(1.0, 1.0, 1.0, 1.0)       # #ffffff trắng sáng

var active_hovered_btn: Button = null


func _setup_button_hover(btn: Button) -> void:
	btn.flat = true
	_ensure_button_pointers(btn)
	
	btn.mouse_entered.connect(func():
		if not is_handling_action:
			_set_button_highlight(btn, true)
	)
	btn.focus_entered.connect(func():
		if not is_handling_action:
			_set_button_highlight(btn, true)
	)
	btn.mouse_exited.connect(func():
		if not is_handling_action and not btn.has_focus():
			_set_button_highlight(btn, false)
	)
	btn.focus_exited.connect(func():
		if not is_handling_action:
			_set_button_highlight(btn, false)
	)


func _ensure_button_pointers(btn: Button) -> void:
	var ptr_tex = load("res://assets/art/Inventory & UI/Pointers/main_menu_pointer_anim0000.png")
	
	var ptr_left: TextureRect = btn.get_node_or_null("PointerLeft")
	if not ptr_left and ptr_tex:
		ptr_left = TextureRect.new()
		ptr_left.name = "PointerLeft"
		ptr_left.layout_mode = 1
		ptr_left.anchors_preset = Control.PRESET_CENTER_LEFT
		ptr_left.anchor_top = 0.5
		ptr_left.anchor_bottom = 0.5
		ptr_left.offset_left = 6.0
		ptr_left.offset_top = -12.0
		ptr_left.offset_right = 30.0
		ptr_left.offset_bottom = 12.0
		ptr_left.grow_vertical = 2
		ptr_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ptr_left.texture = ptr_tex
		ptr_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ptr_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ptr_left.modulate = Color(1, 1, 1, 0.0)
		btn.add_child(ptr_left)
		
	var ptr_right: TextureRect = btn.get_node_or_null("PointerRight")
	if not ptr_right and ptr_tex:
		ptr_right = TextureRect.new()
		ptr_right.name = "PointerRight"
		ptr_right.layout_mode = 1
		ptr_right.anchors_preset = Control.PRESET_CENTER_RIGHT
		ptr_right.anchor_left = 1.0
		ptr_right.anchor_right = 1.0
		ptr_right.anchor_top = 0.5
		ptr_right.anchor_bottom = 0.5
		ptr_right.offset_left = -30.0
		ptr_right.offset_top = -12.0
		ptr_right.offset_right = -6.0
		ptr_right.offset_bottom = 12.0
		ptr_right.grow_horizontal = 0
		ptr_right.grow_vertical = 2
		ptr_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ptr_right.texture = ptr_tex
		ptr_right.flip_h = true
		ptr_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ptr_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ptr_right.modulate = Color(1, 1, 1, 0.0)
		btn.add_child(ptr_right)


func _set_button_highlight(btn: Button, active: bool) -> void:
	if not is_instance_valid(btn):
		return
		
	var ptr_left: TextureRect = btn.get_node_or_null("PointerLeft")
	var ptr_right: TextureRect = btn.get_node_or_null("PointerRight")
	
	if active:
		active_hovered_btn = btn
		_play_sfx(button_hover_sfx)
		
		btn.pivot_offset = btn.size * 0.5
		var tw = create_tween().set_parallel(true)
		tw.tween_property(btn, "theme_override_colors/font_color", COLOR_HOVER, 0.12)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.12)
		
		if ptr_left:
			ptr_left.visible = true
			var tw_l = create_tween().set_parallel(true)
			tw_l.tween_property(ptr_left, "modulate:a", 1.0, 0.15)
			tw_l.tween_property(ptr_left, "position:x", 8.0, 0.15).from(0.0)
		if ptr_right:
			ptr_right.visible = true
			var tw_r = create_tween().set_parallel(true)
			tw_r.tween_property(ptr_right, "modulate:a", 1.0, 0.15)
			tw_r.tween_property(ptr_right, "position:x", btn.size.x - 32.0, 0.15).from(btn.size.x - 24.0)
	else:
		if active_hovered_btn == btn:
			active_hovered_btn = null
			
		btn.pivot_offset = btn.size * 0.5
		var tw = create_tween().set_parallel(true)
		tw.tween_property(btn, "theme_override_colors/font_color", COLOR_NORMAL, 0.15)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.15)
		
		if ptr_left:
			var tw_l = create_tween()
			tw_l.tween_property(ptr_left, "modulate:a", 0.0, 0.12)
		if ptr_right:
			var tw_r = create_tween()
			tw_r.tween_property(ptr_right, "modulate:a", 0.0, 0.12)


func _play_sfx(stream: AudioStream) -> void:
	if sfx_player and stream:
		sfx_player.stream = stream
		sfx_player.play()


func trigger_game_over(geo_collected: int = 0, level_scene_path: String = "") -> void:
	is_handling_action = false
	if level_scene_path != "":
		current_level_path = level_scene_path
	else:
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.scene_file_path != "":
			current_level_path = current_scene.scene_file_path
			
	SaveManager.return_scene_path = current_level_path
	SaveManager.last_geo_collected = geo_collected
	
	if geo_label:
		geo_label.text = "%d GEO COLLECTED" % geo_collected

	# Dừng nhạc nền màn chơi để tạo không khí tử nạn trang nghiêm
	var level_root = get_tree().current_scene
	if level_root:
		var bgm = level_root.find_child("BGMPlayer", true, false)
		if bgm and bgm is AudioStreamPlayer and bgm.playing:
			var bgm_tw = create_tween()
			bgm_tw.tween_property(bgm, "volume_db", -40.0, 1.0)
	
	# Phát âm thanh Game Over SFX
	_play_sfx(game_over_sfx)
	
	# Bắt đầu hoạt ảnh xuất hiện hoành tráng
	visible = true
	modulate.a = 0.0
	main_panel.scale = Vector2(0.85, 0.85)
	main_panel.pivot_offset = main_panel.size * 0.5
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(main_panel, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Hiệu ứng nhịp đập / ánh sáng đỏ mờ ảo của Cracked Mask
	if cracked_mask:
		var mask_tw = create_tween().set_loops()
		mask_tw.tween_property(cracked_mask, "modulate", Color(1.8, 0.4, 0.4, 1.0), 1.2).set_trans(Tween.TRANS_SINE)
		mask_tw.tween_property(cracked_mask, "modulate", Color(1.0, 0.8, 0.8, 0.8), 1.2).set_trans(Tween.TRANS_SINE)


func _on_replay_pressed() -> void:
	if is_handling_action: return
	is_handling_action = true
	_play_sfx(button_click_sfx)
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	
	# Ưu tiên load lại màn chơi có Checkpoint đã lưu (Bench / Respawn)
	var target_scene = current_level_path
	if SaveManager.instance:
		var respawn_data = SaveManager.instance.get_respawn_info()
		if respawn_data.get("has_checkpoint", false) and respawn_data.get("scene_path", "") != "":
			target_scene = respawn_data["scene_path"]
	get_tree().change_scene_to_file(target_scene)


func _on_home_pressed() -> void:
	if is_handling_action: return
	is_handling_action = true
	_play_sfx(button_click_sfx)
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	get_tree().change_scene_to_file("res://assets/scenes/menu/main_menu.tscn")


func _on_settings_pressed() -> void:
	if is_handling_action: return
	is_handling_action = true
	_play_sfx(button_click_sfx)
	SaveManager.return_scene_path = current_level_path
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	get_tree().change_scene_to_file("res://assets/scenes/menu/settings_screen.tscn")


func _on_warehouse_pressed() -> void:
	if is_handling_action: return
	is_handling_action = true
	_play_sfx(button_click_sfx)
	SaveManager.return_scene_path = current_level_path
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	get_tree().change_scene_to_file("res://assets/scenes/menu/inventory_screen.tscn")
