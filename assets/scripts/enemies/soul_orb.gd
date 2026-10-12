extends Area2D

@export var speed: float = 330.0
@export var damage: int = 1
@export var homing_duration: float = 1.4
@export var turn_speed: float = 3.5
@export var lifetime: float = 5.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var direction: Vector2 = Vector2.DOWN
var is_homing: bool = true
var homing_timer: float = 0.0
var is_orbiting: bool = false
var orbit_center_node: Node2D = null
var orbit_angle: float = 0.0
var orbit_radius: float = 90.0
var orbit_speed: float = 3.5
var is_destroyed: bool = false
var target_player: Node2D = null


func _ready() -> void:
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	_find_player()
	
	var tw = create_tween()
	tw.tween_interval(lifetime)
	tw.tween_callback(queue_free)


func setup_shot(start_pos: Vector2, initial_dir: Vector2, p_speed: float = 330.0, p_homing: bool = true) -> void:
	global_position = start_pos
	direction = initial_dir.normalized()
	speed = p_speed
	is_homing = p_homing
	is_orbiting = false
	homing_timer = homing_duration
	_find_player()


func setup_shield_orb(center_node: Node2D, angle_rad: float, radius: float = 95.0) -> void:
	is_orbiting = true
	is_homing = false
	orbit_center_node = center_node
	orbit_angle = angle_rad
	orbit_radius = radius
	if orbit_center_node and is_instance_valid(orbit_center_node):
		global_position = orbit_center_node.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius


func release_shield_orb(fly_dir: Vector2, fly_speed: float = 380.0) -> void:
	is_orbiting = false
	is_homing = false
	direction = fly_dir.normalized()
	speed = fly_speed


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		target_player = players[0]


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
		
	# Trạng thái xoay quanh thân boss (Orb Shield)
	if is_orbiting:
		if orbit_center_node and is_instance_valid(orbit_center_node):
			orbit_angle += orbit_speed * delta
			global_position = orbit_center_node.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
		else:
			is_orbiting = false
		return
		
	# Trạng thái bắn đuổi theo người chơi (Homing)
	if is_homing:
		homing_timer -= delta
		if homing_timer <= 0.0:
			is_homing = false
		elif target_player and is_instance_valid(target_player):
			var to_player = (target_player.global_position - global_position).normalized()
			direction = direction.lerp(to_player, turn_speed * delta).normalized()
			
	global_position += direction * speed * delta
	
	if sprite:
		sprite.rotation += 4.0 * delta


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
	if is_destroyed:
		return false
	var p = _resolve_player_target(target)
	if p and p.has_method("take_damage"):
		if "is_invincible" not in p or not p.is_invincible:
			p.take_damage(damage, global_position)
		_destroy()
		return true
	return false


func _on_body_entered(body: Node) -> void:
	if is_destroyed:
		return
	if _check_and_damage_player(body):
		return
	elif not body.is_in_group("enemies") and not body.is_in_group("enemy_projectiles") and not body.is_in_group("bosses"):
		_destroy()


func _on_area_entered(area: Area2D) -> void:
	if is_destroyed:
		return
	# Người chơi chém trúng quả cầu -> phá hủy quả cầu
	if area.name == "AttackArea" or area.is_in_group("player_attacks"):
		_destroy()
		return
	_check_and_damage_player(area)


func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	var tw = create_tween()
	tw.tween_property(self, "scale", scale * 1.4, 0.08)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.08)
	tw.tween_callback(queue_free)
