extends Area2D
class_name NailMasterNPC

## NPC NailMaster (Cựu Binh Bảo Vệ)
## Cốt truyện: Trao đổi "Bản Thảo Thánh Đường" (Sanctum Parchment) lấy "Piercing Blast" (Kỷ Vật Xạ Thủ).
## Thiết kế mới: Tự động kiểm tra Inventory, hiển thị lựa chọn đổi trực tiếp trên khung thoại,
## ẩn Touch Controls khi đối thoại, đồng bộ SaveManager.

signal dialogue_started()
signal dialogue_finished()
signal item_exchanged(item_given: String, item_received: String)

@export var npc_name: String = "NAILMASTER (CỰU BINH BẢO VỆ)"
@export var typing_speed: float = 38.0
@export var anim_speed: float = 0.22

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var interact_prompt: Control = get_node_or_null("InteractPrompt")
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")
@onready var talk_position: Marker2D = get_node_or_null("TalkPosition")

# --- NỘI DUNG ĐỐI THOẠI CHUẨN KỊCH BẢN ---
const DIALOGUE_CASE_1_NO_ITEM: String = "Dừng bước, hỡi khách bộ hành. Đừng đâm đầu vào tử địa. Thanh kiếm rỉ sét này từng thề bảo vệ vương triều, nhưng khi Soul Master chiếm đoạt nguồn năng lượng cấm, cả quân đoàn của ta đã bị xé nát. Hắn dịch chuyển các khối đá, đảo lộn từng ngóc ngách, biến thánh đường thành một mê cung phong ấn không lối ra. Ta đã chôn chân ở đây qua bao mùa rêu mọc, mắt mờ đi vì mất phương hướng. Nghe bảo tên nhặt phế liệu Tuk có nhặt được cuộn bản vẽ kết cấu cũ của thánh đường... Nếu không có nó, ngươi hay ta cũng chỉ là những bộ xương khô chờ mục rữa dưới chân tháp mà thôi."

const DIALOGUE_CASE_2_HAVE_ITEM: String = "Nét vẽ này... những lối ngầm bí mật của đội cận vệ! Đôi mắt ta như được khai sáng lần nữa! Điểm mù của hắn... chính là ở đỉnh đại điện! Ngươi đã cứu rỗi linh hồn của một kẻ chiến bại. Xin hãy nhận lấy PIERCING BLAST – khối tinh thể hộ mệnh đọng lại từ ý chí sắt đá của những cận vệ đã ngã xuống. Hãy mang nó theo, để ngọn kim của ngươi phóng ra tia chớp công phá mọi kết giới tà ác!"

const DIALOGUE_THANK_YOU: String = "Ý chí của quân đoàn cận vệ nay trao lại cho ngươi. Đừng để máu của đồng đội ta đổ xuống vô ích. Hãy xuyên thủng trái tim kẻ phản bội!"

const DIALOGUE_CASE_3_DONE: String = "Con đường đã mở trong tâm trí ta. Hãy tiến lên đỉnh tháp, hỡi chiến binh. Thanh trừng tên bạo chúa và trả lại sự tôn nghiêm cho vùng đất này!"

# --- TRẠNG THÁI LƯU TRỮ ---
var has_exchanged_piercing_blast: bool = false
var is_player_in_range: bool = false
var current_player: Node2D = null

# --- UI DIALOGUE COMPONENTS ---
var dialogue_layer: CanvasLayer = null
var dialogue_panel: PanelContainer = null
var dialogue_name_label: Label = null
var dialogue_text_label: Label = null
var dialogue_hint_label: Label = null
var choice_container: HBoxContainer = null
var trade_btn: Button = null
var later_btn: Button = null
var leave_btn: Button = null
var reward_banner: PanelContainer = null
var reward_label: Label = null
var touch_blocker: Control = null

# --- ĐIỀU KHIỂN HỘI THOẠI ---
enum DialogueMode { NO_ITEM, CAN_TRADE, AFTER_TRADE, COMPLETED }
var current_mode: DialogueMode = DialogueMode.NO_ITEM

var is_dialogue_active: bool = false
var is_typing: bool = false
var dialogue_fully_revealed: bool = false
var type_tween: Tween = null
var hint_tween: Tween = null

