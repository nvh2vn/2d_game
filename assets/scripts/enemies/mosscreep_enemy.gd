class_name MosscreepEnemy
extends BaseEnemy

## State Machine cho Mosscreep (Bụi rêu nhút nhát vùng Greenpath)
enum State {
	IDLE,
	WALK,
	PANIC_RUN,
	DEATH
}

@export_group("Mosscreep AI")
@export var walk_speed: float = 35.0
@export var panic_speed: float = 125.0
@export var panic_range: float = 140.0

var current_state: State = State.WALK
var target_player: CharacterBody2D = null
var move_direction: int = -1
var hop_timer: float = 0.0

@onready var wall_ray: RayCast2D = get_node_or_null("%WallRay")
@onready var ledge_ray: RayCast2D = get_node_or_null("%LedgeRay")

func _on_enemy_ready() -> void:
	max_health = 2
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL
	min_drop_coins = 1
	max_drop_coins = 2
	chance_5_geo = 0.1
	_change_state(State.WALK)

func _physics_process(delta: float) -> void:
	if is_dead:
		move_and_slide()
		return
		
	# Trọng lực
	if not is_on_floor():
		velocity.y += 980.0 * delta
	else:
		velocity.y = 0.0
		
	if knockback_timer > 0.0:
		knockback_timer -= delta
		move_and_slide()
		return
		
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
			
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.WALK:
			_process_walk(delta)
		State.PANIC_RUN:
			_process_panic(delta)

	move_and_slide()

func _process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
	if animated_sprite and animated_sprite.animation != "idle":
		animated_sprite.play("idle")
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= panic_range:
			_change_state(State.PANIC_RUN)

func _process_walk(delta: float) -> void:
	velocity.x = move_direction * walk_speed
	
	if is_on_wall() or (wall_ray and wall_ray.is_colliding()) or (ledge_ray and is_on_floor() and not ledge_ray.is_colliding()):
		_flip_direction()
		
	if animated_sprite and animated_sprite.animation != "walk":
		animated_sprite.play("walk")
		
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= panic_range:
			_change_state(State.PANIC_RUN)

func _process_panic(delta: float) -> void:
	if target_player and is_instance_valid(target_player):
		# Chạy thục mạng NGƯỢC hướng người chơi
		var dir_away = -sign(target_player.global_position.x - global_position.x)
		if dir_away != 0:
			move_direction = int(dir_away)
			_update_facing()
			
	velocity.x = move_direction * panic_speed
	
	# Thỉnh thoảng nhảy chồm lên vì hoảng loạn
	hop_timer -= delta
	if hop_timer <= 0.0 and is_on_floor():
		velocity.y = -170.0
		hop_timer = randf_range(0.8, 1.6)
		
	# Nếu gặp tường khi hoảng sợ thì quay đầu chạy lại
	if is_on_wall() or (wall_ray and wall_ray.is_colliding()):
		_flip_direction()
		
	if animated_sprite and animated_sprite.animation != "panic_run":
		animated_sprite.play("panic_run")
		
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist > panic_range * 1.6:
			_change_state(State.WALK)

func _flip_direction() -> void:
	move_direction *= -1
	_update_facing()

func _update_facing() -> void:
	if animated_sprite:
		animated_sprite.flip_h = (move_direction > 0)
	if wall_ray:
		wall_ray.target_position.x = move_direction * 18.0
	if ledge_ray:
		ledge_ray.position.x = move_direction * 14.0

func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			if animated_sprite: animated_sprite.play("idle")
		State.WALK:
			if animated_sprite: animated_sprite.play("walk")
		State.PANIC_RUN:
			hop_timer = 0.4
			if animated_sprite and animated_sprite.sprite_frames.has_animation("panic_run"):
				animated_sprite.play("panic_run")
		State.DEATH:
			pass

func take_damage(amount: int = 1, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	current_health -= amount
	apply_knockback(knockback_dir)
	knockback_timer = 0.1
	
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color(4.0, 4.0, 4.0, 1.0), 0.05)
		tween.tween_property(animated_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
		
	_change_state(State.PANIC_RUN)
	
	if current_health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_state = State.DEATH
	
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)

	if loot_tier == GeoDropHelper.EnemyTier.CUSTOM:
		GeoDropHelper.drop_geo(global_position, get_parent(), min_drop_coins, max_drop_coins, chance_5_geo, chance_25_geo)
	else:
		GeoDropHelper.drop_from_tier(global_position, get_parent(), loot_tier)

	_on_death_animation()

func _on_death_animation() -> void:
	if animated_sprite and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
	var tw = create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	queue_free()
