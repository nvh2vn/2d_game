extends Node

## Singleton Autoload quản lý trạng thái trò chơi & tiến trình kỹ năng (Skills & Global State).
## Điều khiển việc thức tỉnh kỹ năng "Silk Storm" (City Crest) và "Needle Throw" (Piercing Blast).

static var instance: Node = null

signal skill_unlocked(skill_name: String)
signal skills_changed()

var can_silk_storm: bool = false
var can_needle_throw: bool = false

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
	skills_changed.emit()


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
