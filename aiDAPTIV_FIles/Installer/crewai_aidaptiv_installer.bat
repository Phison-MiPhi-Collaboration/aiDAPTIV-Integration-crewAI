@echo off
setlocal EnableExtensions
title CrewAI - Create a Crew Manually (aiDAPTIV KV-Cache)

rem ======================================================================
rem  create_crew_aidaptiv.bat
rem  Automates "Way 2: Create a crew manually" from the
rem  CrewAI User Manual - aiDAPTIV KV-Cache Integration Edition.
rem
rem    Part 1   : check Python / uv, install CrewAI 1.15.23
rem    Step 1-2 : crewai create crew <name>   (wizard answers are automated)
rem    Step 4   : put the aiDAPTIV llm block into agents\*.jsonc
rem               and pin crewai[tools]==1.15.23 in pyproject.toml
rem    (stops here - crewai install / crewai run are NOT executed)
rem
rem  Run it from the folder where the new project folder should be created.
rem  (The questions, the server check and the file edit are done by the
rem   PowerShell section at the bottom of this file.)
rem ======================================================================

set "BATFILE=%~f0"
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
set "CREWAI_VER=1.15.23"
set "PYARG="
set "AID_ANS=%TEMP%\aid_crew_answers.txt"
set "AID_CFG=%TEMP%\aid_crew_config.json"
set "AID_NAMEF=%TEMP%\aid_crew_name.txt"
set "CLOG=%TEMP%\aid_crew_create.log"

echo.
echo  ============================================================
echo    CrewAI  -  Create a Crew Manually  (aiDAPTIV KV-Cache)
echo    CrewAI version used by this manual: %CREWAI_VER%
echo  ============================================================
echo    Project will be created in: %CD%
echo.

rem "Run as administrator" starts in %WINDIR%\System32 - never create the project there.
set "AID_MODE=where"
call :runps
if errorlevel 1 goto :fail

rem ----------------------------------------------------------------------
echo  [1/6] Checking Python (CrewAI needs 3.10 or newer, below 3.14)
rem ----------------------------------------------------------------------
where python >nul 2>&1
if errorlevel 1 goto :py_missing
python -c "import sys; sys.exit(0 if (3,10)<=sys.version_info[:2]<(3,14) else 1)" >nul 2>&1
if errorlevel 1 goto :py_unsupported
for /f "delims=" %%V in ('python --version 2^>^&1') do echo        OK - %%V
goto :py_done
:py_missing
echo        Python was not found on PATH. uv will download Python 3.13 for CrewAI.
set "PYARG=--python 3.13"
goto :py_done
:py_unsupported
echo        No usable default Python 3.10 - 3.13 found. uv will use Python 3.13.
set "PYARG=--python 3.13"
:py_done

rem ----------------------------------------------------------------------
echo  [2/6] Checking uv (Python package manager used by CrewAI)
rem ----------------------------------------------------------------------
set "PATH=%USERPROFILE%\.local\bin;%PATH%"
where uv >nul 2>&1
if not errorlevel 1 goto :uv_ok
echo        uv not found - installing it now (official installer from the manual)...
powershell -NoProfile -ExecutionPolicy ByPass -Command "irm https://astral.sh/uv/install.ps1 | iex"
set "PATH=%USERPROFILE%\.local\bin;%USERPROFILE%\.cargo\bin;%PATH%"
where uv >nul 2>&1
if not errorlevel 1 goto :uv_ok
echo.
echo  [ERROR] uv could not be installed. Install it manually, then run this file again:
echo          powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
goto :fail
:uv_ok
for /f "delims=" %%V in ('uv --version 2^>^&1') do echo        OK - %%V

rem ----------------------------------------------------------------------
echo  [3/6] Checking CrewAI %CREWAI_VER%
rem ----------------------------------------------------------------------
uv tool list 2>nul | findstr /B /C:"crewai v%CREWAI_VER%" >nul
if not errorlevel 1 goto :crewai_have
echo        CrewAI %CREWAI_VER% not installed - installing (this can take a few minutes)...
uv tool install crewai==%CREWAI_VER% %PYARG% --force
if not errorlevel 1 goto :crewai_have
echo        First attempt failed - retrying with Python 3.13...
uv tool install crewai==%CREWAI_VER% --python 3.13 --force
if not errorlevel 1 goto :crewai_have
echo.
echo  [ERROR] CrewAI %CREWAI_VER% could not be installed. See the messages above.
goto :fail
:crewai_have
echo        Note: adding uv's tool folder to your user PATH permanently
echo              (uv tool update-shell) so crewai also works in new terminals.
uv tool update-shell >nul 2>&1
for /f "delims=" %%B in ('uv tool dir --bin 2^>nul') do set "PATH=%%B;%PATH%"
crewai version >nul 2>&1
if not errorlevel 1 goto :crewai_ok
echo.
echo  [ERROR] The crewai command is still not found. Close this window, open a new
echo          terminal and run this file again (uv tool update-shell was executed).
goto :fail
:crewai_ok
for /f "delims=" %%V in ('crewai version 2^>^&1') do echo        OK - %%V

