class_name LockedDoor
extends StaticBody2D

## Cánh cửa bị khóa (Locked Door) phong cách Hollow Knight / Metroidvania trong Godot 4.
## Cơ chế:
## 1. Ban đầu cửa khóa (is_locked = true), CollisionShape2D chặn vật lý người chơi.
## 2. Khi người chơi lại gần vùng tương tác (InteractionArea) và bấm "interact" / "ui_accept" / [E]:
##    - Nếu CÓ chìa khóa (mặc định "simple_key" từ Shop Tuk): Tiêu hao chìa khóa (nếu bật consume_key),
##      mở khóa, lưu trạng thái hoàn thành vào SaveManager, phát SFX và chạy animation "open".
##    - Nếu KHÔNG có chìa khóa: Phát SFX từ chối, rung lắc cánh cửa và hiển thị thông báo nổi.
## 3. Khi animation "open" hoàn tất: Tắt va chạm (disabled = true) để người chơi tự do đi qua.

signal door_unlocked()
signal door_opened()

@export_group("Door Identification & State")
## Mã ID định danh duy nhất của cánh cửa (dùng để lưu trạng thái đã mở vĩnh viễn vào SaveManager)
@export var door_id: String = "door_tuk_lock_01"
## Trạng thái cửa có đang bị khóa hay không
@export var is_locked: bool = true

@export_group("Key Requirement")
## ID vật phẩm chìa khóa cần có trong túi đồ (mặc định "simple_key" mua từ thương nhân Tuk)
@export var required_key_id: String = "simple_key"
## Tên hiển thị của chìa khóa trong câu thông báo khi bị khóa
@export var required_key_name: String = "Chìa khóa từ thương nhân Tuk"
## Có trừ (tiêu hao) chìa khóa sau khi mở cửa thành công hay không
@export var consume_key: bool = true

@export_group("Scene Transition / Boss Teleport")
## (Tùy chọn) Đường dẫn Scene phòng Boss hoặc map tiếp theo khi bước qua cửa
@export_file("*.tscn") var target_scene: String = "res://assets/scenes/levels/map_boss.tscn"
@export var target_spawn_id: String = ""
## Thời gian mờ đen màn hình khi bước vào cửa
@export var fade_transition_duration: float = 0.45

@export_group("Audio Configuration")
@export var unlock_sfx: AudioStream = preload("res://assets/art/2d/new_assets/Audio/Effects/UI/Radiance_ui_unlock.wav")
@export var open_sfx: AudioStream = preload("res://assets/art/2d/silksong_full/Sounds/Gate/gate_open.mp3")
@export var locked_sfx: AudioStream = preload("res://assets/art/2d/new_assets/Audio/Effects/Dream/dream_gate_fail.wav")

@export_group("Node References")
@onready var physical_collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")
@onready var boss_teleport_trigger: Area2D = get_node_or_null("BossTeleportTrigger")
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")
@onready var interact_prompt: Node2D = get_node_or_null("InteractPrompt")
@onready var message_label: Label = get_node_or_null("MessageLabel")

# Biến trạng thái nội bộ
var is_player_in_range: bool = false
var current_player: Node2D = null
var is_opening: bool = false
var is_teleporting: bool = false
var message_tween: Tween = null
var shake_tween: Tween = null


func _ready() -> void:
	# 1. Thêm vào group doors để dễ quản lý toàn cục
	add_to_group("doors")
	
	# 2. Cấu hình Collision cho StaticBody2D (Vật cản rắn chặn Player)
	# Layer 1 = World/Solid, Mask = 0 (StaticBody không cần quét va chạm)
	collision_layer = 1
	collision_mask = 0
	
	# 3. Khởi tạo SpriteFrames tự động từ folder nếu chưa gán trong Inspector
	_setup_sprite_frames_if_needed()
	
	# 4. Cấu hình InteractionArea (Vùng nhận diện Player tiếp cận)
	_setup_interaction_area()
	
	# 4b. Cấu hình BossTeleportTrigger (Vùng teleport chuyển map khi bước vào lòng cửa)
	_setup_boss_teleport_trigger()
	
	# 5. Kết nối tín hiệu kết thúc animation mở cửa
	if animated_sprite and not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
		
	# 6. Khởi tạo AudioStreamPlayer2D nếu thiếu
	if not audio_player:
		audio_player = AudioStreamPlayer2D.new()
		audio_player.name = "AudioStreamPlayer2D"
		audio_player.bus = &"SFX"
		add_child(audio_player)
		
	# 7. Kiểm tra trạng thái đã mở trước đó qua SaveManager (World State persistence)
	if SaveManager and SaveManager.is_event_completed(door_id):
		is_locked = false
		_apply_opened_state_immediate()
	else:
		if is_locked:
			_apply_locked_state_immediate()
		else:
			_apply_opened_state_immediate()
			
	# 8. Ẩn các UI prompt ban đầu
	if interact_prompt:
		interact_prompt.visible = false
	if message_label:
		message_label.visible = false
		message_label.modulate.a = 0.0


