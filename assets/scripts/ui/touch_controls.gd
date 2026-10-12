class_name TouchControls
extends CanvasLayer

## Mobile On-Touch Screen Controls
## Tương thích 100% với PlayerController và hệ thống InputMap của Godot 4.
## Tự động chặn sự kiện chạm/click để không kích hoạt đòn đánh thường toàn màn hình.

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

# Trạng thái Joystick
var joystick_touch_id: int = -1
var current_input_vector: Vector2 = Vector2.ZERO
var _snap_tween: Tween = null

# Trạng thái chuột cho Action Buttons (cho PC testing)
var _active_mouse_btn: TouchScreenButton = null


func _ready() -> void:
	# 1. Tự động kiểm tra thiết bị: Hiển thị trên Android/iOS hoặc màn hình cảm ứng
	var is_mobile: bool = OS.get_name() in ["Android", "iOS"] or DisplayServer.is_touchscreen_available()
	visible = is_mobile or force_show
	
	if control_root:
		control_root.modulate.a = controls_alpha

	_setup_button_feedback()


func _notification(what: int) -> void:
	# Đảm bảo an toàn khi mất focus cửa sổ hoặc tạm dừng game
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_joystick()
		if _active_mouse_btn:
			Input.action_release(_active_mouse_btn.action)
			_on_btn_up(_active_mouse_btn)
			_active_mouse_btn = null


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

	# Kiểm tra xem chạm/click có nằm trong phạm vi Joystick hoặc Action Buttons không
	var in_joystick_zone: bool = false
	var touched_btn: TouchScreenButton = null

	if is_pointer_event:
		in_joystick_zone = _is_in_joystick_zone(pointer_pos)
		touched_btn = _get_action_button_at(pointer_pos)

		# CHẶN SỰ KIỆN: Nếu chạm/click vào nút ảo hoặc joystick, chặn ngay không cho truyền xuống
		# để không bao giờ bị kích hoạt đòn đánh thường toàn màn hình (unhandled_input)
		if in_joystick_zone or touched_btn != null:
			get_viewport().set_input_as_handled()

	# --- 1. Xử lý Cảm ứng Đa chạm (Multi-touch) trên Mobile ---
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

	# --- 2. Xử lý Fallback Chuột cho PC Testing ---
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Chuột nhấn vào Joystick
				if joystick_touch_id == -1 and in_joystick_zone:
					joystick_touch_id = 9999
					_update_joystick(event.position)
				# Chuột nhấn vào Action Button trên PC
				elif touched_btn != null:
					_active_mouse_btn = touched_btn
					Input.action_press(touched_btn.action)
					_on_btn_down(touched_btn)
			else:
				# Chuột nhả
				if joystick_touch_id == 9999:
					_release_joystick()
				if _active_mouse_btn != null:
					Input.action_release(_active_mouse_btn.action)
					_on_btn_up(_active_mouse_btn)
					_active_mouse_btn = null

	elif event is InputEventMouseMotion:
		if joystick_touch_id == 9999:
			_update_joystick(event.position)


func _is_in_joystick_zone(screen_pos: Vector2) -> bool:
	if not joystick_container:
		return false
	var center := joystick_container.global_position
	# Kiểm tra bán kính quanh tâm
	if screen_pos.distance_to(center) <= touch_zone_radius:
		return true
	# Hoặc vùng góc dưới bên trái màn hình
	var vp_size := get_viewport().get_visible_rect().size
	if screen_pos.x <= vp_size.x * 0.32 and screen_pos.y >= vp_size.y * 0.45:
		return true
	return false


func _get_action_button_at(screen_pos: Vector2) -> TouchScreenButton:
	var buttons = [jump_btn, attack_btn, dash_btn, throw_btn, skill_btn]
	for btn in buttons:
		if btn and is_instance_valid(btn):
			# Tính tâm và bán kính va chạm của nút
			var btn_center: Vector2 = btn.global_position + (Vector2(256, 256) * btn.scale)
			var btn_radius: float = 256.0 * btn.scale.x * 1.15
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

	# Giới hạn (clamp) trong bán kính của Base
	if dist > joystick_radius:
		joystick_knob.position = diff.normalized() * joystick_radius
	else:
		joystick_knob.position = diff

	# Vector chuẩn hóa từ -1.0 đến 1.0
	var input_vec := diff / joystick_radius
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()
		
	current_input_vector = input_vec

	# 1. Trục Ngang (Horizontal Movement)
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

	# 2. Trục Dọc (Vertical: Hướng ngước nhìn, ngồi ghế, chém lên, chém xuống/pogo)
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

	# Hủy toàn bộ hành động di chuyển
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")

	# Đàn hồi mượt mà về tâm
	if joystick_knob:
		if _snap_tween and _snap_tween.is_valid():
			_snap_tween.kill()
		_snap_tween = create_tween()
		_snap_tween.tween_property(joystick_knob, "position", Vector2.ZERO, snap_back_duration)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)


func _setup_button_feedback() -> void:
	var buttons = [attack_btn, jump_btn, dash_btn, throw_btn, skill_btn]
	for btn in buttons:
		if btn and btn is TouchScreenButton:
			btn.pressed.connect(_on_btn_down.bind(btn))
			btn.released.connect(_on_btn_up.bind(btn))


func _on_btn_down(btn: TouchScreenButton) -> void:
	if not is_instance_valid(btn):
		return
	var tw = create_tween()
	tw.tween_property(btn, "modulate", Color(1.35, 1.35, 1.35, 1.0), 0.04)


func _on_btn_up(btn: TouchScreenButton) -> void:
	if not is_instance_valid(btn):
		return
	var tw = create_tween()
	tw.tween_property(btn, "modulate", Color.WHITE, 0.08)
