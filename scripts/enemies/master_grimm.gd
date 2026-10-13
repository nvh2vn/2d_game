class_name MasterGrimm
extends BaseEnemy

## Troupe Master Grimm - Boss Fight Controller
## Phỏng theo cơ chế chiến đấu chuẩn của Hollow Knight:
## - Không tuần tra, chuyển động hoàn toàn bằng Teleport.
## - Cúi chào mở màn; phản đòn Pufferfish nếu bị tấn công lúc chào.
## - Chu kỳ tấn công linh hoạt: Firebats, Dash Uppercut, Dive Dash, Ground Spikes, Pufferfish.
## - Cơ chế Choáng (Stagger) vỡ thành đàn dơi.
## - Thanh máu hiển thị HUD với icon mặt nạ Grimm và hiệu ứng 2 lớp.

enum BossState {
	DORMANT,
	INTRO_BOW,
	IDLE_WAIT,
	TELEPORTING,
	ATTACK_FIREBATS,
	ATTACK_DASH_UPPERCUT,
	ATTACK_DIVE_DASH,
	ATTACK_SPIKES,
	ATTACK_PUFFERFISH,
	STAGGER,
	DEATH
}

@export_group("Boss Settings")
@export var boss_display_name: String = "TROUPE MASTER GRIMM"
@export var activation_range: float = 600.0
@export var auto_start_fight: bool = false
@export var arena_left_x: float = -9999.0
@export var arena_right_x: float = 9999.0
@export var arena_ground_y: float = 9999.0

@export_group("Combat Prefabs")
@export var firebat_scene: PackedScene = preload("res://scenes/enemies/grimm_firebat.tscn")
@export var spike_scene: PackedScene = preload("res://scenes/enemies/grimm_spike.tscn")
@export var fireball_scene: PackedScene = preload("res://scenes/enemies/grimm_fireball.tscn")
@export var stagger_bat_scene: PackedScene = preload("res://scenes/enemies/grimm_stagger_bat.tscn")
@export var health_bar_scene: PackedScene = preload("res://scenes/prefabs/ui/boss_health_bar.tscn")
@export var mask_icon: Texture2D = preload("res://assets/ui/journal/Nightmare King Grimm - bestiary__0000_grimm_nightmare_boss_portrait.png")

@export_group("Audio Streams")
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

@onready var attack_hitbox: Area2D = get_node_or_null("AttackHitbox")
@onready var attack_collision: CollisionShape2D = get_node_or_null("AttackHitbox/CollisionShape2D")
@onready var sfx_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

var state: BossState = BossState.DORMANT
var current_phase: int = 1
var is_invulnerable: bool = false
var damage_cooldown: float = 0.0
var facing_dir: float = -1.0
var player_target: Node2D = null
var boss_health_bar_inst: Node = null

# Cơ chế Stagger
var stagger_hits: int = 0
const HITS_TO_STAGGER: int = 13

# Ngưỡng máu kích hoạt Pufferfish (75%, 50%, 25%)
var puffer_threshold_75: bool = false
var puffer_threshold_50: bool = false
var puffer_threshold_25: bool = false
var queued_pufferfish: bool = false


func _on_enemy_ready() -> void:
	is_boss = true
	enemy_journal_id = "nightmare_king"
	max_health = 50
	current_health = max_health
	loot_tier = GeoDropHelper.EnemyTier.BOSS
	
	# Xác định biên độ đấu trường nếu chưa gán
	if arena_ground_y > 9000.0:
		arena_ground_y = global_position.y
	if arena_left_x < -9000.0:
		arena_left_x = global_position.x - 480.0
	if arena_right_x > 9000.0:
		arena_right_x = global_position.x + 480.0
		
	if attack_hitbox:
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
		if attack_collision:
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
		
	if not player_target or not is_instance_valid(player_target):
		_find_player()
		
	# Tự động kích hoạt khi người chơi đến gần
	if state == BossState.DORMANT and not is_dead:
		if auto_start_fight:
			start_encounter()
		elif player_target and is_instance_valid(player_target):
			var dist = global_position.distance_to(player_target.global_position)
			if dist <= activation_range:
				start_encounter()


