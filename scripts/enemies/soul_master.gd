class_name SoulMaster
extends BaseEnemy

## Soul Master (Bậc Thầy Linh Hồn) - Boss Controller
## - Bay lơ lửng, chuyển động hoàn toàn bằng Teleport.
## - Bắn Soul Orb bám đuôi (Homing).
## - Vòng xoay hộ thể (Rotating Orbs Pass) 4 quả cầu xoay quanh thân.
## - Đập sàn xung kích (Desolate Dive / Slam) kèm đòn đánh lừa (Feint Dive 30%).
## - Lướt quét sàn (Dash / Lunge).
## - Trạng thái kiệt sức (Stagger) rơi xuống đất trong 3.5s.
## - Đồng bộ thanh máu Boss HUD với icon mặt nạ đặc trưng.

enum BossState {
	DORMANT,
	INTRO,
	IDLE_HOVER,
	TELEPORTING,
	ATTACK_ORB_SHOT,
	ATTACK_ORB_SHIELD_PASS,
	ATTACK_SLAM,
	ATTACK_DASH_LUNGE,
	STAGGER,
	DEATH
}

signal boss_defeated()

@export_group("Boss Settings")
@export var boss_display_name: String = "SOUL MASTER"
@export var activation_range: float = 620.0
@export var auto_start_fight: bool = false
## Nếu bật, Boss sẽ chờ tín hiệu kích hoạt từ Cutscene / TriggerArea thay vì tự bật theo tầm nhìn
@export var wait_for_trigger: bool = false
@export var arena_left_x: float = -9999.0
@export var arena_right_x: float = 9999.0
@export var arena_ground_y: float = 9999.0

@export_group("Combat Prefabs")
@export var orb_scene: PackedScene = preload("res://scenes/enemies/soul_orb.tscn")
@export var shockwave_scene: PackedScene = preload("res://scenes/enemies/soul_shockwave.tscn")
@export var health_bar_scene: PackedScene = preload("res://scenes/prefabs/ui/boss_health_bar.tscn")
@export var boss_icon: Texture2D = preload("res://assets/ui/journal/Soul Master - bestiary_mage_lord_s.png")

@export_group("Audio Streams")
@export var teleport_sfx: AudioStream = preload("res://assets/audio/soul_master/teleport.mp3")
@export var cast_sfx: AudioStream = preload("res://assets/audio/soul_master/cast_0.mp3")
@export var cast_alt_sfx: AudioStream = preload("res://assets/audio/soul_master/cast_1.mp3")
@export var roar_sfx: AudioStream = preload("res://assets/audio/soul_master/roar.mp3")
@export var angry_sfx: AudioStream = preload("res://assets/audio/soul_master/angry_0.mp3")
@export var slam_ground_sfx: AudioStream = preload("res://assets/audio/soul_master/ground.mp3")
@export var slash_sfx: AudioStream = preload("res://assets/audio/soul_master/slash.mp3")
@export var start_stun_sfx: AudioStream = preload("res://assets/audio/soul_master/startstun.mp3")
@export var stun_sfx: AudioStream = preload("res://assets/audio/soul_master/stun.mp3")
@export var start_death_sfx: AudioStream = preload("res://assets/audio/soul_master/startdeath.mp3")
@export var death_sfx: AudioStream = preload("res://assets/audio/soul_master/death.mp3")
@export var explode_sfx: AudioStream = preload("res://assets/audio/soul_master/explode.mp3")

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
const HITS_TO_STAGGER: int = 14

# Chiêu thức đã thực hiện gần đây để tránh lặp lại cùng 1 đòn
var last_attack: String = ""


func _on_enemy_ready() -> void:
	is_boss = true
	enemy_journal_id = "mage_lord"
	max_health = 45
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.BOSS
	
	if arena_ground_y > 9000.0:
		arena_ground_y = global_position.y
	if arena_left_x < -9000.0:
		arena_left_x = global_position.x - 460.0
	if arena_right_x > 9000.0:
		arena_right_x = global_position.x + 460.0
		
	# Kết nối AttackHitbox gây sát thương đặc biệt
	if attack_hitbox:
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
		attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
		if attack_collision:
			attack_collision.set_deferred("disabled", true)
			
	# Kết nối thêm signal area_entered cho Hitbox chạm thân
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		hitbox.set_deferred("monitoring", true)
		hitbox.set_deferred("monitorable", true)
			
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
		
	if state == BossState.DORMANT and not is_dead:
		if wait_for_trigger:
			pass
		elif auto_start_fight:
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


