extends CharacterBody2D

var current_attack_dir: Vector2 = Vector2.RIGHT
enum STATE {
	FALL,
	FLOOR,
	JUMP,
	DOUBLE_JUMP,
	FLOAT,
	LEDGE_CLIMB,
	LEDGE_JUMP,
	WALL_SLIDE,
	WALL_JUMP,
	WALL_CLIMB,
	DASH,
	TURNING,
	ATTACK,
	DIE,
}

@export_group("Map 1 Unlockable Abilities")
@export var unlock_double_jump: bool = false
@export var unlock_dash: bool = false
@export var unlock_wall_climb: bool = false
@export var unlock_float: bool = false
@export var unlock_ledge_climb: bool = false
@export var unlock_attack: bool = true

@export_group("Player Health & Combat")
@export var fall_death_y: float = 600.0
@export var max_health: int = 5
var current_health: int = 5
var is_invincible: bool = false

const FALL_GRAVITY := 1500.0
const FALL_VELOCITY := 500.0
const WALK_VELOCITY := 200.0
const JUMP_VELOCITY := -600.0
const JUMP_DECELERATION := 1500.0
const DOUBLE_JUMP_VELOCITY := -450.0
const FLOAT_GRAVITY := 200.0
const FLOAT_VELOCITY := 100.0
const FLOAT_ACCELERATION := 700.0
const LEDGE_JUMP_VELOCITY := -500.0
const WALL_SLIDE_GRAVITY := 300.0
const WALL_SLIDE_VELOCITY := 500.0
const WALL_JUMP_LENGTH := 30.0
const WALL_JUMP_VELOCITY := -500.0
const WALL_CLIMB_VELOCITY := -300.0
const WALL_CLIMB_LENGTH := 65.0
const DASH_LENGTH := 100.0
const DASH_VELOCITY := 600.0
const SPRINT_VELOCITY := 400.0
const SPRINT_ACCELERATION := 1800.0

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("%AnimatedSprite")
@onready var coyote_timer: Timer = get_node_or_null("%CoyoteTimer")
@onready var float_cooldown: Timer = get_node_or_null("%FloatCooldown")
@onready var player_collider: CollisionShape2D = get_node_or_null("%PlayerCollider")
@onready var ledge_climb_ray_cast: RayCast2D = get_node_or_null("%LedgeClimbRayCast")
@onready var ledge_space_ray_cast: RayCast2D = get_node_or_null("%LedgeSpaceRayCast")
@onready var wall_slide_ray_cast: RayCast2D = get_node_or_null("%WallSlideRayCast")
@onready var dash_cooldown: Timer = get_node_or_null("%DashCooldown")
@onready var attack_timer: Timer = get_node_or_null("%AttackTimer")
@onready var attack_area: Area2D = get_node_or_null("%AttackArea")
@onready var invincibility_timer: Timer = get_node_or_null("%InvincibilityTimer")
@onready var hp_label: Label = get_node_or_null("%HPLabel")
@onready var health_container: HBoxContainer = get_node_or_null("%HealthContainer")
@onready var blood_effect: AnimatedSprite2D = get_node_or_null("%BloodEffect")
@onready var death_vignette: Sprite2D = get_node_or_null("%DeathVignette")

@export var active_mask_texture: Texture2D = preload("res://assets/art/2d/silksong_full/Images/UI/mask_white.png")
@export var lost_mask_texture: Texture2D = preload("res://assets/art/2d/silksong_full/Images/UI/mask_black.png")

var blink_tween: Tween
var active_state := STATE.FALL
var can_double_jump := false
var facing_direction := 1.0
var saved_position := Vector2.ZERO
var can_dash := false
var dash_jump_buffer := false
var is_sprinting := false

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	switch_state(active_state)
	ledge_climb_ray_cast.add_exception(self)
	if attack_timer:
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	if invincibility_timer:
		invincibility_timer.timeout.connect(_on_invincibility_timer_timeout)
	if attack_area:
		attack_area.area_entered.connect(_on_attack_area_entered)
	if blood_effect:
		blood_effect.animation_finished.connect(_on_blood_effect_animation_finished)
	update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			heal(1)

func _on_attack_area_entered(area: Area2D) -> void:
	var target = area.get_parent()
	if target and target.has_method("take_damage"):
		target.take_damage(1)
	elif area.has_method("take_damage"):
		area.take_damage(1)

