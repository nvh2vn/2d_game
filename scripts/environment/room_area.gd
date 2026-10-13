@tool
class_name RoomArea
extends Area2D

## Hệ thống giới hạn Camera theo từng phòng và bục bậc thang (Room & Stepped Area Camera Bounds).
## Tự động tính toán 4 cạnh biên (Left, Top, Right, Bottom) và nội suy mượt mà (Smooth Limits Interpolation)
## bằng Tween khi người chơi di chuyển qua lại giữa các phòng hoặc nhảy lên bục cao / vực sâu.

# --- TÍN HIỆU (SIGNALS) ---
signal player_entered_room(room: RoomArea, bounds: Rect2i)
signal player_exited_room(room: RoomArea)

# --- QUẢN LÝ DANH SÁCH PHÒNG ĐANG HOẠT ĐỘNG (ROOM STACK & TWEEN) ---
static var active_rooms: Array[RoomArea] = []
static var current_active_room: RoomArea = null
static var active_tween: Tween = null

# --- CẤU HÌNH PHÒNG & ĐỘ ƯU TIÊN (ROOM SETTINGS & PRIORITY) ---
@export_group("Room Identity & Priority")
@export var room_name: String = "Unnamed Room":
	set(value):
		room_name = value
		queue_redraw()

## Độ ưu tiên của khu vực. Main Room phòng lớn = 0.
## Các bục bậc thang cao hơn (Sub-Areas/Stepped Platforms) = 1 (hoặc cao hơn).
## Khi người chơi đứng trong bục cao nằm trong phòng lớn, bục cao sẽ chiếm quyền camera.
## Khi người chơi nhảy xuống lại sàn chính, camera tự động trượt êm ái về lại phòng lớn.
@export var room_priority: int = 0:
	set(value):
		room_priority = value
		queue_redraw()

@export_group("Stepped Platform & Selective Overrides")
## Cho phép khu vực này ghi đè cạnh Trái
@export var override_limit_left: bool = true
## Cho phép khu vực này ghi đè cạnh Trên
@export var override_limit_top: bool = true
## Cho phép khu vực này ghi đè cạnh Phải
@export var override_limit_right: bool = true
## Cho phép khu vực này ghi đè cạnh Dưới (Rất quan trọng cho bục bậc thang/vực sâu)
@export var override_limit_bottom: bool = true

@export_group("Room Dimensions (Kích Thước Phòng)")
## Kích thước phòng (Rộng x Cao). Chỉnh trực tiếp tại Inspector mà không cần mở node con CollisionShape2D.
@export var room_size: Vector2 = Vector2(960, 540):
	set(value):
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

@export_group("Transition Smoothing (Tween Interpolation)")
## Bật chuyển đổi mượt mà giữa các giới hạn camera thay vì bị giật khung hình
@export var smooth_transition: bool = true
## Thời gian chuyển giao camera giữa 2 phòng/bục (khoảng 0.35s - 0.45s theo yêu cầu)
@export_range(0.1, 1.5, 0.05) var transition_duration: float = 0.4
## Kiểu chuyển động nội suy (Mặc định TRANS_SINE kết hợp EASE_OUT)
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

@export_group("Editor Debug Visuals")
## Hiển thị viền màu và tên phòng trực quan ngay trong Godot 2D Editor
@export var show_editor_debug: bool = true:
	set(value):
		show_editor_debug = value
		queue_redraw()
@export var debug_color: Color = Color(0.18, 0.8, 0.95, 0.22):
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

	if not Engine.is_editor_hint():
		# Layer va chạm của Player (Layer 3 bit value 4)
		set_collision_mask_value(3, true)
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	else:
		child_order_changed.connect(_on_child_order_changed)


func _on_child_order_changed() -> void:
	_connect_shape_changed()
	queue_redraw()


## Đảm bảo mỗi phòng có Shape riêng biệt (Local to Scene)
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


## Lắng nghe khi người dùng kéo handle CollisionShape2D trên màn hình 2D
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
	if not active_rooms.has(self):
		active_rooms.append(self)
	_recalculate_active_room(body)


func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return
	player_exited_room.emit(self)
	if active_rooms.has(self):
		active_rooms.erase(self)
	_recalculate_active_room(body)


## Kiểm tra xem body va chạm có phải là Player
func _is_player(node: Node) -> bool:
	return node.is_in_group("player") or node.name == "PlayerController" or node.name.begins_with("Player")


## Tính toán lại phòng có độ ưu tiên cao nhất trong danh sách các phòng Player đang đứng trong đó
static func _recalculate_active_room(player_node: Node2D = null) -> void:
	# Lọc bỏ các phòng đã bị free hoặc không còn trong scene tree
	active_rooms = active_rooms.filter(func(r: RoomArea) -> bool:
		return is_instance_valid(r) and r.is_inside_tree()
	)
	
	if active_rooms.is_empty():
		current_active_room = null
		return

	# Sắp xếp theo priority giảm dần (priority cao nhất sẽ đứng đầu danh sách)
	active_rooms.sort_custom(func(a: RoomArea, b: RoomArea) -> bool:
		return a.room_priority > b.room_priority
	)

	var target_room: RoomArea = active_rooms[0]
	if target_room != current_active_room:
		target_room.activate_room(player_node)


