class_name HuskGuardEnemy
extends BaseEnemy

@export var walk_speed: float = 40.0
@export var slam_range: float = 110.0
var direction: float = 1.0
var is_slamming: bool = false
var slam_cooldown: float = 0.0
var player: CharacterBody2D = null

func _on_enemy_ready() -> void:
	max_health = 14
	current_health = max_health
	damage = 2
	loot_tier = GeoDropHelper.EnemyTier.ELITE

func _physics_process(delta: float) -> void:
	if is_dead: return
	if not is_on_floor(): velocity.y += 980.0 * delta
	else: velocity.y = 0.0
	if slam_cooldown > 0.0: slam_cooldown -= delta
	
	if not player or not is_instance_valid(player):
		var p = get_tree().get_nodes_in_group("player")
		if p.size() > 0: player = p[0]
		
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		direction = 1.0 if player.global_position.x > global_position.x else -1.0
		if animated_sprite: animated_sprite.flip_h = (direction < 0)
		
		if dist <= slam_range and slam_cooldown <= 0.0 and not is_slamming:
			_perform_slam()
		elif not is_slamming and dist > slam_range and dist < 360.0:
			velocity.x = direction * walk_speed
			if animated_sprite and animated_sprite.sprite_frames.has_animation("walk"):
				animated_sprite.play("walk")
		else:
			velocity.x = 0.0
			if not is_slamming and animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
				animated_sprite.play("idle")
	else:
		velocity.x = 0.0
		
	move_and_slide()

func _perform_slam() -> void:
	is_slamming = true
	slam_cooldown = 2.8
	velocity.x = 0.0
	if animated_sprite and animated_sprite.sprite_frames.has_animation("slam"):
		animated_sprite.play("slam")
		
	await get_tree().create_timer(0.6).timeout
	if is_dead or not is_inside_tree(): return
	
	# Camera shake when hammer hits floor
	var cam = get_viewport().get_camera_2d()
	if cam:
		var tw = create_tween()
		for i in range(4):
			tw.tween_property(cam, "offset", Vector2(0, randf_range(-4, 4)), 0.04)
		tw.tween_property(cam, "offset", Vector2.ZERO, 0.04)
		
	await get_tree().create_timer(0.6).timeout
	is_slamming = false
	if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
