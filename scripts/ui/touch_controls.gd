class_name TouchControls
extends CanvasLayer

## Mobile On-Touch Screen Controls
## Tương thích 100% với PlayerController và hệ thống InputMap của Godot 4.
## Hỗ trợ Chế độ Tùy chỉnh vị trí nút ảo (Customize Edit Mode) và lưu ConfigFile.

signal customizing_finished

static var instance: TouchControls = null

static func show_interact(tree: SceneTree, target_type: String = "") -> void:
	if instance and is_instance_valid(instance):
		instance.show_interact_button(target_type)
	elif tree:
		var tc = tree.get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.show_interact_button(target_type)

static func hide_interact(tree: SceneTree) -> void:
	if instance and is_instance_valid(instance):
		instance.hide_interact_button()
	elif tree:
		var tc = tree.get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.hide_interact_button()

static func suppress_interact(tree: SceneTree, suppressed: bool) -> void:
	if instance and is_instance_valid(instance):
		instance.set_interact_suppressed(suppressed)
	elif tree:
		var tc = tree.get_first_node_in_group("touch_controls") as TouchControls
		if tc:
			tc.set_interact_suppressed(suppressed)

static func set_controls_visible(tree: SceneTree, p_visible: bool) -> void:
	if instance and is_instance_valid(instance):
		instance.visible = p_visible
		instance.process_mode = Node.PROCESS_MODE_ALWAYS if p_visible else Node.PROCESS_MODE_DISABLED
		if instance.control_root and is_instance_valid(instance.control_root):
			instance.control_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not p_visible:
			instance._release_joystick()
			if instance._active_mouse_btn and instance._active_mouse_btn.action != &"":
				Input.action_release(instance._active_mouse_btn.action)
				instance._active_mouse_btn = null
			var all_actions = [
				&"move_left", &"move_right", &"move_up", &"move_down",
				&"jump", &"attack", &"dash", &"shoot", &"special_attack", &"bind", &"interact"
			]
			for act in all_actions:
				Input.action_release(act)
	if tree:
		var tc_nodes = tree.get_nodes_in_group("touch_controls")
		for n in tc_nodes:
			if n is CanvasItem:
				n.visible = p_visible
			if n is Node:
				n.process_mode = Node.PROCESS_MODE_ALWAYS if p_visible else Node.PROCESS_MODE_DISABLED
		var tc = tree.root.find_child("TouchControls", true, false)
		if tc and tc != instance:
			if tc is CanvasItem:
				tc.visible = p_visible
			if tc is Node:
				tc.process_mode = Node.PROCESS_MODE_ALWAYS if p_visible else Node.PROCESS_MODE_DISABLED



static func update_skill_buttons(tree: SceneTree) -> void:
	if instance and is_instance_valid(instance):
		instance.update_skills_visibility()
	elif tree:
		var tc_nodes = tree.get_nodes_in_group("touch_controls")
		for n in tc_nodes:
			if n.has_method("update_skills_visibility"):
				n.update_skills_visibility()
		var tc = tree.root.find_child("TouchControls", true, false)
		if tc and tc.has_method("update_skills_visibility"):
			tc.update_skills_visibility()

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

const CONFIG_FILE_PATH: String = "user://touch_layout.cfg"
const CONFIG_SECTION: String = "touch_layout"

@export_group("Configuration")
## Bắt buộc hiển thị cả trên PC/Editor để test thuận tiện
@export var force_show: bool = true
## Bán kính giới hạn tối đa cho cần điều khiển Joystick
@export var joystick_radius: float = 72.0
## Vùng chạm tối đa quanh tâm Joystick (độ nhạy nhận diện ngón tay cái)
@export var touch_zone_radius: float = 140.0
## Ngưỡng kích hoạt di chuyển ngang (move_left / move_right)
@export var movement_threshold: float = 0.3
## Ngưỡng kích hoạt hướng dọc (move_up / move_down - dùng cho ngẩng mặt/ngồi/chém lên/chém xuống)
@export var vertical_threshold: float = 0.35
## Độ mờ mặc định của toàn bộ cụm nút (0.7 - 0.85 theo yêu cầu)
@export_range(0.1, 1.0) var controls_alpha: float = 0.82
## Thời gian cần đàn hồi về tâm (giây)
@export var snap_back_duration: float = 0.12

