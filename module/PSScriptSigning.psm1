#
# Autor   : Andreas werner
# Date    : 13.07.2023
# Version : 1.0
#


function Get-WindowResourcesStyle
{
[CmdletBinding()]
param
(
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="File path")]
    [PSCustomObject] $Style
)

Begin 
{ 
    [System.String] $windowResourcesStyle = ''
}

Process
{    
    [System.Array] $styleNames =  $Style | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -ne 'MainForm' }     

    foreach( $styleName in $styleNames.Name)
    {
        
        [System.String] $targetTypeStart = "<Style TargetType='$styleName'>"   
        [System.String] $targetTypeEnd   = "</Style>"
        [System.String] $Setters         = ""

         $Style.$styleName | Get-Member -MemberType NoteProperty | ForEach-Object{
            $property = $_.Name
            $value    = $Style.$styleName.$property

            $Setters += "<Setter Property='$property' Value='$value' />"
         }

         $windowResourcesStyle += $targetTypeStart + $Setters + $targetTypeEnd
    }
    
}

End 
{ 
    return $windowResourcesStyle
}

}

function Get-WPS_MainForm
{
[CmdletBinding()]
param()

#Load Tab items
    $mainFormTabItem = Get-ChildItem -Path $($parameter.MainForm) -Filter '*.xaml' | Get-Content -Encoding utf8

    $windowResourcesStyle = Get-WindowResourcesStyle -Style $Style

[xml] $xamlMainForm = @"
<Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:ribbon="clr-namespace:System.Windows.Controls.Ribbon;assembly=System.Windows.Controls.Ribbon"

        FontFamily            = "$($Style.MainForm.FontFamily)"
        Title                 = "$($config.Title) - Version: $($config.Version)"
        ShowInTaskbar         = "$($Style.MainForm.ShowInTaskbar)"
        WindowStartupLocation = "$($Style.MainForm.WindowStartupLocation)"
        ResizeMode            = "$($Style.MainForm.ResizeMode)"       
        Background            = "$($Style.MainForm.Background)" 
>
    <Window.Resources>        
        $windowResourcesStyle 
    </Window.Resources>
       
    $($mainFormTabItem)

</Window>
"@

    return $xamlMainForm

}

function Import-JSON_File
{
[CmdletBinding()]
param
(
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,HelpMessage="File path")]
    [Alias("FullName")]
    [System.String] $FilePath,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="File encoding")]
    [System.Text.Encoding] $Encoding = [System.Text.Encoding]::UTF8,

    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,HelpMessage="validate file path")]
    [Switch] $ValidateFilePath
)

Begin 
{ 
    Write-Verbose "Start - Import JSON file"
}

Process
{
    #region Test file path
        if($ValidateFilePath)
        {
            Write-Verbose "Test file path : $FilePath"
            if( -not( Test-Path -Path $FilePath )) 
            {
                Write-Warning "JSON file not found" -Verbose
                return
            }
            Write-Verbose "OK - File found"
        }
    #endregion
    
    #region Import JSON file
        try 
        {
            Write-Verbose 'Import JSON file...'
            Write-Verbose "  Encoding : $Encoding"
            Write-Verbose "  FilePath : $FilePath"

            $json = Get-Content -Raw -Encoding UTF8 -Path $FilePath | ConvertFrom-Json -ErrorAction Stop 
            Write-Verbose "OK - Import JSON file successfully"
            
            return $json
        }
        catch 
        {
            $errMsg = $Global:Error[0].Exception.Message
            Write-Host $errMsg -BackgroundColor Red -ForegroundColor White
            
            return
        }
    #endregion
}

End 
{ 
    Write-Verbose "Finish - Import JSON file"
}

}

