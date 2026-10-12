extends Node

## Singleton Autoload quản lý Lưu / Đọc dữ liệu (Save/Load) tập trung cho tựa game Metroidvania trên Mobile.
## Tự động mã hóa file save trên thiết bị (Android/iOS) bằng FileAccess.open_encrypted_with_pass.
## Hỗ trợ vòng đời Mobile (_notification), Checkpoint hồi sinh và World State Event tracking.

# --- CẤU HÌNH ĐƯỜNG DẪN & MÃ HÓA ---
const SAVE_FILE_PATH: String = "user://save_data.dat"
const ENCRYPTION_KEY: String = "HK_Mobile_Save_Key_2026_Secure"

# Tham chiếu Singleton đang chạy
static var instance: Node = null

# Biến tạm thời trong phiên chơi (Tương thích ngược)
static var return_scene_path: String = "res://assets/scenes/menu/main_menu.tscn"
static var last_geo_collected: int = 0
static var last_bench_pos: Vector2 = Vector2.ZERO
static var last_bench_scene: String = ""

# --- CẤU TRÚC DỮ LIỆU LƯU (SAVE DATA DICTIONARY) ---
var save_data: Dictionary = {
	"version": 1,
	"timestamp": 0,
	"player": {
		"current_health": 5,
		"max_health": 5,
		"geo": 0,
		"current_silk": 4,
		"max_silk": 4,
		"skills": {
			"dash": true,
			"double_jump": false,
			"wall_climb": false,
			"float": false
		}
	},
	"inventory": [
		{
			"id": "city_key",
			"name": "City Crest",
			"desc": "Chìa khóa đá cổ mang biểu tượng vương quốc, dùng để mở các cánh cổng cơ quan ngầm.",
			"icon": "res://assets/art/Inventory & UI/inv_item_city_key.png",
			"category": "key"
		},
		{
			"id": "hallownest_map",
			"name": "Bản Đồ Phế Tích",
			"desc": "Tấm giấy da ghi chép mạng lưới địa hình và các ngóc ngách đã từng đi qua.",
			"icon": "res://assets/art/Inventory & UI/inv_item__0006_area_map.png",
			"category": "map"
		},
		{
			"id": "pale_ore",
			"name": "Mảnh Quặng Cổ (Pale Ore)",
			"desc": "Kim loại cổ màu nhợt nhạt hiếm có, tỏa ra hơi lạnh. Dùng để tôi luyện và nâng cấp vũ khí.",
			"icon": "res://assets/art/Inventory & UI/inv_item__0009_ore.png",
			"category": "upgrade"
		}
	],
	"quests": {
		"ancient_whispers": {
			"id": "ancient_whispers",
			"title": "Dấu Vết Cổ Xưa (Ancient Whispers)",
			"desc": "Một nguồn năng lượng bí ẩn đang lan tỏa khắp khu phế tích. Hãy khám phá sâu hơn vào lòng đất...",
			"objective": "Khám phá vùng đất chưa biết (0/1)",
			"status": "active",
			"icon_path": "res://assets/art/2d/Achievements/achievement__0014_dream_witch_quest_end.png"
		}
	},
	"hunter_journal": {},
	"shop_purchases": {}, # Lưu trạng thái { "item_id": true/false }
	"checkpoint": {
		"has_checkpoint": false,
		"scene_path": "res://assets/scenes/levels/map_1.tscn",
		"spawn_pos_x": 0.0,
		"spawn_pos_y": 0.0
	},
	"world_state": {
		"last_scene": "res://assets/scenes/levels/map_1.tscn",
		"completed_events": [], # Danh sách Event ID: Boss hạ gục, cửa mở, nhặt item...
		"unlocked_waypoints": []
	},
	"shade": {
		"active": false,
		"scene_path": "",
		"pos_x": 0.0,
		"pos_y": 0.0,
		"geo": 0
	}
}


func _enter_tree() -> void:
	if instance == null:
		instance = self
	load_from_disk()


func _ready() -> void:
	if instance == null:
		instance = self


# --- VÒNG ĐỜI MOBILE (MOBILE APPLICATION LIFECYCLE) ---
func _notification(what: int) -> void:
	match what:
		# Người chơi ấn nút Home hoặc chuyển sang ứng dụng khác trên Android/iOS
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			_auto_save_on_mobile_pause()