rem ----------------------------------------------------------------------
echo.
echo  [4/6] Your crew details  (press Enter to accept the [default])
rem ----------------------------------------------------------------------
set "AID_MODE=ask"
call :runps
if errorlevel 1 (
    echo.
    echo  [ERROR] Input was cancelled or failed.
    goto :fail
)
set "PROJ="
set /p "PROJ=" <"%AID_NAMEF%"
if not defined PROJ (
    echo  [ERROR] No project name was captured.
    goto :fail
)

rem ----------------------------------------------------------------------
echo.
echo  [5/6] Checking the aiDAPTIV llama.cpp server
rem ----------------------------------------------------------------------
set "AID_MODE=check"
call :runps

rem ----------------------------------------------------------------------
echo.
echo  [6/6] Creating the crew project (crewai create crew %PROJ%)
rem ----------------------------------------------------------------------
rem The wizard answers (role, goal, backstory, no tools, planning=n,
rem delegation=n, no more agents, task, expected output, no more tasks,
rem memory=n) were written to %AID_ANS% by the PowerShell section.
crewai create crew "%PROJ%" --skip-provider <"%AID_ANS%" >"%CLOG%" 2>&1
set "RC=%errorlevel%"
del "%AID_ANS%" >nul 2>&1
if not "%RC%"=="0" goto :create_failed
rem If the folder already exists, crewai asks "Override? [y/N]", eats the piped
rem answers, prints "Cancelled." and still exits 0. The "folder already exists"
rem check in step 4 is the main guard; this catches anything that slips past it,
rem so the folder search below can never pick up (and edit) an older project.
findstr /C:"Cancelled." "%CLOG%" >nul 2>&1
if errorlevel 1 goto :created
:create_failed
echo.
echo  [ERROR] crewai create crew failed. Wizard output:
type "%CLOG%"
goto :fail
:created

rem CrewAI normalises the folder name (e.g. aiDAPTIV -> aidaptiv):
rem take the newest folder that contains crew.jsonc.
set "FOLDER="
for /f "delims=" %%D in ('dir /b /ad /o-d 2^>nul') do call :pickfolder "%%D"
if defined FOLDER goto :found
echo  [ERROR] The project folder was not found after creation. Wizard output:
type "%CLOG%"
goto :fail
:found
set "AID_PROJDIR=%CD%\%FOLDER%"
echo        OK - created: %AID_PROJDIR%

echo        Adding the aiDAPTIV llm block to agents\*.jsonc (Step 4), pinning CrewAI in
echo        pyproject.toml and checking crew.jsonc...
set "AID_MODE=apply"
call :runps
if not errorlevel 1 goto :applied
echo.
echo  [ERROR] Could not configure the aiDAPTIV endpoint.
echo          Edit agents\*.jsonc by hand using Part 2 of the manual.
goto :fail
:applied

echo.
echo  ============================================================
echo    DONE - your aiDAPTIV crew project folder is ready
echo  ============================================================
echo    Folder : %AID_PROJDIR%
echo.
echo    Nothing was installed or run inside the project.
echo    When you are ready, run these yourself (from the manual):
echo.
echo        cd "%AID_PROJDIR%"
echo        crewai install
echo        crewai run
echo.
echo    "memory": false is set in crew.jsonc (as the manual requires).
echo    pyproject.toml is pinned to crewai[tools]==%CREWAI_VER%, so
echo    crewai install uses the same CrewAI version as this manual.
echo    After a run, look for your offload_folder_name under the
echo    aiDAPTIV NVMe cache root (Part 4 of the manual).
echo.
call :cleanup
pause
endlocal
exit /b 0

:fail
call :cleanup
echo.
pause
endlocal
exit /b 1

:cleanup
del "%AID_ANS%" "%AID_CFG%" "%AID_NAMEF%" >nul 2>&1
exit /b 0

:pickfolder
if defined FOLDER exit /b 0
if exist "%~1\crew.jsonc" set "FOLDER=%~1"
exit /b 0

:runps
powershell -NoProfile -ExecutionPolicy Bypass -Command "$m='#PS'+'_BEGIN'; $t=[IO.File]::ReadAllText($env:BATFILE); iex $t.Substring($t.LastIndexOf($m)+$m.Length)"
exit /b %errorlevel%

