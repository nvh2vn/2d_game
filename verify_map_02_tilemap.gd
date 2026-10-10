@tool
extends SceneTree

func _init() -> void:
	print("===========================================")
	print("--- VERIFYING map_02_tilemap.tscn ---")
	print("===========================================")

	var scene_path := "res://assets/scenes/levels/map_02_tilemap.tscn"
	var packed_scene: PackedScene = load(scene_path)
	if not packed_scene:
		printerr("FAIL: Could not load scene at ", scene_path)
		quit(1)
		return

	var map_instance = packed_scene.instantiate()
	if not map_instance:
		printerr("FAIL: Could not instantiate scene")
		quit(1)
		return

	print("✓ Scene loaded and instantiated cleanly!")

	# 1. Verify Root Node
	assert(map_instance.name == "Map02", "Root node name must be Map02")
	print("✓ Root Node: ", map_instance.name, " (Node2D)")

	# 2. Verify TileMapLayer_Walls Node
	var walls_node = map_instance.get_node_or_null("TileMapLayer_Walls")
	assert(walls_node != null, "TileMapLayer_Walls node missing!")
	assert(walls_node is TileMapLayer, "TileMapLayer_Walls must be a TileMapLayer node!")
	print("✓ TileMapLayer_Walls is a valid TileMapLayer node (NOT deprecated TileMap)")

	var tileset: TileSet = walls_node.tile_set
	assert(tileset != null, "TileSet missing on TileMapLayer_Walls!")
	print("✓ TileSet attached: tile_size = ", tileset.tile_size)
	assert(tileset.tile_size == Vector2i(32, 32) or tileset.tile_size == Vector2i(16, 16), "Tile size should be 16x16 or 32x32")
	assert(tileset.get_physics_layers_count() >= 1, "TileSet must have at least 1 Physics Layer")
	print("✓ Physics Layer configured: count = ", tileset.get_physics_layers_count())

	# Check tile collision polygon
	var source: TileSetAtlasSource = tileset.get_source(0)
	assert(source != null, "TileSet source 0 missing!")
	var tile_data = source.get_tile_data(Vector2i(0, 0), 0)
	assert(tile_data != null, "Tile (0,0) data missing!")
	assert(tile_data.get_collision_polygons_count(0) >= 1, "Tile (0,0) must have collision polygon!")
	print("✓ Wall Tile (0,0) collision shape polygon points: ", tile_data.get_collision_polygon_points(0, 0))

	# 3. Verify Layout and set_cell data
	# Check Room 1 outer wall cells
	var top_left_cell = walls_node.get_cell_atlas_coords(Vector2i(0, 0))
	print("✓ Cell (0,0) atlas coords: ", top_left_cell)
	assert(top_left_cell != Vector2i(-1, -1), "Wall tile at (0,0) should be painted!")

	# Check doorway gap between Room 1 and Room 2 at y=15, x=27
	var gap_cell = walls_node.get_cell_atlas_coords(Vector2i(27, 15))
	print("✓ Doorway gap cell (27,15) atlas coords: ", gap_cell, " (should be -1,-1 for open space)")
	assert(gap_cell == Vector2i(-1, -1), "Doorway gap at (27,15) should be empty space!")

	# 4. Verify Scene Hierarchy & Markers
	var markers_node = map_instance.get_node_or_null("Markers")
	assert(markers_node != null, "Markers node missing!")

	var player_start = markers_node.get_node_or_null("PlayerStart")
	assert(player_start != null and player_start is Marker2D, "PlayerStart Marker2D missing!")
	print("✓ Marker PlayerStart position: ", player_start.position)

	var skill_dash = markers_node.get_node_or_null("Skill_Dash")
	assert(skill_dash != null and skill_dash is Marker2D, "Skill_Dash Marker2D missing!")
	print("✓ Marker Skill_Dash position: ", skill_dash.position)

	var exit_map3 = markers_node.get_node_or_null("Exit_Map3")
	assert(exit_map3 != null and exit_map3 is Marker2D, "Exit_Map3 Marker2D missing!")
	print("✓ Marker Exit_Map3 position: ", exit_map3.position)

	# 5. Check Player Spawn Collision (Ensure PlayerStart is NOT stuck in wall collision)
	var player_cell = walls_node.local_to_map(player_start.position)
	var cell_coords_at_start = walls_node.get_cell_atlas_coords(player_cell)
	print("✓ PlayerStart cell coordinate: ", player_cell, " -> Tile at cell: ", cell_coords_at_start)
	assert(cell_coords_at_start == Vector2i(-1, -1), "PlayerStart must spawn in OPEN space (no wall tile at position)!")

	print("===========================================")
	print("🎉 ALL TESTS PASSED SUCCESSFULLY! 🎉")
	print("===========================================")
	quit()
