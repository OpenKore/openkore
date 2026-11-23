param(
	[Parameter(Mandatory = $true)]
	[string[]] $Executables,
	[string[]] $GuiExecutables = @(),
	[int] $TimeoutSeconds = 45
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$dllPath = Join-Path $repoRoot 'XSTools.dll'
if (-not (Test-Path -LiteralPath $dllPath -PathType Leaf)) {
	throw "Distributed XSTools.dll is missing: $dllPath"
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("openkore-launcher-smoke-" + [guid]::NewGuid().ToString('N'))
$runtimeDir = Join-Path $testRoot 'runtime'
New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
$hiddenDllPath = Join-Path $testRoot 'XSTools.dll.original'
$dllHidden = $false

try {
	# Run the checked-in PerlApp launchers with the checked-in DLL that ships beside
	# them. Hide the checkout copy while testing so the process cannot accidentally
	# load a different DLL from its current working directory.
	Copy-Item -LiteralPath $dllPath -Destination (Join-Path $runtimeDir 'XSTools.dll')
	$netRedirect = Join-Path $repoRoot 'NetRedirect.dll'
	if (Test-Path -LiteralPath $netRedirect -PathType Leaf) {
		Copy-Item -LiteralPath $netRedirect -Destination (Join-Path $runtimeDir 'NetRedirect.dll')
	}
	Move-Item -LiteralPath $dllPath -Destination $hiddenDllPath
	$dllHidden = $true

	foreach ($name in $Executables) {
		$source = Join-Path $repoRoot $name
		if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
			throw "Distributed launcher is missing: $source"
		}
		$exe = Join-Path $runtimeDir $name
		Copy-Item -LiteralPath $source -Destination $exe
		$isGui = $GuiExecutables -contains $name
		$processInfo = New-Object System.Diagnostics.ProcessStartInfo
		$processInfo.FileName = $exe
		$processInfo.Arguments = '--version'
		$processInfo.WorkingDirectory = $repoRoot
		$processInfo.UseShellExecute = $false
		$processInfo.CreateNoWindow = $true
		$processInfo.RedirectStandardOutput = $true
		$processInfo.RedirectStandardError = $true
		$process = New-Object System.Diagnostics.Process
		$process.StartInfo = $processInfo
		Write-Host "Testing $name with the distributed XSTools.dll"
		try {
			if (-not $process.Start()) { throw "Windows did not start $name" }
			$stdoutTask = $process.StandardOutput.ReadToEndAsync()
			$stderrTask = $process.StandardError.ReadToEndAsync()
			if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
				Write-Host "$name exceeded ${TimeoutSeconds}s; terminating its process tree."
				& taskkill.exe /PID $process.Id /T /F 2>&1 | ForEach-Object { Write-Host $_ }
				if (-not $process.WaitForExit(5000)) {
					$process.Kill()
					if (-not $process.WaitForExit(5000)) {
						throw "$name could not be terminated after timeout"
					}
				}
				throw "$name did not exit within $TimeoutSeconds seconds"
			}
			$process.WaitForExit()
			$stdoutText = $stdoutTask.GetAwaiter().GetResult()
			$stderrText = $stderrTask.GetAwaiter().GetResult()
			$combined = $stdoutText + $stderrText
			Write-Host "stdout:`n$stdoutText"
			Write-Host "stderr:`n$stderrText"
			Write-Host "exit code: $($process.ExitCode)"
			if ($combined -match '(?i)XSTools::(?:Load|Compile)Exception|Cannot load the XSTools library|XSTools\.dll is not found|Can.t locate .*? in \@INC|Can.t locate loadable object for module XSTools|Undefined subroutine|Compilation failed|BEGIN failed|Died at|Perl.*(?:panic|exception)') {
				throw "$name reported a Perl/XSTools initialization failure"
			}
			if ($process.ExitCode -ne 0) {
				throw "$name exited abnormally with exit code $($process.ExitCode)"
			}
			if (-not $isGui -and $combined -notmatch '(?im)^\*\*\*\s+OpenKore\s+.+\*\*\*') {
				throw "$name exited successfully but did not print the expected OpenKore version banner"
			}
			if ($isGui) {
				Write-Host "$name is a GUI-subsystem executable; Windows exposes no redirected console output. Verified bounded startup, clean exit, and any diagnostics exposed by the process."
			} else {
				Write-Host "$name printed the OpenKore version banner and exited successfully."
			}
		} finally {
			$process.Dispose()
		}
	}
} finally {
	if ($dllHidden -and (Test-Path -LiteralPath $hiddenDllPath -PathType Leaf)) {
		Move-Item -LiteralPath $hiddenDllPath -Destination $dllPath -Force
	}
	if (Test-Path -LiteralPath $testRoot) {
		Remove-Item -LiteralPath $testRoot -Recurse -Force
	}
}
