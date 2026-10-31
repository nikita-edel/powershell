$global:obsb = "C:\Program Files\obs-studio\bin\64bit\obs64.exe"

function obs {
	Push-Location "C:\Program Files\obs-studio\bin\64bit"
	& $obsb @args
	Pop-Location
}

function start_obs {
	obs --startreplaybuffer --minimize-to-tray
}
