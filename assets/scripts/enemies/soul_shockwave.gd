extends Area2D

@export var speed: float = 340.0
@export var damage: int = 1
@export var max_distance: float = 440.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var dir_x: float = 1.0
var traveled: float = 0.0
var is_active: bool = true


func _ready() -> void:
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	if animated_sprite:
		animated_sprite.play("wave")


func setup(direction_x: float, start_pos: Vector2, p_speed: float = 340.0) -> void:
	dir_x = signf(direction_x)
	if dir_x == 0.0: dir_x = 1.0
	global_position = start_pos
	speed = p_speed
	
	if animated_sprite:
		animated_sprite.flip_h = (dir_x < 0)


func _physics_process(delta: float) -> void:
	if not is_active:
		return
		
	var step = speed * delta
	global_position.x += dir_x * step
	traveled += step
	
	if traveled >= max_distance:
		_fade_out()


func _resolve_player_target(node: Node) -> Node:
	if not node:
		return null
	if node.is_in_group("player") or node.name == "PlayerController" or node.name.begins_with("Player"):
		return node
	if node.get_parent() and (node.get_parent().is_in_group("player") or node.get_parent().name == "PlayerController" or node.get_parent().name.begins_with("Player")):
		return node.get_parent()
	if node.owner and (node.owner.is_in_group("player") or node.owner.name == "PlayerController" or node.owner.name.begins_with("Player")):
		return node.owner
	return null


func _check_and_damage_player(target: Node) -> bool:
	if not is_active:
		return false
	var p = _resolve_player_target(target)
	if p and p.has_method("take_damage"):
		if "is_invincible" not in p or not p.is_invincible:
			p.take_damage(damage, global_position)
		return true
	return false


func _on_body_entered(body: Node) -> void:
	_check_and_damage_player(body)


func _on_area_entered(area: Area2D) -> void:
	_check_and_damage_player(area)


func _fade_out() -> void:
	is_active = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)
