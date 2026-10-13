# status.ps1 —— 查看存档情况（不修改任何东西，纯查看）

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$C = "Cyan"; $G = "Green"; $Y = "Yellow"

Write-Host ""
Write-Host "############ 旅游攻略自动化 —— 存档情况 ############" -ForegroundColor $C
Write-Host ""

# --- 1. 仓库位置 ---
Write-Host "【1】仓库位置" -ForegroundColor $C
Write-Host "     $repoRoot"

# --- 2. 是否连上 GitHub ---
Write-Host ""
Write-Host "【2】云端 GitHub 连接状态" -ForegroundColor $C
$remote = git remote -v 2>$null
if ([string]::IsNullOrWhiteSpace($remote)) {
    Write-Host "     未连接" -ForegroundColor $Y
    Write-Host "     （本地存档正常工作；连上后每次存档会自动上云）" -ForegroundColor DarkGray
} else {
    $remote -split "`n" | ForEach-Object { Write-Host "     $_" -ForegroundColor $G }
}

# --- 3. 存档点清单 ---
Write-Host ""
Write-Host "【3】确认点清单（你说过满意的存档）" -ForegroundColor $C
$tags = git tag --list "ok-*" --sort=version:refname
if (-not $tags) {
    Write-Host "     还没有任何确认点" -ForegroundColor $Y
} else {
    Write-Host ("     {0,-8} {1,-17} {2}" -f "标签", "时间", "内容") -ForegroundColor DarkGray
    foreach ($t in $tags) {
        $when  = git log -1 --format=%ad --date=format:'%Y-%m-%d %H:%M' $t
        $subj  = git log -1 --format=%s $t
        $color = if ($t -eq $tags[-1]) { $G } else { "Gray" }
        Write-Host ("     {0,-8} {1,-17} {2}" -f $t, $when, $subj) -ForegroundColor $color
    }
    Write-Host "     （最后一行是当前所在的最新确认点）" -ForegroundColor DarkGray
}

# --- 4. 自动备份点 ---
Write-Host ""
Write-Host "【4】回退时的自动备份" -ForegroundColor $C
$bk = git tag --list "backup-*"
if (-not $bk) {
    Write-Host "     无（还没执行过回退）" -ForegroundColor DarkGray
} else {
    Write-Host ("     共 " + @($bk).Count + " 个：") -NoNewline
    Write-Host ($bk -join ", ") -ForegroundColor Gray
}

# --- 5. 有无未存档的改动 ---
Write-Host ""
Write-Host "【5】未存档的改动" -ForegroundColor $C
$s = git status --short
if ([string]::IsNullOrWhiteSpace($s)) {
    Write-Host "     无 —— 所有改动都已存档" -ForegroundColor $G
} else {
    Write-Host "     有以下改动还没存档：" -ForegroundColor $Y
    $s -split "`n" | ForEach-Object { if ($_ -ne "") { Write-Host "       $_" } }
}

# --- 6. 占用空间 ---
Write-Host ""
Write-Host "【6】存档占用空间" -ForegroundColor $C
$size = (Get-ChildItem (Join-Path $repoRoot ".git") -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Write-Host ("     " + [math]::Round($size/1KB,1) + " KB   （存档数据放在隐藏文件夹 .git 里）")
Write-Host ("     工作文件共 " + @(git ls-files).Count + " 个受管理")

# --- 7. 怎么用 ---
Write-Host ""
Write-Host "############ 怎么操作 ############" -ForegroundColor $C
Write-Host '  存档  : pwsh -File .\tools\save-point.ps1 -Message "说明文字"'
Write-Host "  回退  : pwsh -File .\tools\rollback.ps1 -Tag ok-1"
Write-Host "  看清单: pwsh -File .\tools\rollback.ps1 -List"
Write-Host "  或者   : 直接跟 AI 说「这个我满意，存档」/「退回 ok-1」" -ForegroundColor $G
Write-Host ""
