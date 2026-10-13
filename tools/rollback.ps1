# rollback.ps1 —— 退回某个"确认点"（退回前会自动备份当前状态，绝不丢东西）
#
# 用法：
#   pwsh -File .\tools\rollback.ps1 -Tag ok-2      # 退回 ok-2
#   pwsh -File .\tools\rollback.ps1 -List          # 只看有哪些存档点，不动任何东西

[CmdletBinding()]
param(
    [string]$Tag = "",
    [switch]$List
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Write-Step($text) { Write-Host "==> $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "  OK  $text" -ForegroundColor Green }
function Write-Warn2($text){ Write-Host "  注意  $text" -ForegroundColor Yellow }

git rev-parse --is-inside-work-tree *> $null
if ($LASTEXITCODE -ne 0) { throw "当前目录不是 Git 仓库：$repoRoot" }

# ---------- 只列出存档点 ----------
if ($List -or [string]::IsNullOrWhiteSpace($Tag)) {
    Write-Host ""
    Write-Host "可用存档点（ok-*）：" -ForegroundColor Cyan
    $tags = git tag --list "ok-*" --sort=version:refname
    if (-not $tags) {
        Write-Warn2 "还没有任何存档点"
    } else {
        foreach ($t in $tags) {
            $when = git log -1 --format=%ad --date=format:'%Y-%m-%d %H:%M' $t
            $subj = git log -1 --format=%s $t
            Write-Host ("  {0,-8} {1}  {2}" -f $t, $when, $subj)
        }
        Write-Host ""
        Write-Host "退回命令示例： pwsh -File .\tools\rollback.ps1 -Tag ok-1" -ForegroundColor DarkGray
    }
    return
}

# ---------- 0. 校验标签 ----------
if (-not (git tag --list $Tag)) {
    throw "找不到标签：$Tag （用 -List 看看有哪些）"
}

# ---------- 1. 回退前先自动备份当前状态 ----------
$stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = "backup-$stamp"
# 同一秒内连续回退时，标签名会重复，这里自动加序号避免撞车
$n = 1
while (git tag --list $backup) {
    $backup = "backup-$stamp-$n"
    $n++
}

Write-Step "先把当前状态备份成 $backup（这样退错了也能救回来）"
git add -A
$dirty = (git status --porcelain)
if (-not [string]::IsNullOrWhiteSpace($dirty)) {
    git commit -m "回退前自动备份（$stamp）" | Out-Null
    Write-Ok "未提交的改动已一起备份"
} else {
    Write-Ok "当前没有未提交的改动"
}
git tag -a $backup -m "回退到 $Tag 之前的自动备份（$stamp）"
if ($LASTEXITCODE -ne 0) { throw "创建备份标签失败" }
Write-Ok "备份标签：$backup"

# ---------- 2. 回退 ----------
Write-Step "把文件还原到 $Tag"
git reset --hard $Tag
if ($LASTEXITCODE -ne 0) { throw "回退失败，当前状态仍是安全的（备份标签 $backup 存在）" }
Write-Ok "已还原到 $Tag"

# ---------- 3. 汇总 ----------
$subj = git log -1 --format=%s $Tag
Write-Host ""
Write-Host "=================== 回退完成 ===================" -ForegroundColor Green
Write-Host "  已回到    : $Tag  ($subj)"
Write-Host "  当前版本号: $(git rev-parse --short HEAD)"
Write-Host "  退前备份  : $backup"
Write-Host "================================================" -ForegroundColor Green
Write-Host "如果这次退错了，执行下面这句就能变回去：" -ForegroundColor DarkGray
Write-Host "     pwsh -File .\tools\rollback.ps1 -Tag $backup" -ForegroundColor DarkGray