## Kích hoạt ranh giới camera của phòng/bục hiện tại
func activate_room(player_node: Node2D = null) -> void:
	current_active_room = self
	
	var bounds: Rect2i = get_room_bounds()
	var cam: Camera2D = _find_camera(player_node)
	
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


## Cập nhật các giới hạn camera mượt mà bằng Tween (Không bao giờ gán đứt đoạn)
func _apply_camera_bounds(cam: Camera2D, target_bounds: Rect2i) -> void:
	if not is_instance_valid(cam):
		return

	var raw_left: int = target_bounds.position.x
	var raw_top: int = target_bounds.position.y
	var raw_right: int = target_bounds.size.x
	var raw_bottom: int = target_bounds.size.y
	
	# Đảm bảo kích thước tối thiểu bằng màn hình để tránh rung giật camera khi phòng nhỏ
	var vp_size = Vector2(640, 360)
	if cam.is_inside_tree():
		var vp = cam.get_viewport()
		if vp:
			vp_size = vp.get_visible_rect().size / cam.zoom
	var min_w = int(vp_size.x)
	var min_h = int(vp_size.y)
	
	if (raw_right - raw_left) < min_w:
		var mid_x = (raw_left + raw_right) / 2
		raw_left = mid_x - min_w / 2
		raw_right = raw_left + min_w
		
	if (raw_bottom - raw_top) < min_h:
		var mid_y = (raw_top + raw_bottom) / 2
		raw_top = mid_y - min_h / 2
		raw_bottom = raw_top + min_h

	# Tính toán 4 cạnh đích cuối cùng dựa trên cấu hình Override của khu vực
	# Nếu một cạnh không được override (ví dụ bục bậc thang chỉ nâng/hạ limit_bottom),
	# cạnh đó sẽ giữ nguyên vị trí hiện tại của Camera mà không ép buộc co cụm.
	var final_target_left: int = raw_left if override_limit_left else cam.limit_left
	var final_target_top: int = raw_top if override_limit_top else cam.limit_top
	var final_target_right: int = raw_right if override_limit_right else cam.limit_right
	var final_target_bottom: int = raw_bottom if override_limit_bottom else cam.limit_bottom

	# Nếu camera trước đó đang ở giới hạn mặc định vô hạn (chưa gán lần nào),
	# khởi tạo điểm bắt đầu từ tầm nhìn màn hình hiện tại của camera để tween mượt mà,
	# TUYỆT ĐỐI không gán đứt đoạn gây giật camera.
	var cam_center = cam.get_screen_center_position()
	var half_vp = vp_size * 0.5
	if abs(cam.limit_left) > 1000000:
		cam.limit_left = int(cam_center.x - half_vp.x - 100)
	if abs(cam.limit_right) > 1000000:
		cam.limit_right = int(cam_center.x + half_vp.x + 100)
	if abs(cam.limit_top) > 1000000:
		cam.limit_top = int(cam_center.y - half_vp.y - 100)
	if abs(cam.limit_bottom) > 1000000:
		cam.limit_bottom = int(cam_center.y + half_vp.y + 100)

	# KIỂM TRA AN TOÀN: Nếu có tween đổi limit cũ đang chạy (is_running()), hãy gọi kill()
	# trước khi khởi tạo tween mới để tránh xung đột làm rung giật camera khi di chuyển qua lại ranh giới liên tục.
	if active_tween and active_tween.is_valid() and active_tween.is_running():
		active_tween.kill()

	# Khởi tạo Tween nội suy mượt mà từng pixel cho cả 4 cạnh giới hạn theo thời gian thực
	active_tween = cam.create_tween().set_trans(transition_type).set_ease(ease_type)
	active_tween.tween_property(cam, "limit_left", final_target_left, transition_duration)
	active_tween.parallel().tween_property(cam, "limit_top", final_target_top, transition_duration)
	active_tween.parallel().tween_property(cam, "limit_right", final_target_right, transition_duration)
	active_tween.parallel().tween_property(cam, "limit_bottom", final_target_bottom, transition_duration)


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
		
		# Tùy biến màu theo Priority: Phòng chính (room_priority=0) màu Cyan, Sub-Area (room_priority>0) màu Amber ấm
		var fill_col = debug_color if room_priority == 0 else Color(0.95, 0.75, 0.2, 0.25)
		var border_col = debug_border_color if room_priority == 0 else Color(1.0, 0.82, 0.3, 0.95)
		
		draw_rect(local_rect, fill_col, true)
		draw_rect(local_rect, border_col, false, 2.5)
		
		# Nhãn tên phòng và cấp độ ưu tiên
		if room_name != "":
			var font = ThemeDB.fallback_font
			var font_size = 15
			var text_pos = local_rect.position + Vector2(10, 22)
			var type_str = "Main Room" if room_priority == 0 else "Sub-Area (Priority %d)" % room_priority
			draw_string(font, text_pos, " [%s: %s] (%dx%d)" % [type_str, room_name, int(s.x), int(s.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, border_col)
