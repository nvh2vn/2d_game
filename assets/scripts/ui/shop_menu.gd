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

static var active_instance: ShopMenu = null

func _enter_tree() -> void:
	active_instance = self

func _exit_tree() -> void:
	if active_instance == self:
		active_instance = null

var shop_items: Array[Dictionary] = [
	{
		"id": "simple_key",
		"name": "Chìa Khóa Đơn (Simple Key)",
		"price": 150,
		"description": "Dùng để mở các ổ khóa cổ hoặc cửa sắt bí mật bị khóa trong các khu vực.",
		"icon": "res://assets/art/Inventory & UI/inv_item__00014_graveyard_key.png",
		"category": "CHÌA KHÓA",
		"one_time": true
	},
	{
		"id": "map_tuk",
		"name": "Bản Đồ Cổ Khu Vực (Map)",
		"price": 100,
		"description": "Tấm bản đồ ghi chép mạng lưới địa hình và các ngóc ngách bí mật dưới cống ngầm của Tuk.",
		"icon": "res://assets/art/Inventory & UI/inv_item__0006_area_map.png",
		"category": "BẢN ĐỒ",
		"one_time": true
	},
	{
		"id": "rancid_egg",
		"name": "Trứng Thối (Rancid Egg)",
		"price": 80,
		"description": "Món đồ ưa thích được Tuk thu gom dưới các cống ngầm. Có giá trị trao đổi đặc biệt.",
		"icon": "res://assets/art/Inventory & UI/inv_rancid_egg.png",
		"category": "VẬT PHẨM",
		"one_time": false
	},
	{
		"id": "mask_shard",
		"name": "Mảnh Mặt Nạ (Mask Shard)",
		"price": 250,
		"description": "Mảnh cổ vật tích tụ sức sống. Thu thập đủ 4 mảnh để gia tăng tối đa 1 HP.",
		"icon": "res://assets/art/Inventory & UI/Spell & Item prompts/blessing_prompt.png",
		"category": "CỔ VẬT NÂNG CẤP",
		"one_time": true
	}
]

const COLOR_NORMAL := Color(0.66, 0.67, 0.7, 0.95)   # #a8abb3 xám mờ / bạc tối
const COLOR_HOVER := Color(1.0, 1.0, 1.0, 1.0)       # #ffffff trắng sáng

var hover_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/UI/ui_change_selection.mp3")
var confirm_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/UI/ui_button_confirm.mp3")
var trajan_font: FontFile = preload("res://assets/art/2d/silksong_full/TrajanPro.ttf")
var active_hovered_btn: Button = null

func _ready() -> void:
	layer = 110
	load_shop_purchases()
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		_setup_button_hover(close_button)

func open_shop(player_ref: Node2D = null, npc_title: String = "Tuk (Nhà Thu Gom)") -> void:
	current_player = player_ref
	npc_name_str = npc_title
	
	if is_instance_valid(current_player):
		if "is_sitting" in current_player:
			current_player.is_sitting = true
		if "velocity" in current_player:
			current_player.velocity = Vector2.ZERO
			
	if title_label:
		title_label.text = "SHOP - " + npc_title.to_upper()
		
	load_shop_purchases()
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
		geo_label.text = "%d GEO" % current_geo

