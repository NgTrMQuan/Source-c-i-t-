# Tải, cài và fix lỗi Autodesk — ghi chú cho Claude Code

Website tĩnh nội bộ của nhóm OneCAD Vietnam, chạy trên GitHub Pages:
https://ngtrmquan.github.io/Source-c-i-t-/ (nhánh `main`, thư mục gốc). Người cập nhật: Minh Quân.

## Cấu trúc

| File | Vai trò |
|---|---|
| `index.html` | Trang chủ: tiêu đề "Tải, cài và fix lỗi Autodesk", nền sao bay như hai trang con, hai cổng dẫn sang hai trang con |
| `cai-dat.html` | Bộ cài đặt: vòng xoay 3D icon, lưới thẻ theo nhóm (lọc thì ẩn hẳn thẻ không khớp và cuộn tới đầu thư viện), bảng tải theo phiên bản. Đọc `data.json` |
| `loi.html` | Lỗi thường gặp: ô tìm kiếm + 2 phần: “Kinh nghiệm xử lý” (`source: "asana"`, chép từ Asana project “2. Kinh nghiệm xử lý”) và “Hướng dẫn từ Autodesk” (`source: "autodesk"`, người dùng gửi dần). Mỗi phần có ô chọn phần mềm (theo `section`) → danh sách tiêu đề → ngăn chi tiết trượt từ phải (Dấu hiệu / Nguyên nhân / Cách khắc phục / Hình minh họa `images[]` / Tham khảo). Link sâu: `#pm=<source>|<section>` và `#<id>`. Đọc `errors.json` |
| `data.json` | Danh sách phần mềm: `{name, icon, group, note, versions:[{v, links:[{label, url}]}]}`. Phiên bản mới đặt đầu mảng |
| `errors.json` | Danh sách lỗi: `{id, source, section, code, title, kind ("loi"|"huongdan"), software[], symptoms, cause, steps[], subs[], images[], refs[], asana, download, note, updated, draft}`. Trong `symptoms`, `cause`, `steps` có thể dùng `` `code` `` |
| `tools/xoa-sach-autodesk.bat` | Công cụ “Xóa sạch” (Clean Uninstall theo bài của Autodesk): file .bat tự xin quyền Admin, chạy phần PowerShell nhúng sau dòng `##PS_START`; chế độ 1 = chỉ kiểm tra, 2 = xóa (gõ `XOA`); ghi log + bảng kết quả ra Desktop. Lưu với xuống dòng CRLF, UTF-8. Ô “Xóa sạch” trong `loi.html` là mục `xoa-sach` của `errors.json` (trường `download`) |
| `icons/<slug>.png` | Icon phần mềm, tên file là slug của `name` (vd. `civil-3d.png`, `3ds-max.png`). Thiếu icon thì trang hiện chữ cái tạm |

Mỗi file HTML tự chứa CSS/JS của nó (không có bước build). Ba trang dùng chung một bộ CSS và đoạn JS nền sao (sao bay, dải Ngân Hà, sao băng, đá trôi) — khi sửa phần dùng chung, sửa cả ba file cho đồng bộ.

## Thiết kế

- Nền vũ trụ tối, font Unbounded (tiêu đề) + Be Vietnam Pro (nội dung).
- Màu theo nhóm: AutoCAD `#ff6b8b→#e0245e`, Revit & BIM `#4fa3ff→#2754e6`, Hạ tầng & Kết cấu `#2fe0b5→#0a9a82`, Cơ khí & Gia công `#ffc04a→#f2661b`, Vault `#a678ff→#5a37e0`, Đồ họa 3D `#ff6be0→#b52bc0`.
- Trang lỗi dùng tông cam/hồng `#ffb347→#ff4d6d`.
- Hiệu ứng luôn bật theo yêu cầu người dùng (`window.CALM=false` ở đầu mỗi trang, quy tắc tắt chuyển động nằm dưới `html.calm` nên không kích hoạt); kiểm tra cả màn hình điện thoại (≤640px).

## Quy ước

- Toàn bộ chữ trên giao diện bằng tiếng Việt có dấu.
- Không đổi tên/đường dẫn file đang được đồng nghiệp bookmark (`index.html`, `cai-dat.html`, `loi.html`).
- 4 lỗi trong `errors.json` đang là bản nháp (`draft: true`) — chỉ bỏ `draft` khi người dùng xác nhận nội dung.
- Bài Autodesk người dùng gửi: đọc toàn bộ bài, tóm tắt tiếng Việt vào mục `source: "autodesk"` (Dấu hiệu / Nguyên nhân / các cách trong `subs[]`, link bài gốc ở `refs[]`). Lệnh CMD, đường dẫn, tên file viết trong `` `...` `` → trang tự cho bấm để sao chép (hàm `isCmd` trong `loi.html`); tên nút/menu cũng để trong `` ` `` nhưng không sao chép. Link trong nội dung: bấm = sao chép, Ctrl + bấm = mở.
- Link tải trỏ thẳng máy chủ Autodesk; giữ nguyên tham số `authparam` khi chép link.
- Xem thử cục bộ: `python -m http.server` trong thư mục repo rồi mở http://localhost:8000 (mở trực tiếp file sẽ không đọc được JSON).
