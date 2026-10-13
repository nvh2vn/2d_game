extends Area2D

enum TeleportType {
	SAME_SCENE,
	CHANGE_SCENE
}

@export_group("Teleport Settings")
@export var teleport_type: TeleportType = TeleportType.CHANGE_SCENE
@export_file("*.tscn") var target_scene_path: String = ""
@export var target_marker: Marker2D
@export var is_active: bool = true
@export var require_interaction: bool = false

var is_teleporting: bool = false
var is_player_in_range: bool = false
var current_player: Node2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
	if not require_interaction or not is_player_in_range or is_teleporting or not is_instance_valid(current_player):
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and (event.keycode in [KEY_E, KEY_UP, KEY_W])):
		TouchControls.hide_interact(get_tree())
		trigger_teleport(current_player)
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if not is_active or is_teleporting:
		return
	
	if body.is_in_group("player") or body.name == "PlayerController" or body.name.begins_with("Player"):
		current_player = body
		is_player_in_range = true
		if require_interaction:
			TouchControls.show_interact(get_tree(), "door")
		else:
			trigger_teleport(body)


func _on_body_exited(body: Node2D) -> void:
	if body == current_player:
		is_player_in_range = false
		current_player = null
		if require_interaction:
			TouchControls.hide_interact(get_tree())


func trigger_teleport(player: Node2D) -> void:
	is_teleporting = true
	
	# Hiệu ứng mờ dần nhân vật
	var sprite = player.get_node_or_null("%AnimatedSprite")
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
		await tween.finished
	
	match teleport_type:
		TeleportType.SAME_SCENE:
			if target_marker:
				if "velocity" in player:
					player.velocity = Vector2.ZERO
				player.global_position = target_marker.global_position
				
				# Hiện sáng lại nhân vật
				if sprite:
					var tween_in = create_tween()
					tween_in.tween_property(sprite, "modulate:a", 1.0, 0.2)
			is_teleporting = false
		
		TeleportType.CHANGE_SCENE:
			if target_scene_path != "":
				SaveManager.save_last_level(target_scene_path)
				get_tree().change_scene_to_file(target_scene_path)
			else:
				is_teleporting = false
