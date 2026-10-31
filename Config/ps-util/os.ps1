$global:config_home = if ($IsWindows) { $env:LOCALAPPDATA } else { Join-Path $HOME .config }
$global:data_home = if ($IsWindows) { $env:LOCALAPPDATA } else { Join-Path $HOME .local share }
