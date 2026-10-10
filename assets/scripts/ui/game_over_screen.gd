extends Control

@export_group("Sound Effects")
@export var game_over_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Player/sound_die.mp3")
@export var button_click_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Geo/geo_collect_0.mp3")
@export var button_hover_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Geo/geo_rock_hit_0.mp3")

@onready var replay_button: Button = %ReplayButton
@onready var home_button: Button = %HomeButton
@onready var settings_button: Button = %SettingsButton
@onready var warehouse_button: Button = %WarehouseButton

@onready var dark_overlay: ColorRect = %DarkOverlay
@onready var main_panel: PanelContainer = %MainPanel
@onready var cracked_mask: TextureRect = %CrackedMask
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var geo_label: Label = %GeoLabel
@onready var sfx_player: AudioStreamPlayer = %SFXPlayer

var current_level_path: String = "res://assets/scenes/levels/map_1.tscn"
var is_handling_action: bool = false


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_init_buttons()


func _init_buttons() -> void:
	if replay_button:
		replay_button.pressed.connect(_on_replay_pressed)
		_setup_button_hover(replay_button)
	if home_button:
		home_button.pressed.connect(_on_home_pressed)
		_setup_button_hover(home_button)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
		_setup_button_hover(settings_button)
	if warehouse_button:
		warehouse_button.pressed.connect(_on_warehouse_pressed)
		_setup_button_hover(warehouse_button)


func _setup_button_hover(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		if not is_handling_action:
			_play_sfx(button_hover_sfx)
			var tw = create_tween()
			tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
			tw.parallel().tween_property(btn, "modulate", Color(1.3, 1.2, 1.0, 1.0), 0.1)
	)
	btn.mouse_exited.connect(func():
		if not is_handling_action:
			var tw = create_tween()
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
			tw.parallel().tween_property(btn, "modulate", Color.WHITE, 0.1)
	)


func _play_sfx(stream: AudioStream) -> void:
	if sfx_player and stream:
		sfx_player.stream = stream
		sfx_player.play()


func trigger_game_over(geo_collected: int = 0, level_scene_path: String = "") -> void:
	is_handling_action = false
	if level_scene_path != "":
		current_level_path = level_scene_path
	else:
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.scene_file_path != "":
			current_level_path = current_scene.scene_file_path
			
	SaveManager.return_scene_path = current_level_path
	SaveManager.last_geo_collected = geo_collected
	
	if geo_label:
		geo_label.text = "%d GEO COLLECTED" % geo_collected

	# Dừng nhạc nền màn chơi để tạo không khí tử nạn trang nghiêm
	var level_root = get_tree().current_scene
	if level_root:
		var bgm = level_root.find_child("BGMPlayer", true, false)
		if bgm and bgm is AudioStreamPlayer and bgm.playing:
			var bgm_tw = create_tween()
			bgm_tw.tween_property(bgm, "volume_db", -40.0, 1.0)
	
	# Phát âm thanh Game Over SFX
	_play_sfx(game_over_sfx)
	
	# Bắt đầu hoạt ảnh xuất hiện hoành tráng
	visible = true
	modulate.a = 0.0
	main_panel.scale = Vector2(0.85, 0.85)
	main_panel.pivot_offset = main_panel.size * 0.5
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(main_panel, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Hiệu ứng nhịp đập / ánh sáng đỏ mờ ảo của Cracked Mask
	if cracked_mask:
		var mask_tw = create_tween().set_loops()
		mask_tw.tween_property(cracked_mask, "modulate", Color(1.8, 0.4, 0.4, 1.0), 1.2).set_trans(Tween.TRANS_SINE)
		mask_tw.tween_property(cracked_mask, "modulate", Color(1.0, 0.8, 0.8, 0.8), 1.2).set_trans(Tween.TRANS_SINE)


func _on_replay_pressed() -> void:
	if is_handling_action: return
	is_handling_action = true
	_play_sfx(button_click_sfx)
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	get_tree().change_scene_to_file(current_level_path)


func _on_home_pressed() -> void:
	if is_handling_action: return
	is_handling_action = true
	_play_sfx(button_click_sfx)
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	get_tree().change_scene_to_file("res://assets/scenes/menu/main_menu.tscn")


func _on_settings_pressed() -> void:
	if is_handling_action: return
	is_handling_action = true
	_play_sfx(button_click_sfx)
	SaveManager.return_scene_path = current_level_path
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	get_tree().change_scene_to_file("res://assets/scenes/menu/settings_screen.tscn")


func _on_warehouse_pressed() -> void:
	if is_handling_action: return
	is_handling_action = true
	_play_sfx(button_click_sfx)
	SaveManager.return_scene_path = current_level_path
	
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	await tw.finished
	get_tree().change_scene_to_file("res://assets/scenes/menu/inventory_screen.tscn")
