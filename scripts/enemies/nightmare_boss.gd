class_name NightmareBoss
extends BaseEnemy

enum State {
	INTRO,
	IDLE,
	TELEPORT_OUT,
	TELEPORT_IN,
	DASH_UPPERCUT,
	DIVE_DASH,
	FIRE_BATS,
	FLOOR_SPIKES,
	FLAME_PILLARS,
	BALLOON_BULLET_HELL,
	SCREAM_TRANSITION,
	DEFEATED
}

@export_group("Boss Settings")
@export var boss_name: String = "NIGHTMARE KING"
@export var activation_range: float = 650.0
@export var auto_activate: bool = false
@export var arena_left_x: float = -9999.0
@export var arena_right_x: float = 9999.0
@export var arena_ground_y: float = 9999.0

@export_group("Projectiles & Prefabs")
@export var fireball_scene: PackedScene = preload("res://scenes/prefabs/enemies/nightmare_fireball.tscn")
@export var spike_scene: PackedScene = preload("res://scenes/prefabs/enemies/nightmare_spike.tscn")
@export var pillar_scene: PackedScene = preload("res://scenes/prefabs/enemies/nightmare_pillar.tscn")
@export var health_bar_scene: PackedScene = preload("res://scenes/prefabs/ui/boss_health_bar.tscn")

@export_group("Boss Audio")
@export var appear_sfx: AudioStream = preload("res://assets/audio/nightmare/appear.mp3")
@export var teleport_in_sfx: AudioStream = preload("res://assets/audio/nightmare/teleport_in.mp3")
@export var teleport_out_sfx: AudioStream = preload("res://assets/audio/nightmare/teleport_out.mp3")
@export var dash_sfx: AudioStream = preload("res://assets/audio/nightmare/dash.mp3")
@export var uppercut_sfx: AudioStream = preload("res://assets/audio/nightmare/uppercut.mp3")
@export var airdash_sfx: AudioStream = preload("res://assets/audio/nightmare/airdash.mp3")
@export var cast_sfx: AudioStream = preload("res://assets/audio/nightmare/cast_1.mp3")
@export var scream_sfx: AudioStream = preload("res://assets/audio/nightmare/scream.mp3")
@export var balloon_sfx: AudioStream = preload("res://assets/audio/nightmare/balloon_fireballs_loop.mp3")
@export var defeat_sfx: AudioStream = preload("res://assets/audio/nightmare/defeat.mp3")
@export var explode_bats_sfx: AudioStream = preload("res://assets/audio/nightmare/explode_into_bats.mp3")

@onready var sfx_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_collision: CollisionShape2D = $AttackHitbox/CollisionShape2D

var current_phase: int = 1
var current_state: State = State.IDLE
var boss_health_bar_inst: Node = null
var player: CharacterBody2D = null

var is_active: bool = false
var is_invulnerable: bool = false
var damage_cooldown: float = 0.0
var has_done_balloon_phase2: bool = false
var has_done_balloon_phase3: bool = false
var facing_dir: float = -1.0


func _on_enemy_ready() -> void:
	max_health = 45
	current_health = max_health
	loot_tier = GeoDropHelper.EnemyTier.BOSS
	
	# Tự động lấy tọa độ đấu trường theo vị trí đặt Boss nếu chưa cấu hình
	if arena_ground_y > 9000.0:
		arena_ground_y = global_position.y
	if arena_left_x < -9000.0:
		arena_left_x = global_position.x - 450.0
	if arena_right_x > 9000.0:
		arena_right_x = global_position.x + 450.0
	
	if attack_hitbox:
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
		attack_collision.set_deferred("disabled", true)
		
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")


func _exit_tree() -> void:
	if boss_health_bar_inst and is_instance_valid(boss_health_bar_inst):
		boss_health_bar_inst.queue_free()


func _physics_process(delta: float) -> void:
	if damage_cooldown > 0.0:
		damage_cooldown -= delta
	if not player or not is_instance_valid(player):
		_find_player()
		
	if not is_active and not is_dead:
		if auto_activate:
			_activate_boss()
		elif player and is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			if dist <= activation_range:
				_activate_boss()


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		player = players[0]