func populate_shop_items() -> void:
	if item_list_container == null:
		return
		
	for c in item_list_container.get_children():
		c.queue_free()
		
	var player_geo = _get_player_geo()

	var card_box = StyleBoxFlat.new()
	card_box.bg_color = Color(0.04, 0.05, 0.08, 0.5)
	card_box.border_width_left = 1; card_box.border_width_top = 1; card_box.border_width_right = 1; card_box.border_width_bottom = 1
	card_box.border_color = Color(0.35, 0.38, 0.44, 0.6)
	card_box.corner_radius_top_left = 4; card_box.corner_radius_top_right = 4; card_box.corner_radius_bottom_right = 4; card_box.corner_radius_bottom_left = 4
	card_box.content_margin_left = 12; card_box.content_margin_right = 12; card_box.content_margin_top = 8; card_box.content_margin_bottom = 8

	var btn_norm = StyleBoxFlat.new()
	btn_norm.bg_color = Color(0.08, 0.1, 0.14, 0.7)
	btn_norm.border_width_left = 1; btn_norm.border_width_top = 1; btn_norm.border_width_right = 1; btn_norm.border_width_bottom = 1
	btn_norm.border_color = Color(0.4, 0.44, 0.52, 0.6)
	btn_norm.corner_radius_top_left = 4; btn_norm.corner_radius_top_right = 4; btn_norm.corner_radius_bottom_right = 4; btn_norm.corner_radius_bottom_left = 4
	btn_norm.content_margin_left = 12; btn_norm.content_margin_right = 12; btn_norm.content_margin_top = 6; btn_norm.content_margin_bottom = 6

	var btn_hov = StyleBoxFlat.new()
	btn_hov.bg_color = Color(0.14, 0.16, 0.22, 0.9)
	btn_hov.border_width_left = 1; btn_hov.border_width_top = 1; btn_hov.border_width_right = 1; btn_hov.border_width_bottom = 1
	btn_hov.border_color = Color(1.0, 1.0, 1.0, 0.95)
	btn_hov.corner_radius_top_left = 4; btn_hov.corner_radius_top_right = 4; btn_hov.corner_radius_bottom_right = 4; btn_hov.corner_radius_bottom_left = 4
	btn_hov.content_margin_left = 12; btn_hov.content_margin_right = 12; btn_hov.content_margin_top = 6; btn_hov.content_margin_bottom = 6

	var btn_dis = StyleBoxFlat.new()
	btn_dis.bg_color = Color(0.03, 0.03, 0.05, 0.4)
	btn_dis.border_width_left = 1; btn_dis.border_width_top = 1; btn_dis.border_width_right = 1; btn_dis.border_width_bottom = 1
	btn_dis.border_color = Color(0.25, 0.28, 0.32, 0.3)
	btn_dis.corner_radius_top_left = 4; btn_dis.corner_radius_top_right = 4; btn_dis.corner_radius_bottom_right = 4; btn_dis.corner_radius_bottom_left = 4
	btn_dis.content_margin_left = 12; btn_dis.content_margin_right = 12; btn_dis.content_margin_top = 6; btn_dis.content_margin_bottom = 6

	for item in shop_items:
		var item_id = item["id"]
		var is_purchased = item["one_time"] and purchased_items.get(item_id, false)
		
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel", card_box.duplicate())
		
		var item_row = HBoxContainer.new()
		item_row.custom_minimum_size = Vector2(0, 52)
		item_row.add_theme_constant_override("separation", 12)
		
		# Icon
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_tex = load(item["icon"])
		if icon_tex:
			icon_rect.texture = icon_tex
		item_row.add_child(icon_rect)
		
		# Item Details Label
		var detail_box = VBoxContainer.new()
		detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_box.add_theme_constant_override("separation", 2)
		
		var name_lbl = Label.new()
		name_lbl.text = item["name"].to_upper()
		name_lbl.add_theme_font_override("font", trajan_font)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98, 1))
		detail_box.add_child(name_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = item["description"]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.66, 0.68, 0.74, 0.85))
		detail_box.add_child(desc_lbl)
		
		item_row.add_child(detail_box)
		
		# Buy Button
		var buy_btn = Button.new()
		buy_btn.custom_minimum_size = Vector2(160, 40)
		buy_btn.add_theme_font_override("font", trajan_font)
		buy_btn.add_theme_font_size_override("font_size", 13)
		buy_btn.add_theme_stylebox_override("normal", btn_norm)
		buy_btn.add_theme_stylebox_override("hover", btn_hov)
		buy_btn.add_theme_stylebox_override("focus", btn_hov)
		buy_btn.add_theme_stylebox_override("pressed", btn_hov)
		buy_btn.add_theme_stylebox_override("disabled", btn_dis)
		
		buy_btn.add_theme_color_override("font_color", COLOR_NORMAL)
		buy_btn.add_theme_color_override("font_hover_color", COLOR_HOVER)
		buy_btn.add_theme_color_override("font_focus_color", COLOR_HOVER)
		buy_btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.46, 0.5))
		
		if is_purchased:
			buy_btn.text = "PURCHASED"
			buy_btn.disabled = true
		else:
			if player_geo < item["price"]:
				buy_btn.disabled = true
				buy_btn.text = "%d GEO" % item["price"]
			else:
				buy_btn.text = "BUY (%d GEO)" % item["price"]
				buy_btn.pressed.connect(func():
					_play_sfx(confirm_sfx)
					_on_item_buy_pressed(item)
				)
				_setup_button_hover(buy_btn)
				
		item_row.add_child(buy_btn)
		card.add_child(item_row)
		item_list_container.add_child(card)


