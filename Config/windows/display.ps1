
function Get-DisplaySize {
    param([int]$DisplayId)

    $m = (Get-DisplayConfig).ModeArray |
         Where-Object { $_.infoType -eq 'DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE' -and $_.id -eq $DisplayId } |
         Select-Object -First 1
    $m.modeInfo.sourceMode | Select-Object width, height
}

function res {
    param([int]$X, [int]$Y)
    Set-DisplayResolution -DisplayId 1 -Width $X -Height $Y
}

function tgres {
	$size = Get-DisplaySize 0
	if ($size.width -eq 2560) {
		res 2160 1440
	} else {
		res 2560 1440
	}
}
