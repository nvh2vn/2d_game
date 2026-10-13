class_name GrimmkinNoviceEnemy
extends BaseEnemy

@export var fly_speed: float = 100.0
@export var shoot_cooldown: float = 2.4
var shoot_timer: float = 0.0
var player: CharacterBody2D = null

var fireball_prefab: PackedScene = preload("res://scenes/prefabs/enemies/nightmare_fireball.tscn")

func _on_enemy_ready() -> void:
	max_health = 6
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.ELITE

func _physics_process(delta: float) -> void:
	if is_dead: return
	if shoot_timer > 0.0: shoot_timer -= delta
	
	if not player or not is_instance_valid(player):
		var p = get_tree().get_nodes_in_group("player")
		if p.size() > 0: player = p[0]
		
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		var dir = (player.global_position - global_position).normalized()
		if animated_sprite: animated_sprite.flip_h = (dir.x < 0)
		
		if dist > 180.0:
			velocity = velocity.move_toward(dir * fly_speed, 200.0 * delta)
		elif dist < 120.0:
			velocity = velocity.move_toward(-dir * fly_speed, 200.0 * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 150.0 * delta)
			
		if shoot_timer <= 0.0 and dist <= 320.0:
			_cast_flame(dir)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 150.0 * delta)
		
	move_and_slide()

func _cast_flame(dir: Vector2) -> void:
	shoot_timer = shoot_cooldown
	if animated_sprite and animated_sprite.sprite_frames.has_animation("cast"):
		animated_sprite.play("cast")
	await get_tree().create_timer(0.4).timeout
	if is_dead or not is_inside_tree(): return
	
	if fireball_prefab and get_parent():
		var fb = fireball_prefab.instantiate()
		get_parent().add_child(fb)
		fb.setup(dir, global_position + dir * 20.0, 260.0)
		
	await get_tree().create_timer(0.3).timeout
	if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
