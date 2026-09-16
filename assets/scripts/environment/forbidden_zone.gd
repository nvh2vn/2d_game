extends Area2D

@export_group("Alarm Settings")
@export var max_beeps: int = 5                  # Số lần phát tiếng cảnh báo (từ 3 đến 6 lần)
@export var alarm_sound: AudioStream            # File âm thanh còi hú / tiếng bíp cảnh báo
@export var beep_interval: float = 0.4          # Khoảng cách giữa các tiếng bíp (giây)

@onready var alarm_player: AudioStreamPlayer2D = $AlarmPlayer
@onready var alarm_timer: Timer = $AlarmTimer
@onready var debug_rect: ColorRect = get_node_or_null("DebugVisual")

var current_beep_count: int = 0
var is_alarming: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if alarm_timer:
		alarm_timer.wait_time = beep_interval
		alarm_timer.timeout.connect(_on_alarm_timer_timeout)


func _on_body_entered(body: Node2D) -> void:
	# Phát hiện khi một đối tượng B (quái vật/creep/NPC) đi vào vùng cấm
	if (body.is_in_group("enemies") or body.name.to_lower().contains("enemy") or body.name.to_lower().contains("creep")) and not is_alarming:
		start_alarm()


func start_alarm() -> void:
	is_alarming = true
	current_beep_count = 0
	trigger_beep()
	if alarm_timer:
		alarm_timer.start()
	
	# Hiệu ứng nhấp nháy đỏ vùng cấm khi có cảnh báo
	if debug_rect:
		var tween = create_tween().set_loops(max_beeps)
		tween.tween_property(debug_rect, "modulate:a", 0.6, beep_interval * 0.5)
		tween.tween_property(debug_rect, "modulate:a", 0.15, beep_interval * 0.5)


func trigger_beep() -> void:
	if current_beep_count < max_beeps:
		if alarm_player:
			if alarm_sound and alarm_player.stream != alarm_sound:
				alarm_player.stream = alarm_sound
			if alarm_player.stream:
				alarm_player.play()
		current_beep_count += 1
	else:
		if alarm_timer:
			alarm_timer.stop()
		is_alarming = false


func _on_alarm_timer_timeout() -> void:
	trigger_beep()
