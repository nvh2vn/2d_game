extends Area2D
class_name EmilitiaNPC

## NPC Eternal Emilitia (Quý Tộc Lưu Vong)
## Cốt truyện: Học giả/quý tộc phế tích trao đổi "Ống Nghiệm Linh Hồn" (Soul Vial)
## lấy "City Crest" (Cổ Vật Hoàng Thành) để mở đường vào Thánh Đường.

signal dialogue_started()
signal dialogue_finished()
signal item_exchanged(item_given: String, item_received: String)

@export var npc_name: String = "ETERNAL EMILITIA"
@export var typing_speed: float = 38.0
@export var anim_speed: float = 0.22

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var interact_prompt: Control = get_node_or_null("InteractPrompt")
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")
@onready var talk_position: Marker2D = get_node_or_null("TalkPosition")

# --- NỘI DUNG 3 NHÁNH HỘI THOẠI CỐT TRUYỆN ---
const DIALOGUE_BRANCH_1_NO_ITEM: String = "Ôi chao... Một bóng hình còn thở giữa đống đổ nát này sao? Những tiếng la hét từ đỉnh tháp vẫn văng vẳng mỗi đêm... Soul Master, gã học giả điên loạn đó đã rút cạn sinh lực của tất cả những ai dám bén mảng đến. Nếu ngươi còn giữ một chút tàn dư linh hồn của các đồng môn ta – thứ mà tên buôn Tuk bẩn thỉu kia nhặt nhạnh được – hãy mang nó đến đây. Ta sẽ trao cho ngươi một ấn vật hoàng tộc để mở ra con đường phía trước."

const DIALOGUE_BRANCH_2_EXCHANGE: String = "Thứ sương mờ này... đúng là họ rồi! Ta có thể nghe thấy lời ai oán của họ lắng xuống. Cầm lấy chiếc huy hiệu này đi, hiệp sĩ áo đỏ. Hãy dùng nó để xuyên qua kết giới và trả thù cho chúng ta!"

const DIALOGUE_BRANCH_3_DONE: String = "Hãy cẩn trọng khi bước qua cánh cổng thánh đường. Soul Master không còn là kẻ phàm trần nữa... Hắn sử dụng ma thuật thao túng không gian để biến mất và giáng đòn từ hư vô. Đừng để hắn đánh lừa đôi mắt của ngươi!"

# --- TRẠNG THÁI HỘI THOẠI & SAVE/LOAD FLAGS ---
var has_met_emilitia: bool = false
var has_exchanged_city_crest: bool = false

# --- THAM CHIẾU & BIẾN ĐIỀU KHIỂN ---
var is_player_in_range: bool = false
var current_player: Node2D = null

# --- UI DIALOGUE COMPONENTS ---
var dialogue_layer: CanvasLayer = null
var dialogue_panel: PanelContainer = null
var dialogue_name_label: Label = null
var dialogue_text_label: Label = null
var dialogue_hint_label: Label = null
var reward_banner: PanelContainer = null
var reward_label: Label = null
var touch_blocker: Control = null

var is_dialogue_active: bool = false
var is_typing: bool = false
var dialogue_fully_revealed: bool = false
var type_tween: Tween = null
var hint_tween: Tween = null
var _current_dialogue_callback: Callable = Callable()

var trajan_font: FontFile = preload("res://assets/ui/TrajanPro.ttf")
var confirm_sfx: AudioStream = preload("res://assets/audio/ui/ui_button_confirm.mp3")

# --- ANIMATION FRAMES ---
var anim_frames: Array[Texture2D] = []
var current_frame_idx: int = 0
var anim_timer: float = 0.0


func _ready() -> void:
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
	if dialogue_layer and is_instance_valid(dialogue_layer):
		dialogue_layer.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_dialogue_margins()


# ==================== ĐỒNG BỘ DỮ LIỆU SAVEMANAGER ====================
func _load_state() -> void:
	if SaveManager.instance:
		has_met_emilitia = SaveManager.instance.is_event_completed("has_met_emilitia")
		has_exchanged_city_crest = SaveManager.instance.is_event_completed("has_exchanged_city_crest")
		if SaveManager.instance.has_inventory_item("city_crest"):
			has_exchanged_city_crest = true