# ==================== KHỞI ĐẦU TRẬN ĐẤU ====================
func start_encounter() -> void:
	if state != BossState.DORMANT or is_dead:
		return
	state = BossState.INTRO
	
	# Khởi tạo thanh máu Boss HUD
	if health_bar_scene:
		boss_health_bar_inst = health_bar_scene.instantiate()
		get_tree().current_scene.add_child(boss_health_bar_inst)
		if boss_health_bar_inst.has_method("setup_boss"):
			boss_health_bar_inst.setup_boss(boss_display_name, max_health, boss_icon)
			
	play_sfx(roar_sfx)
	_look_at_player()
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
		
	await get_tree().create_timer(1.5).timeout
	if state == BossState.INTRO and not is_dead:
		_start_attack_loop()


# ==================== NHẬN SÁT THƯƠNG ====================
func take_damage(amount: int = 1, _knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable or is_dead or damage_cooldown > 0.0:
		return
		
	if state == BossState.DORMANT:
		start_encounter()
		if amount < 99999 and not (DebugManager and DebugManager.is_one_hit):
			return
		
	if (DebugManager and DebugManager.is_one_hit) or amount >= 99999:
		current_health = 0
		if boss_health_bar_inst and boss_health_bar_inst.has_method("update_health"):
			boss_health_bar_inst.update_health(0)
		die()
		return

	damage_cooldown = 0.12
	current_health -= amount
	stagger_hits += 1
	
	if boss_health_bar_inst and boss_health_bar_inst.has_method("update_health"):
		boss_health_bar_inst.update_health(current_health)
		
	# Chớp đỏ khi nhận đòn
	if animated_sprite:
		var tw = create_tween()
		tw.tween_property(animated_sprite, "modulate", Color(2.5, 0.4, 0.4), 0.08)
		tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.08)
		
	if current_health <= 0:
		die()
		return
		
	# Đổi Phase khi còn dưới 50% HP
	if float(current_health) / float(max_health) <= 0.5:
		current_phase = 2
		
	# Kích hoạt kiệt sức (Stagger) khi nhận đủ số đòn
	if stagger_hits >= HITS_TO_STAGGER and state != BossState.STAGGER:
		stagger_hits = 0
		_trigger_stagger()


# ==================== CHU KỲ TẤN CÔNG (FSM) ====================
func _start_attack_loop() -> void:
	_next_attack_cycle()


func _next_attack_cycle() -> void:
	if is_dead or not is_inside_tree() or state == BossState.STAGGER:
		return
		
	if player_target and ("current_health" in player_target and player_target.current_health <= 0):
		if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		return
		
	# Thời gian bay lơ lửng chờ giữa các đòn
	state = BossState.IDLE_HOVER
	var rest_time = 0.7 if current_phase == 1 else 0.45
	await get_tree().create_timer(rest_time).timeout
	if is_dead or not is_inside_tree() or state == BossState.STAGGER:
		return
		
	# Chọn chiêu thức không trùng với chiêu vừa ra
	var pool = ["orb_shot", "orb_shield", "slam", "dash"]
	if last_attack != "" and pool.has(last_attack):
		pool.erase(last_attack)
	var chosen = pool.pick_random()
	last_attack = chosen
	
	match chosen:
		"orb_shot":
			_attack_orb_shot()
		"orb_shield":
			_attack_orb_shield_pass()
		"slam":
			_attack_slam_dive()
		"dash":
			_attack_dash_lunge()


# ==================== DỊCH CHUYỂN (TELEPORT) ====================
func _teleport_to(target_pos: Vector2, play_sound: bool = true) -> void:
	state = BossState.TELEPORTING
	is_invulnerable = true
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		
	if play_sound:
		play_sfx(teleport_sfx)
		
	if animated_sprite and animated_sprite.sprite_frames.has_animation("teleport_out"):
		animated_sprite.play("teleport_out")
		
	var tw_out = create_tween()
	tw_out.tween_property(animated_sprite, "modulate:a", 0.0, 0.18)
	await tw_out.finished
	if is_dead or not is_inside_tree():
		return
		
	# Đổi vị trí
	target_pos.x = clampf(target_pos.x, arena_left_x + 50.0, arena_right_x - 50.0)
	global_position = target_pos
	_look_at_player()
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("teleport_in"):
		animated_sprite.play("teleport_in")
		
	var tw_in = create_tween()
	tw_in.tween_property(animated_sprite, "modulate:a", 1.0, 0.16)
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


