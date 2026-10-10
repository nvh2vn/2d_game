@tool
extends SceneTree

func _init() -> void:
	print("===========================================")
	print("--- VERIFYING PLATFORM TILEMAP SCENE ---")
	print("===========================================")

	var scene_path := "res://assets/scenes/levels/map_02_tilemap.tscn"
	var packed_scene: PackedScene = load(scene_path)
	assert(packed_scene != null, "Scene must load cleanly!")

	var scene_inst = packed_scene.instantiate()
	assert(scene_inst != null, "Scene must instantiate!")
	print("✓ Scene instantiated cleanly!")

	var platforms_layer = scene_inst.get_node_or_null("TileMapLayer_Platforms")
	assert(platforms_layer != null, "TileMapLayer_Platforms node must exist!")
	assert(platforms_layer is TileMapLayer, "Must be TileMapLayer class!")
	print("✓ Node TileMapLayer_Platforms exists and is a valid TileMapLayer node!")

	var tileset = platforms_layer.tile_set
	assert(tileset != null, "TileSet property must be assigned!")
	print("✓ TileSet property assigned with tile_size = ", tileset.tile_size)
	print("✓ Total TileSetAtlasSource count = ", tileset.get_source_count())
	assert(tileset.get_source_count() > 0, "TileSet must contain sources!")

	print("===========================================")
	print("🎉 PLATFORM TILEMAP VERIFIED SUCCESSFULLY! 🎉")
	print("===========================================")
	quit()
