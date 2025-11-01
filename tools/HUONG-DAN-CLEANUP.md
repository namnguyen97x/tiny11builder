# Hướng Dẫn Xóa Lịch Sử Workflow Runs

## Bước 1: Cài đặt GitHub CLI (gh)

### Windows:
```powershell
# Cách 1: Dùng winget (Windows 11/10)
winget install --id GitHub.cli

# Cách 2: Download và cài thủ công
# https://cli.github.com/
```

### Kiểm tra đã cài:
```powershell
gh --version
```

## Bước 2: Authenticate với GitHub

```powershell
gh auth login
```

Chọn:
- GitHub.com
- HTTPS
- Login với browser (dễ nhất) hoặc token
- Chọn quyền cần thiết

Kiểm tra đã login:
```powershell
gh auth status
```

## Bước 3: Chạy Script

### Tùy chọn 1: Xóa runs của một workflow cụ thể

```powershell
# Xem trước (không xóa)
.\tools\cleanup-workflow-runs.ps1 -WorkflowFile "build.yml" -DryRun

# Xóa thật sự
.\tools\cleanup-workflow-runs.ps1 -WorkflowFile "build.yml"
```

### Tùy chọn 2: Xóa runs của build-nano.yml

```powershell
# Xem trước
.\tools\cleanup-workflow-runs.ps1 -WorkflowFile "build-nano.yml" -DryRun

# Xóa thật sự
.\tools\cleanup-workflow-runs.ps1 -WorkflowFile "build-nano.yml"
```

### Tùy chọn 3: Xóa TẤT CẢ workflows

```powershell
# Xem trước
.\tools\cleanup-workflow-runs.ps1 -AllWorkflows -DryRun

# Xóa thật sự
.\tools\cleanup-workflow-runs.ps1 -AllWorkflows
```

## Ví dụ Output

```
GitHub Workflow Runs Cleanup Script
====================================

✓ GitHub CLI found
✓ GitHub CLI authenticated

Repository: namnguyen97x/tiny11builder

Fetching workflows...
Finding workflow: build.yml
Found 2 workflow(s)

Processing workflow: Build Tiny11 ISO
Workflow ID: 12345678
Found 95 workflow run(s)
  Run #95 (ID: 12345) - Status: completed/success - Created: 2025-11-01T00:00:00Z
    Deleting... ✓ Deleted
  Run #94 (ID: 12344) - Status: completed/failure - Created: 2025-11-01T00:01:00Z
    Deleting... ✓ Deleted
  ...

  Deleted: 95

====================================
Cleanup completed!
```

## Lưu ý Quan Trọng

⚠️ **CẢNH BÁO:**
- ❌ Không thể hoàn tác sau khi xóa
- ❌ Logs và artifacts sẽ bị mất vĩnh viễn
- ✅ Luôn dùng `-DryRun` trước để xem sẽ xóa gì
- ✅ Script tự động delay để tránh rate limiting
- ✅ Cần quyền `actions:write` trên repository

## Troubleshooting

### Lỗi: "GitHub CLI (gh) is not installed"
→ Cài GitHub CLI từ https://cli.github.com/

### Lỗi: "Not authenticated"
→ Chạy `gh auth login`

### Lỗi: "Permission denied"
→ Kiểm tra quyền truy cập repository, cần quyền admin hoặc có quyền `actions:write`

### Script chạy chậm
→ Bình thường, script delay 100ms giữa mỗi lần xóa để tránh rate limit

