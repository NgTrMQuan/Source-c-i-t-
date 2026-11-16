# Source cài đặt

Thư viện link bộ cài phần mềm Autodesk dùng chung trong nhóm OneCAD Vietnam.

## Cấu trúc

| File | Vai trò |
|---|---|
| `index.html` | Giao diện trang web. Thường không cần sửa. |
| `data.json` | Danh sách phần mềm, phiên bản và link tải. Cập nhật dữ liệu tại đây. |

## Cập nhật link

1. Mở `data.json` trên GitHub, bấm biểu tượng ✏️ (Edit this file).
2. Thêm hoặc sửa theo mẫu bên dưới.
3. Bấm **Commit changes**. Trang tự cập nhật sau khoảng 1 phút.

Mỗi phần mềm có dạng:

```json
{
  "name": "Inventor",
  "icon": "🔩",
  "group": "Cơ khí & Gia công",
  "note": null,
  "versions": [
    {
      "v": "2027",
      "links": [
        { "label": "Part 1", "url": "https://..." },
        { "label": "Part 2", "url": "https://..." }
      ]
    }
  ]
}
```

- Phiên bản mới đặt **lên đầu** mảng `versions`.
- Nhóm (`group`) dùng một trong các tên sẵn có: `AutoCAD`, `Revit & BIM`, `Hạ tầng & Kết cấu`, `Cơ khí & Gia công`, `Vault`, `Đồ họa 3D`.
- `note`: ghi chú cảnh báo hiện trong bảng chi tiết; để `null` nếu không có.
- Chú ý dấu phẩy giữa các mục. Nếu trang báo "Không tải được data.json", hãy dán nội dung file vào https://jsonlint.com để tìm lỗi.

## Bật GitHub Pages

Settings → Pages → Source: **Deploy from a branch** → Branch: `main` / `(root)` → Save.