func play_boss_sfx(stream: AudioStream) -> void:
	if sfx_player and stream:
		sfx_player.stream = stream
		sfx_player.play()


func _activate_boss() -> void:
	if is_active or is_dead: return
	is_active = true
	
	# Khởi tạo thanh máu Boss HUD
	if health_bar_scene:
		boss_health_bar_inst = health_bar_scene.instantiate()
		get_tree().current_scene.add_child(boss_health_bar_inst)
		boss_health_bar_inst.setup_boss(boss_name, max_health)

	_start_intro()


func _start_intro() -> void:
	current_state = State.INTRO
	play_boss_sfx(appear_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("bow"):
		animated_sprite.play("bow")
	
	# Cúi chào 1.5s rồi bước vào trận chiến
	await get_tree().create_timer(1.6).timeout
	if current_state == State.INTRO and not is_dead:
		_next_attack_cycle()


func take_damage(amount: int = 1, _knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable or is_dead or damage_cooldown > 0.0:
		return
	
	if not is_active:
		_activate_boss()
	
	damage_cooldown = 0.12 # Ngăn ngừa nhận 2 lần sát thương trong 1 nhịp chém
		
	# Nếu đánh trúng lúc đang cúi chào -> Kích hoạt Scream nộ ngay lập tức
	if current_state == State.INTRO:
		_trigger_scream_rage()
		return
		
	current_health -= amount
	if boss_health_bar_inst and boss_health_bar_inst.has_method("update_health"):
		boss_health_bar_inst.update_health(current_health)
		
	# Hiệu ứng chớp đỏ
	if animated_sprite:
		var tw = create_tween()
		tw.tween_property(animated_sprite, "modulate", Color(3.0, 0.4, 0.4), 0.08)
		tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.08)
		
	if (DebugManager and DebugManager.is_one_hit) or amount >= 99999 or current_health <= 0:
		current_health = 0
		if boss_health_bar_inst and boss_health_bar_inst.has_method("update_health"):
			boss_health_bar_inst.update_health(0)
		die()
		return

	# Kiểm tra chuyển Phase
	var hp_pct = float(current_health) / float(max_health)
	if hp_pct <= 0.7 and current_phase == 1:
		current_phase = 2
		_trigger_scream_rage()
		return
	elif hp_pct <= 0.35 and current_phase == 2:
		current_phase = 3
		_trigger_scream_rage()
		return


func _trigger_scream_rage() -> void:
	current_state = State.SCREAM_TRANSITION
	is_invulnerable = true
	attack_collision.set_deferred("disabled", true)
	
	play_boss_sfx(scream_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("scream"):
		animated_sprite.play("scream")
		
	# Rung màn hình khi gầm thét
	var cam = get_viewport().get_camera_2d()
	if cam:
		var tw_cam = create_tween()
		for i in range(8):
			tw_cam.tween_property(cam, "offset", Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)), 0.05)
		tw_cam.tween_property(cam, "offset", Vector2.ZERO, 0.05)
		
	await get_tree().create_timer(1.4).timeout
	if is_dead or not is_inside_tree(): return
	is_invulnerable = false
	
	# Kích hoạt chiêu Pufferfish Balloon ngay khi nộ
	_attack_balloon_bullet_hell()


