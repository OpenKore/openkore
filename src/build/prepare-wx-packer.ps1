$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$directory = Join-Path $temp ('openkore-wx-packer-' + [Guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $directory) { throw 'Temporary directory already exists' }
$null = New-Item -ItemType Directory -Path $directory
try {
    & perl -MConfig -e 'exit($Config{ptrsize} == 4 ? 0 : 1)'
    if ($LASTEXITCODE -ne 0) { throw '32-bit Perl is required' }
    $version = & perl -MPAR::Packer -e 'print $PAR::Packer::VERSION'
    if ($LASTEXITCODE -ne 0 -or $version -ne '1.064') { throw 'PAR::Packer 1.064 is required' }
    $archive = Join-Path $directory 'PAR-Packer-1.064.tar.gz'
    if ($env:OPENKORE_PAR_PACKER_ARCHIVE) {
        Copy-Item -LiteralPath $env:OPENKORE_PAR_PACKER_ARCHIVE -Destination $archive
    } else {
        Invoke-WebRequest -Uri 'https://cpan.metacpan.org/authors/id/R/RS/RSCHUPP/PAR-Packer-1.064.tar.gz' -OutFile $archive -UseBasicParsing
    }
    $stream = [IO.File]::OpenRead($archive)
    try { $hash = ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($stream))).Replace('-', '') } finally { $stream.Dispose() }
    if ($hash -ne '0FC063E448E34F7CB5C69C6BE5B2258F7150187B33140DEDABD53A2C34CA3CBA') { throw 'Unexpected PAR::Packer archive hash' }
    & tar.exe -xzf $archive -C $directory
    if ($LASTEXITCODE -ne 0) { throw 'Cannot extract PAR::Packer source' }
    $source = Join-Path $directory 'PAR-Packer-1.064'
    $boot = Join-Path $source 'myldr\boot.c'
    $text = [IO.File]::ReadAllText($boot)
    $old = '    rc = _wspawnvp(P_WAIT, w_my_perl, (const wchar_t* const*)w_argv);'
    $replacement = @'
    {
        if (!par_getenv("wx_msw_dark_mode"))
            par_setenv("wx_msw_dark_mode", "1");
        intptr_t child = _wspawnvp(P_NOWAIT, w_my_perl, (const wchar_t* const*)w_argv);
        rc = -1;
        if (child != -1) {
            DWORD child_pid = GetProcessId((HANDLE) child);
            DWORD initial[64], *clients = initial, capacity = 64;
            BOOL observed = FALSE;
            while (child_pid && WaitForSingleObject((HANDLE) child, 25) == WAIT_TIMEOUT) {
                DWORD count = GetConsoleProcessList(clients, capacity), i;
                BOOL attached = FALSE;
                if (!count) break;
                if (count > capacity) {
                    DWORD *larger = (DWORD *)malloc(count * sizeof(DWORD));
                    if (!larger) break;
                    if (clients != initial) free(clients);
                    clients = larger;
                    capacity = count;
                    continue;
                }
                for (i = 0; i < count; ++i)
                    if (clients[i] == child_pid) attached = TRUE;
                if (attached) observed = TRUE;
                else if (observed) {
                    FreeConsole();
                    break;
                }
            }
            if (clients != initial) free(clients);
            if (WaitForSingleObject((HANDLE) child, INFINITE) == WAIT_OBJECT_0) {
                DWORD code;
                if (GetExitCodeProcess((HANDLE) child, &code)) rc = (int) code;
            }
            CloseHandle((HANDLE) child);
        }
    }
'@
    if ($text.Split(@($old), [StringSplitOptions]::None).Count -ne 2) { throw 'Unexpected PAR::Packer source' }
    [IO.File]::WriteAllText($boot, $text.Replace($old, $replacement), [Text.Encoding]::ASCII)
    Push-Location $source
    try {
        & perl Makefile.PL
        if ($LASTEXITCODE -ne 0) { throw 'PAR::Packer configuration failed' }
        & gmake
        if ($LASTEXITCODE -ne 0) { throw 'PAR::Packer build failed' }
    } finally { Pop-Location }
    $overlay = Join-Path $directory 'overlay'
    $static = Join-Path $overlay 'PAR\StrippedPARL'
    New-Item -ItemType Directory -Path $static -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $source 'myldr\Static.pm') -Destination $static
    $env:PERL5LIB = "$overlay;$env:PERL5LIB"
    $env:OPENKORE_WX_LOADER_READY = '1'
    Push-Location $repo
    try {
        & cmd.exe /d /c (Join-Path $repo 'src\build\compile-wx.bat')
        if ($LASTEXITCODE -ne 0) { throw 'wxstart build failed' }
    } finally { Pop-Location }
} finally {
    $target = [IO.Path]::GetFullPath($directory)
    if (-not $target.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or $target -eq $temp) { throw 'Invalid temporary directory' }
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
}