function Write-StatusMessage
{
[CmdletBinding()]
param 
(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [System.String] $Message,
    
    [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
    [ValidateSet("Info","OK","WAR","ERR")]
    [System.String] $Severity = 'Info' 
)
    switch($severity )
    {
        'Info' { $staInfo.Background = 'White'     ; $txtStatusInfo.Foreground = 'Black' }
        'OK'   { $staInfo.Background = 'PaleGreen' ; $txtStatusInfo.Foreground = 'Black' }        
        'WAR'  { $staInfo.Background = 'Yellow'    ; $txtStatusInfo.Foreground = 'Black' }
        'ERR'  { $staInfo.Background = 'Red'       ; $txtStatusInfo.Foreground = 'White' }
    }
    
    $txtStatusInfo.Text = $Message
    $MainForm.Dispatcher.Invoke([System.Action]{},'Background')
}


#-------------------------------------------------------------------
#--------------     S E L F S I G N     ------------------
#-------------------------------------------------------------------

function Set-GUIDefaults
{
    $config.Defaults.Certificate

    $txtFriendlyName.Text = $config.Defaults.Certificate.FriendlyName
    $txtDnsName.Text      = $config.Defaults.Certificate.DnsName 
    $txtValidYears.Text   = $config.Defaults.Certificate.ValidYears

    $cboKeyLength.ItemsSource = $config.Defaults.Certificate.KeyLength
    $cboKeyLength.SelectedIndex = 0
    $cboHashAlgo.ItemsSource  = $config.Defaults.Certificate.HashAlgorithm
    $cboHashAlgo.SelectedIndex = 0
}

function New-SelfSignCode
{
[CmdletBinding()]
param()

Begin {}

Process
{
'Create new Self-sign certificate. Please wait...' | Write-StatusMessage -severity Info

[hashtable] $certParam = @{   
    CertStoreLocation = "Cert:\CurrentUser\My"
    KeyLength         = $cboKeyLength.Text
    Type              = 'CodeSigningCert'    
    HashAlgorithm     = $cboHashAlgo.Text      
    ErrorAction       = 'Stop' 
}

# Friendly name
    if ( $txtFriendlyName.Text.Trim() ) { $certParam.add('FriendlyName', $($txtFriendlyName.Text.Trim() )) }
    else { $certParam.add('FriendlyName', $null ) }

# DNS name
    if ( $txtDnsName.Text.Trim() ) { $certParam.add('DnsName', $($txtDnsName.Text.Trim() )) }
    else { 'DNS name not set' | Write-StatusMessage -Severity ERR ; return }

# Valid certificate in years
    try   { [System.Int16] $years = $txtValidYears.Text.Trim()  }
    catch { $Global:Error[0].Exception.Message | Write-StatusMessage -Severity ERR ; return }

    if ( $years -gt 0 -or $years -eq 10) { $certParam.add('NotAfter', $( (Get-Date).AddYears($years) ) ) }
    else { 'Invalid year value' | Write-StatusMessage -Severity ERR ; return }
    
# Create new certificate
    try   { $cert = New-SelfSignedCertificate  @certParam }
    catch { $Global:Error[0].Exception.Message | Write-StatusMessage -Severity ERR ; return }

# Export public key from Self-sign certificate
    [System.String] $exportFilePath = Join-Path -Path $env:TEMP -ChildPath 'tempPubSelfSignCert.cer'

    try   { Export-Certificate -Cert $cert -FilePath $exportFilePath -ErrorAction Stop }
    catch { $Global:Error[0].Exception.Message | Write-StatusMessage -Severity ERR ; return }

# Add Certificate to the "Trusted Root Store"
    try   { Import-Certificate -CertStoreLocation "Cert:\LocalMachine\Root" -FilePath $exportFilePath -ErrorAction Stop }
    catch { $Global:Error[0].Exception.Message | Write-StatusMessage -Severity ERR ; return }

# Add Certificate to the "Trusted Publisher"
    try   { Import-Certificate -CertStoreLocation "Cert:\LocalMachine\TrustedPublisher" -FilePath $exportFilePath -ErrorAction Stop }
    catch { $Global:Error[0].Exception.Message | Write-StatusMessage -Severity ERR ; return }


    "Self-sign certificate created - Thumbprint: $($cert.Thumbprint)" | Write-StatusMessage -Severity OK

    show-SelfSignCode
}

End {}
}

function Show-SelfSignCode
{
[CmdletBinding()]
param()

Process
{
    $dtCodeSelfSign.Rows.Clear()

    [System.Array] $certs = Get-ChildItem -Path "Cert:\CurrentUser\My" -Recurse | Where-Object { $_.EnhancedKeyUsageList.ObjectId -contains '1.3.6.1.5.5.7.3.3' } 

    if( $certs.Count -eq 0 ) 
    { 
        'No Self-sign certificate found' | Write-StatusMessage -Severity war
        $dgCodSelfSign.ItemsSource = $dtCodeSelfSign.DefaultView
        return
    }
    
    foreach ( $cert in $certs)
    {
       [System.Boolean] $existRoot      = $false
       [System.Boolean] $existTrustPubl = $false

       $thumbprint = $cert.thumbprint

       $pathRoot     = Join-Path -Path "Cert:\LocalMachine\Root" -ChildPath $thumbprint
       $pathTrustPub = Join-Path -Path "Cert:\LocalMachine\TrustedPublisher" -ChildPath $thumbprint

       if(Test-Path -Path $pathRoot)     { $existRoot      = $true }
       if(Test-Path -Path $pathTrustPub) { $existTrustPubl = $true }

       if ( $existRoot -and $existTrustPubl ) 
       { 
            $row = $dtCodeSelfSign.NewRow()                
                $row.Thumbprint    = $cert.Thumbprint
                $row.FriendlyName  = $cert.FriendlyName
                $row.NotAfter      = $cert.NotAfter
                $row.HashAlgorithm = $cert.SignatureAlgorithm.FriendlyName
                $row.KeyLength     = $cert.PublicKey.Key.KeySize
                
            [void] $dtCodeSelfSign.Rows.Add($row)
       }
    }
    
    $dgCodSelfSign.ItemsSource = $dtCodeSelfSign.DefaultView
}

End {}

}

function Remove-SelfSignCode
{
[CmdletBinding()]
param(
    [System.String] $Thumbprint = $dgCodSelfSign.SelectedItem.Thumbprint
)

Process
{    
    try
    {
        [System.String] $pathTrustPub = Join-Path -Path "Cert:\LocalMachine\TrustedPublisher" -ChildPath $thumbprint
        Remove-Item -Path $pathTrustPub -Force -ErrorAction Stop

        [System.String] $pathRoot = Join-Path -Path "Cert:\LocalMachine\Root" -ChildPath $thumbprint
        Remove-Item -Path $pathRoot -Force -ErrorAction Stop

        [System.String] $pathMy = Join-Path -Path "Cert:\CurrentUser\My" -ChildPath $thumbprint
        Remove-Item -Path $pathMy -Force -ErrorAction Stop
    }
    catch
    {
        $Global:Error[0].Exception.Message | Write-StatusMessage -Severity ERR ; return
    }

    "Self-sign certificate removed - Thumbprint: $($thumbprint)" | Write-StatusMessage -Severity OK

    Show-SelfSignCode
}

End {}

}

function Start-PowerShellScriptSigning
{
[CmdletBinding()]
param
(
    
)

Process
{
    #region Signing certificate
        [System.String] $thumbprint = $dgCodSelfSign.SelectedItem.Thumbprint
        if (-not $thumbprint)
        {
            'Signing certificate not selected' | Write-StatusMessage -Severity ERR
            return
        }
    #endregion

    #region Open file dialog
        $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
            InitialDirectory = [Environment]::GetFolderPath('Desktop')
            Filter =  'PowerShell (*.ps1;*.psm1;*.psd1)|*.ps1;*.psm1;*.psd1'
        }

        $null = $fileBrowser.ShowDialog()
    #endregion

    #region Start Signing
        if ($fileBrowser.FileName)
        {
            [System.String] $pathMy = Join-Path -Path "Cert:\CurrentUser\My" -ChildPath $thumbprint
            $cert = Get-ChildItem -Path $pathMy
            
            Set-AuthenticodeSignature -Certificate $cert -FilePath $($fileBrowser.FileName) -ErrorAction Stop

            '!!!  > The script has been digitally signed <  !!!' | Write-StatusMessage -Severity OK
        }
    #endregion
}

End {}

}

