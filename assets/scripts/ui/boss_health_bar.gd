extends CanvasLayer

@onready var container: Control = get_node_or_null("%Container")
@onready var boss_name_label: Label = get_node_or_null("%BossNameLabel")
@onready var health_bar: ProgressBar = get_node_or_null("%HealthBar")
@onready var damage_bar: ProgressBar = get_node_or_null("%DamageBar")

var max_hp: int = 40
var current_hp: int = 40
var boss_title: String = "NIGHTMARE KING"
var is_active: bool = false


func _ready() -> void:
	_resolve_nodes()
	if not is_active:
		if container:
			container.visible = false
			container.modulate.a = 0.0
	else:
		_apply_setup()


func _resolve_nodes() -> void:
	if not container:
		container = get_node_or_null("Container")
	if not boss_name_label:
		boss_name_label = find_child("BossNameLabel", true, false)
	if not health_bar:
		health_bar = find_child("HealthBar", true, false)
	if not damage_bar:
		damage_bar = find_child("DamageBar", true, false)


func setup_boss(p_boss_name: String, p_max_health: int) -> void:
	boss_title = p_boss_name
	max_hp = p_max_health
	current_hp = p_max_health
	is_active = true
	
	_resolve_nodes()
	if is_inside_tree() and is_node_ready():
		_apply_setup()


func _apply_setup() -> void:
	if boss_name_label:
		boss_name_label.text = boss_title
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = max_hp
	if damage_bar:
		damage_bar.max_value = max_hp
		damage_bar.value = max_hp
		
	if container:
		container.visible = true
		container.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(container, "modulate:a", 1.0, 0.8)


func update_health(new_health: int) -> void:
	current_hp = clampi(new_health, 0, max_hp)
	_resolve_nodes()
	if health_bar:
		var tw_hp = create_tween()
		tw_hp.tween_property(health_bar, "value", float(current_hp), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if damage_bar:
		var tw_dmg = create_tween()
		tw_dmg.tween_interval(0.3)
		tw_dmg.tween_property(damage_bar, "value", float(current_hp), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func hide_bar() -> void:
	_resolve_nodes()
	if container:
		var tw = create_tween()
		tw.tween_property(container, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func(): 
			if is_instance_valid(container):
				container.visible = false
		)
