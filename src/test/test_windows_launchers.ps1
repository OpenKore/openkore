param(
	[Parameter(Mandatory = $true)]
	[string[]] $Executables,
	[string[]] $GuiExecutables = @(),
	[int] $TimeoutSeconds = 45
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$dllPath = Join-Path $repoRoot 'XSTools.dll'
$netRedirectPath = Join-Path $repoRoot 'NetRedirect.dll'
$failures = [System.Collections.Generic.List[string]]::new()
$results = [System.Collections.Generic.List[object]]::new()
$perlErrorPattern = '(?i)XSTools::(?:Load|Compile)Exception|Cannot load the XSTools library|XSTools\.dll is not found|Can.t locate .*? in \@INC|Can.t locate loadable object for module XSTools|Undefined subroutine|Compilation failed|BEGIN failed|Died at|Perl.*(?:panic|exception)|unable to load.*(?:dll|module)|(?:dll|module).*not found'

foreach ($name in $Executables) {
	$exe = Join-Path $repoRoot $name
	$isGui = $GuiExecutables -contains $name
	$started = $false
	$exitCode = $null
	$timedOut = $false
	$result = 'FAIL'
	$failureReason = ''
	$stdoutText = ''
	$stderrText = ''
	$process = $null

	Write-Host "`nTesting $name from the distribution root: $exe"
	if (-not (Test-Path -LiteralPath $dllPath -PathType Leaf)) {
		$failureReason = "Distributed XSTools.dll is missing: $dllPath"
	} elseif (-not (Test-Path -LiteralPath $netRedirectPath -PathType Leaf)) {
		$failureReason = "Distributed NetRedirect.dll is missing: $netRedirectPath"
	} elseif (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
		$failureReason = "Distributed launcher is missing: $exe"
	} else {
		try {
			$processInfo = [System.Diagnostics.ProcessStartInfo]::new()
			$processInfo.FileName = $exe
			$processInfo.Arguments = '--version'
			$processInfo.WorkingDirectory = $repoRoot
			$processInfo.UseShellExecute = $false
			$processInfo.CreateNoWindow = $true
			$processInfo.RedirectStandardInput = $true
			$processInfo.RedirectStandardOutput = $true
			$processInfo.RedirectStandardError = $true
			$process = [System.Diagnostics.Process]::new()
			$process.StartInfo = $processInfo
			if (-not $process.Start()) {
				throw "Windows did not start $name"
			}
			$started = $true
			$stdoutTask = $process.StandardOutput.ReadToEndAsync()
			$stderrTask = $process.StandardError.ReadToEndAsync()
			$process.StandardInput.Close()
			if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
				$timedOut = $true
				$failureReason = "Process did not exit within $TimeoutSeconds seconds"
				Write-Host "$name timed out; terminating its process tree."
				& taskkill.exe /PID $process.Id /T /F 2>&1 | ForEach-Object { Write-Host $_ }
				if (-not $process.WaitForExit(5000)) {
					try {
						$process.Kill($true)
					} catch {
						Write-Warning "Process-tree termination failed for $name; trying direct termination: $($_.Exception.Message)"
						try { $process.Kill() } catch { Write-Warning "Direct termination failed for $name`: $($_.Exception.Message)" }
					}
					[void] $process.WaitForExit(5000)
				}
			}
			if ($process.HasExited) {
				$exitCode = $process.ExitCode
			}
		if ($stdoutTask.Wait(5000)) {
			try { $stdoutText = $stdoutTask.GetAwaiter().GetResult() } catch { $stdoutText = "<stdout capture failed: $($_.Exception.Message)>" }
		} else {
			$stdoutText = '<stdout capture did not close within 5 seconds>'
		}
		if ($stderrTask.Wait(5000)) {
			try { $stderrText = $stderrTask.GetAwaiter().GetResult() } catch { $stderrText = "<stderr capture failed: $($_.Exception.Message)>" }
		} else {
			$stderrText = '<stderr capture did not close within 5 seconds>'
		}

			$combined = $stdoutText + "`n" + $stderrText
			if (-not $failureReason -and $combined -match $perlErrorPattern) {
				$failureReason = 'Perl/XSTools or native DLL initialization error was reported'
			} elseif (-not $failureReason -and $exitCode -ne 0) {
				$failureReason = "Process exited with code $exitCode"
			} elseif (-not $failureReason -and -not $isGui -and $combined -notmatch '(?im)^\*\*\*\s+OpenKore\s+.+\*\*\*') {
				$failureReason = 'Successful exit did not include the expected OpenKore version banner'
			} elseif (-not $failureReason) {
				$result = 'PASS'
			}
		} catch {
			$failureReason = $_.Exception.Message
		} finally {
			if ($process) {
				if (-not $process.HasExited) {
					try {
						$process.Kill($true)
					} catch {
						Write-Warning "Process-tree cleanup failed for $name; trying direct termination: $($_.Exception.Message)"
						try { $process.Kill() } catch { Write-Warning "Direct cleanup failed for $name`: $($_.Exception.Message)" }
					}
					if (-not $process.WaitForExit(5000)) {
						Write-Warning "Could not confirm $name exited after termination was requested."
					}
				}
				$process.Dispose()
			}
		}
	}

	if ($failureReason) {
		$failures.Add("$name`: $failureReason")
	}
	Write-Host "Started: $started; Exit code: $exitCode; Timeout: $timedOut; Result: $result"
	Write-Host "stdout:`n$stdoutText"
	Write-Host "stderr:`n$stderrText"
	if ($isGui) {
		Write-Host "$name uses the Windows GUI subsystem. Its startup assertion is a bounded --version exit with code 0 and no Perl/DLL error; redirected output may be unavailable for GUI applications."
	}
	$results.Add([pscustomobject]@{
		Executable = $name
		Started = $started
		ExitCode = if ($null -eq $exitCode) { '—' } else { $exitCode }
		Timeout = $timedOut
		Result = $result
		FailureReason = if ($failureReason) { $failureReason } else { '—' }
	})
}

$summary = $results | Format-Table -AutoSize | Out-String
Write-Host "`nLauncher smoke summary:`n$summary"
if ($env:GITHUB_STEP_SUMMARY) {
	$markdown = @(
		'### Windows PerlApp launcher smoke tests'
		''
		'Launchers run from the repository distribution root with the checked-in `XSTools.dll` and `NetRedirect.dll`. GUI launchers are validated by their bounded `--version` exit and exposed diagnostics; redirected console output is not guaranteed for GUI-subsystem executables.'
		''
		'| Executable | Started | Exit code | Timeout | Result | Failure reason |'
		'| --- | --- | ---: | --- | --- | --- |'
	)
	foreach ($row in $results) {
		$reason = ([string]$row.FailureReason) -replace '\|', '\|' -replace "`r?`n", ' '
		$markdown += "| $($row.Executable) | $($row.Started) | $($row.ExitCode) | $($row.Timeout) | $($row.Result) | $reason |"
	}
	$markdown | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY
}

if ($failures.Count -gt 0) {
	Write-Error ("Launcher smoke tests failed: " + ($failures -join '; '))
	exit 1
}
