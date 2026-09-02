# 🎮 BÁO CÁO PHÂN TÍCH VÀ THIẾT KẾ DỰ ÁN GAME 2D
## Chủ đề: Hollow Cavern (2D Action Platformer / Metroidvania)

---

## 1. 🏷️ Thể loại game (Genre)
* **Thể loại chính:** **2D Action Platformer** kết hợp các yếu tố **Metroidvania**.
* **Đặc trưng thể loại:**
  * Di chuyển mượt mà, đòi hỏi độ chính xác cao dựa trên nền tảng vật lý (*Precision Platforming*).
  * Hệ thống chiến đấu cận chiến nhịp độ nhanh (*Fast-paced Melee Combat*).
  * Khám phá thế giới phi tuyến tính với các kỹ năng được mở khóa dần theo tiến trình màn chơi (*Ability Gate / Progression*).

---

## 2. 📖 Cốt truyện (Storyline / Plot)
* **Bối cảnh:** Tại một vương quốc ngầm cổ xưa từng phồn vinh nhưng nay đã lụi tàn, bị bao phủ bởi lớp rêu phong, bào tử độc hại cùng sự trỗi dậy của các sinh vật bóng tối biến dị.
* **Nhân vật chính:** Một hiệp sĩ/chiến binh tí hon mang mặt nạ cổ đại thức tỉnh trong hang sâu tăm tối, mang trên mình lưỡi kiếm sắc bén cùng nguồn sinh lực kết tinh thành các mảnh mặt nạ (*Masks*).
* **Hành trình & Mục tiêu:**
  * Thâm nhập qua các tầng địa chất nguy hiểm: từ hang rêu sâu (*Moss Hole*) đến những thành phố phế tích u uất (*Tear City*).
  * Tiêu diệt các loài quái vật canh giữ hang sâu và đối đầu với thế lực ác mộng (*Nightmare Boss*).
  * Khám phá bí ẩn của sự suy tàn và phục hồi lại sự cân bằng cho thế giới ngầm.

---

## 3. 🌍 Thế giới game (Game World / Setting)
* **Không gian & Địa hình:**
  * **Mossy Hollow (Vực Rêu):** Địa hình gồm các vách đá bám đầy rêu xanh, bậc thang lơ lửng (*Floating Platforms*), thảm thực vật cử động và các loài hoa tiết chất độc.
  * **Ruined Kingdom / Tear City:** Các công trình cổ đổ nát, bẫy rào, vực thẳm và hệ thống cổng dịch chuyển cổ xưa kết nối giữa các vùng đất.
* **Cấu trúc không gian:** Hệ thống bản đồ 2D dạng lưới cuộn mượt mà, kết hợp **Parallax Scrolling** nhiều lớp tạo chiều sâu không gian cho hang động ngầm.

---

## 4. 🎨 Phong cách nghệ thuật (Art Style)
* **Phong cách chủ đạo:** **Stylized Dark Fantasy / Gothic 2D** kết hợp giữa nét vẽ tay mượt mà (*Hand-drawn*) và mỹ thuật dạng Sprite. Lấy cảm hứng mạnh mẽ từ phong cách của *Hollow Knight / Silksong*.
* **Tông màu (Color Palette):** Tông màu u tối, lạnh (xanh rêu đậm, lam đen, xám tro, tím bóng đêm) điểm xuyết ánh sáng trắng từ nhân vật và ánh dạ quang từ thực vật kỳ bí.
* **Hoạt ảnh (Animation):** Diễn họa dạng Frame-by-frame mượt mà:
  * **Nhân vật:** Đi, chạy bứt tốc, leo bám mép tường, chém đa hướng, hiệu ứng mờ tan biến khi tử trận.
  * **Môi trường:** Cây cối lay động theo gió, hoa nở theo chu kỳ, gai nhọn nguy hiểm.
* **Giao diện người dùng (UI/HUD):** Tối giản và cổ điển với hệ thống các mặt nạ sứ trắng biểu thị sinh lực và hiệu ứng vỡ/nạp máu (*Blood Splash / Blood Load*).

---

## 5. ⚔️ Cơ chế game (Game Mechanics / Gameplay)

### 5.1. Hệ thống di chuyển nâng cao (Locomotion & Mobility)
* **Cơ bản:** Đi bộ (*Walk*), chạy nhanh (*Sprint*), nhảy biến thiên độ cao (*Jump*).
* **Cơ chế bổ trợ độ mượt (Quality of Life):**
  * **Coyote Time:** Cho phép nhảy dù đã bước hụt khỏi mép vực trong tích tắc.
  * **Jump Buffer:** Nhận diện lệnh nhảy trước khi chạm đất.
