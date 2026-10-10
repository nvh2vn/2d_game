class_name HuskBullyEnemy
extends BaseEnemy

@export var patrol_speed: float = 50.0
@export var charge_speed: float = 180.0
@export var detection_range: float = 220.0
var direction: float = 1.0
var is_charging: bool = false
var charge_cooldown: float = 0.0
var player: CharacterBody2D = null

@onready var wall_ray: RayCast2D = get_node_or_null("%WallRay")

func _on_enemy_ready() -> void:
	max_health = 4
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL

func _physics_process(delta: float) -> void:
	if is_dead: return
	if not is_on_floor(): velocity.y += 980.0 * delta
	else: velocity.y = 0.0
	if charge_cooldown > 0.0: charge_cooldown -= delta
	
	if not player or not is_instance_valid(player):
		var p = get_tree().get_nodes_in_group("player")
		if p.size() > 0: player = p[0]
		
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= detection_range and charge_cooldown <= 0.0 and not is_charging:
			_start_charge()
			
	if is_charging:
		velocity.x = direction * charge_speed
	else:
		if wall_ray and wall_ray.is_colliding():
			direction *= -1.0
			_update_facing()
		velocity.x = direction * patrol_speed
		
	move_and_slide()

func _start_charge() -> void:
	is_charging = true
	charge_cooldown = 3.0
	if player and is_instance_valid(player):
		direction = 1.0 if player.global_position.x > global_position.x else -1.0
		_update_facing()
	if animated_sprite and animated_sprite.sprite_frames.has_animation("attack"):
		animated_sprite.play("attack")
	await get_tree().create_timer(1.2).timeout
	is_charging = false
	if animated_sprite and animated_sprite.sprite_frames.has_animation("walk"):
		animated_sprite.play("walk")

func _update_facing() -> void:
	if animated_sprite: animated_sprite.flip_h = (direction < 0)
	if wall_ray: wall_ray.target_position.x = 24.0 * direction