@onready var control_root: Control = %ControlRoot
@onready var joystick_container: Control = %JoystickContainer
@onready var joystick_base: Sprite2D = %JoystickBase
@onready var joystick_knob: Sprite2D = %JoystickKnob
@onready var action_buttons_container: Control = %ActionButtonsContainer

# Danh sách Action Buttons
@onready var attack_btn: TouchScreenButton = get_node_or_null("%AttackButton")
@onready var jump_btn: TouchScreenButton = get_node_or_null("%JumpButton")
@onready var dash_btn: TouchScreenButton = get_node_or_null("%DashButton")
@onready var throw_btn: TouchScreenButton = get_node_or_null("%ThrowButton")
@onready var skill_btn: TouchScreenButton = get_node_or_null("%SkillButton")
@onready var bind_btn: TouchScreenButton = get_node_or_null("%BindButton")
@onready var interact_btn: TouchScreenButton = get_node_or_null("%InteractButton")

# UI Tùy chỉnh (Customize Overlay)
@onready var customize_overlay: Control = get_node_or_null("%CustomizeOverlay")
@onready var customize_top_bar: MarginContainer = get_node_or_null("%CustomizeTopBar")
@onready var reset_layout_button: Button = get_node_or_null("%ResetLayoutButton")
@onready var save_exit_button: Button = get_node_or_null("%SaveExitButton")

# --- Trạng thái Gameplay ---
var joystick_touch_id: int = -1
var current_input_vector: Vector2 = Vector2.ZERO
var _snap_tween: Tween = null
var _active_mouse_btn: TouchScreenButton = null

# --- Trạng thái Nút Tương Tác Ngữ Cảnh ---
var _interact_tween: Tween = null
var _interaction_count: int = 0

# --- Trạng thái Chế độ Tùy chỉnh (Edit Mode) ---
var is_customizing: bool = false
var return_ui_target: Control = null
var default_positions: Dictionary = {}
var _original_actions: Dictionary = {}
var _button_base_scales: Dictionary = {}

var font_title: FontFile = preload("res://assets/fonts/Cinzel-Bold.ttf")
var font_body: FontFile = preload("res://assets/fonts/Spectral-Bold.ttf")

var _drag_target: Node = null
var _drag_touch_id: int = -1
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	if font_title and font_body:
		font_title.fallbacks = [font_body]

	add_to_group("touch_controls")

	# Đảm bảo action interact luôn có sẵn trong InputMap
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact", 0.2)
		for key in [KEY_E, KEY_W, KEY_UP]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event("interact", ev)

	# 1. Tự động kiểm tra thiết bị: Hiển thị trên Android/iOS hoặc màn hình cảm ứng
	var is_mobile: bool = OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()
	visible = is_mobile or force_show

	if control_root:
		control_root.modulate.a = controls_alpha

	_setup_button_feedback()
	_setup_customize_ui()

	# Khởi tạo lưu trữ tỷ lệ gốc của nút để phóng to / thu nhỏ mượt khi kéo
	_cache_button_scales()

	# Khởi tạo nạp vị trí lưu từ ConfigFile
	_init_layout_persistence()
	
	# Đồng bộ hiển thị 2 nút kỹ năng Silk Storm và Needle Throw theo GameManager
	update_skills_visibility()
	if is_inside_tree() and get_tree().root.has_node("GameManager"):
		var gm = get_tree().root.get_node("GameManager")
		if not gm.skills_changed.is_connected(update_skills_visibility):
			gm.skills_changed.connect(update_skills_visibility)


func update_skills_visibility() -> void:
	if is_customizing:
		return
	var can_storm: bool = false
	var can_throw: bool = false
	if is_inside_tree() and get_tree() and get_tree().root and get_tree().root.has_node("GameManager"):
		var gm = get_tree().root.get_node("GameManager")
		can_storm = gm.can_silk_storm
		can_throw = gm.can_needle_throw
		
	if skill_btn and is_instance_valid(skill_btn):
		skill_btn.visible = can_storm
	if throw_btn and is_instance_valid(throw_btn):
		throw_btn.visible = can_throw