## Tự động lưu tức thì khi ứng dụng bị tạm dừng / đóng (Bảo toàn dữ liệu mới nhất từ Player)
func _auto_save_on_mobile_pause() -> void:
	# 1. Luôn cập nhật trạng thái thời gian thực mới nhất từ Player node (HP, Coins, Energy/Silk,...)
	update_current_player_stats()
	# 2. Vị trí hồi sinh (spawn_position) và scene Checkpoint vẫn giữ nguyên tọa độ Bench gần nhất
	# 3. Ghi dữ liệu an toàn xuống đĩa
	save_to_disk()


# --- GHI & ĐỌC DỮ LIỆU MÃ HÓA (ENCRYPTED FILE ACCESS) ---

## Ghi toàn bộ dữ liệu xuống đĩa với mã hóa mật khẩu
func save_to_disk() -> bool:
	save_data["timestamp"] = Time.get_unix_time_from_system()
	var json_string = JSON.stringify(save_data)
	
	var file = FileAccess.open_encrypted_with_pass(SAVE_FILE_PATH, FileAccess.WRITE, ENCRYPTION_KEY)
	if not file:
		var err = FileAccess.get_open_error()
		push_error("[SaveManager] Không thể tạo file save mã hóa! Lỗi: %d" % err)
		return false
		
	file.store_string(json_string)
	file.close()
	return true


## Đọc và giải mã dữ liệu từ đĩa
func load_from_disk() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		if FileAccess.file_exists("user://save_data.cfg"):
			return _migrate_from_legacy_cfg()
		return false
		
	var file = FileAccess.open_encrypted_with_pass(SAVE_FILE_PATH, FileAccess.READ, ENCRYPTION_KEY)
	if not file:
		var err = FileAccess.get_open_error()
		push_error("[SaveManager] Lỗi giải mã file save! Lỗi: %d" % err)
		return false
		
	var content = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(content)
	if typeof(parsed) == TYPE_DICTIONARY:
		# Hợp nhất dữ liệu đã lưu vào dictionary chuẩn
		_merge_dictionary(save_data, parsed)
		# Đồng bộ biến static tương thích ngược
		var cp = save_data.get("checkpoint", {})
		if cp.get("has_checkpoint", false):
			last_bench_pos = Vector2(cp.get("spawn_pos_x", 0.0), cp.get("spawn_pos_y", 0.0))
			last_bench_scene = cp.get("scene_path", "")
		return true
		
	return false


## Tự động chuyển đổi dữ liệu từ file cấu hình cũ (save_data.cfg) sang file mã hóa mới
func _migrate_from_legacy_cfg() -> bool:
	var cfg = ConfigFile.new()
	var err = cfg.load("user://save_data.cfg")
	if err != OK:
		return false
		
	var bx = cfg.get_value("checkpoint", "bench_x", 0.0)
	var by = cfg.get_value("checkpoint", "bench_y", 0.0)
	var scene = cfg.get_value("checkpoint", "scene", "")
	if bx != 0.0 or by != 0.0:
		save_data["checkpoint"] = {
			"has_checkpoint": true,
			"scene_path": scene,
			"spawn_pos_x": bx,
			"spawn_pos_y": by
		}
		last_bench_pos = Vector2(bx, by)
		last_bench_scene = scene
		
	save_data["world_state"]["last_scene"] = cfg.get_value("game", "last_scene", "res://assets/scenes/levels/map_1.tscn")
	save_data["player"]["geo"] = cfg.get_value("player", "geo", 0)
	
	var shade_active = cfg.get_value("shade", "active", false)
	if shade_active:
		save_data["shade"] = {
			"active": true,
			"scene_path": cfg.get_value("shade", "scene", ""),
			"pos_x": cfg.get_value("shade", "x", 0.0),
			"pos_y": cfg.get_value("shade", "y", 0.0),
			"geo": cfg.get_value("shade", "geo", 0)
		}
		
	save_to_disk()
	return true


## Kiểm tra xem có file save hợp lệ trên thiết bị hay không
static func has_save() -> bool:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		return true
	# Kiểm tra thêm đường dẫn cũ nếu có
	return FileAccess.file_exists("user://save_data.cfg")