func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		player_target = players[0]


func play_sfx(clip: AudioStream) -> void:
	if sfx_player and clip:
		sfx_player.stream = clip
		sfx_player.play()


# ==================== KHỞI ĐẦU TRẬN ĐẤU (INTRO & BOW) ====================
func start_encounter() -> void:
	if state != BossState.DORMANT or is_dead:
		return
	state = BossState.INTRO_BOW
	
	# Tạo thanh máu HUD ở cạnh dưới màn hình
	if health_bar_scene:
		boss_health_bar_inst = health_bar_scene.instantiate()
		get_tree().current_scene.add_child(boss_health_bar_inst)
		if boss_health_bar_inst.has_method("setup_boss"):
			boss_health_bar_inst.setup_boss(boss_display_name, max_health, mask_icon)
			
	play_sfx(appear_sfx)
	_look_at_player()
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("bow"):
		animated_sprite.play("bow")
		
	# Thời gian cúi chào ~ 1.7 giây
	await get_tree().create_timer(1.7).timeout
	if state == BossState.INTRO_BOW and not is_dead:
		_start_attack_loop()


# ==================== HỆ THỐNG NHẬN SÁT THƯƠNG ====================
func take_damage(amount: int = 1, _knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable or is_dead or damage_cooldown > 0.0:
		return
		
	if state == BossState.DORMANT:
		start_encounter()
		return
		
	damage_cooldown = 0.12 # Ngăn ngừa ăn multi-hit trong 1 đòn chém
	
	# TRƯỜNG HỢP ĐẶC BIỆT: Người chơi tấn công Grimm lúc đang cúi chào!
	# Grimm lập tức phản đòn Pufferfish ngay tại chỗ để trừng phạt!
	if state == BossState.INTRO_BOW:
		_trigger_bow_punish()
		return
		
	current_health -= amount
	stagger_hits += 1
	
	if boss_health_bar_inst and boss_health_bar_inst.has_method("update_health"):
		boss_health_bar_inst.update_health(current_health)
		
	# Hiệu ứng chớp đỏ
	if animated_sprite:
		var tw = create_tween()
		tw.tween_property(animated_sprite, "modulate", Color(2.8, 0.4, 0.4), 0.08)
		tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.08)
		
	# Kiểm tra tử trận
	if current_health <= 0:
		die()
		return
		
	# Kiểm tra các mốc máu Pufferfish (75%, 50%, 25%)
	var hp_ratio = float(current_health) / float(max_health)
	if hp_ratio <= 0.75 and not puffer_threshold_75:
		puffer_threshold_75 = true
		current_phase = 2
		queued_pufferfish = true
	elif hp_ratio <= 0.50 and not puffer_threshold_50:
		puffer_threshold_50 = true
		queued_pufferfish = true
	elif hp_ratio <= 0.25 and not puffer_threshold_25:
		puffer_threshold_25 = true
		current_phase = 3
		queued_pufferfish = true
		
	# Kiểm tra Choáng (Stagger)
	if stagger_hits >= HITS_TO_STAGGER and state != BossState.ATTACK_PUFFERFISH and state != BossState.STAGGER:
		stagger_hits = 0
		_trigger_stagger()


func take_damage_during_stagger(amount: int = 1) -> void:
	if is_dead:
		return
	current_health -= amount
	if boss_health_bar_inst and boss_health_bar_inst.has_method("update_health"):
		boss_health_bar_inst.update_health(current_health)
	if current_health <= 0:
		die()