func _notification(what: int) -> void:
	# Đảm bảo an toàn khi mất focus cửa sổ hoặc tạm dừng game
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_joystick()
		if _active_mouse_btn:
			Input.action_release(_active_mouse_btn.action)
			_on_btn_up(_active_mouse_btn)
			_active_mouse_btn = null
		if is_customizing:
			if _drag_target:
				_highlight_item(_drag_target, false)
				_drag_target = null
			_drag_touch_id = -1


# ==============================================================================
# HỆ THỐNG LƯU / NẠP TỌA ĐỘ NÚT (PERSISTENCE VIA CONFIGFILE)
# ==============================================================================

func _init_layout_persistence() -> void:
	# Chờ 1 frame để Godot tính toán xong anchors và viewport dimensions
	if is_inside_tree():
		await get_tree().process_frame

	_record_default_positions()

	# Xóa bỏ file cấu hình cũ nếu có và KHÔNG tự động nạp để ưu tiên 100% vị trí được kéo thả trong Editor .tscn
	if FileAccess.file_exists(CONFIG_FILE_PATH):
		DirAccess.remove_absolute(CONFIG_FILE_PATH)


func _record_default_positions() -> void:
	if not default_positions.is_empty():
		return
	if joystick_container:
		default_positions["joystick"] = joystick_container.global_position
	if jump_btn:
		default_positions["jump"] = jump_btn.global_position
	if attack_btn:
		default_positions["attack"] = attack_btn.global_position
	if dash_btn:
		default_positions["dash"] = dash_btn.global_position
	if throw_btn:
		default_positions["throw"] = throw_btn.global_position
	if skill_btn:
		default_positions["skill"] = skill_btn.global_position
	if bind_btn:
		default_positions["bind"] = bind_btn.global_position
	if interact_btn:
		default_positions["interact"] = interact_btn.global_position


func save_layout() -> void:
	var config = ConfigFile.new()
	if joystick_container:
		config.set_value(CONFIG_SECTION, "joystick", joystick_container.global_position)
	if jump_btn:
		config.set_value(CONFIG_SECTION, "jump", jump_btn.global_position)
	if attack_btn:
		config.set_value(CONFIG_SECTION, "attack", attack_btn.global_position)
	if dash_btn:
		config.set_value(CONFIG_SECTION, "dash", dash_btn.global_position)
	if throw_btn:
		config.set_value(CONFIG_SECTION, "throw", throw_btn.global_position)
	if skill_btn:
		config.set_value(CONFIG_SECTION, "skill", skill_btn.global_position)
	if bind_btn:
		config.set_value(CONFIG_SECTION, "bind", bind_btn.global_position)
	if interact_btn:
		config.set_value(CONFIG_SECTION, "interact", interact_btn.global_position)

	var err = config.save(CONFIG_FILE_PATH)
	if err == OK:
		print("[TouchControls] Layout saved successfully to: ", CONFIG_FILE_PATH)
	else:
		push_error("[TouchControls] Failed to save layout to %s (error %d)" % [CONFIG_FILE_PATH, err])


func load_layout() -> bool:
	# Vô hiệu hóa nạp cấu hình đè vị trí để ưu tiên 100% vị trí trong Editor .tscn
	return false


func reset_to_defaults() -> void:
	if default_positions.is_empty():
		_record_default_positions()

	if joystick_container and default_positions.has("joystick"):
		_animate_to_pos(joystick_container, default_positions["joystick"])
	if jump_btn and default_positions.has("jump"):
		_animate_to_pos(jump_btn, default_positions["jump"])
	if attack_btn and default_positions.has("attack"):
		_animate_to_pos(attack_btn, default_positions["attack"])
	if dash_btn and default_positions.has("dash"):
		_animate_to_pos(dash_btn, default_positions["dash"])
	if throw_btn and default_positions.has("throw"):
		_animate_to_pos(throw_btn, default_positions["throw"])
	if skill_btn and default_positions.has("skill"):
		_animate_to_pos(skill_btn, default_positions["skill"])
	if bind_btn and default_positions.has("bind"):
		_animate_to_pos(bind_btn, default_positions["bind"])
	if interact_btn and default_positions.has("interact"):
		_animate_to_pos(interact_btn, default_positions["interact"])


