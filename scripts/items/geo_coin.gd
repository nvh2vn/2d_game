extends CharacterBody2D
class_name GeoCoin

@export var value: int = 1 # 1, 5, hoặc 25
@export var coin_textures: Dictionary = {
	1: preload("res://assets/ui/1Geo.png"),
	5: preload("res://assets/ui/5Geo.png"),
	25: preload("res://assets/ui/25Geo.png")
}

@export var collect_sfx: Array[AudioStream] = [
	preload("res://assets/audio/geo/geo_collect_0.mp3"),
	preload("res://assets/audio/geo/geo_collect_1.mp3")
]

@export var bounce_sfx: Array[AudioStream] = [
	preload("res://assets/audio/geo/geo_hit_ground_0.mp3"),
	preload("res://assets/audio/geo/geo_hit_ground_1.mp3")
]

var gravity: float = 750.0
var bounce_count: int = 0
var max_bounces: int = 2
var bounce_damp: float = 0.45
var pickup_delay: float = 0.18
var target_player: Node2D = null
var is_collected: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var magnet_area: Area2D = $MagnetArea
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready() -> void:
	add_to_group("geo_coins")
	update_texture()
	if pickup_area:
		pickup_area.body_entered.connect(_on_pickup_body_entered)
	if magnet_area:
		magnet_area.body_entered.connect(_on_magnet_body_entered)
		magnet_area.body_exited.connect(_on_magnet_body_exited)


func set_value(val: int) -> void:
	value = val
	update_texture()


func update_texture() -> void:
	if sprite == null:
		return
	if coin_textures.has(value):
		sprite.texture = coin_textures[value]
	else:
		sprite.texture = coin_textures[1]
	
	# Điều chỉnh scale nhẹ theo giá trị tiền
	if value == 1:
		sprite.scale = Vector2(0.4, 0.4)
	elif value == 5:
		sprite.scale = Vector2(0.48, 0.48)
	elif value == 25:
		sprite.scale = Vector2(0.55, 0.55)


func _physics_process(delta: float) -> void:
	if is_collected:
		return
		
	if pickup_delay > 0.0:
		pickup_delay -= delta

	# Hiệu ứng nam châm hút về phía Player nếu trong tầm
	if target_player and is_instance_valid(target_player) and not ("current_health" in target_player and target_player.current_health <= 0):
		var to_player = (target_player.global_position - global_position)
		var dist = to_player.length()
		if dist > 3.0:
			var speed = clampf(420.0 + (100.0 - dist) * 4.0, 350.0, 750.0)
			velocity = velocity.move_toward(to_player.normalized() * speed, 1600.0 * delta)
			move_and_slide()
			
			if pickup_delay <= 0.0 and dist < 22.0:
				collect(target_player)
			return

	# Vật lý rơi bình thường
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0, 80.0 * delta)
	else:
		if bounce_count < max_bounces and absf(velocity.y) > 40.0:
			bounce_count += 1
			velocity.y = -velocity.y * bounce_damp
			velocity.x *= 0.65
			play_bounce_sfx()
		else:
			velocity.x = move_toward(velocity.x, 0, 400.0 * delta)
			velocity.y = 0.0

	move_and_slide()


func _on_magnet_body_entered(body: Node2D) -> void:
	if is_player(body):
		target_player = body


func _on_magnet_body_exited(body: Node2D) -> void:
	if body == target_player:
		target_player = null


func _on_pickup_body_entered(body: Node2D) -> void:
	if pickup_delay <= 0.0 and is_player(body):
		collect(body)


func is_player(node: Node) -> bool:
	return node.is_in_group("player") or node.name == "PlayerController" or node.name.begins_with("Player")


func play_bounce_sfx() -> void:
	if audio_player and bounce_sfx.size() > 0:
		audio_player.stream = bounce_sfx.pick_random()
		audio_player.pitch_scale = randf_range(0.95, 1.15)
		audio_player.play()


func collect(player: Node) -> void:
	if is_collected:
		return
	is_collected = true
	
	if player.has_method("add_geo"):
		player.add_geo(value)

	if audio_player and collect_sfx.size() > 0:
		audio_player.stream = collect_sfx.pick_random()
		audio_player.pitch_scale = randf_range(0.95, 1.15)
		audio_player.play()

	# Hiệu ứng nảy scale và mờ dần
	if sprite:
		var tween = create_tween()
		tween.parallel().tween_property(sprite, "scale", sprite.scale * 1.6, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.14)
		tween.parallel().tween_property(sprite, "position:y", sprite.position.y - 15.0, 0.14)
		await tween.finished
	else:
		await get_tree().create_timer(0.1).timeout
		
	queue_free()
