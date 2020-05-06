$jb = @()
foreach ($v in @(1..22)) {
    $jb += Invoke-Command -ComputerName $v.ToString('vgrid00') -ScriptBlock {
        gwmi win32_logicaldisk |ft -AutoSize
    } -AsJob
}
Wait-Job $jb
Receive-Job $jb
