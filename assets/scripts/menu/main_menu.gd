extends Control

@export_file("*.tscn") var default_level_path: String = "res://assets/scenes/levels/map_1.tscn"

@export_group("Background Music (BGM)")
@export var menu_bgm: AudioStream
@export var bgm_volume_db: float = 0.0
@export var auto_play_bgm: bool = true

@export_group("UI Audio SFX")
@export var hover_sfx: AudioStream
@export var confirm_sfx: AudioStream

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
@onready var bgm_player: AudioStreamPlayer = get_node_or_null("%BGMPlayer")
@onready var sfx_player: AudioStreamPlayer = get_node_or_null("%SFXPlayer")

# Pointer & Confirmation Popup
@onready var menu_pointer: TextureRect = get_node_or_null("%MenuPointer")
@onready var confirm_modal: Control = get_node_or_null("%ConfirmNewGameModal")
@onready var confirm_new_game_btn: Button = get_node_or_null("%ConfirmNewGameButton")
@onready var cancel_new_game_btn: Button = get_node_or_null("%CancelNewGameButton")

var is_loading: bool = false
var target_scene_to_load: String = ""
var pointer_tween: Tween = null
var active_hovered_btn: Button = null


func _ready() -> void:
	# Thiết lập và phát nhạc nền Menu
	if bgm_player:
		bgm_player.bus = &"Music"
		if menu_bgm:
			bgm_player.stream = menu_bgm
			bgm_player.volume_db = bgm_volume_db
			if auto_play_bgm and not bgm_player.playing:
				bgm_player.play()

	# Cấu hình text nút bấm
	if play_button:
		play_button.text = "NEW GAME"
		play_button.pressed.connect(_on_play_button_pressed)
		_setup_button_hover(play_button)
	
	if continue_button:
		continue_button.text = "CONTINUE"
		continue_button.pressed.connect(_on_continue_button_pressed)
		_setup_button_hover(continue_button)
		_update_continue_button_state()
	
	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
		_setup_button_hover(settings_button)
		
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
		_setup_button_hover(quit_button)
	
	# Kết nối popup xác nhận New Game
	if confirm_new_game_btn:
		confirm_new_game_btn.pressed.connect(_on_confirm_new_game_pressed)
		_setup_button_hover(confirm_new_game_btn)
	if cancel_new_game_btn:
		cancel_new_game_btn.pressed.connect(_on_cancel_new_game_pressed)
		_setup_button_hover(cancel_new_game_btn)
	if confirm_modal:
		confirm_modal.visible = false
		confirm_modal.modulate.a = 0.0

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
	
	if menu_pointer:
		menu_pointer.visible = false
		menu_pointer.modulate.a = 0.0

	# Bắt đầu các hiệu ứng nền
	_start_background_effects()


func _update_continue_button_state() -> void:
	var btn: Button = continue_button if continue_button else get_node_or_null("%ContinueButton")
	if not btn:
		return
	var has_save_file = SaveManager.has_save()
	btn.disabled = not has_save_file
	if has_save_file:
		btn.modulate = Color.WHITE
		btn.tooltip_text = "Tiếp tục từ điểm lưu gần nhất"
	else:
		btn.modulate = Color(1.0, 1.0, 1.0, 0.38)
		btn.tooltip_text = "Chưa có tiến trình chơi trước đó"


func _setup_button_hover(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		if btn.disabled or is_loading:
			return
		active_hovered_btn = btn
		_move_pointer_to(btn)
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
		tween.tween_property(btn, "modulate", Color(1.2, 1.2, 1.3, 1.0), 0.1)
	)
	
	btn.focus_entered.connect(func():
		if btn.disabled or is_loading:
			return
		active_hovered_btn = btn
		_move_pointer_to(btn)
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
	)
	
	btn.mouse_exited.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		if btn == continue_button and not SaveManager.has_save():
			tween.tween_property(btn, "modulate", Color(1.0, 1.0, 1.0, 0.38), 0.1)
		else:
			tween.tween_property(btn, "modulate", Color.WHITE, 0.1)
		if active_hovered_btn == btn:
			active_hovered_btn = null
	)
	
	btn.focus_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)


