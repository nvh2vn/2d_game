class_name HuskWarriorEnemy
extends BaseEnemy

@export var walk_speed: float = 60.0
@export var attack_range: float = 85.0
var direction: float = 1.0
var is_attacking: bool = false
var is_blocking: bool = false
var attack_cooldown: float = 0.0
var player: CharacterBody2D = null

func _on_enemy_ready() -> void:
	max_health = 6
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL

func _physics_process(delta: float) -> void:
	if is_dead: return
	if not is_on_floor(): velocity.y += 980.0 * delta
	else: velocity.y = 0.0
	if attack_cooldown > 0.0: attack_cooldown -= delta
	
	if not player or not is_instance_valid(player):
		var p = get_tree().get_nodes_in_group("player")
		if p.size() > 0: player = p[0]
		
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		direction = 1.0 if player.global_position.x > global_position.x else -1.0
		if animated_sprite: animated_sprite.flip_h = (direction < 0)
		
		if dist <= attack_range and attack_cooldown <= 0.0 and not is_attacking:
			_perform_slash()
		elif not is_attacking and not is_blocking and dist > attack_range and dist < 320.0:
			velocity.x = direction * walk_speed
		else:
			velocity.x = 0.0
	else:
		velocity.x = 0.0
		
	move_and_slide()

func _perform_slash() -> void:
	is_attacking = true
	attack_cooldown = 2.0
	velocity.x = direction * 80.0
	if animated_sprite and animated_sprite.sprite_frames.has_animation("slash"):
		animated_sprite.play("slash")
	await get_tree().create_timer(0.6).timeout
	is_attacking = false
	if animated_sprite and animated_sprite.sprite_frames.has_animation("walk"):
		animated_sprite.play("walk")