func _animate_to_pos(target_node: Node, target_pos: Vector2) -> void:
	var tw = create_tween()
	tw.tween_property(target_node, "global_position", target_pos, 0.25)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


# ==============================================================================
# CHẾ ĐỘ TÙY CHỈNH (CUSTOMIZE MODE LOGIC)
# ==============================================================================

func start_customizing(return_target: Control = null) -> void:
	is_customizing = true
	return_ui_target = return_target
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	if control_root:
		control_root.modulate.a = 1.0

	if customize_overlay:
		customize_overlay.visible = true

	# 1. Tạm thời xóa action trên TouchScreenButton để ngắt hoàn toàn gameplay actions
	_original_actions.clear()
	var buttons = [jump_btn, attack_btn, dash_btn, throw_btn, skill_btn, bind_btn, interact_btn]
	for btn in buttons:
		if btn and is_instance_valid(btn):
			_original_actions[btn] = btn.action
			btn.action = &""

	if interact_btn and is_instance_valid(interact_btn):
		interact_btn.visible = true
		interact_btn.modulate.a = 0.85

	# 2. Hủy trạng thái joystick và nhả toàn bộ các phím gameplay
	_release_joystick()
	var all_actions = [
		&"move_left", &"move_right", &"move_up", &"move_down",
		&"jump", &"attack", &"dash", &"shoot", &"special_attack", &"bind", &"interact"
	]
	for act in all_actions:
		Input.action_release(act)


func finish_customizing() -> void:
	is_customizing = false

	if control_root:
		control_root.modulate.a = controls_alpha

	if customize_overlay:
		customize_overlay.visible = false

	# 1. Khôi phục lại action gameplay cho TouchScreenButton
	var buttons = [jump_btn, attack_btn, dash_btn, throw_btn, skill_btn, bind_btn, interact_btn]
	for btn in buttons:
		if btn and is_instance_valid(btn) and _original_actions.has(btn):
			btn.action = _original_actions[btn]
	_original_actions.clear()

	# Khôi phục trạng thái hiển thị của interact_btn theo số lượng tương tác hiện tại
	if interact_btn and is_instance_valid(interact_btn):
		if _interaction_count <= 0:
			interact_btn.visible = false
			interact_btn.modulate.a = 0.0
		else:
			interact_btn.visible = true
			interact_btn.modulate.a = 1.0

	# 2. Xóa trạng thái kéo
	if _drag_target:
		_highlight_item(_drag_target, false)
		_drag_target = null
	_drag_touch_id = -1

	# 3. Nếu đang nằm trên menu độc lập (Settings/MainMenu), ẩn TouchControls đi
	var p = get_parent()
	if p and (p.name == "SettingsScreen" or p.name == "MainMenu" or p is Control):
		visible = false
	else:
		var is_mobile: bool = OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()
		visible = is_mobile or force_show

	customizing_finished.emit()
	update_skills_visibility()

	if return_ui_target and is_instance_valid(return_ui_target):
		return_ui_target.visible = true
		return_ui_target = null


func _setup_customize_ui() -> void:
	if reset_layout_button:
		reset_layout_button.pressed.connect(_on_reset_layout_pressed)
	if save_exit_button:
		save_exit_button.pressed.connect(_on_save_exit_pressed)


func _on_reset_layout_pressed() -> void:
	reset_to_defaults()


func _on_save_exit_pressed() -> void:
	save_layout()
	finish_customizing()


func _cache_button_scales() -> void:
	var buttons = [jump_btn, attack_btn, dash_btn, throw_btn, skill_btn, bind_btn, interact_btn]
	for btn in buttons:
		if btn and is_instance_valid(btn):
			_button_base_scales[btn] = btn.scale


# ==============================================================================
# QUẢN LÝ NÚT TƯƠNG TÁC NGỮ CẢNH (CONTEXTUAL INTERACT BUTTON)
# ==============================================================================

