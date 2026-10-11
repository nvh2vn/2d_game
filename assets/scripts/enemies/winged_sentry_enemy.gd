class_name WingedSentryEnemy
extends BaseEnemy

## State Machine cho Winged Sentry (Lính canh có cánh xứ City of Tears)
enum State {
	IDLE,
	PURSUE,
	ANTICIPATE,
	ATTACK_DASH,
	RECOVER,
	BACKSTEP,
	DEATH
}

@export_group("AI Movement & Attack")
@export var fly_speed: float = 110.0
@export var attack_dash_speed: float = 380.0
@export var backstep_speed: float = 180.0
@export var detection_range: float = 320.0
@export var attack_trigger_range: float = 170.0
@export var attack_cooldown: float = 1.8

var current_state: State = State.IDLE
var target_player: CharacterBody2D = null
var attack_timer: float = 0.0
var state_timer: float = 0.0
var attack_direction: Vector2 = Vector2.ZERO
var hover_time: float = 0.0
var facing_dir: int = -1 # -1: Trái, 1: Phải

@onready var sword_hitbox: Area2D = get_node_or_null("%SwordHitbox")
@onready var detection_area: Area2D = get_node_or_null("%DetectionArea")
@onready var wall_ray: RayCast2D = get_node_or_null("%WallRay")

func _on_enemy_ready() -> void:
	max_health = 5
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.NORMAL
	min_drop_coins = 3
	max_drop_coins = 6
	chance_5_geo = 0.4
	
	if sword_hitbox:
		sword_hitbox.body_entered.connect(_on_sword_hitbox_body_entered)
		sword_hitbox.set_deferred("monitoring", false)
		sword_hitbox.set_deferred("monitorable", false)
		
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
		
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
		
	if attack_timer > 0.0:
		attack_timer -= delta
		
	# Tự động tìm Player nếu chưa có tham chiếu
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
			
	match current_state:
		State.IDLE:
			_process_idle_state(delta)
		State.PURSUE:
			_process_pursue_state(delta)
		State.ANTICIPATE:
			_process_anticipate_state(delta)
		State.ATTACK_DASH:
			_process_attack_dash_state(delta)
		State.RECOVER:
			_process_recover_state(delta)
		State.BACKSTEP:
			_process_backstep_state(delta)

	move_and_slide()

## Trạng thái tuần tra / bay lơ lửng tự nhiên
func _process_idle_state(delta: float) -> void:
	hover_time += delta * 3.0
	velocity.x = move_toward(velocity.x, 0.0, 150.0 * delta)
	velocity.y = sin(hover_time) * 18.0
	
	if animated_sprite and animated_sprite.animation != "idle":
		animated_sprite.play("idle")
		
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= detection_range:
			_change_state(State.PURSUE)

