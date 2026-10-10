extends Area2D

@export var damage: int = 1
@export var warning_duration: float = 0.55
@export var erupt_duration: float = 0.5

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

var shoot_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/NightMare/spike_shoot_up.mp3")


func _ready() -> void:
	collision_shape.disabled = true
	body_entered.connect(_on_body_entered)
	_start_cycle()


func _start_cycle() -> void:
	# 1. Cảnh báo gai nhú lên
	if animated_sprite.sprite_frames.has_animation("warn"):
		animated_sprite.play("warn")
	
	await get_tree().create_timer(warning_duration).timeout
	if not is_instance_valid(self): return
	
	# 2. Phóng gai đâm thẳng lên và kích hoạt va chạm gây sát thương
	if sfx_player and shoot_sfx:
		sfx_player.stream = shoot_sfx
		sfx_player.play()
		
	if animated_sprite.sprite_frames.has_animation("erupt"):
		animated_sprite.play("erupt")
	collision_shape.disabled = false
	
	await get_tree().create_timer(erupt_duration).timeout
	if not is_instance_valid(self): return
	
	# 3. Thu gai lại và biến mất
	collision_shape.disabled = true
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body.name == "PlayerController" or body.name.begins_with("Player"):
		if body.has_method("take_damage") and ("is_invincible" not in body or not body.is_invincible):
			body.take_damage(damage, global_position)
