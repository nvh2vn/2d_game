extends Node2D
class_name FallingRockHazard

enum State { IDLE, TELEGRAPH, FALLING, HIT, RESPAWNING }

@export_group("Hazard Config")
@export var damage: int = 2
@export var shake_time: float = 0.4
@export var fall_speed: float = 350.0
@export var max_fall_speed: float = 750.0
@export var gravity_accel: float = 1200.0
@export var respawn_delay: float = 3.0
@export var trigger_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Player/sound_damage_0.mp3")

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var trigger_area: Area2D = get_node_or_null("TriggerArea")
@onready var hit_area: Area2D = get_node_or_null("HitArea")
@onready var ray_cast: RayCast2D = get_node_or_null("RayCast2D")
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

var current_state: State = State.IDLE
var initial_position: Vector2
var current_fall_velocity: float = 0.0
var shake_timer: float = 0.0
var sprite_initial_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("hazards")
	add_to_group("falling_rocks")
	initial_position = global_position
	if sprite:
		sprite_initial_offset = sprite.position
		
	if trigger_area:
		trigger_area.collision_layer = 4
		trigger_area.collision_mask = 255
		trigger_area.body_entered.connect(_on_trigger_body_entered)
		trigger_area.area_entered.connect(_on_trigger_area_entered)
		
	if hit_area:
		hit_area.collision_layer = 4
		hit_area.collision_mask = 255
		hit_area.body_entered.connect(_on_hit_body_entered)
		hit_area.area_entered.connect(_on_hit_area_entered)

	if ray_cast:
		ray_cast.collision_mask = 255

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_check_idle_trigger()
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.FALLING:
			_process_falling(delta)

func _check_idle_trigger() -> void:
	if not trigger_area:
		return
	for body in trigger_area.get_overlapping_bodies():
		if _is_player(body):
			_start_telegraph()
			return
	for area in trigger_area.get_overlapping_areas():
		var parent = area.get_parent()
		if parent and _is_player(parent):
			_start_telegraph()
			return

func _on_trigger_body_entered(body: Node2D) -> void:
	if current_state == State.IDLE and _is_player(body):
		_start_telegraph()

func _on_trigger_area_entered(area: Area2D) -> void:
	if current_state == State.IDLE:
		var parent = area.get_parent()
		if parent and _is_player(parent):
			_start_telegraph()

func _is_player(node: Node2D) -> bool:
	return node.is_in_group("player") or node.name.begins_with("Player") or node.has_method("trigger_hazard_reset")

func _start_telegraph() -> void:
	current_state = State.TELEGRAPH
	shake_timer = shake_time

func _process_telegraph(delta: float) -> void:
	shake_timer -= delta
	if sprite:
		var offset_x = randf_range(-3.0, 3.0)
		sprite.position = sprite_initial_offset + Vector2(offset_x, 0)
		
	if shake_timer <= 0.0:
		if sprite:
			sprite.position = sprite_initial_offset
		current_state = State.FALLING
		current_fall_velocity = fall_speed

func _process_falling(delta: float) -> void:
	current_fall_velocity = minf(current_fall_velocity + gravity_accel * delta, max_fall_speed)
	global_position.y += current_fall_velocity * delta
	
	# RayCast check for ground terrain
	if ray_cast and ray_cast.is_colliding():
		var collider = ray_cast.get_collider()
		if collider:
			if _is_player(collider):
				_on_impact_player(collider)
				return
			else:
				_on_impact_ground()
				return
				
	# Overlap checks during falling
	if hit_area:
		for body in hit_area.get_overlapping_bodies():
			if current_state != State.FALLING:
				return
			if _is_player(body):
				_on_impact_player(body)
				return
			elif body is TileMap or body is TileMapLayer or body is StaticBody2D:
				_on_impact_ground()
				return

func _on_hit_body_entered(body: Node2D) -> void:
	if current_state != State.FALLING:
		return
		
	if _is_player(body):
		_on_impact_player(body)
	elif body is TileMap or body is TileMapLayer or body is StaticBody2D:
		_on_impact_ground()

func _on_hit_area_entered(area: Area2D) -> void:
	if current_state != State.FALLING:
		return
		
	var parent = area.get_parent()
	if parent and _is_player(parent):
		_on_impact_player(parent)

func _on_impact_player(player: Node2D) -> void:
	if current_state != State.FALLING:
		return
	current_state = State.HIT
	if player.has_method("trigger_hazard_reset"):
		player.trigger_hazard_reset(damage, global_position)
	elif player.has_method("take_damage"):
		player.take_damage(damage, global_position)
		
	_play_impact_sfx()
	_break_and_respawn()

func _on_impact_ground() -> void:
	if current_state != State.FALLING:
		return
	current_state = State.HIT
	_play_impact_sfx()
	_break_and_respawn()

func _play_impact_sfx() -> void:
	if audio_player and trigger_sfx:
		audio_player.stream = trigger_sfx
		audio_player.play()

func _break_and_respawn() -> void:
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "scale", Vector2(1.3, 0.2), 0.1)
		tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.1)
		await tw.finished
		sprite.visible = false
		
	if respawn_delay > 0.0:
		current_state = State.RESPAWNING
		await get_tree().create_timer(respawn_delay).timeout
		_reset_to_idle()
	else:
		queue_free()

func _reset_to_idle() -> void:
	global_position = initial_position
	current_fall_velocity = 0.0
	if sprite:
		sprite.scale = Vector2.ONE
		sprite.modulate.a = 1.0
		sprite.position = sprite_initial_offset
		sprite.visible = true
	current_state = State.IDLE
