class_name ElevatorFastTravel
extends Node2D

## Thang máy di chuyển nhanh (Fast Travel Elevator)
## Hỗ trợ tương tác mượt mà qua bàn phím [E / UP] và Nút Tương Tác Ngữ Cảnh trên mobile.

signal elevator_started()
signal elevator_arrived()

@export_group("Elevator Settings")
@export var travel_offset: Vector2 = Vector2(0, -500)
@export var travel_duration: float = 3.5
@export var auto_return: bool = false
@export var auto_return_delay: float = 4.0

@onready var interact_area: Area2D = get_node_or_null("InteractArea")
@onready var interact_prompt: Label = get_node_or_null("InteractPrompt")
@onready var stand_point: Marker2D = get_node_or_null("StandPoint")
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

var is_player_in_range: bool = false
var current_player: Node2D = null
var is_moving: bool = false
var is_at_destination: bool = false

var original_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("elevators")
	original_pos = global_position
	target_pos = original_pos + travel_offset

	if interact_prompt:
		interact_prompt.visible = false

	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
		interact_area.area_entered.connect(_on_area_entered)
		interact_area.area_exited.connect(_on_area_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not is_player_in_range or is_moving or not is_instance_valid(current_player):
		return

	var is_interact: bool = event.is_action_pressed("interact") or event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and (event.keycode in [KEY_E, KEY_UP, KEY_W]))
	if is_interact:
		activate_elevator()
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

	if interact_prompt:
		interact_prompt.visible = in_range and not is_moving
		if in_range and not is_moving:
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			interact_prompt.scale = Vector2(0.5, 0.5)
			tw.tween_property(interact_prompt, "scale", Vector2.ONE, 0.15)

	if in_range and not is_moving:
		TouchControls.show_interact(get_tree(), "elevator")
	elif not in_range or is_moving:
		TouchControls.hide_interact(get_tree())


func activate_elevator() -> void:
	if is_moving:
		return

	is_moving = true
	TouchControls.hide_interact(get_tree())
	if interact_prompt:
		interact_prompt.visible = false

	var destination = original_pos if is_at_destination else target_pos

	if audio_player and audio_player.stream:
		audio_player.play()

	elevator_started.emit()

	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_position", destination, travel_duration)

	await tw.finished

	is_moving = false
	is_at_destination = not is_at_destination
	elevator_arrived.emit()

	if is_player_in_range:
		_set_in_range(true)

	if auto_return and is_at_destination:
		await get_tree().create_timer(auto_return_delay).timeout
		if not is_moving and is_at_destination:
			activate_elevator()
