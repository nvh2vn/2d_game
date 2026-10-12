extends Control

@export_group("Background Music (BGM)")
@export var bgm_stream: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/menu.mp3")
@export var button_click_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Geo/geo_collect_0.mp3")
@export var button_hover_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Geo/geo_rock_hit_0.mp3")

@onready var master_slider: HSlider = %MasterSlider
@onready var master_val_label: Label = %MasterValLabel
@onready var bgm_slider: HSlider = %BGMSlider
@onready var bgm_val_label: Label = %BGMValLabel
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_val_label: Label = %SFXValLabel
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var customize_controls_button: Button = get_node_or_null("%CustomizeControlsButton")
@onready var back_button: Button = %BackButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var settings_panel: Control = get_node_or_null("%SettingsPanel")
@onready var sfx_player: AudioStreamPlayer = %SFXPlayer
@onready var bgm_player: AudioStreamPlayer = %BGMPlayer


func _ready() -> void:
	if bgm_player and bgm_stream:
		bgm_player.bus = &"Music"
		bgm_player.stream = bgm_stream
		if not bgm_player.playing:
			bgm_player.play()
			
	_init_sliders()
	_init_buttons()
	
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)


func _init_sliders() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx != -1 and master_slider:
		var db = AudioServer.get_bus_volume_db(master_idx)
		var is_mute = AudioServer.is_bus_mute(master_idx)
		var pct = 0 if is_mute else int(db_to_linear(db) * 100.0)
		master_slider.value = pct
		if master_val_label: master_val_label.text = "%d%%" % pct
		master_slider.value_changed.connect(_on_master_changed)
	
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx != -1 and bgm_slider:
		var db = AudioServer.get_bus_volume_db(music_idx)
		var is_mute = AudioServer.is_bus_mute(music_idx)
		var pct = 0 if is_mute else int(db_to_linear(db) * 100.0)
		bgm_slider.value = pct
		if bgm_val_label: bgm_val_label.text = "%d%%" % pct
		bgm_slider.value_changed.connect(_on_bgm_changed)

	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1 and sfx_slider:
		var db = AudioServer.get_bus_volume_db(sfx_idx)
		var is_mute = AudioServer.is_bus_mute(sfx_idx)
		var pct = 0 if is_mute else int(db_to_linear(db) * 100.0)
		sfx_slider.value = pct
		if sfx_val_label: sfx_val_label.text = "%d%%" % pct
		sfx_slider.value_changed.connect(_on_sfx_changed)
		
	if fullscreen_check:
		fullscreen_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)


func _init_buttons() -> void:
	if customize_controls_button:
		customize_controls_button.pressed.connect(_on_customize_controls_pressed)
		_setup_button_hover(customize_controls_button)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		_setup_button_hover(back_button)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
		_setup_button_hover(main_menu_button)


func _setup_button_hover(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		_play_sfx(button_hover_sfx)
		var tw = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
		tw.parallel().tween_property(btn, "modulate", Color(1.2, 1.2, 1.4, 1.0), 0.1)
	)
	btn.mouse_exited.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		tw.parallel().tween_property(btn, "modulate", Color.WHITE, 0.1)
	)


func _play_sfx(stream: AudioStream) -> void:
	if sfx_player and stream:
		sfx_player.stream = stream
		sfx_player.play()


func _on_master_changed(val: float) -> void:
	if master_val_label:
		master_val_label.text = "%d%%" % int(val)
	var idx = AudioServer.get_bus_index("Master")
	if idx != -1:
		if val <= 0:
			AudioServer.set_bus_mute(idx, true)
		else:
			AudioServer.set_bus_mute(idx, false)
			AudioServer.set_bus_volume_db(idx, linear_to_db(val / 100.0))


func _on_bgm_changed(val: float) -> void:
	if bgm_val_label:
		bgm_val_label.text = "%d%%" % int(val)
	var idx = AudioServer.get_bus_index("Music")
	if idx != -1:
		if val <= 0:
			AudioServer.set_bus_mute(idx, true)
		else:
			AudioServer.set_bus_mute(idx, false)
			AudioServer.set_bus_volume_db(idx, linear_to_db(val / 100.0))


func _on_sfx_changed(val: float) -> void:
	if sfx_val_label:
		sfx_val_label.text = "%d%%" % int(val)
	var idx = AudioServer.get_bus_index("SFX")
	if idx != -1:
		if val <= 0:
			AudioServer.set_bus_mute(idx, true)
		else:
			AudioServer.set_bus_mute(idx, false)
			AudioServer.set_bus_volume_db(idx, linear_to_db(val / 100.0))


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	_play_sfx(button_click_sfx)
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_customize_controls_pressed() -> void:
	_play_sfx(button_click_sfx)
	var touch_controls = get_node_or_null("TouchControls")
	if not touch_controls:
		var tc_scene = preload("res://assets/scenes/ui/touch_controls.tscn")
		touch_controls = tc_scene.instantiate()
		touch_controls.name = "TouchControls"
		add_child(touch_controls)
	
	if settings_panel:
		settings_panel.visible = false
	touch_controls.start_customizing(settings_panel)


func _on_back_pressed() -> void:
	_play_sfx(button_click_sfx)
	var target = SaveManager.return_scene_path
	if target == "" or target == scene_file_path:
		target = "res://assets/scenes/menu/main_menu.tscn"
	_transition_to_scene(target)


func _on_main_menu_pressed() -> void:
	_play_sfx(button_click_sfx)
	_transition_to_scene("res://assets/scenes/menu/main_menu.tscn")


func _transition_to_scene(scene_path: String) -> void:
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	get_tree().change_scene_to_file(scene_path)