## Thiết lập InteractionArea quét Player (Layer 3 / Bitmask 4)
func _setup_interaction_area() -> void:
	if not interaction_area:
		interaction_area = get_node_or_null("InteractionArea")
		
	if interaction_area:
		interaction_area.collision_layer = 0
		# Player trong dự án này ở Layer 3 (1 << 2 = 4). Quét thêm Layer 1 & 2 để an toàn (mask = 255)
		interaction_area.collision_mask = 255
		
		if not interaction_area.body_entered.is_connected(_on_body_entered):
			interaction_area.body_entered.connect(_on_body_entered)
		if not interaction_area.body_exited.is_connected(_on_body_exited):
			interaction_area.body_exited.connect(_on_body_exited)


## Thiết lập BossTeleportTrigger (Vùng kích hoạt chuyển map khi bước vào lòng cửa)
func _setup_boss_teleport_trigger() -> void:
	if not boss_teleport_trigger:
		boss_teleport_trigger = get_node_or_null("BossTeleportTrigger")
		
	if not boss_teleport_trigger:
		boss_teleport_trigger = Area2D.new()
		boss_teleport_trigger.name = "BossTeleportTrigger"
		var col_shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36, 140)
		col_shape.shape = rect
		boss_teleport_trigger.add_child(col_shape)
		add_child(boss_teleport_trigger)
		
	boss_teleport_trigger.collision_layer = 0
	boss_teleport_trigger.collision_mask = 255
	# Ban đầu TẮT monitoring để không nhận va chạm khi cửa chưa mở
	boss_teleport_trigger.monitoring = false
	boss_teleport_trigger.monitorable = false
	
	if not boss_teleport_trigger.body_entered.is_connected(_on_boss_teleport_body_entered):
		boss_teleport_trigger.body_entered.connect(_on_boss_teleport_body_entered)



## Tự động tạo SpriteFrames từ thư mục res://assets/art/2d/door/ nếu chưa tạo sẵn
func _setup_sprite_frames_if_needed() -> void:
	if not animated_sprite:
		return
		
	if animated_sprite.sprite_frames != null:
		return
		
	var frames := SpriteFrames.new()
	
	# 1. Animation "locked" (Khung 26 - Cửa đóng chặt)
	var closed_path := "res://assets/art/2d/door/door_open0026.png"
	if ResourceLoader.exists(closed_path):
		var tex := load(closed_path) as Texture2D
		frames.add_animation("locked")
		frames.set_animation_loop("locked", false)
		frames.add_frame("locked", tex)
		
	# 2. Animation "open" (Khung 26 đến 32 - Hiệu ứng mở cửa)
	frames.add_animation("open")
	frames.set_animation_loop("open", false)
	frames.set_animation_speed("open", 10.0)
	for i in range(26, 33):
		var frame_num := str(i).pad_zeros(4)
		var frame_path := "res://assets/art/2d/door/door_open" + frame_num + ".png"
		if ResourceLoader.exists(frame_path):
			var tex := load(frame_path) as Texture2D
			if tex:
				frames.add_frame("open", tex)
				
	# 3. Animation "opened" (Khung 32 - Cửa đã mở toang)
	var opened_path := "res://assets/art/2d/door/door_open0032.png"
	if ResourceLoader.exists(opened_path):
		var tex := load(opened_path) as Texture2D
		frames.add_animation("opened")
		frames.set_animation_loop("opened", false)
		frames.add_frame("opened", tex)
		
	animated_sprite.sprite_frames = frames


# ==============================================================================
# XỬ LÝ SỰ KIỆN TƯƠNG TÁC (INPUT & INTERACTION)
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_in_range or is_opening:
		return
		
	# Bắt các phím tương tác phổ biến: "interact", "ui_accept", "ui_up", E, W, Up Arrow, Space, Enter
	var is_interact_action: bool = (
		event.is_action_pressed("interact") or 
		event.is_action_pressed("ui_accept") or 
		event.is_action_pressed("ui_up") or
		(event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_W, KEY_UP, KEY_ENTER, KEY_SPACE])
	)
	
	if is_interact_action:
		interact()
		get_viewport().set_input_as_handled()


