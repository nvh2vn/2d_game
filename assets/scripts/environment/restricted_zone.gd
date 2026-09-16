class_name RestrictedZone
extends Area2D

## Số lần phát chuỗi âm thanh cảnh báo (từ 3 đến 6 lần theo yêu cầu)
@export_range(3, 6) var warning_repeats: int = 5

## Khoảng cách thời gian giữa các lần kêu (giây)
@export var sound_interval: float = 0.45

## Thời gian hồi trước khi có thể kích hoạt cảnh báo đợt tiếp theo (giây)
@export var alarm_cooldown: float = 2.5

## Âm thanh cảnh báo
@export var warning_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Player/sound_counter.mp3")

## Tiêu đề cảnh báo hiển thị trên vùng cấm
@export var zone_title: String = "⚠️ VÙNG CẤM - CẢNH BÁO!"

@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var visual_zone: ColorRect = $VisualZone
@onready var warning_label: Label = $WarningLabel
@onready var particles: CPUParticles2D = $CPUParticles2D

var is_alarm_active: bool = false
var cooldown_timer: float = 0.0


func _ready() -> void:
	# Bắt va chạm với Quái vật / NPC (Layer 2)
	collision_layer = 0
	collision_mask = 2
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	if audio_player and warning_sfx:
		audio_player.stream = warning_sfx
		audio_player.bus = "SFX"
	
	if warning_label:
		warning_label.text = zone_title
		warning_label.modulate.a = 0.0


func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta


func _on_body_entered(body: Node2D) -> void:
	_check_intruder(body)


func _on_area_entered(area: Area2D) -> void:
	if area.owner and area.owner is Node2D:
		_check_intruder(area.owner)


func _check_intruder(node: Node2D) -> void:
	if is_alarm_active or cooldown_timer > 0.0:
		return
	
	# Kiểm tra nếu là Quái vật / NPC
	if node.is_in_group("enemies") or node.name.to_lower().contains("bug") or node.name.to_lower().contains("enemy") or node.has_method("take_damage"):
		trigger_alarm(node)


func trigger_alarm(intruder: Node2D) -> void:
	is_alarm_active = true
	cooldown_timer = alarm_cooldown
	
	print("[RestrictedZone] 🚨 CẢNH BÁO: Đối tượng NPC/Quái vật (", intruder.name, ") đã bước vào Vùng Cấm!")
	
	if particles:
		particles.emitting = true
	
	# Hiện nhãn cảnh báo
	if warning_label:
		var label_tween = create_tween()
		label_tween.tween_property(warning_label, "modulate:a", 1.0, 0.2)
	
	# Phát chuỗi âm thanh cảnh báo liên tục (từ 3 đến 6 lần)
	for i in range(warning_repeats):
		if audio_player:
			audio_player.play()
		
		# Nhấp nháy trực quan vùng cấm
		_flash_visual()
		
		# Nhấp nháy text cảnh báo
		_flash_label()
		
		await get_tree().create_timer(sound_interval).timeout
	
	# Ẩn dần nhãn cảnh báo sau khi phát xong
	if warning_label:
		var fade_tween = create_tween()
		fade_tween.tween_property(warning_label, "modulate:a", 0.0, 0.6)
	
	is_alarm_active = false


func _flash_visual() -> void:
	if not visual_zone:
		return
	var tween = create_tween()
	tween.tween_property(visual_zone, "color", Color(1.0, 0.1, 0.1, 0.6), sound_interval * 0.4)
	tween.tween_property(visual_zone, "color", Color(1.0, 0.0, 0.0, 0.2), sound_interval * 0.6)


func _flash_label() -> void:
	if not warning_label:
		return
	var tween = create_tween()
	tween.tween_property(warning_label, "scale", Vector2(1.15, 1.15), sound_interval * 0.3)
	tween.tween_property(warning_label, "scale", Vector2(1.0, 1.0), sound_interval * 0.7)