var font_title: FontFile = preload("res://assets/fonts/Cinzel-Bold.ttf")
var font_body: FontFile = preload("res://assets/fonts/Spectral-Bold.ttf")
var trajan_font: FontFile = font_body
var confirm_sfx: AudioStream = preload("res://assets/audio/ui/ui_button_confirm.mp3")
var save_sfx: AudioStream = preload("res://assets/audio/ui/ui_save.mp3")

# --- ANIMATION SPRITE FRAMES ---
var anim_frames: Array[Texture2D] = []
var current_frame_idx: int = 0
var anim_timer: float = 0.0


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
	
	if interaction_area and interaction_area != self:
		interaction_area.collision_layer = 4
		interaction_area.collision_mask = 255
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
		interaction_area.area_entered.connect(_on_area_entered)
		interaction_area.area_exited.connect(_on_area_exited)
		
	_load_animation_frames()
	_load_state()
	_setup_nodes_if_missing()
	_setup_dialogue_ui()


func _exit_tree() -> void:
	if is_dialogue_active:
		_set_touch_controls_visible(true)
	if dialogue_layer and is_instance_valid(dialogue_layer):
		dialogue_layer.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_dialogue_margins()


# ==================== ĐỒNG BỘ SAVEMANAGER ====================
func _load_state() -> void:
	if SaveManager.instance:
		has_exchanged_piercing_blast = SaveManager.instance.is_event_completed("has_exchanged_piercing_blast")
		if SaveManager.instance.has_inventory_item("piercing_blast") or SaveManager.instance.has_inventory_item("defender_crest"):
			has_exchanged_piercing_blast = true


# ==================== ANIMATION SPRITE ====================
func _load_animation_frames() -> void:
	anim_frames.clear()
	for i in range(6):
		var path = "res://assets/sprites/npc/nailmaster/nailmaster_frame_" + str(i) + ".png"
		if ResourceLoader.exists(path):
			var tex = load(path) as Texture2D
			if tex:
				anim_frames.append(tex)
				
	if anim_frames.size() == 0:
		var full_tex_path = "res://assets/sprites/npc/NailMaster.png"
		if ResourceLoader.exists(full_tex_path):
			var full_tex = load(full_tex_path) as Texture2D
			if full_tex:
				anim_frames.append(full_tex)


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
		sprite.scale = Vector2(0.38, 0.38)
		add_child(sprite)
	else:
		if sprite.texture == null and anim_frames.size() > 0:
			sprite.texture = anim_frames[0]
		if sprite.scale == Vector2.ONE:
			sprite.scale = Vector2(0.38, 0.38)
			
	if interact_prompt == null:
		var prompt_lbl = Label.new()
		prompt_lbl.name = "InteractPrompt"
		prompt_lbl.text = "[E] Nói chuyện với NailMaster"
		if font_body:
			prompt_lbl.add_theme_font_override("font", font_body)
		prompt_lbl.add_theme_font_size_override("font_size", 14)
		prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_lbl.position = Vector2(-120, -100)
		prompt_lbl.visible = false
		add_child(prompt_lbl)
		interact_prompt = prompt_lbl
	else:
		if interact_prompt is Label:
			interact_prompt.text = "[E] Nói chuyện với NailMaster"