func update_hud() -> void:
	if health_container:
		var masks = health_container.get_children()
		for i in range(masks.size()):
			if i < current_health:
				masks[i].modulate = Color(1.0, 1.0, 1.0, 1.0)
				if active_mask_texture:
					masks[i].texture = active_mask_texture
			else:
				masks[i].modulate = Color(1.0, 1.0, 1.0, 1.0)
				if lost_mask_texture:
					masks[i].texture = lost_mask_texture
	elif hp_label:
		var masks := ""
		for i in range(current_health):
			masks += "🤍 "
		for i in range(max_health - current_health):
			masks += "🩶 "
		hp_label.text = ("MASK: " + masks).strip_edges()

func play_blood_minus_effect(mask_index: int) -> void:
	if not blood_effect:
		return
	if health_container:
		var masks = health_container.get_children()
		if mask_index >= 0 and mask_index < masks.size():
			var target_mask = masks[mask_index]
			blood_effect.global_position = target_mask.global_position + target_mask.size * 0.5
		else:
			blood_effect.position = Vector2(80, 45)
	else:
		blood_effect.position = Vector2(80, 45)
	blood_effect.visible = true
	blood_effect.play("blood_minus")

func heal(amount: int = 1) -> void:
	if current_health >= max_health or active_state == STATE.DIE:
		return
	var restored_index = current_health
	current_health = mini(current_health + amount, max_health)
	play_blood_load_effect(restored_index)
	update_hud()

func play_blood_load_effect(mask_index: int) -> void:
	if not blood_effect:
		return
	if health_container:
		var masks = health_container.get_children()
		if mask_index >= 0 and mask_index < masks.size():
			var target_mask = masks[mask_index]
			blood_effect.global_position = target_mask.global_position + target_mask.size * 0.5
		else:
			blood_effect.position = Vector2(80, 45)
	else:
		blood_effect.position = Vector2(80, 45)
	blood_effect.visible = true
	blood_effect.play("blood_load")

func _on_blood_effect_animation_finished() -> void:
	if blood_effect:
		blood_effect.visible = false

func take_damage(amount: int) -> void:
	if is_invincible or current_health <= 0 or active_state == STATE.DIE:
		return
	var broken_index = current_health - 1
	current_health -= amount
	play_blood_minus_effect(broken_index)
	update_hud()
	
	if current_health <= 0:
		die()
		return
	
	is_invincible = true
	if invincibility_timer:
		invincibility_timer.start(1.2)
	
	# Hiệu ứng nảy lùi nhẹ (Knockback)
	velocity.y = -180.0
	velocity.x = -facing_direction * 120.0
		
	# Hiệu ứng nhấp nháy mờ liên tục trong suốt thời gian bất tử (I-frames)
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
		
	if animated_sprite:
		animated_sprite.modulate = Color(2.5, 0.3, 0.3, 1.0)
		blink_tween = create_tween().set_loops()
		blink_tween.tween_property(animated_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.25), 0.1)
		blink_tween.tween_property(animated_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.85), 0.1)

func _on_invincibility_timer_timeout() -> void:
	is_invincible = false
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
	if animated_sprite and active_state != STATE.DIE:
		animated_sprite.modulate = Color.WHITE

func die() -> void:
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
	switch_state(STATE.DIE)
	if attack_area:
		attack_area.monitoring = false
	if attack_timer:
		attack_timer.stop()
	if invincibility_timer:
		invincibility_timer.stop()
	
	# Vùng tối vignette bung tỏa rộng ra từ tâm người chơi
	if death_vignette:
		death_vignette.visible = true
		death_vignette.modulate = Color(1.0, 1.0, 1.0, 0.0)
		death_vignette.scale = Vector2(0.2, 0.2)
		var tween_v = create_tween()
		tween_v.tween_property(death_vignette, "modulate:a", 1.0, 0.25)
		tween_v.parallel().tween_property(death_vignette, "scale", Vector2(3.5, 3.5), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Hiệu ứng nảy lùi nhẹ khi bị tiêu diệt
	velocity.y = -220.0
	velocity.x = -facing_direction * 100.0
	
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
		animated_sprite.play("die")
	
	# Chờ phát xong hoạt ảnh die và mờ dần màn hình
	await get_tree().create_timer(1.2).timeout
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.4)
		if death_vignette:
			tween.parallel().tween_property(death_vignette, "modulate:a", 0.0, 0.4)
		await tween.finished
	
	get_tree().reload_current_scene()

func _on_attack_timer_timeout() -> void:
	if active_state == STATE.ATTACK:
		if attack_area:
			attack_area.monitoring = false
		if is_on_floor():
			switch_state(STATE.FLOOR)
		else:
			switch_state(STATE.FALL)


