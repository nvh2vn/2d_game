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
	THROW,
	REMOTE_SKILL,
	DEFEND_START,
	DEFEND,
	DEFEND_END,
	DEFEND_ATTACK,
	FOCUS_HEAL,
	DIE,
}

@export_group("Map 1 Unlockable Abilities")
@export var unlock_double_jump: bool = false
@export var unlock_dash: bool = true
@export var unlock_wall_climb: bool = false
@export var unlock_float: bool = false
@export var unlock_ledge_climb: bool = true
var ledge_climb_timer: float = 0.0
@export var unlock_attack: bool = true
@export var unlock_shoot: bool = false
@export var unlock_special_attack: bool = false
@export var unlock_defend: bool = true

@export_group("Combat Timings")
@export var max_defend_duration: float = 0.5
@export var defend_cooldown_time: float = 0.4
@export var shoot_cooldown_time: float = 0.35
@export var remote_skill_cooldown_time: float = 1.0
@export var dash_cooldown_time: float = 0.4

var defend_duration_timer: float = 0.0
var defend_cooldown: float = 0.0
var shoot_cooldown: float = 0.0
var remote_skill_cooldown: float = 0.0

@export_group("Hazard Reset Transition")
@export var fade_duration: float = 0.2
@export var black_hold_duration: float = 0.08
@export var sit_texture: Texture2D = preload("res://assets/sprites/player/SitDown.png")

@export_group("Shade & Death Penalty System")
@export var shade_scene: PackedScene = preload("res://scenes/prefabs/enemies/shade.tscn")
var is_silk_cracked: bool = false

@export_group("Player Health & Combat")
@export var fall_death_y: float = 600.0
@export var max_health: int = 5
var current_health: int = 5
var is_invincible: bool = false
var slow_timer: float = 0.0
var speed_multiplier: float = 1.0

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
const DASH_LENGTH := 140.0
const DASH_VELOCITY := 650.0
const SPRINT_VELOCITY := 400.0
const SPRINT_ACCELERATION := 1800.0

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite") if get_node_or_null("AnimatedSprite") != null else get_node_or_null("%AnimatedSprite")
@onready var counter_effect: AnimatedSprite2D = get_node_or_null("%CounterEffect")
@onready var remote_skill_effect: AnimatedSprite2D = get_node_or_null("%RemoteSkillEffect")
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
@onready var geo_label: Label = get_node_or_null("%GeoLabel")
@onready var geo_icon: TextureRect = get_node_or_null("%GeoIcon")
@onready var silk_meter: Control = get_node_or_null("%SilkMeter")
@onready var silk_spool_progress: TextureProgressBar = get_node_or_null("%SilkSpoolProgress")
@onready var silk_spool_sprite: AnimatedSprite2D = get_node_or_null("%SilkSpoolSprite")
@onready var needle_silk_line: TextureProgressBar = get_node_or_null("%NeedleSilkLine")
@onready var blood_effect: AnimatedSprite2D = get_node_or_null("%BloodEffect")
@onready var death_vignette: Sprite2D = get_node_or_null("%DeathVignette")
@onready var camera_2d: Camera2D = get_node_or_null("%Camera2D")
@onready var fade_rect: ColorRect = get_node_or_null("%FadeRect")
@export var game_over_scene: PackedScene = preload("res://scenes/ui/game_over_screen.tscn")

var geo_amount: int = 0
var inventory: Array = []
var mask_shards: int = 0
var is_cutscene_locked: bool = false

@export_group("Silk Energy System")
@export var max_silk: int = 6
@export var current_silk: int = 6
@export var dart_silk_cost: int = 1         # Chiêu K: Bắn phi tiêu tốn 1 tơ
@export var remote_skill_silk_cost: int = 2 # Chiêu X: Sóng tơ bão kích tốn 2 tơ
@export var heal_silk_cost: int = 3         # Phím H: Hồi 1 MASK tốn 3 tơ
@export var bind_silk_cost: int = 6         # Silksong Bind: Tiêu tốn full cuộn tơ (hoặc tối thiểu bind_silk_cost)
@export var bind_heal_amount: int = 3       # Hồi 3 MASK
@export var bind_charge_duration: float = 0.95 # Giữ nút tụ lực ~0.95s
@export var silk_gain_on_hit: int = 1       # Đánh thường trúng tích 1 tơ
@export var soul_hit_sfx: AudioStream = preload("res://assets/audio/player/soulhit.mp3")
@export var sound_cure_sfx: AudioStream = preload("res://assets/audio/player/sound_cure.mp3")
@export var voice_cure_sfx: AudioStream = preload("res://assets/audio/player/voice_cure.mp3")

enum BIND_PHASE {
	START,
	CHARGING,
	SUCCESS,
	CANCEL
}
var bind_phase: BIND_PHASE = BIND_PHASE.START
var bind_timer: float = 0.0
var focus_heal_timer: float = 0.0

@export var active_mask_texture: Texture2D = preload("res://assets/ui/mask_white.png")
@export var lost_mask_texture: Texture2D = preload("res://assets/ui/mask_black.png")

@export_group("Sound Effects (SFX)")
@export var slash_sfx: AudioStream
@export var shoot_sfx: AudioStream
@export var jump_sfx: AudioStream
@export var dash_sfx: AudioStream
@export var hurt_sfx: AudioStream
@export var heal_sfx: AudioStream
@export var die_sfx: AudioStream
@export var falling_sfx: AudioStream
@export var land_sfx: AudioStream
@export var wall_slide_sfx: AudioStream
@export var defend_sfx: AudioStream
@export var parry_sfx: AudioStream
@export var block_sfx: AudioStream
@export var throw_sfx: AudioStream
@export var remote_sfx: AudioStream
@export var remote_voice_sfx: AudioStream
@export var dart_scene: PackedScene = preload("res://scenes/prefabs/projectiles/dart.tscn")

@onready var sfx_player: AudioStreamPlayer2D = get_node_or_null("%SFXPlayer")
@onready var sound_off_btn: BaseButton = get_node_or_null("%SoundOff")
@onready var sound_on_btn: BaseButton = get_node_or_null("%SoundOn")
@onready var music_off_btn: BaseButton = get_node_or_null("%MusicOff")
@onready var music_on_btn: BaseButton = get_node_or_null("%MusicOn")

var blink_tween: Tween
var active_state := STATE.FALL
var can_double_jump := false
var facing_direction := 1.0
var saved_position := Vector2.ZERO
var last_safe_position := Vector2.ZERO
var safe_ground_time: float = 0.0
var is_touching_hazard: bool = false
var is_resetting_hazard: bool = false
var is_sitting: bool = false
var sit_cooldown: float = 0.0
var can_dash := false
var dash_jump_buffer := false
var is_sprinting := false
var hurt_knockback_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	last_safe_position = global_position
	_setup_fade_overlay()
	
	# Neu co Bench Checkpoint da luu thi hoi sinh / dat vi tri Player tai do
	var checkpoint = SaveManager.get_bench_checkpoint()
	if checkpoint and checkpoint.get("pos", Vector2.ZERO) != Vector2.ZERO:
		var check_scene = checkpoint.get("scene", "")
		if check_scene == "" or (get_tree().current_scene and check_scene == get_tree().current_scene.scene_file_path):
			global_position = checkpoint["pos"]
			last_safe_position = checkpoint["pos"]
			
	_check_teleport_marker()
			
	if sfx_player:
		sfx_player.bus = &"SFX"
	current_health = max_health
	
	# Đồng bộ các kỹ năng đã unlock và thông tin đã lưu từ SaveManager (Mobile Safe)
	if SaveManager.instance:
		SaveManager.instance.apply_to_player(self)
	elif GameManager:
		unlock_shoot = GameManager.can_needle_throw
		unlock_special_attack = GameManager.can_silk_storm
		
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
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	if counter_effect:
		counter_effect.animation_finished.connect(_on_counter_effect_animation_finished)
	if remote_skill_effect:
		remote_skill_effect.animation_finished.connect(_on_remote_skill_effect_animation_finished)
	_setup_audio_ui()
	update_hud()
	_check_and_spawn_shade()

