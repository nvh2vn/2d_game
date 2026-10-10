@tool
extends SceneTree

func _init() -> void:
	print("==========================================================")
	print("--- VERIFYING HK PLATFORM TILESET & SCENE INTEGRATION ---")
	print("==========================================================")

	var scene_path := "res://assets/scenes/levels/map_02_tilemap.tscn"
	var packed_scene: PackedScene = load(scene_path)
	assert(packed_scene != null, "Scene must load cleanly!")

	var map_instance = packed_scene.instantiate()
	assert(map_instance != null, "Scene must instantiate!")
	print("✓ Scene instantiated cleanly!")

	var platforms_layer = map_instance.get_node_or_null("TileMapLayer_Platforms")
	assert(platforms_layer != null, "TileMapLayer_Platforms node missing!")
	assert(platforms_layer is TileMapLayer, "Must be TileMapLayer!")
	print("✓ TileMapLayer_Platforms exists and is valid!")

	var tileset: TileSet = platforms_layer.tile_set
	assert(tileset != null, "TileSet missing on TileMapLayer_Platforms!")
	print("✓ TileSet assigned with tile_size = ", tileset.tile_size)

	var sources_count = tileset.get_source_count()
	print("✓ Total Atlas Sources in TileSet = ", sources_count)
	assert(sources_count > 0, "TileSet must contain atlas sources!")

	# Check physics layer
	assert(tileset.get_physics_layers_count() >= 1, "TileSet physics layer 0 must be configured!")
	print("✓ Physics Layer 0 configured properly!")

	print("==========================================================")
	print("🎉 HK PLATFORM TILESET VERIFICATION SUCCESSFUL! 🎉")
	print("==========================================================")
	quit()
