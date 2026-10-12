extends Area2D
class_name BenchCheckpoint

signal bench_rested()

@export_group("Bench Config")
@export var face_right: bool = true
@export var sit_offset: Vector2 = Vector2(0, -5)
@export var bench_unlit_tex: Texture2D = null
@export var bench_lit_tex: Texture2D = null
@export var rest_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Player/bench_rest.mp3")

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var sit_position: Marker2D = get_node_or_null("SitPosition")
@onready var interact_prompt: Node2D = get_node_or_null("InteractPrompt")
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

var is_player_in_range: bool = false
var current_player: Node2D = null
var is_active_bench: bool = false
var rest_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("benches")
	add_to_group("checkpoints")
	collision_layer = 4
	collision_mask = 255
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	if interact_prompt:
		interact_prompt.visible = false
		
	if sprite:
		if sprite.texture != null and bench_unlit_tex == null:
			bench_unlit_tex = sprite.texture
		elif bench_unlit_tex != null and sprite.texture == null:
			sprite.texture = bench_unlit_tex

func _physics_process(delta: float) -> void:
	if rest_cooldown > 0.0:
		rest_cooldown -= delta

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(current_player):
		return
		
	var is_sitting_now: bool = ("is_sitting" in current_player and current_player.is_sitting) or is_active_bench
	
	if is_sitting_now:
		if rest_cooldown > 0.0:
			return
		var is_any_leave_key: bool = event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and (event.keycode in [KEY_A, KEY_D, KEY_S, KEY_W, KEY_LEFT, KEY_RIGHT, KEY_DOWN, KEY_UP, KEY_E, KEY_SPACE]))
		if is_any_leave_key:
			_stop_rest()
			get_viewport().set_input_as_handled()
			return
			
	if is_player_in_range and not is_sitting_now:
		var is_interact: bool = event.is_action_pressed("ui_up") or event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and (event.keycode in [KEY_E, KEY_UP, KEY_W]))
		if is_interact:
			_start_rest()
			get_viewport().set_input_as_handled()

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		current_player = body
		_set_in_range(true)

func _on_body_exited(body: Node2D) -> void:
	if body == current_player:
		_set_in_range(false)

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent and _is_player(parent):
		current_player = parent
		_set_in_range(true)

func _on_area_exited(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent == current_player:
		_set_in_range(false)

func _is_player(node: Node2D) -> bool:
	return node.is_in_group("player") or node.name.begins_with("Player") or node.has_method("trigger_hazard_reset")

func _set_in_range(in_range: bool) -> void:
	is_player_in_range = in_range
	if interact_prompt:
		interact_prompt.visible = in_range
		if in_range:
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			interact_prompt.scale = Vector2(0.5, 0.5)
			tw.tween_property(interact_prompt, "scale", Vector2.ONE, 0.15)

	if in_range and not is_active_bench:
		TouchControls.show_interact(get_tree(), "bench")
	elif not in_range:
		TouchControls.hide_interact(get_tree())

func _start_rest() -> void:
	if not is_instance_valid(current_player):
		return
		
	is_active_bench = true
	rest_cooldown = 0.35
	TouchControls.hide_interact(get_tree())
	
	if sprite and bench_lit_tex:
		sprite.texture = bench_lit_tex
		
	if audio_player and rest_sfx:
		audio_player.stream = rest_sfx
		audio_player.play()
		
	var sit_pos = global_position + sit_offset
	if sit_position:
		sit_pos = sit_position.global_position
		
	var scene_path = ""
	if get_tree().current_scene:
		scene_path = get_tree().current_scene.scene_file_path
		
	# Hồi phục toàn bộ máu & năng lượng cho người chơi
	if current_player.has_method("rest_at_bench"):
		current_player.rest_at_bench(sit_pos, face_right)
		
	# Cập nhật Checkpoint và lưu mã hóa toàn bộ dữ liệu xuống đĩa (Mobile Safe)
	if SaveManager.instance:
		SaveManager.instance.set_checkpoint(scene_path, sit_pos, true)
	else:
		SaveManager.save_bench_checkpoint(sit_pos, scene_path)
		
	bench_rested.emit()
	get_tree().call_group("enemies", "reset_enemy")

func _stop_rest() -> void:
	if is_instance_valid(current_player) and current_player.has_method("stand_up_from_bench"):
		current_player.stand_up_from_bench()
	if sprite and bench_unlit_tex:
		sprite.texture = bench_unlit_tex
	is_active_bench = false
	if is_player_in_range:
		TouchControls.show_interact(get_tree(), "bench")
