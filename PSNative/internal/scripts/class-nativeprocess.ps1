class NativeProcess {
	[string]$Name
	[object[]]$ArgumentList
	[string]$WorkingDirectory
	[hashtable]$EnvironmentVariables = @{ }
	[datetime]$Started
	[datetime]$Stopped
	[PSCredential]$Credential

	[System.Diagnostics.Process]$Process

	hidden [object] $OutputTask
	hidden [object] $ErrorTask

	NativeProcess([string]$Name) {
		$this.Name = $Name
	}

	NativeProcess([string]$Name, [object[]]$ArgumentList) {
		$this.Name = $Name
		$this.ArgumentList = $ArgumentList
	}

	[void] Start() {
		if ($this.Process -and -not $this.Process.HasExited) {
			$this.Stop()
		}

		$this.OutputTask = $null
		$this.ErrorTask = $null

		#region Process
		$info = [System.Diagnostics.ProcessStartInfo]::new()
		$info.FileName = $this.Name
		if ($this.WorkingDirectory) { $info.WorkingDirectory = $this.WorkingDirectory }
		foreach ($entry in $this.ArgumentList) { $info.ArgumentList.Add($entry) }
	
		if ($global:PSVersionTable.PSVersion.Major -lt 6) { $info.UseShellExecute = $false }
		$info.RedirectStandardInput = $true
		$info.RedirectStandardError = $true
		$info.RedirectStandardOutput = $true

		if ($this.Credential) {
			$info.Password = $this.Credential.Password
			$networkCred = $this.Credential.GetNetworkCredential()
			$domain = $networkCred.Domain
			$user = $networkCred.UserName
			if (-not $domain -and $networkCred.UserName -like '*@*') {
				$domain = ($networkCred.UserName -split '@')[-1]
				$user = ($networkCred.UserName -split '@')[0]
			}
			$info.UserName = $user
			$info.Domain = $domain
		}
		foreach ($pair in $this.EnvironmentVariables.GetEnumerator()) {
			$info.EnvironmentVariables[$pair.Key] = $pair.Value
		}
	
		$proc = [System.Diagnostics.Process]::new()
		$proc.StartInfo = $info
	
		# Start
		$null = $proc.Start()

		$this.Process = $proc
		#endregion Process

		$this.Started = Get-Date
	}

	[void] Stop() {
		$this.Process.Kill()
		$this.Process = $null
		$this.OutputTask = $null
		$this.ErrorTask = $null

		$this.Stopped = Get-Date
	}

	[string[]] ReadOutput() {
		if (-not $this.Process) {return @() }
		
		$lastStart = [DateTime]::Now
		$lines = while ($true) {
			if ($this.OutputTask -and $this.OutputTask.Status -eq 'WaitingForActivation') {
				if ($lastStart -gt [DateTime]::Now.AddMilliseconds(-100)) {
					continue
				}
				break
			}

			if ($this.OutputTask) {
				$this.OutputTask.Result
			}
			$this.OutputTask = $this.Process.StandardOutput.ReadLineAsync()
			$lastStart = [DateTime]::Now

			if ($this.Process.HasExited) {
				if ($this.OutputTask) {
					$this.OutputTask.Result
				}
				$this.Process.StandardOutput.ReadToEnd() -split "`n"
			}
		}
		if (-not $lines) {
			return @()
		}

		return $lines
	}

	[string[]] ReadError() {
		if (-not $this.Process) {return @() }

		$lastStart = [DateTime]::Now
		$lines = while ($true) {
			if ($this.ErrorTask -and $this.ErrorTask.Status -eq 'WaitingForActivation') {
				if ($lastStart -gt [DateTime]::Now.AddMilliseconds(-100)) {
					continue
				}
				break
			}

			if ($this.ErrorTask) {
				$this.ErrorTask.Result
			}
			$this.ErrorTask = $this.Process.StandardError.ReadLineAsync()
			$lastStart = [DateTime]::Now

			if ($this.Process.HasExited) {
				if ($this.ErrorTask) {
					$this.ErrorTask.Result
				}
				$this.Process.StandardOutput.ReadToEnd() -split "`n"
			}
		}
		if (-not $lines) {
			return @()
		}

		return $lines
	}

	[void] Send([string[]]$Lines) {
		if ($null -eq $this.Process) {
			throw "Process not running! Use Start() first."
		}
		if ($this.Process.HasExited) {
			throw "Process has stopped already! Use Start() to restart it first."
		}

		foreach ($line in $Lines) {
			$this.Process.StandardInput.WriteLine($line)
		}
	}
}