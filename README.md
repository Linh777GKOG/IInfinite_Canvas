

### 1. Tổng quan Dự án
**Tên dự án :** Infinite Canvas.

**Mô tả ngắn gọn:** Ứng dụng vẽ phác thảo và thiết kế vector-based với canvas vô hạn dành riêng cho Android, lấy cảm hứng trực tiếp từ Concepts (iOS/Windows). Tập trung vào trải nghiệm mượt mà, hiệu suất cao trên mọi thiết bị Android, kể cả máy tầm trung.

**Mục tiêu chính:**
- Tạo ra một công cụ vẽ tự do mạnh mẽ, không giới hạn không gian sáng tạo.
- Đạt hiệu suất 60 FPS ngay cả khi zoom sâu hoặc có hàng nghìn nét vẽ.
- Hỗ trợ tốt bút stylus (Samsung S Pen, Lenovo, Huawei…) với pressure & tilt sensitivity.
- ra mắt trong vòng 4–5 tháng.

**Đối tượng người dùng:**
- Nghệ sĩ kỹ thuật số, UI/UX designer, kiến trúc sư, sinh viên mỹ thuật, người ghi chú ý tưởng.
- Người dùng Android 18–45 tuổi, ưu tiên tablet và điện thoại màn hình lớn.

**Phạm vi MVP (v1.0):**
- Canvas vô hạn + layer + công cụ vẽ cơ bản + xuất PNG/SVG/PDF.
- Không bao gồm: cloud sync, cộng tác real-time, marketplace brush.

### 2. Chức năng (Features)

| Nhóm                  | Tính năng MVP (Phase 1)                                | Phase 2 (Sau 6 tháng)                          |
|-----------------------|--------------------------------------------------------|-------------------------------------------------|
| Canvas                | Canvas vô hạn, zoom 10–10000%, pan mượt               | Snap to grid, perspective grid                 |
| Công cụ vẽ            | Bút chì, bút mực, cọ mềm, tẩy, fill, eyedropper       | Brush tùy chỉnh, import .abr, vector shapes    |
| Layer & Tổ chức       | Tối đa 15 layer, blend mode cơ bản, nhóm layer        | Layer mask, adjustment layer                   |
| Tương tác             | Pinch-zoom, 2-finger pan, quick undo/redo (30 bước)   | Lasso + transform tool, symmetry drawing       |
| Văn bản & Shape       | Text tool + basic shapes (line, rectangle, circle)    | Editable vector shapes, boolean operations     |
| Xuất & Lưu            | Lưu project (.isketch), xuất PNG, SVG, PDF            | Export PSD, share link, cloud backup           |
| Hỗ trợ Stylus         | Pressure + tilt (Samsung, EMR, AES)                    | Palm rejection nâng cao, hover preview         |
| Giao diện             | Toolbar thu gọn, HUD điều khiển, dark mode            | Customizable toolbar, gesture shortcuts        |

### 3. Ngôn ngữ và Công cụ

| Thành phần            | Công nghệ lựa chọn (2025)                              | Lý do chọn                                      |
|-----------------------|--------------------------------------------------------|--------------------------------------------------|
| Ngôn ngữ              | 100% Kotlin                                            | Hiện đại, null-safety, coroutines                |
| IDE                   | Android Studio Koala / Meerkat                         | Hỗ trợ Compose tốt nhất                          |
| UI Framework          | Jetpack Compose + Material 3                           | Responsive, dễ animate, hỗ trợ tablet tốt        |
| Render Engine         | Custom View (Compose Canvas) + OpenGL fallback         | Hiệu suất cao hơn View cũ                        |
| Vector Drawing        | Path + PathMeasure + tự build vector engine            | Kiểm soát hoàn toàn, tiết kiệm RAM               |
| Lưu trữ project       | Room Database + Protocol Buffers (.proto)              | Nhanh, binary, dễ mở rộng                        |
| Thư viện phụ          | Coil (image), Accompanist (system UI), Hilt/Dagger    | Nhẹ, hiện đại                                    |
| Quản lý dự án         | Git + GitHub Actions + Jira/Trello                     | CI/CD tự động                                    |
| Target SDK            | minSdk 24 (Android 7) → targetSdk 35                   | Phủ 98% thiết bị hiện tại                        |

### 4. Giải pháp Kỹ thuật (Chi tiết thực tế)

#### 4.1 Infinite Canvas Engine
- Không dùng Bitmap lớn → dùng Quad-tree + Tiling 512×512 hoặc 1024×1024.
- Mỗi tile là một Picture (Skia) hoặc Compose Canvas snapshot.
- Chỉ render các tile nằm trong viewport + 1 lớp buffer xung quanh.
- Khi zoom < 30% → tự động chuyển sang low-res tile để tiết kiệm RAM.

#### 4.2 Vector-based Strokes (giống Concepts)
- Mỗi nét vẽ là một VectorStroke object gồm danh sách điểm (x, y, pressure, tilt, time).
- Sử dụng Catmull-Rom spline hoặc tự build simplified polyline để làm mượt.
- Render bằng Compose Canvas + Shader (độ dày thay đổi theo pressure).

#### 4.3 Layer System
- Mỗi layer chứa danh sách VectorStroke + optional Raster cache.
- Khi zoom > 200% → render vector, khi zoom xa → dùng cache bitmap để tăng tốc.
- Composite bằng Canvas.drawPicture() hoặc RenderNode (API 29+).

#### 4.4 Undo/Redo
- Command Pattern + tối đa 50 bước.
- Lưu diff thay vì toàn bộ state → tiết kiệm bộ nhớ.

#### 4.5 Stylus Support
- Sử dụng MotionEvent.TOOL_TYPE_STYLUS + getAxisValue(AXIS_PRESSURE, AXIS_TILT).
- Samsung S Pen: bật Pointer Icon và hover preview.

#### 4.6 Export SVG
- Tự build SVG generator từ VectorStroke → xuất file SVG thực sự (không phải rasterize).

### 5. Kế hoạch Phát triển

| Tuần | Mục tiêu chính                              | Deliverable                            |
|------|---------------------------------------------|----------------------------------------|
| 1–2  | Nghiên cứu + UI/UX Design                   | Wireframe, Design system (Figma)       |
| 3–5  | Core Canvas Engine + Gesture                | Infinite zoom/pan hoạt động mượt       |
| 6–8  | Vector Brush Engine + Pressure              | Vẽ được nét đẹp, hỗ trợ stylus         |
| 9–11 | Layer System + Undo/Redo                    | Đa layer, blend mode cơ bản            |
| 12–14| Toolbar, Color Picker, Basic Tools          | Giao diện hoàn chỉnh                   |
| 15–16| Export PNG/SVG/PDF + Project Save           | Lưu và mở file                         |
| 17–18| Tối ưu hiệu suất + Test trên 20+ devices    | 60 FPS trên máy yếu                    |
| 19   | Closed Beta (100 testers)                   | Thu thập feedback                      |
| 20   | Fix bug + Release v1.0 lên Google Play      | Official launch                        |


