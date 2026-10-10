class_name MantisWarriorEnemy
extends BaseEnemy

@export var dash_speed: float = 240.0
@export var attack_range: float = 140.0
var direction: float = 1.0
var is_dashing: bool = false
var dash_cooldown: float = 0.0
var player: CharacterBody2D = null

func _on_enemy_ready() -> void:
	max_health = 7
	current_health = max_health
	damage = 1
	loot_tier = GeoDropHelper.EnemyTier.ELITE

func _physics_process(delta: float) -> void:
	if is_dead: return
	if not is_on_floor(): velocity.y += 980.0 * delta
	else: velocity.y = 0.0
	if dash_cooldown > 0.0: dash_cooldown -= delta
	
	if not player or not is_instance_valid(player):
		var p = get_tree().get_nodes_in_group("player")
		if p.size() > 0: player = p[0]
		
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		direction = 1.0 if player.global_position.x > global_position.x else -1.0
		if animated_sprite: animated_sprite.flip_h = (direction < 0)
		
		if dist <= attack_range and dash_cooldown <= 0.0 and not is_dashing:
			_perform_dash_slash()
		elif not is_dashing:
			velocity.x = 0.0
	else:
		velocity.x = 0.0
		
	move_and_slide()

func _perform_dash_slash() -> void:
	is_dashing = true
	dash_cooldown = 2.2
	if animated_sprite and animated_sprite.sprite_frames.has_animation("dash"):
		animated_sprite.play("dash")
		
	var tw = create_tween()
	var target_x = global_position.x + direction * 160.0
	tw.tween_property(self, "global_position:x", target_x, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	if is_dead or not is_inside_tree(): return
	
	if animated_sprite and animated_sprite.sprite_frames.has_animation("slash"):
		animated_sprite.play("slash")
	await get_tree().create_timer(0.4).timeout
	is_dashing = false
	if animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")
