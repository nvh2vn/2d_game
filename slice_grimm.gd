@tool
extends SceneTree

# Script to slice Bosses - Troupe Master Grimm.png into clean, aligned frames
func _init():
	var start_time = Time.get_ticks_msec()
	print("Starting Grimm sprite extraction...")
	var img = Image.load_from_file("res://assets/art/2d/Enemies/Bosses - Troupe Master Grimm.png")
	if not img:
		printerr("Failed to load Grimm spritesheet!")
		quit(1)
		return
		
	var w = img.get_width()
	var h = img.get_height()
	print("Loaded sheet: ", w, "x", h)
	
	var out_dir = "res://assets/art/2d/Enemies/grimm_extracted/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	
	# Helper to check if pixel is teal/cyan background
	var is_bg = func(c: Color) -> bool:
		if c.a < 0.05: return true
		# Spriters Resource teal: R ~ 0.0, G ~ 0.45, B ~ 0.58
		if c.r < 0.06 and c.g > 0.35 and c.g < 0.55 and c.b > 0.48 and c.b < 0.68:
			return true
		# Also check for black border or text near edges if needed, but let's test
		return false
		
	# Normalized canvas size for Grimm body animations
	var CANVAS_W = 512
	var CANVAS_H = 512
	var FEET_Y = 480
	var CENTER_X = 256
	
	# Let's define the row definitions and frame boundaries
	# We can use the frame horizontal boxes detected earlier
	# Row 0: Idle (12 frames)
	# Row 1: Bow (7 frames), Screech (4 frames)
	# Row 2: Teleport Out (5 frames), Teleport In (2 frames)
	# Row 4: Dash Prep & Slash (6 frames)
	# Row 5: Uppercut (4 frames)
	# Row 6: Dive & Slide (7 frames)
	# Row 7: Cast Firebats (8 frames)
	# Row 8: Firebat Projectile (5 frames)
	# Row 16: Spikes Cast (10 frames)
	# Row 17: Spikes & Pufferfish (Spikes: F3..F12, Puffer: F14..F18)
	# Row 18: Death / Stagger burst (5 frames)
	# Row 19: Small Bats (5 frames)
	
	# Function to extract a frame from rectangle [fx1, ry1, fx2, ry2]
	var extract_frame = func(anim_name: String, f_idx: int, fx1: int, ry1: int, fx2: int, ry2: int, custom_anchor_y: int = FEET_Y, custom_w: int = CANVAS_W, custom_h: int = CANVAS_H):
		# 1. Find tight bounding box of sprite ignoring background
		var min_x = fx2
		var max_x = fx1
		var min_y = ry2
		var max_y = ry1
		var found_pixel = false
		
		for y in range(ry1, ry2):
			for x in range(fx1, fx2):
				var c = img.get_pixel(x, y)
				if not is_bg.call(c) and c.a > 0.05:
					found_pixel = true
					if x < min_x: min_x = x
					if x > max_x: max_x = x
					if y < min_y: min_y = y
					if y > max_y: max_y = y
					
		if not found_pixel:
			print("Warning: no content in frame ", anim_name, "_", f_idx)
			return null
			
		var sprite_w = max_x - min_x + 1
		var sprite_h = max_y - min_y + 1
		
		# 2. Create blank image
		var frame_img = Image.create(custom_w, custom_h, false, Image.FORMAT_RGBA8)
		frame_img.fill(Color(0, 0, 0, 0))
		
		# 3. Determine placement on canvas
		# For ground animations: bottom of sprite at custom_anchor_y, center at custom_w / 2
		var dest_x = int(custom_w / 2.0 - sprite_w / 2.0)
		var dest_y = custom_anchor_y - sprite_h
		
		# Copy pixels from source to frame_img, filtering out bg
		for y in range(sprite_h):
			var src_y = min_y + y
			var target_y = dest_y + y
			if target_y < 0 or target_y >= custom_h: continue
			for x in range(sprite_w):
				var src_x = min_x + x
				var target_x = dest_x + x
				if target_x < 0 or target_x >= custom_w: continue
				var c = img.get_pixel(src_x, src_y)
				if is_bg.call(c):
					frame_img.set_pixel(target_x, target_y, Color(0, 0, 0, 0))
				else:
					frame_img.set_pixel(target_x, target_y, c)
					
		var save_path = out_dir + anim_name + "_" + str(f_idx) + ".png"
		frame_img.save_png(save_path)
		return save_path
		
	# --- 1. IDLE (Row 0, y=22..426, 12 frames) ---
	var r0_y1 = 22
	var r0_y2 = 426
	var r0_step = 202
	for i in range(12):
		extract_frame.call("idle", i, 3 + i * r0_step, r0_y1, 3 + (i + 1) * r0_step - 3, r0_y2)
		
	# --- 2. BOW (Row 1, y=448..855, F0..F6, step 250) ---
	var r1_y1 = 448
	var r1_y2 = 855
	var bow_xs = [[3, 250], [253, 500], [503, 750], [753, 1000], [1003, 1250], [1253, 1500], [1503, 1750]]
	for i in range(bow_xs.size()):
		extract_frame.call("bow", i, bow_xs[i][0], r1_y1, bow_xs[i][1], r1_y2)
		
	# --- 3. SCREECH / ROAR (Row 1, F7..F10) ---
	var screech_xs = [[1785, 2044], [2070, 2452], [2455, 2837], [2840, 3222]]
	for i in range(screech_xs.size()):
		extract_frame.call("screech", i, screech_xs[i][0], r1_y1, screech_xs[i][1], r1_y2)
		
	# --- 4. TELEPORT OUT (Row 2, y=877..1303, F0..F4) ---
	var r2_y1 = 877
	var r2_y2 = 1303
	var tp_out_xs = [[3, 237], [240, 474], [477, 711], [714, 948], [951, 1185]]
	for i in range(tp_out_xs.size()):
		extract_frame.call("teleport_out", i, tp_out_xs[i][0], r2_y1, tp_out_xs[i][1], r2_y2)
		
	# --- 5. TELEPORT IN (Row 2, F5..F6) ---
	var tp_in_xs = [[1220, 1479], [1482, 1741]]
	for i in range(tp_in_xs.size()):
		extract_frame.call("teleport_in", i, tp_in_xs[i][0], r2_y1, tp_in_xs[i][1], r2_y2)
		
	# --- 6. DASH SLASH (Row 4 & Row 5) ---
	# Row 4: y=2247..2623, F0..F5
	var r4_y1 = 2247
	var r4_y2 = 2623
	var r4_xs = [[3, 282], [285, 564], [567, 846], [849, 1128], [1163, 1798], [1833, 2359]]
	for i in range(r4_xs.size()):
		extract_frame.call("dash_slash", i, r4_xs[i][0], r4_y1, r4_xs[i][1], r4_y2)
	# Row 5 F0: y=2645..3029, x=[3..630] (Full slash arc)
	extract_frame.call("dash_slash", 6, 3, 2645, 630, 3029)
	
	# --- 7. UPPERCUT (Row 5, y=2645..3029, F1..F3) ---
	var uc_xs = [[665, 1137], [1140, 1612], [1615, 2087]]
	for i in range(uc_xs.size()):
		extract_frame.call("uppercut", i, uc_xs[i][0], 2645, uc_xs[i][1], 3029)
		
	# --- 8. DIVE & SLIDE (Row 6, y=3051..3503) ---
	# F3..F5: dive in air (anchor in middle)
	var dive_xs = [[1274, 1590], [1593, 1909], [1944, 2138]]
	for i in range(dive_xs.size()):
		extract_frame.call("dive", i, dive_xs[i][0], 3051, dive_xs[i][1], 3503, 350)
	# F0..F2: slide on floor
	var slide_xs = [[3, 413], [416, 826], [829, 1239]]
	for i in range(slide_xs.size()):
		extract_frame.call("slide", i, slide_xs[i][0], 3051, slide_xs[i][1], 3503)
		
	# --- 9. CAST FIREBATS (Row 7, y=3703..4128, F0..F7) ---
	var r7_y1 = 3703
	var r7_y2 = 4128
	var r7_xs = [[3, 255], [258, 510], [513, 765], [768, 1020], [1055, 1478], [1481, 1904], [1907, 2330], [2333, 2756]]
	for i in range(r7_xs.size()):
		extract_frame.call("cast_firebats", i, r7_xs[i][0], r7_y1, r7_xs[i][1], r7_y2)
		
	# --- 10. FIREBAT PROJECTILE (Row 8, y=4150..4367, 5 frames) ---
	var r8_y1 = 4150
	var r8_y2 = 4367
	var r8_xs = [[3, 256], [259, 512], [515, 768], [771, 1024], [1027, 1280]]
	for i in range(r8_xs.size()):
		extract_frame.call("firebat", i, r8_xs[i][0], r8_y1, r8_xs[i][1], r8_y2, 128, 256, 256)
		
	# --- 11. SPIKES CAST (Row 16, y=7249..7658, 10 frames) ---
	var r16_y1 = 7249
	var r16_y2 = 7658
	var r16_step = 343
	for i in range(10):
		extract_frame.call("spikes_cast", i, 3 + i * r16_step, r16_y1, 3 + (i + 1) * r16_step - 3, r16_y2)
		
	# --- 12. SPIKES HAZARD (Row 17, y=7680..8236) ---
	# F3..F4 warning nubs, F5 rising, F6, F7, F9 full thorns
	var spike_xs = [[254, 351], [354, 451], [454, 551], [554, 651], [686, 755], [862, 950]]
	for i in range(spike_xs.size()):
		extract_frame.call("spike", i, spike_xs[i][0], 7680, spike_xs[i][1], 8236, 500, 256, 512)
		
	# --- 13. PUFFERFISH BALL (Row 17, F14..F18) ---
	# F14 curling, F15..F18 pulsing pufferfish sphere (anchor in center)
	var puffer_xs = [[1349, 1596], [1631, 2030], [2033, 2432], [2435, 2834], [2837, 3236]]
	for i in range(puffer_xs.size()):
		extract_frame.call("pufferfish", i, puffer_xs[i][0], 7680, puffer_xs[i][1], 8236, 450)
		
	# --- 14. STAGGER / DEATH BURST (Row 18, y=8562..9055, F0..F4) ---
	var r18_xs = [[3, 231], [234, 462], [497, 976], [979, 1458], [1461, 1940]]
	for i in range(r18_xs.size()):
		extract_frame.call("death", i, r18_xs[i][0], 8562, r18_xs[i][1], 9055, 450)
		
	# --- 15. STAGGER BAT (Row 19, y=9077..9431, F0..F4) ---
	var bat_xs = [[3, 143], [146, 286], [289, 429], [464, 631], [634, 801]]
	for i in range(bat_xs.size()):
		extract_frame.call("stagger_bat", i, bat_xs[i][0], 9077, bat_xs[i][1], 9431, 128, 256, 256)
		
	var elapsed = Time.get_ticks_msec() - start_time
	print("Extracted all Grimm sprites in ", elapsed, " ms to ", out_dir)
	quit(0)
