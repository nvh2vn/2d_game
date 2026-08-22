# 🎮 2D Action Platformer Game (Godot 4)

Dự án game 2D Platformer / Metroidvania lấy cảm hứng từ phong cách gameplay và đồ họa của Silksong / Hollow Knight, được xây dựng trên nền tảng **Godot Engine 4**.

---

## 🌟 Tính năng nổi bật

### 1. 🗡️ Điều khiển nhân vật (Player Controller)
- **Di chuyển cơ bản:** Đi bộ, chạy nhanh, nhảy (hỗ trợ *Coyote Time* mượt mà).
- **Kỹ năng nâng cao:** Bám tường (*Wall Slide*), leo gờ tường (*Ledge Climb*), lướt (*Dash*).
- **Hệ thống chiến đấu:** Tấn công đa hướng (Tấn công thường, chém lên `Attack Up`, chém xuống `Attack Down`).
- **Máu & Giao diện (HUD):** Hiển thị thanh máu dạng mặt nạ (*Masks*), hiệu ứng nhận sát thương và thời gian bất tử tạm thời (*Invincibility Frames*).

### 2. 🦇 Kẻ địch (Enemies & AI)
- **Fly Enemy:** Kẻ địch bay lơ lửng, tự động phát hiện người chơi khi vào vùng kích hoạt (*Detection Area*), rượt đuổi và nhận sát thương/chết.
- **Slime Enemy:** Kẻ địch mặt đất tuần tra và gây sát thương va chạm.

### 3. 🗺️ Môi trường & Bản đồ (Level & Camera)
- Hệ thống **Parallax Background** đa lớp tạo chiều sâu không gian.
- **Dynamic Camera Limits:** Quản lý giới hạn khung nhìn camera tự động thông qua các điểm mốc `Marker2D` (`TopLeft`, `BottomRight`), dễ dàng mở rộng và tùy chỉnh cho từng màn chơi.
- Đồ họa môi trường phong phú (Moss Hole, Tear City).

---

## 🕹️ Bảng điều khiển (Controls)

| Phím | Hành động |
| :--- | :--- |
| <kbd>A</kbd> / <kbd>D</kbd> | Di chuyển sang Trái / Phải |
| <kbd>Space</kbd> | Nhảy (*Jump*) |
| <kbd>Shift</kbd> | Lướt / Chạy nhanh (*Sprint / Dash*) |
| <kbd>J</kbd> / <kbd>Z</kbd> / Chuột trái | Tấn công (*Attack*) |
| <kbd>W</kbd> + Tấn công | Tấn công hướng lên (*Attack Up*) |
| <kbd>S</kbd> + Tấn công (trên không) | Tấn công hướng xuống (*Attack Down*) |

---

## 🛠️ Cài đặt & Trải nghiệm

1. **Yêu cầu:** [Godot Engine 4.x](https://godotengine.org/download) (Khuyên dùng Godot 4.3 trở lên).
2. **Các bước mở dự án:**
   - Clone repository về máy:
     ```bash
     git clone https://github.com/nvh2vn/2d_game.git
     ```
   - Mở **Godot Engine** $\rightarrow$ chọn **Import**.
   - Chọn đường dẫn đến thư mục dự án và chọn file `project.godot`.
   - Nhấn **Import & Edit** để bắt đầu trải nghiệm hoặc chỉnh sửa!

---

## 📁 Cấu trúc thư mục

```text
├── assets/
│   ├── art/                # Spritesheets, textures, UI, background, âm thanh
│   ├── prefabs/            # Các đối tượng mẫu (Player, Enemies...)
│   ├── resources/          # Tài nguyên Tileset, Physics Material
│   ├── scenes/             # Các màn chơi (Levels)
│   └── scripts/            # Mã nguồn GDScript
│       ├── player/         # Logic điều khiển nhân vật chính
│       └── enemies/        # Logic AI kẻ địch
├── project.godot           # File cấu hình dự án Godot
├── .gitignore              # Bỏ qua các file cache tạm thời của engine
└── README.md               # Tài liệu giới thiệu dự án
```

---

## 📜 Giấy phép
Dự án được phát triển phục vụ mục đích học tập và nghiên cứu lập trình game 2D trên Godot Engine.
