extends CanvasLayer
class_name TeleportMenu

@onready var background: ColorRect = get_node_or_null("%Background")
@onready var list_container: VBoxContainer = get_node_or_null("%DestinationList")
@onready var close_button: Button = get_node_or_null("%CloseButton")

var current_player: Node2D = null
var current_wp_id: String = ""

const COLOR_NORMAL := Color(0.66, 0.67, 0.7, 0.95)   # #a8abb3 xám mờ / bạc tối
const COLOR_HOVER := Color(1.0, 1.0, 1.0, 1.0)       # #ffffff trắng sáng

var hover_sfx: AudioStream = preload("res://assets/audio/ui/ui_change_selection.mp3")
var confirm_sfx: AudioStream = preload("res://assets/audio/ui/ui_button_confirm.mp3")
var font_title: FontFile = preload("res://assets/fonts/Cinzel-Bold.ttf")
var font_body: FontFile = preload("res://assets/fonts/Spectral-Bold.ttf")
var trajan_font: FontFile = font_body
var active_hovered_btn: Button = null

func _ready() -> void:
	layer = 105
	if font_title and font_body:
		font_title.fallbacks = [font_body]
	if close_button:
		close_button.add_theme_font_override("font", font_body)
		close_button.pressed.connect(_on_close_pressed)
		_setup_button_hover(close_button)

func _get_teleport_manager() -> Node:
	return get_node_or_null("/root/TeleportManager")

func open_menu(wp_id: String, player_ref: Node2D = null) -> void:
	current_wp_id = wp_id
	current_player = player_ref
	
	if current_player:
		if "is_sitting" in current_player:
			current_player.is_sitting = true
		if "velocity" in current_player:
			current_player.velocity = Vector2.ZERO
			
	populate_destinations()

func populate_destinations() -> void:
	if list_container == null:
		list_container = get_node_or_null("%DestinationList")
		if list_container == null:
			return
			
	for c in list_container.get_children():
		c.queue_free()
		
	var waypoints: Array = []
	var tm = _get_teleport_manager()
	if tm and tm.has_method("get_unlocked_list"):
		waypoints = tm.get_unlocked_list()
		
	if waypoints.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "CHƯA CÓ ĐIỂM DỊCH CHUYỂN NÀO ĐƯỢC MỞ KHÓA"
		if font_body:
			empty_lbl.add_theme_font_override("font", font_body)
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68, 0.8))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(empty_lbl)
		return
		
	var norm_box = StyleBoxFlat.new()
	norm_box.bg_color = Color(0.04, 0.05, 0.08, 0.6)
	norm_box.border_width_left = 1; norm_box.border_width_top = 1; norm_box.border_width_right = 1; norm_box.border_width_bottom = 1
	norm_box.border_color = Color(0.35, 0.38, 0.44, 0.6)
	norm_box.corner_radius_top_left = 4; norm_box.corner_radius_top_right = 4; norm_box.corner_radius_bottom_right = 4; norm_box.corner_radius_bottom_left = 4
	norm_box.content_margin_left = 16; norm_box.content_margin_right = 16; norm_box.content_margin_top = 8; norm_box.content_margin_bottom = 8

	var hov_box = StyleBoxFlat.new()
	hov_box.bg_color = Color(0.12, 0.14, 0.18, 0.85)
	hov_box.border_width_left = 1; hov_box.border_width_top = 1; hov_box.border_width_right = 1; hov_box.border_width_bottom = 1
	hov_box.border_color = Color(1.0, 1.0, 1.0, 0.95)
	hov_box.corner_radius_top_left = 4; hov_box.corner_radius_top_right = 4; hov_box.corner_radius_bottom_right = 4; hov_box.corner_radius_bottom_left = 4
	hov_box.content_margin_left = 16; hov_box.content_margin_right = 16; hov_box.content_margin_top = 8; hov_box.content_margin_bottom = 8

	var dis_box = StyleBoxFlat.new()
	dis_box.bg_color = Color(0.03, 0.03, 0.05, 0.4)
	dis_box.border_width_left = 1; dis_box.border_width_top = 1; dis_box.border_width_right = 1; dis_box.border_width_bottom = 1
	dis_box.border_color = Color(0.25, 0.28, 0.32, 0.3)
	dis_box.corner_radius_top_left = 4; dis_box.corner_radius_top_right = 4; dis_box.corner_radius_bottom_right = 4; dis_box.corner_radius_bottom_left = 4
	dis_box.content_margin_left = 16; dis_box.content_margin_right = 16; dis_box.content_margin_top = 8; dis_box.content_margin_bottom = 8

	for wp in waypoints:
		var btn = Button.new()
		var is_current = (wp["id"] == current_wp_id)
		
		if font_body:
			btn.add_theme_font_override("font", font_body)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_stylebox_override("normal", norm_box)
		btn.add_theme_stylebox_override("hover", hov_box)
		btn.add_theme_stylebox_override("focus", hov_box)
		btn.add_theme_stylebox_override("pressed", hov_box)
		btn.add_theme_stylebox_override("disabled", dis_box)
		
		btn.add_theme_color_override("font_color", COLOR_NORMAL)
		btn.add_theme_color_override("font_hover_color", COLOR_HOVER)
		btn.add_theme_color_override("font_focus_color", COLOR_HOVER)
		btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.46, 0.5))
		
		if is_current:
			btn.text = str(wp["name"]).to_upper() + " (VỊ TRÍ HIỆN TẠI)"
			btn.disabled = true
		else:
			btn.text = str(wp["name"]).to_upper()
			btn.pressed.connect(func():
				_play_sfx(confirm_sfx)
				_on_destination_selected(wp)
			)
			_setup_button_hover(btn)
			
		btn.custom_minimum_size = Vector2(340, 44)
		list_container.add_child(btn)


