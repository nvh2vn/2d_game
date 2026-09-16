extends Area2D
class_name PoisonTrap

@export var damage: int = 1
@export var slow_duration: float = 3.0
@export var slow_multiplier: float = 0.45
@export var cooldown_time: float = 1.8
@export var trigger_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Player/sound_damage_0.mp3")

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var particles: CPUParticles2D = get_node_or_null("CPUParticles2D")
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

var is_ready: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if animated_sprite:
		animated_sprite.play("idle")

func _on_body_entered(body: Node2D) -> void:
	if not is_ready:
		return
	
	if body.has_method("take_damage") and (body.is_in_group("player") or body.name.begins_with("Player")):
		trigger_trap(body)

func trigger_trap(player: Node2D) -> void:
	is_ready = false
	
	# Gây 1 sát thương cho người chơi
	if player.has_method("take_damage"):
		player.take_damage(damage, global_position)
	
	# Làm chậm tốc độ di chuyển của người chơi
	if player.has_method("apply_slow"):
		player.apply_slow(slow_duration, slow_multiplier)
	
	# Âm thanh kích hoạt bẫy
	if audio_player and trigger_sfx:
		audio_player.stream = trigger_sfx
		audio_player.play()
	
	# Hiệu ứng nổ phấn độc
	if particles:
		particles.restart()
		particles.emitting = true
	
	# Hoạt ảnh bẫy cắn / phun độc
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("trigger"):
			animated_sprite.play("trigger")
		else:
			var tw = create_tween()
			tw.tween_property(animated_sprite, "scale", Vector2(0.42, 0.28), 0.08)
			tw.tween_property(animated_sprite, "scale", Vector2(0.35, 0.35), 0.12)
	
	# Chờ hết hồi chiêu rồi kích hoạt lại
	await get_tree().create_timer(cooldown_time).timeout
	is_ready = true
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
