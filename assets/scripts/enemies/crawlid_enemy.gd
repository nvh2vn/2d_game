class_name CrawlidEnemy
extends BaseEnemy

@export var move_speed: float = 45.0
var direction: float = 1.0

@onready var wall_ray: RayCast2D = get_node_or_null("%WallRay")
@onready var ledge_ray: RayCast2D = get_node_or_null("%LedgeRay")

func _on_enemy_ready() -> void:
	max_health = 2
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL

func _physics_process(delta: float) -> void:
	if is_dead: return
	if not is_on_floor():
		velocity.y += 980.0 * delta
	else:
		velocity.y = 0.0
		
	if wall_ray and wall_ray.is_colliding():
		direction *= -1.0
		_update_facing()
	elif ledge_ray and not ledge_ray.is_colliding():
		direction *= -1.0
		_update_facing()
		
	velocity.x = direction * move_speed
	move_and_slide()

func _update_facing() -> void:
	if animated_sprite:
		animated_sprite.flip_h = (direction < 0)
	if wall_ray:
		wall_ray.target_position.x = 20.0 * direction
	if ledge_ray:
		ledge_ray.position.x = 18.0 * direction
