function Invoke-NativeCommand {
	<#
	.SYNOPSIS
		Execute an external application and wait for it to conclude.
	
	.DESCRIPTION
		Execute an external application and wait for it to conclude.
		Provides convenient parameterization options and output processing.
	
	.PARAMETER Name
		Name of or path to the process to run.
	
	.PARAMETER ArgumentList
		Parameters to provide to the process launched.
	
	.PARAMETER WorkingDirectory
		Directory from which to launch the process.
		Defaults to the current filesystem path.
	
	.PARAMETER Timeout
		How long to wait for the process to complete.
		Defaults to 15 minutes.
	
	.PARAMETER Credential
		Credentials to use when launching the process.
	
	.PARAMETER Environment
		Environment variables to add to the launched process
	
	.EXAMPLE
		PS C:\> Invoke-NativeCommand -Name nslookup 'wikipedia.org' '1.1.1.1'
		
		Launches nslookup, resolving wikipedia.org against 1.1.1.1.
	#>
	[CmdletBinding(PositionalBinding = $false)]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[Alias('FilePath')]
		[string]
		$Name,

		[Parameter(ValueFromRemainingArguments = $true)]
		[string[]]
		$ArgumentList,

		[string]
		$WorkingDirectory = (Get-Location -PSProvider FileSystem).ProviderPath,

		[Timespan]
		$Timeout = '00:15:00',

		[PSCredential]
		$Credential,

		[hashtable]
		$Environment = @{ }
	)

	begin {
		$info = [System.Diagnostics.ProcessStartInfo]::new()
		$info.FileName = $Name
		if ($WorkingDirectory) {
			$resolved = Resolve-PathEx -Path $WorkingDirectory -SingleItem -Type Directory
			if (-not $resolved.Success) {
				throw ($resolved.Message -join "`n")
			}
			$info.WorkingDirectory = $resolved.Path
		}
		foreach ($entry in $ArgumentList) { $info.ArgumentList.Add($entry) }

		$info.RedirectStandardError = $true
		$info.RedirectStandardOutput = $true

		if ($Credential) {
			$info.Password = $Credential.Password
			$networkCred = $Credential.GetNetworkCredential()
			$domain = $networkCred.Domain
			$user = $networkCred.UserName
			if (-not $domain -and $networkCred.UserName -like '*@*') {
				$domain = ($networkCred.UserName -split '@')[-1]
				$user = ($networkCred.UserName -split '@')[0]
			}
			$info.UserName = $user
			$info.Domain = $domain
		}
		foreach ($pair in $Environment.GetEnumerator()) {
			$info.EnvironmentVariables[$pair.Key] = $pair.Value
		}

		$proc = [System.Diagnostics.Process]::new()
		$proc.StartInfo = $info
		$started = $false
	}
	process {
		if (-not $started) {
			$start = Get-Date
			$null = $proc.Start()
		}
	}
	end {
		$failed = $false

		$limit = $start.Add($Timeout)
		while (-not $proc.HasExited) {
			Start-Sleep -Milliseconds 250
			if ($limit -lt (Get-Date)) {
				$failed = $true
				$proc.Close()
				break
			}
		}

		if ($proc.ExitCode -ne 0) { $failed = $true }

		[PSCustomObject]@{
			File     = $Name
			Success  = -not $failed
			Output   = $(try { $proc.StandardOutput.ReadToEnd() } catch { })
			Error    = $(try { $proc.StandardError.ReadToEnd() } catch { })
			ExitCode = $proc.ExitCode
		}
	}
}