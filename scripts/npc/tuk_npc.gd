extends Area2D
class_name TukNPC

## NPC Tuk (Nhà Thu Gom) với Hệ thống Hội thoại Ngữ cảnh Động (Contextual Dialogue System)
## Hỗ trợ 3 nhánh hội thoại cốt truyện Hollow Knight, Typewriter effect, đồng bộ SaveManager & Touch Controls.

signal shop_opened()
signal shop_closed()
signal dialogue_started()
signal dialogue_finished()

@export var npc_name: String = "Tuk (Nhà Thu Gom)"
@export var shop_menu_scene: PackedScene = preload("res://scenes/ui/shop_menu.tscn")
@export var typing_speed: float = 38.0 # Tốc độ gõ chữ (ký tự / giây)

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var interact_prompt: Control = get_node_or_null("InteractPrompt")
@onready var talk_position: Marker2D = get_node_or_null("TalkPosition")

# --- NỘI DUNG 3 NHÁNH HỘI THOẠI CỐT TRUYỆN ---
const DIALOGUE_FIRST_MEET: String = "Suỵt! Nhỏ tiếng thôi cô bé áo đỏ... Cây kim của ngươi rỉ sét rồi kìa. Lũ lính gác của gã Bậc Thầy bên trên đang lùng sục khắp nơi để bắt bớ linh hồn đấy. Muốn sống sót xuống tầng dưới thì phải có đồ nghề. Ta có chìa khóa, có cả mảnh mặt nạ cứng cáp... chỉ cần ngươi có Geo."

const DIALOGUE_AFTER_PURCHASE: String = "Giao dịch sòng phẳng! Cầm lấy chiếc chìa khóa đó mà mở cánh cổng sắt dẫn vào hầm đá. Nhưng cẩn thận đấy, đừng để linh hồn của ngươi bị hắn rút cạn như những kẻ xấu số khác."

const DIALOGUE_RETURN: String = "Vẫn chưa đi à? Đừng lảng vảng ở đây lâu, tiếng bước chân của ngươi sẽ kéo lũ quái vật đến mất!"

# --- TRẠNG THÁI HỘI THOẠI & SAVE/LOAD FLAGS ---
var has_met_tuk: bool = false
var has_bought_item: bool = false
var _has_played_purchase_speech: bool = false

# --- THAM CHIẾU & BIẾN ĐIỀU KHIỂN ---
var is_player_in_range: bool = false
var current_player: Node2D = null
var active_shop_menu: Node = null

# --- UI DIALOGUE COMPONENTS ---
var dialogue_layer: CanvasLayer = null
var dialogue_panel: PanelContainer = null
var dialogue_name_label: Label = null
var dialogue_text_label: Label = null
var dialogue_hint_label: Label = null
var choice_container: HBoxContainer = null
var open_shop_btn: Button = null
var leave_btn: Button = null
var touch_blocker: Control = null

var is_dialogue_active: bool = false
var is_typing: bool = false
var dialogue_fully_revealed: bool = false
var type_tween: Tween = null
var hint_tween: Tween = null
var _current_dialogue_callback: Callable = Callable()
var _is_showing_choices: bool = false

var font_title: FontFile = preload("res://assets/fonts/Cinzel-Bold.ttf")
var font_body: FontFile = preload("res://assets/fonts/Spectral-Bold.ttf")
var trajan_font: FontFile = font_body
var confirm_sfx: AudioStream = preload("res://assets/audio/ui/ui_button_confirm.mp3")

# --- ANIMATION FRAMES CỦA TUK ---
var anim_frames: Array[Texture2D] = []
var current_frame_idx: int = 0
var anim_timer: float = 0.0
@export var anim_speed: float = 0.25


func _ready() -> void:
	if font_title and font_body:
		font_title.fallbacks = [font_body]
	add_to_group("npcs")
	collision_layer = 4
	collision_mask = 255
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	_load_tuk_animation_frames()
	_load_dialogue_state()
	
	if interact_prompt:
		interact_prompt.visible = false
		
	_setup_nodes_if_missing()
	_setup_dialogue_ui()


