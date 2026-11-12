# run *.sh as powershell in this session instead of letting windows open git-bash


<#
$ExecutionContext.InvokeCommand.PreCommandLookupAction = {
	param($name, $e)
	if ($name -notlike '*.sh' -or -not (Test-Path -LiteralPath $name -PathType Leaf)) { return }
	$path = (Resolve-Path -LiteralPath $name).Path
	$e.CommandScriptBlock = {
		& ([scriptblock]::Create((Get-Content -Raw -LiteralPath $path))) @args
	}.GetNewClosure()
	$e.StopSearch = $true
} #>
