class_name VengeflyEnemy
extends BaseEnemy

@export var fly_speed: float = 120.0
@export var detection_range: float = 260.0
var player: CharacterBody2D = null
var is_chasing: bool = false
var start_pos: Vector2 = Vector2.ZERO

func _on_enemy_ready() -> void:
	max_health = 2
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL
	start_pos = global_position

func _physics_process(delta: float) -> void:
	if is_dead: return
	if not player or not is_instance_valid(player):
		var p = get_tree().get_nodes_in_group("player")
		if p.size() > 0: player = p[0]
		
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= detection_range:
			is_chasing = true
		elif dist > detection_range * 1.5:
			is_chasing = false
			
	if is_chasing and player and is_instance_valid(player):
		var dir = (player.global_position - global_position).normalized()
		velocity = velocity.move_toward(dir * fly_speed, 350.0 * delta)
		if animated_sprite and animated_sprite.sprite_frames.has_animation("chase"):
			animated_sprite.play("chase")
			animated_sprite.flip_h = (dir.x < 0)
	else:
		var dir = (start_pos - global_position)
		if dir.length() > 20.0:
			velocity = velocity.move_toward(dir.normalized() * (fly_speed * 0.5), 200.0 * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
		if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
			
	move_and_slide()
