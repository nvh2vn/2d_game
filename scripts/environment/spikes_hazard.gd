extends Area2D
class_name SpikesHazard

@export var damage: int = 2
@export var is_pogoable: bool = true
@export var trigger_sfx: AudioStream = preload("res://assets/audio/player/sound_damage_0.mp3")

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

func _ready() -> void:
	add_to_group("hazards")
	add_to_group("spikes")
	collision_layer = 4
	collision_mask = 255
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if _is_player(body):
			_try_damage_player(body)
			
	for area in get_overlapping_areas():
		var parent = area.get_parent()
		if parent and _is_player(parent):
			_try_damage_player(parent)

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_try_damage_player(body)

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent and _is_player(parent):
		_try_damage_player(parent)

func _is_player(node: Node2D) -> bool:
	return node.is_in_group("player") or node.name.begins_with("Player") or node.has_method("trigger_hazard_reset")

func _try_damage_player(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
		
	if "is_touching_hazard" in target:
		target.is_touching_hazard = true

	if "is_invincible" in target and target.is_invincible:
		return
		
	if target.has_method("trigger_hazard_reset"):
		target.trigger_hazard_reset(damage, global_position)
		_play_sfx()
	elif target.has_method("take_damage"):
		target.take_damage(damage, global_position)
		_play_sfx()

func _play_sfx() -> void:
	if audio_player and trigger_sfx:
		audio_player.stream = trigger_sfx
		audio_player.play()
