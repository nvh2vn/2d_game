extends Area2D
class_name ShadeVessel

signal shade_recovered(geo_amount: int)

@export_group("Cocoon Settings")
@export var hp: int = 1
@export var stored_geo: int = 0

@export_group("Assets & Visuals")
@export var cocoon_texture: Texture2D = preload("res://assets/art/cocoon.png")
@export var break_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Player/soulhit.mp3")

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var sfx_player: AudioStreamPlayer2D = get_node_or_null("SFXPlayer")

var start_pos: Vector2 = Vector2.ZERO
var is_broken: bool = false

func _ready() -> void:
	add_to_group("cocoon")
	add_to_group("shade")
	add_to_group("enemies")
	
	collision_layer = 255
	collision_mask = 255
	monitoring = true
	monitorable = true
	
	if start_pos == Vector2.ZERO:
		start_pos = global_position
		
	_setup_nodes_if_missing()
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _setup_nodes_if_missing() -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		if cocoon_texture:
			sprite.texture = cocoon_texture
		else:
			sprite.texture = load("res://assets/art/cocoon.png")
		sprite.scale = Vector2(0.35, 0.35)
		add_child(sprite)
		
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var shape = CapsuleShape2D.new()
		shape.radius = 24.0
		shape.height = 70.0
		collision_shape.shape = shape
		add_child(collision_shape)
		
	if sfx_player == null:
		sfx_player = AudioStreamPlayer2D.new()
		sfx_player.name = "SFXPlayer"
		sfx_player.bus = &"SFX"
		add_child(sfx_player)

func setup_shade(geo_to_store: int, pos: Vector2) -> void:
	setup_cocoon(geo_to_store, pos)

func setup_cocoon(geo_to_store: int, pos: Vector2) -> void:
	stored_geo = geo_to_store
	global_position = pos
	start_pos = pos

func _on_area_entered(area: Area2D) -> void:
	if is_broken:
		return
	var parent = area.get_parent()
	if area.name.contains("Attack") or (parent and (parent.is_in_group("player") or parent.has_method("trigger_hitstop"))):
		var dir = Vector2.RIGHT
		if parent and "current_attack_dir" in parent:
			dir = parent.current_attack_dir
		take_damage(1, dir)

func _on_body_entered(body: Node2D) -> void:
	if is_broken:
		return
	if body.name.contains("Attack") or body.is_in_group("player"):
		pass

func take_damage(amount: int, attack_dir: Vector2 = Vector2.ZERO) -> void:
	if is_broken:
		return
		
	hp -= amount
	
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(3.0, 3.0, 3.5, 1.0), 0.05)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.08)
		
		var shake_offset = (attack_dir * 6.0) if attack_dir != Vector2.ZERO else Vector2(randf_range(-4, 4), -4)
		sprite.position = shake_offset
		var tw_pos = create_tween()
		tw_pos.tween_property(sprite, "position", Vector2.ZERO, 0.1)
		
	if hp <= 0:
		break_cocoon()

func break_cocoon() -> void:
	if is_broken:
		return
	is_broken = true
	
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p):
			if p.has_method("add_geo"):
				p.add_geo(stored_geo)
			elif "geo_amount" in p:
				p.geo_amount += stored_geo
				if p.has_method("update_geo_hud"):
					p.update_geo_hud()
					
			if p.has_method("restore_max_silk"):
				p.restore_max_silk()
				
	SaveManager.clear_shade()
	shade_recovered.emit(stored_geo)
	
	if break_sfx and sfx_player:
		sfx_player.stream = break_sfx
		sfx_player.play()
		
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "scale", Vector2(0.45, 0.45), 0.06)
		tw.parallel().tween_property(sprite, "modulate", Color(3.5, 3.5, 3.5, 1.0), 0.06)
		tw.tween_property(sprite, "scale", Vector2(0.55, 0.55), 0.1)
		tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.1)
		await tw.finished
		
	queue_free()

func recover_shade() -> void:
	break_cocoon()
