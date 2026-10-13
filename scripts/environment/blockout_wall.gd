@tool
extends StaticBody2D
class_name BlockoutWall

@export var size: Vector2 = Vector2(200, 40):
	set(val):
		size = val
		_update_blockout_size()

@export var fill_color: Color = Color(0.2, 0.25, 0.35, 1.0):
	set(val):
		fill_color = val
		if fill_rect:
			fill_rect.color = fill_color

@export var border_color: Color = Color(0.8, 0.88, 1.0, 1.0):
	set(val):
		border_color = val
		if border_rect:
			border_rect.border_color = border_color

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var fill_rect: ColorRect = $VisualFill
@onready var border_rect: ReferenceRect = $VisualBorder


func _ready() -> void:
	_update_blockout_size()
	if fill_rect and not fill_rect.resized.is_connected(_on_fill_rect_resized):
		fill_rect.resized.connect(_on_fill_rect_resized)


func _on_fill_rect_resized() -> void:
	if fill_rect:
		size = fill_rect.size
		_update_blockout_size()


func _update_blockout_size() -> void:
	var half_w = size.x * 0.5
	var half_h = size.y * 0.5
	
	if collision_shape:
		if collision_shape.shape == null or not (collision_shape.shape is RectangleShape2D):
			collision_shape.shape = RectangleShape2D.new()
		(collision_shape.shape as RectangleShape2D).size = size
		collision_shape.position = Vector2.ZERO
		
	if fill_rect:
		fill_rect.size = size
		fill_rect.position = Vector2(-half_w, -half_h)
		fill_rect.color = fill_color
		
	if border_rect:
		border_rect.size = size
		border_rect.position = Vector2(-half_w, -half_h)
		border_rect.border_color = border_color
