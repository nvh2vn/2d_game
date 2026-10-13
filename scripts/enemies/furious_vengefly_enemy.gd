class_name FuriousVengeflyEnemy
extends BaseEnemy

enum State {
	IDLE,
	SCREECH,
	DIVE,
	RECOVER,
	DEATH
}

@export_group("AI Dive Attack")
@export var patrol_speed: float = 65.0
@export var dive_speed: float = 340.0
@export var detection_range: float = 280.0
@export var attack_cooldown: float = 2.0

var current_state: State = State.IDLE
var target_player: CharacterBody2D = null
var attack_timer: float = 0.0
var state_timer: float = 0.0
var dive_direction: Vector2 = Vector2.ZERO
var hover_time: float = 0.0
var facing_dir: int = -1

func _on_enemy_ready() -> void:
	max_health = 4
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL
	min_drop_coins = 2
	max_drop_coins = 5
	chance_5_geo = 0.3
	_change_state(State.IDLE)

func _physics_process(delta: float) -> void:
	if is_dead:
		move_and_slide()
		return
		
	if knockback_timer > 0.0:
		knockback_timer -= delta
		move_and_slide()
		return
		
	if attack_timer > 0.0:
		attack_timer -= delta
		
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
			
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.SCREECH:
			_process_screech(delta)
		State.DIVE:
			_process_dive(delta)
		State.RECOVER:
			_process_recover(delta)

	move_and_slide()

func _process_idle(delta: float) -> void:
	hover_time += delta * 3.0
	velocity.y = sin(hover_time) * 15.0
	velocity.x = move_toward(velocity.x, 0.0, 100.0 * delta)
	
	if animated_sprite and animated_sprite.animation != "idle":
		animated_sprite.play("idle")
		
	if target_player and is_instance_valid(target_player) and attack_timer <= 0.0:
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= detection_range:
			_change_state(State.SCREECH)

func _process_screech(delta: float) -> void:
	state_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
	
	if target_player and is_instance_valid(target_player):
		_update_facing(target_player.global_position.x - global_position.x)
		
	if state_timer <= 0.0:
		_change_state(State.DIVE)

func _process_dive(delta: float) -> void:
	state_timer -= delta
	velocity = dive_direction * dive_speed
	
	# Chạm sàn hoặc tường hoặc hết thời gian lao
	if is_on_floor() or is_on_wall() or state_timer <= 0.0:
		_change_state(State.RECOVER)

func _process_recover(delta: float) -> void:
	state_timer -= delta
	# Bay vòng lên cao để lấy lại cao độ
	velocity = velocity.move_toward(Vector2(facing_dir * 40.0, -90.0), 200.0 * delta)
	
	if state_timer <= 0.0:
		_change_state(State.IDLE)

func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			if animated_sprite: animated_sprite.play("idle")
		State.SCREECH:
			state_timer = 0.4 # Tiếng thét báo hiệu
			if animated_sprite and animated_sprite.sprite_frames.has_animation("screech"):
				animated_sprite.play("screech")
		State.DIVE:
			state_timer = 0.5
			attack_timer = attack_cooldown
			if target_player and is_instance_valid(target_player):
				dive_direction = (target_player.global_position - global_position).normalized()
			else:
				dive_direction = Vector2(facing_dir, 1.0).normalized()
			_update_facing(dive_direction.x)
			if animated_sprite and animated_sprite.sprite_frames.has_animation("dive"):
				animated_sprite.play("dive")
		State.RECOVER:
			state_timer = 0.5
			if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
				animated_sprite.play("idle")
		State.DEATH:
			pass

func _update_facing(x_dir: float) -> void:
	if x_dir < -2.0:
		facing_dir = -1
		if animated_sprite: animated_sprite.flip_h = false
	elif x_dir > 2.0:
		facing_dir = 1
		if animated_sprite: animated_sprite.flip_h = true

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
	# Hiệu ứng nổ cam đặc trưng khi Furious Vengefly chết
	var tw = create_tween()
	tw.tween_property(self, "scale", scale * 1.3, 0.15)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	await tw.finished
	queue_free()
