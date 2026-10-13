class_name BaseEnemy
extends CharacterBody2D

@export_group("Stats & Combat")
@export var max_health: int = 2
@export var damage: int = 1
@export var speed: float = 80.0

@export_group("Loot & Rewards")
@export var loot_tier: GeoDropHelper.EnemyTier = GeoDropHelper.EnemyTier.NORMAL
@export var min_drop_coins: int = 1
@export var max_drop_coins: int = 3
@export var chance_5_geo: float = 0.0   # Tỷ lệ rơi 5Geo (0.0 -> 1.0)
@export var chance_25_geo: float = 0.0  # Tỷ lệ rơi 25Geo (0.0 -> 1.0)

@export var is_boss: bool = false
@export var enemy_journal_id: String = ""

var current_health: int = 2
var is_dead: bool = false
var knockback_timer: float = 0.0
var spawn_position: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("%AnimatedSprite")
@onready var hitbox: Area2D = get_node_or_null("%Hitbox")
@onready var hurtbox: Area2D = get_node_or_null("%Hurtbox")


func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position
	current_health = max_health
	_setup_combat_areas()
	_on_enemy_ready()

func reset_enemy() -> void:
	if is_boss and is_dead:
		return
	is_dead = false
	current_health = max_health
	if spawn_position != Vector2.ZERO:
		global_position = spawn_position
	visible = true
	if hitbox:
		hitbox.set_deferred("monitoring", true)
		hitbox.set_deferred("monitorable", true)
	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
		hurtbox.set_deferred("monitorable", true)
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")


## Hook để quái vật con ghi đè logic khởi tạo riêng
func _on_enemy_ready() -> void:
	pass


func _setup_combat_areas() -> void:
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)


func _on_hitbox_body_entered(body: Node) -> void:
	if is_dead:
		return
	if is_player(body):
		if body.has_method("take_damage") and ("is_invincible" not in body or not body.is_invincible):
			body.take_damage(damage, global_position)
		_on_player_hit(body)


## Hook khi quái cắn trúng player
func _on_player_hit(_player_body: Node) -> void:
	pass


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.name == "AttackArea" or area.is_in_group("player_attacks"):
		var dmg = 1
		var kb_dir = Vector2.ZERO
		if "damage" in area:
			dmg = area.damage
		if "direction" in area:
			kb_dir = area.direction
		else:
			var player_node = area.get_parent()
			if player_node and "current_attack_dir" in player_node:
				kb_dir = player_node.current_attack_dir
			elif player_node:
				kb_dir = (global_position - player_node.global_position).normalized()
		take_damage(dmg, kb_dir)


func take_damage(amount: int = 1, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	current_health -= amount
	
	# Xử lý lực đẩy lùi (Knockback)
	apply_knockback(knockback_dir)
	
	# Hiệu ứng chớp đỏ khi trúng đòn
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color(2.5, 0.3, 0.3), 0.1)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
		
	if current_health <= 0:
		die()


func apply_knockback(dir: Vector2) -> void:
	knockback_timer = 0.25
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	velocity = dir.normalized() * 250.0


func is_player(node: Node) -> bool:
	return node.is_in_group("player") or node.name == "PlayerController" or node.name.begins_with("Player")


## Tự động kích hoạt rơi xu khi bất kỳ quái vật nào chết
func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)

	# Rơi tiền Geo dựa trên cấu hình Tier hoặc Custom
	if loot_tier == GeoDropHelper.EnemyTier.CUSTOM:
		GeoDropHelper.drop_geo(global_position, get_parent(), min_drop_coins, max_drop_coins, chance_5_geo, chance_25_geo)
	else:
		GeoDropHelper.drop_from_tier(global_position, get_parent(), loot_tier)

	# Ghi nhận hạ gục vào Sổ tay thợ săn (Hunter's Journal)
	var j_id = enemy_journal_id
	if j_id == "":
		j_id = _infer_journal_id()
	if j_id != "" and SaveManager.instance:
		SaveManager.instance.record_enemy_kill(j_id)

	_on_death_animation()


func _on_death_animation() -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("die"):
			animated_sprite.play("die")
		elif animated_sprite.sprite_frames.has_animation("death"):
			animated_sprite.play("death")
	await get_tree().create_timer(1.0).timeout
	queue_free()


func _infer_journal_id() -> String:
	var n = name.to_lower()
	var s_name = ""
	var scr = get_script()
	if scr:
		s_name = scr.resource_path.get_file().to_lower()
	var full = n + " " + s_name
	if "crawlid" in full:
		return "crawlid"
	elif "vengefly" in full or "fly" in full:
		return "vengefly"
	elif "aspid" in full:
		return "aspid_hunter"
	elif "belfly" in full:
		return "belfly"
	elif "tiktik" in full:
		return "tiktik"
	elif "moss" in full:
		return "mosscreep"
	elif "sentry" in full:
		return "winged_sentry"
	elif "baldur" in full:
		return "baldur"
	elif "bug" in full or "husk" in full:
		return "wandering_husk"
	elif "nightmare" in full or "grimm" in full:
		return "nightmare_king"
	elif "soul_master" in full or "soul" in full or "mage" in full:
		return "mage_lord"
	elif "shade" in full:
		return "shade"
	return ""
