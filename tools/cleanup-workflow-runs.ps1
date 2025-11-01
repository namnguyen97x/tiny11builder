# Script to delete all workflow runs for a GitHub repository
# Requires GitHub CLI (gh) to be installed and authenticated
# Usage: .\cleanup-workflow-runs.ps1 -WorkflowFile "build.yml"
#        .\cleanup-workflow-runs.ps1 -WorkflowFile "build-nano.yml"
#        .\cleanup-workflow-runs.ps1 -AllWorkflows

param(
    [Parameter(Mandatory=$false)]
    [string]$WorkflowFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$AllWorkflows,
    
    [Parameter(Mandatory=$false)]
    [string]$Owner = "namnguyen97x",
    
    [Parameter(Mandatory=$false)]
    [string]$Repo = "tiny11builder",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false
)

Write-Host "GitHub Workflow Runs Cleanup Script" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Check if GitHub CLI is installed
try {
    $ghVersion = gh --version 2>&1
    Write-Host "✓ GitHub CLI found" -ForegroundColor Green
} catch {
    Write-Error "GitHub CLI (gh) is not installed. Please install it first:"
    Write-Host "  https://cli.github.com/" -ForegroundColor Yellow
    exit 1
}

# Check if authenticated
try {
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Not authenticated with GitHub CLI. Please run: gh auth login"
        exit 1
    }
    Write-Host "✓ GitHub CLI authenticated" -ForegroundColor Green
} catch {
    Write-Error "Failed to check authentication status"
    exit 1
}

Write-Host ""
Write-Host "Repository: $Owner/$Repo" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host ""
    Write-Host "⚠️  DRY RUN MODE - No runs will be deleted" -ForegroundColor Yellow
    Write-Host ""
}

# Function to delete workflow runs
function Remove-WorkflowRuns {
    param(
        [string]$WorkflowId,
        [string]$WorkflowName
    )
    
    Write-Host ""
    Write-Host "Processing workflow: $WorkflowName" -ForegroundColor Cyan
    Write-Host "Workflow ID: $WorkflowId" -ForegroundColor Gray
    
    # Get all workflow runs
    Write-Host "Fetching workflow runs..."
    $runsJson = gh api "repos/$Owner/$Repo/actions/workflows/$WorkflowId/runs?per_page=100" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to fetch runs for $WorkflowName"
        return
    }
    
    $runs = $runsJson | ConvertFrom-Json
    $totalRuns = $runs.total_count
    
    Write-Host "Found $totalRuns workflow run(s)" -ForegroundColor Yellow
    
    if ($totalRuns -eq 0) {
        Write-Host "  No runs to delete" -ForegroundColor Gray
        return
    }
    
    $deletedCount = 0
    $failedCount = 0
    
    foreach ($run in $runs.workflow_runs) {
        $runId = $run.id
        $runNumber = $run.run_number
        $runStatus = $run.status
        $runConclusion = $run.conclusion
        $createdAt = $run.created_at
        
        Write-Host "  Run #$runNumber (ID: $runId) - Status: $runStatus/$runConclusion - Created: $createdAt" -ForegroundColor Gray
        
        if (-not $DryRun) {
            Write-Host "    Deleting..." -NoNewline
            
            # Delete the run
            $deleteResult = gh api -X DELETE "repos/$Owner/$Repo/actions/runs/$runId" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host " ✓ Deleted" -ForegroundColor Green
                $deletedCount++
            } else {
                Write-Host " ✗ Failed: $deleteResult" -ForegroundColor Red
                $failedCount++
            }
            
            # Small delay to avoid rate limiting
            Start-Sleep -Milliseconds 100
        } else {
            Write-Host "    [DRY RUN] Would delete" -ForegroundColor Yellow
            $deletedCount++
        }
    }
    
    Write-Host ""
    if ($DryRun) {
        Write-Host "  Would delete $deletedCount run(s)" -ForegroundColor Yellow
    } else {
        Write-Host "  Deleted: $deletedCount" -ForegroundColor Green
        if ($failedCount -gt 0) {
            Write-Host "  Failed: $failedCount" -ForegroundColor Red
        }
    }
}

# Get list of workflows
Write-Host ""
Write-Host "Fetching workflows..." -ForegroundColor Cyan

if ($AllWorkflows) {
    Write-Host "Fetching all workflows..." -ForegroundColor Yellow
    $workflowsJson = gh api "repos/$Owner/$Repo/actions/workflows" 2>&1
} elseif ($WorkflowFile) {
    Write-Host "Finding workflow: $WorkflowFile" -ForegroundColor Yellow
    $workflowsJson = gh api "repos/$Owner/$Repo/actions/workflows" 2>&1
} else {
    Write-Error "Please specify either -WorkflowFile or -AllWorkflows"
    exit 1
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to fetch workflows: $workflowsJson"
    exit 1
}

$workflows = $workflowsJson | ConvertFrom-Json

if ($workflows.total_count -eq 0) {
    Write-Host "No workflows found" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($workflows.total_count) workflow(s)" -ForegroundColor Green
Write-Host ""

# Process workflows
if ($AllWorkflows) {
    foreach ($workflow in $workflows.workflows) {
        Remove-WorkflowRuns -WorkflowId $workflow.id -WorkflowName $workflow.name
    }
} elseif ($WorkflowFile) {
    $found = $false
    foreach ($workflow in $workflows.workflows) {
        if ($workflow.path -like "*$WorkflowFile" -or $workflow.name -like "*$WorkflowFile*") {
            $found = $true
            Remove-WorkflowRuns -WorkflowId $workflow.id -WorkflowName $workflow.name
            break
        }
    }
    if (-not $found) {
        Write-Error "Workflow file '$WorkflowFile' not found"
        Write-Host ""
        Write-Host "Available workflows:" -ForegroundColor Yellow
        foreach ($workflow in $workflows.workflows) {
            Write-Host "  - $($workflow.path) ($($workflow.name))" -ForegroundColor Gray
        }
        exit 1
    }
}

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "Dry run completed. Use without -DryRun to actually delete." -ForegroundColor Yellow
} else {
    Write-Host "Cleanup completed!" -ForegroundColor Green
}

