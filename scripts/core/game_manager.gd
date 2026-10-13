extends Node

## Singleton Autoload quản lý trạng thái trò chơi & tiến trình kỹ năng (Skills & Global State).
## Điều khiển việc thức tỉnh kỹ năng "Silk Storm" (City Crest) và "Needle Throw" (Piercing Blast).

static var instance: Node = null

signal skill_unlocked(skill_name: String)
signal skills_changed()
signal bench_rested()
signal enemies_reset()
signal chest_opened(chest_id: String)

var can_silk_storm: bool = false
var can_needle_throw: bool = false

# Quản lý danh sách quái thường bị tiêu diệt (chỉ hồi sinh khi ngồi Ghế/Bench)
var defeated_normal_enemies: Dictionary = {}

# Quản lý danh sách rương kho báu đã mở (lưu vĩnh viễn, không bị reset khi chuyển map/dùng waypoint)
var opened_chests: Dictionary = {}

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	instance = self
	_sync_from_save_manager()


func _sync_from_save_manager() -> void:
	if SaveManager and SaveManager.instance:
		var skills = SaveManager.instance.save_data.get("player", {}).get("skills", {})
		can_silk_storm = skills.get("can_silk_storm", false)
		can_needle_throw = skills.get("can_needle_throw", false)
		opened_chests = SaveManager.instance.save_data.get("opened_chests", {})
	skills_changed.emit()


# ==================== QUẢN LÝ QUÁI VẬT & BENCH RESPRAWN ====================
func record_enemy_defeated(enemy_id: String) -> void:
	if enemy_id != "":
		defeated_normal_enemies[enemy_id] = true


func is_enemy_defeated(enemy_id: String) -> bool:
	if enemy_id == "":
		return false
	return defeated_normal_enemies.get(enemy_id, false)


func reset_map_enemies() -> void:
	defeated_normal_enemies.clear()
	bench_rested.emit()
	enemies_reset.emit()
	if is_inside_tree() and get_tree():
		get_tree().call_group("enemies", "reset_enemy")


# ==================== QUẢN LÝ TRẠNG THÁI MỞ RƯƠNG ====================
func is_chest_opened(chest_id: String) -> bool:
	if chest_id == "":
		return false
	return opened_chests.get(chest_id, false)


func record_chest_opened(chest_id: String) -> void:
	if chest_id == "":
		return
	opened_chests[chest_id] = true
	_persist_opened_chests()
	chest_opened.emit(chest_id)


func _persist_opened_chests() -> void:
	if SaveManager and SaveManager.instance:
		SaveManager.instance.save_data["opened_chests"] = opened_chests
		SaveManager.instance.save_to_disk()


func unlock_silk_storm() -> void:
	if can_silk_storm:
		return
	can_silk_storm = true
	_persist_and_apply("silk_storm")


func unlock_needle_throw() -> void:
	if can_needle_throw:
		return
	can_needle_throw = true
	_persist_and_apply("needle_throw")


func _persist_and_apply(skill_name: String) -> void:
	if SaveManager and SaveManager.instance:
		var p_data = SaveManager.instance.save_data.get("player", {})
		if not p_data.has("skills"):
			p_data["skills"] = {}
		p_data["skills"]["can_silk_storm"] = can_silk_storm
		p_data["skills"]["can_needle_throw"] = can_needle_throw
		SaveManager.instance.save_to_disk()
	
	if is_inside_tree() and get_tree():
		var player = get_tree().get_first_node_in_group("player")
		if player:
			if "unlock_special_attack" in player:
				player.unlock_special_attack = can_silk_storm
			if "unlock_shoot" in player:
				player.unlock_shoot = can_needle_throw
		TouchControls.update_skill_buttons(get_tree())
	
	skill_unlocked.emit(skill_name)
	skills_changed.emit()


func reset_skills() -> void:
	can_silk_storm = false
	can_needle_throw = false
	if SaveManager and SaveManager.instance:
		var skills = SaveManager.instance.save_data.get("player", {}).get("skills", {})
		skills["can_silk_storm"] = false
		skills["can_needle_throw"] = false
	if is_inside_tree() and get_tree():
		var player = get_tree().get_first_node_in_group("player")
		if player:
			if "unlock_special_attack" in player:
				player.unlock_special_attack = false
			if "unlock_shoot" in player:
				player.unlock_shoot = false
		TouchControls.update_skill_buttons(get_tree())
	skills_changed.emit()