## Hàm tương tác chính được gọi khi bấm phím hoặc nhấn nút trên màn hình cảm ứng
func interact() -> void:
	if not is_player_in_range or is_opening:
		return
		
	# Trường hợp 1: Cửa ĐÃ MỞ (chỉ chuyển cảnh nếu người chơi bấm tương tác trực tiếp)
	if not is_locked:
		if target_scene != "" and not is_teleporting:
			_on_boss_teleport_body_entered(current_player)
		return
		
	# Trường hợp 2: Cửa ĐANG KHÓA -> Kiểm tra chìa khóa
	if _has_required_key():
		_unlock_and_open_door()
	else:
		_show_locked_warning()


# ==============================================================================
# KIỂM TRA & TIÊU HAO CHÌA KHÓA
# ==============================================================================

## Kiểm tra xem người chơi có chìa khóa hợp lệ hay không qua nhiều nguồn dự phòng
func _has_required_key() -> bool:
	# 1. Kiểm tra qua SaveManager Singleton (Chính xác nhất trong dự án)
	if SaveManager:
		if SaveManager.has_method("has_inventory_item") and SaveManager.has_inventory_item(required_key_id):
			return true
		if SaveManager.has_method("has_item") and SaveManager.has_item(required_key_id):
			return true
			
	# 2. Kiểm tra nếu có Autoload InventoryManager
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr:
		if inv_mgr.has_method("has_item") and inv_mgr.has_item(required_key_id):
			return true
			
	# 3. Kiểm tra nếu có Autoload GameManager
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if gm.has_method("has_item") and gm.has_item(required_key_id):
			return true
		if "has_tuk_key" in gm and gm.has_tuk_key:
			return true
			
	# 4. Kiểm tra trực tiếp trên Node Player
	if is_instance_valid(current_player):
		if current_player.has_method("has_item") and current_player.has_item(required_key_id):
			return true
		if "inventory" in current_player and current_player.inventory is Array:
			for it in current_player.inventory:
				if (it is Dictionary and it.get("id", "") == required_key_id) or (it is String and it == required_key_id):
					return true
					
	return false


## Tiêu hao chìa khóa khỏi túi đồ
func _consume_required_key() -> void:
	if not consume_key:
		return
		
	# 1. Trừ qua SaveManager
	if SaveManager and SaveManager.has_method("remove_inventory_item"):
		SaveManager.remove_inventory_item(required_key_id, 1)
		
	# 2. Trừ qua InventoryManager nếu có
	var inv_mgr = get_node_or_null("/root/InventoryManager")
	if inv_mgr and inv_mgr.has_method("remove_item"):
		inv_mgr.remove_item(required_key_id)
		
	# 3. Trừ trên Player Node nếu có
	if is_instance_valid(current_player):
		if current_player.has_method("remove_item"):
			current_player.remove_item(required_key_id)
		elif "inventory" in current_player and current_player.inventory is Array:
			for i in range(current_player.inventory.size()):
				var it = current_player.inventory[i]
				if (it is Dictionary and it.get("id", "") == required_key_id) or (it is String and it == required_key_id):
					current_player.inventory.remove_at(i)
					break


# ==============================================================================
# TIẾN TRÌNH MỞ KHÓA & ANIMATION
# ==============================================================================

## Thực hiện mở khóa và kích hoạt animation mở cửa
func _unlock_and_open_door() -> void:
	is_locked = false
	is_opening = true
	
	# Tiêu hao chìa khóa
	_consume_required_key()
	
	# Lưu trạng thái cửa đã mở vĩnh viễn vào SaveManager
	if SaveManager:
		SaveManager.set_event_completed(door_id, true)
		
	# Phát âm thanh mở khóa
	if audio_player and unlock_sfx:
		audio_player.stream = unlock_sfx
		audio_player.play()
		
	# Ẩn nút tương tác và prompt
	if interact_prompt:
		interact_prompt.visible = false
	TouchControls.hide_interact(get_tree())
	
	door_unlocked.emit()
	print_rich("[color=green][LockedDoor][/color] Mở khóa thành công cánh cửa: [b]%s[/b]" % door_id)
	
	# Đợi nhẹ một nhịp sau tiếng lách cách mở khóa rồi phát âm thanh và animation mở cửa
	await get_tree().create_timer(0.25).timeout
	
	if audio_player and open_sfx:
		audio_player.stream = open_sfx
		audio_player.play()
		
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("open"):
			animated_sprite.play("open")
		else:
			_on_animation_finished()
	else:
		_on_animation_finished()