# ==================== KHỞI TẠO DIALOGUE UI ====================
func _setup_dialogue_ui() -> void:
	if dialogue_layer and is_instance_valid(dialogue_layer):
		return
		
	dialogue_layer = CanvasLayer.new()
	dialogue_layer.name = "NailMasterDialogueLayer"
	dialogue_layer.layer = 105
	add_child(dialogue_layer)
	dialogue_layer.visible = false
	
	# Touch Blocker nền (bắt chạm để bỏ qua gõ chữ khi đang chạy typewriter)
	touch_blocker = Control.new()
	touch_blocker.name = "TouchBlocker"
	touch_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_blocker.mouse_filter = Control.MOUSE_FILTER_PASS
	touch_blocker.gui_input.connect(_on_touch_blocker_gui_input)
	dialogue_layer.add_child(touch_blocker)
	
	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.anchor_left = 0.0
	dialogue_panel.anchor_right = 1.0
	
	_update_dialogue_margins()
	
	var panel_sb = _create_stylebox(
		Color(0.04, 0.05, 0.08, 0.95),
		Color(0.85, 0.72, 0.5, 0.9),
		2,
		6,
		Vector4(24, 16, 24, 16)
	)
	dialogue_panel.add_theme_stylebox_override("panel", panel_sb)
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_layer.add_child(dialogue_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	dialogue_panel.add_child(vbox)
	
	# Tên NPC: "NAILMASTER (CỰU BINH BẢO VỆ)"
	dialogue_name_label = Label.new()
	dialogue_name_label.text = npc_name
	if font_title:
		dialogue_name_label.add_theme_font_override("font", font_title)
	dialogue_name_label.add_theme_font_size_override("font_size", 18)
	dialogue_name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	dialogue_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	dialogue_name_label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(dialogue_name_label)
	
	# Lời thoại
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
	
	# VÙNG NÚT LỰA CHỌN TRỰC TIẾP TRÊN KHUNG THOẠI (FOOTER)
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)
	
	choice_container = HBoxContainer.new()
	choice_container.add_theme_constant_override("separation", 12)
	choice_container.visible = false
	footer.add_child(choice_container)
	
	# 1. Nút [TRAO ĐỔI VẬT PHẨM] (Nổi bật viền vàng ánh kim)
	trade_btn = Button.new()
	trade_btn.text = "🎁 TRAO ĐỔI VẬT PHẨM"
	if font_body:
		trade_btn.add_theme_font_override("font", font_body)
	trade_btn.add_theme_font_size_override("font_size", 14)
	trade_btn.custom_minimum_size = Vector2(180, 40)
	trade_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var btn_trade_sb = _create_stylebox(Color(0.18, 0.15, 0.08, 0.95), Color(1.0, 0.82, 0.35, 1.0), 1, 6, Vector4(16, 8, 16, 8))
	var btn_trade_h = _create_stylebox(Color(0.28, 0.23, 0.1, 1.0), Color(1.0, 0.95, 0.65, 1.0), 2, 6, Vector4(16, 8, 16, 8))
	trade_btn.add_theme_stylebox_override("normal", btn_trade_sb)
	trade_btn.add_theme_stylebox_override("hover", btn_trade_h)
	trade_btn.add_theme_stylebox_override("pressed", btn_trade_h)
	trade_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	trade_btn.pressed.connect(_on_trade_button_pressed)
	choice_container.add_child(trade_btn)
	
	# 2. Nút [ĐỂ SAU] (Đóng hộp thoại, không thực hiện đổi)
	later_btn = Button.new()
	later_btn.text = "✕ ĐỂ SAU"
	if font_body:
		later_btn.add_theme_font_override("font", font_body)
	later_btn.add_theme_font_size_override("font_size", 13)
	later_btn.custom_minimum_size = Vector2(110, 40)
	later_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var btn_later_sb = _create_stylebox(Color(0.13, 0.13, 0.16, 0.85), Color(0.5, 0.6, 0.7, 0.6), 1, 6, Vector4(14, 8, 14, 8))
	var btn_later_h = _create_stylebox(Color(0.2, 0.2, 0.25, 0.95), Color(0.8, 0.8, 0.9, 0.9), 1, 6, Vector4(14, 8, 14, 8))
	later_btn.add_theme_stylebox_override("normal", btn_later_sb)
	later_btn.add_theme_stylebox_override("hover", btn_later_h)
	later_btn.add_theme_stylebox_override("pressed", btn_later_h)
	later_btn.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88))
	later_btn.pressed.connect(_on_close_dialogue_pressed)
	choice_container.add_child(later_btn)
	
	# 3. Nút [RỜI ĐI] (Dùng cho TH1 và TH3)
	leave_btn = Button.new()
	leave_btn.text = "✕ RỜI ĐI"
	if font_body:
		leave_btn.add_theme_font_override("font", font_body)
	leave_btn.add_theme_font_size_override("font_size", 13)
	leave_btn.custom_minimum_size = Vector2(110, 40)
	leave_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var btn_leave_sb = _create_stylebox(Color(0.14, 0.14, 0.16, 0.85), Color(0.5, 0.5, 0.55, 0.6), 1, 6, Vector4(14, 8, 14, 8))
	var btn_leave_h = _create_stylebox(Color(0.24, 0.15, 0.15, 0.95), Color(0.9, 0.45, 0.45, 0.9), 1, 6, Vector4(14, 8, 14, 8))
	leave_btn.add_theme_stylebox_override("normal", btn_leave_sb)
	leave_btn.add_theme_stylebox_override("hover", btn_leave_h)
	leave_btn.add_theme_stylebox_override("pressed", btn_leave_h)
	leave_btn.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88))
	leave_btn.pressed.connect(_on_close_dialogue_pressed)
	choice_container.add_child(leave_btn)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)
	
	dialogue_hint_label = Label.new()
	dialogue_hint_label.text = "▼ Chạm màn hình để tiếp tục"
	if font_body:
		dialogue_hint_label.add_theme_font_override("font", font_body)
	dialogue_hint_label.add_theme_font_size_override("font_size", 13)
	dialogue_hint_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.75))
	dialogue_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(dialogue_hint_label)
	
	# Banner nhận thưởng trên đỉnh màn hình
	reward_banner = PanelContainer.new()
	reward_banner.name = "RewardBanner"
	reward_banner.anchors_preset = Control.PRESET_CENTER_TOP
	reward_banner.anchor_left = 0.5
	reward_banner.anchor_right = 0.5
	reward_banner.anchor_top = 0.0
	reward_banner.offset_left = -220
	reward_banner.offset_right = 220
	reward_banner.offset_top = 70
	reward_banner.offset_bottom = 120
	var reward_sb = _create_stylebox(Color(0.08, 0.12, 0.2, 0.95), Color(1.0, 0.85, 0.4, 0.9), 2, 8, Vector4(20, 10, 20, 10))
	reward_banner.add_theme_stylebox_override("panel", reward_sb)
	reward_banner.visible = false
	dialogue_layer.add_child(reward_banner)
	
	reward_label = Label.new()
	reward_label.text = "★ NHẬN ĐƯỢC: PIERCING BLAST (KỶ VẬT XẠ THỦ)"
	if font_title:
		reward_label.add_theme_font_override("font", font_title)
	reward_label.add_theme_font_size_override("font_size", 14)
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_banner.add_child(reward_label)


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
	dialogue_panel.offset_top = bot_m - 185.0


