extends CanvasLayer

## Secret Debug Cheat Panel phục vụ Demo Bảo Vệ Đồ Án (Tương thích PC & Mobile/APK)
## Autoload: DebugManager ("*res://scripts/core/debug_manager.gd")

static var instance: Node = null

# Cờ trạng thái Cheat toàn cục
var is_god_mode: bool = false
var is_one_hit: bool = false

# UI Components
var root_ctrl: Control
var debug_toggle_btn: Button
var debug_panel: PanelContainer
var god_mode_btn: Button
var one_hit_btn: Button
var refill_btn: Button
var geo_btn: Button
var close_btn: Button
var status_badge: Label

var _panel_open: bool = false
var _panel_tween: Tween
var _base_pos: Vector2 = Vector2(18.0, 16.0)

signal god_mode_changed(enabled: bool)
signal one_hit_changed(enabled: bool)


func _ready() -> void:
	instance = self
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS # Hoạt động xuyên suốt kể cả khi Pause
	
	_calculate_safe_position()
	_build_ui()
	_update_ui_state()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED or what == NOTIFICATION_APPLICATION_RESUMED:
		_calculate_safe_position()
		if debug_toggle_btn:
			debug_toggle_btn.position = _base_pos
		if debug_panel:
			debug_panel.position = _base_pos + Vector2(0, 40.0)


