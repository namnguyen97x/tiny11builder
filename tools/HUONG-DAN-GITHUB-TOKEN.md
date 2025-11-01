# Hướng Dẫn Lấy GitHub Token

Có 2 cách để authenticate với GitHub CLI:

## Cách 1: Login với Browser (Dễ Nhất) ✅

**Khuyên dùng cách này vì đơn giản nhất!**

Khi chạy `gh auth login`:
1. Chọn `GitHub.com`
2. Chọn `HTTPS`
3. Chọn **`Login with a web browser`** ← Chọn cái này
4. Mở trình duyệt và xác nhận
5. Done!

**Ưu điểm**: Không cần tạo token thủ công, tự động và an toàn.

---

## Cách 2: Dùng Personal Access Token

Nếu muốn dùng token (ví dụ: automation, CI/CD), làm theo các bước sau:

### Bước 1: Tạo Personal Access Token

1. **Đăng nhập GitHub**: https://github.com

2. **Vào Settings → Developer settings**:
   - Click avatar (góc trên bên phải) → **Settings**
   - Scroll xuống → **Developer settings** (bên trái)
   - Hoặc truy cập trực tiếp: https://github.com/settings/apps

3. **Vào Personal access tokens → Tokens (classic)**:
   - Click **Personal access tokens**
   - Click **Tokens (classic)**
   - Hoặc truy cập: https://github.com/settings/tokens

4. **Tạo token mới**:
   - Click **Generate new token** → **Generate new token (classic)**

5. **Cấu hình token**:
   - **Note**: Đặt tên dễ nhớ, ví dụ: "GitHub CLI - Workflow Cleanup"
   - **Expiration**: Chọn thời hạn (30 days, 90 days, hoặc No expiration)
   - **Scopes (quyền)**: Tích các quyền cần thiết:
     - ✅ `repo` (Full control of private repositories)
     - ✅ `workflow` (Update GitHub Action workflows)
     - ✅ `delete_repo` (nếu cần xóa repo)

6. **Generate token**:
   - Click **Generate token** ở cuối trang
   - ⚠️ **QUAN TRỌNG**: Copy token ngay lập tức! Token chỉ hiển thị 1 lần duy nhất!
   - Lưu token ở nơi an toàn (password manager, file encrypted)

### Bước 2: Dùng Token với GitHub CLI

Khi chạy `gh auth login`:
1. Chọn `GitHub.com`
2. Chọn `HTTPS`
3. Chọn **`Paste an authentication token`**
4. Paste token đã copy vào
5. Done!

### Hoặc dùng lệnh trực tiếp:

```powershell
# Set token làm biến môi trường
$env:GH_TOKEN = "ghp_your_token_here"

# Hoặc dùng lệnh login với token
gh auth login --with-token < token.txt
```

---

## Kiểm Tra Đã Login

```powershell
gh auth status
```

Nếu thấy:
```
✓ Logged in to github.com as namnguyen97x
✓ Git operations for github.com configured to use HTTPS
✓ Token: gho_xxxxxxxxxxxxx
```

→ Đã login thành công!

---

## Lưu Ý Bảo Mật

⚠️ **Quan trọng**:
- Token có quyền truy cập như password của bạn
- **KHÔNG** commit token vào git
- **KHÔNG** chia sẻ token công khai
- Nếu token bị lộ → Revoke ngay lập tức:
  - Vào: https://github.com/settings/tokens
  - Click **Revoke** bên cạnh token
- Token classic có thể được thay thế bằng fine-grained tokens (an toàn hơn)

---

## Troubleshooting

### Token không hoạt động?
→ Kiểm tra token còn hạn, có đủ quyền, chưa bị revoke

### "Permission denied" khi chạy cleanup script?
→ Token thiếu quyền `workflow` hoặc `repo`

### Muốn xem token hiện tại?
```powershell
gh auth status
```

### Muốn logout và login lại?
```powershell
gh auth logout
gh auth login
```

