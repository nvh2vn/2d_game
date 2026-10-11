@tool
class_name RoomArea
extends Area2D

## Hệ thống giới hạn Camera theo từng phòng (Room-Based Camera Bounds) chuẩn phong cách Hollow Knight.
## Tự động tính toán 4 cạnh biên (Left, Top, Right, Bottom) và nội suy mượt mà (Smoothing Interpolation)
## cho Camera2D của người chơi khi bước qua ranh giới các phòng.

# --- TÍN HIỆU (SIGNALS) ---
signal player_entered_room(room: RoomArea, bounds: Rect2i)
signal player_exited_room(room: RoomArea)

# --- BIẾN TOÀN CỤC QUẢN LÝ PHÒNG ĐANG HOẠT ĐỘNG ---
static var current_active_room: RoomArea = null
static var active_tween: Tween = null

# --- CẤU HÌNH PHÒNG (ROOM SETTINGS) ---
@export_group("Room Identity")
@export var room_name: String = "Unnamed Room":
	set(value):
		room_name = value
		queue_redraw()

@export_group("Room Dimensions (Kích Thước Phòng)")
## Kích thước phòng (Rộng x Cao). Bạn có thể chỉnh trực tiếp tại đây trong Inspector 
## mà KHÔNG CẦN phải mở node con CollisionShape2D!
@export var room_size: Vector2 = Vector2(960, 540):
	set(value):
		# Giới hạn kích thước tối thiểu để tránh lỗi shape âm
		room_size = Vector2(maxf(value.x, 32.0), maxf(value.y, 32.0))
		_apply_room_size_to_shape()
		queue_redraw()

@export_group("Camera Target & Calculation")
## Nếu để trống, script sẽ tự động tìm Camera2D của Player hoặc Camera2D đang active trong Viewport
@export var custom_camera: Camera2D = null

## Tự động tính toán 4 biên camera dựa trên CollisionShape2D con
@export var auto_calculate_bounds: bool = true:
	set(value):
		auto_calculate_bounds = value
		notify_property_list_changed()
		queue_redraw()

## Node CollisionShape2D chỉ định làm ranh giới phòng (Mặc định tự tìm node con đầu tiên)
@export var custom_collision_shape: CollisionShape2D = null:
	set(value):
		custom_collision_shape = value
		_connect_shape_changed()
		queue_redraw()

@export_group("Manual Offsets & Overrides")
## Bù trừ cạnh Trái (px)
@export var offset_left: int = 0:
	set(value):
		offset_left = value
		queue_redraw()
## Bù trừ cạnh Trên (px)
@export var offset_top: int = 0:
	set(value):
		offset_top = value
		queue_redraw()
## Bù trừ cạnh Phải (px)
@export var offset_right: int = 0:
	set(value):
		offset_right = value
		queue_redraw()
## Bù trừ cạnh Dưới (px)
@export var offset_bottom: int = 0:
	set(value):
		offset_bottom = value
		queue_redraw()

## Nếu tắt auto_calculate_bounds, sẽ sử dụng 4 giá trị thủ công này:
@export var manual_limit_left: int = -10000000
@export var manual_limit_top: int = -10000000
@export var manual_limit_right: int = 10000000
@export var manual_limit_bottom: int = 10000000

@export_group("Transition Smoothing (Hollow Knight Style)")
## Bật chuyển đổi mượt mà giữa các giới hạn camera thay vì bị giật khung hình tức thì
@export var smooth_transition: bool = true
## Thời gian chuyển giao camera giữa 2 phòng (giây)
@export_range(0.05, 2.0, 0.05) var transition_duration: float = 0.45
## Kiểu chuyển động nội suy
@export var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

@export_group("Editor Debug Visuals")
## Hiển thị viền màu và tên phòng trực quan ngay trong Godot 2D Editor
@export var show_editor_debug: bool = true:
	set(value):
		show_editor_debug = value
		queue_redraw()
@export var debug_color: Color = Color(0.18, 0.8, 0.95, 0.25):
	set(value):
		debug_color = value
		queue_redraw()
@export var debug_border_color: Color = Color(0.2, 0.9, 1.0, 0.9):
	set(value):
		debug_border_color = value
		queue_redraw()


func _ready() -> void:
	_ensure_unique_shape()
	_sync_initial_size()
	_connect_shape_changed()

	# Đảm bảo mask nhận diện được Layer 4 (PlayerController)
	if not Engine.is_editor_hint():
		set_collision_mask_value(3, true) # Layer 4 (bit 3)
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	else:
		child_order_changed.connect(_on_child_order_changed)


func _on_child_order_changed() -> void:
	_connect_shape_changed()
	queue_redraw()


## Đảm bảo mỗi phòng có Shape riêng biệt (Local to Scene), tránh bị đổi kích thước chùm
func _ensure_unique_shape() -> void:
	var shape_node = _get_active_collision_shape()
	if shape_node and shape_node.shape:
		if Engine.is_editor_hint() and not shape_node.shape.resource_local_to_scene:
			shape_node.shape = shape_node.shape.duplicate()
			shape_node.shape.resource_local_to_scene = true