#PS_BEGIN
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Fail($m) { Write-Host ("        [ERROR] " + $m); exit 1 }
function Ask($label, $default) {
    $v = Read-Host ("        " + $label + " [" + $default + "]")
    if ([string]::IsNullOrWhiteSpace($v)) { return $default }
    return $v.Trim()
}
function Q($s) { return ($s | ConvertTo-Json -Compress) }
function Strip-Comments($text) {
    return (($text -split "`r?`n") | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
}
function Get-ServedModels($baseUrl) {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 6 -Uri ($baseUrl.TrimEnd('/') + '/models')
    return @(($r.Content | ConvertFrom-Json).data | ForEach-Object { $_.id })
}

# ------------------------------------------------------------- where
if ($env:AID_MODE -eq 'where') {
    $here = (Get-Location).Path.TrimEnd('\') + '\'
    $win  = $env:WINDIR.TrimEnd('\') + '\'
    if ($here.StartsWith($win, [StringComparison]::OrdinalIgnoreCase)) {
        Write-Host ('        [ERROR] This window is in ' + (Get-Location).Path + ', inside the Windows folder.')
        Write-Host '                That happens when the file is started with "Run as administrator".'
        Write-Host '                Run it normally (double-click), or from a terminal opened in the'
        Write-Host '                folder where the project should be created.'
        exit 1
    }
    exit 0
}

# ---------------------------------------------------------------- ask
if ($env:AID_MODE -eq 'ask') {
    Write-Host ''
    Write-Host '        -- Project --'
    while ($true) {
        $name = Ask 'Project name' 'aiDAPTIV'
        if ($name -notmatch '^[A-Za-z][A-Za-z0-9_]*$') {
            Write-Host '        Use only letters, digits and underscore, starting with a letter.'
            continue
        }
        if (Test-Path -LiteralPath (Join-Path (Get-Location).Path $name)) {
            Write-Host ('        A folder named "' + $name + '" already exists here. Choose another name.')
            continue
        }
        break
    }
    Write-Host ''
    Write-Host '        -- Agent (Step 2.1 of the manual) --'
    Write-Host '        Tip: use {placeholder} for values you want to change at run time.'
    $role  = Ask 'Role' 'researcher'
    $goal  = Ask 'Goal' 'Find comprehensive information about a given topic'
    $back  = Ask 'Backstory' 'You find the most relevant information and present it clearly.'
    Write-Host ''
    Write-Host '        -- Task (Step 2.6 of the manual) --'
    $tdesc = Ask 'Task description' 'explainer'
    $tout  = Ask 'Expected output' 'explain in simple terms'
    Write-Host ''
    Write-Host '        -- aiDAPTIV server (Part 2 of the manual) --'
    $url = Ask 'Server base_url' 'http://localhost:8080/v1'
    # Offer the name the server really reports (llama-server without --alias
    # reports the .gguf file name, not "gemma-4").
    $served = @()
    # @() keeps a one-model answer as a list (PowerShell unrolls it to a string)
    try { $served = @(Get-ServedModels $url) } catch { }
    if ($served.Count -gt 0) {
        Write-Host ('        Server is up. Models served: ' + ($served -join ', '))
        $defModel = $served[0]
    } else {
        Write-Host '        Server is not reachable right now - type the model name it will serve.'
        $defModel = 'gemma-4'
    }
    while ($true) {
        $model = Ask 'Model name exactly as the server serves it' $defModel
        if ($served.Count -eq 0 -or $served -contains $model) { break }
        Write-Host ('        "' + $model + '" is not served. Served: ' + ($served -join ', '))
        if ((Ask 'Use it anyway? (y/n)' 'n') -match '^[Yy]') { break }
    }
    $folder = Ask 'offload_folder_name (KV-cache subfolder)' 'crewai_benchmark'

    # Answers for the crewai wizard, in order:
    # role, goal, backstory, tools (empty = No tools), planning=n, delegation=n,
    # add another agent=n, task description, expected output, add another task=n, memory=n
    $lines = @($role, $goal, $back, '', 'n', 'n', 'n', $tdesc, $tout, 'n', 'n')
    [IO.File]::WriteAllText($env:AID_ANS, (($lines -join "`n") + "`n"), $utf8)
    $cfg = [ordered]@{ model = $model; base_url = $url; offload_folder_name = $folder }
    [IO.File]::WriteAllText($env:AID_CFG, ($cfg | ConvertTo-Json), $utf8)
    [IO.File]::WriteAllText($env:AID_NAMEF, ($name + "`r`n"), $utf8)
    exit 0
}

# ------------------------------------------------------------- check
if ($env:AID_MODE -eq 'check') {
    $cfg = [IO.File]::ReadAllText($env:AID_CFG) | ConvertFrom-Json
    Write-Host ('        Checking ' + $cfg.base_url.TrimEnd('/') + '/models')
    try {
        $ids = @(Get-ServedModels $cfg.base_url)
        if ($ids -contains $cfg.model) {
            Write-Host ('        OK - server is reachable and serves "' + $cfg.model + '"')
        } else {
            Write-Host ('        [WARN] Server answered, but model "' + $cfg.model + '" is not in /v1/models.')
            Write-Host ('               Models served: ' + ($ids -join ', '))
            Write-Host '               If the crew fails with "Model not found", change "model" in'
            Write-Host '               agents\*.jsonc to the exact name above.'
        }
    } catch {
        Write-Host '        [WARN] The server did not answer. Start the aiDAPTIV middleware / llama.cpp'
        Write-Host '               server before the crew runs. The project will still be created.'
    }
    exit 0
}

# ------------------------------------------------------------- apply
if ($env:AID_MODE -eq 'apply') {
    $cfg = [IO.File]::ReadAllText($env:AID_CFG) | ConvertFrom-Json
    $proj = $env:AID_PROJDIR
    $agentsDir = Join-Path $proj 'agents'
    $files = @(Get-ChildItem -LiteralPath $agentsDir -Filter '*.jsonc')
    if ($files.Count -eq 0) { Fail 'no agent files found in the agents folder' }

    $block = @"
  "llm": {
    "model": $(Q $cfg.model),
    "provider": "openai",
    "base_url": $(Q $cfg.base_url),
    "api_key": "not-needed",
    "extra_body": {
      "cache_prompt": true,
      "offload_folder_name": $(Q $cfg.offload_folder_name)
    }
  },
"@
    $pattern = '(?m)^[ \t]*"llm"[ \t]*:[ \t]*"[^"]*",[ \t]*(?=\r?$)'

    foreach ($f in $files) {
        $t = [IO.File]::ReadAllText($f.FullName)
        $blk = ($block -replace "`r?`n", "`n")
        if ($t.Contains("`r`n")) { $blk = ($blk -replace "`n", "`r`n") }
        $blk = $blk.Replace('$', '$$')
        if (-not [regex]::IsMatch($t, $pattern)) { Fail ('no default llm line found in agents\' + $f.Name) }
        $t = [regex]::Replace($t, $pattern, $blk)
        [IO.File]::WriteAllText($f.FullName, $t, $utf8)

        $o = (Strip-Comments $t) | ConvertFrom-Json
        if ($o.llm.base_url -ne $cfg.base_url -or $o.llm.model -ne $cfg.model -or
            $o.llm.provider -ne 'openai' -or $o.llm.extra_body.cache_prompt -ne $true -or
            $o.llm.extra_body.offload_folder_name -ne $cfg.offload_folder_name) {
            Fail ('llm block check failed for agents\' + $f.Name)
        }
        Write-Host ('        OK - llm block set in agents\' + $f.Name)
    }

    # pyproject.toml: the wizard writes crewai[tools]>=X,<2.0.0, so crewai install
    # would pull the newest 1.x. Pin it to the version this manual was tested with.
    $pp = Join-Path $proj 'pyproject.toml'
    $p = [IO.File]::ReadAllText($pp)
    $depPat = '"crewai\[tools\][^"]*"'
    if (-not [regex]::IsMatch($p, $depPat)) { Fail 'crewai[tools] dependency not found in pyproject.toml' }
    $p = [regex]::Replace($p, $depPat, ('"crewai[tools]==' + $env:CREWAI_VER + '"'))
    [IO.File]::WriteAllText($pp, $p, $utf8)
    Write-Host ('        OK - pyproject.toml pinned to crewai[tools]==' + $env:CREWAI_VER)

    # crew.jsonc: memory must stay false (embeddings would call OpenAI, not aiDAPTIV)
    $cp = Join-Path $proj 'crew.jsonc'
    $c = [IO.File]::ReadAllText($cp)
    $memTrue = '(?m)^([ \t]*"memory"[ \t]*:[ \t]*)true'
    if ([regex]::IsMatch($c, $memTrue)) {
        $c = [regex]::Replace($c, $memTrue, '${1}false')
        [IO.File]::WriteAllText($cp, $c, $utf8)
        Write-Host '        Fixed: "memory" set to false in crew.jsonc'
    }
    $co = (Strip-Comments $c) | ConvertFrom-Json
    if ($co.memory -ne $false) { Fail 'crew.jsonc does not contain "memory": false' }
    if (@($co.agents).Count -lt 1 -or @($co.tasks).Count -lt 1) { Fail 'crew.jsonc has no agents or no tasks' }
    Write-Host ('        OK - crew.jsonc: memory=false, agents=' + @($co.agents).Count + ', tasks=' + @($co.tasks).Count)
    Write-Host ('        KV-cache folder to look for later: ' + $cfg.offload_folder_name)
    exit 0
}
Fail 'unknown AID_MODE'
