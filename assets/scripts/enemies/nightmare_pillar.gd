extends Area2D

@export var damage: int = 1
@export var warning_time: float = 0.4
@export var active_time: float = 0.6

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

var flame_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/NightMare/fireball_cast.mp3")


func _ready() -> void:
	collision_shape.disabled = true
	body_entered.connect(_on_body_entered)
	_start_pillar()


func _start_pillar() -> void:
	# Bắt đầu với hiệu ứng mờ nhấp nháy cảnh báo
	modulate = Color(2.0, 0.5, 0.5, 0.4)
	scale = Vector2(0.5, 1.0)
	
	var warn_tw = create_tween()
	warn_tw.tween_property(self, "scale:x", 1.0, warning_time)
	await warn_tw.finished
	if not is_instance_valid(self): return
	
	# Bùng cháy toàn diện
	modulate = Color.WHITE
	collision_shape.disabled = false
	if sfx_player and flame_sfx:
		sfx_player.stream = flame_sfx
		sfx_player.play()
		
	if animated_sprite and animated_sprite.sprite_frames.has_animation("burn"):
		animated_sprite.play("burn")
		
	await get_tree().create_timer(active_time).timeout
	if not is_instance_valid(self): return
	
	collision_shape.disabled = true
	var fade_tw = create_tween()
	fade_tw.tween_property(self, "modulate:a", 0.0, 0.25)
	fade_tw.tween_callback(queue_free)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body.name == "PlayerController" or body.name.begins_with("Player"):
		if body.has_method("take_damage") and ("is_invincible" not in body or not body.is_invincible):
			body.take_damage(damage, global_position)
