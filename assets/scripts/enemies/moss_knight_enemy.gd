class_name MossKnightEnemy
extends BaseEnemy

@export var walk_speed: float = 65.0
@export var attack_range: float = 95.0
var direction: float = 1.0
var is_acting: bool = false
var action_cooldown: float = 0.0
var player: CharacterBody2D = null

func _on_enemy_ready() -> void:
	max_health = 10
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.ELITE

func _physics_process(delta: float) -> void:
	if is_dead: return
	if not is_on_floor(): velocity.y += 980.0 * delta
	else: velocity.y = 0.0
	if action_cooldown > 0.0: action_cooldown -= delta
	
	if not player or not is_instance_valid(player):
		var p = get_tree().get_nodes_in_group("player")
		if p.size() > 0: player = p[0]
		
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		direction = 1.0 if player.global_position.x > global_position.x else -1.0
		if animated_sprite: animated_sprite.flip_h = (direction < 0)
		
		if action_cooldown <= 0.0 and not is_acting:
			if dist <= attack_range:
				_perform_slash()
			elif dist < 320.0 and randf() < 0.4:
				_perform_spit()
			elif dist > attack_range and dist < 380.0:
				velocity.x = direction * walk_speed
			else:
				velocity.x = 0.0
		elif not is_acting:
			velocity.x = direction * (walk_speed * 0.5)
	else:
		velocity.x = 0.0
		
	move_and_slide()

func _perform_slash() -> void:
	is_acting = true
	action_cooldown = 1.8
	velocity.x = direction * 100.0
	if animated_sprite and animated_sprite.sprite_frames.has_animation("slash"):
		animated_sprite.play("slash")
	await get_tree().create_timer(0.7).timeout
	is_acting = false
	if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")

func _perform_spit() -> void:
	is_acting = true
	action_cooldown = 2.4
	velocity.x = 0.0
	if animated_sprite and animated_sprite.sprite_frames.has_animation("spit"):
		animated_sprite.play("spit")
	await get_tree().create_timer(0.8).timeout
	is_acting = false
	if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
