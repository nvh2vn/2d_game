extends Control

@export_file("*.tscn") var default_level_path: String = "res://assets/scenes/levels/map_1.tscn"

@onready var play_button: Button = %PlayButton
@onready var continue_button: Button = %ContinueButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton

@onready var menu_buttons_container: VBoxContainer = %MenuButtonsContainer
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value_label: Label = %VolumeValueLabel
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var settings_back_button: Button = %SettingsBackButton

@onready var loading_container: VBoxContainer = %LoadingContainer
@onready var loading_bar: ProgressBar = %LoadingBar
@onready var loading_label: Label = %LoadingLabel

@onready var beam_sprite: TextureRect = %BeamSprite
@onready var game_logo: TextureRect = %GameLogo

var is_loading: bool = false
var target_scene_to_load: String = ""


func _ready() -> void:
	# Kết nối tín hiệu các nút menu chính
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)
		_setup_button_hover(play_button)
	
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)
		_setup_button_hover(continue_button)
		# Kiểm tra nếu chưa có save thì làm mờ nút continue
		if not SaveManager.has_save():
			continue_button.modulate = Color(1.0, 1.0, 1.0, 0.45)
			continue_button.tooltip_text = "Chưa có tiến trình chơi trước đó"
	
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
		_setup_button_hover(settings_button)
		
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
		_setup_button_hover(quit_button)
	
	# Cấu hình Settings Panel
	if settings_back_button:
		settings_back_button.pressed.connect(_on_settings_back_pressed)
		_setup_button_hover(settings_back_button)
	
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_slider_changed)
		var bus_idx = AudioServer.get_bus_index("Master")
		if bus_idx != -1:
			var db = AudioServer.get_bus_volume_db(bus_idx)
			var linear = db_to_linear(db) * 100.0
			volume_slider.value = linear
			if volume_value_label:
				volume_value_label.text = "%d%%" % int(linear)
				
	if fullscreen_check:
		fullscreen_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	# Ẩn panel settings và loading ban đầu
	if settings_panel:
		settings_panel.visible = false
		settings_panel.modulate.a = 0.0

	if loading_container:
		loading_container.visible = false
		loading_container.modulate.a = 0.0
	
	# Bắt đầu các hiệu ứng nền
	_start_background_effects()


func _setup_button_hover(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
		tween.parallel().tween_property(btn, "modulate", Color(1.2, 1.2, 1.3, 1.0), 0.1)
	)
	btn.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		if btn == continue_button and not SaveManager.has_save():
			tween.parallel().tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 0.45), 0.1)
		else:
			tween.parallel().tween_property(btn, "modulate", Color.WHITE, 0.1)
	)


func _start_background_effects() -> void:
	# Hiệu ứng luồng sáng lập lòe (Breathing beam)
	if beam_sprite:
		var beam_tween = create_tween().set_loops()
		beam_tween.tween_property(beam_sprite, "modulate:a", 0.85, 2.5).set_trans(Tween.TRANS_SINE)
		beam_tween.tween_property(beam_sprite, "modulate:a", 0.4, 2.5).set_trans(Tween.TRANS_SINE)
	
	# Hiệu ứng logo lơ lửng nhẹ nhàng
	if game_logo:
		var initial_pos_y = game_logo.position.y
		var logo_tween = create_tween().set_loops()
		logo_tween.tween_property(game_logo, "position:y", initial_pos_y - 8.0, 2.0).set_trans(Tween.TRANS_SINE)
		logo_tween.tween_property(game_logo, "position:y", initial_pos_y + 8.0, 2.0).set_trans(Tween.TRANS_SINE)


func _on_play_button_pressed() -> void:
	if is_loading:
		return
	start_game_loading(default_level_path)


func _on_continue_button_pressed() -> void:
	if is_loading:
		return
	var last_level = SaveManager.get_last_level(default_level_path)
	start_game_loading(last_level)


func _on_settings_button_pressed() -> void:
	# Chuyển từ cụm Menu sang Panel Settings
	var tween = create_tween()
	tween.tween_property(menu_buttons_container, "modulate:a", 0.0, 0.2)
	await tween.finished
	menu_buttons_container.visible = false
	
	settings_panel.visible = true
	var tween_in = create_tween()
	tween_in.tween_property(settings_panel, "modulate:a", 1.0, 0.2)


func _on_settings_back_pressed() -> void:
	# Quay lại Menu chính
	var tween = create_tween()
	tween.tween_property(settings_panel, "modulate:a", 0.0, 0.2)
	await tween.finished
	settings_panel.visible = false
	
	menu_buttons_container.visible = true
	var tween_in = create_tween()
	tween_in.tween_property(menu_buttons_container, "modulate:a", 1.0, 0.2)


func _on_volume_slider_changed(value: float) -> void:
	if volume_value_label:
		volume_value_label.text = "%d%%" % int(value)
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx != -1:
		if value <= 0:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func start_game_loading(scene_path: String) -> void:
	is_loading = true
	target_scene_to_load = scene_path
	
	# Ẩn cụm nút menu
	var menu_tween = create_tween()
	menu_tween.tween_property(menu_buttons_container, "modulate:a", 0.0, 0.25)
	await menu_tween.finished
	menu_buttons_container.visible = false
	
	# Hiện thanh loading bar
	loading_container.visible = true
	loading_bar.value = 0
	var load_show_tween = create_tween()
	load_show_tween.tween_property(loading_container, "modulate:a", 1.0, 0.25)
	
	# Giả lập quá trình nạp tài nguyên mượt mà
	var progress_tween = create_tween()
	progress_tween.tween_property(loading_bar, "value", 100.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	while progress_tween.is_running():
		if loading_label:
			loading_label.text = "LOADING... %d%%" % int(loading_bar.value)
		await get_tree().process_frame
	
	if loading_label:
		loading_label.text = "READY!"
	
	await get_tree().create_timer(0.2).timeout
	
	# Fade toàn màn hình rồi chuyển Scene
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate", Color(0, 0, 0, 1), 0.3)
	await fade_out.finished
	
	get_tree().change_scene_to_file(target_scene_to_load)