func _exit_tree() -> void:
	if dialogue_layer and is_instance_valid(dialogue_layer):
		dialogue_layer.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_dialogue_margins()


# ==================== ĐỒNG BỘ DỮ LIỆU SAVEMANAGER ====================
func _load_dialogue_state() -> void:
	if SaveManager.instance:
		has_met_tuk = SaveManager.instance.is_event_completed("has_met_tuk")
		has_bought_item = SaveManager.instance.is_event_completed("has_bought_from_tuk")
		if SaveManager.instance.has_item("simple_key"):
			has_bought_item = true
	if has_bought_item:
		_has_played_purchase_speech = true


# ==================== ANIMATION SPRITE ====================
func _load_tuk_animation_frames() -> void:
	anim_frames.clear()
	for i in range(5):
		var path = "res://assets/sprites/npc/tuk/tuk_frame_" + str(i) + ".png"
		if ResourceLoader.exists(path):
			var tex = load(path) as Texture2D
			if tex:
				anim_frames.append(tex)
				
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
		prompt_lbl.text = "[E] Nói chuyện với Tuk"
		if font_body:
			prompt_lbl.add_theme_font_override("font", font_body)
		prompt_lbl.add_theme_font_size_override("font_size", 14)
		prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_lbl.position = Vector2(-80, -80)
		prompt_lbl.visible = false
		add_child(prompt_lbl)
		interact_prompt = prompt_lbl


# ==================== KHỞI TẠO GIAO DIỆN HỘP THOẠI (DIALOGUE UI) ====================
func _setup_dialogue_ui() -> void:
	if dialogue_layer and is_instance_valid(dialogue_layer):
		return
		
	dialogue_layer = CanvasLayer.new()
	dialogue_layer.name = "TukDialogueLayer"
	dialogue_layer.layer = 105
	add_child(dialogue_layer)
	dialogue_layer.visible = false
	
	# Control bắt chạm toàn màn hình (Hỗ trợ lướt thoại trên Android)
	touch_blocker = Control.new()
	touch_blocker.name = "DialogueTouchReceiver"
	touch_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	touch_blocker.gui_input.connect(_on_touch_receiver_gui_input)
	dialogue_layer.add_child(touch_blocker)
	
	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.anchor_left = 0.0
	dialogue_panel.anchor_right = 1.0
	
	_update_dialogue_margins()
	
	# Khung thoại Hollow Knight: Nền đen tuyền mờ viền ánh kim
	var panel_sb = _create_stylebox(
		Color(0.04, 0.05, 0.08, 0.94),
		Color(0.8, 0.72, 0.55, 0.88),
		2,
		6,
		Vector4(24, 16, 24, 16)
	)
	dialogue_panel.add_theme_stylebox_override("panel", panel_sb)
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_layer.add_child(dialogue_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dialogue_panel.add_child(vbox)
	
	# Tên người nói: "TUK (NHÀ THU GOM)"
	dialogue_name_label = Label.new()
	dialogue_name_label.text = "TUK (NHÀ THU GOM)"
	if font_title:
		dialogue_name_label.add_theme_font_override("font", font_title)
	dialogue_name_label.add_theme_font_size_override("font_size", 18)
	dialogue_name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	dialogue_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	dialogue_name_label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(dialogue_name_label)
	
	# Nội dung thoại (Typewriter Effect)
	dialogue_text_label = Label.new()
	dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_body:
		dialogue_text_label.add_theme_font_override("font", font_body)
	dialogue_text_label.add_theme_font_size_override("font_size", 16)
	dialogue_text_label.add_theme_constant_override("line_spacing", 4)
	dialogue_text_label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.96))
	dialogue_text_label.add_theme_color_override("font_outline_color", Color.BLACK)
	dialogue_text_label.add_theme_constant_override("outline_size", 3)
	vbox.add_child(dialogue_text_label)
	
	# Vùng nút tùy chọn & chỉ dẫn (Footer)
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)
	
	choice_container = HBoxContainer.new()
	choice_container.add_theme_constant_override("separation", 10)
	choice_container.visible = false
	footer.add_child(choice_container)
	
	# Nút [🛒 MỞ CỬA HÀNG]
	open_shop_btn = Button.new()
	open_shop_btn.text = "🛒 MỞ CỬA HÀNG"
	if font_body:
		open_shop_btn.add_theme_font_override("font", font_body)
	open_shop_btn.add_theme_font_size_override("font_size", 14)
	var btn_shop_sb = _create_stylebox(Color(0.12, 0.16, 0.22, 0.9), Color(0.85, 0.75, 0.5, 0.8), 1, 4, Vector4(14, 6, 14, 6))
	var btn_shop_sb_h = _create_stylebox(Color(0.18, 0.26, 0.36, 0.95), Color(1.0, 0.92, 0.65, 1.0), 1, 4, Vector4(14, 6, 14, 6))
	open_shop_btn.add_theme_stylebox_override("normal", btn_shop_sb)
	open_shop_btn.add_theme_stylebox_override("hover", btn_shop_sb_h)
	open_shop_btn.add_theme_stylebox_override("pressed", btn_shop_sb_h)
	open_shop_btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78))
	open_shop_btn.pressed.connect(_on_open_shop_button_pressed)
	choice_container.add_child(open_shop_btn)
	
	# Nút [✕ RỜI ĐI]
	leave_btn = Button.new()
	leave_btn.text = "✕ RỜI ĐI"
	if font_body:
		leave_btn.add_theme_font_override("font", font_body)
	leave_btn.add_theme_font_size_override("font_size", 13)
	var btn_leave_sb = _create_stylebox(Color(0.14, 0.14, 0.16, 0.8), Color(0.45, 0.45, 0.5, 0.5), 1, 4, Vector4(12, 6, 12, 6))
	var btn_leave_sb_h = _create_stylebox(Color(0.25, 0.15, 0.15, 0.9), Color(0.9, 0.4, 0.4, 0.8), 1, 4, Vector4(12, 6, 12, 6))
	leave_btn.add_theme_stylebox_override("normal", btn_leave_sb)
	leave_btn.add_theme_stylebox_override("hover", btn_leave_sb_h)
	leave_btn.add_theme_stylebox_override("pressed", btn_leave_sb_h)
	leave_btn.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	leave_btn.pressed.connect(_on_leave_button_pressed)
	choice_container.add_child(leave_btn)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)
	
	# Gợi ý bấm tiếp tục
	dialogue_hint_label = Label.new()
	dialogue_hint_label.text = "▼ Chạm màn hình hoặc bấm Enter / Space / E để tiếp tục"
	if font_body:
		dialogue_hint_label.add_theme_font_override("font", font_body)
	dialogue_hint_label.add_theme_font_size_override("font_size", 13)
	dialogue_hint_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.75))
	dialogue_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(dialogue_hint_label)


