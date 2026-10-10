@tool
extends SceneTree

func _init() -> void:
	print("--- Starting map_02_tilemap generation ---")
	
	# 1. Create Tile texture image if not exists
	var img_dir := "res://assets/art/2d/enviroment"
	DirAccess.make_dir_recursive_absolute(img_dir)
	var img_path := img_dir + "/map_02_tiles.png"
	
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	# Tile 0,0 (Wall Tile): Dark blue-grey stone block with border
	for x in range(0, 32):
		for y in range(0, 32):
			if x <= 1 or x >= 30 or y <= 1 or y >= 30:
				img.set_pixel(x, y, Color(0.35, 0.4, 0.52, 1.0)) # Border
			elif x == 2 or y == 2 or x == 29 or y == 29:
				img.set_pixel(x, y, Color(0.22, 0.26, 0.35, 1.0)) # Inner edge shadow
			else:
				img.set_pixel(x, y, Color(0.16, 0.19, 0.27, 1.0)) # Fill
				
	# Tile 1,0 (Platform / Floor Tile): Highlighted top floor
	for x in range(32, 64):
		for y in range(0, 32):
			var local_x = x - 32
			if y <= 3:
				img.set_pixel(x, y, Color(0.5, 0.65, 0.85, 1.0)) # Bright grass/top ledge
			elif local_x <= 1 or local_x >= 30 or y >= 30:
				img.set_pixel(x, y, Color(0.35, 0.4, 0.52, 1.0))
			else:
				img.set_pixel(x, y, Color(0.18, 0.22, 0.32, 1.0))
				
	# Tile 0,1 (Shaft Wall Tile): Darker purple-grey brick
	for x in range(0, 32):
		for y in range(32, 64):
			var local_y = y - 32
			if x <= 1 or x >= 30 or local_y <= 1 or local_y >= 30:
				img.set_pixel(x, y, Color(0.28, 0.24, 0.36, 1.0))
			else:
				img.set_pixel(x, y, Color(0.14, 0.12, 0.2, 1.0))
				
	# Tile 1,1 (Accent Tile)
	for x in range(32, 64):
		for y in range(32, 64):
			img.set_pixel(x, y, Color(0.25, 0.3, 0.4, 1.0))

	img.save_png(img_path)
	print("Saved texture to: ", img_path)

	# Create ImageTexture
	var tex := ImageTexture.create_from_image(img)

	# 2. Create TileSet Resource
	var tileset_dir := "res://assets/resources/tilesets"
	DirAccess.make_dir_recursive_absolute(tileset_dir)
	var tileset_path := tileset_dir + "/map_02_tileset.tres"

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	
	# Add 1 Physics Layer
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 1)
	
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = tex
	atlas_source.texture_region_size = Vector2i(32, 32)
	
	tileset.add_source(atlas_source, 0)

	# Create tiles in atlas source with full rectangular collision shape (-16..16)
	var full_rect_poly = PackedVector2Array([
		Vector2(-16, -16),
		Vector2(16, -16),
		Vector2(16, 16),
		Vector2(-16, 16)
	])
	
	for tile_coord in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]:
		atlas_source.create_tile(tile_coord)
		var tile_data = atlas_source.get_tile_data(tile_coord, 0)
		if tile_data:
			tile_data.add_collision_polygon(0)
			tile_data.set_collision_polygon_points(0, 0, full_rect_poly)

	ResourceSaver.save(tileset, tileset_path)
	print("Saved TileSet to: ", tileset_path)

	# Reload tileset as external resource
	var external_tileset: TileSet = load(tileset_path)

	# 3. Create Scene Structure
	var root := Node2D.new()
	root.name = "Map02"
	
	# Attach Level Script if available
	var script = load("res://assets/scenes/levels/pixel_level.gd")
	if script:
		root.set_script(script)

	var tilemap_layer := TileMapLayer.new()
	tilemap_layer.name = "TileMapLayer_Walls"
	tilemap_layer.tile_set = external_tileset
	root.add_child(tilemap_layer)
	tilemap_layer.owner = root

	# Paint rooms into TileMapLayer_Walls using set_cell
	var source_id = 0
	var wall_tile = Vector2i(0, 0)
	var floor_tile = Vector2i(1, 0)
	var shaft_tile = Vector2i(0, 1)

	# Helper lambda to draw filled rectangle box outer walls
	# Room 1: (0, 0) to (30, 15)
	for x in range(0, 31):
		for y in range(0, 16):
			# Outer 2-tile thick wall boundary for Room 1
			var is_top_wall = (y <= 1)
			var is_bottom_wall = (y >= 14)
			var is_left_wall = (x <= 1)
			var is_right_wall = (x >= 29)
			
			if is_top_wall or is_left_wall or is_right_wall:
				tilemap_layer.set_cell(Vector2i(x, y), source_id, wall_tile)
			elif is_bottom_wall:
				# Doorway gap connecting to Room 2 (x from 25 to 28 is left open)
				if x < 25 or x > 28:
					tilemap_layer.set_cell(Vector2i(x, y), source_id, floor_tile)

	# Room 2 (Descent Shaft): (25, 15) to (30, 35)
	for x in range(25, 31):
		for y in range(15, 36):
			var is_left_wall = (x <= 26)
			var is_right_wall = (x >= 29)
			
			if is_left_wall or is_right_wall:
				tilemap_layer.set_cell(Vector2i(x, y), source_id, shaft_tile)

	# Room 3 (Monster Dungeon): (10, 35) to (50, 45)
	for x in range(10, 51):
		for y in range(35, 46):
			var is_top_wall = (y <= 36)
			var is_bottom_wall = (y >= 44)
			var is_left_wall = (x <= 11)
			var is_right_wall = (x >= 49)
			
			if is_top_wall:
				# Shaft opening gap from Room 2 (x from 27 to 28 left open)
				if x < 27 or x > 28:
					tilemap_layer.set_cell(Vector2i(x, y), source_id, wall_tile)
			elif is_bottom_wall or is_left_wall or is_right_wall:
				tilemap_layer.set_cell(Vector2i(x, y), source_id, wall_tile)

	# Add Markers node
	var markers := Node2D.new()
	markers.name = "Markers"
	root.add_child(markers)
	markers.owner = root

	var player_start := Marker2D.new()
	player_start.name = "PlayerStart"
	player_start.position = Vector2(5 * 32 + 16, 12 * 32 + 16) # (176, 400)
	markers.add_child(player_start)
	player_start.owner = root

	var skill_dash := Marker2D.new()
	skill_dash.name = "Skill_Dash"
	skill_dash.position = Vector2(18 * 32 + 16, 40 * 32 + 16) # (592, 1296)
	markers.add_child(skill_dash)
	skill_dash.owner = root

	var exit_map3 := Marker2D.new()
	exit_map3.name = "Exit_Map3"
	exit_map3.position = Vector2(45 * 32 + 16, 40 * 32 + 16) # (1456, 1296)
	markers.add_child(exit_map3)
	exit_map3.owner = root

	# Add CameraLimits markers if using pixel_level.gd
	var top_left_marker := Marker2D.new()
	top_left_marker.name = "TopLeft"
	top_left_marker.position = Vector2(-100, -100)
	root.add_child(top_left_marker)
	top_left_marker.owner = root

	var bottom_right_marker := Marker2D.new()
	bottom_right_marker.name = "BottomRight"
	bottom_right_marker.position = Vector2(52 * 32 + 100, 47 * 32 + 100)
	root.add_child(bottom_right_marker)
	bottom_right_marker.owner = root

	# Save Scene
	var packed_scene := PackedScene.new()
	var pack_result = packed_scene.pack(root)
	if pack_result == OK:
		var scene_dir := "res://assets/scenes/levels"
		DirAccess.make_dir_recursive_absolute(scene_dir)
		var scene_path := scene_dir + "/map_02_tilemap.tscn"
		var save_result = ResourceSaver.save(packed_scene, scene_path)
		if save_result == OK:
			print("SUCCESS: Saved map_02_tilemap.tscn to: ", scene_path)
		else:
			print("ERROR: Failed to save scene, error code: ", save_result)
	else:
		print("ERROR: Failed to pack scene, error code: ", pack_result)

	quit()