func _unhandled_input(event: InputEvent) -> void:
	if is_cutscene_locked:
		return
	# Cho phép click chuột trái để tấn công trên Desktop/PC
	# CHỈ kích hoạt khi người chơi click vào thế giới game (không trúng bất kỳ nút UI hoặc vùng điều khiển ảo nào)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if OS.get_name() not in ["Android", "iOS"]:
			if unlock_attack and not is_sitting and active_state not in [STATE.DIE, STATE.FOCUS_HEAL]:
				Input.action_press(&"attack")
				get_tree().create_timer(0.05).timeout.connect(func(): Input.action_release(&"attack"))


func set_cutscene_locked(locked: bool) -> void:
	is_cutscene_locked = locked
	if locked:
		velocity.x = 0.0
		if is_on_floor() and active_state not in [STATE.DIE]:
			switch_state(STATE.FLOOR)
			if animated_sprite:
				animated_sprite.play("idle")


func set_hud_visible(p_visible: bool) -> void:
	var hud_node = get_node_or_null("HUD")
	if hud_node:
		hud_node.visible = p_visible
	var tc = get_node_or_null("TouchControls")
	if tc:
		tc.visible = p_visible
	if TouchControls.instance and is_instance_valid(TouchControls.instance):
		TouchControls.instance.visible = p_visible


func trigger_hitstop(duration: float = 0.04) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func _on_attack_area_entered(area: Area2D) -> void:
	var target = area.get_parent()
	var attack_dir = current_attack_dir
	if attack_dir == Vector2.ZERO:
		attack_dir = Vector2(facing_direction, 0)
	
	var is_down_slash := (current_attack_dir == Vector2.DOWN or attack_dir == Vector2.DOWN)
	var is_air := not is_on_floor()

	var dmg = 2 if active_state == STATE.REMOTE_SKILL else 1
	if DebugManager and DebugManager.is_one_hit:
		dmg = 99999
	var did_hit = false
	var hit_node: Node = null
	
	if area.has_method("take_damage"):
		hit_node = area
	elif target and target.has_method("take_damage"):
		hit_node = target
	elif area.owner and area.owner.has_method("take_damage"):
		hit_node = area.owner

	if hit_node:
		hit_node.take_damage(dmg, attack_dir)
		did_hit = true
	elif area.is_in_group("spikes") or area.is_in_group("hazards") or area.is_in_group("cocoon") or area.is_in_group("shade") or (target and (target.is_in_group("cocoon") or target.is_in_group("shade"))) or area is SpikesHazard or area is PoisonTrap or area.name.begins_with("Trap") or area.name.begins_with("Hazard") or area.name.begins_with("Spike"):
		did_hit = true

	if did_hit:
		# Hiệu ứng Nail Pogo nảy lên khi chém xuống trúng Quái vật, Kén tơ (Cocoon), Bẫy gai hoặc Vật thể
		if is_down_slash and is_air:
			velocity.y = -480.0
			can_double_jump = true
			can_dash = true
			trigger_hitstop(0.04)
		elif not is_air and not is_down_slash:
			# Recoil nảy giật lùi nhẹ khi chém trúng quái theo phương ngang
			velocity.x = -facing_direction * 150.0
			trigger_hitstop(0.04)

		# Tích tơ & âm thanh trúng đòn (SOUL Gain SFX)
		if active_state == STATE.ATTACK or active_state == STATE.DEFEND_ATTACK:
			add_silk(silk_gain_on_hit)
			if soul_hit_sfx:
				play_sfx(soul_hit_sfx)

func _on_animated_sprite_animation_finished() -> void:
	match active_state:
		STATE.THROW:
			if is_on_floor():
				switch_state(STATE.FLOOR)
			else:
				switch_state(STATE.FALL)
		STATE.REMOTE_SKILL:
			if attack_area:
				attack_area.set_deferred("monitoring", false)
			if remote_skill_effect:
				remote_skill_effect.visible = false
			if is_on_floor():
				switch_state(STATE.FLOOR)
			else:
				switch_state(STATE.FALL)
		STATE.DEFEND_START:
			if (Input.is_action_pressed("defend") or Input.is_key_pressed(KEY_C)) and defend_duration_timer > 0.0:
				switch_state(STATE.DEFEND)
			else:
				switch_state(STATE.DEFEND_END)
		STATE.DEFEND_END:
			if is_on_floor():
				switch_state(STATE.FLOOR)
			else:
				switch_state(STATE.FALL)
		STATE.DEFEND_ATTACK:
			if attack_area:
				attack_area.set_deferred("monitoring", false)
			if is_on_floor():
				switch_state(STATE.FLOOR)
			else:
				switch_state(STATE.FALL)
		STATE.ATTACK:
			current_attack_dir = Vector2.ZERO
			if attack_area:
				attack_area.set_deferred("monitoring", false)
			if is_on_floor():
				switch_state(STATE.FLOOR)
			else:
				switch_state(STATE.FALL)
		STATE.FOCUS_HEAL:
			if animated_sprite:
				animated_sprite.modulate = Color.WHITE
			if bind_phase == BIND_PHASE.START:
				bind_phase = BIND_PHASE.CHARGING
				if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("bind_charging"):
					animated_sprite.play("bind_charging")
			elif bind_phase == BIND_PHASE.SUCCESS or bind_phase == BIND_PHASE.CANCEL:
				if is_on_floor():
					switch_state(STATE.FLOOR)
				else:
					switch_state(STATE.FALL)

func _spawn_dart() -> void:
	if not dart_scene:
		return
	var dart = dart_scene.instantiate()
	var spawn_pos = global_position + Vector2(facing_direction * 25.0, -10.0)
	dart.setup(Vector2(facing_direction, 0), spawn_pos)
	get_parent().add_child(dart)

func _on_counter_effect_animation_finished() -> void:
	if counter_effect:
		counter_effect.visible = false

func _on_remote_skill_effect_animation_finished() -> void:
	if remote_skill_effect:
		remote_skill_effect.visible = false

func trigger_parry_counter() -> void:
	# Bất tử ngắn hạn khi phản đòn thành công
	is_invincible = true
	if invincibility_timer:
		invincibility_timer.start(0.4)
	
	if block_sfx:
		play_sfx(block_sfx)
	elif defend_sfx:
		play_sfx(defend_sfx)
	
	switch_state(STATE.DEFEND_ATTACK)

func update_health_hud() -> void:
	update_hud()

func update_hud() -> void:
	if health_container:
		while health_container.get_child_count() < max_health:
			var new_mask = TextureRect.new()
			new_mask.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			new_mask.custom_minimum_size = Vector2(26, 38)
			new_mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			new_mask.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			new_mask.texture = active_mask_texture
			health_container.add_child(new_mask)
		while health_container.get_child_count() > max_health:
			var c = health_container.get_child(health_container.get_child_count() - 1)
			health_container.remove_child(c)
			c.queue_free()

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
	update_geo_hud()
	update_silk_hud()

func add_silk(amount: int = 1) -> void:
	if current_silk < max_silk:
		current_silk = mini(current_silk + amount, max_silk)
		if soul_hit_sfx:
			play_sfx(soul_hit_sfx, 0.08)
		update_silk_hud(true)

func has_enough_silk(cost: int) -> bool:
	return current_silk >= cost

func consume_silk(cost: int) -> bool:
	if current_silk >= cost:
		current_silk -= cost
		update_silk_hud(true)
		return true
	play_silk_warning()
	return false

