# Evensong setup check for a Windows-native machine (not WSL).
# Run from the repository root:
#   powershell -ExecutionPolicy Bypass -File tools\check-setup.ps1
# Messages are ASCII on purpose: Windows PowerShell 5.1 misreads BOM-less UTF-8.
# Config values are read with normal precedence (local > global > system).

$script:ok = 0; $script:fail = 0; $script:warn = 0
function Pass($m) { Write-Host "[ OK ] $m" -ForegroundColor Green; $script:ok++ }
function Fail($m) { Write-Host "[FAIL] $m" -ForegroundColor Red; $script:fail++ }
function Warn($m) { Write-Host "[WARN] $m" -ForegroundColor Yellow; $script:warn++ }
function Info($m) { Write-Host "[INFO] $m" }

$osArch = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment').PROCESSOR_ARCHITECTURE
Info "machine: $env:COMPUTERNAME, OS arch: $osArch, this shell: $env:PROCESSOR_ARCHITECTURE"
if ((Get-Location).Path -like '\\wsl*') { Fail "repo is inside WSL; clone it on a Windows drive (e.g. C:\Dev\evensong)" }

# --- git and LFS ---
if (Get-Command git -ErrorAction SilentlyContinue) { Pass "git: $(git --version)" }
else { Fail "git not found -> winget install --id Git.Git -e"; exit 1 }

$lfs = git lfs version 2>$null
if ($LASTEXITCODE -eq 0) { Pass "git-lfs: $lfs" } else { Fail "git-lfs not found (bundled with Git for Windows)" }
if ($osArch -eq 'ARM64' -and $lfs -like '*amd64*') { Warn "x64 Git runs emulated on ARM64; reinstall the ARM64 build of Git for Windows" }
if ((git config filter.lfs.required) -eq 'true') { Pass "git lfs install done" }
else { Fail "run: git lfs install" }

$name = git config user.name; $mail = git config user.email
if ($name -and $mail) {
    if ($mail -like '*@users.noreply.github.com') { Pass "git identity: $name <$mail>" }
    else { Warn "git email is not the GitHub noreply address: $mail" }
} else { Fail "git identity missing: git config --global user.name / user.email" }

if ((git config init.defaultBranch) -eq 'main') { Pass "init.defaultBranch = main" }
else { Warn "run: git config --global init.defaultBranch main" }
if ((git config core.longpaths) -eq 'true') { Pass "core.longpaths = true" }
else { Warn "run: git config --global core.longpaths true" }

# --- repository ---
$top = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) { Fail "not inside the evensong repository"; exit 1 }
Pass "repo: $top"
$origin = git remote get-url origin 2>$null
if ($origin -like '*ddigle/evensong*') { Pass "origin: $origin" } else { Warn "unexpected origin: $origin" }

$dirty = git status --porcelain
if (-not $dirty) { Pass "working tree clean" } else { Warn "working tree has changes (git status)" }

# LFS files must be real images, not pointer text
$lfsFiles = git lfs ls-files -n
$pointers = @()
foreach ($f in $lfsFiles) {
    $p = Join-Path $top $f
    if (-not (Test-Path $p)) { continue }
    $fs = [System.IO.File]::OpenRead($p)
    try { $buf = New-Object byte[] 8; [void]$fs.Read($buf, 0, 8) } finally { $fs.Close() }
    if ([System.Text.Encoding]::ASCII.GetString($buf) -eq 'version ') { $pointers += $f }
}
if ($lfsFiles.Count -eq 0) { Warn "no LFS files found" }
elseif ($pointers.Count -eq 0) { Pass "LFS files downloaded: $($lfsFiles.Count)" }
else { Fail "$($pointers.Count) LFS pointer files not downloaded -> git lfs pull" }

# text files should be LF in the working tree (.gitattributes: * text=auto eol=lf)
$crlf = git ls-files --eol | Where-Object { $_ -match 'i/lf\s+w/crlf' }
if (-not $crlf) { Pass "line endings: LF" }
else { Warn "$(@($crlf).Count) files checked out as CRLF -> commit or stash first, then: git rm --cached -r . ; git reset --hard" }

# --- tools ---
$py = Get-Command py -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
if ($py) { Pass "python: $(& $py.Source --version 2>&1)" }
else { Warn "python not found -> winget install --id Python.Python.3.12 -e (needed for tools/art)" }

$venvPy = Join-Path $top '.venv\Scripts\python.exe'
if (Test-Path $venvPy) {
    & $venvPy -c "import PIL, numpy" 2>$null
    if ($LASTEXITCODE -eq 0) { Pass ".venv ready for tools/art" }
    else { Warn ".venv missing packages -> .venv\Scripts\pip install -r tools\art\requirements.txt" }
} else { Warn "no .venv -> py -m venv .venv ; .venv\Scripts\pip install -r tools\art\requirements.txt" }

if (Get-Command claude -ErrorAction SilentlyContinue) { Pass "claude: $(claude --version 2>$null)" }
else { Warn "Claude Code not found -> irm https://claude.ai/install.ps1 | iex" }
if (Get-Command codex -ErrorAction SilentlyContinue) { Info "codex found (optional)" }

Write-Host ""
Write-Host "summary: $script:ok ok, $script:warn warn, $script:fail fail"
if ($script:fail -gt 0) { exit 1 }