func _calculate_safe_position() -> void:
	var safe_area = DisplayServer.get_display_safe_area()
	var offset_x = maxf(18.0, float(safe_area.position.x) + 8.0)
	var offset_y = maxf(16.0, float(safe_area.position.y) + 6.0)
	_base_pos = Vector2(offset_x, offset_y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Hỗ trợ F1 hoặc dấu huyền/ngã (tilde/backtick) trên bàn phím PC
		if event.keycode == KEY_F1 or event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE:
			toggle_panel()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Khóa máu người chơi luôn ở mức tối đa khi God Mode được bật
	if is_god_mode:
		var p = get_player()
		if p and "current_health" in p and "max_health" in p:
			if p.current_health < p.max_health:
				p.current_health = p.max_health
				if p.has_method("update_hud"):
					p.update_hud()


# ==================== XÂY DỰNG GIAO DIỆN (UI) ====================
func _build_ui() -> void:
	# 1. Root Control - KHÔNG CHẶN TOUCH/CLICK NGOÀI PANEL
	root_ctrl = Control.new()
	root_ctrl.name = "DebugRoot"
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	# 2. Nút Toggle bí mật ở góc trên bên trái
	debug_toggle_btn = Button.new()
	debug_toggle_btn.name = "DebugToggleBtn"
	debug_toggle_btn.text = "DBG"
	debug_toggle_btn.custom_minimum_size = Vector2(52, 34)
	debug_toggle_btn.position = _base_pos
	debug_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_toggle_btn.focus_mode = Control.FOCUS_NONE
	
	var toggle_sb_norm = _create_stylebox(Color(0.12, 0.15, 0.2, 0.38), Color(0.6, 0.7, 0.85, 0.3), 1, 6)
	var toggle_sb_hover = _create_stylebox(Color(0.18, 0.24, 0.32, 0.85), Color(0.9, 0.8, 0.4, 0.7), 1, 6)
	var toggle_sb_press = _create_stylebox(Color(0.24, 0.32, 0.42, 0.95), Color(1.0, 0.9, 0.5, 0.9), 1, 6)
	
	debug_toggle_btn.add_theme_stylebox_override("normal", toggle_sb_norm)
	debug_toggle_btn.add_theme_stylebox_override("hover", toggle_sb_hover)
	debug_toggle_btn.add_theme_stylebox_override("pressed", toggle_sb_press)
	debug_toggle_btn.add_theme_font_size_override("font_size", 12)
	debug_toggle_btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 0.8))
	debug_toggle_btn.pressed.connect(toggle_panel)
	root_ctrl.add_child(debug_toggle_btn)

	# 3. Hộp Panel Menu trượt
	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.custom_minimum_size = Vector2(240, 0)
	debug_panel.position = _base_pos + Vector2(0, 40.0)
	debug_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_panel.visible = false
	debug_panel.modulate.a = 0.0

	var panel_sb = _create_stylebox(
		Color(0.06, 0.08, 0.12, 0.95),
		Color(0.8, 0.68, 0.35, 0.85), # Viền vàng cổ điển Hollow Knight
		2,
		8,
		Vector4(14, 12, 14, 12)
	)
	debug_panel.add_theme_stylebox_override("panel", panel_sb)
	root_ctrl.add_child(debug_panel)

	# 4. Nội dung bên trong Panel
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	debug_panel.add_child(vbox)

	# Header: Tiêu đề + Nút Đóng
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = "⚙️ DEBUG CHEAT"
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	header.add_child(title_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(26, 26)
	close_btn.focus_mode = Control.FOCUS_NONE
	var close_sb = _create_stylebox(Color(0.2, 0.1, 0.1, 0.6), Color(0.8, 0.3, 0.3, 0.6), 1, 4, Vector4(4, 2, 4, 2))
	var close_sb_h = _create_stylebox(Color(0.4, 0.12, 0.12, 0.9), Color(1.0, 0.4, 0.4, 0.9), 1, 4, Vector4(4, 2, 4, 2))
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.add_theme_stylebox_override("hover", close_sb_h)
	close_btn.add_theme_stylebox_override("pressed", close_sb_h)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(close_panel)
	header.add_child(close_btn)

	# Phân cách
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# Nút Toggle: GOD MODE
	god_mode_btn = Button.new()
	god_mode_btn.custom_minimum_size = Vector2(212, 38)
	god_mode_btn.focus_mode = Control.FOCUS_NONE
	god_mode_btn.pressed.connect(toggle_god_mode)
	vbox.add_child(god_mode_btn)

	# Nút Toggle: ONE HIT
	one_hit_btn = Button.new()
	one_hit_btn.custom_minimum_size = Vector2(212, 38)
	one_hit_btn.focus_mode = Control.FOCUS_NONE
	one_hit_btn.pressed.connect(toggle_one_hit)
	vbox.add_child(one_hit_btn)

	# Phân cách tiện ích phụ phục vụ demo
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Tiện ích: Hồi đầy máu & tơ ngay lập tức
	refill_btn = Button.new()
	refill_btn.text = "❤️ HỒI ĐẦY MÁU & TƠ"
	refill_btn.custom_minimum_size = Vector2(212, 32)
	refill_btn.focus_mode = Control.FOCUS_NONE
	var util_sb = _create_stylebox(Color(0.12, 0.22, 0.32, 0.85), Color(0.3, 0.6, 0.8, 0.5), 1, 5)
	var util_sb_h = _create_stylebox(Color(0.18, 0.32, 0.46, 0.95), Color(0.4, 0.8, 1.0, 0.8), 1, 5)
	refill_btn.add_theme_stylebox_override("normal", util_sb)
	refill_btn.add_theme_stylebox_override("hover", util_sb_h)
	refill_btn.add_theme_stylebox_override("pressed", util_sb_h)
	refill_btn.add_theme_font_size_override("font_size", 11)
	refill_btn.pressed.connect(func():
		refill_player()
		refill_btn.text = "✓ ĐÃ HỒI ĐẦY!"
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(refill_btn):
			refill_btn.text = "❤️ HỒI ĐẦY MÁU & TƠ"
	)
	vbox.add_child(refill_btn)

	# Tiện ích: Thêm 1000 Geo để demo mua đồ Tuk
	geo_btn = Button.new()
	geo_btn.text = "💰 +1000 GEO"
	geo_btn.custom_minimum_size = Vector2(212, 32)
	geo_btn.focus_mode = Control.FOCUS_NONE
	var geo_sb = _create_stylebox(Color(0.28, 0.22, 0.08, 0.85), Color(0.8, 0.68, 0.3, 0.5), 1, 5)
	var geo_sb_h = _create_stylebox(Color(0.4, 0.32, 0.12, 0.95), Color(1.0, 0.85, 0.4, 0.8), 1, 5)
	geo_btn.add_theme_stylebox_override("normal", geo_sb)
	geo_btn.add_theme_stylebox_override("hover", geo_sb_h)
	geo_btn.add_theme_stylebox_override("pressed", geo_sb_h)
	geo_btn.add_theme_font_size_override("font_size", 11)
	geo_btn.pressed.connect(func():
		add_player_geo(1000)
		geo_btn.text = "✓ +1000 GEO THÀNH CÔNG!"
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(geo_btn):
			geo_btn.text = "💰 +1000 GEO"
	)
	vbox.add_child(geo_btn)

	# Hint phím tắt PC
	var hint_lbl = Label.new()
	hint_lbl.text = "PC: Bấm F1 hoặc ~ để đóng/mở"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72, 0.6))
	vbox.add_child(hint_lbl)


# ==================== LOGIC ĐIỀU KHIỂN & ANIMATION ====================
func toggle_panel() -> void:
	if _panel_open:
		close_panel()
	else:
		open_panel()


