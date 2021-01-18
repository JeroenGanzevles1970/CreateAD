[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
$scriptName     = ($MyInvocation.MyCommand.Name.replace( ".ps1", ""))
$ScriptPath     = (split-path -parent $MyInvocation.Mycommand.Path)
$xamlFile       = "$ScriptPath\XAML\Domain.xaml"
$ProgramVersion = "1.0"
$ProgramDate    = "26-08-2020"
$LogFolder      = ("{0}\Logging" -f $ScriptPath)
$hostname       = $env:computername
$sysvol         = "c:\Windows\Sysvol" 
$DHCPEnabled    = (Get-NetIPInterface -InterfaceAlias eth* -AddressFamily IPv4).Dhcp
$interface      = (Get-NetIPAddress -AddressFamily IPv4 -interFaceAlias Eth*)
$Ipaddress      = $interface.IpAddress
$PrefixLength   = $interface.PrefixLength
$INtGateway     = (Get-NetIPConfiguration)
$defaultGateway = ($INtGateway.IPv4DefaultGateway.nexthop)

Import-Module -Name ($ScriptPath + "\Module\Logging.psm1") -ErrorAction SilentlyContinue -Force
. .\function\functionlib.ps1 

# Maak bovenstaande mappen aan indien ze nog niet bestaan
If(!(Test-Path -Path $LogFolder)){
  New-Item -Path $LogFolder -ItemType Directory
}

Start-Log -LogPath $LogFolder -LogName $ScriptName
Write-Log -Msg "dit is scriptversion: $ProgramVersion en het script is gestart op $ProgramDate." -Level Info

if(test-path -path $xamlFile){
    Write-log -Msg "Het XAML bestand is beschikbaar om gebruikt te worden." 
}
Else{
    Write-log "Bestand bestaat niet." -level Error
    Write-log "Script wordt afgesloten" -level Error
    Exit
}

#create window
$inputXML = Get-Content $xamlFile -Raw
$inputXML = $inputXML -replace '<vervang>', $ScriptPath
[XML]$XAML = $inputXML
$reader = (New-Object System.Xml.XmlNodeReader $xaml) 
try { $Form = [Windows.Markup.XamlReader]::Load( $reader ) }
catch { Write-Host "Unable to load Windows.Markup.XamlReader"; exit }
 
# Store Form Objects In PowerShell
$xaml.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name ($_.Name) -Value $Form.FindName($_.Name) }
$listfiles = Get-ChildItem -path "$Logfolder" "*.log"
foreach( $files in $listfiles){
    $CBfilelist.Items.Add($files.name)
}

$sysvolExist = test-Path $sysvol
if ($sysvolExist -eq $True){
    $DomainName = (Get-ADDomain).DNSRoot
    write-log -msg "Deze machine host het domain $domainName. " -level info
    $TBOU.IsSelected = "True"
    $TBou.IsEnabled = "True"
    $TBgroepen.IsEnabled = "True"
    $TBUsers.IsEnabled = "True"
}
Else{
    write-log -msg "Deze machine is geen domain controller. " -level Warning
}

$TXHostnaam.text = $hostname 
Write-log -msg "Deze machine heeft nu als hostname $hostname." -level info
$TXHostnaam.Add_TextChanged({
    $BTHernoemServer.IsEnabled = "true" 
})

$TXNetbiosNaam.Add_TextChanged({
    $BTConfigAD.IsEnabled = "true" 
})

if($DHCPEnabled -eq $True){
    Write-log -msg "Deze machine heeft een DHCP ipaddress." -level info
    $CHdhcp.IsChecked = "True"
    $TXipaddress.IsReadOnly = "true"  
    $TXipaddress.text = $Ipaddress
    $TXPrefixLength.IsReadOnly = "true"
    $TXPrefixLength.text = $PrefixLength 
    $TXGateway.IsReadOnly = "true"
    $TXGateway.text = $defaultGateway
}

Stop-log

$CHdhcp.Add_Checked({
    $TXipaddress.IsReadOnly = "true"  
    $TXipaddress.text = $Ipaddress
    $TXPrefixLength.IsReadOnly = "true"
    $TXPrefixLength.text = $PrefixLength 
    $TXGateway.IsReadOnly = "true"
    $TXGateway.text = $defaultGateway
})

$CHdhcp.add_UnChecked({
    $TXipaddress.IsReadOnly = ""  
    $TXipaddress.Text = ""
    $TXPrefixLength.IsReadOnly = ""
    $TXPrefixLength.text = ""
    $TXGateway.IsReadOnly = ""
    $TXGateway.text = ""
})

$BTHernoemServer.Add_click({
    $NewHostname = $TXHostnaam.Text
    RenameHostname -NewHostname  $NewHostname
    $Form.close()
    shutdown -r -t 0
})

$BTConfigAD.Add_Click({
    $DomainName = $TXDomeinNaam.Text    
    $NetbiosName = $TXNetbiosNaam.Text
    $SafeMode = $PSSafeMode.Password
    $IPAddress = $TXIpaddress.Text
    $PrefixLength = $TXPrefixLength.Text
    $Gateway = $TXGateway.Text

    SetIPADDRESS -ipaddress $IPAddress -PrefixLength $PrefixLength -gateway $Gateway 
    installAD   
    CreateForest -DomainName $DomainName -NetBiosName $NetbiosName -SafeMode $SafeMode
    $Form.close()
    shutdown -r -t 0
})


$BTEditCSV.Add_click({
    start-process 'C:\windows\system32\notepad.exe' .\csv\OUstructuur.csv

})

$Btshowlog.Add_click({
     showlog 

})

$BTBrowseOU.Add_click({
    SelectOU
    write-host  " $dn_text_box.Text" 
})

$Form.ShowDialog() | out-null