func _update_dialogue_margins() -> void:
	if not dialogue_panel:
		return
	var safe_area = DisplayServer.get_display_safe_area()
	var vp_size = get_viewport_rect().size if get_viewport() else Vector2(1280, 720)
	var left_m = maxf(80.0, float(safe_area.position.x) + 30.0)
	var right_m = -maxf(80.0, float(vp_size.x - safe_area.end.x) + 30.0)
	var bot_m = -maxf(35.0, float(vp_size.y - safe_area.end.y) + 20.0)
	dialogue_panel.offset_left = left_m
	dialogue_panel.offset_right = right_m
	dialogue_panel.offset_bottom = bot_m
	dialogue_panel.offset_top = bot_m - 175.0


# ==================== ĐIỀU KHIỂN & KÍCH HOẠT HỘI THOẠI ====================
func _unhandled_input(event: InputEvent) -> void:
	# 1. Khi đang hiển thị lời thoại: Nhận input lướt chữ / qua câu
	if is_dialogue_active:
		if _is_showing_choices and dialogue_fully_revealed:
			return
		var is_advance_action: bool = (
			event.is_action_pressed("ui_accept") or
			event.is_action_pressed("interact") or
			event.is_action_pressed("jump") or
			event.is_action_pressed("attack") or
			(event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E, KEY_W, KEY_UP, KEY_Z, KEY_J])) or
			(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or
			(event is InputEventScreenTouch and event.pressed)
		)
		if is_advance_action:
			_handle_dialogue_advance()
			get_viewport().set_input_as_handled()
		return

	# 2. Khi đang ở gần Tuk: Nhận phím Tương tác
	if not is_player_in_range or not is_instance_valid(current_player):
		return
		
	var is_interact: bool = event.is_action_pressed("ui_up") or event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_E, KEY_UP, KEY_W]))
	if is_interact:
		_interact_with_tuk()
		get_viewport().set_input_as_handled()