# ==================== ĐIỀU KHIỂN & KÍCH HOẠT ====================
func _unhandled_input(event: InputEvent) -> void:
	if is_dialogue_active:
		var is_advance_action: bool = (
			event.is_action_pressed("ui_accept") or
			event.is_action_pressed("interact") or
			(event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]))
		)
		if is_advance_action:
			_handle_dialogue_advance()
			get_viewport().set_input_as_handled()
		return

	if not is_player_in_range or not is_instance_valid(current_player):
		return
		
	var is_interact: bool = event.is_action_pressed("ui_up") or event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_E, KEY_UP, KEY_W]))
	if is_interact:
		_interact_with_nailmaster()
		get_viewport().set_input_as_handled()


func _interact_with_nailmaster() -> void:
	if is_dialogue_active:
		return
		
	_load_state()
	
	# TRƯỜNG HỢP 3: Đã hoàn tất đổi trước đó
	if has_exchanged_piercing_blast:
		current_mode = DialogueMode.COMPLETED
		_start_typewriter(DIALOGUE_CASE_3_DONE)
		return
		
	# Tự động kiểm tra Inventory xem đã có Bản Thảo Thánh Đường chưa
	var has_parchment: bool = SaveManager.has_item("sanctum_parchment") or SaveManager.has_item("map_tuk")
	
	if has_parchment:
		# TRƯỜNG HỢP 2: Đã có sanctum_parchment và CHƯA ĐỔI
		current_mode = DialogueMode.CAN_TRADE
		_start_typewriter(DIALOGUE_CASE_2_HAVE_ITEM)
	else:
		# TRƯỜNG HỢP 1: Trong túi CHƯA CÓ sanctum_parchment
		current_mode = DialogueMode.NO_ITEM
		_start_typewriter(DIALOGUE_CASE_1_NO_ITEM)