## Đồng bộ kích thước ban đầu giữa CollisionShape và biến room_size
func _sync_initial_size() -> void:
	var shape_node = _get_active_collision_shape()
	if shape_node and shape_node.shape is RectangleShape2D:
		var rect = shape_node.shape as RectangleShape2D
		if room_size != rect.size:
			room_size = rect.size


## Cập nhật kích thước từ biến room_size xuống CollisionShape2D
func _apply_room_size_to_shape() -> void:
	var shape_node = _get_active_collision_shape()
	if not shape_node:
		return
		
	if not shape_node.shape:
		var new_rect = RectangleShape2D.new()
		new_rect.size = room_size
		new_rect.resource_local_to_scene = true
		shape_node.shape = new_rect
	elif shape_node.shape is RectangleShape2D:
		var rect = shape_node.shape as RectangleShape2D
		if rect.size != room_size:
			rect.size = room_size


## Lắng nghe khi người dùng kéo tay các handle của CollisionShape2D trên màn hình 2D
func _connect_shape_changed() -> void:
	var shape_node = _get_active_collision_shape()
	if shape_node and shape_node.shape:
		if not shape_node.shape.changed.is_connected(_on_shape_resource_changed):
			shape_node.shape.changed.connect(_on_shape_resource_changed)


func _on_shape_resource_changed() -> void:
	var shape_node = _get_active_collision_shape()
	if shape_node and shape_node.shape is RectangleShape2D:
		var current_size = (shape_node.shape as RectangleShape2D).size
		if room_size != current_size:
			room_size = current_size
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	activate_room(body)


func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return
	player_exited_room.emit(self)


## Kiểm tra xem body va chạm có phải là Player
func _is_player(node: Node) -> bool:
	return node.is_in_group("player") or node.name == "PlayerController" or node.name.begins_with("Player")


## Kích hoạt ranh giới camera của phòng hiện tại
func activate_room(player_node: Node2D = null) -> void:
	current_active_room = self
	
	var bounds = get_room_bounds()
	var cam = _find_camera(player_node)
	
	if not cam:
		push_warning("[RoomArea] '%s': Không tìm thấy Camera2D hợp lệ!" % room_name)
		player_entered_room.emit(self, bounds)
		return
		
	player_entered_room.emit(self, bounds)
	_apply_camera_bounds(cam, bounds)


## Tính toán tọa độ thế giới (Global Position) 4 cạnh: Left, Top, Right, Bottom
func get_room_bounds() -> Rect2i:
	if not auto_calculate_bounds:
		return Rect2i(
			manual_limit_left + offset_left,
			manual_limit_top + offset_top,
			manual_limit_right + offset_right,
			manual_limit_bottom + offset_bottom
		)
		
	var shape_node = _get_active_collision_shape()
	if not shape_node or not shape_node.shape:
		return Rect2i(manual_limit_left, manual_limit_top, manual_limit_right, manual_limit_bottom)
		
	var shape = shape_node.shape
	var center = shape_node.global_position
	var half_size = Vector2.ZERO
	
	if shape is RectangleShape2D:
		var s = (shape as RectangleShape2D).size
		half_size.x = (s.x * abs(shape_node.global_scale.x)) * 0.5
		half_size.y = (s.y * abs(shape_node.global_scale.y)) * 0.5
	else:
		var r = shape.get_rect()
		half_size.x = (r.size.x * abs(shape_node.global_scale.x)) * 0.5
		half_size.y = (r.size.y * abs(shape_node.global_scale.y)) * 0.5
		
	var left_bound = int(round(center.x - half_size.x)) + offset_left
	var top_bound = int(round(center.y - half_size.y)) + offset_top
	var right_bound = int(round(center.x + half_size.x)) + offset_right
	var bottom_bound = int(round(center.y + half_size.y)) + offset_bottom
	
	# Đảm bảo phòng tối thiểu không bị ngược (Left <= Right, Top <= Bottom)
	if left_bound > right_bound:
		var temp = left_bound
		left_bound = right_bound
		right_bound = temp
	if top_bound > bottom_bound:
		var temp_y = top_bound
		top_bound = bottom_bound
		bottom_bound = temp_y
		
	return Rect2i(left_bound, top_bound, right_bound, bottom_bound)