# ==================== ĐÒN 1: BẮN CẦU LINH HỒN (SOUL ORB SHOT) ====================
func _attack_orb_shot() -> void:
	state = BossState.ATTACK_ORB_SHOT
	if not player_target or not is_instance_valid(player_target):
		_find_player()
		
	# Teleport lơ lửng trên không
	var air_y = arena_ground_y - randf_range(160.0, 220.0)
	var air_x = clampf(global_position.x + randf_range(-180.0, 180.0), arena_left_x + 80.0, arena_right_x - 80.0)
	await _teleport_to(Vector2(air_x, air_y))
	if is_dead or not is_inside_tree():
		return
		
	play_sfx(cast_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("cast_orb"):
		animated_sprite.play("cast_orb")
		
	await get_tree().create_timer(0.35).timeout
	if is_dead or not is_inside_tree():
		return
		
	# Bắn cầu linh hồn đuổi theo người chơi
	var orb_count = 2 if current_phase == 2 else 1
	for i in range(orb_count):
		if orb_scene and get_parent():
			var orb = orb_scene.instantiate()
			get_parent().add_child(orb)
			var shoot_pos = global_position + Vector2(facing_dir * 45.0, -20.0)
			var init_dir = (player_target.global_position - shoot_pos).normalized() if player_target else Vector2(facing_dir, 0.5)
			orb.setup_shot(shoot_pos, init_dir, 330.0, true)
		if orb_count > 1 and i == 0:
			await get_tree().create_timer(0.35).timeout
			if is_dead or not is_inside_tree(): return
			
	await get_tree().create_timer(0.6).timeout
	_next_attack_cycle()


# ==================== ĐÒN 2: VÒNG XOAY HỘ THỂ (ROTATING ORBS PASS) ====================
func _attack_orb_shield_pass() -> void:
	state = BossState.ATTACK_ORB_SHIELD_PASS
	if not player_target or not is_instance_valid(player_target):
		_find_player()
		
	# Chọn mép xuất phát (trái hoặc phải)
	var start_from_left = (randf() < 0.5)
	var start_x = (arena_left_x + 70.0) if start_from_left else (arena_right_x - 70.0)
	var target_x = (arena_right_x - 70.0) if start_from_left else (arena_left_x + 70.0)
	var fly_dir_x = 1.0 if start_from_left else -1.0
	
	# Teleport ở độ cao ngang người chơi (cần nhảy né)
	await _teleport_to(Vector2(start_x, arena_ground_y - 75.0))
	if is_dead or not is_inside_tree():
		return
		
	play_sfx(angry_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("orb_shield"):
		animated_sprite.play("orb_shield")
	if animated_sprite:
		animated_sprite.flip_h = (fly_dir_x > 0)
		
	# Triệu hồi 4 quả cầu xoay quanh người làm khiên
	var shield_orbs = []
	if orb_scene and get_parent():
		for i in range(4):
			var orb = orb_scene.instantiate()
			get_parent().add_child(orb)
			var angle = i * (PI / 2.0)
			orb.setup_shield_orb(self, angle, 90.0)
			shield_orbs.append(orb)
			
	# Bay từ từ từ mép này sang mép kia sân đấu
	var fly_duration = 3.2
	var tw_fly = create_tween()
	tw_fly.tween_property(self, "global_position:x", target_x, fly_duration).set_trans(Tween.TRANS_LINEAR)
	await tw_fly.finished
	if is_dead or not is_inside_tree():
		for o in shield_orbs:
			if is_instance_valid(o): o.queue_free()
		return
		
	# Khi bay hết màn hình, 4 quả cầu mở rộng bán kính và bay tỏa ra ngoài
	for i in range(shield_orbs.size()):
		var o = shield_orbs[i]
		if is_instance_valid(o):
			var out_dir = Vector2(cos(o.orbit_angle), sin(o.orbit_angle))
			o.release_shield_orb(out_dir, 400.0)
			
	await get_tree().create_timer(0.3).timeout
	_next_attack_cycle()


# ==================== ĐÒN 3: ĐẬP SÀN XUNG KÍCH (DESOLATE DIVE / SLAM) ====================
func _attack_slam_dive() -> void:
	state = BossState.ATTACK_SLAM
	if not player_target or not is_instance_valid(player_target):
		_find_player()
	var p_x = player_target.global_position.x if player_target and is_instance_valid(player_target) else global_position.x
	
	# Teleport lên vị trí ngay trên đầu Player
	await _teleport_to(Vector2(p_x, arena_ground_y - 250.0))
	if is_dead or not is_inside_tree():
		return
		
	# Khựng lại chuẩn bị lao xuống
	if animated_sprite and animated_sprite.sprite_frames.has_animation("slam_anticipation"):
		animated_sprite.play("slam_anticipation")
	await get_tree().create_timer(0.32).timeout
	if is_dead or not is_inside_tree():
		return
		
	# CƠ CHẾ ĐÁNH LỪA (FAKE DIVE / FEINT - 30% XÁC SUẤT):
	var is_feint = (randf() < 0.30)
	if is_feint:
		# Lao xuống lưng chừng rồi đột ngột teleport biến mất!
		if animated_sprite and animated_sprite.sprite_frames.has_animation("slam_dive"):
			animated_sprite.play("slam_dive")
		var fake_tw = create_tween()
		fake_tw.tween_property(self, "global_position:y", arena_ground_y - 120.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await fake_tw.finished
		if is_dead or not is_inside_tree(): return
		
		# Teleport xuất hiện lại trên đầu vị trí mới của Player!
		if not player_target or not is_instance_valid(player_target): _find_player()
		var new_p_x = player_target.global_position.x if player_target else global_position.x
		await _teleport_to(Vector2(new_p_x, arena_ground_y - 250.0))
		if is_dead or not is_inside_tree(): return
		
		if animated_sprite and animated_sprite.sprite_frames.has_animation("slam_anticipation"):
			animated_sprite.play("slam_anticipation")
		await get_tree().create_timer(0.18).timeout
		if is_dead or not is_inside_tree(): return
		
	# LAO CẮM THẲNG XUỐNG ĐẤT THẬT
	if animated_sprite and animated_sprite.sprite_frames.has_animation("slam_dive"):
		animated_sprite.play("slam_dive")
	if attack_collision:
		attack_collision.set_deferred("disabled", false)
		
	var dive_tw = create_tween()
	dive_tw.tween_property(self, "global_position:y", arena_ground_y, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await dive_tw.finished
	
	# TIẾP ĐẤT TẠO RUNG CHẤN VÀ 2 CỘT SÓNG XUNG KÍCH SANG HAI BÊN
	play_sfx(slam_ground_sfx)
	var cam = get_viewport().get_camera_2d()
	if cam:
		var tw_cam = create_tween()
		for i in range(8):
			tw_cam.tween_property(cam, "offset", Vector2(0, randf_range(-6.0, 6.0)), 0.04)
		tw_cam.tween_property(cam, "offset", Vector2.ZERO, 0.04)
		
	# Sinh 2 sóng chấn động (trái và phải)
	if shockwave_scene and get_parent():
		var sw_left = shockwave_scene.instantiate()
		get_parent().add_child(sw_left)
		sw_left.setup(-1.0, Vector2(global_position.x - 30.0, arena_ground_y), 360.0)
		
		var sw_right = shockwave_scene.instantiate()
		get_parent().add_child(sw_right)
		sw_right.setup(1.0, Vector2(global_position.x + 30.0, arena_ground_y), 360.0)
		
	# Tắt va chạm đập đất sau nhịp va đập ngắn
	await get_tree().create_timer(0.15).timeout
	if attack_collision:
		attack_collision.set_deferred("disabled", true)
		
	# Khựng lại trên sàn 0.3s
	await get_tree().create_timer(0.3).timeout
	_next_attack_cycle()


# ==================== ĐÒN 4: BAY LƯỚT QUÉT SÀN (DASH / LUNGE) ====================
func _attack_dash_lunge() -> void:
	state = BossState.ATTACK_DASH_LUNGE
	if not player_target or not is_instance_valid(player_target):
		_find_player()
		
	# Teleport sát mặt sàn ở mép phòng
	var start_left = (player_target.global_position.x > (arena_left_x + arena_right_x) * 0.5) if player_target else true
	var start_x = (arena_left_x + 60.0) if start_left else (arena_right_x - 60.0)
	var dash_target_x = (arena_right_x - 60.0) if start_left else (arena_left_x + 60.0)
	var dash_dir_x = 1.0 if start_left else -1.0
	
	await _teleport_to(Vector2(start_x, arena_ground_y - 30.0))
	if is_dead or not is_inside_tree():
		return
		
	play_sfx(slash_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("dash"):
		animated_sprite.play("dash")
	if animated_sprite:
		animated_sprite.flip_h = (dash_dir_x > 0)
	if attack_collision:
		attack_collision.set_deferred("disabled", false)
		
	# Lướt nhanh ngang người sang mép đối diện
	var tw_dash = create_tween()
	tw_dash.tween_property(self, "global_position:x", dash_target_x, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw_dash.finished
	if attack_collision:
		attack_collision.set_deferred("disabled", true)
	if is_dead or not is_inside_tree():
		return
		
	await get_tree().create_timer(0.25).timeout
	_next_attack_cycle()


# ==================== TRẠNG THÁI KIỆT SỨC (STAGGER) ====================
func _trigger_stagger() -> void:
	state = BossState.STAGGER
	if attack_collision:
		attack_collision.set_deferred("disabled", true)
		
	play_sfx(start_stun_sfx)
	
	# Rơi bịch xuống sàn
	var drop_tw = create_tween()
	drop_tw.tween_property(self, "global_position:y", arena_ground_y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("stagger_start"):
		animated_sprite.play("stagger_start")
	await get_tree().create_timer(0.4).timeout
	if is_dead or not is_inside_tree():
		return
		
	play_sfx(stun_sfx)
	if animated_sprite and animated_sprite.sprite_frames.has_animation("stagger"):
		animated_sprite.play("stagger")
		
	# Kiệt sức trong 3.5 giây
	await get_tree().create_timer(3.5).timeout
	if is_dead or not is_inside_tree():
		return
		
	play_sfx(angry_sfx)
	# Hồi phục và teleport bay lên lại
	await _teleport_to(Vector2(global_position.x, arena_ground_y - 180.0))
	_next_attack_cycle()


# ==================== VA CHẠM VÀ GÂY SÁT THƯƠNG ====================
func _resolve_player_target(node: Node) -> Node:
	if not node:
		return null
	if node.is_in_group("player") or node.name == "PlayerController" or node.name.begins_with("Player"):
		return node
	if node.get_parent() and (node.get_parent().is_in_group("player") or node.get_parent().name == "PlayerController" or node.get_parent().name.begins_with("Player")):
		return node.get_parent()
	if node.owner and (node.owner.is_in_group("player") or node.owner.name == "PlayerController" or node.owner.name.begins_with("Player")):
		return node.owner
	return null


func _check_and_damage_player(target: Node, dmg_amount: int) -> bool:
	if is_dead:
		return false
	var p = _resolve_player_target(target)
	if p and p.has_method("take_damage"):
		if "is_invincible" not in p or not p.is_invincible:
			p.take_damage(dmg_amount, global_position)
		return true
	return false


func _on_attack_hitbox_body_entered(body: Node) -> void:
	_check_and_damage_player(body, 2)


func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	_check_and_damage_player(area, 2)


func _on_hitbox_area_entered(area: Area2D) -> void:
	_check_and_damage_player(area, damage)


# ==================== TỬ TRẬN ====================
func die() -> void:
	if is_dead:
		return
	is_dead = true
	state = BossState.DEATH
	is_invulnerable = true
	boss_defeated.emit()
	
	if attack_collision:
		attack_collision.set_deferred("disabled", true)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
		
	if boss_health_bar_inst and is_instance_valid(boss_health_bar_inst) and boss_health_bar_inst.has_method("hide_bar"):
		boss_health_bar_inst.hide_bar()
		
	play_sfx(start_death_sfx)
	play_sfx(death_sfx)
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		
	await get_tree().create_timer(0.6).timeout
	play_sfx(explode_sfx)
	
	if get_parent():
		GeoDropHelper.drop_from_tier(global_position, get_parent(), GeoDropHelper.EnemyTier.BOSS)
		
	if SaveManager.instance:
		SaveManager.instance.record_enemy_kill("mage_lord")
		SaveManager.instance.set_event_completed("soul_master_defeated", true)
		
	var tw = create_tween()
	tw.tween_property(animated_sprite, "modulate:a", 0.0, 1.4)
	await tw.finished
	queue_free()
