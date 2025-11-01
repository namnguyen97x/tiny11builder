# GitHub Actions Workflow Runs Cleanup

Script để xóa lịch sử workflow runs trong GitHub Actions.

## Yêu cầu

1. **GitHub CLI (gh)** - Cần cài đặt và authenticate
   - Download: https://cli.github.com/
   - Authenticate: `gh auth login`

## Cách sử dụng

### 1. Xóa tất cả runs của một workflow cụ thể

```powershell
# Xóa tất cả runs của build.yml
.\tools\cleanup-workflow-runs.ps1 -WorkflowFile "build.yml"

# Xóa tất cả runs của build-nano.yml
.\tools\cleanup-workflow-runs.ps1 -WorkflowFile "build-nano.yml"
```

### 2. Xóa tất cả runs của tất cả workflows

```powershell
.\tools\cleanup-workflow-runs.ps1 -AllWorkflows
```

### 3. Dry run (chỉ xem, không xóa)

```powershell
# Xem sẽ xóa bao nhiêu runs (không thực sự xóa)
.\tools\cleanup-workflow-runs.ps1 -WorkflowFile "build.yml" -DryRun
```

### 4. Chỉ định repository khác

```powershell
.\tools\cleanup-workflow-runs.ps1 -WorkflowFile "build.yml" -Owner "username" -Repo "reponame"
```

## Lưu ý

⚠️ **CẢNH BÁO**: Việc xóa workflow runs là **KHÔNG THỂ HOÀN TÁC**. Hãy chắc chắn trước khi chạy!

- Sử dụng `-DryRun` trước để xem sẽ xóa gì
- Mỗi workflow run bị xóa sẽ mất vĩnh viễn logs và artifacts
- GitHub API có rate limit, script sẽ tự động delay giữa các lần xóa

## Ví dụ output

```
GitHub Workflow Runs Cleanup Script
====================================

✓ GitHub CLI found
✓ GitHub CLI authenticated

Repository: namnguyen97x/tiny11builder

Fetching workflows...
Found 2 workflow(s)

Processing workflow: Build Tiny11 ISO
Workflow ID: 12345678
Found 95 workflow run(s)
  Run #95 (ID: 12345) - Status: completed/success - Created: 2025-11-01T00:00:00Z
    Deleting... ✓ Deleted
  ...

  Deleted: 95
```