func update_silk_hud(punch_anim: bool = false) -> void:
	if silk_spool_progress:
		silk_spool_progress.max_value = float(max_silk)
		var tw_val = create_tween()
		tw_val.tween_property(silk_spool_progress, "value", float(current_silk), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if silk_spool_sprite:
		var frame_idx = clampi(current_silk, 0, 6)
		silk_spool_sprite.frame = frame_idx
	if silk_meter:
		if is_silk_cracked:
			silk_meter.modulate = Color(0.65, 0.55, 0.8, 0.95)
		else:
			silk_meter.modulate = Color.WHITE
	if punch_anim and silk_meter:
		var tw = create_tween()
		tw.tween_property(silk_meter, "scale", Vector2(1.08, 1.08), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(silk_meter, "scale", Vector2.ONE, 0.08)

func restore_max_silk() -> void:
	is_silk_cracked = false
	max_silk = 6
	current_silk = max_silk
	update_silk_hud()

func _check_and_spawn_shade() -> void:
	var shade_info = SaveManager.get_shade()
	if shade_info.get("active", false):
		is_silk_cracked = true
		max_silk = 4
		current_silk = mini(current_silk, max_silk)
		update_silk_hud()
		
		var existing_shades = get_tree().get_nodes_in_group("shade")
		if existing_shades.size() == 0 and shade_scene != null:
			var shade_pos: Vector2 = shade_info.get("pos", Vector2.ZERO)
			var shade_scene_path: String = shade_info.get("scene", "")
			var cur_scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
			if shade_pos != Vector2.ZERO and (shade_scene_path == "" or cur_scene_path == "" or shade_scene_path == cur_scene_path):
				var shade_inst = shade_scene.instantiate()
				if shade_inst.has_method("setup_shade"):
					shade_inst.setup_shade(shade_info.get("geo", 0), shade_pos)
				get_parent().call_deferred("add_child", shade_inst)

func _check_teleport_marker() -> void:
	var tm = get_node_or_null("/root/TeleportManager")
	if tm and tm.target_waypoint_marker != "":
		var target_marker = tm.target_waypoint_marker
		var pillars = get_tree().get_nodes_in_group("waypoints")
		var target_pillar: WaypointPillar = null
		for p in pillars:
			if p is WaypointPillar and p.marker_id == target_marker:
				target_pillar = p
				break
				
		if target_pillar:
			var dest_pos = target_pillar.global_position
			if target_pillar.spawn_point:
				dest_pos = target_pillar.spawn_point.global_position
			global_position = dest_pos
			last_safe_position = dest_pos
			velocity = Vector2.ZERO
			if camera_2d and camera_2d.has_method("reset_smoothing"):
				camera_2d.reset_smoothing()
				
		tm.target_waypoint_marker = ""

func play_silk_warning() -> void:
	if silk_meter:
		var tw = create_tween()
		tw.tween_property(silk_meter, "modulate", Color(2.5, 0.3, 0.3), 0.08)
		tw.tween_property(silk_meter, "modulate", Color.WHITE, 0.12)

func add_geo(amount: int) -> void:
	geo_amount += amount
	SaveManager.save_geo(geo_amount)
	update_geo_hud()

func update_geo_hud() -> void:
	if geo_label:
		geo_label.text = str(geo_amount)
	if geo_icon:
		var tween = create_tween()
		tween.tween_property(geo_icon, "scale", Vector2(1.28, 1.28), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(geo_icon, "scale", Vector2.ONE, 0.08)

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

func _setup_audio_ui() -> void:
	if sound_off_btn:
		sound_off_btn.pressed.connect(_on_sound_off_pressed)
		_setup_ui_hover(sound_off_btn)
	if sound_on_btn:
		sound_on_btn.pressed.connect(_on_sound_on_pressed)
		_setup_ui_hover(sound_on_btn)
	if music_off_btn:
		music_off_btn.pressed.connect(_on_music_off_pressed)
		_setup_ui_hover(music_off_btn)
	if music_on_btn:
		music_on_btn.pressed.connect(_on_music_on_pressed)
		_setup_ui_hover(music_on_btn)

	var sfx_idx = AudioServer.get_bus_index("SFX")
	var is_sfx_muted = (sfx_idx != -1 and AudioServer.is_bus_mute(sfx_idx))
	_update_sound_ui(not is_sfx_muted)

	var music_idx = AudioServer.get_bus_index("Music")
	var is_music_muted = (music_idx != -1 and AudioServer.is_bus_mute(music_idx))
	_update_music_ui(not is_music_muted)

func _setup_ui_hover(btn: BaseButton) -> void:
	if not btn:
		return
	btn.pivot_offset = Vector2(20, 20)
	btn.mouse_entered.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.1)
		tw.parallel().tween_property(btn, "modulate", Color(1.2, 1.2, 1.3, 1.0), 0.1)
	)
	btn.mouse_exited.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		tw.parallel().tween_property(btn, "modulate", Color.WHITE, 0.1)
	)

func _on_sound_off_pressed() -> void:
	# Click SoundOff -> Tắt hiệu ứng âm thanh ngắn, hiện SoundOn thay thế vị trí
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_mute(sfx_idx, true)
	_update_sound_ui(false)

func _on_sound_on_pressed() -> void:
	# Click SoundOn -> Bật hiệu ứng âm thanh ngắn, hiện SoundOff thay thế vị trí
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_mute(sfx_idx, false)
	_update_sound_ui(true)

func _update_sound_ui(is_enabled: bool) -> void:
	if sound_off_btn and sound_on_btn:
		sound_off_btn.visible = is_enabled
		sound_on_btn.visible = not is_enabled

func _on_music_off_pressed() -> void:
	# Click MusicOff -> Nhạc nền bị tắt, hiện MusicOn thay thế vị trí
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_mute(music_idx, true)
	_update_music_ui(false)

func _on_music_on_pressed() -> void:
	# Click MusicOn -> Nhạc nền được phát, hiện MusicOff thay thế vị trí
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_mute(music_idx, false)
	var level_root = get_tree().current_scene
	if level_root:
		var bgm = level_root.find_child("BGMPlayer", true, false)
		if bgm and bgm is AudioStreamPlayer and not bgm.playing and bgm.stream:
			bgm.play()
	_update_music_ui(true)

func _update_music_ui(is_playing: bool) -> void:
	if music_on_btn and music_off_btn:
		music_off_btn.visible = is_playing
		music_on_btn.visible = not is_playing

func play_sfx(stream: AudioStream, pitch_variance: float = 0.05) -> void:
	if sfx_player and stream:
		sfx_player.stream = stream
		if pitch_variance > 0.0:
			sfx_player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
		else:
			sfx_player.pitch_scale = 1.0
		sfx_player.play()