func _interact_with_tuk() -> void:
	# Nếu Shop đang mở hoặc đang thoại thì bỏ qua
	var existing_menu = get_tree().current_scene.find_child("ShopMenu", true, false)
	if existing_menu or is_dialogue_active:
		return
		
	if not has_met_tuk:
		# NHÁNH 1: Lần đầu tiên gặp gỡ
		_start_dialogue(DIALOGUE_FIRST_MEET, func():
			has_met_tuk = true
			if SaveManager.instance:
				SaveManager.instance.set_event_completed("has_met_tuk", true)
				SaveManager.instance.save_to_disk()
			_open_shop_menu()
		, false)
	else:
		# NHÁNH 3: Nói chuyện lại các lần tiếp theo (hiển thị tùy chọn [MỞ CỬA HÀNG] / [RỜI ĐI])
		_start_dialogue(DIALOGUE_RETURN, func():
			_open_shop_menu()
		, true)


func _start_dialogue(text: String, on_complete: Callable = Callable(), show_choices: bool = false) -> void:
	_setup_dialogue_ui()
	_update_dialogue_margins()
	
	is_dialogue_active = true
	_current_dialogue_callback = on_complete
	_is_showing_choices = show_choices
	dialogue_started.emit()
	
	# Khóa di chuyển của Hornet để đứng nghe thoại
	_lock_player(true)
	
	# Ẩn và vô hiệu hóa toàn bộ cụm nút điều khiển cảm ứng
	_set_touch_controls_visible(false)
		
	# Ẩn nút tương tác cảm ứng và prompt trên đầu
	TouchControls.hide_interact(get_tree())
	TouchControls.suppress_interact(get_tree(), true)
	if interact_prompt:
		interact_prompt.visible = false
		
	if choice_container:
		choice_container.visible = false
	if dialogue_hint_label:
		dialogue_hint_label.visible = false
		
	dialogue_text_label.text = text
	dialogue_text_label.visible_characters = 0
	
	dialogue_layer.visible = true
	dialogue_panel.modulate.a = 0.0
	
	var fade_tw = create_tween()
	fade_tw.tween_property(dialogue_panel, "modulate:a", 1.0, 0.2)
	await fade_tw.finished
	
	# Hiệu ứng Typewriter gõ từng chữ
	is_typing = true
	dialogue_fully_revealed = false
	
	if type_tween and type_tween.is_valid():
		type_tween.kill()
		
	var total_chars = text.length()
	var duration = float(total_chars) / maxf(1.0, typing_speed)
	type_tween = create_tween()
	type_tween.tween_property(dialogue_text_label, "visible_characters", total_chars, duration)
	await type_tween.finished
	
	is_typing = false
	dialogue_fully_revealed = true
	_on_text_reveal_completed()


func _on_text_reveal_completed() -> void:
	if not is_inside_tree() or not is_dialogue_active:
		return
	if _is_showing_choices and choice_container:
		choice_container.visible = true
		if open_shop_btn:
			open_shop_btn.grab_focus()
		if dialogue_hint_label:
			dialogue_hint_label.text = "▼ Chọn thao tác để tiếp tục"
			dialogue_hint_label.visible = true
	else:
		if dialogue_hint_label:
			dialogue_hint_label.text = "▼ Chạm màn hình hoặc bấm Enter / Space / E để tiếp tục"
			dialogue_hint_label.visible = true
			
	_start_hint_pulse()


