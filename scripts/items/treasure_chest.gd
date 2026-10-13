extends StaticBody2D
class_name TreasureChest

enum ChestType {
	SMALL,    # Rương nhỏ: ~5 xu (1Geo và 5Geo)
	MEDIUM,   # Rương vừa: ~12 xu (pha trộn 1Geo, 5Geo, 25Geo)
	LARGE,    # Rương lớn: ~25 xu (rất nhiều 5Geo và 25Geo)
	JACKPOT,  # Rương siêu cấp / Đại kho báu: ~40 xu nổ tung màn hình
	CUSTOM    # Tự chỉ định số lượng từng loại xu bên dưới
}

@export_group("Chest Content & Type")
@export var chest_type: ChestType = ChestType.MEDIUM
@export var hits_to_open: int = 1

@export_group("Custom Coins (Khi chọn type = CUSTOM)")
@export var custom_1_geo_count: int = 6
@export var custom_5_geo_count: int = 3
@export var custom_25_geo_count: int = 1

@export_group("Burst Physics")
@export var min_horizontal_speed: float = -280.0
@export var max_horizontal_speed: float = 280.0
@export var min_upward_speed: float = -460.0
@export var max_upward_speed: float = -250.0

@export_group("Visuals & Audio")
@export var closed_texture: Texture2D = preload("res://assets/ui/Chest - atlas0 #087042(1).png")
@export var opened_texture: Texture2D = preload("res://assets/ui/Chest - atlas0 #087042(2).png")
@export var coin_scene: PackedScene = preload("res://scenes/prefabs/items/geo_coin.tscn")
@export var open_sfx: Array[AudioStream] = [
	preload("res://assets/audio/geo/geo_rock_hit_0.mp3"),
	preload("res://assets/audio/geo/geo_rock_hit_1.mp3"),
	preload("res://assets/audio/geo/geo_rock_hit_2.mp3")
]

@export var chest_id: String = ""

var current_hits: int = 0
var is_opened: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready() -> void:
	add_to_group("chests")
	_init_chest_id()
	
	# Kiểm tra trạng thái đã mở từ GameManager
	if _check_is_opened():
		_set_opened_state_immediate()
		return
		
	if sprite and closed_texture:
		sprite.texture = closed_texture
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)


func _init_chest_id() -> void:
	if chest_id.strip_edges() == "":
		var scene_name = ""
		if is_inside_tree() and get_tree() and get_tree().current_scene:
			scene_name = get_tree().current_scene.name
		chest_id = "%s_%s_%d_%d" % [scene_name, name, int(global_position.x), int(global_position.y)]


func _get_game_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().root and get_tree().root.has_node("GameManager"):
		return get_tree().root.get_node("GameManager")
	return null


func _check_is_opened() -> bool:
	var gm = _get_game_manager()
	if gm:
		if "opened_chests" in gm and gm.opened_chests.has(chest_id):
			return bool(gm.opened_chests[chest_id])
		if gm.has_method("is_chest_opened"):
			return gm.is_chest_opened(chest_id)
	return false


func _set_opened_state_immediate() -> void:
	is_opened = true
	if sprite and opened_texture:
		sprite.texture = opened_texture
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		var col = hurtbox.get_node_or_null("CollisionShape2D")
		if col:
			col.set_deferred("disabled", true)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_opened:
		return
	if area.name == "AttackArea" or area.is_in_group("player_attacks"):
		take_hit()


func take_damage(_amount: int = 1, _dir: Vector2 = Vector2.ZERO) -> void:
	take_hit()


func take_hit() -> void:
	if is_opened:
		return
	
	current_hits += 1
	play_hit_sfx()
	
	# Hiệu ứng đàn hồi nảy rương
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(0.48, 0.32), 0.05)
		tween.tween_property(sprite, "scale", Vector2(0.36, 0.44), 0.07)
		tween.tween_property(sprite, "scale", Vector2(0.4, 0.4), 0.08)
		
		# Hiệu ứng chớp sáng trắng
		var flash = create_tween()
		flash.tween_property(sprite, "modulate", Color(2.2, 2.2, 2.2), 0.04)
		flash.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	
	if current_hits >= hits_to_open:
		open_chest()


func open_chest() -> void:
	if is_opened:
		return
	is_opened = true
	
	# Ghi nhận trạng thái mở rương vào GameManager
	var gm = _get_game_manager()
	if gm:
		if "opened_chests" in gm:
			gm.opened_chests[chest_id] = true
		if gm.has_method("record_chest_opened"):
			gm.record_chest_opened(chest_id)
			
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		var col = hurtbox.get_node_or_null("CollisionShape2D")
		if col:
			col.set_deferred("disabled", true)
			
	if sprite and opened_texture:
		sprite.texture = opened_texture
		
	play_hit_sfx()
	
	# Tính toán danh sách các đồng xu cần bắn ra
	var coins_to_spawn: Array[int] = _generate_coin_list()
	
	# Bắn pháo hoa đồng tiền tung tóe
	for i in range(coins_to_spawn.size()):
		var coin_val = coins_to_spawn[i]
		spawn_burst_coin(coin_val, i, coins_to_spawn.size())


func _generate_coin_list() -> Array[int]:
	var list: Array[int] = []
	match chest_type:
		ChestType.SMALL:
			# ~6 xu: 4 đồng 1Geo, 2 đồng 5Geo
			_add_coins(list, 1, 4)
			_add_coins(list, 5, 2)
		ChestType.MEDIUM:
			# ~12 xu: 7 đồng 1Geo, 4 đồng 5Geo, 1 đồng 25Geo
			_add_coins(list, 1, 7)
			_add_coins(list, 5, 4)
			_add_coins(list, 25, 1)
		ChestType.LARGE:
			# ~22 xu: 12 đồng 1Geo, 7 đồng 5Geo, 3 đồng 25Geo
			_add_coins(list, 1, 12)
			_add_coins(list, 5, 7)
			_add_coins(list, 25, 3)
		ChestType.JACKPOT:
			# ~40 xu: 20 đồng 1Geo, 14 đồng 5Geo, 6 đồng 25Geo
			_add_coins(list, 1, 20)
			_add_coins(list, 5, 14)
			_add_coins(list, 25, 6)
		ChestType.CUSTOM:
			_add_coins(list, 1, custom_1_geo_count)
			_add_coins(list, 5, custom_5_geo_count)
			_add_coins(list, 25, custom_25_geo_count)
			
	list.shuffle()
	return list


func _add_coins(list: Array[int], coin_val: int, count: int) -> void:
	for i in range(count):
		list.append(coin_val)


func spawn_burst_coin(coin_value: int, index: int, total: int) -> void:
	if coin_scene == null:
		return
	
	var coin = coin_scene.instantiate() as GeoCoin
	if coin == null:
		return
		
	coin.set_value(coin_value)
	coin.global_position = global_position + Vector2(randf_range(-14.0, 14.0), -18.0)
	
	# Vận tốc nổ tung tỏa đều hình cánh quạt ngẫu nhiên
	var angle_factor = float(index) / maxf(1.0, float(total - 1))
	var vx = lerpf(min_horizontal_speed, max_horizontal_speed, angle_factor) + randf_range(-35.0, 35.0)
	var vy = randf_range(min_upward_speed, max_upward_speed)
	
	coin.velocity = Vector2(vx, vy)
	get_parent().call_deferred("add_child", coin)


func play_hit_sfx() -> void:
	if audio_player and open_sfx.size() > 0:
		audio_player.stream = open_sfx.pick_random()
		audio_player.pitch_scale = randf_range(0.9, 1.15)
		audio_player.play()
