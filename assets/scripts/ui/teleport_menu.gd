extends CanvasLayer
class_name TeleportMenu

@onready var background: ColorRect = get_node_or_null("%Background")
@onready var list_container: VBoxContainer = get_node_or_null("%DestinationList")
@onready var close_button: Button = get_node_or_null("%CloseButton")

var current_player: Node2D = null
var current_wp_id: String = ""

func _ready() -> void:
	layer = 105
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

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
		empty_lbl.text = "Chưa có điểm dịch chuyển nào khác được mở khóa"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list_container.add_child(empty_lbl)
		return
		
	for wp in waypoints:
		var btn = Button.new()
		var is_current = (wp["id"] == current_wp_id)
		
		if is_current:
			btn.text = "📍 " + str(wp["name"]) + " (Vị trí hiện tại)"
			btn.disabled = true
		else:
			btn.text = "🌀 " + str(wp["name"])
			btn.pressed.connect(_on_destination_selected.bind(wp))
			
		btn.custom_minimum_size = Vector2(320, 48)
		list_container.add_child(btn)

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
