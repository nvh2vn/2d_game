class_name BreakableWall
extends StaticBody2D

@export_group("Wall Health & Stages")
@export var max_hits: int = 2
@export var texture_intact: Texture2D = preload("res://assets/art/map_1/King_s Pass/tut_wall_l_0006_03.png")
@export var texture_cracked: Texture2D = preload("res://assets/art/map_1/King_s Pass/tut_wall_l_0005_04.png")

var current_hits: int = 0
var is_broken: bool = false
var _hit_cooldown: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var debris_particles: CPUParticles2D = get_node_or_null("CPUParticles2D")


func _ready() -> void:
	add_to_group("destructible")
	add_to_group("enemies") # Để tương thích với hệ thống quét trúng đòn của Player
	
	if sprite and texture_intact and sprite.texture == null:
		sprite.texture = texture_intact
	
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		hurtbox.body_entered.connect(_on_hurtbox_body_entered)


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_broken:
		return
	
	if area.name == "AttackArea" or area.is_in_group("player_attacks") or area.name.begins_with("Dart") or area.is_in_group("projectiles"):
		take_hit()


func _on_hurtbox_body_entered(body: Node) -> void:
	if is_broken:
		return
	if body.is_in_group("player_attacks") or body.is_in_group("projectiles"):
		take_hit()


## Hàm nhận sát thương chuẩn chung
func take_damage(amount: int = 1, _knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_broken:
		return
	take_hit(amount)


func take_hit(amount: int = 1) -> void:
	if is_broken or _hit_cooldown:
		return
		
	_hit_cooldown = true
	get_tree().create_timer(0.12).timeout.connect(func(): _hit_cooldown = false)
		
	current_hits += amount
	
	# Đổi texture sang trạng thái nứt vỡ nhiều hơn
	if current_hits >= 1 and current_hits < max_hits and texture_cracked and sprite:
		sprite.texture = texture_cracked
	
	# Hiệu ứng rung lắc bức tường
	var tween = create_tween()
	var orig_pos = sprite.position
	tween.tween_property(sprite, "position", orig_pos + Vector2(randf_range(-6, 6), 0), 0.04)
	tween.tween_property(sprite, "position", orig_pos, 0.04)
	
	# Hiệu ứng chớp trắng khi bị chém
	tween.parallel().tween_property(sprite, "modulate", Color(2.5, 2.5, 2.5), 0.06)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.06)
	
	# Phun một ít bụi đá nhỏ
	if debris_particles:
		debris_particles.amount = 10
		debris_particles.restart()
		debris_particles.emitting = true
	
	# Kiểm tra nếu đã đủ số lần chém để vỡ hoàn toàn
	if current_hits >= max_hits:
		break_wall()


func break_wall() -> void:
	is_broken = true
	
	# Tắt va chạm để mở đường đi cho Player
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	
	# Ẩn sprite bức tường
	if sprite:
		sprite.visible = false
	
	# Phun tung tóe mảnh đá lớn
	if debris_particles:
		debris_particles.amount = 35
		debris_particles.explosiveness = 1.0
		debris_particles.restart()
		debris_particles.emitting = true
		await get_tree().create_timer(0.8).timeout
	
	queue_free()