func _start_typewriter(text: String) -> void:
	_setup_dialogue_ui()
	_update_dialogue_margins()
	
	is_dialogue_active = true
	dialogue_started.emit()
	
	# 1. Khóa di chuyển của Hornet
	if current_player and current_player.has_method("set_cutscene_locked"):
		current_player.set_cutscene_locked(true)
	elif current_player and "velocity" in current_player:
		current_player.velocity = Vector2.ZERO
		
	# 2. ẨN HOÀN TOÀN CỤM ĐIỀU KHIỂN CẢM ỨNG (TOUCH CONTROLS)
	_set_touch_controls_visible(false)
	
	TouchControls.hide_interact(get_tree())
	TouchControls.suppress_interact(get_tree(), true)
	if interact_prompt:
		interact_prompt.visible = false
		
	if choice_container:
		choice_container.visible = false
	if dialogue_hint_label:
		dialogue_hint_label.text = "▼ Chạm màn hình để bỏ qua gõ chữ"
		dialogue_hint_label.visible = true
		
	dialogue_name_label.text = npc_name
	dialogue_text_label.text = text
	dialogue_text_label.visible_characters = 0
	
	dialogue_layer.visible = true
	dialogue_panel.modulate.a = 1.0
	_update_choice_buttons_for_mode()
	
	is_typing = true
	dialogue_fully_revealed = false
	
	if type_tween and type_tween.is_valid():
		type_tween.kill()
		
	var total_chars = text.length()
	var duration = float(total_chars) / maxf(1.0, typing_speed)
	type_tween = create_tween()
	type_tween.tween_property(dialogue_text_label, "visible_characters", total_chars, duration)
	type_tween.finished.connect(func():
		if is_typing:
			is_typing = false
			dialogue_fully_revealed = true
			_on_text_reveal_completed()
	)


func _on_text_reveal_completed() -> void:
	if not is_inside_tree() or not is_dialogue_active:
		return
		
	if choice_container:
		choice_container.visible = true
		_update_choice_buttons_for_mode()
		
	if dialogue_hint_label:
		dialogue_hint_label.text = "▼ Chọn thao tác bên dưới"
		dialogue_hint_label.visible = true
	_start_hint_pulse()


func _update_choice_buttons_for_mode() -> void:
	match current_mode:
		DialogueMode.NO_ITEM:
			# Trường hợp 1: Chỉ có 1 nút duy nhất [RỜI ĐI]
			if trade_btn: trade_btn.visible = false
			if later_btn: later_btn.visible = false
			if leave_btn: leave_btn.visible = true
			
		DialogueMode.CAN_TRADE:
			# Trường hợp 2: Có 2 nút [TRAO ĐỔI VẬT PHẨM] và [ĐỂ SAU]
			if trade_btn: trade_btn.visible = true
			if later_btn: later_btn.visible = true
			if leave_btn: leave_btn.visible = false
			
		DialogueMode.AFTER_TRADE, DialogueMode.COMPLETED:
			# Sau khi đổi xong hoặc Trường hợp 3: Chỉ có 1 nút [RỜI ĐI]
			if trade_btn: trade_btn.visible = false
			if later_btn: later_btn.visible = false
			if leave_btn: leave_btn.visible = true


func _handle_dialogue_advance() -> void:
	if not is_dialogue_active:
		return
		
	# Nếu đang gõ -> hiển thị tức thì toàn bộ nội dung
	if is_typing:
		if type_tween and type_tween.is_valid():
			type_tween.kill()
		if dialogue_text_label:
			dialogue_text_label.visible_characters = -1
		is_typing = false
		dialogue_fully_revealed = true
		_on_text_reveal_completed()
		return


func _on_touch_blocker_gui_input(event: InputEvent) -> void:
	if not is_dialogue_active:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		if is_typing:
			_handle_dialogue_advance()
			get_viewport().set_input_as_handled()