## Xóa sạch toàn bộ dữ liệu lưu và đưa mọi trạng thái (stats, shop, inventory, world) về mặc định khi bắt đầu New Game
func reset_and_start_new_game() -> void:
	delete_save()


## Xóa trắng file save và reset toàn bộ trạng thái để chơi New Game
func delete_save() -> void:
	var da = DirAccess.open("user://")
	if da:
		if da.file_exists("save_data.dat"):
			da.remove("save_data.dat")
		if da.file_exists("save_data.cfg"):
			da.remove("save_data.cfg")
		if da.file_exists("shop_data.cfg"):
			da.remove("shop_data.cfg")
			
	# Reset trạng thái Shop trong ShopMenu
	var shop_script = load("res://assets/scripts/ui/shop_menu.gd")
	if shop_script and shop_script.has_method("reset_shop_state"):
		shop_script.reset_shop_state()
		
	# Reset Waypoints trong TeleportManager
	if is_inside_tree() and get_tree() and get_tree().root:
		var tm = get_tree().root.get_node_or_null("TeleportManager")
		if tm and "unlocked_waypoints" in tm:
			tm.unlocked_waypoints.clear()
		
	last_bench_pos = Vector2.ZERO
	last_bench_scene = ""
	last_geo_collected = 0
	_reset_to_default()


func _reset_to_default() -> void:
	save_data = {
		"version": 1,
		"timestamp": 0,
		"player": {
			"current_health": 5,
			"max_health": 5,
			"geo": 0,
			"current_silk": 4,
			"max_silk": 4,
			"skills": {
				"dash": true,
				"double_jump": false,
				"wall_climb": false,
				"float": false
			}
		},
		"inventory": [
			{
				"id": "city_key",
				"name": "City Crest",
				"desc": "Chìa khóa đá cổ mang biểu tượng vương quốc, dùng để mở các cánh cổng cơ quan ngầm.",
				"icon": "res://assets/art/Inventory & UI/inv_item_city_key.png",
				"category": "key"
			},
			{
				"id": "hallownest_map",
				"name": "Bản Đồ Phế Tích",
				"desc": "Tấm giấy da ghi chép mạng lưới địa hình và các ngóc ngách đã từng đi qua.",
				"icon": "res://assets/art/Inventory & UI/inv_item__0006_area_map.png",
				"category": "map"
			},
			{
				"id": "pale_ore",
				"name": "Mảnh Quặng Cổ (Pale Ore)",
				"desc": "Kim loại cổ màu nhợt nhạt hiếm có, tỏa ra hơi lạnh. Dùng để tôi luyện và nâng cấp vũ khí.",
				"icon": "res://assets/art/Inventory & UI/inv_item__0009_ore.png",
				"category": "upgrade"
			}
		],
		"quests": {
			"ancient_whispers": {
				"id": "ancient_whispers",
				"title": "Dấu Vết Cổ Xưa (Ancient Whispers)",
				"desc": "Một nguồn năng lượng bí ẩn đang lan tỏa khắp khu phế tích. Hãy khám phá sâu hơn vào lòng đất...",
				"objective": "Khám phá vùng đất chưa biết (0/1)",
				"status": "active",
				"icon_path": "res://assets/art/2d/Achievements/achievement__0014_dream_witch_quest_end.png"
			}
		},
		"hunter_journal": {},
		"shop_purchases": {},
		"checkpoint": {
			"has_checkpoint": false,
			"scene_path": "res://assets/scenes/levels/map_1.tscn",
			"spawn_pos_x": 0.0,
			"spawn_pos_y": 0.0
		},
		"world_state": {
			"last_scene": "res://assets/scenes/levels/map_1.tscn",
			"completed_events": [],
			"unlocked_waypoints": []
		},
		"shade": {
			"active": false,
			"scene_path": "",
			"pos_x": 0.0,
			"pos_y": 0.0,
			"geo": 0
		}
	}
	last_bench_pos = Vector2.ZERO
	last_bench_scene = ""
	last_geo_collected = 0


# --- ĐỒNG BỘ DỮ LIỆU PLAYER (PLAYER SYNC) ---

