class_name CorpseCreeperEnemy
extends BaseEnemy

## State Machine cho Corpse Creeper (Ký sinh trùng xác chết Deepnest)
enum State {
	IDLE_CORPSE, # Nằm giả chết ngụy trang
	AWAKEN,      # Co giật, bật dậy thức tỉnh
	CRAWL,       # Bò tìm kiếm mục tiêu
	RUN,         # Lao nhanh giật cục săn mồi
	DEATH
}

@export_group("Corpse Creeper AI")
@export var crawl_speed: float = 60.0
@export var run_speed: float = 210.0
@export var detection_range: float = 170.0
@export var ambush_on_hit: bool = true

var current_state: State = State.IDLE_CORPSE
var target_player: CharacterBody2D = null
var state_timer: float = 0.0
var move_direction: int = -1
var is_ambushing: bool = true

@onready var wall_ray: RayCast2D = get_node_or_null("%WallRay")
@onready var ledge_ray: RayCast2D = get_node_or_null("%LedgeRay")

func _on_enemy_ready() -> void:
	max_health = 4
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL
	min_drop_coins = 3
	max_drop_coins = 6
	chance_5_geo = 0.35
	_change_state(State.IDLE_CORPSE)

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
		State.IDLE_CORPSE:
			_process_idle_corpse(delta)
		State.AWAKEN:
			_process_awaken(delta)
		State.CRAWL:
			_process_crawl(delta)
		State.RUN:
			_process_run(delta)

	move_and_slide()

## Trạng thái ngụy trang giả chết nằm im
func _process_idle_corpse(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	if animated_sprite and animated_sprite.animation != "idle_corpse":
		animated_sprite.play("idle_corpse")
		
	# Nếu Player tiến đến quá gần -> Bật dậy phục kích
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= detection_range:
			_change_state(State.AWAKEN)

## Co giật và bật dậy
func _process_awaken(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
	state_timer -= delta
	if state_timer <= 0.0:
		is_ambushing = false
		_change_state(State.RUN)

## Bò tuần tra
func _process_crawl(delta: float) -> void:
	velocity.x = move_direction * crawl_speed
	
	if is_on_wall() or (wall_ray and wall_ray.is_colliding()) or (ledge_ray and is_on_floor() and not ledge_ray.is_colliding()):
		_flip_direction()
		
	if animated_sprite and animated_sprite.animation != "crawl":
		animated_sprite.play("crawl")
		
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= detection_range * 1.5:
			_change_state(State.RUN)

## Lao nhanh giật cục săn mồi
func _process_run(delta: float) -> void:
	if target_player and is_instance_valid(target_player):
		var p_dir = sign(target_player.global_position.x - global_position.x)
		if p_dir != 0:
			move_direction = int(p_dir)
			_update_facing()
			
	velocity.x = move_direction * run_speed
	
	# Nhảy chồm qua chướng ngại vật nhỏ khi đụng tường
	if is_on_wall() and is_on_floor():
		velocity.y = -220.0
		
	if animated_sprite and animated_sprite.animation != "run":
		animated_sprite.play("run")
		
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist > detection_range * 2.0:
			_change_state(State.CRAWL)

func _flip_direction() -> void:
	move_direction *= -1
	_update_facing()

func _update_facing() -> void:
	if animated_sprite:
		animated_sprite.flip_h = (move_direction > 0)
	if wall_ray:
		wall_ray.target_position.x = move_direction * 22.0
	if ledge_ray:
		ledge_ray.position.x = move_direction * 18.0

func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE_CORPSE:
			if animated_sprite: animated_sprite.play("idle_corpse")
		State.AWAKEN:
			state_timer = 0.55 # Thời gian co giật thức tỉnh
			if animated_sprite and animated_sprite.sprite_frames.has_animation("awaken"):
				animated_sprite.play("awaken")
		State.CRAWL:
			if animated_sprite: animated_sprite.play("crawl")
		State.RUN:
			if animated_sprite: animated_sprite.play("run")
		State.DEATH:
			pass

func take_damage(amount: int = 1, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
		
	# Nếu đang nằm giả chết mà bị Player chém -> Bật dậy ngay lập tức!
	if current_state == State.IDLE_CORPSE:
		current_health -= amount
		apply_knockback(knockback_dir)
		knockback_timer = 0.1
		_change_state(State.AWAKEN)
		_flash_white()
		if current_health <= 0:
			die()
		return

	current_health -= amount
	apply_knockback(knockback_dir)
	knockback_timer = 0.1
	_flash_white()
	
	# Phản ứng giật cục: Đổi hướng hoặc lao thẳng vào người chơi
	if current_state == State.CRAWL:
		_change_state(State.RUN)
		
	if current_health <= 0:
		die()

func _flash_white() -> void:
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color(4.0, 4.0, 4.0, 1.0), 0.05)
		tween.tween_property(animated_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)

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
	tw.tween_interval(0.45)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	queue_free()