func _physics_process(delta: float) -> void:
	process_state(delta)
	move_and_slide()
	
	# Fall out of bounds death check
	if global_position.y > fall_death_y and current_health > 0:
		take_damage(max_health)


func switch_state(to_state: STATE) -> void:
	var previous_state := active_state
	active_state = to_state
	
	## State specific things that only need to run once upon entering the next state.
	match active_state:
		STATE.FALL:
			if previous_state != STATE.DOUBLE_JUMP:
				animated_sprite.play("fall")
			if previous_state == STATE.FLOOR:
				coyote_timer.start()
		
		STATE.FLOOR:
			can_double_jump = true
			can_dash = true
		
		STATE.JUMP:
			if previous_state != STATE.TURNING:
				animated_sprite.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
		
		STATE.DOUBLE_JUMP:
			animated_sprite.play("double_jump")
			velocity.y = DOUBLE_JUMP_VELOCITY
			can_double_jump = false
			is_sprinting = false
		
		STATE.FLOAT:
			if float_cooldown.time_left > 0:
				active_state = previous_state
				return
			animated_sprite.play("float")
			velocity.y = 0
			is_sprinting = false
		
		STATE.LEDGE_CLIMB:
			animated_sprite.play("ledge_climb")
			velocity = Vector2.ZERO
			global_position.y = ledge_climb_ray_cast.get_collision_point().y
			can_double_jump = true
		
		STATE.LEDGE_JUMP:
			animated_sprite.play("double_jump")
			velocity.y = LEDGE_JUMP_VELOCITY
			can_dash = true
			is_sprinting = false
		
		STATE.WALL_SLIDE:
			animated_sprite.play("wall_slide")
			velocity.y = 0
			can_double_jump = true
			can_dash = true
			is_sprinting = false
		
		STATE.WALL_JUMP:
			animated_sprite.play("jump")
			velocity.y = WALL_JUMP_VELOCITY
			set_facing_direction(-facing_direction)
			saved_position = position
		
		STATE.WALL_CLIMB:
			animated_sprite.play("wall_climb")
			velocity.y = WALL_CLIMB_VELOCITY
			saved_position = position
		
		STATE.DASH:
			if dash_cooldown.time_left > 0:
				active_state = previous_state
				return
			animated_sprite.play("dash")
			velocity.y = 0
			set_facing_direction(signf(Input.get_axis("move_left", "move_right")))
			velocity.x = facing_direction * DASH_VELOCITY
			saved_position = position
			can_dash = previous_state == STATE.FLOOR or previous_state == STATE.WALL_SLIDE
			dash_jump_buffer = false
		
		STATE.TURNING:
			set_facing_direction(-facing_direction)
		
		STATE.ATTACK:
			var input_h := Input.get_axis("move_left", "move_right")
			var input_v := Input.get_axis("move_up", "move_down")
			
			if input_h != 0:
				set_facing_direction(signf(input_h))
			else:
				set_facing_direction(facing_direction)
				
			if input_v < -0.3 or Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
				current_attack_dir = Vector2.UP
				if attack_area:
					attack_area.position = Vector2(0, -45)
				if animated_sprite:
					animated_sprite.play("attack_up")
			elif (input_v > 0.3 or Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) and not is_on_floor():
				current_attack_dir = Vector2.DOWN
				if attack_area:
					attack_area.position = Vector2(0, 45)
				if animated_sprite:
					animated_sprite.play("attack_down")
			else:
				current_attack_dir = Vector2(facing_direction, 0)
				if attack_area:
					attack_area.position = Vector2(40 * facing_direction, 0)
				if animated_sprite:
					animated_sprite.play("attack")
				
			if attack_area:
				attack_area.monitoring = true
			if attack_timer:
				attack_timer.start(0.25)