## Thu thập và đồng bộ các chỉ số thực tế (current_hp, coins, energy, skills, inventory) từ Player instance trong Scene
func update_current_player_stats(player_node: Node = null) -> bool:
	var player = player_node if player_node != null else _get_active_player()
	if not is_instance_valid(player):
		return false
		
	var p_data: Dictionary = save_data.get("player", {})
	
	# 1. HP / Health
	if "current_health" in player:
		p_data["current_health"] = player.current_health
	elif "current_hp" in player:
		p_data["current_health"] = player.current_hp
	elif "health" in player:
		p_data["current_health"] = player.health
	elif "hp" in player:
		p_data["current_health"] = player.hp
		
	if "max_health" in player:
		p_data["max_health"] = player.max_health
	elif "max_hp" in player:
		p_data["max_health"] = player.max_hp
		
	# 2. Geo / Coins
	if "geo_amount" in player:
		p_data["geo"] = player.geo_amount
		last_geo_collected = player.geo_amount
	elif "geo" in player:
		p_data["geo"] = player.geo
		last_geo_collected = player.geo
	elif "coins" in player:
		p_data["geo"] = player.coins
		last_geo_collected = player.coins
	elif "coin" in player:
		p_data["geo"] = player.coin
		last_geo_collected = player.coin
		
	# 3. Silk / Energy
	if "current_silk" in player:
		p_data["current_silk"] = player.current_silk
	elif "current_energy" in player:
		p_data["current_silk"] = player.current_energy
	elif "silk" in player:
		p_data["current_silk"] = player.silk
	elif "energy" in player:
		p_data["current_silk"] = player.energy
		
	if "max_silk" in player:
		p_data["max_silk"] = player.max_silk
	elif "max_energy" in player:
		p_data["max_silk"] = player.max_energy
		
	# 4. Kỹ năng (Skills)
	var skills: Dictionary = p_data.get("skills", {})
	if "unlock_dash" in player:
		skills["dash"] = player.unlock_dash
	if "unlock_double_jump" in player:
		skills["double_jump"] = player.unlock_double_jump
	if "unlock_wall_climb" in player:
		skills["wall_climb"] = player.unlock_wall_climb
	if "unlock_float" in player:
		skills["float"] = player.unlock_float
	p_data["skills"] = skills
	
	# 5. Inventory (Túi đồ nếu có)
	if "inventory" in player and player.inventory is Array:
		save_data["inventory"] = player.inventory.duplicate()
		
	save_data["player"] = p_data
	return true


## Hàm bọc tương thích gọi update_current_player_stats
func sync_from_player(player: Node) -> void:
	update_current_player_stats(player)


## Nạp dữ liệu lưu áp dụng lên PlayerController
func apply_to_player(player: Node) -> void:
	if not is_instance_valid(player):
		return
		
	var p_data = save_data.get("player", {})
	if "max_health" in player and p_data.has("max_health"):
		player.max_health = p_data["max_health"]
	if "current_health" in player and p_data.has("current_health"):
		var saved_hp = p_data["current_health"]
		player.current_health = saved_hp if saved_hp > 0 else player.max_health
	elif "current_hp" in player and p_data.has("current_health"):
		var saved_hp = p_data["current_health"]
		player.current_hp = saved_hp if saved_hp > 0 else player.max_health
		
	if "geo_amount" in player and p_data.has("geo"):
		player.geo_amount = p_data["geo"]
	elif "geo" in player and p_data.has("geo"):
		player.geo = p_data["geo"]
	elif "coins" in player and p_data.has("geo"):
		player.coins = p_data["geo"]
		
	if "current_silk" in player and p_data.has("current_silk"):
		player.current_silk = p_data["current_silk"]
	elif "current_energy" in player and p_data.has("current_silk"):
		player.current_energy = p_data["current_silk"]
		
	if "max_silk" in player and p_data.has("max_silk"):
		player.max_silk = p_data["max_silk"]
	elif "max_energy" in player and p_data.has("max_silk"):
		player.max_energy = p_data["max_silk"]
		
	var skills = p_data.get("skills", {})
	if "unlock_dash" in player and skills.has("dash"):
		player.unlock_dash = skills["dash"]
	if "unlock_double_jump" in player and skills.has("double_jump"):
		player.unlock_double_jump = skills["double_jump"]
	if "unlock_wall_climb" in player and skills.has("wall_climb"):
		player.unlock_wall_climb = skills["wall_climb"]
	if "unlock_float" in player and skills.has("float"):
		player.unlock_float = skills["float"]
		
	if "inventory" in player and save_data.has("inventory") and save_data["inventory"] is Array:
		player.inventory = save_data["inventory"].duplicate()
		
	if player.has_method("update_hud"):
		player.update_hud()


