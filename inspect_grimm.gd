@tool
extends SceneTree

func _init():
	var img = Image.load_from_file("res://assets/art/2d/Enemies/Bosses - Troupe Master Grimm.png")
	var w = img.get_width()
	var teal_ref = Color(0.0, 0.451, 0.5765, 1.0)
	var is_teal = func(c: Color) -> bool:
		return (abs(c.r - 0.0) < 0.05 and abs(c.g - 0.451) < 0.05 and abs(c.b - 0.5765) < 0.05) or (c.r < 0.05 and c.g > 0.35 and c.g < 0.55 and c.b > 0.45 and c.b < 0.65)
	
	var rows = [
		[22, 426],      # Row 0
		[448, 855],     # Row 1
		[877, 1303],    # Row 2
		[1325, 2225],   # Row 3
	]
	
	for row_idx in range(rows.size()):
		var ry1 = rows[row_idx][0]
		var ry2 = rows[row_idx][1]
		var rh = ry2 - ry1
		var frames = []
		var in_frame = false
		var frame_x1 = 0
		
		for x in range(w):
			var col_has_sprite = false
			for s in range(10):
				var sy = ry1 + int((s + 1) * rh / 12)
				var c = img.get_pixel(x, sy)
				if not is_teal.call(c):
					col_has_sprite = true
					break
			if col_has_sprite and not in_frame:
				in_frame = true
				frame_x1 = x
			elif not col_has_sprite and in_frame:
				in_frame = false
				if (x - frame_x1) > 20:
					frames.append([frame_x1, x])
		if in_frame and (w - frame_x1) > 20:
			frames.append([frame_x1, w])
			
		print("Row ", row_idx, " (y=", ry1, "..", ry2, ", h=", rh, "): ", frames.size(), " frames")
		for f_idx in range(frames.size()):
			var fx1 = frames[f_idx][0]
			var fx2 = frames[f_idx][1]
			var min_x = fx2
			var max_x = fx1
			var min_y = ry2
			var max_y = ry1
			var non_zero = 0
			for py in range(ry1, ry2, 2):
				for px in range(fx1, fx2, 2):
					var c = img.get_pixel(px, py)
					if not is_teal.call(c) and c.a > 0.05:
						non_zero += 1
						if px < min_x: min_x = px
						if px > max_x: max_x = px
						if py < min_y: min_y = py
						if py > max_y: max_y = py
			if non_zero > 0:
				print("   F", f_idx, ": x=[", fx1, "..", fx2, "], content=[", min_x, ",", min_y, " to ", max_x, ",", max_y, "] size=", max_x - min_x, "x", max_y - min_y)
			else:
				print("   F", f_idx, ": EMPTY")
				
	quit(0)
