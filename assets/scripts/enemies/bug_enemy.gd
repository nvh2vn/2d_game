extends CharacterBody2D

@export_group("Movement & Patrol")
@export var speed: float = 70.0
@export var gravity: float = 980.0
@export var initial_direction: int = 1 # 1: phải, -1: trái
@export var turn_at_ledge: bool = false # Bật nếu muốn quái tự quay đầu khi gặp mép vực/sàn (Mặc định = false: Chỉ quay đầu khi chạm tường)
@export var patrol_distance: float = 0.0 # Nếu > 0: Quãng đường tối đa tự quay đầu (px). Nếu = 0: bò đến khi đụng tường

@export_group("Combat")
@export var max_health: int = 2
@export var damage: int = 1

var current_health: int = 2
var direction: int = 1
var is_dead: bool = false
var start_x: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("%AnimatedSprite")
@onready var wall_ray: RayCast2D = get_node_or_null("%WallRay")
@onready var ledge_ray: RayCast2D = get_node_or_null("%LedgeRay")
@onready var hitbox: Area2D = get_node_or_null("%Hitbox")
@onready var hurtbox: Area2D = get_node_or_null("%Hurtbox")


func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	direction = initial_direction
	start_x = global_position.x
	update_facing()
	
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)


func _physics_process(delta: float) -> void:
	if is_dead:
		if not is_on_floor():
			velocity.y += gravity * delta
		else:
			velocity.x = 0
		move_and_slide()
		return
	
	# Áp dụng trọng lực rơi
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Kiểm tra va chạm tường hoặc quãng đường tuần tra
	var should_turn = false
	if is_hitting_real_wall():
		should_turn = true
	elif turn_at_ledge and ledge_ray and is_on_floor() and not ledge_ray.is_colliding():
		should_turn = true
	elif patrol_distance > 0.0 and absf(global_position.x - start_x) >= patrol_distance:
		# Quay đầu nếu vượt quá quãng đường tuần tra
		if (direction > 0 and global_position.x > start_x) or (direction < 0 and global_position.x < start_x):
			should_turn = true
	
	if should_turn:
		turn_around()
	
	velocity.x = direction * speed
	move_and_slide()
	
	# Gây sát thương nếu Player đang chạm vào Hitbox
	if hitbox and not is_dead:
		for body in hitbox.get_overlapping_bodies():
			if is_player(body) and body.has_method("take_damage"):
				if "is_invincible" in body and body.is_invincible:
					continue
				body.take_damage(damage)


func is_hitting_real_wall() -> bool:
	if is_on_wall():
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider and not is_player(collider):
				if absf(collision.get_normal().x) > 0.6:
					return true
	if wall_ray and wall_ray.is_colliding():
		var collider = wall_ray.get_collider()
		if collider and not is_player(collider):
			return true
	return false


func is_player(node: Node) -> bool:
	return node.is_in_group("player") or node.name == "PlayerController" or node.name.begins_with("Player")


func turn_around() -> void:
	direction *= -1
	update_facing()


func update_facing() -> void:
	if animated_sprite:
		animated_sprite.flip_h = (direction < 0)
		if not is_dead and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("walk"):
			animated_sprite.play("walk")
	
	if wall_ray:
		wall_ray.target_position.x = direction * absf(wall_ray.target_position.x)
	if ledge_ray:
		ledge_ray.position.x = direction * absf(ledge_ray.position.x)


func _on_hitbox_body_entered(body: Node) -> void:
	if is_dead:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.name == "AttackArea":
		take_damage(1)


func take_damage(amount: int = 1) -> void:
	if is_dead:
		return
	current_health -= amount
	
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color(2.0, 0.2, 0.2), 0.1)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		die()


func die() -> void:
	is_dead = true
	velocity.x = 0
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	
	await get_tree().create_timer(0.8).timeout
	queue_free()