# Đòn trừng phạt khi người chơi đánh lén lúc cúi chào
func _trigger_bow_punish() -> void:
	state = BossState.TELEPORTING
	is_invulnerable = true
	play_sfx(scream_sfx)
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("screech"):
		animated_sprite.play("screech")
		
	# Rung màn hình khi gầm thét
	var cam = get_viewport().get_camera_2d()
	if cam:
		var tw_cam = create_tween()
		for i in range(10):
			tw_cam.tween_property(cam, "offset", Vector2(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0)), 0.04)
		tw_cam.tween_property(cam, "offset", Vector2.ZERO, 0.04)
		
	await get_tree().create_timer(1.2).timeout
	if is_dead or not is_inside_tree():
		return
		
	_attack_pufferfish_bullet_hell(10.0)


# ==================== CHU KỲ TẤN CÔNG (FSM LOOP) ====================
func _start_attack_loop() -> void:
	_next_attack_cycle()


func _next_attack_cycle() -> void:
	if is_dead or not is_inside_tree() or state == BossState.STAGGER:
		return
		
	# Nếu người chơi đã chết, Grimm dừng tấn công và cúi chào
	if player_target and ("current_health" in player_target and player_target.current_health <= 0):
		if animated_sprite and animated_sprite.sprite_frames.has_animation("bow"):
			animated_sprite.play("bow")
		return
		
	# Nghỉ ngơi ngắn giữa các đòn đánh
	var rest_time = 0.6 if current_phase == 1 else (0.45 if current_phase == 2 else 0.35)
	state = BossState.IDLE_WAIT
	
	await get_tree().create_timer(rest_time).timeout
	if is_dead or not is_inside_tree() or state == BossState.STAGGER:
		return
		
	# Ưu tiên kích hoạt Pufferfish nếu đã chạm ngưỡng HP
	if queued_pufferfish:
		queued_pufferfish = false
		_attack_pufferfish_bullet_hell(8.5)
		return
		
	# Chọn ngẫu nhiên đòn đánh trong Attack Pool
	var pool = ["firebats", "dash_uppercut", "dive_dash", "spikes"]
	var pick = pool.pick_random()
	
	match pick:
		"firebats":
			_attack_firebats()
		"dash_uppercut":
			_attack_dash_uppercut()
		"dive_dash":
			_attack_dive_dash()
		"spikes":
			_attack_ground_spikes()


# ==================== DỊCH CHUYỂN (TELEPORT MECHANISM) ====================
func _teleport_to(target_pos: Vector2, play_sound: bool = true) -> void:
	state = BossState.TELEPORTING
	is_invulnerable = true
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		
	if play_sound:
		play_sfx(teleport_out_sfx)
		
	if animated_sprite and animated_sprite.sprite_frames.has_animation("teleport_out"):
		animated_sprite.play("teleport_out")
		
	var tw_out = create_tween()
	tw_out.tween_property(animated_sprite, "modulate:a", 0.0, 0.18)
	await tw_out.finished
	if is_dead or not is_inside_tree():
		return
		
	# Dịch chuyển vị trí
	target_pos.x = clampf(target_pos.x, arena_left_x + 60.0, arena_right_x - 60.0)
	global_position = target_pos
	_look_at_player()
	
	if play_sound:
		play_sfx(teleport_in_sfx)
		
	if animated_sprite and animated_sprite.sprite_frames.has_animation("teleport_in"):
		animated_sprite.play("teleport_in")
		
	var tw_in = create_tween()
	tw_in.tween_property(animated_sprite, "modulate:a", 1.0, 0.14)
	await tw_in.finished
	animated_sprite.modulate.a = 1.0
	
	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
		hurtbox.set_deferred("monitorable", true)
	is_invulnerable = false


func _look_at_player() -> void:
	if not player_target or not is_instance_valid(player_target):
		_find_player()
	if player_target and is_instance_valid(player_target):
		facing_dir = 1.0 if player_target.global_position.x > global_position.x else -1.0
		if animated_sprite:
			animated_sprite.flip_h = (facing_dir > 0)


