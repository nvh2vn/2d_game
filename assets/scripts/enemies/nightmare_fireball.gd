extends Area2D

@export var speed: float = 380.0
@export var damage: int = 1
@export var lifetime: float = 4.0

var direction: Vector2 = Vector2.LEFT
var is_destroyed: bool = false


func _ready() -> void:
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	var tw = create_tween()
	tw.tween_interval(lifetime)
	tw.tween_callback(queue_free)


func setup(dir: Vector2, start_pos: Vector2, custom_speed: float = 380.0) -> void:
	direction = dir.normalized()
	global_position = start_pos
	speed = custom_speed
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if is_destroyed: return
	if body.is_in_group("player") or body.name == "PlayerController" or body.name.begins_with("Player"):
		if body.has_method("take_damage") and ("is_invincible" not in body or not body.is_invincible):
			body.take_damage(damage, global_position)
		_destroy()
	elif not body.is_in_group("enemies") and not body.is_in_group("enemy_projectiles"):
		_destroy()


func _on_area_entered(area: Area2D) -> void:
	if is_destroyed: return
	# Bị người chơi chém phản đòn hoặc đánh văng
	if area.name == "AttackArea" or area.is_in_group("player_attacks"):
		_destroy()


func _destroy() -> void:
	if is_destroyed: return
	is_destroyed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var tw = create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 1.4), 0.08)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.08)
	tw.tween_callback(queue_free)