func open_panel() -> void:
	_panel_open = true
	debug_panel.visible = true
	_calculate_safe_position()
	var target_pos = _base_pos + Vector2(0, 40.0)
	debug_panel.position = target_pos - Vector2(0, 10.0)
	
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()
		
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(debug_panel, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(debug_panel, "position", target_pos, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_panel() -> void:
	_panel_open = false
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()
		
	var target_pos = _base_pos + Vector2(0, 30.0)
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.tween_property(debug_panel, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_panel_tween.tween_property(debug_panel, "position", target_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_panel_tween.chain().tween_callback(func():
		if not _panel_open and is_instance_valid(debug_panel):
			debug_panel.visible = false
	)


func toggle_god_mode() -> void:
	is_god_mode = not is_god_mode
	if is_god_mode:
		refill_player()
	_update_ui_state()
	god_mode_changed.emit(is_god_mode)


func toggle_one_hit() -> void:
	is_one_hit = not is_one_hit
	_update_ui_state()
	one_hit_changed.emit(is_one_hit)


func _update_ui_state() -> void:
	# Cập nhật nút GOD MODE
	if is_god_mode:
		god_mode_btn.text = "🛡️ GOD MODE: ON"
		var sb_on = _create_stylebox(Color(0.1, 0.55, 0.25, 0.95), Color(0.3, 0.95, 0.5, 0.9), 1, 6)
		god_mode_btn.add_theme_stylebox_override("normal", sb_on)
		god_mode_btn.add_theme_stylebox_override("hover", sb_on)
		god_mode_btn.add_theme_stylebox_override("pressed", sb_on)
		god_mode_btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		god_mode_btn.text = "🛡️ GOD MODE: OFF"
		var sb_off = _create_stylebox(Color(0.18, 0.2, 0.24, 0.9), Color(0.35, 0.38, 0.45, 0.5), 1, 6)
		god_mode_btn.add_theme_stylebox_override("normal", sb_off)
		god_mode_btn.add_theme_stylebox_override("hover", sb_off)
		god_mode_btn.add_theme_stylebox_override("pressed", sb_off)
		god_mode_btn.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))

	# Cập nhật nút ONE HIT
	if is_one_hit:
		one_hit_btn.text = "⚔️ ONE HIT: ON"
		var sb_on = _create_stylebox(Color(0.78, 0.26, 0.1, 0.95), Color(1.0, 0.65, 0.2, 0.9), 1, 6)
		one_hit_btn.add_theme_stylebox_override("normal", sb_on)
		one_hit_btn.add_theme_stylebox_override("hover", sb_on)
		one_hit_btn.add_theme_stylebox_override("pressed", sb_on)
		one_hit_btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		one_hit_btn.text = "⚔️ ONE HIT: OFF"
		var sb_off = _create_stylebox(Color(0.18, 0.2, 0.24, 0.9), Color(0.35, 0.38, 0.45, 0.5), 1, 6)
		one_hit_btn.add_theme_stylebox_override("normal", sb_off)
		one_hit_btn.add_theme_stylebox_override("hover", sb_off)
		one_hit_btn.add_theme_stylebox_override("pressed", sb_off)
		one_hit_btn.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))

	# Cập nhật nút bấm thu nhỏ DBG
	if debug_toggle_btn:
		var has_cheat = is_god_mode or is_one_hit
		if has_cheat:
			debug_toggle_btn.text = "DBG ●"
			var sb_cheat = _create_stylebox(Color(0.2, 0.35, 0.2, 0.65), Color(0.4, 0.95, 0.5, 0.8), 1, 6)
			debug_toggle_btn.add_theme_stylebox_override("normal", sb_cheat)
			debug_toggle_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		else:
			debug_toggle_btn.text = "DBG"
			var sb_norm = _create_stylebox(Color(0.12, 0.15, 0.2, 0.38), Color(0.6, 0.7, 0.85, 0.3), 1, 6)
			debug_toggle_btn.add_theme_stylebox_override("normal", sb_norm)
			debug_toggle_btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 0.8))


# ==================== TIỆN ÍCH GAMEPLAY ====================
func get_player() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		return players[0]
	return null


func refill_player() -> void:
	var p = get_player()
	if p:
		if "max_health" in p and "current_health" in p:
			p.current_health = p.max_health
		if "max_silk" in p and "current_silk" in p:
			p.current_silk = p.max_silk
		if p.has_method("update_hud"):
			p.update_hud()
		if p.has_method("update_silk_hud"):
			p.update_silk_hud()


func add_player_geo(amount: int = 1000) -> void:
	var p = get_player()
	if p and p.has_method("add_geo"):
		p.add_geo(amount)
	elif p and "geo_amount" in p:
		p.geo_amount += amount
		if p.has_method("update_geo_hud"):
			p.update_geo_hud()
		if SaveManager.instance:
			SaveManager.save_geo(p.geo_amount)
	elif SaveManager.instance:
		SaveManager.save_geo(SaveManager.get_geo() + amount)


func _create_stylebox(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0, corner_radius: int = 6, content_margin: Vector4 = Vector4(8, 6, 8, 6)) -> StyleBoxFlat:
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
