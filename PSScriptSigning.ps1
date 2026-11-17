#   ****************************************************************
#   * DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED *
#   * THOROUGHLY IN A LAB ENVIRONMENT. USE AT YOUR OWN RISK.  IF   *
#   * YOU DO NOT UNDERSTAND WHAT THIS SCRIPT DOES OR HOW IT WORKS, *
#   * DO NOT USE IT OUTSIDE OF A SECURE, TEST SETTING.             *
#   ****************************************************************

#Requires -RunAsAdministrator

<#

.NOTES    
    Autor  : Andreas Werner
    Date   : 13.11.2026
    
.SYNOPSIS
    PowerShell script signing GUI

.DESCRIPTION
    PowerShell script signing GUI

#>

#region - - - - -  P A R A M E T E R   - - - - -

[PSCustomObject] $parameter = New-Object -TypeName PSCustomObject -Property @{ 
    MainForm      = Join-Path -Path $PSScriptRoot -ChildPath  '\xaml\PSScriptSigning.xaml'
    Style         = Join-Path -Path $PSScriptRoot -ChildPath  '\config\Style.json'
    Configuration = Join-Path -Path $PSScriptRoot -ChildPath  '\config\PSScriptSigning.json'
    ModuleRoot    = Join-Path -Path $PSScriptRoot -ChildPath  '\module'   
}
           
#endregion

#  +--------------------------------------------------------+
#  |   = = = = =   S T A R T   -   S C R I P T   = = = =    |
#  +--------------------------------------------------------+

Clear-Host
$ErrorActionPreference = 'Stop'
$WarningPreference     = 'SilentlyContinue'
    
#region Import modules
    Write-Host 'Import PowerShell modules' -BackgroundColor DarkCyan -ForegroundColor White
    Get-ChildItem -Path $parameter.ModuleRoot -File -Filter "*.psm1" | ForEach-Object{
        Write-Host " -> $($_.Name)"  -NoNewline
            Import-Module -Name $_.FullName -Force -ErrorAction Stop
        Write-Host ' - OK' -ForegroundColor Green
    }
#endregion

Write-Host '' 

#region Import JSON files
    Write-Host 'Import JSON files' -BackgroundColor DarkCyan -ForegroundColor White
    try
    {    
        Write-Host ' -> Config.json file ' -NoNewline       
            [PSCustomObject] $config = Import-JSON_File -FilePath $($parameter.Configuration)
        Write-Host '- OK' -ForegroundColor Green
    }
    catch
    {       
        break
    }

    try
    {    
        Write-Host ' -> Style.json file ' -NoNewline         
            [PSCustomObject] $style = Import-JSON_File -FilePath $($parameter.Style)
        Write-Host ' - OK' -ForegroundColor Green        
    }
    catch
    {
        Write-Host $Error[0].Exception.Message
        end
    }
#endregion

#region Add shared assemblies
    try
    {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework') | Out-Null
        [System.Reflection.Assembly]::LoadWithPartialName('PresentationCore')      | Out-Null
        # [System.Reflection.Assembly]::LoadWithPartialName('WindowsBase')           | Out-Null
    }
    catch
    {
        Write-Host $Error[0].Exception.Message -BackgroundColor Red -ForegroundColor White
        end
    }
#endregion

#region MainForm - Read XAML and set PS-Variable
    
    [xml] $xaml = Get-WPS_MainForm 
    
    $reader = New-Object System.Xml.XmlNodeReader $xaml

    try
    {
        $MainForm = [Windows.Markup.XamlReader]::Load( $reader )
    }
    catch
    {        
        Write-Host ''
        Write-Host $Error[0].Exception.Message -BackgroundColor Red -ForegroundColor White
        exit
    }
    
    # Store Form Objects In PowerShell
        $xaml.SelectNodes("//*[@Name]") | ForEach-Object{
        Set-Variable -Name ($_.Name) -Value $MainForm.FindName($_.Name)        
    }
#endregion



#region Ribbon
    $rbtnListSSC.LargeImageSource      = $PSScriptRoot + '\images\Lupe.png'
    $rbtnExit.LargeImageSource         = $PSScriptRoot + '\images\close.png'
    $rbtnStartSigning.LargeImageSource = $PSScriptRoot + '\images\approved.png'
    $rbtnNewSSC.LargeImageSource       = $PSScriptRoot + '\images\Note.png'
    $rbtnRemoveSSC.LargeImageSource    = $PSScriptRoot + '\images\clean.png'    
    $rbtnTestSigning.LargeImageSource  = $PSScriptRoot + '\images\test.png'
#endregion

#region Add column to Datatable
    $dtCodeSelfSign = New-Object System.Data.DataTable   

    [System.Array] $col = 
    @(
        "Thumbprint"
        "FriendlyName"
        "NotAfter"
        "HashAlgorithm"
        "KeyLength"       
    )
 
    $dtCodeSelfSign.Columns.AddRange($col)
#endregion

$txtValidYears.Add_PreviewTextInput({
    param($sender, $e)

    if ($e.Text -notmatch '^\d+$') {
        $e.Handled = $true
    }
})

$txtValidYears.Add_TextChanged({
    param($sender, $e)

    $min = 0
    if ([int]::TryParse($sender.Text, [ref]$min)) {

        if ($min -le 0) {
            $sender.BorderBrush = 'Red'
        }
        else {
            $sender.ClearValue([System.Windows.Controls.Control]::BorderBrushProperty)
        }
    }
})


# Button - Create new Self-sign certificate   
    $rbtnNewSSC.Add_Click({ Show-SelfSignCode  })

# Button - Create new Self-sign certificate   
    $rbtnNewSSC.Add_Click({ New-SelfSignCode  })

# Button - Remove new Self-sign certificate
    $rbtnRemoveSSC.Add_Click({ 
        Add-Type -AssemblyName System.Windows.Forms
        [System.String] $thumbprint = $dgCodSelfSign.SelectedItem.Thumbprint

        if(-not $thumbprint -or $null -eq $thumbprint) {
            Write-Host "No certificate selected." -BackgroundColor Red -ForegroundColor White
            "No certificate selected." |  Write-StatusMessage -Severity WAR
            return
        }

        $result = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to remove the self-signed code signing certificate?`nThumbprint: $thumbprint",
            "Remove Self-Signed Code Signing Certificate",  
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2
        )
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            Remove-SelfSignCode -Thumbprint $thumbprint
        }
        
        Show-SelfSignCode
    })

# Button - Start PowerShell script signing
    $rbtnStartSigning.Add_Click({ Start-PowerShellScriptSigning  })

# Button - Start PowerShell script signing
    $rbtnTestSigning.Add_Click({ Test-PowerShellScriptSigning  })
    
# Exit  PowerShell application
    $rbtnExit.Add_Click({ $MainForm.Close() })
    $rAppMenuExit.Add_Click({ $MainForm.Close() })

#region Show all certificates with code signing usage in the current user store
   Show-SelfSignCode

# Set default values for the GUI
    Set-GUIDefaults

# Show Dialog    
    $MainForm.WindowState = "Maximized"
    $MainForm.ShowDialog() | Out-Null