func _setup_button_hover(btn: Button) -> void:
	_ensure_button_pointers(btn)
	
	btn.mouse_entered.connect(func():
		if not btn.disabled:
			_set_button_highlight(btn, true)
	)
	btn.focus_entered.connect(func():
		if not btn.disabled:
			_set_button_highlight(btn, true)
	)
	btn.mouse_exited.connect(func():
		if not btn.has_focus():
			_set_button_highlight(btn, false)
	)
	btn.focus_exited.connect(func():
		_set_button_highlight(btn, false)
	)


func _ensure_button_pointers(btn: Button) -> void:
	var ptr_tex = load("res://assets/art/Inventory & UI/Pointers/main_menu_pointer_anim0000.png")
	
	var ptr_left: TextureRect = btn.get_node_or_null("PointerLeft")
	if not ptr_left and ptr_tex:
		ptr_left = TextureRect.new()
		ptr_left.name = "PointerLeft"
		ptr_left.layout_mode = 1
		ptr_left.anchors_preset = Control.PRESET_CENTER_LEFT
		ptr_left.anchor_top = 0.5
		ptr_left.anchor_bottom = 0.5
		ptr_left.offset_left = 4.0
		ptr_left.offset_top = -10.0
		ptr_left.offset_right = 24.0
		ptr_left.offset_bottom = 10.0
		ptr_left.grow_vertical = 2
		ptr_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ptr_left.texture = ptr_tex
		ptr_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ptr_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ptr_left.modulate = Color(1, 1, 1, 0.0)
		btn.add_child(ptr_left)
		
	var ptr_right: TextureRect = btn.get_node_or_null("PointerRight")
	if not ptr_right and ptr_tex:
		ptr_right = TextureRect.new()
		ptr_right.name = "PointerRight"
		ptr_right.layout_mode = 1
		ptr_right.anchors_preset = Control.PRESET_CENTER_RIGHT
		ptr_right.anchor_left = 1.0
		ptr_right.anchor_right = 1.0
		ptr_right.anchor_top = 0.5
		ptr_right.anchor_bottom = 0.5
		ptr_right.offset_left = -24.0
		ptr_right.offset_top = -10.0
		ptr_right.offset_right = -4.0
		ptr_right.offset_bottom = 10.0
		ptr_right.grow_horizontal = 0
		ptr_right.grow_vertical = 2
		ptr_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ptr_right.texture = ptr_tex
		ptr_right.flip_h = true
		ptr_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ptr_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ptr_right.modulate = Color(1, 1, 1, 0.0)
		btn.add_child(ptr_right)


func _set_button_highlight(btn: Button, active: bool) -> void:
	if not is_instance_valid(btn):
		return
		
	var ptr_left: TextureRect = btn.get_node_or_null("PointerLeft")
	var ptr_right: TextureRect = btn.get_node_or_null("PointerRight")
	
	if active:
		active_hovered_btn = btn
		_play_sfx(hover_sfx)
		
		btn.pivot_offset = btn.size * 0.5
		var tw = create_tween().set_parallel(true)
		tw.tween_property(btn, "theme_override_colors/font_color", COLOR_HOVER, 0.12)
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.12)
		
		if ptr_left:
			ptr_left.visible = true
			var tw_l = create_tween().set_parallel(true)
			tw_l.tween_property(ptr_left, "modulate:a", 1.0, 0.15)
			tw_l.tween_property(ptr_left, "position:x", 6.0, 0.15).from(0.0)
		if ptr_right:
			ptr_right.visible = true
			var tw_r = create_tween().set_parallel(true)
			tw_r.tween_property(ptr_right, "modulate:a", 1.0, 0.15)
			tw_r.tween_property(ptr_right, "position:x", btn.size.x - 26.0, 0.15).from(btn.size.x - 20.0)
	else:
		if active_hovered_btn == btn:
			active_hovered_btn = null
			
		btn.pivot_offset = btn.size * 0.5
		var tw = create_tween().set_parallel(true)
		tw.tween_property(btn, "theme_override_colors/font_color", COLOR_NORMAL, 0.15)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.15)
		
		if ptr_left:
			var tw_l = create_tween()
			tw_l.tween_property(ptr_left, "modulate:a", 0.0, 0.12)
		if ptr_right:
			var tw_r = create_tween()
			tw_r.tween_property(ptr_right, "modulate:a", 0.0, 0.12)


