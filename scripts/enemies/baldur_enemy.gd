class_name BaldurEnemy
extends BaseEnemy

enum State {
	WALK,
	CURL,
	ROLL,
	UNCURL,
	DEATH
}

@export_group("AI Baldur Mechanics")
@export var walk_speed: float = 40.0
@export var roll_speed: float = 230.0
@export var detection_range: float = 200.0
@export var roll_cooldown: float = 3.0

var current_state: State = State.WALK
var target_player: CharacterBody2D = null
var roll_timer: float = 0.0
var state_timer: float = 0.0
var move_direction: int = -1
var is_armored: bool = false

@onready var wall_ray: RayCast2D = get_node_or_null("%WallRay")
@onready var ledge_ray: RayCast2D = get_node_or_null("%LedgeRay")

func _on_enemy_ready() -> void:
	max_health = 4
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL
	min_drop_coins = 2
	max_drop_coins = 4
	_change_state(State.WALK)

func _physics_process(delta: float) -> void:
	if is_dead:
		move_and_slide()
		return
		
	# Trọng lực rơi xuống sàn
	if not is_on_floor():
		velocity.y += 980.0 * delta
	else:
		velocity.y = 0.0
		
	if knockback_timer > 0.0:
		knockback_timer -= delta
		move_and_slide()
		return
		
	if roll_timer > 0.0:
		roll_timer -= delta
		
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
			
	match current_state:
		State.WALK:
			_process_walk(delta)
		State.CURL:
			_process_curl(delta)
		State.ROLL:
			_process_roll(delta)
		State.UNCURL:
			_process_uncurl(delta)

	move_and_slide()

func _process_walk(delta: float) -> void:
	is_armored = false
	velocity.x = move_direction * walk_speed
	
	# Kiểm tra tường hoặc mép sàn để quay đầu
	if is_on_wall() or (wall_ray and wall_ray.is_colliding()) or (ledge_ray and is_on_floor() and not ledge_ray.is_colliding()):
		_flip_direction()
		
	if animated_sprite and animated_sprite.animation != "idle":
		animated_sprite.play("idle")
		
	if target_player and is_instance_valid(target_player) and roll_timer <= 0.0:
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= detection_range:
			_change_state(State.CURL)

func _process_curl(delta: float) -> void:
	state_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	if state_timer <= 0.0:
		_change_state(State.ROLL)

func _process_roll(_delta: float) -> void:
	velocity.x = move_direction * roll_speed
	state_timer -= _delta
	
	# Nếu tông vào tường hoặc hết thời gian lăn
	if is_on_wall() or state_timer <= 0.0:
		_change_state(State.UNCURL)

func _process_uncurl(delta: float) -> void:
	state_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	if state_timer <= 0.0:
		_change_state(State.WALK)

func _flip_direction() -> void:
	move_direction *= -1
	if animated_sprite:
		animated_sprite.flip_h = (move_direction > 0)
	if wall_ray:
		wall_ray.target_position.x = move_direction * 22.0
	if ledge_ray:
		ledge_ray.position.x = move_direction * 18.0

func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.WALK:
			is_armored = false
			if animated_sprite: animated_sprite.play("idle")
		State.CURL:
			is_armored = true
			state_timer = 0.35 # Cuộn tròn
			if animated_sprite and animated_sprite.sprite_frames.has_animation("curl"):
				animated_sprite.play("curl")
		State.ROLL:
			is_armored = true
			state_timer = 1.6 # Thời gian lăn tấn công
			roll_timer = roll_cooldown
			if target_player and is_instance_valid(target_player):
				var p_dir = sign(target_player.global_position.x - global_position.x)
				if p_dir != 0 and p_dir != move_direction:
					_flip_direction()
			if animated_sprite and animated_sprite.sprite_frames.has_animation("roll"):
				animated_sprite.play("roll")
		State.UNCURL:
			is_armored = true
			state_timer = 0.35 # Mở giáp
			if animated_sprite and animated_sprite.sprite_frames.has_animation("uncurl"):
				animated_sprite.play("uncurl")
		State.DEATH:
			is_armored = false

func take_damage(amount: int = 1, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
		
	# Nếu đang bọc giáp (Curled Armor), hoàn toàn miễn nhiễm sát thương đao kiếm thường!
	if is_armored:
		# Hiệu ứng nảy giáp clink kim loại
		if animated_sprite:
			var tw = create_tween()
			tw.tween_property(animated_sprite, "modulate", Color(1.8, 1.8, 1.8), 0.05)
			tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.05)
		return

	# Nhận sát thương khi ở trạng thái bình thường
	current_health -= amount
	apply_knockback(knockback_dir)
	knockback_timer = 0.1
	
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color(4.0, 4.0, 4.0, 1.0), 0.05)
		tween.tween_property(animated_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
		
	# Khi bị chém lập tức cuộn tròn phòng thủ
	if current_state == State.WALK:
		_change_state(State.CURL)
		
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
	tw.tween_interval(0.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	queue_free()