func heal(amount: int = 1) -> void:
	if current_health >= max_health or active_state == STATE.DIE:
		return
	if not consume_silk(heal_silk_cost):
		return
	var restored_index = current_health
	current_health = mini(current_health + amount, max_health)
	play_blood_load_effect(restored_index)
	play_sfx(heal_sfx)
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

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO) -> void:
	# GOD MODE CHEAT: Bỏ qua hoàn toàn trừ máu, knockback nặng và chết
	if DebugManager and DebugManager.is_god_mode:
		current_health = max_health
		update_hud()
		return

	if is_invincible or current_health <= 0 or active_state == STATE.DIE:
		return
	
	# Nếu đang tụ lực Bind (FOCUS_HEAL) mà bị trúng đòn thì ngắt tụ lực ngay lập tức
	if active_state == STATE.FOCUS_HEAL:
		_trigger_bind_cancel()

	# Kiểm tra trạng thái đang phòng thủ để chặn đòn & phản đòn (Block & Parry)
	if active_state == STATE.DEFEND_START or active_state == STATE.DEFEND:
		trigger_parry_counter()
		return

	var broken_index = current_health - 1
	current_health -= amount
	play_blood_minus_effect(broken_index)
	play_sfx(hurt_sfx)
	update_hud()
	
	if current_health <= 0:
		die()
		return
	
	is_invincible = true
	if invincibility_timer:
		invincibility_timer.start(1.0)
	
	# Tính toán hướng văng ra xa nguồn gây sát thương (Knockback chính xác)
	var push_dir_x := -facing_direction
	if source_pos != Vector2.ZERO:
		var diff_x = global_position.x - source_pos.x
		if absf(diff_x) > 1.0:
			push_dir_x = signf(diff_x)
	else:
		var enemies = get_tree().get_nodes_in_group("enemies")
		var min_dist = 99999.0
		var nearest_enemy: Node2D = null
		for e in enemies:
			if e is Node2D and is_instance_valid(e):
				var d = global_position.distance_to(e.global_position)
				if d < min_dist:
					min_dist = d
					nearest_enemy = e
		if nearest_enemy and min_dist < 100.0:
			var diff_x = global_position.x - nearest_enemy.global_position.x
			if absf(diff_x) > 1.0:
				push_dir_x = signf(diff_x)
	
	hurt_knockback_timer = 0.22
	velocity.y = -250.0
	velocity.x = push_dir_x * 320.0
		
	# Hiệu ứng nhấp nháy mờ liên tục trong suốt thời gian bất tử (I-frames)
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
		
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("hurt"):
			animated_sprite.play("hurt")
		animated_sprite.modulate = Color(2.5, 0.3, 0.3, 1.0)
		blink_tween = create_tween().set_loops()
		blink_tween.tween_property(animated_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.25), 0.1)
		blink_tween.tween_property(animated_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.85), 0.1)

func _on_invincibility_timer_timeout() -> void:
	is_invincible = false
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
	if animated_sprite and active_state != STATE.DIE:
		if slow_timer > 0.0:
			animated_sprite.modulate = Color(0.65, 1.35, 0.65, 1.0)
		else:
			animated_sprite.modulate = Color.WHITE

func _setup_fade_overlay() -> void:
	if fade_rect:
		return
	var canvas = get_node_or_null("TransitionCanvasLayer")
	if not canvas:
		canvas = CanvasLayer.new()
		canvas.name = "TransitionCanvasLayer"
		(canvas as CanvasLayer).layer = 100
		add_child(canvas)
		
	fade_rect = canvas.get_node_or_null("FadeRect")
	if not fade_rect:
		fade_rect = ColorRect.new()
		fade_rect.name = "FadeRect"
		fade_rect.color = Color.BLACK
		fade_rect.modulate.a = 0.0
		fade_rect.visible = false
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		canvas.add_child(fade_rect)

func fade_to_black(duration: float = -1.0) -> void:
	var d = fade_duration if duration <= 0.0 else duration
	if not fade_rect:
		_setup_fade_overlay()
	if not fade_rect:
		return
	fade_rect.visible = true
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(fade_rect, "modulate:a", 1.0, d)
	await tw.finished

func fade_from_black(duration: float = -1.0) -> void:
	var d = fade_duration if duration <= 0.0 else duration
	if not fade_rect:
		return
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(fade_rect, "modulate:a", 0.0, d)
	await tw.finished
	fade_rect.visible = false
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func trigger_hazard_reset(amount: int = 2, source_pos: Vector2 = Vector2.ZERO) -> void:
	if is_invincible or current_health <= 0 or active_state == STATE.DIE or is_resetting_hazard:
		return
		
	is_resetting_hazard = true
	
	# 1. Trừ 2 máu theo hệ thống Health hiện có
	take_damage(amount, source_pos)
	
	if current_health <= 0:
		is_resetting_hazard = false
		return
		
	# 2. Khóa điều khiển & Fade màn hình sang đen (~0.2s)
	await fade_to_black(fade_duration)
	
	# 3. ĐỢI MÀN HÌNH ĐEN HOÀN TOÀN -> Dịch chuyển Player về vị trí an toàn cũ
	if last_safe_position != Vector2.ZERO:
		global_position = last_safe_position
		
	# Reset vận tốc rơi và knockback
	velocity = Vector2.ZERO
	hurt_knockback_timer = 0.0
	
	# Đặt lại vị trí Camera2D (reset_smoothing để camera không bị lia giật qua màn hình)
	if camera_2d and camera_2d.has_method("reset_smoothing"):
		camera_2d.reset_smoothing()
	elif get_viewport() and get_viewport().get_camera_2d():
		var cam = get_viewport().get_camera_2d()
		if cam.has_method("reset_smoothing"):
			cam.reset_smoothing()
			
	# 4. Giữ màn hình đen ngắn khoảng 0.05s - 0.1s
	await get_tree().create_timer(black_hold_duration, true, false, true).timeout
	
	# 5. Màn hình sáng dần trở lại (~0.2s)
	await fade_from_black(fade_duration)
	
	is_resetting_hazard = false

func rest_at_bench(sit_pos: Vector2, face_right: bool = true) -> void:
	is_sitting = true
	sit_cooldown = 0.35
	global_position = sit_pos
	last_safe_position = sit_pos
	velocity = Vector2.ZERO
	hurt_knockback_timer = 0.0
	
	if animated_sprite == null:
		animated_sprite = get_node_or_null("AnimatedSprite")
		
	if sit_texture == null:
		sit_texture = load("res://assets/sprites/player/SitDown.png")
		
	facing_direction = 1.0 if face_right else -1.0
	if animated_sprite:
		animated_sprite.flip_h = not face_right
		if sit_texture and animated_sprite.sprite_frames:
			if not animated_sprite.sprite_frames.has_animation("sit"):
				animated_sprite.sprite_frames = animated_sprite.sprite_frames.duplicate()
				animated_sprite.sprite_frames.add_animation("sit")
				animated_sprite.sprite_frames.add_frame("sit", sit_texture)
			elif animated_sprite.sprite_frames.get_frame_count("sit") == 0:
				animated_sprite.sprite_frames.add_frame("sit", sit_texture)
			animated_sprite.play("sit")
		elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("sit"):
			animated_sprite.play("sit")
		else:
			animated_sprite.play("idle")
			
	# Hoi phuc toan bo Mua va Silk energy
	current_health = max_health
	current_silk = max_silk
	update_hud()
	
	if camera_2d and camera_2d.has_method("reset_smoothing"):
		camera_2d.reset_smoothing()

func stand_up_from_bench() -> void:
	if not is_sitting:
		return
	is_sitting = false
	if animated_sprite:
		animated_sprite.play("idle")

func apply_slow(duration: float = 3.0, multiplier: float = 0.45) -> void:
	slow_timer = maxf(slow_timer, duration)
	speed_multiplier = multiplier
	if animated_sprite and not is_invincible and active_state != STATE.DIE:
		animated_sprite.modulate = Color(0.65, 1.35, 0.65, 1.0)