func _next_attack_cycle() -> void:
	if is_dead or not is_inside_tree() or current_state == State.SCREAM_TRANSITION: return
	
	# Nếu player đã chết (Game Over), Boss dừng tấn công
	if player and ("current_health" in player and player.current_health <= 0):
		if animated_sprite and animated_sprite.sprite_frames.has_animation("bow"):
			animated_sprite.play("bow")
		return
	
	# Thời gian nghỉ ngơi theo từng phase
	var rest_time = 0.75 if current_phase == 1 else (0.5 if current_phase == 2 else 0.35)
	await get_tree().create_timer(rest_time).timeout
	if is_dead or not is_inside_tree() or current_state == State.SCREAM_TRANSITION: return
	
	# Chọn chiêu thức tiếp theo ngẫu nhiên dựa vào Phase
	var attacks = ["dash_uppercut", "dive_dash", "fire_bats", "floor_spikes"]
	if current_phase >= 2:
		attacks.append("flame_pillars")
		if not has_done_balloon_phase2 and current_phase == 2 and randf() < 0.35:
			has_done_balloon_phase2 = true
			attacks = ["balloon"]
		elif not has_done_balloon_phase3 and current_phase == 3 and current_health <= 15:
			has_done_balloon_phase3 = true
			attacks = ["balloon"]
			
	var chosen_attack = attacks.pick_random()
	match chosen_attack:
		"dash_uppercut":
			_attack_dash_uppercut()
		"dive_dash":
			_attack_dive_dash()
		"fire_bats":
			_attack_fire_bats()
		"floor_spikes":
			_attack_floor_spikes()
		"flame_pillars":
			_attack_flame_pillars()
		"balloon":
			_attack_balloon_bullet_hell()


