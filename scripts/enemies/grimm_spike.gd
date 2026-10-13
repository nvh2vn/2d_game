extends Area2D

@export var damage: int = 1
@export var warning_duration: float = 0.5
@export var erupt_duration: float = 0.45

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var telegraph_line: Line2D = get_node_or_null("TelegraphLine")

var shoot_sfx: AudioStream = preload("res://assets/audio/nightmare/spike_shoot_up.mp3")


func _ready() -> void:
	collision_shape.disabled = true
	body_entered.connect(_on_body_entered)
	_start_cycle()


func _start_cycle() -> void:
	# 1. Telegraph / Cảnh báo: Hiện gai nhú hoặc vệt đỏ trên sàn
	if telegraph_line:
		telegraph_line.visible = true
		var tw_line = create_tween()
		tw_line.tween_property(telegraph_line, "default_color:a", 0.9, warning_duration * 0.7)
		tw_line.tween_property(telegraph_line, "default_color:a", 0.2, warning_duration * 0.3)
		
	if animated_sprite and animated_sprite.sprite_frames.has_animation("warn"):
		animated_sprite.play("warn")
		
	await get_tree().create_timer(warning_duration).timeout
	if not is_inside_tree() or not is_instance_valid(self):
		return
		
	if telegraph_line:
		telegraph_line.visible = false
		
	# 2. Phóng gai đâm vút lên khỏi mặt đất và kích hoạt va chạm
	if sfx_player and shoot_sfx:
		sfx_player.stream = shoot_sfx
		sfx_player.play()
		
	if animated_sprite and animated_sprite.sprite_frames.has_animation("erupt"):
		animated_sprite.play("erupt")
		
	collision_shape.disabled = false
	
	# Rung nhẹ camera khi gai đâm lên
	var cam = get_viewport().get_camera_2d()
	if cam:
		var tw_cam = create_tween()
		tw_cam.tween_property(cam, "offset", Vector2(0, -2.5), 0.04)
		tw_cam.tween_property(cam, "offset", Vector2.ZERO, 0.04)
		
	await get_tree().create_timer(erupt_duration).timeout
	if not is_inside_tree() or not is_instance_valid(self):
		return
		
	# 3. Thu gai lại và mờ dần
	collision_shape.disabled = true
	if animated_sprite and animated_sprite.sprite_frames.has_animation("retract"):
		animated_sprite.play("retract")
		
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body.name == "PlayerController" or body.name.begins_with("Player"):
		if body.has_method("take_damage") and ("is_invincible" not in body or not body.is_invincible):
			body.take_damage(damage, global_position)