func die() -> void:
	if DebugManager and DebugManager.is_god_mode:
		current_health = max_health
		update_hud()
		return
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
	switch_state(STATE.DIE)
	if attack_area:
		attack_area.set_deferred("monitoring", false)
	if attack_timer:
		attack_timer.stop()
	if invincibility_timer:
		invincibility_timer.stop()
		
	# Store death data & lost geo for Shade / Cocoon System
	var death_pos = global_position
	var lost_geo = geo_amount
	geo_amount = 0
	SaveManager.save_geo(0)
	
	# Nếu chết ở bẫy gai (spikes/hazards), nâng vị trí của Cocoon lên trên gai để người chơi dễ tiếp cận
	if is_touching_hazard or is_resetting_hazard:
		if last_safe_position != Vector2.ZERO:
			death_pos = last_safe_position + Vector2(0, -35.0)
		else:
			death_pos.y -= 55.0
	else:
		death_pos.y -= 15.0
	
	is_silk_cracked = true
	max_silk = 4
	current_silk = mini(current_silk, max_silk)
	update_hud()
	
	# Clear existing Shade / Cocoon in level if player dies again (consecutive death penalty)
	var existing_shades = get_tree().get_nodes_in_group("shade")
	for s in existing_shades:
		if is_instance_valid(s):
			s.queue_free()
			
	var cur_scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	SaveManager.save_shade(death_pos, cur_scene_path, lost_geo)
	
	if shade_scene:
		var new_shade = shade_scene.instantiate()
		if new_shade.has_method("setup_shade"):
			new_shade.setup_shade(lost_geo, death_pos)
		get_parent().call_deferred("add_child", new_shade)
	
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
	play_sfx(die_sfx)
	
	# Chờ phát xong hoạt ảnh die và mờ dần màn hình
	await get_tree().create_timer(1.0).timeout
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.3)
		if death_vignette:
			tween.parallel().tween_property(death_vignette, "modulate:a", 0.0, 0.3)
		await tween.finished
	
	# Kích hoạt màn hình Game Over độc lập lúc chạy game (Dynamic Run-time Instantiate)
	if game_over_scene:
		var go_instance = game_over_scene.instantiate()
		var hud = find_child("HUD", false, false)
		if hud:
			hud.add_child(go_instance)
		else:
			get_tree().current_scene.add_child(go_instance)
		
		if cur_scene_path == "":
			if get_tree().current_scene and get_tree().current_scene.scene_file_path != "":
				cur_scene_path = get_tree().current_scene.scene_file_path
		go_instance.trigger_game_over(0, cur_scene_path)
	else:
		get_tree().reload_current_scene()

func _on_attack_timer_timeout() -> void:
	if attack_area:
		attack_area.set_deferred("monitoring", false)
	if active_state == STATE.DEFEND_ATTACK:
		if Input.is_action_pressed("defend") or Input.is_key_pressed(KEY_C):
			switch_state(STATE.DEFEND)
		elif is_on_floor():
			switch_state(STATE.FLOOR)
		else:
			switch_state(STATE.FALL)


func _physics_process(delta: float) -> void:
	if is_cutscene_locked:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += FALL_GRAVITY * delta
			if animated_sprite and active_state != STATE.DIE:
				animated_sprite.play("fall")
		else:
			if animated_sprite and active_state != STATE.DIE:
				animated_sprite.play("idle")
		move_and_slide()
		return

	if is_sitting:
		velocity = Vector2.ZERO
		move_and_slide()
		
		if sit_cooldown > 0.0:
			sit_cooldown -= delta
			return
		
		# Khi dang ngoi, bat ke nguoi choi an Trai, Phai, Len, Xuong (A, D, W, S hoac phim mui ten) hoac phim hanh dong deu se roi khoi ghe
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var is_key_dir: bool = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE) or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("dash") or Input.is_action_just_pressed("interact")
		
		if input_dir.length() > 0.1 or is_key_dir:
			stand_up_from_bench()
			get_tree().call_group("benches", "_stop_rest")
		return

	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			speed_multiplier = 1.0
			if animated_sprite and not is_invincible and active_state != STATE.DIE:
				animated_sprite.modulate = Color.WHITE

	if defend_cooldown > 0.0:
		defend_cooldown = maxf(0.0, defend_cooldown - delta)
	if shoot_cooldown > 0.0:
		shoot_cooldown = maxf(0.0, shoot_cooldown - delta)
	if remote_skill_cooldown > 0.0:
		remote_skill_cooldown = maxf(0.0, remote_skill_cooldown - delta)
	
	# Xử lý đẩy lùi khi Player trúng đòn (không bị triệt tiêu bởi handle_movement)
	if hurt_knockback_timer > 0.0:
		hurt_knockback_timer -= delta
		if not is_on_floor():
			velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
		velocity.x = move_toward(velocity.x, 0, 800.0 * delta)
		move_and_slide()
		return
	
	# Cơ chế dời vị trí tức thì để không bao giờ có thể lồng/dính vào quái vật
	if active_state != STATE.DIE and active_state != STATE.DASH and get_tree():
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy is CharacterBody2D and is_instance_valid(enemy) and not ("is_dead" in enemy and enemy.is_dead):
				var diff_x = global_position.x - enemy.global_position.x
				var diff_y = absf(global_position.y - enemy.global_position.y)
				if absf(diff_x) < 28.0 and diff_y < 35.0:
					var overlap_x = 28.0 - absf(diff_x)
					var sep_dir = 1.0 if diff_x >= 0 else -1.0
					global_position.x += sep_dir * (overlap_x * 0.5)
					enemy.global_position.x -= sep_dir * (overlap_x * 0.5)
	
	process_state(delta)
	move_and_slide()
	
	# Safe Ground Tracking liên tục khi đang đứng vững trên sàn không nguy hiểm
	if is_on_floor() and active_state == STATE.FLOOR and not is_invincible and active_state != STATE.DIE and not is_touching_hazard:
		safe_ground_time += delta
		if safe_ground_time >= 0.15:
			last_safe_position = global_position
	else:
		safe_ground_time = 0.0
		
	is_touching_hazard = false
	
	# Fall out of bounds death check
	#if global_position.y > fall_death_y and current_health > 0:
	#	take_damage(max_health) 