## Trạng thái rượt đuổi và áp sát vị trí chiến đấu
func _process_pursue_state(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		_change_state(State.IDLE)
		return
		
	var dist = global_position.distance_to(target_player.global_position)
	if dist > detection_range * 1.3:
		_change_state(State.IDLE)
		return
		
	# Mục tiêu tiếp cận: Hơi cao hơn Player 30px để lấy góc bổ xuống
	var desired_pos = target_player.global_position + Vector2(0, -35.0)
	var move_dir = (desired_pos - global_position).normalized()
	
	_update_facing(target_player.global_position.x - global_position.x)
	velocity = velocity.move_toward(move_dir * fly_speed, 220.0 * delta)
	
	if animated_sprite and animated_sprite.animation != "pursue":
		animated_sprite.play("pursue")
		
	# Nếu ở trong tầm vung kiếm và hết thời gian hồi chiêu
	if dist <= attack_trigger_range and attack_timer <= 0.0:
		_change_state(State.ANTICIPATE)

## Trạng thái lấy đà (Wind-up): Khựng lại trên không, giơ kiếm báo hiệu đòn đánh
func _process_anticipate_state(delta: float) -> void:
	state_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	
	if target_player and is_instance_valid(target_player):
		_update_facing(target_player.global_position.x - global_position.x)
		
	if state_timer <= 0.0:
		_change_state(State.ATTACK_DASH)

## Trạng thái lướt chém lao tới với tốc độ cao
func _process_attack_dash_state(delta: float) -> void:
	state_timer -= delta
	velocity = attack_direction * attack_dash_speed
	
	# Kiểm tra va chạm tường hoặc hết thời gian lao
	if is_on_wall() or (wall_ray and wall_ray.is_colliding()) or state_timer <= 0.0:
		_change_state(State.RECOVER)

## Trạng thái hãm đà và hồi sức sau đòn chém
func _process_recover_state(delta: float) -> void:
	state_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
	
	if state_timer <= 0.0:
		# Sau khi hồi sức, nếu Player vẫn ở gần, thực hiện lùi lại né đòn (Backstep)
		if target_player and is_instance_valid(target_player):
			var dist = global_position.distance_to(target_player.global_position)
			if dist < 120.0:
				_change_state(State.BACKSTEP)
				return
		_change_state(State.PURSUE)

## Trạng thái lùi nhanh né đòn (Metroidvania Backstep evade)
func _process_backstep_state(delta: float) -> void:
	state_timer -= delta
	var retreat_dir = Vector2(-facing_dir, -0.3).normalized()
	velocity = retreat_dir * backstep_speed
	
	if state_timer <= 0.0:
		_change_state(State.PURSUE)

## Chuyển đổi trạng thái AI
func _change_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			if animated_sprite: animated_sprite.play("idle")
		State.PURSUE:
			if animated_sprite: animated_sprite.play("pursue")
		State.ANTICIPATE:
			state_timer = 0.35 # Thời gian Wind-up lấy đà
			if animated_sprite and animated_sprite.sprite_frames.has_animation("anticipate"):
				animated_sprite.play("anticipate")
		State.ATTACK_DASH:
			state_timer = 0.38 # Thời gian phi thân lướt chém
			attack_timer = attack_cooldown
			if target_player and is_instance_valid(target_player):
				attack_direction = (target_player.global_position - global_position).normalized()
			else:
				attack_direction = Vector2(facing_dir, 0.2).normalized()
			
			_update_facing(attack_direction.x)
			if animated_sprite:
				if animated_sprite.sprite_frames.has_animation("attack_thrust"):
					animated_sprite.play("attack_thrust")
				elif animated_sprite.sprite_frames.has_animation("attack_slash"):
					animated_sprite.play("attack_slash")
					
			# Bật kiếm sát thương
			if sword_hitbox:
				sword_hitbox.set_deferred("monitoring", true)
				sword_hitbox.set_deferred("monitorable", true)
		State.RECOVER:
			state_timer = 0.32
			if sword_hitbox:
				sword_hitbox.set_deferred("monitoring", false)
				sword_hitbox.set_deferred("monitorable", false)
			if animated_sprite and animated_sprite.sprite_frames.has_animation("recover"):
				animated_sprite.play("recover")
		State.BACKSTEP:
			state_timer = 0.28
			if animated_sprite and animated_sprite.sprite_frames.has_animation("turn"):
				animated_sprite.play("turn")
		State.DEATH:
			pass

## Cập nhật hướng quay mặt của sprite và các Hitbox
func _update_facing(x_dir: float) -> void:
	if x_dir < -5.0:
		facing_dir = -1
		if animated_sprite: animated_sprite.flip_h = false
		if sword_hitbox: sword_hitbox.position.x = -abs(sword_hitbox.position.x)
		if wall_ray: wall_ray.target_position.x = -abs(wall_ray.target_position.x)
	elif x_dir > 5.0:
		facing_dir = 1
		if animated_sprite: animated_sprite.flip_h = true
		if sword_hitbox: sword_hitbox.position.x = abs(sword_hitbox.position.x)
		if wall_ray: wall_ray.target_position.x = abs(wall_ray.target_position.x)

## Ghi đè hàm nhận sát thương để bổ sung White Flash & chuẩn Knockback 0.1s
func take_damage(amount: int = 1, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	current_health -= amount
	
	# Knockback nhẹ ngược hướng chém trong 0.1s chuẩn Metroidvania
	apply_knockback(knockback_dir)
	knockback_timer = 0.1
	
	# Hiệu ứng trúng đòn: Chớp trắng rực rỡ (Modulate White Flash)
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color(4.0, 4.0, 4.0, 1.0), 0.05)
		tween.tween_property(animated_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)
		
	# Nếu đang trong trạng thái hồi chiêu hoặc pursue, quái có thể phản xạ lùi lại né tránh
	if current_state == State.RECOVER or current_state == State.PURSUE:
		_change_state(State.BACKSTEP)
		
	if current_health <= 0:
		die()

## Xử lý tử nạn: Tắt toàn bộ va chạm, rơi Geo, phát animation chết
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
	if sword_hitbox:
		sword_hitbox.set_deferred("monitoring", false)
		sword_hitbox.set_deferred("monitorable", false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)

	# Rơi tiền Geo
	if loot_tier == GeoDropHelper.EnemyTier.CUSTOM:
		GeoDropHelper.drop_geo(global_position, get_parent(), min_drop_coins, max_drop_coins, chance_5_geo, chance_25_geo)
	else:
		GeoDropHelper.drop_from_tier(global_position, get_parent(), loot_tier)

	_on_death_animation()

func _on_death_animation() -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("death"):
			animated_sprite.play("death")
			
	# Rơi chậm dần xuống đất và mờ dần
	var tw = create_tween()
	tw.tween_property(self, "velocity:y", 120.0, 0.4)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	await tw.finished
	queue_free()

func _on_sword_hitbox_body_entered(body: Node) -> void:
	if is_dead:
		return
	if is_player(body):
		if body.has_method("take_damage") and ("is_invincible" not in body or not body.is_invincible):
			body.take_damage(damage, global_position)

func _on_detection_body_entered(body: Node) -> void:
	if is_player(body):
		target_player = body
		if current_state == State.IDLE:
			_change_state(State.PURSUE)

func _on_detection_body_exited(body: Node) -> void:
	if body == target_player:
		pass # Vẫn giữ mục tiêu trong phạm vi truy đuổi