function Test-PowerShellScriptSigning
{
[CmdletBinding()]
param ()

Process
{
    # Open file dialog
        $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
            InitialDirectory = [Environment]::GetFolderPath('Desktop')
            Filter =  'PowerShell (*.ps1;*.psm1;*.psd1)|*.ps1;*.psm1;*.psd1'
        }

        $null = $fileBrowser.ShowDialog()
    
    #region Start test signing
        if ($fileBrowser.FileName)
        {            
            $getAuthenticodeSignature = Get-AuthenticodeSignature -FilePath $($fileBrowser.FileName) -ErrorAction Stop

            switch ($($getAuthenticodeSignature.Status))
            {
                'Valid'        { $txtAuthSigStatus.Background = 'PaleGreen'; $txtAuthSigStatus.Foreground = 'Black'}
                'NotSigned'    { $txtAuthSigStatus.Background = 'yellow'   ; $txtAuthSigStatus.Foreground = 'Black'}
                'HashMismatch' { $txtAuthSigStatus.Background = 'red'      ; $txtAuthSigStatus.Foreground = 'White'}
                default        { $txtAuthSigStatus.Background = 'White'    ; $txtAuthSigStatus.Foreground = 'Black'}
            }
            
            $txtAuthSigPath.Text      = $getAuthenticodeSignature.Path
            $txtAuthSigStatus.Text    = $getAuthenticodeSignature.Status
            $txtAuthSigStatusMsg.Text = $getAuthenticodeSignature.StatusMessage
            $txtAuthSigType.Text      = $getAuthenticodeSignature.SignatureType
            $txtAuthSigTimeStamp.Text = $getAuthenticodeSignature.TimeStamperCertificate

            $txtAuthSigThumbprint.Text = $getAuthenticodeSignature.SignerCertificate.Thumbprint            
            $txtAuthSigNotAfter.Text   = Get-date -Date $getAuthenticodeSignature.SignerCertificate.NotAfter -Format 'dd.MM.yyyy HH:mm:ss'
              

            switch ($($getAuthenticodeSignature.Status))
            {
                'Valid'        { 'The script is digitally signed and the signature is valid' | Write-StatusMessage -Severity OK }
                'NotSigned'    { 'The script is not digitally signed' | Write-StatusMessage -Severity WAR }
                'HashMismatch' { 'The script is digitally signed but the signature is invalid' | Write-StatusMessage -Severity ERR }
                default        { $getAuthenticodeSignature.StatusMessage | Write-StatusMessage -Severity ERR }
            }
        }
}

End {}

}