# ==================== XỬ LÝ NÚT BẤM TRAO ĐỔI ====================
func _on_trade_button_pressed() -> void:
	_play_sfx(confirm_sfx)
	_play_sfx(save_sfx)
	
	# 1. Trừ 1 "sanctum_parchment" khỏi Inventory
	var removed = SaveManager.remove_item("sanctum_parchment", 1)
	if not removed:
		SaveManager.remove_item("map_tuk", 1)
		
	# 2. Thêm 1 "piercing_blast" vào Inventory
	if SaveManager.instance:
		SaveManager.instance.add_inventory_item("piercing_blast")
		SaveManager.instance.set_event_completed("has_exchanged_piercing_blast", true)
		SaveManager.instance.save_to_disk()
		
	has_exchanged_piercing_blast = true
	item_exchanged.emit("sanctum_parchment", "piercing_blast")
	
	# 3. Hiện banner thông báo nhận đồ
	_show_reward_banner("★ NHẬN ĐƯỢC: PIERCING BLAST (KỶ VẬT XẠ THỦ)")
	
	# 4. Cập nhật UI Túi đồ nếu đang mở
	_refresh_active_inventory_ui()
	
	# 5. Cập nhật sang câu thoại cảm ơn ngắn & chỉ hiện nút [RỜI ĐI]
	current_mode = DialogueMode.AFTER_TRADE
	_start_typewriter(DIALOGUE_THANK_YOU)


func _on_close_dialogue_pressed() -> void:
	_play_sfx(confirm_sfx)
	_close_dialogue()


func _close_dialogue() -> void:
	is_dialogue_active = false
	dialogue_fully_revealed = false
	
	if hint_tween and hint_tween.is_valid():
		hint_tween.kill()
		
	# 1. Mở khóa di chuyển cho Hornet
	if current_player and current_player.has_method("set_cutscene_locked"):
		current_player.set_cutscene_locked(false)
		
	# 2. BẬT LẠI CỤM ĐIỀU KHIỂN CẢM ỨNG (TOUCH CONTROLS)
	_set_touch_controls_visible(true)
	
	TouchControls.suppress_interact(get_tree(), false)
	if is_player_in_range:
		TouchControls.show_interact(get_tree(), "nailmaster")
		if interact_prompt:
			interact_prompt.visible = true
			
	if dialogue_panel and is_instance_valid(dialogue_panel):
		dialogue_panel.modulate.a = 0.0
	if dialogue_layer and is_instance_valid(dialogue_layer):
		dialogue_layer.visible = false
		
	dialogue_finished.emit()


func _set_touch_controls_visible(p_visible: bool) -> void:
	TouchControls.set_controls_visible(get_tree(), p_visible)
	if is_instance_valid(current_player):
		var tc = current_player.get_node_or_null("TouchControls")
		if tc and tc is CanvasItem:
			tc.visible = p_visible
	if is_inside_tree() and get_tree():
		var tc_nodes = get_tree().get_nodes_in_group("touch_controls")
		for n in tc_nodes:
			if n is CanvasItem:
				n.visible = p_visible
		var tc_root = get_tree().root.find_child("TouchControls", true, false)
		if tc_root and tc_root is CanvasItem:
			tc_root.visible = p_visible


func _refresh_active_inventory_ui() -> void:
	if is_inside_tree() and get_tree():
		var inv = get_tree().root.find_child("InventoryScreen", true, false)
		if inv and inv.has_method("_refresh_inventory_tab"):
			inv._refresh_inventory_tab()
	if is_instance_valid(current_player) and current_player.has_method("update_hud"):
		current_player.update_hud()


func _show_reward_banner(text: String) -> void:
	if not reward_banner or not reward_label:
		return
	reward_label.text = text
	reward_banner.visible = true
	reward_banner.modulate.a = 0.0
	reward_banner.position.y = 40
	
	var tw = create_tween()
	tw.tween_property(reward_banner, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(reward_banner, "position:y", 65.0, 0.25)
	tw.tween_interval(2.5)
	tw.tween_property(reward_banner, "modulate:a", 0.0, 0.3)
	tw.finished.connect(func(): reward_banner.visible = false)


func _start_hint_pulse() -> void:
	if not dialogue_hint_label:
		return
	if hint_tween and hint_tween.is_valid():
		hint_tween.kill()
	hint_tween = create_tween().set_loops()
	hint_tween.tween_property(dialogue_hint_label, "modulate:a", 0.35, 0.5)
	hint_tween.tween_property(dialogue_hint_label, "modulate:a", 1.0, 0.5)


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
		if parent is Node2D:
			current_player = parent
		_set_in_range(true)


func _on_area_exited(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent == current_player:
		_set_in_range(false)


func _is_player(node: Node) -> bool:
	if not node:
		return false
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
		TouchControls.show_interact(get_tree(), "nailmaster")
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