func switch_state(to_state: STATE) -> void:
	var previous_state := active_state
	active_state = to_state
	
	if previous_state == STATE.FOCUS_HEAL and to_state != STATE.FOCUS_HEAL:
		if animated_sprite:
			animated_sprite.modulate = Color.WHITE
			animated_sprite.offset = Vector2.ZERO

	## State specific things that only need to run once upon entering the next state.
	match active_state:
		STATE.FALL:
			if previous_state != STATE.DOUBLE_JUMP:
				animated_sprite.play("fall")
			if previous_state == STATE.FLOOR:
				coyote_timer.start()
			play_sfx(falling_sfx)
		
		STATE.FLOOR:
			can_double_jump = true
			can_dash = true
			if previous_state == STATE.FALL:
				play_sfx(land_sfx)
		
		STATE.JUMP:
			if previous_state != STATE.TURNING:
				animated_sprite.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			play_sfx(jump_sfx)
		
		STATE.DOUBLE_JUMP:
			animated_sprite.play("double_jump")
			velocity.y = DOUBLE_JUMP_VELOCITY
			can_double_jump = false
			is_sprinting = false
			play_sfx(jump_sfx)
		
		STATE.FLOAT:
			if float_cooldown.time_left > 0:
				active_state = previous_state
				return
			animated_sprite.play("float")
			velocity.y = 0
			is_sprinting = false
		
		STATE.LEDGE_CLIMB:
			if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("ledge_climb"):
				animated_sprite.play("ledge_climb")
			elif animated_sprite:
				animated_sprite.play("jump")
			velocity = Vector2.ZERO
			if ledge_climb_ray_cast and ledge_climb_ray_cast.is_colliding():
				global_position.y = ledge_climb_ray_cast.get_collision_point().y
			can_double_jump = true
			ledge_climb_timer = 0.0
		
		STATE.LEDGE_JUMP:
			if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("ledge_jump"):
				animated_sprite.play("ledge_jump")
			elif animated_sprite:
				animated_sprite.play("jump")
			velocity.y = LEDGE_JUMP_VELOCITY
			can_dash = true
			is_sprinting = false
			play_sfx(jump_sfx)
		
		STATE.WALL_SLIDE:
			animated_sprite.play("wall_slide")
			velocity.y = 0
			can_double_jump = true
			can_dash = true
			is_sprinting = false
			play_sfx(wall_slide_sfx)
		
		STATE.WALL_JUMP:
			animated_sprite.play("jump")
			velocity.y = WALL_JUMP_VELOCITY
			set_facing_direction(-facing_direction)
			saved_position = position
			play_sfx(jump_sfx)
		
		STATE.WALL_CLIMB:
			animated_sprite.play("wall_climb")
			velocity.y = WALL_CLIMB_VELOCITY
			saved_position = position
		
		STATE.DASH:
			if dash_cooldown and dash_cooldown.time_left > 0:
				active_state = previous_state
				return
			if previous_state == STATE.FLOOR or is_on_floor():
				if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("dash"):
					animated_sprite.play("dash")
			else:
				if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("air_dash"):
					animated_sprite.play("air_dash")
				elif animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("dash"):
					animated_sprite.play("dash")
			velocity.y = 0
			var input_h := signf(Input.get_axis("move_left", "move_right"))
			if input_h != 0:
				set_facing_direction(input_h)
			velocity.x = facing_direction * DASH_VELOCITY
			saved_position = position
			can_dash = previous_state == STATE.FLOOR or previous_state == STATE.WALL_SLIDE
			dash_jump_buffer = false
			# Miễn sát thương khi lướt (Invincibility / I-Frames)
			is_invincible = true
			if animated_sprite:
				animated_sprite.modulate = Color(1.3, 1.4, 2.0, 0.75)
			if dash_cooldown:
				dash_cooldown.start(dash_cooldown_time)
			play_sfx(dash_sfx)
		
		STATE.TURNING:
			set_facing_direction(-facing_direction)
		
		STATE.ATTACK:
			var input_h := Input.get_axis("move_left", "move_right")
			var input_v := Input.get_axis("move_up", "move_down")
			
			if input_h != 0:
				set_facing_direction(signf(input_h))
			else:
				set_facing_direction(facing_direction)
				
			var is_up := Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or input_v < -0.2
			var is_down := (Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or input_v > 0.2) and not is_on_floor()
			
			if is_up:
				current_attack_dir = Vector2.UP
				if attack_area:
					attack_area.position = Vector2(0, -45)
				if animated_sprite:
					animated_sprite.play("attack_up")
			elif is_down:
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
				attack_area.set_deferred("monitoring", true)
			if attack_timer:
				attack_timer.start(0.35)
			play_sfx(slash_sfx)

		STATE.THROW:
			if GameManager and not GameManager.can_needle_throw:
				switch_state(previous_state)
				return
			shoot_cooldown = shoot_cooldown_time
			if animated_sprite:
				animated_sprite.play("throw")
			play_sfx(throw_sfx if throw_sfx else shoot_sfx)
			is_sprinting = false
			velocity.x = 0
			_spawn_dart()

		STATE.REMOTE_SKILL:
			if GameManager and not GameManager.can_silk_storm:
				switch_state(previous_state)
				return
			remote_skill_cooldown = remote_skill_cooldown_time
			if animated_sprite:
				animated_sprite.play("remote_skill")
			if remote_skill_effect:
				remote_skill_effect.visible = true
				remote_skill_effect.flip_h = facing_direction < 0
				remote_skill_effect.position = Vector2(45 * facing_direction, -10)
				remote_skill_effect.play("remote_effect")
			if remote_sfx:
				play_sfx(remote_sfx)
			if remote_voice_sfx:
				play_sfx(remote_voice_sfx)
			is_sprinting = false
			velocity.x = facing_direction * 140.0
			current_attack_dir = Vector2(facing_direction, 0)
			if attack_area:
				attack_area.position = Vector2(50 * facing_direction, 0)
				attack_area.set_deferred("monitoring", true)

		STATE.DEFEND_START:
			defend_duration_timer = max_defend_duration
			if animated_sprite:
				animated_sprite.play("defend_start")
			play_sfx(defend_sfx)
			is_sprinting = false

		STATE.DEFEND:
			if animated_sprite:
				animated_sprite.play("defend")
			is_sprinting = false

		STATE.DEFEND_END:
			defend_cooldown = defend_cooldown_time
			if animated_sprite:
				animated_sprite.play("defend_end")
			is_sprinting = false

		STATE.DEFEND_ATTACK:
			defend_cooldown = defend_cooldown_time
			if animated_sprite:
				animated_sprite.play("defend_attack")
			if parry_sfx:
				play_sfx(parry_sfx)
			else:
				play_sfx(slash_sfx)
			
			# Lunge nhẹ về phía trước khi phản kích
			velocity.x = facing_direction * 220.0
			
			# Kích hoạt vùng gây sát thương phản đòn
			if attack_area:
				attack_area.position = Vector2(45 * facing_direction, 0)
				attack_area.set_deferred("monitoring", true)
			
			# Kích hoạt hiệu ứng CounterEffect chém lóe sáng
			if counter_effect:
				counter_effect.visible = true
				counter_effect.flip_h = facing_direction < 0
				counter_effect.position = Vector2(35 * facing_direction, -5)
				counter_effect.play("counter")
			
			if attack_timer:
				attack_timer.start(0.35)

		STATE.FOCUS_HEAL:
			velocity = Vector2.ZERO
			focus_heal_timer = 0.0
			bind_timer = 0.0
			bind_phase = BIND_PHASE.START
			is_sprinting = false
			if sound_cure_sfx:
				play_sfx(sound_cure_sfx)
			if animated_sprite:
				animated_sprite.modulate = Color.WHITE
				if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("bind_start"):
					animated_sprite.play("bind_start")
				elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("bind_charging"):
					animated_sprite.play("bind_charging")
				else:
					animated_sprite.play("idle")


func is_bind_held() -> bool:
	return Input.is_action_pressed("bind") or Input.is_action_pressed("heal") or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_H)

func is_bind_just_pressed() -> bool:
	return Input.is_action_just_pressed("bind") or Input.is_action_just_pressed("heal") or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_H)

func can_bind() -> bool:
	if not is_on_floor():
		return false
	if current_health >= max_health:
		return false
	var required_silk = mini(bind_silk_cost, max_silk)
	if current_silk < required_silk:
		return false
	if is_sitting or is_resetting_hazard or active_state == STATE.DIE:
		return false
	return true

func _trigger_bind_cancel() -> void:
	if bind_phase == BIND_PHASE.CANCEL or bind_phase == BIND_PHASE.SUCCESS:
		return
	bind_phase = BIND_PHASE.CANCEL
	bind_timer = 0.0
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("bind_cancel"):
			animated_sprite.play("bind_cancel")
		else:
			switch_state(STATE.FLOOR)

func _trigger_bind_success() -> void:
	if bind_phase == BIND_PHASE.SUCCESS:
		return
	bind_phase = BIND_PHASE.SUCCESS
	
	# 1. Trừ tơ theo quy định Silksong (tiêu tốn full cuộn tơ hoặc bind_silk_cost)
	var cost = mini(bind_silk_cost, max_silk)
	consume_silk(cost)
	
	# 2. Hồi phục 3 Mask (hoặc hồi đầy tùy giới hạn máu)
	var heal_target = mini(current_health + bind_heal_amount, max_health)
	var heal_count = heal_target - current_health
	if heal_count > 0:
		for i in range(heal_count):
			var restored_idx = current_health + i
			play_blood_load_effect(restored_idx)
		current_health = heal_target
		update_hud()
		
	# 3. SFX và Voice Silksong
	if voice_cure_sfx:
		play_sfx(voice_cure_sfx)
	if sound_cure_sfx:
		play_sfx(sound_cure_sfx)
	elif heal_sfx:
		play_sfx(heal_sfx)
		
	# 4. Hoạt ảnh bind_success (tơ phát nổ tỏa sáng hoàn tất hồi phục máu)
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("bind_success"):
			animated_sprite.play("bind_success")
		else:
			switch_state(STATE.FLOOR)
			
	# 5. Hiệu ứng lóe sáng phát nổ / rung nhẹ camera
	_play_bind_burst_flash()