func _move_pointer_to(btn: Button) -> void:
	if not menu_pointer or not is_instance_valid(btn):
		return
	
	menu_pointer.visible = true
	var target_y = btn.global_position.y + (btn.size.y - menu_pointer.size.y) * 0.5
	var target_x = btn.global_position.x - menu_pointer.size.x - 12.0
	
	if pointer_tween and pointer_tween.is_running():
		pointer_tween.kill()
		
	pointer_tween = create_tween().set_parallel(true)
	pointer_tween.tween_property(menu_pointer, "global_position:y", target_y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pointer_tween.tween_property(menu_pointer, "global_position:x", target_x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pointer_tween.tween_property(menu_pointer, "modulate:a", 1.0, 0.1)
	
	_play_hover_sfx()


func _play_hover_sfx() -> void:
	if sfx_player and hover_sfx:
		sfx_player.stream = hover_sfx
		sfx_player.play()


func _play_confirm_sfx() -> void:
	if sfx_player and confirm_sfx:
		sfx_player.stream = confirm_sfx
		sfx_player.play()


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


# --- NÚT NEW GAME & POPUP XÁC NHẬN ---

func _on_play_button_pressed() -> void:
	if is_loading:
		return
	_play_confirm_sfx()
	
	if SaveManager.has_save():
		_show_confirm_new_game_modal()
	else:
		_start_fresh_new_game()


func _show_confirm_new_game_modal() -> void:
	var modal: Control = confirm_modal if confirm_modal else get_node_or_null("%ConfirmNewGameModal")
	if not modal:
		_start_fresh_new_game()
		return
		
	modal.visible = true
	modal.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(modal, "modulate:a", 1.0, 0.2)
	
	var cancel_btn: Button = cancel_new_game_btn if cancel_new_game_btn else get_node_or_null("%CancelNewGameButton")
	if cancel_btn and is_inside_tree():
		cancel_btn.grab_focus()


func _on_cancel_new_game_pressed() -> void:
	_play_confirm_sfx()
	var modal: Control = confirm_modal if confirm_modal else get_node_or_null("%ConfirmNewGameModal")
	if modal:
		modal.visible = false
		modal.modulate.a = 0.0
	var btn: Button = play_button if play_button else get_node_or_null("%PlayButton")
	if btn and is_inside_tree():
		btn.grab_focus()


func _on_confirm_new_game_pressed() -> void:
	_play_confirm_sfx()
	var modal: Control = confirm_modal if confirm_modal else get_node_or_null("%ConfirmNewGameModal")
	if modal:
		modal.visible = false
	_start_fresh_new_game()


func _start_fresh_new_game() -> void:
	# Xóa sạch tiến trình cũ và nạp lại cấu hình ban đầu
	if SaveManager.instance:
		SaveManager.instance.reset_and_start_new_game()
	else:
		var sm = load("res://assets/scripts/core/save_manager.gd").new()
		sm.reset_and_start_new_game()
		sm.queue_free()
		
	start_game_loading(default_level_path)


# --- NÚT CONTINUE ---

func _on_continue_button_pressed() -> void:
	if is_loading or not SaveManager.has_save():
		return
	_play_confirm_sfx()
	
	var target_scene = default_level_path
	if SaveManager.instance:
		SaveManager.instance.load_from_disk()
		var respawn = SaveManager.instance.get_respawn_info()
		if respawn.get("has_checkpoint", false) and respawn.get("scene_path", "") != "":
			target_scene = respawn["scene_path"]
		else:
			target_scene = SaveManager.get_last_level(default_level_path)
	else:
		target_scene = SaveManager.get_last_level(default_level_path)
		
	start_game_loading(target_scene)


# --- NÚT SETTINGS & QUIT ---

func _on_settings_button_pressed() -> void:
	_play_confirm_sfx()
	var tween = create_tween()
	tween.tween_property(menu_buttons_container, "modulate:a", 0.0, 0.2)
	await tween.finished
	menu_buttons_container.visible = false
	if menu_pointer:
		menu_pointer.visible = false
	
	settings_panel.visible = true
	var tween_in = create_tween()
	tween_in.tween_property(settings_panel, "modulate:a", 1.0, 0.2)
	if settings_back_button:
		settings_back_button.grab_focus()


func _on_settings_back_pressed() -> void:
	_play_confirm_sfx()
	var tween = create_tween()
	tween.tween_property(settings_panel, "modulate:a", 0.0, 0.2)
	await tween.finished
	settings_panel.visible = false
	
	menu_buttons_container.visible = true
	var tween_in = create_tween()
	tween_in.tween_property(menu_buttons_container, "modulate:a", 1.0, 0.2)
	_update_continue_button_state()
	if play_button:
		play_button.grab_focus()


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
	_play_confirm_sfx()
	get_tree().quit()


# --- CHUYỂN CẢNH KÈM LOADING MƯỢT MÀ ---

func start_game_loading(scene_path: String) -> void:
	is_loading = true
	target_scene_to_load = scene_path
	
	var ptr = menu_pointer if menu_pointer else get_node_or_null("%MenuPointer")
	if ptr:
		ptr.visible = false
	
	# Ẩn cụm nút menu
	var buttons_box = menu_buttons_container if menu_buttons_container else get_node_or_null("%MenuButtonsContainer")
	if buttons_box:
		var menu_tween = create_tween()
		menu_tween.tween_property(buttons_box, "modulate:a", 0.0, 0.2)
		await menu_tween.finished
		buttons_box.visible = false
	
	# Hiện thanh loading bar
	var load_box = loading_container if loading_container else get_node_or_null("%LoadingContainer")
	var bar = loading_bar if loading_bar else get_node_or_null("%LoadingBar")
	var lbl = loading_label if loading_label else get_node_or_null("%LoadingLabel")
	
	if load_box and bar:
		load_box.visible = true
		bar.value = 0
		var load_show_tween = create_tween()
		load_show_tween.tween_property(load_box, "modulate:a", 1.0, 0.25)
		
		# Giả lập quá trình nạp tài nguyên mượt mà
		var progress_tween = create_tween()
		progress_tween.tween_property(bar, "value", 100.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		while progress_tween.is_running():
			if lbl:
				lbl.text = "LOADING... %d%%" % int(bar.value)
			await get_tree().process_frame
		
		if lbl:
			lbl.text = "READY!"
		
		await get_tree().create_timer(0.2).timeout
	
	# Fade toàn màn hình rồi chuyển Scene
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate", Color(0, 0, 0, 1), 0.3)
	await fade_out.finished
	
	get_tree().change_scene_to_file(target_scene_to_load)