func process_state(delta: float) -> void:
	match active_state:
		STATE.FALL:
			velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			if is_sprinting:
				handle_sprint(delta)
			else:
				handle_movement()
			
			if Input.is_action_just_pressed("attack") and unlock_attack:
				switch_state(STATE.ATTACK)
			elif is_on_floor():
				switch_state(STATE.FLOOR)
			elif Input.is_action_just_pressed("jump"):
				if coyote_timer.time_left > 0:
					switch_state(STATE.JUMP)
				elif can_double_jump and unlock_double_jump:
					switch_state(STATE.DOUBLE_JUMP)
				elif unlock_float:
					switch_state(STATE.FLOAT)
			elif is_input_toward_facing() and is_ledge() and is_space() and unlock_ledge_climb:
				switch_state(STATE.LEDGE_CLIMB)
			elif is_input_toward_facing() and can_wall_slide() and unlock_wall_climb:
				switch_state(STATE.WALL_SLIDE)
			elif Input.is_action_just_pressed("sprint") and can_dash and unlock_dash:
				switch_state(STATE.DASH)
		
		STATE.FLOOR:
			if is_sprinting:
				animated_sprite.play("sprint")
				handle_sprint(delta)
			else:
				if Input.get_axis("move_left", "move_right"):
					animated_sprite.play("walk")
				else:
					animated_sprite.play("idle")
				handle_movement()
			
			if Input.is_action_just_pressed("attack") and unlock_attack:
				switch_state(STATE.ATTACK)
			elif not is_on_floor():
				switch_state(STATE.FALL)
			elif Input.is_action_just_pressed("jump"):
				switch_state(STATE.JUMP)
			elif Input.is_action_just_pressed("sprint") and unlock_dash:
				switch_state(STATE.DASH)
			elif is_sprinting and is_input_against_facing():
				switch_state(STATE.TURNING)
		
		STATE.JUMP, STATE.DOUBLE_JUMP, STATE.LEDGE_JUMP, STATE.WALL_JUMP:
			velocity.y = move_toward(velocity.y, 0, JUMP_DECELERATION * delta)
			if active_state == STATE.WALL_JUMP:
				var distance := absf(position.x - saved_position.x)
				if distance >= WALL_JUMP_LENGTH or can_wall_slide():
					active_state = STATE.JUMP
				else:
					handle_movement(facing_direction)
			
			if is_sprinting:
				handle_sprint(delta)
			elif active_state != STATE.WALL_JUMP:
				handle_movement()
			
			if Input.is_action_just_pressed("attack") and unlock_attack:
				switch_state(STATE.ATTACK)
			elif Input.is_action_just_released("jump") or velocity.y >= 0:
				velocity.y = 0
				switch_state(STATE.FALL)
			elif Input.is_action_just_pressed("jump") and unlock_double_jump:
				switch_state(STATE.DOUBLE_JUMP)
			elif Input.is_action_just_pressed("sprint") and can_dash and unlock_dash:
				switch_state(STATE.DASH)
		
		STATE.FLOAT:
			velocity.y = move_toward(velocity.y, FLOAT_VELOCITY, FLOAT_GRAVITY * delta)
			handle_movement(0, WALK_VELOCITY, FLOAT_ACCELERATION * delta)
			
			if is_on_floor():
				switch_state(STATE.FLOOR)
			elif Input.is_action_just_released("jump"):
				float_cooldown.start()
				switch_state(STATE.FALL)
			elif is_input_toward_facing() and is_ledge() and is_space():
				switch_state(STATE.LEDGE_CLIMB)
			elif is_input_toward_facing() and can_wall_slide():
				switch_state(STATE.WALL_SLIDE)
			elif Input.is_action_just_pressed("sprint") and can_dash:
				switch_state(STATE.DASH)
		
		STATE.LEDGE_CLIMB:
			is_sprinting = Input.is_action_pressed("sprint")
			if not animated_sprite.is_playing():
				animated_sprite.play("idle")
				var offset := ledge_climb_offset()
				offset.x *= facing_direction
				position += offset
				switch_state(STATE.FLOOR)
			elif Input.is_action_just_pressed("jump"):
				var progress := inverse_lerp(0, animated_sprite.sprite_frames.get_frame_count("ledge_climb"), animated_sprite.frame)
				var offset := ledge_climb_offset()
				offset.x *= facing_direction * progress
				position += offset
				switch_state(STATE.LEDGE_JUMP)
		
		STATE.WALL_SLIDE:
			velocity.y = move_toward(velocity.y, WALL_SLIDE_VELOCITY, WALL_SLIDE_GRAVITY * delta)
			handle_movement()
			
			if is_on_floor():
				switch_state(STATE.FLOOR)
			elif is_ledge() and is_space():
				switch_state(STATE.LEDGE_CLIMB)
			elif not can_wall_slide():
				switch_state(STATE.FALL)
			elif Input.is_action_just_pressed("jump"):
				switch_state(STATE.WALL_JUMP)
			elif Input.is_action_just_pressed("sprint"):
				if is_input_toward_facing():
					switch_state(STATE.WALL_CLIMB)
				else:
					set_facing_direction(-facing_direction)
					switch_state(STATE.DASH)
		
		STATE.WALL_CLIMB:
			var distance := absf(position.y - saved_position.y)
			if distance >= WALL_CLIMB_LENGTH or is_on_ceiling():
				velocity.y = 0
				switch_state(STATE.WALL_SLIDE)
			elif is_ledge():
				switch_state(STATE.LEDGE_JUMP)
		
		STATE.DASH:
			velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			is_sprinting = Input.is_action_pressed("sprint")
			dash_cooldown.start()
			if is_on_floor():
				coyote_timer.start()
			if Input.is_action_just_pressed("jump"):
				dash_jump_buffer = true
			var distance := absf(position.x - saved_position.x)
			if distance >= DASH_LENGTH or signf(get_last_motion().x) != facing_direction:
				if dash_jump_buffer and coyote_timer.time_left > 0:
					
					switch_state(STATE.JUMP)
				elif is_on_floor():
					switch_state(STATE.FLOOR)
				else:
					switch_state(STATE.FALL)
			elif is_ledge() and is_space():
				switch_state(STATE.LEDGE_CLIMB)
			elif can_wall_slide():
				switch_state(STATE.WALL_SLIDE)
		
		STATE.TURNING:
			if signf(velocity.x) == facing_direction and is_input_against_facing():
				set_facing_direction(-facing_direction)
			handle_sprint(delta)
			
			if not is_on_floor():
				switch_state(STATE.FALL)
			elif not is_sprinting or velocity.x * facing_direction >= SPRINT_VELOCITY:
				switch_state(STATE.FLOOR)
			elif Input.is_action_just_pressed("jump"):
				animated_sprite.play("double_jump")
				is_sprinting = false
				switch_state(STATE.JUMP)

		STATE.ATTACK:
			if Input.is_action_just_pressed("jump"):
				velocity.y = JUMP_VELOCITY
			
			if not is_on_floor():
				velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			
			var move_speed := WALK_VELOCITY
			if is_sprinting:
				move_speed = SPRINT_VELOCITY
			handle_movement(0, move_speed)
		
		STATE.DIE:
			if not is_on_floor():
				velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, 400.0 * delta)


