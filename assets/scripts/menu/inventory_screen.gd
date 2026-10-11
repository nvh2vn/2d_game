extends Control

@export_group("Background Music (BGM)")
@export var bgm_stream: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/menu.mp3")
@export var button_click_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Geo/geo_collect_0.mp3")
@export var button_hover_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Geo/geo_rock_hit_0.mp3")

@onready var geo_count_label: Label = %GeoCountLabel
@onready var back_button: Button = %BackButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var sfx_player: AudioStreamPlayer = %SFXPlayer
@onready var bgm_player: AudioStreamPlayer = %BGMPlayer
@onready var last_level_label: Label = %LastLevelLabel


func _ready() -> void:
	if bgm_player and bgm_stream:
		bgm_player.bus = &"Music"
		bgm_player.stream = bgm_stream
		if not bgm_player.playing:
			bgm_player.play()
			
	_display_stats()
	_init_buttons()
	
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)


func _display_stats() -> void:
	var total_geo = SaveManager.get_geo()
	if SaveManager.last_geo_collected > 0:
		total_geo = maxi(total_geo, SaveManager.last_geo_collected)
	if geo_count_label:
		geo_count_label.text = "%d GEO" % total_geo
		
	if last_level_label:
		var last_scene = SaveManager.get_last_level()
		var scene_name = last_scene.get_file().get_basename().capitalize()
		last_level_label.text = "LAST EXPLORED: %s" % scene_name


func _init_buttons() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		_setup_button_hover(back_button)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
		_setup_button_hover(main_menu_button)


const COLOR_NORMAL := Color(0.66, 0.67, 0.7, 0.95)   # #a8abb3 xám mờ / bạc tối
const COLOR_HOVER := Color(1.0, 1.0, 1.0, 1.0)       # #ffffff trắng sáng

var active_hovered_btn: Button = null


func _setup_button_hover(btn: Button) -> void:
	btn.flat = true
	_ensure_button_pointers(btn)
	
	btn.mouse_entered.connect(func():
		_set_button_highlight(btn, true)
	)
	btn.focus_entered.connect(func():
		_set_button_highlight(btn, true)
	)
	btn.mouse_exited.connect(func():
		if not btn.has_focus():
			_set_button_highlight(btn, false)
	)
	btn.focus_exited.connect(func():
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


func _on_back_pressed() -> void:
	_play_sfx(button_click_sfx)
	var target = SaveManager.return_scene_path
	if target == "" or target == scene_file_path:
		target = "res://assets/scenes/menu/main_menu.tscn"
	_transition_to_scene(target)


func _on_main_menu_pressed() -> void:
	_play_sfx(button_click_sfx)
	_transition_to_scene("res://assets/scenes/menu/main_menu.tscn")


func _transition_to_scene(scene_path: String) -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	get_tree().change_scene_to_file(scene_path)