func _teleport_to(target_pos: Vector2) -> void:
	is_invulnerable = true
	play_boss_sfx(teleport_out_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("teleport"):
		animated_sprite.play("teleport")
	
	if animated_sprite:
		var tw = create_tween()
		tw.tween_property(animated_sprite, "modulate:a", 0.0, 0.15)
		await tw.finished
	if is_dead or not is_inside_tree(): return
	
	# Giới hạn tọa độ teleport nằm gọn trong sàn đấu
	target_pos.x = clampf(target_pos.x, arena_left_x + 60.0, arena_right_x - 60.0)
	global_position = target_pos
	_look_at_player()
	play_boss_sfx(teleport_in_sfx)
	
	if animated_sprite:
		var tw_in = create_tween()
		tw_in.tween_property(animated_sprite, "modulate:a", 1.0, 0.15)
		await tw_in.finished
		animated_sprite.modulate.a = 1.0
	is_invulnerable = false


func _look_at_player() -> void:
	if not player or not is_instance_valid(player): _find_player()
	if player and is_instance_valid(player):
		facing_dir = 1.0 if player.global_position.x > global_position.x else -1.0
		if animated_sprite:
			animated_sprite.flip_h = (facing_dir > 0)


# ==================== CHIÊU 1: DASH & UPPERCUT ====================
func _attack_dash_uppercut() -> void:
	current_state = State.DASH_UPPERCUT
	if not player or not is_instance_valid(player): _find_player()
	var player_x = player.global_position.x if player and is_instance_valid(player) else global_position.x
	var start_x = player_x - facing_dir * 180.0
	
	await _teleport_to(Vector2(start_x, arena_ground_y))
	if is_dead or not is_inside_tree(): return
	
	# 1. StartDash
	if animated_sprite and animated_sprite.sprite_frames.has_animation("start_dash"):
		animated_sprite.play("start_dash")
	await get_tree().create_timer(0.2).timeout
	if is_dead or not is_inside_tree(): return
	
	# 2. Dash lướt nhanh quét sàn
	play_boss_sfx(dash_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("dash"):
		animated_sprite.play("dash")
	attack_collision.set_deferred("disabled", false)
	
	var dash_target_x = clampf(global_position.x + facing_dir * 280.0, arena_left_x + 40.0, arena_right_x - 40.0)
	var dash_tw = create_tween()
	dash_tw.tween_property(self, "global_position:x", dash_target_x, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await dash_tw.finished
	if is_dead or not is_inside_tree(): return
	
	# 3. UpperCut hất tung lên trời
	play_boss_sfx(uppercut_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("uppercut"):
		animated_sprite.play("uppercut")
		
	var jump_tw = create_tween()
	jump_tw.tween_property(self, "global_position:y", arena_ground_y - 200.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await jump_tw.finished
	attack_collision.set_deferred("disabled", true)
	if is_dead or not is_inside_tree(): return
	
	# 4. Bắn chùm cầu lửa đỏ rơi từ trên trời xuống
	_spawn_fireball_shower(global_position)
	
	# 5. Biến mất và chuẩn bị chu kỳ mới
	await get_tree().create_timer(0.3).timeout
	_next_attack_cycle()


func _spawn_fireball_shower(origin: Vector2) -> void:
	if not fireball_scene or not get_parent(): return
	for angle_deg in [-60, -30, 0, 30, 60]:
		var rad = deg_to_rad(angle_deg + 90.0)
		var dir = Vector2(cos(rad), sin(rad))
		var fb = fireball_scene.instantiate()
		get_parent().add_child(fb)
		fb.setup(dir, origin + dir * 20.0, 260.0)


# ==================== CHIÊU 2: DIVE AIR DASH ====================
func _attack_dive_dash() -> void:
	current_state = State.DIVE_DASH
	if not player or not is_instance_valid(player): _find_player()
	var player_x = player.global_position.x if player and is_instance_valid(player) else global_position.x
	var air_x = player_x - facing_dir * 140.0
	
	await _teleport_to(Vector2(air_x, arena_ground_y - 180.0))
	if is_dead or not is_inside_tree(): return
	
	# 1. StartAirDash
	if animated_sprite and animated_sprite.sprite_frames.has_animation("start_air_dash"):
		animated_sprite.play("start_air_dash")
	await get_tree().create_timer(0.25).timeout
	if is_dead or not is_inside_tree(): return
	
	# 2. Lao xiên xuống đất
	play_boss_sfx(airdash_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("air_dash"):
		animated_sprite.play("air_dash")
	attack_collision.set_deferred("disabled", false)
	
	var dive_tw = create_tween()
	var land_x = clampf(global_position.x + facing_dir * 160.0, arena_left_x + 40.0, arena_right_x - 40.0)
	var target_land = Vector2(land_x, arena_ground_y)
	dive_tw.tween_property(self, "global_position", target_land, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await dive_tw.finished
	if is_dead or not is_inside_tree(): return
	
	# 3. Lướt ngang quét sàn
	play_boss_sfx(dash_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("dash"):
		animated_sprite.play("dash")
		
	var slide_x = clampf(global_position.x + facing_dir * 200.0, arena_left_x + 40.0, arena_right_x - 40.0)
	var slide_tw = create_tween()
	slide_tw.tween_property(self, "global_position:x", slide_x, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await slide_tw.finished
	attack_collision.set_deferred("disabled", true)
	
	await get_tree().create_timer(0.2).timeout
	_next_attack_cycle()


# ==================== CHIÊU 3: FIRE BATS (CAST) ====================
func _attack_fire_bats() -> void:
	current_state = State.FIRE_BATS
	if not player or not is_instance_valid(player): _find_player()
	var corner_x = (arena_left_x + 100.0) if facing_dir > 0 else (arena_right_x - 100.0)
	
	await _teleport_to(Vector2(corner_x, arena_ground_y - 20.0))
	if is_dead or not is_inside_tree(): return
	
	play_boss_sfx(cast_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("cast"):
		animated_sprite.play("cast")
		
	# Bắn liên hoàn 3-4 đợt cầu lửa
	var count = 4 if current_phase == 3 else 3
	for i in range(count):
		await get_tree().create_timer(0.28).timeout
		if is_dead or not is_inside_tree(): return
		if fireball_scene and get_parent():
			var fb = fireball_scene.instantiate()
			get_parent().add_child(fb)
			var shoot_dir = Vector2(facing_dir, randf_range(-0.15, 0.15))
			fb.setup(shoot_dir, global_position + Vector2(facing_dir * 40.0, -40.0), 380.0)
			
	await get_tree().create_timer(0.4).timeout
	_next_attack_cycle()


# ==================== CHIÊU 4: FLOOR SPIKES ====================
func _attack_floor_spikes() -> void:
	current_state = State.FLOOR_SPIKES
	await _teleport_to(Vector2((arena_left_x + arena_right_x) * 0.5, arena_ground_y - 150.0))
	if is_dead or not is_inside_tree(): return
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("spike"):
		animated_sprite.play("spike")
		
	# Triệu hồi hàng gai nhọn cách nhau 85px trên toàn sàn đấu
	if spike_scene and get_parent():
		var step = 85.0
		var cur_x = arena_left_x + 40.0
		while cur_x < arena_right_x:
			var spike = spike_scene.instantiate()
			spike.global_position = Vector2(cur_x, arena_ground_y)
			get_parent().add_child(spike)
			cur_x += step
			
	await get_tree().create_timer(1.2).timeout
	_next_attack_cycle()


# ==================== CHIÊU 5: FLAME PILLARS ====================
func _attack_flame_pillars() -> void:
	current_state = State.FLAME_PILLARS
	await _teleport_to(Vector2((arena_left_x + arena_right_x) * 0.5, arena_ground_y - 160.0))
	if is_dead or not is_inside_tree(): return
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("cast"):
		animated_sprite.play("cast")
		
	# Triệu hồi 4 cột lửa lần lượt theo vị trí player
	for i in range(4):
		if not player or not is_instance_valid(player): _find_player()
		var p_x = player.global_position.x if player and is_instance_valid(player) else global_position.x
		if pillar_scene and get_parent():
			var pillar = pillar_scene.instantiate()
			pillar.global_position = Vector2(p_x, arena_ground_y)
			get_parent().add_child(pillar)
		await get_tree().create_timer(0.45).timeout
		if is_dead or not is_inside_tree(): return
		
	await get_tree().create_timer(0.4).timeout
	_next_attack_cycle()


# ==================== CHIÊU ĐẶC BIỆT: PUFFERFISH BALLOON ====================
func _attack_balloon_bullet_hell() -> void:
	current_state = State.BALLOON_BULLET_HELL
	is_invulnerable = true
	attack_collision.set_deferred("disabled", true)
	
	await _teleport_to(Vector2((arena_left_x + arena_right_x) * 0.5, arena_ground_y - 120.0))
	if is_dead or not is_inside_tree(): return
	
	# 1. StartBalloon
	if animated_sprite and animated_sprite.sprite_frames.has_animation("start_balloon"):
		animated_sprite.play("start_balloon")
	await get_tree().create_timer(0.35).timeout
	if is_dead or not is_inside_tree(): return
	
	# 2. Hóa thành quả cầu Balloon và xả đạn
	play_boss_sfx(balloon_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("balloon"):
		animated_sprite.play("balloon")
		
	var waves = 7 if current_phase >= 3 else 5
	for w in range(waves):
		if is_dead or not is_inside_tree(): return
		if fireball_scene and get_parent():
			for angle_deg in range(0, 360, 45):
				var rad = deg_to_rad(angle_deg + w * 12.0)
				var dir = Vector2(cos(rad), sin(rad))
				var fb = fireball_scene.instantiate()
				get_parent().add_child(fb)
				fb.setup(dir, global_position + dir * 30.0, 240.0)
		await get_tree().create_timer(0.45).timeout
		
	is_invulnerable = false
	await get_tree().create_timer(0.5).timeout
	_next_attack_cycle()


func _on_attack_hitbox_body_entered(body: Node) -> void:
	if is_dead: return
	if body.is_in_group("player") or body.name == "PlayerController" or body.name.begins_with("Player"):
		if body.has_method("take_damage") and ("is_invincible" not in body or not body.is_invincible):
			body.take_damage(2, global_position)


func die() -> void:
	if is_dead: return
	is_dead = true
	current_state = State.DEFEATED
	attack_collision.set_deferred("disabled", true)
	
	if boss_health_bar_inst and is_instance_valid(boss_health_bar_inst) and boss_health_bar_inst.has_method("hide_bar"):
		boss_health_bar_inst.hide_bar()
		
	play_boss_sfx(defeat_sfx)
	play_boss_sfx(explode_bats_sfx)
	
	# Rơi cơn mưa Geo khổng lồ
	if get_parent():
		GeoDropHelper.drop_from_tier(global_position, get_parent(), GeoDropHelper.EnemyTier.BOSS)
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("die"):
		animated_sprite.play("die")
		
	# Rung chấn và mờ dần
	var tw = create_tween()
	tw.tween_property(animated_sprite, "modulate:a", 0.0, 1.6)
	await tw.finished
	queue_free()
