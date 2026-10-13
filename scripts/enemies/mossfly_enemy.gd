class_name MossflyEnemy
extends BaseEnemy

## State Machine cho Mossfly (Ruồi rêu Greenpath)
enum State {
	FLY,
	TURN,
	EVADE,
	DEATH
}

@export_group("Mossfly AI")
@export var fly_speed: float = 55.0
@export var evade_speed: float = 95.0
@export var patrol_distance: float = 120.0
@export var evade_range: float = 110.0

var current_state: State = State.FLY
var target_player: CharacterBody2D = null
var fly_direction: int = -1
var start_x: float = 0.0
var hover_time: float = 0.0
var state_timer: float = 0.0

func _on_enemy_ready() -> void:
	max_health = 2
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL
	min_drop_coins = 1
	max_drop_coins = 2
	chance_5_geo = 0.1
	start_x = global_position.x
	_change_state(State.FLY)

func _physics_process(delta: float) -> void:
	if is_dead:
		move_and_slide()
		return
		
	if knockback_timer > 0.0:
		knockback_timer -= delta
		move_and_slide()
		return
		
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
			
	match current_state:
		State.FLY:
			_process_fly(delta)
		State.TURN:
			_process_turn(delta)
		State.EVADE:
			_process_evade(delta)

	move_and_slide()

func _process_fly(delta: float) -> void:
	hover_time += delta * 4.0
	velocity.x = fly_direction * fly_speed
	velocity.y = sin(hover_time) * 20.0
	
	# Kiểm tra đổi hướng tuần tra
	if abs(global_position.x - start_x) > patrol_distance or is_on_wall():
		_change_state(State.TURN)
		return
		
	if animated_sprite and animated_sprite.animation != "fly":
		animated_sprite.play("fly")
		
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= evade_range:
			_change_state(State.EVADE)

func _process_turn(delta: float) -> void:
	state_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 150.0 * delta)
	
	if state_timer <= 0.0:
		fly_direction *= -1
		if animated_sprite:
			animated_sprite.flip_h = (fly_direction > 0)
		_change_state(State.FLY)

func _process_evade(delta: float) -> void:
	hover_time += delta * 5.0
	# Bay né tránh bạt lên cao
	if target_player and is_instance_valid(target_player):
		var away_x = -sign(target_player.global_position.x - global_position.x)
		if away_x != 0:
			fly_direction = int(away_x)
			if animated_sprite:
				animated_sprite.flip_h = (fly_direction > 0)
				
	velocity.x = fly_direction * evade_speed
	velocity.y = -60.0 + sin(hover_time) * 15.0
	
	if animated_sprite and animated_sprite.animation != "fly":
		animated_sprite.play("fly")
		
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist > evade_range * 1.5:
			_change_state(State.FLY)

func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.FLY:
			if animated_sprite: animated_sprite.play("fly")
		State.TURN:
			state_timer = 0.25
			if animated_sprite and animated_sprite.sprite_frames.has_animation("turn"):
				animated_sprite.play("turn")
		State.EVADE:
			if animated_sprite: animated_sprite.play("fly")
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
		
	_change_state(State.EVADE)
	
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
	tw.tween_property(self, "velocity:y", 90.0, 0.3)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.4)
	await tw.finished
	queue_free()