## Gọi khi animation mở cửa chạy xong
func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "open":
		is_opening = false
		
		# 1. TẮT VA CHẠM VẬT LÝ để người chơi tự do đi qua
		if physical_collision:
			physical_collision.set_deferred("disabled", true)
			
		# 2. Giữ nguyên hình ảnh cửa mở toang
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("opened"):
			animated_sprite.play("opened")
		else:
			animated_sprite.stop()
			
		door_opened.emit()
		print_rich("[color=cyan][LockedDoor][/color] Cửa đã mở hoàn toàn! CollisionShape2D disabled = true.")
		
		# 3. KÍCH HOẠT VÙNG TELEPORT khi người chơi bước vào sâu bên trong cửa
		if boss_teleport_trigger and target_scene != "":
			boss_teleport_trigger.set_deferred("monitoring", true)
			print_rich("[color=green][LockedDoor][/color] Đã kích hoạt BossTeleportTrigger (monitoring = true). Bước vào cửa để vào map_boss!")
			
		# 4. Khi tương tác mở cửa hoàn tất: Ẩn nút tương tác và prompt
		_update_prompt_text()
		if interact_prompt:
			interact_prompt.visible = false
		TouchControls.hide_interact(get_tree())


# ==============================================================================
# PHẢN HỒI KHI THIẾU CHÌA KHÓA (WARNING & FEEDBACK)
# ==============================================================================

## Xử lý khi người chơi cố mở cửa mà không có chìa khóa
func _show_locked_warning() -> void:
	# 1. Phát âm thanh từ chối / ổ khóa kẹt
	if audio_player and locked_sfx:
		audio_player.stream = locked_sfx
		audio_player.play()
		
	# 2. Rung lắc nhẹ cánh cửa (Shake Effect)
	_play_door_shake()
	
	# 3. Hiển thị thông báo nổi lên màn hình
	var warning_msg := "Cần %s để mở!" % required_key_name
	print_rich("[color=yellow][LockedDoor][/color] %s" % warning_msg)
	_display_floating_message(warning_msg)


## Hiệu ứng rung lắc cửa khi kẹt khóa
func _play_door_shake() -> void:
	if not animated_sprite:
		return
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
		
	var orig_pos := animated_sprite.position
	shake_tween = create_tween()
	shake_tween.tween_property(animated_sprite, "position", orig_pos + Vector2(-5, 0), 0.04)
	shake_tween.tween_property(animated_sprite, "position", orig_pos + Vector2(5, 0), 0.04)
	shake_tween.tween_property(animated_sprite, "position", orig_pos + Vector2(-3, 0), 0.04)
	shake_tween.tween_property(animated_sprite, "position", orig_pos + Vector2(3, 0), 0.04)
	shake_tween.tween_property(animated_sprite, "position", orig_pos, 0.04)


## Hiển thị nhãn thông báo bay lên và mờ dần
func _display_floating_message(msg: String) -> void:
	if not message_label:
		message_label = Label.new()
		message_label.name = "MessageLabel"
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		message_label.position = Vector2(-150, -110)
		message_label.size = Vector2(300, 30)
		message_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
		message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
		message_label.add_theme_constant_override("outline_size", 4)
		add_child(message_label)

	message_label.text = msg
	message_label.visible = true
	message_label.modulate.a = 1.0
	message_label.scale = Vector2(0.8, 0.8)
	message_label.pivot_offset = message_label.size * 0.5
	
	if message_tween and message_tween.is_valid():
		message_tween.kill()
		
	var base_y := -110.0
	message_label.position.y = base_y
	
	message_tween = create_tween()
	# Pop in scale
	message_tween.tween_property(message_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Bay nhẹ lên trên
	message_tween.parallel().tween_property(message_label, "position:y", base_y - 25.0, 2.0)
	# Mờ dần về cuối
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6).set_delay(1.2)
	message_tween.tween_callback(func(): message_label.visible = false)


# ==============================================================================
# NHẬN DIỆN VÙNG PLAYER (PROXIMITY & TOUCH BUTTON)
# ==============================================================================

func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		current_player = body
		_set_player_in_range(true)


func _on_body_exited(body: Node2D) -> void:
	if body == current_player or _is_player(body):
		_set_player_in_range(false)
		current_player = null


func _is_player(node: Node2D) -> bool:
	if not node:
		return false
	return node.is_in_group("player") or node.name.begins_with("Player") or node.has_method("trigger_hazard_reset")