func show_interact_button(target_type: String = "") -> void:
	if not interact_btn:
		interact_btn = get_node_or_null("%InteractButton")
	if not interact_btn or not is_instance_valid(interact_btn):
		return
	_interaction_count += 1
	if is_customizing:
		return
	if _interact_tween and _interact_tween.is_valid():
		_interact_tween.kill()

	interact_btn.visible = true
	var base_scale: Vector2 = _button_base_scales.get(interact_btn, interact_btn.scale)
	interact_btn.scale = base_scale * 0.8
	
	_interact_tween = create_tween().set_parallel(true)
	_interact_tween.tween_property(interact_btn, "modulate:a", 1.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	_interact_tween.tween_property(interact_btn, "scale", base_scale, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


func hide_interact_button() -> void:
	if not interact_btn:
		interact_btn = get_node_or_null("%InteractButton")
	if not interact_btn or not is_instance_valid(interact_btn):
		return
	_interaction_count = maxi(0, _interaction_count - 1)
	if _interaction_count > 0:
		return
	_force_hide_interact_button()


func _force_hide_interact_button() -> void:
	if not interact_btn:
		interact_btn = get_node_or_null("%InteractButton")
	if not interact_btn or not is_instance_valid(interact_btn):
		return
	if is_customizing:
		return
	if _interact_tween and _interact_tween.is_valid():
		_interact_tween.kill()

	var base_scale: Vector2 = _button_base_scales.get(interact_btn, interact_btn.scale)
	_interact_tween = create_tween().set_parallel(true)
	_interact_tween.tween_property(interact_btn, "modulate:a", 0.0, 0.15)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)
	_interact_tween.tween_property(interact_btn, "scale", base_scale * 0.8, 0.15)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	_interact_tween.chain().tween_callback(func():
		if interact_btn and not is_customizing and _interaction_count <= 0:
			interact_btn.visible = false
	)


func set_interact_suppressed(suppressed: bool) -> void:
	if suppressed:
		_force_hide_interact_button()
	else:
		if _interaction_count > 0:
			# Re-show
			_interaction_count -= 1
			show_interact_button()


# ==============================================================================
# XỬ LÝ SỰ KIỆN NHẬP (INPUT EVENT HANDLING)
# ==============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Lấy tọa độ con trỏ (Touch hoặc Mouse)
	var pointer_pos: Vector2 = Vector2.INF
	var is_pointer_event: bool = false

	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		pointer_pos = event.position
		is_pointer_event = true
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		pointer_pos = event.position
		is_pointer_event = true

	# --- 1. XỬ LÝ CHẾ ĐỘ TÙY CHỈNH (CUSTOMIZE MODE) ---
	if is_customizing:
		if is_pointer_event:
			# Nếu chạm vào vùng thanh điều khiển TopBar ("Lưu" / "Đặt lại"), cho UI Button tự nhận sự kiện
			if customize_top_bar and is_instance_valid(customize_top_bar):
				var top_bar_rect: Rect2 = customize_top_bar.get_global_rect()
				if top_bar_rect.has_point(pointer_pos):
					return

			# Chặn sự kiện không để rò rỉ vào game
			get_viewport().set_input_as_handled()
			_handle_customize_drag_input(event, pointer_pos)
		return

	# --- 2. XỬ LÝ GAMEPLAY BÌNH THƯỜNG ---
	var in_joystick_zone: bool = false
	var touched_btn: TouchScreenButton = null

	if is_pointer_event:
		in_joystick_zone = _is_in_joystick_zone(pointer_pos)
		touched_btn = _get_action_button_at(pointer_pos)

		# Chặn đòn đánh thường toàn màn hình khi chạm vào joystick hoặc nút ảo
		if in_joystick_zone or touched_btn != null:
			get_viewport().set_input_as_handled()

	# Multi-touch Mobile
	if event is InputEventScreenTouch:
		if event.pressed:
			if joystick_touch_id == -1 and in_joystick_zone:
				joystick_touch_id = event.index
				_update_joystick(event.position)
		else:
			if event.index == joystick_touch_id:
				_release_joystick()

	elif event is InputEventScreenDrag:
		if event.index == joystick_touch_id:
			_update_joystick(event.position)

	# PC Testing Fallback
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if joystick_touch_id == -1 and in_joystick_zone:
					joystick_touch_id = 9999
					_update_joystick(event.position)
				elif touched_btn != null:
					_active_mouse_btn = touched_btn
					if touched_btn.action != &"":
						Input.action_press(touched_btn.action)
					_on_btn_down(touched_btn)
			else:
				if joystick_touch_id == 9999:
					_release_joystick()
				if _active_mouse_btn != null:
					if _active_mouse_btn.action != &"":
						Input.action_release(_active_mouse_btn.action)
					_on_btn_up(_active_mouse_btn)
					_active_mouse_btn = null

	elif event is InputEventMouseMotion:
		if joystick_touch_id == 9999:
			_update_joystick(event.position)


# ==============================================================================
# LOGIC KÉO THẢ NÚT TRONG CHẾ ĐỘ TÙY CHỈNH (DRAG & DROP LOGIC)
# ==============================================================================

func _handle_customize_drag_input(event: InputEvent, pointer_pos: Vector2) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _drag_touch_id == -1:
				var item = _get_customizable_item_at(pointer_pos)
				if item:
					_drag_target = item
					_drag_touch_id = event.index
					_drag_offset = item.global_position - pointer_pos
					_highlight_item(item, true)
		else:
			if event.index == _drag_touch_id:
				if _drag_target:
					_highlight_item(_drag_target, false)
				_drag_target = null
				_drag_touch_id = -1

	elif event is InputEventScreenDrag:
		if event.index == _drag_touch_id and _drag_target:
			_move_customized_item(_drag_target, pointer_pos + _drag_offset)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _drag_touch_id == -1:
					var item = _get_customizable_item_at(pointer_pos)
					if item:
						_drag_target = item
						_drag_touch_id = 9999
						_drag_offset = item.global_position - pointer_pos
						_highlight_item(item, true)
			else:
				if _drag_touch_id == 9999:
					if _drag_target:
						_highlight_item(_drag_target, false)
					_drag_target = null
					_drag_touch_id = -1

	elif event is InputEventMouseMotion:
		if _drag_touch_id == 9999 and _drag_target:
			_move_customized_item(_drag_target, pointer_pos + _drag_offset)


func _get_customizable_item_at(screen_pos: Vector2) -> Node:
	# Kiểm tra TouchScreenButtons trước
	var buttons = [jump_btn, attack_btn, dash_btn, throw_btn, skill_btn, bind_btn, interact_btn]
	for btn in buttons:
		if btn and is_instance_valid(btn):
			var tex_size = btn.texture_normal.get_size() if btn.texture_normal else Vector2(512, 512)
			var btn_center: Vector2 = btn.global_position + (tex_size * 0.5 * btn.scale)
			var btn_radius: float = (tex_size.x * 0.5) * btn.scale.x * 1.3
			if screen_pos.distance_to(btn_center) <= btn_radius:
				return btn

	# Kiểm tra Joystick
	if joystick_container and is_instance_valid(joystick_container):
		var joy_center := joystick_container.global_position
		var joy_radius := 115.0
		if screen_pos.distance_to(joy_center) <= joy_radius:
			return joystick_container

	return null


func _move_customized_item(item: Node, target_pos: Vector2) -> void:
	if not is_instance_valid(item):
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	if item == joystick_container:
		var joy_radius: float = 100.0
		target_pos.x = clampf(target_pos.x, joy_radius, vp_size.x - joy_radius)
		target_pos.y = clampf(target_pos.y, joy_radius, vp_size.y - joy_radius)
		item.global_position = target_pos
	elif item is TouchScreenButton:
		var btn = item as TouchScreenButton
		var tex_size = btn.texture_normal.get_size() if btn.texture_normal else Vector2(512, 512)
		var btn_w: float = tex_size.x * btn.scale.x
		var btn_h: float = tex_size.y * btn.scale.y
		target_pos.x = clampf(target_pos.x, 0.0, vp_size.x - btn_w)
		target_pos.y = clampf(target_pos.y, 0.0, vp_size.y - btn_h)
		btn.global_position = target_pos


func _highlight_item(item: Node, active: bool) -> void:
	if not is_instance_valid(item):
		return
	var target_scale_mult = Vector2(1.15, 1.15) if active else Vector2(1.0, 1.0)
	var target_mod = Color(1.5, 1.4, 0.85, 1.0) if active else Color.WHITE

	var tw = create_tween().set_parallel(true)
	if item == joystick_container:
		if joystick_base:
			tw.tween_property(joystick_base, "scale", Vector2(0.38, 0.38) * target_scale_mult, 0.08)
			tw.tween_property(joystick_base, "modulate", target_mod, 0.08)
	elif item is TouchScreenButton:
		var orig_scale: Vector2 = _button_base_scales.get(item, item.scale)
		tw.tween_property(item, "scale", orig_scale * target_scale_mult, 0.08)
		tw.tween_property(item, "modulate", target_mod, 0.08)


# ==============================================================================
# HỖ TRỢ GAMEPLAY (JOYSTICK & FEEDBACK)
# ==============================================================================

func _is_in_joystick_zone(screen_pos: Vector2) -> bool:
	if not joystick_container:
		return false
	var center := joystick_container.global_position
	return screen_pos.distance_to(center) <= touch_zone_radius


func _get_action_button_at(screen_pos: Vector2) -> TouchScreenButton:
	var buttons = [jump_btn, attack_btn, dash_btn, throw_btn, skill_btn, bind_btn, interact_btn]
	for btn in buttons:
		if btn and is_instance_valid(btn):
			if btn == interact_btn and (not btn.visible or btn.modulate.a <= 0.05):
				continue
			var tex_size = btn.texture_normal.get_size() if btn.texture_normal else Vector2(512, 512)
			var btn_center: Vector2 = btn.global_position + (tex_size * 0.5 * btn.scale)
			var btn_radius: float = (tex_size.x * 0.5) * btn.scale.x * 1.15
			if screen_pos.distance_to(btn_center) <= btn_radius:
				return btn
	return null


func _update_joystick(screen_pos: Vector2) -> void:
	if not joystick_container or not joystick_knob:
		return

	if _snap_tween and _snap_tween.is_valid():
		_snap_tween.kill()

	var center := joystick_container.global_position
	var diff := screen_pos - center
	var dist := diff.length()

	if dist > joystick_radius:
		joystick_knob.position = diff.normalized() * joystick_radius
	else:
		joystick_knob.position = diff

	var input_vec := diff / joystick_radius
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	current_input_vector = input_vec

	if is_customizing:
		return

	# Trục Ngang
	if input_vec.x < -movement_threshold:
		var strength := clampf(absf(input_vec.x), 0.0, 1.0)
		Input.action_press(&"move_left", strength)
		Input.action_release(&"move_right")
	elif input_vec.x > movement_threshold:
		var strength := clampf(input_vec.x, 0.0, 1.0)
		Input.action_press(&"move_right", strength)
		Input.action_release(&"move_left")
	else:
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")

	# Trục Dọc
	if input_vec.y < -vertical_threshold:
		var strength := clampf(absf(input_vec.y), 0.0, 1.0)
		Input.action_press(&"move_up", strength)
		Input.action_release(&"move_down")
	elif input_vec.y > vertical_threshold:
		var strength := clampf(input_vec.y, 0.0, 1.0)
		Input.action_press(&"move_down", strength)
		Input.action_release(&"move_up")
	else:
		Input.action_release(&"move_up")
		Input.action_release(&"move_down")


func _release_joystick() -> void:
	joystick_touch_id = -1
	current_input_vector = Vector2.ZERO

	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")

	if joystick_knob:
		if _snap_tween and _snap_tween.is_valid():
			_snap_tween.kill()
		_snap_tween = create_tween()
		_snap_tween.tween_property(joystick_knob, "position", Vector2.ZERO, snap_back_duration)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)


func _setup_button_feedback() -> void:
	var buttons = [attack_btn, jump_btn, dash_btn, throw_btn, skill_btn, bind_btn, interact_btn]
	for btn in buttons:
		if btn and btn is TouchScreenButton:
			btn.pressed.connect(_on_btn_down.bind(btn))
			btn.released.connect(_on_btn_up.bind(btn))


func _on_btn_down(btn: TouchScreenButton) -> void:
	if not is_instance_valid(btn) or is_customizing:
		return
	var tw = create_tween()
	tw.tween_property(btn, "modulate", Color(1.35, 1.35, 1.35, 1.0), 0.04)


func _on_btn_up(btn: TouchScreenButton) -> void:
	if not is_instance_valid(btn) or is_customizing:
		return
	var tw = create_tween()
	tw.tween_property(btn, "modulate", Color.WHITE, 0.08)
