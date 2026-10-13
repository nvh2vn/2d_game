extends CharacterBody2D

@export_group("Combat")
@export var max_health: int = 2
@export var speed: float = 120.0
@export var detection_radius: float = 300.0

@export_group("Loot & Rewards")
@export var loot_tier: GeoDropHelper.EnemyTier = GeoDropHelper.EnemyTier.NORMAL
@export var min_drop_coins: int = 1
@export var max_drop_coins: int = 3
@export var chance_5_geo: float = 0.0
@export var chance_25_geo: float = 0.0

var current_health: int = 2
var player: Node2D = null
var is_chasing: bool = false
var is_dead: bool = false
var float_timer: float = 0.0
var initial_y: float = 0.0
var knockback_timer: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("%AnimatedSprite")
@onready var detection_area: Area2D = get_node_or_null("%DetectionArea")
@onready var hitbox: Area2D = get_node_or_null("%Hitbox")

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	initial_y = global_position.y
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.y += 400 * delta
		move_and_slide()
		return

	# Xử lý hiệu ứng đẩy lùi (Knockback)
	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return

	if is_chasing and player:
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * speed
		if animated_sprite:
			animated_sprite.flip_h = (dir.x < 0)
			if animated_sprite.animation != "chase":
				animated_sprite.play("chase")
	else:
		float_timer += delta * 3.0
		velocity = Vector2(0, sin(float_timer) * 15.0)
		if animated_sprite and animated_sprite.animation != "idle":
			animated_sprite.play("idle")

	move_and_slide()

func _on_detection_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body.name == "PlayerController":
		player = body
		is_chasing = true
		if animated_sprite:
			animated_sprite.play("start_chase")

func _on_detection_body_exited(body: Node) -> void:
	if body == player:
		is_chasing = false
		player = null

func _on_hitbox_body_entered(body: Node) -> void:
	if is_dead:
		return
	if is_player(body):
		if body.has_method("take_damage") and ("is_invincible" not in body or not body.is_invincible):
			body.take_damage(1, global_position)
		var bounce_dir = (global_position - body.global_position).normalized()
		velocity = bounce_dir * 200.0
		knockback_timer = 0.25

func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.name == "AttackArea" or area.is_in_group("player_attacks"):
		var kb_dir = Vector2.ZERO
		var dmg = 1
		if "damage" in area:
			dmg = area.damage
		if "direction" in area:
			kb_dir = area.direction
		else:
			var player_node = area.get_parent()
			if player_node and "current_attack_dir" in player_node:
				kb_dir = player_node.current_attack_dir
			elif player_node:
				kb_dir = (global_position - player_node.global_position).normalized()
		take_damage(dmg, kb_dir)

func is_player(node: Node) -> bool:
	return node.is_in_group("player") or node.name == "PlayerController" or node.name.begins_with("Player")

func take_damage(amount: int = 1, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	current_health -= amount

	# Tính toán hướng đẩy lùi (Knockback)
	if knockback_dir == Vector2.ZERO:
		if player:
			knockback_dir = (global_position - player.global_position).normalized()
		else:
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				knockback_dir = (global_position - players[0].global_position).normalized()
			else:
				knockback_dir = Vector2.UP

	knockback_timer = 0.25
	var push = knockback_dir.normalized() * 280.0
	if push.y >= 0:
		push.y -= 80.0
	velocity = push

	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color(2.5, 0.3, 0.3), 0.1)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)

	if current_health <= 0:
		die()

func die() -> void:
	is_dead = true
	
	# Rơi tiền Geo khi bị tiêu diệt
	if loot_tier == GeoDropHelper.EnemyTier.CUSTOM:
		GeoDropHelper.drop_geo(global_position, get_parent(), min_drop_coins, max_drop_coins, chance_5_geo, chance_25_geo)
	else:
		GeoDropHelper.drop_from_tier(global_position, get_parent(), loot_tier)
			
	if animated_sprite:
		animated_sprite.play("die")
	await get_tree().create_timer(1.2).timeout
	queue_free()