* **Kỹ năng mở khóa (Unlockable Skills):**
  * **Air Dash:** Lướt nhanh xuyên không trung né đòn tức thời.
  * **Double Jump / Float:** Nhảy đúp 2 lần hoặc lơ lửng hãm đà rơi.
  * **Wall Slide & Wall Climb:** Trượt dọc vách đá và bật nhảy leo tường (*Wall Jump*).
  * **Ledge Climb:** Tự động phát hiện mép gờ bằng RayCast và kéo người trèo lên.

### 5.2. Hệ thống chiến đấu (Combat System)
* **Tấn công đa hướng:** Chém ngang phía trước, chém hướng lên (*Attack Up*) để đánh quái bay, và chém chúc xuống (*Attack Down / Pogo*) khi đang ở trên không.
* **Phản hồi va chạm (Combat Feedback):**
  * Chớp đỏ (*Red Flash*) khi trúng đòn.
  * Độ giật nảy nhẹ (*Knockback*) cho cả nhân vật và kẻ địch.
  * Khung hình bất tử (*I-Frames*) kèm hiệu ứng nhấp nháy mờ ảo giúp tránh nhận sát thương liên hoàn.

### 5.3. Hệ sinh thái Kẻ địch (Enemy AI)
* **Bug Enemy (Quái bọ đất):** Tuần tra mặt đất, sử dụng RayCast để tự động nhận biết vách tường hoặc mép vực để quay đầu; gây sát thương va chạm.
* **Fly Enemy (Quái bay):** Bay lơ lửng dạng sóng lượn (dao động hình sin). Khi người chơi đi vào vùng cảm biến (*Detection Area*), quái sẽ kích hoạt trạng thái truy đuổi (*Chase AI*).
* **Nightmare Enemy (Boss / Quái tinh anh):** Sở hữu chuỗi hoạt ảnh phức tạp gồm bắn đạn ma thuật (*Cast/Balloon*), lướt trên không (*AirDash*) và thế thủ kích hoạt.

### 5.4. Hệ thống Máu & Hồi sinh (Health & Respawn)
* **Masks Health:** Máu chia theo từng nấc mặt nạ (Mặc định 5 Masks).
* **Heal Mechanic:** Hồi phục sinh mệnh với hiệu ứng nạp năng lượng sinh học (*Blood Load*).
* **Cơ chế tử trận (Death Sequence):** Hiệu ứng vùng tối tử thần (*Death Vignette*) bung tỏa từ tâm người chơi kèm hiệu ứng tan biến và tự động tải lại màn chơi.

---

## 6. 🛠️ Công nghệ & Công cụ thực hiện (Tech Stack & Assets)

| Thành phần | Công nghệ / Công cụ được sử dụng |
| :--- | :--- |
| **Game Engine** | **Godot Engine 4.x** (chạy Renderer tương thích cao `GL Compatibility` / `Mobile`). |
| **Ngôn ngữ lập trình** | **GDScript** (Ngôn ngữ hướng đối tượng chuyên dụng, cú pháp linh hoạt tương tự Python). |
| **Hệ thống Vật lý** | **Godot 2D Physics Engine** (`CharacterBody2D`, `RayCast2D`, `Area2D` quản lý Hitbox/Hurtbox). |
| **Công cụ Đồ họa & Thiết kế** | **Aseprite / Adobe Photoshop / Krita** (cắt ghép và thiết kế Spritesheet, Tileset). |
| **Quản lý Bản đồ** | **Godot TileMapLayer & TileSet Resources** (kết hợp quản lý tự động Collision và Navigation). |
| **Tài nguyên đồ họa (Assets)** | • **Player & UI:** Bộ Sprite nhân vật, hệ thống Mask UI, hiệu ứng máu / vignette.<br>• **Enemies:** Bộ hoạt ảnh Bug, Fly, Boss Nightmare (Cast, Dash, Die).<br>• **Environment:** Mossy Tileset (nền, gờ đá, thực vật chuyển động, hoa bẫy độc). |
| **Quản lý mã nguồn** | **Git & GitHub** |

---

## 💡 Gợi ý bố cục khi trình bày Slide (Presentation Flow)
1. **Slide 1:** Tên dự án, thành viên nhóm và Thể loại game.
2. **Slide 2:** Cốt truyện & Bối cảnh thế giới ngầm kỳ bí.
3. **Slide 3:** Phong cách mỹ thuật (*Art Style*) & Trình diễn hình ảnh nhân vật / quái vật.
4. **Slide 4:** Cơ chế di chuyển & Combat đa hướng (Điểm nhấn gameplay).
5. **Slide 5:** Thiết kế AI kẻ địch & Bản đồ màn chơi (*Level Design & Camera Marker*).
6. **Slide 6:** Công nghệ sử dụng (Godot 4, GDScript, RayCast AI) & Demo ngắn gameplay thực tế.