func _play_bind_burst_flash() -> void:
	if animated_sprite:
		var flash_tw = create_tween()
		flash_tw.tween_property(animated_sprite, "modulate", Color(2.6, 2.6, 2.6, 1.0), 0.06)
		flash_tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.28)
	if camera_2d:
		var cam_tw = create_tween()
		var orig_offset = camera_2d.offset
		cam_tw.tween_property(camera_2d, "offset", orig_offset + Vector2(0, -3), 0.04)
		cam_tw.tween_property(camera_2d, "offset", orig_offset, 0.08)

func is_dash_held() -> bool:
	return Input.is_action_pressed("dash") or Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_L)

func try_cast_shoot() -> void:
	if GameManager and not GameManager.can_needle_throw:
		return
	if unlock_shoot and shoot_cooldown <= 0.0:
		if consume_silk(dart_silk_cost):
			switch_state(STATE.THROW)

func try_cast_remote_skill() -> void:
	if GameManager and not GameManager.can_silk_storm:
		return
	if unlock_special_attack and remote_skill_cooldown <= 0.0:
		if consume_silk(remote_skill_silk_cost):
			switch_state(STATE.REMOTE_SKILL)

func process_state(delta: float) -> void:
	match active_state:
		STATE.FALL:
			velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			if is_sprinting:
				handle_sprint(delta)
			else:
				handle_movement()
			
			if (Input.is_action_just_pressed("defend") or Input.is_key_pressed(KEY_C)) and unlock_defend and defend_cooldown <= 0.0:
				switch_state(STATE.DEFEND_START)
			elif (Input.is_action_just_pressed("attack") or Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_Z)) and unlock_attack:
				switch_state(STATE.ATTACK)
			elif (Input.is_action_just_pressed("shoot") or Input.is_key_pressed(KEY_K)):
				try_cast_shoot()
			elif (Input.is_action_just_pressed("special_attack") or Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_V)):
				try_cast_remote_skill()
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
			elif (Input.is_action_just_pressed("dash") or Input.is_key_pressed(KEY_L) or Input.is_action_just_pressed("sprint")) and can_dash and unlock_dash and (dash_cooldown == null or dash_cooldown.time_left <= 0.0):
				switch_state(STATE.DASH)
		
		STATE.FLOOR:
			var input_h := signf(Input.get_axis("move_left", "move_right"))
			if is_dash_held() and (input_h != 0 or is_sprinting):
				is_sprinting = true
				if animated_sprite and animated_sprite.animation != "sprint":
					animated_sprite.play("sprint")
				handle_sprint(delta)
			else:
				is_sprinting = false
				if input_h != 0:
					animated_sprite.play("walk")
				else:
					animated_sprite.play("idle")
				handle_movement()
			
			if (Input.is_action_just_pressed("defend") or Input.is_key_pressed(KEY_C)) and unlock_defend and defend_cooldown <= 0.0:
				switch_state(STATE.DEFEND_START)
			elif (Input.is_action_just_pressed("attack") or Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_Z)) and unlock_attack:
				switch_state(STATE.ATTACK)
			elif (Input.is_action_just_pressed("shoot") or Input.is_key_pressed(KEY_K)):
				try_cast_shoot()
			elif (Input.is_action_just_pressed("special_attack") or Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_V)):
				try_cast_remote_skill()
			elif not is_on_floor():
				switch_state(STATE.FALL)
			elif Input.is_action_just_pressed("jump"):
				switch_state(STATE.JUMP)
			elif is_bind_held() and can_bind():
				switch_state(STATE.FOCUS_HEAL)
			elif is_bind_just_pressed() and not can_bind():
				var req_silk = mini(bind_silk_cost, max_silk)
				if current_silk < req_silk:
					play_silk_warning()
			elif (Input.is_action_just_pressed("dash") or Input.is_key_pressed(KEY_L) or Input.is_action_just_pressed("sprint")) and unlock_dash and (dash_cooldown == null or dash_cooldown.time_left <= 0.0):
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
			
			if (Input.is_action_just_pressed("defend") or Input.is_key_pressed(KEY_C)) and unlock_defend and defend_cooldown <= 0.0:
				switch_state(STATE.DEFEND_START)
			elif (Input.is_action_just_pressed("attack") or Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_Z)) and unlock_attack:
				switch_state(STATE.ATTACK)
			elif (Input.is_action_just_pressed("shoot") or Input.is_key_pressed(KEY_K)):
				try_cast_shoot()
			elif (Input.is_action_just_pressed("special_attack") or Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_V)):
				try_cast_remote_skill()
			elif is_ledge() and is_space() and unlock_ledge_climb:
				switch_state(STATE.LEDGE_CLIMB)
			elif Input.is_action_just_released("jump") or velocity.y >= 0:
				velocity.y = 0
				switch_state(STATE.FALL)
			elif Input.is_action_just_pressed("jump") and unlock_double_jump:
				switch_state(STATE.DOUBLE_JUMP)
			elif (Input.is_action_just_pressed("dash") or Input.is_key_pressed(KEY_L) or Input.is_action_just_pressed("sprint")) and can_dash and unlock_dash and (dash_cooldown == null or dash_cooldown.time_left <= 0.0):
				switch_state(STATE.DASH)
		
		STATE.FLOAT:
			velocity.y = move_toward(velocity.y, FLOAT_VELOCITY, FLOAT_GRAVITY * delta)
			handle_movement(0, WALK_VELOCITY, FLOAT_ACCELERATION * delta)
			
			if is_on_floor():
				switch_state(STATE.FLOOR)
			elif Input.is_action_just_released("jump"):
				float_cooldown.start()
				switch_state(STATE.FALL)
			elif is_ledge() and is_space() and unlock_ledge_climb:
				switch_state(STATE.LEDGE_CLIMB)
			elif is_input_toward_facing() and can_wall_slide():
				switch_state(STATE.WALL_SLIDE)
			elif (Input.is_action_just_pressed("dash") or Input.is_key_pressed(KEY_L) or Input.is_action_just_pressed("sprint")) and can_dash and (dash_cooldown == null or dash_cooldown.time_left <= 0.0):
				switch_state(STATE.DASH)
		
		STATE.LEDGE_CLIMB:
			velocity = Vector2.ZERO
			is_sprinting = is_dash_held()
			
			if Input.is_action_just_pressed("jump"):
				switch_state(STATE.LEDGE_JUMP)
			else:
				ledge_climb_timer += delta
				var step_ratio: float = clampf(ledge_climb_timer / 0.12, 0.0, 1.0)
				var target_x: float = global_position.x + facing_direction * 22.0
				var target_y: float = global_position.y - 18.0
				if ledge_climb_ray_cast and ledge_climb_ray_cast.is_colliding():
					target_y = ledge_climb_ray_cast.get_collision_point().y - 16.0
				
				global_position.x = move_toward(global_position.x, target_x, 160.0 * delta)
				global_position.y = move_toward(global_position.y, target_y, 160.0 * delta)
				
				if step_ratio >= 1.0 or global_position.distance_to(Vector2(target_x, target_y)) < 3.0:
					global_position = Vector2(target_x, target_y)
					switch_state(STATE.FLOOR)

		STATE.FOCUS_HEAL:
			velocity = Vector2.ZERO
			
			if not is_on_floor() and bind_phase != BIND_PHASE.SUCCESS:
				_trigger_bind_cancel()
				switch_state(STATE.FALL)
				return
				
			match bind_phase:
				BIND_PHASE.START:
					bind_timer += delta
					if not is_bind_held():
						_trigger_bind_cancel()
						return
					if bind_timer >= 0.32:
						bind_phase = BIND_PHASE.CHARGING
						if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("bind_charging"):
							animated_sprite.play("bind_charging")

				BIND_PHASE.CHARGING:
					bind_timer += delta
					if animated_sprite:
						var pulse = 1.0 + sin(bind_timer * 20.0) * 0.18
						animated_sprite.modulate = Color(1.25 * pulse, 1.25 * pulse, 1.1 * pulse, 1.0)
					
					if not is_bind_held():
						_trigger_bind_cancel()
						return
					
					if bind_timer >= bind_charge_duration:
						_trigger_bind_success()

				BIND_PHASE.SUCCESS:
					pass

				BIND_PHASE.CANCEL:
					pass
		
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
			elif Input.is_action_just_pressed("sprint") or Input.is_action_just_pressed("dash") or Input.is_key_pressed(KEY_L):
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
			velocity.y = 0
			is_invincible = true
			is_sprinting = is_dash_held()
			if is_on_floor():
				coyote_timer.start()
			if Input.is_action_just_pressed("jump"):
				dash_jump_buffer = true
			var distance := absf(position.x - saved_position.x)
			if distance >= DASH_LENGTH or signf(get_last_motion().x) != facing_direction:
				if invincibility_timer == null or invincibility_timer.time_left <= 0:
					is_invincible = false
					if animated_sprite and active_state != STATE.DIE:
						animated_sprite.modulate = Color.WHITE
				if dash_jump_buffer and coyote_timer.time_left > 0:
					switch_state(STATE.JUMP)
				elif is_on_floor():
					is_sprinting = is_dash_held()
					switch_state(STATE.FLOOR)
				else:
					is_sprinting = is_dash_held()
					switch_state(STATE.FALL)
			elif is_ledge() and is_space():
				if invincibility_timer == null or invincibility_timer.time_left <= 0:
					is_invincible = false
					if animated_sprite and active_state != STATE.DIE:
						animated_sprite.modulate = Color.WHITE
				switch_state(STATE.LEDGE_CLIMB)
			elif can_wall_slide():
				if invincibility_timer == null or invincibility_timer.time_left <= 0:
					is_invincible = false
					if animated_sprite and active_state != STATE.DIE:
						animated_sprite.modulate = Color.WHITE
				switch_state(STATE.WALL_SLIDE)
		
		STATE.TURNING:
			if signf(velocity.x) == facing_direction and is_input_against_facing():
				set_facing_direction(-facing_direction)
			if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("turning"):
				if animated_sprite.animation != "turning":
					animated_sprite.play("turning")
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
				if is_on_floor():
					switch_state(STATE.JUMP)
				elif can_double_jump and unlock_double_jump:
					switch_state(STATE.DOUBLE_JUMP)
			
			if not is_on_floor():
				velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			
			var move_speed := WALK_VELOCITY
			if is_sprinting:
				move_speed = SPRINT_VELOCITY
			handle_movement(0, move_speed)

		STATE.THROW:
			if not is_on_floor():
				velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			velocity.x = move_toward(velocity.x, 0, 600.0 * delta)

		STATE.REMOTE_SKILL:
			if not is_on_floor():
				velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			velocity.x = move_toward(velocity.x, 0, 350.0 * delta)

		STATE.DEFEND_START:
			defend_duration_timer -= delta
			if not is_on_floor():
				velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			velocity.x = move_toward(velocity.x, 0, 800.0 * delta)
			
			if Input.is_action_just_pressed("attack") and unlock_attack:
				switch_state(STATE.DEFEND_ATTACK)
			elif defend_duration_timer <= 0.0:
				switch_state(STATE.DEFEND_END)
			elif not (Input.is_action_pressed("defend") or Input.is_key_pressed(KEY_C)) and not animated_sprite.is_playing():
				switch_state(STATE.DEFEND_END)

		STATE.DEFEND:
			defend_duration_timer -= delta
			if not is_on_floor():
				velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			velocity.x = move_toward(velocity.x, 0, 800.0 * delta)
			
			if Input.is_action_just_pressed("attack") and unlock_attack:
				switch_state(STATE.DEFEND_ATTACK)
			elif defend_duration_timer <= 0.0 or not (Input.is_action_pressed("defend") or Input.is_key_pressed(KEY_C)):
				switch_state(STATE.DEFEND_END)
			elif Input.is_action_just_pressed("jump") and is_on_floor():
				switch_state(STATE.JUMP)

		STATE.DEFEND_END:
			if not is_on_floor():
				velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			velocity.x = move_toward(velocity.x, 0, 800.0 * delta)
			
			if Input.is_action_just_pressed("attack") and unlock_attack:
				switch_state(STATE.ATTACK)
			elif (Input.is_action_just_pressed("defend") or Input.is_key_pressed(KEY_C)) and unlock_defend and defend_cooldown <= 0.0:
				switch_state(STATE.DEFEND_START)

		STATE.DEFEND_ATTACK:
			if not is_on_floor():
				velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			velocity.x = move_toward(velocity.x, 0, 500.0 * delta)
			
			if Input.is_action_just_pressed("jump") and is_on_floor():
				if attack_area:
					attack_area.set_deferred("monitoring", false)
				switch_state(STATE.JUMP)
		
		STATE.DIE:
			if not is_on_floor():
				velocity.y = move_toward(velocity.y, FALL_VELOCITY, FALL_GRAVITY * delta)
			else:
				velocity.x = move_toward(velocity.x, 0, 400.0 * delta)


