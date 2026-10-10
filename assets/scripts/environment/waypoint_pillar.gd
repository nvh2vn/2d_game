extends Area2D
class_name WaypointPillar

signal waypoint_activated(wp_id: String)

@export_group("Waypoint Config")
@export var waypoint_id: String = "area_1_pillar"
@export var waypoint_display_name: String = "Khu Vực 1"
@export var marker_id: String = "wp_1"
@export var teleport_menu_scene: PackedScene = preload("res://assets/scenes/ui/teleport_menu.tscn")

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var spawn_point: Marker2D = get_node_or_null("SpawnPoint")
@onready var interact_prompt: Node2D = get_node_or_null("InteractPrompt")
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

var is_player_in_range: bool = false
var current_player: Node2D = null

func _ready() -> void:
	add_to_group("waypoints")
	collision_layer = 4
	collision_mask = 255
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	if interact_prompt:
		interact_prompt.visible = false
		
	# Tự động tạo unique ID nếu kéo nhiều Trụ vào cùng 1 Scene mà không sửa ID thủ công trong Inspector
	_ensure_unique_waypoint_id()
	_setup_nodes_if_missing()

func _ensure_unique_waypoint_id() -> void:
	var scene_name = get_tree().current_scene.name if get_tree().current_scene else "scene"
	
	# Nếu dùng ID mặc định hoặc rỗng, sinh ID độc nhất dựa trên tên node đặt trên Scene
	if waypoint_id == "area_1_pillar" or waypoint_id == "":
		waypoint_id = scene_name.to_lower() + "_" + name.to_lower()
	if marker_id == "wp_1" or marker_id == "":
		marker_id = name
	if waypoint_display_name == "Khu Vực 1" or waypoint_display_name == "":
		var clean_name = name.capitalize()
		waypoint_display_name = scene_name.capitalize() + " - " + clean_name

func _setup_nodes_if_missing() -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		var tex = load("res://assets/art/map_1/Dirtmouth/bretta_pillar.png")
		if tex:
			sprite.texture = tex
		add_child(sprite)
		
	if spawn_point == null:
		spawn_point = Marker2D.new()
		spawn_point.name = "SpawnPoint"
		spawn_point.position = Vector2(0, 10)
		add_child(spawn_point)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_in_range or not is_instance_valid(current_player):
		return
		
	var is_interact: bool = event.is_action_pressed("ui_up") or event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and (event.keycode in [KEY_E, KEY_UP, KEY_W]))
	if is_interact:
		_open_teleport_menu()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		current_player = body
		_set_in_range(true)

func _on_body_exited(body: Node2D) -> void:
	if body == current_player:
		_set_in_range(false)

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent and _is_player(parent):
		current_player = parent
		_set_in_range(true)

func _on_area_exited(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent == current_player:
		_set_in_range(false)

func _is_player(node: Node2D) -> bool:
	return node.is_in_group("player") or node.name.begins_with("Player") or node.has_method("trigger_hazard_reset")

func _set_in_range(in_range: bool) -> void:
	is_player_in_range = in_range
	if in_range:
		# Automatically unlock waypoint when visited
		var cur_scene = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		var tm = get_node_or_null("/root/TeleportManager")
		if tm and tm.has_method("unlock_waypoint"):
			tm.unlock_waypoint(waypoint_id, waypoint_display_name, cur_scene, marker_id)

	if interact_prompt:
		interact_prompt.visible = in_range
		if in_range:
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			interact_prompt.scale = Vector2(0.5, 0.5)
			tw.tween_property(interact_prompt, "scale", Vector2.ONE, 0.15)

func _open_teleport_menu() -> void:
	var existing_menu = get_tree().current_scene.find_child("TeleportMenu", true, false)
	if existing_menu:
		return
		
	if teleport_menu_scene:
		var menu_inst = teleport_menu_scene.instantiate()
		get_tree().current_scene.add_child(menu_inst)
		if menu_inst.has_method("open_menu"):
			menu_inst.open_menu(waypoint_id, current_player)