# --- CHECKPOINT & RESPAWN SYSTEM ---

## Lưu điểm Checkpoint hồi sinh (Băng ghế Bench hoặc Cột Waypoint)
func set_checkpoint(scene_path: String, spawn_pos: Vector2, save_now: bool = true) -> void:
	save_data["checkpoint"] = {
		"has_checkpoint": true,
		"scene_path": scene_path,
		"spawn_pos_x": spawn_pos.x,
		"spawn_pos_y": spawn_pos.y
	}
	save_data["world_state"]["last_scene"] = scene_path
	last_bench_pos = spawn_pos
	last_bench_scene = scene_path
	
	if save_now:
		var p = _get_active_player()
		if p:
			sync_from_player(p)
		save_to_disk()


## Lấy thông tin điểm hồi sinh khi Game Over
func get_respawn_info() -> Dictionary:
	var cp = save_data.get("checkpoint", {})
	if cp.get("has_checkpoint", false):
		return {
			"has_checkpoint": true,
			"scene_path": cp.get("scene_path", "res://assets/scenes/levels/map_1.tscn"),
			"spawn_position": Vector2(cp.get("spawn_pos_x", 0.0), cp.get("spawn_pos_y", 0.0))
		}
	# Fallback về màn chơi gần nhất hoặc map 1
	var last_scene = save_data.get("world_state", {}).get("last_scene", "res://assets/scenes/levels/map_1.tscn")
	return {
		"has_checkpoint": false,
		"scene_path": last_scene,
		"spawn_position": Vector2.ZERO
	}


# --- WORLD STATE & EVENT TRACKING ---

## Kiểm tra xem một Event ID (mở cửa, hạ boss, nhặt đồ) đã hoàn thành chưa
func is_event_completed(event_id: String) -> bool:
	var events: Array = save_data.get("world_state", {}).get("completed_events", [])
	return event_id in events


## Đánh dấu Event ID đã hoàn thành để không bị reset khi chuyển map
func set_event_completed(event_id: String, save_now: bool = false) -> void:
	var events: Array = save_data["world_state"]["completed_events"]
	if not (event_id in events):
		events.append(event_id)
		if save_now:
			save_to_disk()


# --- CÁC HÀM STATIC TƯƠNG THÍCH NGƯỢC (BACKWARD COMPATIBILITY) ---

static func save_bench_checkpoint(bench_pos: Vector2, scene_path: String) -> void:
	if instance:
		instance.set_checkpoint(scene_path, bench_pos, true)
	else:
		last_bench_pos = bench_pos
		last_bench_scene = scene_path


static func get_bench_checkpoint() -> Dictionary:
	if instance:
		var respawn = instance.get_respawn_info()
		if respawn["has_checkpoint"]:
			return {"pos": respawn["spawn_position"], "scene": respawn["scene_path"]}
	if last_bench_pos != Vector2.ZERO:
		return {"pos": last_bench_pos, "scene": last_bench_scene}
	return {"pos": Vector2.ZERO, "scene": ""}


static func save_last_level(scene_path: String) -> void:
	if scene_path == "" or scene_path.contains("menu") or scene_path.contains("ui"):
		return
	if instance:
		instance.save_data["world_state"]["last_scene"] = scene_path
		instance.save_to_disk()


static func get_last_level(default_path: String = "res://assets/scenes/levels/map_1.tscn") -> String:
	if instance:
		return instance.save_data.get("world_state", {}).get("last_scene", default_path)
	return default_path


static func save_geo(amount: int) -> void:
	if instance:
		instance.save_data["player"]["geo"] = amount
		instance.save_to_disk()