# ==================== ANIMATION SPRITE ====================
func _load_animation_frames() -> void:
	anim_frames.clear()
	for i in range(6):
		var path = "res://assets/sprites/npc/emilitia/emilitia_frame_" + str(i) + ".png"
		if ResourceLoader.exists(path):
			var tex = load(path) as Texture2D
			if tex:
				anim_frames.append(tex)
				
	if anim_frames.size() == 0:
		var full_tex_path = "res://assets/sprites/npc/Eternal Emilitia.png"
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
		sprite.scale = Vector2(0.55, 0.55)
		add_child(sprite)
	else:
		if sprite.texture == null and anim_frames.size() > 0:
			sprite.texture = anim_frames[0]
		if sprite.scale == Vector2.ONE:
			sprite.scale = Vector2(0.55, 0.55)
			
	if interact_prompt == null:
		var prompt_lbl = Label.new()
		prompt_lbl.name = "InteractPrompt"
		prompt_lbl.text = "[E] Nói chuyện với Emilitia"
		if trajan_font:
			prompt_lbl.add_theme_font_override("font", trajan_font)
		prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_lbl.position = Vector2(-110, -90)
		prompt_lbl.visible = false
		add_child(prompt_lbl)
		interact_prompt = prompt_lbl


# ==================== GIAO DIỆN HỘP THOẠI (DIALOGUE UI) ====================
func _setup_dialogue_ui() -> void:
	if dialogue_layer and is_instance_valid(dialogue_layer):
		return
		
	dialogue_layer = CanvasLayer.new()
	dialogue_layer.name = "EmilitiaDialogueLayer"
	dialogue_layer.layer = 105
	add_child(dialogue_layer)
	dialogue_layer.visible = false
	
	touch_blocker = Control.new()
	touch_blocker.name = "TouchBlocker"
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
	
	var panel_sb = _create_stylebox(
		Color(0.04, 0.05, 0.08, 0.94),
		Color(0.85, 0.72, 0.5, 0.9),
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
	
	dialogue_name_label = Label.new()
	dialogue_name_label.text = "ETERNAL EMILITIA (QUÝ TỘC LƯU VONG)"
	if trajan_font:
		dialogue_name_label.add_theme_font_override("font", trajan_font)
	dialogue_name_label.add_theme_font_size_override("font_size", 18)
	dialogue_name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	dialogue_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	dialogue_name_label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(dialogue_name_label)
	
	dialogue_text_label = Label.new()
	dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if trajan_font:
		dialogue_text_label.add_theme_font_override("font", trajan_font)
	dialogue_text_label.add_theme_font_size_override("font_size", 15)
	dialogue_text_label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.96))
	dialogue_text_label.add_theme_color_override("font_outline_color", Color.BLACK)
	dialogue_text_label.add_theme_constant_override("outline_size", 3)
	vbox.add_child(dialogue_text_label)
	
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)
	
	dialogue_hint_label = Label.new()
	dialogue_hint_label.text = "▼ Chạm màn hình hoặc bấm Enter / Space / E để tiếp tục"
	if trajan_font:
		dialogue_hint_label.add_theme_font_override("font", trajan_font)
	dialogue_hint_label.add_theme_font_size_override("font_size", 12)
	dialogue_hint_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.75))
	dialogue_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(dialogue_hint_label)
	
	# Banner nhận thưởng
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
	reward_label.text = "★ NHẬN ĐƯỢC: CITY CREST (CỔ VẬT HOÀNG THÀNH)"
	if trajan_font:
		reward_label.add_theme_font_override("font", trajan_font)
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
	dialogue_panel.offset_top = bot_m - 175.0


# ==================== ĐIỀU KHIỂN & KÍCH HOẠT HỘI THOẠI ====================
func _unhandled_input(event: InputEvent) -> void:
	if is_dialogue_active:
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

	if not is_player_in_range or not is_instance_valid(current_player):
		return
		
	var is_interact: bool = event.is_action_pressed("ui_up") or event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_E, KEY_UP, KEY_W]))
	if is_interact:
		_interact_with_emilitia()
		get_viewport().set_input_as_handled()


