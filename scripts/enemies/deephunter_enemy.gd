class_name DeephunterEnemy
extends BaseEnemy

## State Machine cho Deephunter (Thợ săn bóng đêm Deepnest)
enum State {
	IDLE,
	HOVER,
	SWOOP_ANTICIPATE,
	SWOOP,
	RECOVER,
	DEATH
}

@export_group("Deephunter AI")
@export var hover_speed: float = 75.0
@export var swoop_speed: float = 370.0
@export var detection_range: float = 290.0
@export var swoop_cooldown: float = 2.4

var current_state: State = State.IDLE
var target_player: CharacterBody2D = null
var attack_timer: float = 0.0
var state_timer: float = 0.0
var swoop_dir: Vector2 = Vector2.ZERO
var hover_time: float = 0.0
var facing_dir: int = -1

func _on_enemy_ready() -> void:
	max_health = 4
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL
	min_drop_coins = 3
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
		State.HOVER:
			_process_hover(delta)
		State.SWOOP_ANTICIPATE:
			_process_swoop_anticipate(delta)
		State.SWOOP:
			_process_swoop(delta)
		State.RECOVER:
			_process_recover(delta)

	move_and_slide()

func _process_idle(delta: float) -> void:
	hover_time += delta * 3.0
	velocity.y = sin(hover_time) * 16.0
	velocity.x = move_toward(velocity.x, 0.0, 100.0 * delta)
	
	if animated_sprite and animated_sprite.animation != "idle":
		animated_sprite.play("idle")
		
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= detection_range:
			_change_state(State.HOVER)

func _process_hover(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		_change_state(State.IDLE)
		return
		
	var dist = global_position.distance_to(target_player.global_position)
	if dist > detection_range * 1.3:
		_change_state(State.IDLE)
		return
		
	# Giữ vị trí trên cao chếch so với Player
	var desired_pos = target_player.global_position + Vector2(facing_dir * 100.0, -90.0)
	var move_dir = (desired_pos - global_position).normalized()
	velocity = velocity.move_toward(move_dir * hover_speed, 180.0 * delta)
	
	_update_facing(target_player.global_position.x - global_position.x)
	if animated_sprite and animated_sprite.animation != "hover":
		animated_sprite.play("hover")
		
	if dist <= detection_range and attack_timer <= 0.0:
		_change_state(State.SWOOP_ANTICIPATE)

func _process_swoop_anticipate(delta: float) -> void:
	state_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	
	if target_player and is_instance_valid(target_player):
		_update_facing(target_player.global_position.x - global_position.x)
		
	if state_timer <= 0.0:
		_change_state(State.SWOOP)

func _process_swoop(delta: float) -> void:
	state_timer -= delta
	velocity = swoop_dir * swoop_speed
	
	if is_on_floor() or is_on_wall() or state_timer <= 0.0:
		_change_state(State.RECOVER)

func _process_recover(delta: float) -> void:
	state_timer -= delta
	# Lượn vòng ngược lên cao trốn thoát
	var retreat_dir = Vector2(facing_dir * 80.0, -120.0).normalized()
	velocity = velocity.move_toward(retreat_dir * hover_speed * 1.3, 200.0 * delta)
	
	if state_timer <= 0.0:
		_change_state(State.HOVER)

func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			if animated_sprite: animated_sprite.play("idle")
		State.HOVER:
			if animated_sprite and animated_sprite.sprite_frames.has_animation("hover"):
				animated_sprite.play("hover")
		State.SWOOP_ANTICIPATE:
			state_timer = 0.35 # Wind-up chuẩn bị bổ nhào
			if animated_sprite and animated_sprite.sprite_frames.has_animation("swoop_anticipate"):
				animated_sprite.play("swoop_anticipate")
		State.SWOOP:
			state_timer = 0.45
			attack_timer = swoop_cooldown
			if target_player and is_instance_valid(target_player):
				swoop_dir = (target_player.global_position - global_position).normalized()
			else:
				swoop_dir = Vector2(facing_dir, 0.8).normalized()
			_update_facing(swoop_dir.x)
			if animated_sprite and animated_sprite.sprite_frames.has_animation("swoop"):
				animated_sprite.play("swoop")
		State.RECOVER:
			state_timer = 0.5
			if animated_sprite and animated_sprite.sprite_frames.has_animation("hover"):
				animated_sprite.play("hover")
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
	var tw = create_tween()
	tw.tween_property(self, "velocity:y", 120.0, 0.4)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	await tw.finished
	queue_free()
