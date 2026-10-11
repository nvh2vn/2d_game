extends CanvasLayer

## Pause Menu & Mobile Pause Button dành cho Godot 4 2D Mobile.
## Tạm dừng toàn bộ gameplay khi mở menu và hỗ trợ lưu trạng thái an toàn.

@export_file("*.tscn") var main_menu_scene_path: String = "res://assets/scenes/menu/main_menu.tscn"

@export_group("UI Audio SFX")
@export var hover_sfx: AudioStream
@export var confirm_sfx: AudioStream

@onready var pause_button: TextureButton = %PauseButton
@onready var pause_overlay: Control = %PauseOverlay
@onready var resume_button: Button = %ResumeButton
@onready var restart_checkpoint_button: Button = %RestartCheckpointButton
@onready var main_menu_button: Button = %MainMenuButton

@onready var pause_pointer: TextureRect = %PausePointer
@onready var sfx_player: AudioStreamPlayer = %SFXPlayer

var is_paused: bool = false
var pointer_tween: Tween = null


func _ready() -> void:
	# Đảm bảo PauseMenu và toàn bộ cây con luôn nhận xử lý khi game bị Pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)
		pause_button.visible = true
		
	if pause_overlay:
		pause_overlay.visible = false
		pause_overlay.modulate.a = 0.0
		
	if pause_pointer:
		pause_pointer.visible = false
		pause_pointer.modulate.a = 0.0

	# Cấu hình các nút trong Pause Menu
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
		_setup_button_hover(resume_button)
		
	if restart_checkpoint_button:
		restart_checkpoint_button.pressed.connect(_on_restart_checkpoint_pressed)
		_setup_button_hover(restart_checkpoint_button)
		
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
		_setup_button_hover(main_menu_button)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		if is_paused:
			resume_game()
		else:
			pause_game()


func _on_pause_button_pressed() -> void:
	_play_confirm_sfx()
	pause_game()


func pause_game() -> void:
	if is_paused:
		return
	is_paused = true
	var tree = get_tree()
	if tree:
		tree.paused = true
	
	var btn = pause_button if pause_button else get_node_or_null("%PauseButton")
	if btn:
		btn.visible = false
		
	var overlay = pause_overlay if pause_overlay else get_node_or_null("%PauseOverlay")
	if overlay:
		overlay.visible = true
		overlay.modulate.a = 1.0
		
	var res_btn = resume_button if resume_button else get_node_or_null("%ResumeButton")
	if res_btn:
		if is_inside_tree():
			res_btn.grab_focus()
		_move_pointer_to(res_btn)


func resume_game() -> void:
	if not is_paused:
		return
	is_paused = false
	_play_confirm_sfx()
	
	var ptr = pause_pointer if pause_pointer else get_node_or_null("%PausePointer")
	if ptr:
		ptr.visible = false
		
	var overlay = pause_overlay if pause_overlay else get_node_or_null("%PauseOverlay")
	if overlay:
		overlay.visible = false
		overlay.modulate.a = 0.0
		
	var btn = pause_button if pause_button else get_node_or_null("%PauseButton")
	if btn:
		btn.visible = true
		
	var tree = get_tree()
	if tree:
		tree.paused = false


func _on_resume_pressed() -> void:
	resume_game()


func _on_restart_checkpoint_pressed() -> void:
	_play_confirm_sfx()
	is_paused = false
	get_tree().paused = false
	
	var target_scene = "res://assets/scenes/levels/map_1.tscn"
	if get_tree().current_scene and get_tree().current_scene.scene_file_path != "":
		target_scene = get_tree().current_scene.scene_file_path
		
	if SaveManager.instance:
		var respawn = SaveManager.instance.get_respawn_info()
		if respawn.get("has_checkpoint", false) and respawn.get("scene_path", "") != "":
			target_scene = respawn["scene_path"]
		else:
			target_scene = SaveManager.get_last_level(target_scene)
	else:
		target_scene = SaveManager.get_last_level(target_scene)
		
	get_tree().change_scene_to_file(target_scene)


func _on_main_menu_pressed() -> void:
	_play_confirm_sfx()
	
	# Tự động lưu tiến trình hiện tại qua SaveManager trước khi thoát về Menu
	if SaveManager.instance:
		SaveManager.instance.update_current_player_stats()
		SaveManager.instance.save_to_disk()
		
	is_paused = false
	var tree = get_tree()
	if tree:
		tree.paused = false
		tree.change_scene_to_file(main_menu_scene_path)


func _setup_button_hover(btn: Button) -> void:
	btn.mouse_entered.connect(func():
		if not is_paused or btn.disabled:
			return
		_move_pointer_to(btn)
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
		tween.tween_property(btn, "modulate", Color(1.2, 1.2, 1.3, 1.0), 0.1)
	)
	
	btn.focus_entered.connect(func():
		if not is_paused or btn.disabled:
			return
		_move_pointer_to(btn)
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
	)
	
	btn.mouse_exited.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(btn, "modulate", Color.WHITE, 0.1)
	)
	
	btn.focus_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)


func _move_pointer_to(btn: Button) -> void:
	if not pause_pointer or not is_instance_valid(btn):
		return
	
	pause_pointer.visible = true
	var target_y = btn.global_position.y + (btn.size.y - pause_pointer.size.y) * 0.5
	var target_x = btn.global_position.x - pause_pointer.size.x - 12.0
	
	if pointer_tween and pointer_tween.is_running():
		pointer_tween.kill()
		
	pointer_tween = create_tween().set_parallel(true)
	pointer_tween.tween_property(pause_pointer, "global_position:y", target_y, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pointer_tween.tween_property(pause_pointer, "global_position:x", target_x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pointer_tween.tween_property(pause_pointer, "modulate:a", 1.0, 0.1)
	
	_play_hover_sfx()


func _play_hover_sfx() -> void:
	if sfx_player and hover_sfx:
		sfx_player.stream = hover_sfx
		sfx_player.play()


func _play_confirm_sfx() -> void:
	if sfx_player and confirm_sfx:
		sfx_player.stream = confirm_sfx
		sfx_player.play()
