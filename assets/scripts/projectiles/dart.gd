extends Area2D

@export var speed: float = 700.0
@export var damage: int = 1
@export var lifetime: float = 1.2
@export var hit_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Player/sound_darthit.mp3")

var direction: Vector2 = Vector2.RIGHT
var is_destroyed: bool = false

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

func _ready() -> void:
	add_to_group("player_attacks")
	monitoring = true
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("fly"):
		animated_sprite.play("fly")
		animated_sprite.flip_h = (direction.x < 0)
	
	get_tree().create_timer(lifetime).timeout.connect(func():
		if not is_destroyed:
			queue_free()
	)

func setup(dir: Vector2, start_pos: Vector2) -> void:
	direction = dir.normalized()
	global_position = start_pos
	rotation = direction.angle()
	if direction.x < 0:
		scale.y = -1.0

func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	if is_destroyed:
		return
	var target = area.get_parent()
	if target and target.is_in_group("player"):
		return
	if target and target.has_method("take_damage"):
		target.take_damage(damage, direction)
		_destroy()
	elif area.has_method("take_damage"):
		area.take_damage(damage, direction)
		_destroy()

func _on_body_entered(body: Node) -> void:
	if is_destroyed:
		return
	if body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, direction)
		_destroy()
	elif body is TileMapLayer or body is StaticBody2D or body.is_class("TileMap") or body.is_class("TileMapLayer"):
		_destroy()

func _destroy() -> void:
	is_destroyed = true
	set_physics_process(false)
	monitoring = false
	if hit_sfx:
		var audio = AudioStreamPlayer2D.new()
		audio.bus = &"SFX"
		audio.stream = hit_sfx
		audio.global_position = global_position
		get_parent().add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)
	
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "scale", Vector2.ZERO, 0.08)
		await tween.finished
	queue_free()
