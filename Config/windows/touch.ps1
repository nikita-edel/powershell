# GNU-style touch: touch [-acm] [-d DATE] [-r FILE] [-t STAMP] FILE...
function touch {
	$atime = $true; $mtime = $true; $create = $true
	$time = $null; $files = @(); $onlyFiles = $false

	$parseStamp = {
		param([string]$s)
		# unquoted 1200.30 arrives as a double → "1200.3"; ss is always 2 digits
		if ($s -match '\.\d$') { $s += '0' }
		if ($s -notmatch '^(\d{8}|\d{10}|\d{12})(\.(\d{2}))?$') { throw "touch: invalid date format '$s'" }
		$d = $Matches[1]; $sec = if ($Matches[3]) { [int]$Matches[3] } else { 0 }
		$year = (Get-Date).Year
		switch ($d.Length) {
			12 { $year = [int]$d.Substring(0, 4); $d = $d.Substring(4) }
			10 { $yy = [int]$d.Substring(0, 2); $year = if ($yy -lt 69) { 2000 + $yy } else { 1900 + $yy }; $d = $d.Substring(2) }
		}
		Get-Date -Year $year -Month $d.Substring(0, 2) -Day $d.Substring(2, 2) -Hour $d.Substring(4, 2) -Minute $d.Substring(6, 2) -Second $sec -Millisecond 0
	}
	$parseDate = {
		param([string]$s)
		switch -Regex ($s) {
			'^@(-?\d+)$'   { return [DateTimeOffset]::FromUnixTimeSeconds([long]$Matches[1]).LocalDateTime }
			'^now$'        { return Get-Date }
			'^today$'      { return Get-Date }
			'^yesterday$'  { return (Get-Date).AddDays(-1) }
			'^tomorrow$'   { return (Get-Date).AddDays(1) }
			'^([+-]?\d+) (second|minute|hour|day|week|month|year)s?( ago)?$' {
				$n = [int]$Matches[1]; if ($Matches[3]) { $n = -$n }
				$now = Get-Date
				switch ($Matches[2]) {
					'second' { return $now.AddSeconds($n) }
					'minute' { return $now.AddMinutes($n) }
					'hour'   { return $now.AddHours($n) }
					'day'    { return $now.AddDays($n) }
					'week'   { return $now.AddDays(7 * $n) }
					'month'  { return $now.AddMonths($n) }
					'year'   { return $now.AddYears($n) }
				}
			}
		}
		try { [datetime]::Parse($s) } catch { throw "touch: invalid date format '$s'" }
	}
	$refTime = {
		param([string]$p)
		$ref = Get-Item -LiteralPath $p -Force -ErrorAction Stop
		@{ A = $ref.LastAccessTime; M = $ref.LastWriteTime }
	}

	$onlyA = $false; $onlyM = $false
	$argv = @($args | ForEach-Object { "$_" })
	for ($i = 0; $i -lt $argv.Count; $i++) {
		$a = $argv[$i]
		if ($onlyFiles -or $a -eq '-' -or -not $a.StartsWith('-')) { $files += $a; continue }
		if ($a -eq '--') { $onlyFiles = $true; continue }

		if ($a.StartsWith('--')) {
			$name, $val = $a.Substring(2) -split '=', 2
			if ($name -in 'date', 'reference', 'time' -and $null -eq $val) {
				$i++; if ($i -ge $argv.Count) { throw "touch: option '--$name' requires an argument" }
				$val = $argv[$i]
			}
			switch ($name) {
				'no-create'      { $create = $false }
				'date'           { $time = & $parseDate $val }
				'reference'      { $time = & $refTime $val }
				'time'           {
					if ($val -in 'access', 'atime', 'use') { $onlyA = $true }
					elseif ($val -in 'modify', 'mtime') { $onlyM = $true }
					else { throw "touch: invalid argument '$val' for '--time'" }
				}
				'no-dereference' { }
				'help'           { Write-Output 'Usage: touch [-acm] [-d DATE] [-r FILE] [-t [[CC]YY]MMDDhhmm[.ss]] FILE...'; return }
				default          { throw "touch: unrecognized option '--$name'" }
			}
			continue
		}

		# bundled short flags, e.g. -am, -cd 'yesterday', -tSTAMP
		$flags = $a.Substring(1)
		for ($j = 0; $j -lt $flags.Length; $j++) {
			$f = $flags[$j]
			if ($f -in 'd', 'r', 't') {
				$val = $flags.Substring($j + 1)
				if (-not $val) { $i++; if ($i -ge $argv.Count) { throw "touch: option requires an argument -- '$f'" }; $val = $argv[$i] }
				switch ($f) {
					'd' { $time = & $parseDate $val }
					'r' { $time = & $refTime $val }
					't' { $time = & $parseStamp $val }
				}
				break
			}
			switch ($f) {
				'a' { $onlyA = $true }
				'm' { $onlyM = $true }
				'c' { $create = $false }
				'h' { }
				'f' { }
				default { throw "touch: invalid option -- '$f'" }
			}
		}
	}

	if (-not $files) { throw 'touch: missing file operand' }

	# neither or both of -a/-m → change both
	if ($onlyA -xor $onlyM) { $atime = $onlyA; $mtime = $onlyM }

	if ($null -eq $time) { $time = Get-Date }
	$at = if ($time -is [hashtable]) { $time.A } else { $time }
	$mt = if ($time -is [hashtable]) { $time.M } else { $time }

	foreach ($f in $files) {
		if ($f -eq '-') { continue }
		$full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($f)
		$item = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
		if (-not $item) {
			if (-not $create) { continue }
			try { $item = New-Item -ItemType File -Path $full -ErrorAction Stop }
			catch { Write-Error "touch: cannot touch '$f': $($_.Exception.Message)"; continue }
		}
		if ($atime) { $item.LastAccessTime = $at }
		if ($mtime) { $item.LastWriteTime = $mt }
	}
}
