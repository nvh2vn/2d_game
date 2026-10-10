extends Control

@export_group("Background Music (BGM)")
@export var bgm_stream: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/menu.mp3")
@export var button_click_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Geo/geo_collect_0.mp3")
@export var button_hover_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Geo/geo_rock_hit_0.mp3")

@onready var geo_count_label: Label = %GeoCountLabel
@onready var back_button: Button = %BackButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var sfx_player: AudioStreamPlayer = %SFXPlayer
@onready var bgm_player: AudioStreamPlayer = %BGMPlayer
@onready var last_level_label: Label = %LastLevelLabel


func _ready() -> void:
	if bgm_player and bgm_stream:
		bgm_player.bus = &"Music"
		bgm_player.stream = bgm_stream
		if not bgm_player.playing:
			bgm_player.play()
			
	_display_stats()
	_init_buttons()
	
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)


func _display_stats() -> void:
	var total_geo = SaveManager.get_geo()
	if SaveManager.last_geo_collected > 0:
		total_geo = maxi(total_geo, SaveManager.last_geo_collected)
	if geo_count_label:
		geo_count_label.text = "%d GEO" % total_geo
		
	if last_level_label:
		var last_scene = SaveManager.get_last_level()
		var scene_name = last_scene.get_file().get_basename().capitalize()
		last_level_label.text = "LAST EXPLORED: %s" % scene_name


func _init_buttons() -> void:
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
