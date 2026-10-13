extends Area2D

@export var is_main_target: bool = false
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var center_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var reform_pos: Vector2 = Vector2.ZERO
var is_reforming: bool = false
var elapsed: float = 0.0
var flit_timer: float = 0.0
var boss_ref: Node = null


func _ready() -> void:
	if animated_sprite:
		animated_sprite.play("fly")
	if is_main_target:
		modulate = Color(1.3, 0.4, 0.4)
		scale = Vector2(0.42, 0.42)
	else:
		scale = Vector2(0.3, 0.3)
	
	area_entered.connect(_on_area_entered)


func setup(p_center: Vector2, p_is_main: bool, p_boss: Node) -> void:
	center_pos = p_center
	is_main_target = p_is_main
	boss_ref = p_boss
	global_position = center_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	_pick_new_flit_target()


func _pick_new_flit_target() -> void:
	flit_timer = randf_range(0.2, 0.5)
	var radius = 220.0
	target_pos = center_pos + Vector2(randf_range(-radius, radius), randf_range(-radius * 0.7, radius * 0.5))


func start_reforming(p_reform_pos: Vector2) -> void:
	is_reforming = true
	reform_pos = p_reform_pos


func _physics_process(delta: float) -> void:
	elapsed += delta
	if is_reforming:
		var dir = (reform_pos - global_position)
		if dir.length() < 15.0:
			queue_free()
			return
		global_position += dir.normalized() * 550.0 * delta
		if animated_sprite:
			animated_sprite.flip_h = (dir.x > 0)
		return
		
	flit_timer -= delta
	if flit_timer <= 0.0:
		_pick_new_flit_target()
		
	var to_target = (target_pos - global_position)
	velocity = velocity.lerp(to_target.normalized() * 300.0, 8.0 * delta)
	global_position += velocity * delta
	
	if animated_sprite and abs(velocity.x) > 20.0:
		animated_sprite.flip_h = (velocity.x > 0)


func _on_area_entered(area: Area2D) -> void:
	if not is_main_target or is_reforming:
		return
	if area.name == "AttackArea" or area.is_in_group("player_attacks"):
		# Người chơi chém trúng con dơi chính của Grimm -> gây 1 damage lên Grimm
		if boss_ref and is_instance_valid(boss_ref) and boss_ref.has_method("take_damage_during_stagger"):
			boss_ref.take_damage_during_stagger(1)
		# Chớp trắng khi trúng đòn
		var tw = create_tween()
		tw.tween_property(self, "modulate", Color(3.0, 3.0, 3.0), 0.08)
		tw.tween_property(self, "modulate", Color(1.3, 0.4, 0.4), 0.08)
