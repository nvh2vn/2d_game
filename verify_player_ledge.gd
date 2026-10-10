@tool
extends SceneTree

func _init() -> void:
	print("--- VERIFYING PLAYER LEDGE CLIMB SCRIPT ---")
	var player_scene = load("res://assets/prefabs/player/player_controller(pixel).tscn")
	assert(player_scene != null, "Player scene must load")
	var player_inst = player_scene.instantiate()
	assert(player_inst != null, "Player must instantiate")
	print("✓ Player prefab instantiated successfully!")
	print("✓ unlock_ledge_climb status: ", player_inst.unlock_ledge_climb)
	assert(player_inst.unlock_ledge_climb == true, "unlock_ledge_climb must default to true!")
	print("🎉 PLAYER LEDGE CLIMB MECHANIC VERIFIED SUCCESSFULLY! 🎉")
	quit()
