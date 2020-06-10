param(
    [Parameter()]
    [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE', 
                 'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED', 
                 'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
    $State = 'FORCEMINIMIZE',
    
    [Parameter()]
    $ProcName = @('HSPFEngine','powershell'),
    
    [Parameter()]
    $WindowTitle = $null
)
    $WindowStates = @{
        'FORCEMINIMIZE'   = 11
        'HIDE'            = 0
        'MAXIMIZE'        = 3
        'MINIMIZE'        = 6
        'RESTORE'         = 9
        'SHOW'            = 5
        'SHOWDEFAULT'     = 10
        'SHOWMAXIMIZED'   = 3
        'SHOWMINIMIZED'   = 2
        'SHOWMINNOACTIVE' = 7
        'SHOWNA'          = 8
        'SHOWNOACTIVATE'  = 4
        'SHOWNORMAL'      = 1
    }
$Win32ShowWindow = Add-Type –memberDefinition @” 
[DllImport("user32.dll")] 
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow); 
“@ -name “Win32ShowWindow” -namespace Win32Functions –passThru  

if ($null -eq $WindowTitle) {
    Get-Process -Name $ProcName |%{
        $Win32ShowWindow::ShowWindow($_.MainWindowHandle,$WindowStates[$State])
    } |Out-Null
}
else {
    Get-Process -Name $ProcName |?{$_.MainWindowTitle -imatch $WindowTitle} |%{
        $Win32ShowWindow::ShowWindow($_.MainWindowHandle,$WindowStates[$State])
    } |Out-Null
}