func handle_movement(input_direction: float = 0, horizontal_velocity: float = WALK_VELOCITY, step: float = WALK_VELOCITY) -> void:
	if input_direction == 0:
		input_direction = signf(Input.get_axis("move_left", "move_right"))
	set_facing_direction(input_direction)
	velocity.x = move_toward(velocity.x, input_direction * horizontal_velocity, step)


func handle_sprint(delta: float) -> void:
	handle_movement(facing_direction, SPRINT_VELOCITY, SPRINT_ACCELERATION * delta)
	is_sprinting = Input.is_action_pressed("sprint") and not is_on_wall()


func set_facing_direction(direction: float) -> void:
	if direction != 0:
		if direction != facing_direction:
			facing_direction = direction
			animated_sprite.flip_h = direction < 0
			ledge_climb_ray_cast.position.x = direction * absf(ledge_climb_ray_cast.position.x)
			ledge_climb_ray_cast.target_position.x = direction * absf(ledge_climb_ray_cast.target_position.x)
			ledge_climb_ray_cast.force_raycast_update()
			wall_slide_ray_cast.position.x = direction * absf(wall_slide_ray_cast.position.x)
			wall_slide_ray_cast.target_position.x = direction * absf(wall_slide_ray_cast.target_position.x)
			wall_slide_ray_cast.force_raycast_update()
		if attack_area:
			attack_area.position.x = facing_direction * 40.0

func is_input_toward_facing() -> bool:
	return signf(Input.get_axis("move_left", "move_right")) == facing_direction


func is_input_against_facing() -> bool:
	return signf(Input.get_axis("move_left", "move_right")) == -facing_direction


func is_ledge() -> bool:
	return is_on_wall_only() and \
	ledge_climb_ray_cast.is_colliding() and \
	ledge_climb_ray_cast.get_collision_normal().is_equal_approx(Vector2.UP)


func is_space() -> bool:
	ledge_space_ray_cast.global_position = ledge_climb_ray_cast.get_collision_point()
	ledge_space_ray_cast.force_raycast_update()
	return not ledge_space_ray_cast.is_colliding()


func ledge_climb_offset() -> Vector2:
	var shape := player_collider.shape
	if shape is CapsuleShape2D:
		return Vector2(shape.radius * 2.0, -shape.height * 0.5)
	if shape is RectangleShape2D:
		return Vector2(shape.size.x, -shape.size.y * 0.5)
	return Vector2.ZERO


func can_wall_slide() -> bool:
	return is_on_wall_only() and wall_slide_ray_cast.is_colliding()