func _interact_with_emilitia() -> void:
	if is_dialogue_active:
		return
		
	_load_state()
	
	# NHÁNH 3: Đã hoàn tất trao đổi vật phẩm trước đó
	if has_exchanged_city_crest:
		_start_dialogue(DIALOGUE_BRANCH_3_DONE)
		return
		
	# Kiểm tra người chơi có mang theo Soul Vial (hoặc rancid_egg) hay không
	var has_vial = SaveManager.has_item("soul_vial") or SaveManager.has_item("rancid_egg")
	
	if has_vial:
		# NHÁNH 2: Đã có Soul Vial trong túi -> Thực hiện trao đổi
		_start_dialogue(DIALOGUE_BRANCH_2_EXCHANGE, func():
			_execute_item_exchange()
		)
	else:
		# NHÁNH 1: Chưa có Soul Vial -> Gợi ý tìm kiếm
		_start_dialogue(DIALOGUE_BRANCH_1_NO_ITEM, func():
			has_met_emilitia = true
			if SaveManager.instance:
				SaveManager.instance.set_event_completed("has_met_emilitia", true)
				SaveManager.instance.save_to_disk()
		)


func _execute_item_exchange() -> void:
	# Trừ 1 Soul Vial khỏi túi đồ
	var removed = SaveManager.remove_item("soul_vial", 1)
	if not removed:
		SaveManager.remove_item("rancid_egg", 1)
		
	# Thêm City Crest vào túi đồ
	if SaveManager.instance:
		SaveManager.instance.add_inventory_item("city_crest")
		SaveManager.instance.set_event_completed("has_exchanged_city_crest", true)
		SaveManager.instance.save_to_disk()
		
	has_exchanged_city_crest = true
	item_exchanged.emit("soul_vial", "city_crest")
	_show_reward_banner("★ NHẬN ĐƯỢC: CITY CREST (CỔ VẬT HOÀNG THÀNH)")


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


func _start_dialogue(text: String, on_complete: Callable = Callable()) -> void:
	_setup_dialogue_ui()
	_update_dialogue_margins()
	
	is_dialogue_active = true
	_current_dialogue_callback = on_complete
	dialogue_started.emit()
	
	# Khóa di chuyển của Hornet
	if current_player and current_player.has_method("set_cutscene_locked"):
		current_player.set_cutscene_locked(true)
	elif current_player and "velocity" in current_player:
		current_player.velocity = Vector2.ZERO
		
	TouchControls.hide_interact(get_tree())
	TouchControls.suppress_interact(get_tree(), true)
	if interact_prompt:
		interact_prompt.visible = false
		
	if dialogue_hint_label:
		dialogue_hint_label.visible = false
		
	dialogue_text_label.text = text
	dialogue_text_label.visible_characters = 0
	
	dialogue_layer.visible = true
	dialogue_panel.modulate.a = 0.0
	
	var fade_tw = create_tween()
	fade_tw.tween_property(dialogue_panel, "modulate:a", 1.0, 0.2)
	await fade_tw.finished
	
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
		
	if is_typing:
		if type_tween and type_tween.is_valid():
			type_tween.kill()
		if dialogue_text_label:
			dialogue_text_label.visible_characters = -1
		is_typing = false
		dialogue_fully_revealed = true
		_on_text_reveal_completed()
		return
		
	if dialogue_fully_revealed:
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
		
	# Mở khóa Hornet
	if current_player and current_player.has_method("set_cutscene_locked"):
		current_player.set_cutscene_locked(false)
	TouchControls.suppress_interact(get_tree(), false)
	if is_player_in_range:
		TouchControls.show_interact(get_tree(), "emilitia")
		if interact_prompt:
			interact_prompt.visible = true


func _on_touch_receiver_gui_input(event: InputEvent) -> void:
	if not is_dialogue_active:
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_handle_dialogue_advance()
		get_viewport().set_input_as_handled()


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
		TouchControls.show_interact(get_tree(), "emilitia")
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