func handle_movement(input_direction: float = 0, horizontal_velocity: float = WALK_VELOCITY, step: float = WALK_VELOCITY) -> void:
	if input_direction == 0:
		input_direction = signf(Input.get_axis("move_left", "move_right"))
	set_facing_direction(input_direction)
	var target_vel = input_direction * (horizontal_velocity * speed_multiplier)
	velocity.x = move_toward(velocity.x, target_vel, step * speed_multiplier)


func handle_sprint(delta: float) -> void:
	var input_h := signf(Input.get_axis("move_left", "move_right"))
	if input_h != 0:
		set_facing_direction(input_h)
	handle_movement(facing_direction, SPRINT_VELOCITY, SPRINT_ACCELERATION * delta)
	is_sprinting = is_dash_held() and not is_on_wall()


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
			if current_attack_dir == Vector2.UP:
				attack_area.position = Vector2(0, -45)
			elif current_attack_dir == Vector2.DOWN:
				attack_area.position = Vector2(0, 45)
			else:
				attack_area.position = Vector2(facing_direction * 40.0, 0)
		if counter_effect:
			counter_effect.flip_h = direction < 0
			counter_effect.position.x = direction * absf(counter_effect.position.x)
		if remote_skill_effect:
			remote_skill_effect.flip_h = direction < 0
			remote_skill_effect.position.x = direction * absf(remote_skill_effect.position.x)

func is_input_toward_facing() -> bool:
	return signf(Input.get_axis("move_left", "move_right")) == facing_direction


func is_input_against_facing() -> bool:
	return signf(Input.get_axis("move_left", "move_right")) == -facing_direction


func is_ledge() -> bool:
	if not ledge_climb_ray_cast:
		return false
	ledge_climb_ray_cast.force_raycast_update()
	if not ledge_climb_ray_cast.is_colliding():
		return false
	var norm := ledge_climb_ray_cast.get_collision_normal()
	var hitting_top := norm.y < -0.5
	var near_wall := is_on_wall() or (wall_slide_ray_cast and wall_slide_ray_cast.is_colliding()) or is_input_toward_facing()
	return near_wall and hitting_top


func is_space() -> bool:
	if not ledge_space_ray_cast or not ledge_climb_ray_cast or not ledge_climb_ray_cast.is_colliding():
		return true
	ledge_space_ray_cast.global_position = ledge_climb_ray_cast.get_collision_point() + Vector2(0, -10)
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
