extends CanvasLayer
class_name ShopMenu

signal item_purchased(item_id: String, item_name: String, price: int)

@onready var title_label: Label = get_node_or_null("%ShopTitle")
@onready var geo_label: Label = get_node_or_null("%GeoBalance")
@onready var item_list_container: VBoxContainer = get_node_or_null("%ItemList")
@onready var close_button: Button = get_node_or_null("%CloseButton")
@onready var info_description: Label = get_node_or_null("%InfoDescription")

var current_player: Node2D = null
var npc_name_str: String = "Tuk (Nhà Thu Gom)"
var purchased_items: Dictionary = {}
const SAVE_PATH: String = "user://shop_data.cfg"

var shop_items: Array[Dictionary] = [
	{
		"id": "simple_key",
		"name": "Chìa Khóa Đơn (Simple Key)",
		"price": 150,
		"description": "Dùng để mở các ổ khóa cổ hoặc cửa sắt bí mật bị khóa trong các khu vực.",
		"icon": "res://assets/art/Inventory & UI/Spell & Item prompts/kings_brand_prompt.png",
		"one_time": true
	},
	{
		"id": "forgotten_map",
		"name": "Bản Đồ Cổ Khu Vực",
		"price": 100,
		"description": "Mở khóa góc nhìn bản đồ vị trí và các tuyến đường trong khu vực.",
		"icon": "res://assets/art/Inventory & UI/Spell & Item prompts/Map_prompt.png",
		"one_time": true
	},
	{
		"id": "collectors_map",
		"name": "Bản Đồ Nhà Thu Gom",
		"price": 180,
		"description": "Bản đồ đánh dấu các điểm rương kho báu và vật phẩm ẩn của Tuk.",
		"icon": "res://assets/art/Inventory & UI/Spell & Item prompts/collectors_map_prompt.png",
		"one_time": true
	},
	{
		"id": "rancid_egg",
		"name": "Trứng Thối (Rancid Egg)",
		"price": 80,
		"description": "Món đồ ưa thích được Tuk thu gom dưới các cống ngầm. Có giá trị trao đổi đặc biệt.",
		"icon": "res://assets/art/Inventory & UI/Spell & Item prompts/dreamer_mask_prompt.png",
		"one_time": false
	},
	{
		"id": "mask_shard",
		"name": "Mảnh Mặt Nạ (Mask Shard)",
		"price": 250,
		"description": "Mảnh cổ vật tích tụ sức sống. Thu thập đủ 4 mảnh để gia tăng tối đa 1 HP.",
		"icon": "res://assets/art/Inventory & UI/Spell & Item prompts/blessing_prompt.png",
		"one_time": true
	}
]

func _ready() -> void:
	layer = 110
	load_shop_purchases()
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

func open_shop(player_ref: Node2D = null, npc_title: String = "Tuk (Nhà Thu Gom)") -> void:
	current_player = player_ref
	npc_name_str = npc_title
	
	if is_instance_valid(current_player):
		if "is_sitting" in current_player:
			current_player.is_sitting = true
		if "velocity" in current_player:
			current_player.velocity = Vector2.ZERO
			
	if title_label:
		title_label.text = "🛒 CỬA HÀNG - " + npc_title.to_upper()
		
	update_geo_display()
	populate_shop_items()

func update_geo_display() -> void:
	var current_geo = 0
	if is_instance_valid(current_player):
		if "geo_amount" in current_player:
			current_geo = current_player.geo_amount
		elif "geo" in current_player:
			current_geo = current_player.geo
			
	if geo_label:
		geo_label.text = "💰 Túi Geo: " + str(current_geo) + " 🪙"

func populate_shop_items() -> void:
	if item_list_container == null:
		return
		
	for c in item_list_container.get_children():
		c.queue_free()
		
	var player_geo = _get_player_geo()

	for item in shop_items:
		var item_id = item["id"]
		var is_purchased = item["one_time"] and purchased_items.get(item_id, false)
		
		var item_row = HBoxContainer.new()
		item_row.custom_minimum_size = Vector2(0, 56)
		
		# Icon
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(48, 48)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_tex = load(item["icon"])
		if icon_tex:
			icon_rect.texture = icon_tex
		item_row.add_child(icon_rect)
		
		# Item Details Label
		var detail_box = VBoxContainer.new()
		detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var name_lbl = Label.new()
		name_lbl.text = item["name"]
		name_lbl.add_theme_font_size_override("font_size", 16)
		detail_box.add_child(name_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = item["description"]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		detail_box.add_child(desc_lbl)
		
		item_row.add_child(detail_box)
		
		# Buy Button
		var buy_btn = Button.new()
		buy_btn.custom_minimum_size = Vector2(140, 44)
		
		if is_purchased:
			buy_btn.text = "✓ Đã Mua"
			buy_btn.disabled = true
		else:
			buy_btn.text = "Mua (" + str(item["price"]) + " 🪙)"
			if player_geo < item["price"]:
				buy_btn.disabled = true
				buy_btn.text = "Thiếu Geo (" + str(item["price"]) + " 🪙)"
			else:
				buy_btn.pressed.connect(_on_item_buy_pressed.bind(item))
				
		item_row.add_child(buy_btn)
		item_list_container.add_child(item_row)

func _get_player_geo() -> int:
	if is_instance_valid(current_player):
		if "geo_amount" in current_player:
			return current_player.geo_amount
		elif "geo" in current_player:
			return current_player.geo
	return 0

func _deduct_player_geo(amount: int) -> bool:
	if is_instance_valid(current_player):
		if "geo_amount" in current_player:
			if current_player.geo_amount >= amount:
				current_player.geo_amount -= amount
				if current_player.has_method("update_geo_hud"):
					current_player.update_geo_hud()
				return true
		elif "geo" in current_player:
			if current_player.geo >= amount:
				current_player.geo -= amount
				return true
	return false

func _on_item_buy_pressed(item: Dictionary) -> void:
	var price = item["price"]
	var item_id = item["id"]
	
	if _deduct_player_geo(price):
		if item["one_time"]:
			purchased_items[item_id] = true
			save_shop_purchases()
			
		# Granular item unlock handling
		_grant_item_to_player(item_id, item["name"])
		
		item_purchased.emit(item_id, item["name"], price)
		
		if info_description:
			info_description.text = "✨ Đã mua thành công: " + item["name"] + "!"
			
		update_geo_display()
		populate_shop_items()

func _grant_item_to_player(item_id: String, item_name: String) -> void:
	if not is_instance_valid(current_player):
		return
		
	if "inventory" in current_player:
		if current_player.inventory is Array:
			current_player.inventory.append(item_id)
			
	if item_id == "mask_shard" and "max_health" in current_player:
		current_player.max_health += 1
		current_player.current_health = current_player.max_health
		if current_player.has_method("update_health_hud"):
			current_player.update_health_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	if is_instance_valid(current_player):
		if "is_sitting" in current_player:
			current_player.is_sitting = false
	queue_free()

func save_shop_purchases() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("shop", "purchased", purchased_items)
	config.save(SAVE_PATH)

func load_shop_purchases() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		purchased_items = config.get_value("shop", "purchased", {})
