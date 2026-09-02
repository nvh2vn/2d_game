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

var is_teleporting: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not is_active or is_teleporting:
		return
	
	if body.is_in_group("player") or body.name == "PlayerController" or body.name.begins_with("Player"):
		trigger_teleport(body)


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