# ==================== ĐÒN 1: FIREBATS (DƠI LỬA) ====================
func _attack_firebats() -> void:
	state = BossState.ATTACK_FIREBATS
	if not player_target or not is_instance_valid(player_target):
		_find_player()
		
	# Teleport ra góc xa đấu trường
	var spawn_x = (arena_left_x + 90.0) if facing_dir > 0 else (arena_right_x - 90.0)
	await _teleport_to(Vector2(spawn_x, arena_ground_y))
	if is_dead or not is_inside_tree():
		return
		
	play_sfx(cast_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("cast_firebats"):
		animated_sprite.play("cast_firebats")
		
	# Bắn 3 con dơi (hoặc 4 con ở phase 3) bay lượn sóng
	var bat_count = 4 if current_phase == 3 else 3
	for i in range(bat_count):
		await get_tree().create_timer(0.32).timeout
		if is_dead or not is_inside_tree() or state != BossState.ATTACK_FIREBATS:
			return
		if firebat_scene and get_parent():
			var fb = firebat_scene.instantiate()
			get_parent().add_child(fb)
			var shoot_pos = global_position + Vector2(facing_dir * 50.0, -80.0 - i * 15.0)
			var shoot_dir = Vector2(facing_dir, 0.0)
			var phase_offset = float(i) * 1.6
			fb.setup(shoot_dir, shoot_pos, 380.0, phase_offset)
			
	await get_tree().create_timer(0.5).timeout
	_next_attack_cycle()


# ==================== ĐÒN 2: DASH UPPERCUT & FIREBALL SHOWER ====================
func _attack_dash_uppercut() -> void:
	state = BossState.ATTACK_DASH_UPPERCUT
	if not player_target or not is_instance_valid(player_target):
		_find_player()
	var p_x = player_target.global_position.x if player_target and is_instance_valid(player_target) else global_position.x
	var start_x = p_x - facing_dir * 200.0
	
	await _teleport_to(Vector2(start_x, arena_ground_y))
	if is_dead or not is_inside_tree():
		return
		
	# 1. Lao chém quét sàn
	play_sfx(dash_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("dash_slash"):
		animated_sprite.play("dash_slash")
	if attack_collision:
		attack_collision.set_deferred("disabled", false)
		
	var dash_end_x = clampf(global_position.x + facing_dir * 290.0, arena_left_x + 40.0, arena_right_x - 40.0)
	var tw_dash = create_tween()
	tw_dash.tween_property(self, "global_position:x", dash_end_x, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw_dash.finished
	if is_dead or not is_inside_tree():
		return
		
	# 2. Uppercut vút lên trần
	play_sfx(uppercut_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("uppercut"):
		animated_sprite.play("uppercut")
		
	var tw_jump = create_tween()
	tw_jump.tween_property(self, "global_position:y", arena_ground_y - 210.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw_jump.finished
	if attack_collision:
		attack_collision.set_deferred("disabled", true)
	if is_dead or not is_inside_tree():
		return
		
	# 3. Nổ ra 5-6 quả cầu lửa rơi hình vòng cung xuống sàn
	_spawn_fireball_shower(global_position)
	
	# Biến mất sau khi nổ cầu lửa
	await get_tree().create_timer(0.25).timeout
	_next_attack_cycle()


func _spawn_fireball_shower(origin: Vector2) -> void:
	if not fireball_scene or not get_parent():
		return
	var angles = [-75, -45, -15, 15, 45, 75]
	for a in angles:
		var rad = deg_to_rad(a + 90.0)
		var dir = Vector2(cos(rad), sin(rad))
		var fb = fireball_scene.instantiate()
		get_parent().add_child(fb)
		fb.setup(dir, origin + dir * 25.0, 240.0, 320.0)


# ==================== ĐÒN 3: DIVE DASH (LAO XIÊN & TRƯỢT) ====================
func _attack_dive_dash() -> void:
	state = BossState.ATTACK_DIVE_DASH
	if not player_target or not is_instance_valid(player_target):
		_find_player()
	var p_x = player_target.global_position.x if player_target and is_instance_valid(player_target) else global_position.x
	var air_x = p_x - facing_dir * 170.0
	
	# Teleport lên cao
	await _teleport_to(Vector2(air_x, arena_ground_y - 210.0))
	if is_dead or not is_inside_tree():
		return
		
	# 1. Lao xiên xuống đất
	play_sfx(airdash_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("dive"):
		animated_sprite.play("dive")
	if attack_collision:
		attack_collision.set_deferred("disabled", false)
		
	var land_x = clampf(global_position.x + facing_dir * 180.0, arena_left_x + 40.0, arena_right_x - 40.0)
	var tw_dive = create_tween()
	tw_dive.tween_property(self, "global_position", Vector2(land_x, arena_ground_y), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw_dive.finished
	if is_dead or not is_inside_tree():
		return
		
	# 2. Trượt dài quét sàn (Slide)
	play_sfx(dash_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("slide"):
		animated_sprite.play("slide")
		
	var slide_end_x = clampf(global_position.x + facing_dir * 240.0, arena_left_x + 40.0, arena_right_x - 40.0)
	var tw_slide = create_tween()
	tw_slide.tween_property(self, "global_position:x", slide_end_x, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw_slide.finished
	if attack_collision:
		attack_collision.set_deferred("disabled", true)
		
	await get_tree().create_timer(0.2).timeout
	_next_attack_cycle()


# ==================== ĐÒN 4: GROUND SPIKES (BÀN CHÔNG GAI) ====================
func _attack_ground_spikes() -> void:
	state = BossState.ATTACK_SPIKES
	# Teleport đứng trên sàn giữa phòng
	var center_x = (arena_left_x + arena_right_x) * 0.5
	await _teleport_to(Vector2(center_x, arena_ground_y))
	if is_dead or not is_inside_tree():
		return
		
	# Cắm áo choàng xuống đất
	if animated_sprite and animated_sprite.sprite_frames.has_animation("spikes_cast"):
		animated_sprite.play("spikes_cast")
		
	# Triệu hồi hàng gai nhọn mọc khắp sàn với bước nhảy đều
	if spike_scene and get_parent():
		var step = 85.0
		var cur_x = arena_left_x + 45.0
		while cur_x < arena_right_x - 30.0:
			var spk = spike_scene.instantiate()
			spk.global_position = Vector2(cur_x, arena_ground_y)
			get_parent().add_child(spk)
			cur_x += step
			
	await get_tree().create_timer(1.2).timeout
	_next_attack_cycle()


# ==================== ĐÒN ĐẶC BIỆT: PUFFERFISH (BULLET HELL) ====================
func _attack_pufferfish_bullet_hell(duration: float = 8.5) -> void:
	state = BossState.ATTACK_PUFFERFISH
	is_invulnerable = true # Miễn nhiễm cận chiến trong lúc hóa cầu
	if attack_collision:
		attack_collision.set_deferred("disabled", true)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		
	# Teleport lên chính giữa không trung đấu trường
	var center_x = (arena_left_x + arena_right_x) * 0.5
	await _teleport_to(Vector2(center_x, arena_ground_y - 130.0))
	if is_dead or not is_inside_tree():
		return
		
	play_sfx(balloon_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("pufferfish"):
		animated_sprite.play("pufferfish")
		
	# Bắn các làn sóng đạn nhịp điệu (Bullet Hell) sang hai bên
	var wave_count = int(duration / 0.52)
	for w in range(wave_count):
		if is_dead or not is_inside_tree():
			return
		_spawn_pufferfish_wave(w)
		await get_tree().create_timer(0.52).timeout
		
	# Kết thúc Pufferfish
	is_invulnerable = false
	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
		hurtbox.set_deferred("monitorable", true)
		
	await get_tree().create_timer(0.4).timeout
	_next_attack_cycle()


func _spawn_pufferfish_wave(wave_index: int) -> void:
	if not fireball_scene or not get_parent():
		return
		
	# Hollow Knight Pufferfish pattern: các quả cầu đỏ bay ngang ở độ cao thấp (nhảy né) và độ cao cao
	var heights = [-10.0, 50.0] if (wave_index % 2 == 0) else [20.0, 75.0]
	for h_offset in heights:
		for dir_x in [-1.0, 1.0]:
			var fb = fireball_scene.instantiate()
			get_parent().add_child(fb)
			var shoot_pos = global_position + Vector2(dir_x * 55.0, h_offset)
			fb.setup(Vector2(dir_x, 0.0), shoot_pos, 280.0, 0.0)


# ==================== CƠ CHẾ CHOÁNG (STAGGER / VỠ THÀNH DƠI) ====================
func _trigger_stagger() -> void:
	state = BossState.STAGGER
	is_invulnerable = true
	if attack_collision:
		attack_collision.set_deferred("disabled", true)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		
	play_sfx(explode_bats_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("stagger"):
		animated_sprite.play("stagger")
		
	var tw = create_tween()
	tw.tween_property(animated_sprite, "modulate:a", 0.0, 0.2)
	await tw.finished
	if is_dead or not is_inside_tree():
		return
		
	# Sinh ra đàn dơi nhỏ bay tán loạn
	var bats = []
	var bat_count = 12
	var reform_target = Vector2((arena_left_x + arena_right_x) * 0.5, arena_ground_y)
	
	if stagger_bat_scene and get_parent():
		for i in range(bat_count):
			var b = stagger_bat_scene.instantiate()
			get_parent().add_child(b)
			b.setup(global_position, (i == 0), self) # Con dơi đầu tiên là mục tiêu chính nhận đòn
			bats.append(b)
			
	# Choáng trong 3.5s
	await get_tree().create_timer(3.5).timeout
	if is_dead or not is_inside_tree():
		for b in bats:
			if is_instance_valid(b): b.queue_free()
		return
		
	# Các con dơi bay hội tụ lại
	for b in bats:
		if is_instance_valid(b):
			b.start_reforming(reform_target)
			
	await get_tree().create_timer(0.4).timeout
	# Re-appear Grimm
	await _teleport_to(reform_target)
	_next_attack_cycle()


# ==================== VA CHẠM THỂ CHẤT VỚI PLAYER ====================
func _on_attack_hitbox_body_entered(body: Node) -> void:
	if is_dead:
		return
	if is_player(body):
		if body.has_method("take_damage") and ("is_invincible" not in body or not body.is_invincible):
			body.take_damage(2, global_position)


# ==================== TỬ TRẬN & KẾT THÚC TRẬN ĐẤU ====================
func die() -> void:
	if is_dead:
		return
	is_dead = true
	state = BossState.DEATH
	is_invulnerable = true
	
	if attack_collision:
		attack_collision.set_deferred("disabled", true)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
		
	# Ẩn và hủy thanh máu Boss HUD
	if boss_health_bar_inst and is_instance_valid(boss_health_bar_inst) and boss_health_bar_inst.has_method("hide_bar"):
		boss_health_bar_inst.hide_bar()
		
	play_sfx(defeat_sfx)
	play_sfx(explode_bats_sfx)
	
	# Rơi cơn mưa Geo khổng lồ
	if get_parent():
		GeoDropHelper.drop_from_tier(global_position, get_parent(), GeoDropHelper.EnemyTier.BOSS)
		
	# Ghi nhận vào Hunter's Journal
	if SaveManager.instance:
		SaveManager.instance.record_enemy_kill("nightmare_king")
		
	# Hoạt ảnh tử trận
	if animated_sprite and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		
	# Mờ dần và giải phóng
	var tw = create_tween()
	tw.tween_property(animated_sprite, "modulate:a", 0.0, 1.8)
	await tw.finished
	queue_free()
