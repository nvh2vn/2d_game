class_name BelflyEnemy
extends BaseEnemy

@export var swoop_speed: float = 320.0
@export var trigger_distance: float = 240.0
var is_swooping: bool = false
var has_exploded: bool = false
var player: CharacterBody2D = null

func _on_enemy_ready() -> void:
	max_health = 1
	current_health = max_health
	damage = 2
	loot_tier = GeoDropHelper.EnemyTier.NORMAL

func _physics_process(delta: float) -> void:
	if is_dead: return
	if not player or not is_instance_valid(player):
		var p = get_tree().get_nodes_in_group("player")
		if p.size() > 0: player = p[0]
		
	if player and is_instance_valid(player) and not is_swooping:
		var dist = global_position.distance_to(player.global_position)
		if dist <= trigger_distance and player.global_position.y > global_position.y:
			_start_swoop()
			
	if is_swooping and not has_exploded and player and is_instance_valid(player):
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * swoop_speed
		move_and_slide()
		if is_on_floor() or is_on_wall() or global_position.distance_to(player.global_position) < 30.0:
			_explode()

func _start_swoop() -> void:
	is_swooping = true
	if animated_sprite and animated_sprite.sprite_frames.has_animation("swoop"):
		animated_sprite.play("swoop")

func _explode() -> void:
	if has_exploded: return
	has_exploded = true
	velocity = Vector2.ZERO
	if animated_sprite and animated_sprite.sprite_frames.has_animation("explode"):
		animated_sprite.play("explode")
	await get_tree().create_timer(0.4).timeout
	die()