func _set_player_in_range(in_range: bool) -> void:
	is_player_in_range = in_range
	_update_prompt_text()
	
	# Icon và prompt CHỈ hiện khi Player ở gần VÀ cửa ĐANG KHÓA (chưa hoàn tất mở)
	# Khi cửa đã mở: Ẩn icon đi để người chơi tự do bước qua
	var can_interact: bool = in_range and is_locked and not is_opening and not is_teleporting
	
	if interact_prompt:
		interact_prompt.visible = can_interact
		if can_interact:
			interact_prompt.scale = Vector2(0.5, 0.5)
			var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(interact_prompt, "scale", Vector2.ONE, 0.15)
			
	if can_interact:
		TouchControls.show_interact(get_tree(), "locked_door")
	else:
		TouchControls.hide_interact(get_tree())


func _update_prompt_text() -> void:
	if not interact_prompt:
		return
	var lbl := interact_prompt.get_node_or_null("Label") as Label
	if not lbl:
		return
		
	if is_locked:
		lbl.text = "[E] Mở Cửa (Cần Chìa Khóa)"
	else:
		lbl.text = ""


func _apply_locked_state_immediate() -> void:
	is_locked = true
	is_opening = false
	if physical_collision:
		physical_collision.set_deferred("disabled", false)
	if boss_teleport_trigger:
		boss_teleport_trigger.set_deferred("monitoring", false)
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("locked"):
			animated_sprite.play("locked")
		else:
			animated_sprite.frame = 0
			animated_sprite.stop()
	_update_prompt_text()


func _apply_opened_state_immediate() -> void:
	is_locked = false
	is_opening = false
	if physical_collision:
		physical_collision.set_deferred("disabled", true)
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("opened"):
			animated_sprite.play("opened")
		elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("open"):
			var count: int = animated_sprite.sprite_frames.get_frame_count("open")
			animated_sprite.play("open")
			animated_sprite.frame = count - 1
			animated_sprite.stop()
	if interact_prompt:
		interact_prompt.visible = false
		
	# Nếu cửa đã mở sẵn từ trước, kích hoạt trigger teleport để người chơi bước vào
	if boss_teleport_trigger and target_scene != "":
		boss_teleport_trigger.set_deferred("monitoring", true)


# ==============================================================================
# XỬ LÝ CHUYỂN MAP QUA BOSS TELEPORT TRIGGER
# ==============================================================================

## Kích hoạt khi Player điều khiển nhân vật bước vào sâu bên trong cửa đã mở
func _on_boss_teleport_body_entered(body: Node2D) -> void:
	if not _is_player(body) or is_teleporting or target_scene == "":
		return
		
	# 1. Ngắt ngay monitoring để tránh trigger lặp lại nhiều lần
	is_teleporting = true
	if boss_teleport_trigger:
		boss_teleport_trigger.set_deferred("monitoring", false)
		
	print_rich("[color=yellow][LockedDoor][/color] Player đã bước vào cửa! Bắt đầu chuyển scene sang: [b]%s[/b]" % target_scene)
	
	if interact_prompt:
		interact_prompt.visible = false
	TouchControls.hide_interact(get_tree())
	
	# 2. Xử lý hiệu ứng mờ dần và load scene map_boss
	_execute_boss_transition(body)


func _execute_boss_transition(player: Node2D) -> void:
	# Dừng vận tốc để nhân vật không bị trôi khi đổi cảnh
	if player and "velocity" in player:
		player.velocity = Vector2.ZERO
		
	# Tìm FadeRect trên Player hoặc màn chơi để tạo hiệu ứng Fade Out mượt mà
	var fade_rect: CanvasItem = null
	if player:
		fade_rect = player.find_child("FadeRect", true, false)
	if not fade_rect and get_tree().current_scene:
		fade_rect = get_tree().current_scene.find_child("FadeRect", true, false)
		
	if fade_rect:
		fade_rect.visible = true
		var tw := create_tween()
		tw.tween_property(fade_rect, "modulate:a", 1.0, fade_transition_duration)
		await tw.finished
	else:
		var p_sprite = player.get_node_or_null("%AnimatedSprite") if player else null
		if p_sprite:
			var tw := create_tween()
			tw.tween_property(p_sprite, "modulate:a", 0.0, 0.3)
			await tw.finished
		else:
			await get_tree().create_timer(0.2).timeout
			
	# Lưu map gần nhất vào SaveManager
	if SaveManager:
		SaveManager.save_last_level(target_scene)
		
	# Chuyển scene sang map_boss
	var err := get_tree().change_scene_to_file(target_scene)
	if err != OK:
		push_error("[LockedDoor] Lỗi chuyển scene sang %s: mã lỗi %d" % [target_scene, err])
		is_teleporting = false
		if boss_teleport_trigger:
			boss_teleport_trigger.set_deferred("monitoring", true)