func _play_sfx(stream: AudioStream) -> void:
	if stream and is_inside_tree():
		var asp = AudioStreamPlayer.new()
		asp.stream = stream
		asp.bus = &"SFX"
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)

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
	# 1. Tìm thông tin chi tiết vật phẩm từ SaveManager registry hoặc shop_items
	var item_dict: Dictionary = {}
	if SaveManager.has_method("get_item_definition"):
		item_dict = SaveManager.get_item_definition(item_id)
	if item_dict.is_empty():
		for s_it in shop_items:
			if s_it.get("id", "") == item_id:
				item_dict = {
					"id": item_id,
					"name": s_it.get("name", item_name),
					"desc": s_it.get("description", ""),
					"icon": s_it.get("icon", ""),
					"category": s_it.get("category", "VẬT PHẨM")
				}
				break

	# 2. Thêm vào SaveManager tập trung
	if SaveManager.instance:
		if not item_dict.is_empty():
			SaveManager.instance.add_inventory_item(item_dict)
		else:
			SaveManager.instance.add_inventory_item(item_id)

	# 3. Hiệu ứng riêng của từng vật phẩm (Mảnh mặt nạ tăng 1 Max HP)
	if item_id == "mask_shard":
		if is_instance_valid(current_player) and "max_health" in current_player:
			current_player.max_health += 1
			current_player.current_health = current_player.max_health
			if current_player.has_method("update_health_hud"):
				current_player.update_health_hud()
			elif current_player.has_method("update_hud"):
				current_player.update_hud()
		if SaveManager.instance:
			var p_data = SaveManager.instance.save_data.get("player", {})
			p_data["max_health"] = p_data.get("max_health", 5) + 1
			p_data["current_health"] = p_data["max_health"]
			SaveManager.instance.save_data["player"] = p_data
			SaveManager.instance.save_to_disk()

	# 4. Đồng bộ player inventory nếu player đang tồn tại
	if is_instance_valid(current_player) and "inventory" in current_player:
		if SaveManager.instance:
			current_player.inventory = SaveManager.instance.get_inventory_items().duplicate()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	if is_instance_valid(current_player):
		if "is_sitting" in current_player:
			current_player.is_sitting = false
	queue_free()

## Xóa sạch toàn bộ dữ liệu mua hàng của Shop trên đĩa và trong bộ nhớ
static func reset_shop_state() -> void:
	var da = DirAccess.open("user://")
	if da and da.file_exists("shop_data.cfg"):
		da.remove("shop_data.cfg")
	if active_instance and is_instance_valid(active_instance):
		active_instance.purchased_items.clear()
		if active_instance.is_inside_tree():
			active_instance.populate_shop_items()

func save_shop_purchases() -> void:
	# 1. Đồng bộ sang SaveManager tập trung nếu có
	if SaveManager.instance:
		SaveManager.instance.save_data["shop_purchases"] = purchased_items.duplicate()
		SaveManager.instance.save_to_disk()
		
	# 2. Ghi ra shop_data.cfg
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("shop", "purchased", purchased_items)
	config.save(SAVE_PATH)

func load_shop_purchases() -> void:
	# 1. Ưu tiên nạp từ SaveManager tập trung nếu có
	if SaveManager.instance and SaveManager.instance.save_data.has("shop_purchases"):
		var sp = SaveManager.instance.save_data["shop_purchases"]
		if typeof(sp) == TYPE_DICTIONARY:
			purchased_items = sp.duplicate()
			return
		elif typeof(sp) == TYPE_ARRAY:
			purchased_items.clear()
			for item_id in sp:
				purchased_items[item_id] = true
			return
			
	# 2. Đọc từ file shop_data.cfg
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		purchased_items = config.get_value("shop", "purchased", {})
	else:
		purchased_items = {}
