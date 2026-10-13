extends Area2D

@export var speed: float = 340.0
@export var damage: int = 1
@export var lifetime: float = 5.0
@export var gravity_scale: float = 0.0

var velocity: Vector2 = Vector2.ZERO
var is_destroyed: bool = false


func _ready() -> void:
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	var tw = create_tween()
	tw.tween_interval(lifetime)
	tw.tween_callback(queue_free)


func setup(dir: Vector2, start_pos: Vector2, custom_speed: float = 340.0, p_gravity: float = 0.0) -> void:
	global_position = start_pos
	speed = custom_speed
	gravity_scale = p_gravity
	velocity = dir.normalized() * speed
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	if gravity_scale > 0.0:
		velocity.y += gravity_scale * delta
		rotation = velocity.angle()
	global_position += velocity * delta


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