## Cập nhật các giới hạn camera với tính năng chuyển giao mượt mà (Smoothing)
func _apply_camera_bounds(cam: Camera2D, target_bounds: Rect2i) -> void:
	var target_left = target_bounds.position.x
	var target_top = target_bounds.position.y
	var target_right = target_bounds.size.x
	var target_bottom = target_bounds.size.y
	
	# Đảm bảo kích thước tối thiểu bằng màn hình để tránh rung lắc camera khi phòng nhỏ
	var vp_size = Vector2(640, 360)
	if cam.is_inside_tree():
		var vp = cam.get_viewport()
		if vp:
			vp_size = vp.get_visible_rect().size / cam.zoom
	var min_w = int(vp_size.x)
	var min_h = int(vp_size.y)
	
	if (target_right - target_left) < min_w:
		var mid_x = (target_left + target_right) / 2
		target_left = mid_x - min_w / 2
		target_right = target_left + min_w
		
	if (target_bottom - target_top) < min_h:
		var mid_y = (target_top + target_bottom) / 2
		target_top = mid_y - min_h / 2
		target_bottom = target_top + min_h

	# Nếu không bật smooth, cập nhật trực tiếp ngay lập tức
	if not smooth_transition or transition_duration <= 0.0:
		cam.limit_left = target_left
		cam.limit_top = target_top
		cam.limit_right = target_right
		cam.limit_bottom = target_bottom
		return
		
	# Hủy Tween cũ nếu người chơi chuyển phòng liên tục
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	var start_left = cam.limit_left
	var start_top = cam.limit_top
	var start_right = cam.limit_right
	var start_bottom = cam.limit_bottom
	
	# Nếu lần đầu tiên camera chưa được gán giới hạn hợp lệ
	if abs(start_left) > 1000000 or abs(start_right) > 1000000:
		cam.limit_left = target_left
		cam.limit_top = target_top
		cam.limit_right = target_right
		cam.limit_bottom = target_bottom
		return
		
	# Tween nội suy mượt mà từng pixel cho cả 4 cạnh giới hạn theo thời gian thực
	active_tween = create_tween().set_trans(transition_type).set_ease(ease_type)
	active_tween.tween_method(func(progress: float):
		if not is_instance_valid(cam):
			return
		cam.limit_left = int(lerpf(start_left, target_left, progress))
		cam.limit_top = int(lerpf(start_top, target_top, progress))
		cam.limit_right = int(lerpf(start_right, target_right, progress))
		cam.limit_bottom = int(lerpf(start_bottom, target_bottom, progress))
	, 0.0, 1.0, transition_duration)


## Tự động tìm kiếm Camera2D theo nhiều cơ chế linh hoạt
func _find_camera(player_node: Node2D = null) -> Camera2D:
	if custom_camera and is_instance_valid(custom_camera):
		return custom_camera
		
	# 1. Tìm trong Player node
	if player_node and is_instance_valid(player_node):
		var p_cam = player_node.get_node_or_null("%Camera2D")
		if p_cam and p_cam is Camera2D:
			return p_cam
		for child in player_node.get_children():
			if child is Camera2D:
				return child
			for sub in child.get_children():
				if sub is Camera2D:
					return sub
					
	# 2. Tìm camera active trong Viewport
	if is_inside_tree():
		var vp = get_viewport()
		if vp and vp.get_camera_2d():
			return vp.get_camera_2d()
			
	# 3. Tìm qua Group "camera" hoặc "player_camera"
	if is_inside_tree() and get_tree():
		var cam_group = get_tree().get_nodes_in_group("camera")
		if cam_group.size() > 0 and cam_group[0] is Camera2D:
			return cam_group[0]
			
		var p_cam_group = get_tree().get_nodes_in_group("player_camera")
		if p_cam_group.size() > 0 and p_cam_group[0] is Camera2D:
			return p_cam_group[0]
			
		# 4. Tìm Player trong scene rồi trỏ tới Camera2D
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var p = players[0]
			var c = p.get_node_or_null("%Camera2D")
			if c and c is Camera2D:
				return c
				
	return null


func _get_active_collision_shape() -> CollisionShape2D:
	if custom_collision_shape and is_instance_valid(custom_collision_shape):
		return custom_collision_shape
	for child in get_children():
		if child is CollisionShape2D and not child.disabled:
			return child
	return null


# --- VẼ PREVIEW TRỰC QUAN TRONG GODOT 2D EDITOR ---
func _draw() -> void:
	if not Engine.is_editor_hint() or not show_editor_debug:
		return
		
	var shape_node = _get_active_collision_shape()
	if not shape_node or not shape_node.shape:
		return
		
	var shape = shape_node.shape
	if shape is RectangleShape2D:
		var rect_shape = shape as RectangleShape2D
		var shape_pos = shape_node.position
		var s = rect_shape.size * shape_node.scale
		
		var local_rect = Rect2(
			shape_pos.x - s.x * 0.5 + offset_left,
			shape_pos.y - s.y * 0.5 + offset_top,
			s.x + (offset_right - offset_left),
			s.y + (offset_bottom - offset_top)
		)
		
		# Nền trong suốt màu cyan phong cách Hollow Knight
		draw_rect(local_rect, debug_color, true)
		# Đường viền phòng
		draw_rect(local_rect, debug_border_color, false, 2.5)
		
		# Nhãn tên phòng
		if room_name != "":
			var font = ThemeDB.fallback_font
			var font_size = 16
			var text_pos = local_rect.position + Vector2(10, 24)
			draw_string(font, text_pos, " [Room: " + room_name + "] (" + str(int(s.x)) + "x" + str(int(s.y)) + ")", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, debug_border_color)