static func get_geo() -> int:
	if instance:
		return instance.save_data.get("player", {}).get("geo", 0)
	return 0


static func save_shade(pos: Vector2, scene_path: String, geo: int) -> void:
	if instance:
		instance.save_data["shade"] = {
			"active": true,
			"scene_path": scene_path,
			"pos_x": pos.x,
			"pos_y": pos.y,
			"geo": geo
		}
		instance.save_to_disk()


static func get_shade() -> Dictionary:
	if instance:
		var s = instance.save_data.get("shade", {})
		if s.get("active", false):
			return {
				"active": true,
				"pos": Vector2(s.get("pos_x", 0.0), s.get("pos_y", 0.0)),
				"scene": s.get("scene_path", ""),
				"geo": s.get("geo", 0)
			}
	return {"active": false, "pos": Vector2.ZERO, "scene": "", "geo": 0}


static func clear_shade() -> void:
	if instance:
		instance.save_data["shade"]["active"] = false
		instance.save_data["shade"]["geo"] = 0
		instance.save_to_disk()


static func save_cocoon(pos: Vector2, scene_path: String, geo: int) -> void:
	save_shade(pos, scene_path, geo)


static func get_cocoon() -> Dictionary:
	return get_shade()


static func clear_cocoon() -> void:
	clear_shade()


# --- QUẢN LÝ NHIỆM VỤ (QUEST SYSTEM API) ---

func get_quests() -> Dictionary:
	return save_data.get("quests", {})

func add_quest(quest_id: String, title: String, desc: String, objective: String = "", icon_path: String = "") -> void:
	if not save_data.has("quests") or not (save_data["quests"] is Dictionary):
		save_data["quests"] = {}
	if icon_path == "":
		icon_path = "res://assets/art/2d/Achievements/achievement__0014_dream_witch_quest_end.png"
	save_data["quests"][quest_id] = {
		"id": quest_id,
		"title": title,
		"desc": desc,
		"objective": objective,
		"status": "active",
		"icon_path": icon_path
	}
	save_to_disk()

func complete_quest(quest_id: String) -> void:
	if save_data.has("quests") and save_data["quests"].has(quest_id):
		save_data["quests"][quest_id]["status"] = "completed"
		save_to_disk()

func is_quest_completed(quest_id: String) -> bool:
	if save_data.has("quests") and save_data["quests"].has(quest_id):
		return save_data["quests"][quest_id].get("status", "") == "completed"
	return false


# --- QUẢN LÝ SỔ TAY THỢ SĂN (HUNTER'S JOURNAL API) ---

func get_hunter_journal() -> Dictionary:
	return save_data.get("hunter_journal", {})

func record_enemy_kill(enemy_id: String) -> void:
	if not save_data.has("hunter_journal") or not (save_data["hunter_journal"] is Dictionary):
		save_data["hunter_journal"] = {}
	var cur = int(save_data["hunter_journal"].get(enemy_id, 0))
	save_data["hunter_journal"][enemy_id] = cur + 1
	save_to_disk()

func get_enemy_kills(enemy_id: String) -> int:
	if save_data.has("hunter_journal") and save_data["hunter_journal"].has(enemy_id):
		return int(save_data["hunter_journal"][enemy_id])
	return 0


# --- QUẢN LÝ VẬT PHẨM TÚI ĐỒ (INVENTORY ITEMS API) ---

func get_inventory_items() -> Array:
	return save_data.get("inventory", [])

func add_inventory_item(item_data: Dictionary) -> void:
	if not save_data.has("inventory") or not (save_data["inventory"] is Array):
		save_data["inventory"] = []
	save_data["inventory"].append(item_data)
	save_to_disk()

func has_inventory_item(item_id: String) -> bool:
	for it in get_inventory_items():
		if it is Dictionary and it.get("id", "") == item_id:
			return true
	return false


# --- HELPER FUNCTIONS NỘI BỘ ---

func _get_active_player() -> Node:
	if not is_inside_tree() or get_tree() == null:
		return null
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


func _merge_dictionary(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if target.has(key) and typeof(target[key]) == TYPE_DICTIONARY and typeof(source[key]) == TYPE_DICTIONARY:
			_merge_dictionary(target[key], source[key])
		else:
			target[key] = source[key]
