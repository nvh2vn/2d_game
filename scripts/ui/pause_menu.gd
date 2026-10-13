extends CanvasLayer

## Pause Menu & Mobile Pause Button dành cho Godot 4 2D Mobile.
## Tạm dừng toàn bộ gameplay khi mở menu và hỗ trợ lưu trạng thái an toàn.

@export_file("*.tscn") var main_menu_scene_path: String = "res://scenes/menu/main_menu.tscn"

@export_group("UI Audio SFX")
@export var hover_sfx: AudioStream
@export var confirm_sfx: AudioStream

@onready var pause_button: TextureButton = %PauseButton
@onready var pause_overlay: Control = %PauseOverlay
@onready var resume_button: Button = %ResumeButton
@onready var restart_checkpoint_button: Button = %RestartCheckpointButton
@onready var main_menu_button: Button = %MainMenuButton

@onready var pause_pointer: TextureRect = %PausePointer
@onready var sfx_player: AudioStreamPlayer = %SFXPlayer

var is_paused: bool = false
var pointer_tween: Tween = null


func _ready() -> void:
	# Đảm bảo PauseMenu và toàn bộ cây con luôn nhận xử lý khi game bị Pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)
		pause_button.visible = true
		
	if pause_overlay:
		pause_overlay.visible = false
		pause_overlay.modulate.a = 0.0
		
	if pause_pointer:
		pause_pointer.visible = false
		pause_pointer.modulate.a = 0.0

	# Cấu hình các nút trong Pause Menu
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
		_setup_button_hover(resume_button)
		
	if restart_checkpoint_button:
		restart_checkpoint_button.pressed.connect(_on_restart_checkpoint_pressed)
		_setup_button_hover(restart_checkpoint_button)
		
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
		_setup_button_hover(main_menu_button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		if is_paused:
			resume_game()
		else:
			pause_game()


func _on_pause_button_pressed() -> void:
	_play_confirm_sfx()
	pause_game()


const COLOR_NORMAL := Color(0.66, 0.67, 0.7, 0.95)   # #a8abb3 xám mờ / bạc tối
const COLOR_HOVER := Color(1.0, 1.0, 1.0, 1.0)       # #ffffff trắng sáng

var active_hovered_btn: Button = null


func pause_game() -> void:
	if is_paused:
		return
	is_paused = true
	var tree = get_tree()
	if tree:
		tree.paused = true
	
	var btn = pause_button if pause_button else get_node_or_null("%PauseButton")
	if btn:
		btn.visible = false
		
	var overlay = pause_overlay if pause_overlay else get_node_or_null("%PauseOverlay")
	if overlay:
		overlay.visible = true
		overlay.modulate.a = 1.0
		
	var res_btn = resume_button if resume_button else get_node_or_null("%ResumeButton")
	if res_btn:
		if is_inside_tree():
			res_btn.grab_focus()
		_set_button_highlight(res_btn, true)


func resume_game() -> void:
	if not is_paused:
		return
	is_paused = false
	_play_confirm_sfx()
	
	for btn in [resume_button, restart_checkpoint_button, main_menu_button]:
		if btn and is_instance_valid(btn):
			_set_button_highlight(btn, false)
	
	var ptr = pause_pointer if pause_pointer else get_node_or_null("%PausePointer")
	if ptr:
		ptr.visible = false
		
	var overlay = pause_overlay if pause_overlay else get_node_or_null("%PauseOverlay")
	if overlay:
		overlay.visible = false
		overlay.modulate.a = 0.0
		
	var btn = pause_button if pause_button else get_node_or_null("%PauseButton")
	if btn:
		btn.visible = true
		
	var tree = get_tree()
	if tree:
		tree.paused = false


func _on_resume_pressed() -> void:
	resume_game()


func _on_restart_checkpoint_pressed() -> void:
	_play_confirm_sfx()
	is_paused = false
	get_tree().paused = false
	
	var target_scene = "res://scenes/levels/map_1.tscn"
	if get_tree().current_scene and get_tree().current_scene.scene_file_path != "":
		target_scene = get_tree().current_scene.scene_file_path
		
	if SaveManager.instance:
		var respawn = SaveManager.instance.get_respawn_info()
		if respawn.get("has_checkpoint", false) and respawn.get("scene_path", "") != "":
			target_scene = respawn["scene_path"]
		else:
			target_scene = SaveManager.get_last_level(target_scene)
	else:
		target_scene = SaveManager.get_last_level(target_scene)
		
	get_tree().change_scene_to_file(target_scene)


func _on_main_menu_pressed() -> void:
	_play_confirm_sfx()
	
	# Tự động lưu tiến trình hiện tại qua SaveManager trước khi thoát về Menu
	if SaveManager.instance:
		SaveManager.instance.update_current_player_stats()
		SaveManager.instance.save_to_disk()
		
	is_paused = false
	var tree = get_tree()
	if tree:
		tree.paused = false
		tree.change_scene_to_file(main_menu_scene_path)


func _setup_button_hover(btn: Button) -> void:
	btn.flat = true
	_ensure_button_pointers(btn)
	
	btn.mouse_entered.connect(func():
		if not is_paused or btn.disabled:
			return
		_set_button_highlight(btn, true)
	)
	
	btn.focus_entered.connect(func():
		if not is_paused or btn.disabled:
			return
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
	var ptr_tex = load("res://assets/ui/inventory/Pointers/main_menu_pointer_anim0000.png")
	
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
		_play_hover_sfx()
		
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


func _move_pointer_to(btn: Button) -> void:
	_set_button_highlight(btn, true)
	
	_play_hover_sfx()


func _play_hover_sfx() -> void:
	if sfx_player and hover_sfx:
		sfx_player.stream = hover_sfx
		sfx_player.play()


func _play_confirm_sfx() -> void:
	if sfx_player and confirm_sfx:
		sfx_player.stream = confirm_sfx
		sfx_player.play()
