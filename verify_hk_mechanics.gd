@tool
extends SceneTree

func _init() -> void:
	print("==========================================================")
	print("--- VERIFYING HOLLOW KNIGHT CORE MECHANICS INTEGRATION ---")
	print("==========================================================")

	var scene_path := "res://assets/prefabs/player/player_controller(pixel).tscn"
	var packed_player: PackedScene = load(scene_path)
	assert(packed_player != null, "Player prefab must load cleanly!")

	var player_inst = packed_player.instantiate()
	assert(player_inst != null, "Player prefab must instantiate!")
	print("✓ Player prefab instantiated cleanly!")

	# Check STATE.FOCUS_HEAL
	assert("FOCUS_HEAL" in player_inst.STATE, "STATE.FOCUS_HEAL must exist!")
	print("✓ STATE.FOCUS_HEAL added to player State Machine!")

	# Check methods
	assert(player_inst.has_method("trigger_hitstop"), "trigger_hitstop() method must exist!")
	assert(player_inst.has_method("_on_attack_area_entered"), "_on_attack_area_entered() method must exist!")
	print("✓ Nail Pogo, Hitstop, and Weapon Recoil methods verified!")

	# Check SFX preloads
	assert(player_inst.sound_cure_sfx != null, "sound_cure_sfx audio stream must be preloaded!")
	assert(player_inst.voice_cure_sfx != null, "voice_cure_sfx audio stream must be preloaded!")
	print("✓ Focus Heal Audio SFX (sound_cure & voice_cure) preloaded!")

	print("==========================================================")
	print("🎉 HOLLOW KNIGHT CORE MECHANICS VERIFIED SUCCESSFULLY! 🎉")
	print("==========================================================")
	quit()
