# PowerShell mirror of test-validate-batch.sh — exercises validate_batch.py
# against known-good and known-broken JSON inputs.

Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginRoot = Split-Path -Parent $ScriptDir
$Validator = Join-Path $ScriptDir 'validate_batch.py'

$script:PASS = 0
$script:FAIL = 0
function Pass($m) { $script:PASS++; Write-Host "  PASS  $m" }
function Fail($m, $d = '') { $script:FAIL++; Write-Host "  FAIL  $m"; if ($d) { Write-Host "        $d" } }

Write-Host 'test-validate-batch.ps1 — exercises validate_batch.py'
Write-Host ''

function Invoke-Validator([string]$JsonText) {
    $tmp = New-TemporaryFile
    Set-Content -LiteralPath $tmp.FullName -Value $JsonText -Encoding UTF8
    $errFile = New-TemporaryFile
    $stdout = & python3 $Validator $tmp.FullName 2>$errFile.FullName
    $rc = $LASTEXITCODE
    $errText = Get-Content -Raw -LiteralPath $errFile.FullName -ErrorAction SilentlyContinue
    Remove-Item -Force $tmp.FullName, $errFile.FullName -ErrorAction SilentlyContinue
    return @{ rc = $rc; stderr = $errText }
}

# Stage 1: a well-formed, fully-scored batch passes with NO advisory warnings.
# A "clean" doc is structurally valid AND carries all five review-queue scored
# fields on every task with no varchar(255) overflow — exit 0 with empty stderr.
$ok = @'
{"goals": [{"title": "Test goal", "type": "goal", "tasks": [{"title": "T1", "type": "work", "dependencies": [], "testing_strategy": {"unit_tests": ["covers the happy path"]}, "security_considerations": ["scoped to the current user"], "patterns_to_follow": "mirror the sibling module", "pitfalls": ["do not skip validation"], "acceptance_criteria": "the feature works end to end"}]}]}
'@
$r = Invoke-Validator $ok
if ($r.rc -eq 0 -and [string]::IsNullOrWhiteSpace($r.stderr)) {
    Pass "well-formed, fully-scored batch accepted with no warnings"
} else {
    Fail "well-formed batch rejected or produced unexpected warnings" $r.stderr
}

# Stage 2: malformed JSON triggers parse_error.
$r = Invoke-Validator 'not json at all {{'
if ($r.rc -ne 0 -and ($r.stderr -match 'parse|JSON')) { Pass "parse_error reported on bad JSON" } else { Fail "parse_error not detected" $r.stderr }

# Stage 3: wrong root key (tasks instead of goals) reports the common mistake.
$wrongRoot = '{"tasks": [{"title": "x", "type": "work"}]}'
$r = Invoke-Validator $wrongRoot
if ($r.rc -ne 0 -and ($r.stderr -match "(?i)root.*key|tasks|goals")) {
    Pass "wrong_root_key detected"
} else {
    Fail "wrong_root_key not detected" $r.stderr
}

# Stage 4: empty goals array.
$r = Invoke-Validator '{"goals": []}'
if ($r.rc -ne 0 -and ($r.stderr -match "empty|goals")) { Pass "empty_goals detected" } else { Fail "empty_goals not detected" $r.stderr }

# Stage 5: goal missing required field (title).
$missingField = '{"goals": [{"type": "goal", "tasks": []}]}'
$r = Invoke-Validator $missingField
if ($r.rc -ne 0 -and ($r.stderr -match "title|required|missing")) {
    Pass "goal_missing_field detected"
} else {
    Fail "goal_missing_field not detected" $r.stderr
}

# Stage 6: bad dependency index (forward reference).
$badDep = @'
{"goals": [{"title": "G", "type": "goal", "tasks": [
    {"title": "T1", "type": "work", "dependencies": [5]}
]}]}
'@
$r = Invoke-Validator $badDep
if ($r.rc -ne 0 -and ($r.stderr -match "dependency|dependencies|index|references")) {
    Pass "bad_dependency_index detected"
} else {
    Fail "bad_dependency_index not detected" $r.stderr
}

# Stage 7: a task missing scored fields warns on stderr but STILL exits 0.
$missingScored = '{"goals": [{"title": "G", "type": "goal", "tasks": [{"title": "Bare task", "type": "work", "dependencies": []}]}]}'
$r = Invoke-Validator $missingScored
if ($r.rc -eq 0 -and ($r.stderr -match "missing scored field")) {
    Pass "advisory: missing scored fields warns but exits 0"
} else {
    Fail "advisory: missing scored fields not warned (or exit changed)" $r.stderr
}

# Stage 8: an empty scored field (present but empty) also counts as missing.
$emptyScored = '{"goals": [{"title": "G", "type": "goal", "tasks": [{"title": "Empty pitfalls", "type": "work", "dependencies": [], "testing_strategy": {"unit_tests": ["t"]}, "security_considerations": ["s"], "patterns_to_follow": "p", "pitfalls": [], "acceptance_criteria": "ac"}]}]}'
$r = Invoke-Validator $emptyScored
if ($r.rc -eq 0 -and ($r.stderr -match "missing scored field 'pitfalls'")) {
    Pass "advisory: an empty scored field counts as missing"
} else {
    Fail "advisory: empty scored field not warned" $r.stderr
}

# Stage 9: a title over 255 code points warns but exits 0.
$longTitle = 'T' * 300
$longTitleDoc = '{"goals": [{"title": "G", "type": "goal", "tasks": [{"title": "' + $longTitle + '", "type": "work", "dependencies": [], "testing_strategy": {"unit_tests": ["t"]}, "security_considerations": ["s"], "patterns_to_follow": "p", "pitfalls": ["pf"], "acceptance_criteria": "ac"}]}]}'
$r = Invoke-Validator $longTitleDoc
if ($r.rc -eq 0 -and ($r.stderr -match "over the 255 varchar limit")) {
    Pass "advisory: a title over 255 code points warns but exits 0"
} else {
    Fail "advisory: over-255 title not warned" $r.stderr
}

# Stage 10: a security_considerations element over 255 code points warns.
$longElem = 'S' * 300
$longSecDoc = '{"goals": [{"title": "G", "type": "goal", "tasks": [{"title": "T", "type": "work", "dependencies": [], "testing_strategy": {"unit_tests": ["t"]}, "security_considerations": ["' + $longElem + '"], "patterns_to_follow": "p", "pitfalls": ["pf"], "acceptance_criteria": "ac"}]}]}'
$r = Invoke-Validator $longSecDoc
if ($r.rc -eq 0 -and ($r.stderr -match "security_considerations\[0\] is 300 code points")) {
    Pass "advisory: a security_considerations element over 255 code points warns"
} else {
    Fail "advisory: over-255 array element not warned" $r.stderr
}

# Stage 11: structural checks stay FATAL even when advisories would also apply.
$fatalBeatsWarning = @'
{"goals": [{"title": "G", "type": "goal", "tasks": [
    {"title": "First", "type": "work", "dependencies": []},
    {"title": "Second", "type": "work", "dependencies": [9]}
]}]}
'@
$r = Invoke-Validator $fatalBeatsWarning
if ($r.rc -ne 0 -and ($r.stderr -match "references index 9 but goal only has 2 tasks")) {
    Pass "structural error stays fatal even when scored fields are missing"
} else {
    Fail "structural error did not stay fatal" $r.stderr
}

Write-Host ''
Write-Host ("{0} passed, {1} failed" -f $script:PASS, $script:FAIL)
if ($script:FAIL -gt 0) { exit 1 } else { exit 0 }
