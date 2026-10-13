extends Area2D
class_name TukNPC

signal shop_opened()
signal shop_closed()

@export var npc_name: String = "Tuk (Nhà Thu Gom)"
@export var shop_menu_scene: PackedScene = preload("res://scenes/ui/shop_menu.tscn")

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var interact_prompt: Control = get_node_or_null("InteractPrompt")
@onready var talk_position: Marker2D = get_node_or_null("TalkPosition")

var is_player_in_range: bool = false
var current_player: Node2D = null

# Animation variables for cropped frames
var anim_frames: Array[Texture2D] = []
var current_frame_idx: int = 0
var anim_timer: float = 0.0
@export var anim_speed: float = 0.25 # seconds per frame

func _ready() -> void:
	add_to_group("npcs")
	collision_layer = 4
	collision_mask = 255
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	_load_tuk_animation_frames()
	
	if interact_prompt:
		interact_prompt.visible = false
		
	_setup_nodes_if_missing()

func _load_tuk_animation_frames() -> void:
	anim_frames.clear()
	for i in range(5):
		var path = "res://assets/sprites/npc/tuk/tuk_frame_" + str(i) + ".png"
		if ResourceLoader.exists(path):
			var tex = load(path) as Texture2D
			if tex:
				anim_frames.append(tex)
				
	# Fallback if cropped frames haven't imported yet
	if anim_frames.size() == 0:
		var main_tex = load("res://assets/sprites/npc/PC _ Computer - Hollow Knight - Non-Playable Characters - Tuk.png") as Texture2D
		if main_tex:
			anim_frames.append(main_tex)

func _process(delta: float) -> void:
	if anim_frames.size() > 1 and sprite != null:
		anim_timer += delta
		if anim_timer >= anim_speed:
			anim_timer = 0.0
			current_frame_idx = (current_frame_idx + 1) % anim_frames.size()
			sprite.texture = anim_frames[current_frame_idx]

func _setup_nodes_if_missing() -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		if anim_frames.size() > 0:
			sprite.texture = anim_frames[0]
		sprite.scale = Vector2(0.22, 0.22)
		add_child(sprite)
	else:
		sprite.scale = Vector2(0.22, 0.22)
		sprite.region_enabled = false
		if anim_frames.size() > 0:
			sprite.texture = anim_frames[0]
		
	if interact_prompt == null:
		var prompt_lbl = Label.new()
		prompt_lbl.name = "InteractPrompt"
		prompt_lbl.text = "[E] Mua hàng từ Tuk"
		prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_lbl.position = Vector2(-70, -80)
		prompt_lbl.visible = false
		add_child(prompt_lbl)
		interact_prompt = prompt_lbl

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_in_range or not is_instance_valid(current_player):
		return
		
	var is_interact: bool = event.is_action_pressed("ui_up") or event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and (event.keycode in [KEY_E, KEY_UP, KEY_W]))
	if is_interact:
		_open_shop_menu()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		current_player = body
		_set_in_range(true)

func _on_body_exited(body: Node2D) -> void:
	if body == current_player:
		_set_in_range(false)

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent and _is_player(parent):
		current_player = parent
		_set_in_range(true)

func _on_area_exited(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent == current_player:
		_set_in_range(false)

func _is_player(node: Node2D) -> bool:
	return node.is_in_group("player") or node.name.begins_with("Player") or node.has_method("trigger_hazard_reset")

func _set_in_range(in_range: bool) -> void:
	is_player_in_range = in_range
	if interact_prompt:
		interact_prompt.visible = in_range
		if in_range:
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			interact_prompt.scale = Vector2(0.5, 0.5)
			tw.tween_property(interact_prompt, "scale", Vector2.ONE, 0.15)
	
	if in_range:
		TouchControls.show_interact(get_tree(), "tuk_shop")
	else:
		TouchControls.hide_interact(get_tree())

func _open_shop_menu() -> void:
	var existing_menu = get_tree().current_scene.find_child("ShopMenu", true, false)
	if existing_menu:
		return
		
	if shop_menu_scene:
		TouchControls.hide_interact(get_tree())
		var menu_inst = shop_menu_scene.instantiate()
		get_tree().current_scene.add_child(menu_inst)
		menu_inst.tree_exited.connect(_on_shop_menu_closed)
		if menu_inst.has_method("open_shop"):
			menu_inst.open_shop(current_player, npc_name)
		shop_opened.emit()

func _on_shop_menu_closed() -> void:
	shop_closed.emit()
	if is_player_in_range:
		TouchControls.show_interact(get_tree(), "tuk_shop")
