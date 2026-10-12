extends Area2D

@export var speed: float = 360.0
@export var damage: int = 1
@export var wave_frequency: float = 7.0
@export var wave_amplitude: float = 120.0
@export var lifetime: float = 4.5

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var base_direction: Vector2 = Vector2.LEFT
var perp_direction: Vector2 = Vector2.UP
var elapsed: float = 0.0
var is_destroyed: bool = false


func _ready() -> void:
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	if animated_sprite:
		animated_sprite.play("fly")
		
	var tw = create_tween()
	tw.tween_interval(lifetime)
	tw.tween_callback(queue_free)


func setup(dir: Vector2, start_pos: Vector2, custom_speed: float = 360.0, wave_offset_phase: float = 0.0) -> void:
	base_direction = dir.normalized()
	perp_direction = Vector2(-base_direction.y, base_direction.x)
	global_position = start_pos
	speed = custom_speed
	elapsed = wave_offset_phase
	rotation = base_direction.angle()


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	elapsed += delta
	var forward = base_direction * speed * delta
	var wave_velocity = perp_direction * (sin(elapsed * wave_frequency) * wave_amplitude * delta)
	global_position += forward + wave_velocity
	
	var cur_vel = forward + wave_velocity
	if cur_vel.length_squared() > 0.001:
		rotation = cur_vel.angle()


func _on_body_entered(body: Node) -> void:
	if is_destroyed:
		return
	if body.is_in_group("player") or body.name == "PlayerController" or body.name.begins_with("Player"):
		if body.has_method("take_damage") and ("is_invincible" not in body or not body.is_invincible):
			body.take_damage(damage, global_position)
		_destroy()
	elif not body.is_in_group("enemies") and not body.is_in_group("enemy_projectiles"):
		_destroy()


func _on_area_entered(area: Area2D) -> void:
	if is_destroyed:
		return
	# Có thể bị kiếm người chơi chém nát
	if area.name == "AttackArea" or area.is_in_group("player_attacks"):
		_destroy()


func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	var tw = create_tween()
	tw.tween_property(self, "scale", scale * 1.3, 0.08)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.08)
	tw.tween_callback(queue_free)
