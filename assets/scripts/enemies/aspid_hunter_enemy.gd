class_name AspidHunterEnemy
extends BaseEnemy

## State Machine cho Aspid Hunter (Thợ săn Aspid - Forgotten Crossroads)
enum State {
	IDLE,
	KITING,
	ANTICIPATE,
	SHOOT,
	RECOVER,
	DEATH
}

@export_group("AI Movement & Ranged Attack")
@export var fly_speed: float = 95.0
@export var detection_range: float = 320.0
@export var preferred_dist_min: float = 140.0
@export var preferred_dist_max: float = 230.0
@export var shoot_cooldown: float = 2.2
@export var projectile_speed: float = 260.0

var current_state: State = State.IDLE
var target_player: CharacterBody2D = null
var shoot_timer: float = 0.0
var state_timer: float = 0.0
var hover_time: float = 0.0
var facing_dir: int = -1

var projectile_prefab: PackedScene = preload("res://assets/prefabs/projectiles/aspid_projectile.tscn")
@onready var shoot_marker: Marker2D = get_node_or_null("%ShootMarker")

func _on_enemy_ready() -> void:
	max_health = 3
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL
	min_drop_coins = 2
	max_drop_coins = 4
	chance_5_geo = 0.25
	_change_state(State.IDLE)

func _physics_process(delta: float) -> void:
	if is_dead:
		move_and_slide()
		return
		
	# Xử lý Knockback khi trúng đòn
	if knockback_timer > 0.0:
		knockback_timer -= delta
		move_and_slide()
		return
		
	if shoot_timer > 0.0:
		shoot_timer -= delta
		
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
			
	match current_state:
		State.IDLE:
			_process_idle_state(delta)
		State.KITING:
			_process_kiting_state(delta)
		State.ANTICIPATE:
			_process_anticipate_state(delta)
		State.SHOOT:
			_process_shoot_state(delta)
		State.RECOVER:
			_process_recover_state(delta)

	move_and_slide()

## Bay lơ lửng tuần tra bập bềnh
func _process_idle_state(delta: float) -> void:
	hover_time += delta * 3.5
	velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)
	velocity.y = sin(hover_time) * 16.0
	
	if animated_sprite and animated_sprite.animation != "idle":
		animated_sprite.play("idle")
		
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= detection_range:
			_change_state(State.KITING)

## Cơ chế Kiting đặc trưng: Giữ khoảng cách vàng với Player
func _process_kiting_state(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		_change_state(State.IDLE)
		return
		
	var dist = global_position.distance_to(target_player.global_position)
	if dist > detection_range * 1.3:
		_change_state(State.IDLE)
		return
		
	var dir_to_player = (target_player.global_position - global_position).normalized()
	_update_facing(dir_to_player.x)
	
	# Logic giữ khoảng cách:
	# Nếu Player áp sát quá gần -> Bay lùi lại (retreat)
	# Nếu Player ở xa -> Bay tiếp cận
	# Nếu ở cự ly vàng -> Dao động nhẹ và chuẩn bị bắn
	if dist < preferred_dist_min:
		velocity = velocity.move_toward(-dir_to_player * fly_speed, 220.0 * delta)
	elif dist > preferred_dist_max:
		velocity = velocity.move_toward(dir_to_player * fly_speed, 220.0 * delta)
	else:
		hover_time += delta * 4.0
		var float_vel = Vector2(0, sin(hover_time) * 20.0)
		velocity = velocity.move_toward(float_vel, 180.0 * delta)
		
		# Sẵn sàng bắn khi đã vào tầm và hết cooldown
		if shoot_timer <= 0.0:
			_change_state(State.ANTICIPATE)
			return

	if animated_sprite and animated_sprite.animation != "idle":
		animated_sprite.play("idle")

## Trạng thái lấy đà: Phồng bụng tích tụ dịch Infection axit
func _process_anticipate_state(delta: float) -> void:
	state_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
	
	if target_player and is_instance_valid(target_player):
		_update_facing(target_player.global_position.x - global_position.x)
		
	if state_timer <= 0.0:
		_change_state(State.SHOOT)

## Trạng thái phun đạn Infection về phía Player
func _process_shoot_state(_delta: float) -> void:
	# Bắn đạn và chuyển ngay sang Recover
	_spawn_projectile()
	_change_state(State.RECOVER)

## Hồi phục sau khi bắn và giữ khoảng cách
func _process_recover_state(delta: float) -> void:
	state_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 150.0 * delta)
	
	if state_timer <= 0.0:
		_change_state(State.KITING)

func _spawn_projectile() -> void:
	if not projectile_prefab or not is_inside_tree():
		return
		
	var spawn_pos = global_position
	if shoot_marker:
		spawn_pos = shoot_marker.global_position
		
	var shoot_dir = Vector2(facing_dir, 0.0)
	if target_player and is_instance_valid(target_player):
		shoot_dir = (target_player.global_position - spawn_pos).normalized()
		
	var parent_node = get_parent()
	if parent_node:
		var proj = projectile_prefab.instantiate()
		parent_node.add_child(proj)
		proj.setup(shoot_dir, spawn_pos + shoot_dir * 10.0, projectile_speed)

func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			if animated_sprite: animated_sprite.play("idle")
		State.KITING:
			if animated_sprite: animated_sprite.play("idle")
		State.ANTICIPATE:
			state_timer = 0.4 # Thời gian phồng họng tích đạn
			if animated_sprite and animated_sprite.sprite_frames.has_animation("anticipate"):
				animated_sprite.play("anticipate")
		State.SHOOT:
			shoot_timer = shoot_cooldown
			if animated_sprite and animated_sprite.sprite_frames.has_animation("shoot"):
				animated_sprite.play("shoot")
		State.RECOVER:
			state_timer = 0.25
		State.DEATH:
			pass

func _update_facing(x_dir: float) -> void:
	if x_dir < -2.0:
		facing_dir = -1
		if animated_sprite: animated_sprite.flip_h = false
		if shoot_marker: shoot_marker.position.x = -abs(shoot_marker.position.x)
	elif x_dir > 2.0:
		facing_dir = 1
		if animated_sprite: animated_sprite.flip_h = true
		if shoot_marker: shoot_marker.position.x = abs(shoot_marker.position.x)

func take_damage(amount: int = 1, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	current_health -= amount
	
	# Đẩy lùi nhẹ 0.1s
	apply_knockback(knockback_dir)
	knockback_timer = 0.1
	
	# Chớp trắng rực rỡ
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

	# Rơi tiền Geo
	if loot_tier == GeoDropHelper.EnemyTier.CUSTOM:
		GeoDropHelper.drop_geo(global_position, get_parent(), min_drop_coins, max_drop_coins, chance_5_geo, chance_25_geo)
	else:
		GeoDropHelper.drop_from_tier(global_position, get_parent(), loot_tier)

	_on_death_animation()

func _on_death_animation() -> void:
	var tw = create_tween()
	tw.tween_property(self, "velocity:y", 100.0, 0.35)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	await tw.finished
	queue_free()
