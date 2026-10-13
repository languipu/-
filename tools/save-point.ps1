# save-point.ps1 —— 打一个"确认点"：存档 + 贴标签 + 上传 GitHub
#
# 用法：
#   pwsh -File .\tools\save-point.ps1 -Message "第 1 次确认：需求整理"
#   pwsh -File .\tools\save-point.ps1 -Message "..." -Tag ok-5      # 手动指定标签
#   pwsh -File .\tools\save-point.ps1 -Message "..." -NoPush        # 只存本地，不上传

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "这次存档的说明文字")]
    [string]$Message,

    [string]$Tag = "",

    [switch]$NoPush
)

$ErrorActionPreference = "Stop"

# 切到仓库根目录
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Write-Step($text) { Write-Host "==> $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "  OK  $text" -ForegroundColor Green }
function Write-Warn2($text){ Write-Host "  注意  $text" -ForegroundColor Yellow }

# ---------- 0. 检查是不是 Git 仓库 ----------
git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) {
    throw "当前目录不是 Git 仓库：$repoRoot"
}
Write-Ok "仓库根目录：$repoRoot"

# ---------- 1. 暂存全部改动 ----------
Write-Step "记录当前所有改动"
git add -A
if ($LASTEXITCODE -ne 0) { throw "git add 失败" }

$staged = (git status --porcelain)
if ([string]::IsNullOrWhiteSpace($staged)) {
    Write-Warn2 "没有任何改动需要存档，跳过提交"
    $madeCommit = $false
} else {
    $madeCommit = $true
    Write-Host $staged -ForegroundColor DarkGray
}

# ---------- 2. 提交 ----------
if ($madeCommit) {
    Write-Step "打存档（commit）"
    git commit -m $Message
    if ($LASTEXITCODE -ne 0) { throw "git commit 失败" }
    Write-Ok "提交完成：$Message"
}

# ---------- 3. 贴标签 ----------
if ([string]::IsNullOrWhiteSpace($Tag)) {
    $existing = git tag --list "ok-*"
    $max = -1
    foreach ($t in $existing) {
        if ($t -match '^ok-(\d+)$') {
            $n = [int]$Matches[1]
            if ($n -gt $max) { $max = $n }
        }
    }
    $Tag = "ok-" + ($max + 1)
}

if (git tag --list $Tag) {
    Write-Warn2 "标签 $Tag 已存在，本次不重复创建"
} else {
    Write-Step "贴标签：$Tag"
    git tag -a $Tag -m "$Tag | $Message"
    if ($LASTEXITCODE -ne 0) { throw "git tag 失败" }
    Write-Ok "标签已创建：$Tag"
}

# ---------- 4. 上传 GitHub ----------
$hasRemote = git remote
if ($NoPush) {
    Write-Warn2 "按要求跳过上传（-NoPush）"
} elseif ([string]::IsNullOrWhiteSpace($hasRemote)) {
    Write-Warn2 "还没有配置 GitHub 远程地址，本次只存了本地。"
    Write-Warn2 "配置好以后执行：git push -u origin main --tags"
} else {
    Write-Step "上传到 GitHub"
    git push origin HEAD --tags
    if ($LASTEXITCODE -ne 0) {
        Write-Warn2 "上传失败（可能是没登录或不联网）。本地存档是好的，修好后重新执行："
        Write-Host "     git push origin HEAD --tags" -ForegroundColor DarkGray
        exit 2
    }
    Write-Ok "已上传 GitHub"
}

# ---------- 5. 汇总 ----------
Write-Host ""
Write-Host "=================== 存档完成 ===================" -ForegroundColor Green
Write-Host "  标签      : $Tag"
Write-Host "  说明      : $Message"
Write-Host "  版本号    : $(git rev-parse --short HEAD)"
Write-Host "  当前分支  : $(git rev-parse --abbrev-ref HEAD)"
Write-Host "  已有存档点: $((git tag --list 'ok-*') -join ', ')"
Write-Host "================================================" -ForegroundColor Green
Write-Host "要退回某一次，执行： pwsh -File .\tools\rollback.ps1 -Tag <标签>" -ForegroundColor DarkGray
