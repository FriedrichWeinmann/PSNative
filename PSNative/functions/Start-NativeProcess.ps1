function Start-NativeProcess {
	<#
	.SYNOPSIS
		Create a native process that allows for ongoing interaction.
	
	.DESCRIPTION
		Create a native process that allows for ongoing interaction.
		This can be use to wrap interactive console applications, then repeatedly send commands and receive output.

		The returned object has a few relevant methods:
		+ Stop(): Kill the process.
		+ Start(): Start the process again.
		+ Send([string]): Send a line of command to the process
		+ ReadOutput(): Read the lines of output from the proceess
		+ ReadError(): Read the lines of errors from the process

		The two read commands will retrieve all the data written so far (and then discard them from the object,
		so calling them a second time without new output will not return anything).
		There is no indication whether the wrapped process is done doing what it is intending to do,
		making it necessary to understand the expected output.

		Sending multiple lines of input will queue up commands, which will be processed sequentially.
	
	.PARAMETER Name
		Name of the application to start.
		Can be the full path or the simple name, if the application is in the PATH environment variable.
	
	.PARAMETER ArgumentList
		Arguments to send to the application.
		These basically are the parameters needed BEFORE running the command.
		Use the .Send([string]) method to send commands to the process after starting it.
	
	.PARAMETER WorkingDirectory
		Path to run the program in.
		Defaults to the current file system path.
	
	.PARAMETER Credential
		Credentials under which to run the process.
	
	.PARAMETER Environment
		Any environment variables to inject into the process being started.

	.PARAMETER NoStart
		Do not automatically start th process after preparing the starting information.
		By default, the wrapped process is launched immediately instead.
		
	.EXAMPLE
		PS C:\ $cmd = Start-NativeProcess -Name cmd
		PS C:\> $cmd.Send('dir C:\')
		PS C:\> $cmd.ReadOutput()
		
		Starts a persistent cmd process, then sends the dir command to it and reads the response.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,

		[string[]]
		$ArgumentList = @(),

		[string]
		$WorkingDirectory = (Get-Location -PSProvider FileSystem).ProviderPath,

		[PSCredential]
		$Credential,

		[hashtable]
		$Environment = @{ },

		[switch]
		$NoStart
	)

	$process = [NativeProcess]::New($Name, $ArgumentList)
	if ($WorkingDirectory) {
		$resolved = Resolve-PathEx -Path $WorkingDirectory -SingleItem -Type Directory
		if (-not $resolved.Success) {
			throw ($resolved.Message -join "`n")
		}
		$process.WorkingDirectory = $resolved.Path
	}
	if ($Credential) {
		$process.Credential = $Credential
	}
	$process.EnvironmentVariables = $Environment
	if (-not $NoStart) { $process.Start() }
	$process
}