func _start_hint_pulse() -> void:
	if not dialogue_hint_label:
		return
	if hint_tween and hint_tween.is_valid():
		hint_tween.kill()
	hint_tween = create_tween().set_loops()
	hint_tween.tween_property(dialogue_hint_label, "modulate:a", 0.35, 0.5)
	hint_tween.tween_property(dialogue_hint_label, "modulate:a", 1.0, 0.5)


func _handle_dialogue_advance() -> void:
	if not is_dialogue_active:
		return
		
	# Nếu đang gõ dở -> hiện tức thì toàn bộ nội dung
	if is_typing:
		if type_tween and type_tween.is_valid():
			type_tween.kill()
		if dialogue_text_label:
			dialogue_text_label.visible_characters = -1
		is_typing = false
		dialogue_fully_revealed = true
		_on_text_reveal_completed()
		return
		
	# Nếu chữ đã hiện đầy đủ -> hoàn tất hội thoại
	if dialogue_fully_revealed:
		if _is_showing_choices:
			return
		_close_dialogue_and_execute(_current_dialogue_callback)


func _close_dialogue_and_execute(callback: Callable = Callable()) -> void:
	is_dialogue_active = false
	dialogue_fully_revealed = false
	
	if hint_tween and hint_tween.is_valid():
		hint_tween.kill()
		
	if dialogue_panel and is_instance_valid(dialogue_panel):
		var tw = create_tween()
		tw.tween_property(dialogue_panel, "modulate:a", 0.0, 0.14)
		await tw.finished
		
	if dialogue_layer and is_instance_valid(dialogue_layer):
		dialogue_layer.visible = false
		
	dialogue_finished.emit()
	
	if callback.is_valid():
		callback.call()
	else:
		var existing_menu = get_tree().current_scene.find_child("ShopMenu", true, false) if is_inside_tree() and get_tree() else null
		if not existing_menu and not active_shop_menu:
			_lock_player(false)
			_set_touch_controls_visible(true)
			TouchControls.suppress_interact(get_tree(), false)
			if is_player_in_range:
				TouchControls.show_interact(get_tree(), "tuk_shop")
				if interact_prompt:
					interact_prompt.visible = true


func _on_touch_receiver_gui_input(event: InputEvent) -> void:
	if not is_dialogue_active:
		return
	if _is_showing_choices and dialogue_fully_revealed:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_handle_dialogue_advance()
		get_viewport().set_input_as_handled()


func _on_open_shop_button_pressed() -> void:
	_play_sfx(confirm_sfx)
	_close_dialogue_and_execute(func(): _open_shop_menu())


func _on_leave_button_pressed() -> void:
	_play_sfx(confirm_sfx)
	_close_dialogue_and_execute(func():
		_lock_player(false)
		_set_touch_controls_visible(true)
		TouchControls.suppress_interact(get_tree(), false)
		if is_player_in_range:
			TouchControls.show_interact(get_tree(), "tuk_shop")
			if interact_prompt:
				interact_prompt.visible = true
	)


# ==================== QUẢN LÝ GIAO DIỆN SHOP TUK ====================
func _open_shop_menu() -> void:
	var existing_menu = get_tree().current_scene.find_child("ShopMenu", true, false)
	if existing_menu:
		return
		
	if shop_menu_scene:
		_lock_player(true)
		_set_touch_controls_visible(false)
		TouchControls.hide_interact(get_tree())
		TouchControls.suppress_interact(get_tree(), true)
		if interact_prompt:
			interact_prompt.visible = false
			
		var menu_inst = shop_menu_scene.instantiate()
		active_shop_menu = menu_inst
		get_tree().current_scene.add_child(menu_inst)
		menu_inst.tree_exited.connect(_on_shop_menu_closed)
		if menu_inst.has_signal("item_purchased"):
			menu_inst.item_purchased.connect(_on_item_purchased_from_shop)
		if menu_inst.has_method("open_shop"):
			menu_inst.open_shop(current_player, npc_name)
		shop_opened.emit()