func _setup_button_hover(btn: Button) -> void:
	_ensure_button_pointers(btn)
	
	btn.mouse_entered.connect(func():
		if not btn.disabled:
			_set_button_highlight(btn, true)
	)
	btn.focus_entered.connect(func():
		if not btn.disabled:
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
		_play_sfx(hover_sfx)
		
		btn.pivot_offset = btn.size * 0.5
		var tw = create_tween().set_parallel(true)
		tw.tween_property(btn, "theme_override_colors/font_color", COLOR_HOVER, 0.12)
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
		
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
	if stream and is_inside_tree():
		var asp = AudioStreamPlayer.new()
		asp.stream = stream
		asp.bus = &"SFX"
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	if is_instance_valid(current_player):
		if "is_sitting" in current_player:
			current_player.is_sitting = false
	queue_free()

func _on_destination_selected(dest_data: Dictionary) -> void:
	var target_scene = dest_data.get("scene_path", "")
	var target_marker = dest_data.get("marker_id", "")
	
	var tm = _get_teleport_manager()
	if tm:
		tm.target_waypoint_marker = target_marker
	
	var player = current_player
	if not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			
	# Start Teleport Fade Sequence
	if is_instance_valid(player) and player.has_method("fade_to_black"):
		player.fade_to_black(0.25)
		await get_tree().create_timer(0.26, true, false, true).timeout
		
		var cur_scene = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		if target_scene != "" and target_scene != cur_scene:
			# Change Level Scene
			get_tree().change_scene_to_file(target_scene)
		else:
			# Same Scene Teleport
			var pillars = get_tree().get_nodes_in_group("waypoints")
			var target_pillar: WaypointPillar = null
			for p in pillars:
				if p is WaypointPillar and p.marker_id == target_marker:
					target_pillar = p
					break
					
			if target_pillar:
				var dest_pos = target_pillar.global_position
				if target_pillar.spawn_point:
					dest_pos = target_pillar.spawn_point.global_position
				player.global_position = dest_pos
				if "last_safe_position" in player:
					player.last_safe_position = dest_pos
				if "velocity" in player:
					player.velocity = Vector2.ZERO
				if "camera_2d" in player and player.camera_2d and player.camera_2d.has_method("reset_smoothing"):
					player.camera_2d.reset_smoothing()
					
			if "is_sitting" in player:
				player.is_sitting = false
				
			player.fade_from_black(0.25)
			
		queue_free()
	else:
		if target_scene != "":
			get_tree().change_scene_to_file(target_scene)
		queue_free()
