extends CharacterBody2D

@export var max_health: int = 2
@export var speed: float = 120.0
@export var detection_radius: float = 300.0

var current_health: int = 2
var player: Node2D = null
var is_chasing: bool = false
var is_dead: bool = false
var float_timer: float = 0.0
var initial_y: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("%AnimatedSprite")
@onready var detection_area: Area2D = get_node_or_null("%DetectionArea")
@onready var hitbox: Area2D = get_node_or_null("%Hitbox")

func _ready() -> void:
	current_health = max_health
	initial_y = global_position.y
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.y += 400 * delta
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
	if body.has_method("take_damage") and not is_dead:
		body.take_damage(1)

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
	if animated_sprite:
		animated_sprite.play("die")
	await get_tree().create_timer(1.2).timeout
	queue_free()