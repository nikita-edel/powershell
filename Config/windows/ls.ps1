# name colors for ls; hidden is applied on top of the type color
$global:LsColors = @{
	Dir     = "`e[1;34m"   # bold blue
	Link    = "`e[1;36m"   # bold cyan
	File    = ''           # default
	Hidden  = "`e[2m"      # dim
}

# ls: names + human-readable sizes in columns, no header; args pass through to Get-ChildItem
function ls {
	$entries = @(foreach ($i in Get-ChildItem @args) {
		$name = $i.Name
		if ($i.LinkType) {
			$size = '-'; $color = $LsColors.Link
		} elseif ($i.PSIsContainer) {
			$size = '-'; $color = $LsColors.Dir; $name += '/'
		} else {
			$n = [double]$i.Length; $u = 0
			while ($n -ge 1024 -and $u -lt 4) { $n /= 1024; $u++ }
			$size = if ($u -eq 0) { "$n" } else { "{0:0.#}{1}" -f $n, 'BKMGT'[$u] }
			$color = $LsColors.File
		}
		if ($i.Attributes -band [IO.FileAttributes]::Hidden -or $i.Name.StartsWith('.')) { $color = $LsColors.Hidden + $color }
		# Len = visible width, excluding ANSI color codes
		[pscustomobject]@{ Text = "{0,6}  {1}{2}`e[0m" -f $size, $color, $name; Len = 8 + $name.Length }
	})
	if (-not $entries) { return }

	# piped into something else → one per line, like GNU ls
	if ($MyInvocation.PipelinePosition -lt $MyInvocation.PipelineLength) { return $entries.Text }

	$width = try { $Host.UI.RawUI.WindowWidth } catch { 0 }
	if (-not $width) { $width = 80 }
	$gap = 3
	$count = $entries.Count
	$lens = $entries.Len

	# fewest rows whose per-column widths fit the window, like GNU ls
	$rows = $count; $colW = @(($lens | Measure-Object -Maximum).Maximum)
	$minLen = ($lens | Measure-Object -Minimum).Minimum
	$maxCols = [math]::Min($count, [math]::Floor(($width + $gap) / ($minLen + $gap)))
	for ($cols = $maxCols; $cols -gt 1; $cols--) {
		$r = [math]::Ceiling($count / $cols)
		$w = for ($c = 0; $c * $r -lt $count; $c++) {
			($lens[($c * $r)..([math]::Min($count, ($c + 1) * $r) - 1)] | Measure-Object -Maximum).Maximum
		}
		if (($w | Measure-Object -Sum).Sum + $gap * (@($w).Count - 1) -le $width) { $rows = $r; $colW = @($w); break }
	}

	# fill column-major (down, then across)
	for ($r = 0; $r -lt $rows; $r++) {
		$line = ''
		for ($c = 0; $c -lt $colW.Count; $c++) {
			$idx = $c * $rows + $r
			if ($idx -ge $count) { break }
			$e = $entries[$idx]
			$line += $e.Text + ' ' * ($colW[$c] - $e.Len + $gap)
		}
		$line.TrimEnd()
	}
}