func _on_item_purchased_from_shop(item_id: String, _item_name: String, _price: int) -> void:
	has_bought_item = true
	if SaveManager.instance:
		SaveManager.instance.set_event_completed("has_bought_from_tuk", true)
		SaveManager.instance.save_to_disk()
		
	# NHÁNH 2: Vừa hoàn tất mua đồ (kích hoạt khi mua Chìa Khóa Cổ hoặc lần mua đầu)
	if item_id == "simple_key" or not _has_played_purchase_speech:
		_has_played_purchase_speech = true
		if active_shop_menu and is_instance_valid(active_shop_menu):
			active_shop_menu.visible = false
			
		_start_dialogue(DIALOGUE_AFTER_PURCHASE, func():
			# Trở lại trạng thái Shop để người chơi tiếp tục xem hàng hoặc bấm đóng
			if active_shop_menu and is_instance_valid(active_shop_menu):
				active_shop_menu.visible = true
				if active_shop_menu.has_method("populate_shop_items"):
					active_shop_menu.populate_shop_items()
			else:
				_open_shop_menu()
		, false)


func _on_shop_menu_closed() -> void:
	active_shop_menu = null
	shop_closed.emit()
	if not is_dialogue_active:
		_lock_player(false)
		_set_touch_controls_visible(true)
		TouchControls.suppress_interact(get_tree(), false)
		if is_player_in_range:
			TouchControls.show_interact(get_tree(), "tuk_shop")
			if interact_prompt:
				interact_prompt.visible = true


# ==================== VÙNG VA CHẠM TƯƠNG TÁC ====================
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
		interact_prompt.visible = in_range and not is_dialogue_active
		if in_range:
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			interact_prompt.scale = Vector2(0.5, 0.5)
			tw.tween_property(interact_prompt, "scale", Vector2.ONE, 0.15)
	
	if in_range and not is_dialogue_active:
		TouchControls.show_interact(get_tree(), "tuk_shop")
	else:
		TouchControls.hide_interact(get_tree())


# ==================== TIỆN ÍCH HELPER ====================
func _play_sfx(clip: AudioStream) -> void:
	if clip and is_inside_tree():
		var asp = AudioStreamPlayer.new()
		asp.stream = clip
		asp.bus = &"SFX"
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)


func _create_stylebox(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0, corner_radius: int = 6, content_margin: Vector4 = Vector4(12, 8, 12, 8)) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(corner_radius)
	sb.content_margin_left = content_margin.x
	sb.content_margin_top = content_margin.y
	sb.content_margin_right = content_margin.z
	sb.content_margin_bottom = content_margin.w
	return sb


func _lock_player(locked: bool) -> void:
	if not current_player or not is_instance_valid(current_player):
		return
	if locked:
		if "velocity" in current_player:
			current_player.velocity = Vector2.ZERO
		if current_player.has_method("set_cutscene_locked"):
			current_player.set_cutscene_locked(true)
		if "animated_sprite" in current_player and current_player.animated_sprite:
			if current_player.animated_sprite.sprite_frames and current_player.animated_sprite.sprite_frames.has_animation("idle"):
				current_player.animated_sprite.play("idle")
	else:
		if current_player.has_method("set_cutscene_locked"):
			current_player.set_cutscene_locked(false)


func _set_touch_controls_visible(p_visible: bool) -> void:
	TouchControls.set_controls_visible(get_tree(), p_visible)
	if is_instance_valid(current_player):
		var tc = current_player.get_node_or_null("TouchControls")
		if tc and tc is CanvasItem:
			tc.visible = p_visible
		if tc and tc is Node:
			tc.process_mode = Node.PROCESS_MODE_ALWAYS if p_visible else Node.PROCESS_MODE_DISABLED
	if is_inside_tree() and get_tree():
		var tc_nodes = get_tree().get_nodes_in_group("touch_controls")
		for n in tc_nodes:
			if n is CanvasItem:
				n.visible = p_visible
			if n is Node:
				n.process_mode = Node.PROCESS_MODE_ALWAYS if p_visible else Node.PROCESS_MODE_DISABLED
		var tc_root = get_tree().root.find_child("TouchControls", true, false)
		if tc_root and tc_root is CanvasItem:
			tc_root.visible = p_visible
		if tc_root and tc_root is Node:
			tc_root.process_mode = Node.PROCESS_MODE_ALWAYS if p_visible else Node.PROCESS_MODE_DISABLED

