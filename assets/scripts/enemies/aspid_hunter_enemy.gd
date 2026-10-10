class_name AspidHunterEnemy
extends BaseEnemy

@export var fly_speed: float = 90.0
@export var detection_range: float = 300.0
@export var shoot_cooldown: float = 2.2
var shoot_timer: float = 0.0
var player: CharacterBody2D = null
var is_shooting: bool = false

var fireball_prefab: PackedScene = preload("res://assets/prefabs/enemies/nightmare_fireball.tscn")

func _on_enemy_ready() -> void:
	max_health = 3
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL

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
		
		if dist <= detection_range and not is_shooting:
			if dist < 140.0:
				velocity = velocity.move_toward(-dir * fly_speed, 250.0 * delta)
			elif dist > 200.0:
				velocity = velocity.move_toward(dir * fly_speed, 250.0 * delta)
			else:
				velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
				
			if shoot_timer <= 0.0:
				_shoot_at_player(dir)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 150.0 * delta)
			
	move_and_slide()

func _shoot_at_player(dir: Vector2) -> void:
	is_shooting = true
	shoot_timer = shoot_cooldown
	if animated_sprite and animated_sprite.sprite_frames.has_animation("shoot"):
		animated_sprite.play("shoot")
	await get_tree().create_timer(0.35).timeout
	if is_dead or not is_inside_tree(): return
	
	if fireball_prefab and get_parent():
		var fb = fireball_prefab.instantiate()
		get_parent().add_child(fb)
		fb.setup(dir, global_position + dir * 18.0, 220.0)
		
	await get_tree().create_timer(0.25).timeout
	is_shooting = false
	if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
