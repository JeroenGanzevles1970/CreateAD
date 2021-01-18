Function RenameHostname{
    param(
        [string]$NewHostname
    )
    process {
        $Hostname = $env:COMPUTERNAME
        Start-Log -LogPath $LogFolder -LogName "RenameHost"
        $CBfilelist.Items.Add("RenameHost.log")

        if ($NewHostname -eq $Hostname){
            Write-log -Msg "De hostnaam is al gezet naar $Hostname." -Level Info 
            Stop-Log
        }
        Else{
            try{
                Rename-Computer -NewName $NewHostname 
                Write-log -Msg "De hostnaam is geworden $Newhostname. " -Level Info
                Write-log -Msg "De Server wordt gereboot om de hostname door te voeren." -Level Info
                stop-Log    
            }
            catch{
                write-log -msg "De hostnaam kon niet gewijzigd worden." -Level error
                Write-log -msg "$_" -Level error
                stop-log
            }
        }
    }
}

Function SetIPADDRESS{
    Param(
        [ipaddress]$IPAddress,
        [int32]$PrefixLength, 
        [ipaddress]$Gateway 
    )
    process {
        Start-Log -LogPath $LogFolder -LogName "SetIpaddress"
        try {
            $interface = (Get-NetIPAddress -AddressFamily IPv4 -interFaceAlias Eth*)
            $interfaceAlias = $interface.Interfacealias
            $interfaceIndex = $interface.InterfaceIndex

            write-log -msg "Er is een interface gevonden met als alias ethernet" -level info
        }
        catch {
            write-log -msg "De interface met als aliasnaam ethernet is niet gevonden." -Level error
            Write-log -msg "$_" -Level error 
        }

        if ($CHdhcp.ischecked -eq $true){
            Write-log -msg "Het vinkje voor DHCP is gezet." -level info
            Write-log -msg "De server heeft het IPaddress $IPaddress van de DHCP-Server gekregen." -level info 
            Write-log -msg "Het prefixlegth = $PrefixLength" -level info
            Write-log -msg "De defaultgateway = $Gateway" -level info
            Stop-log
        }
        else{
            Write-log -msg " het ipaddress wordt gezet." -level info
            try {
                Set-NetIPInterface -interfaceindex $interfaceIndex -Dhcp Disabled
                new-NetIPAddress -InterfaceAlias $interfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway
                Write-log -Msg "Het IP address is gezet op $IPAddress met als prefixlength $PrefixLength en als gateway $Gateway" -level Info
                Stop-Log 
            }
            catch {
                write-log -msg "Het ip address kan niet gezet worden" -Level error
                Write-log -msg "$_" -Level error
                Stop-log
            }
        }
    }
}

Function installAD{
    Start-Log -LogPath $LogFolder -LogName "installAD"
    $ADDomainServices = Get-WindowsFeature AD-Domain-Services
    if ($ADDomainServices.installstate -eq "installed"){
        Write-log -msg "De windows Feature AD-domain-Services is al geinstalleerd." -Level Warning
        stop-log
    }
    Else{
        Write-log -msg "De Windows Feature AD-Domain-Services is nog niet geinstalleerd. het word nu geinstalleerd." -level info
        Start-Job -ScriptBlock {Install-windowsfeature AD-domain-services}
        start-Sleep -S 40
        get-Job
        $ADDomainServices = Get-WindowsFeature AD-Domain-Services
        if ($ADDomainServices.installstate -eq "installed"){
            Write-log -msg "De Windows Feature AD-domain-services is geinstalleerd." -Level Info
            $Job = get-job
            $JobName = $Job.Name
            if($Job.state -eq "Completed"){ 
                remove-Job job* 
                Write-log -msg "De Job $JobName is verwijderd." -Level Info   
            }
            else{
                Write-log -msg "De Job $JobName is niet verwijderd." -Level Error
            }
        }
        else {
            Write-log -msg "De Windows Feature AD-Domain-Services is niet geinstalleerd." -Level error
        }
    stop-log
    }
}

function CreateForest{
    param(
        [string]$DomainName, 
        [string]$NetbiosName, 
        [string]$SafeMode
    )
    Process{
        Start-Log -LogPath $LogFolder -LogName "CreateForest"
        write-log -msg "De forest $DomainName wordt nu aangemaakt." -Level info
        try {


            Install-ADDSForest -SkipPreChecks -DomainName $DomainName -DomainNetbiosName $NetbiosName -CreateDNSDelegation:$false `
            -InstallDNS:$true -SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText $safemode -Force) -force:$true -NoRebootOnCompletion
            write-log -Msg "de forest is aangemaakt. De machine wordt nu gereboot." -Level info 
            Stop-log
        }
        catch {
            write-log -msg "De forest kon niet gemaakt worden." -Level error
            Write-log -msg "$_" -Level error 
            stop-Log       
        }
    }
    
}


function showlog() {
    $SelectLogfile = $CBfilelist.Selecteditem

    $logfil = $LogFolder + "\" + $SelectLogfile 
    $Loginhoud = get-Content -Path $logfil -Delimiter "`r`n"    
    $TXShowlog.text = $Loginhoud
}


function SelectOU()
{
    $dc_hash = @{}
    #$selected_ou = $null

    $forest = Get-ADForest
    #[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
    #[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

    function Get-NodeInfo($sender, $dn_textbox)
    {
        $selected_node = $sender.Node
        $dn_textbox.Text = $selected_node.Name
    }

    function Add-ChildNodes($sender)
    {
        $expanded_node = $sender.Node

        if ($expanded_node.Name -eq "root") {
            return
        }

        $expanded_node.Nodes.Clear() | Out-Null

       # $dc_hostname = $dc_hash[$($expanded_node.Name -replace '(OU=[^,]+,)*((DC=\w+,?)+)','$2')]
        $child_OUs = Get-ADObject -Server $dc_hostname -Filter 'ObjectClass -eq "organizationalUnit" -or ObjectClass -eq "container"' -SearchScope OneLevel -SearchBase $expanded_node.Name
        if($null -eq $child_OUs) {
            $sender.Cancel = $true
        } else {
            foreach($ou in $child_OUs) {
                $ou_node = New-Object Windows.Forms.TreeNode
                $ou_node.Text = $ou.Name
                $ou_node.Name = $ou.DistinguishedName
                $ou_node.Nodes.Add('') | Out-Null
                $expanded_node.Nodes.Add($ou_node) | Out-Null
            }
        }
    }

    function Add-ForestNodes($forest, [ref]$dc_hash)
    {
        $ad_root_node = New-Object Windows.Forms.TreeNode
        $ad_root_node.Text = $forest.RootDomain
        $ad_root_node.Name = "root"
        $ad_root_node.Expand()

        $i = 1
        foreach ($ad_domain in $forest.Domains) {
            Write-Progress -Activity "Querying AD forest for domains and hostnames..." -Status $ad_domain -PercentComplete ($i++ / $forest.Domains.Count * 100)
            $dc = Get-ADDomainController -Server $ad_domain
            $dn = $dc.DefaultPartition
            $dc_hash.Value.Add($dn, $dc.Hostname)
            $dc_node = New-Object Windows.Forms.TreeNode
            $dc_node.Name = $dn
            $dc_node.Text = $dc.Domain
            $dc_node.Nodes.Add("") | Out-Null
            $ad_root_node.Nodes.Add($dc_node) | Out-Null
        }

        return $ad_root_node
    }
    
    $main_dlg_box = New-Object System.Windows.Forms.Form
    $main_dlg_box.ClientSize = New-Object System.Drawing.Size(400,600)
    $main_dlg_box.MaximizeBox = $false
    $main_dlg_box.MinimizeBox = $false
    $main_dlg_box.FormBorderStyle = 'FixedSingle'

    # widget size and location variables
    $ctrl_width_col = $main_dlg_box.ClientSize.Width/20
    $ctrl_height_row = $main_dlg_box.ClientSize.Height/15
    $max_ctrl_width = $main_dlg_box.ClientSize.Width - $ctrl_width_col*2
    $max_ctrl_height = $main_dlg_box.ClientSize.Height - $ctrl_height_row
    $right_edge_x = $max_ctrl_width
    $left_edge_x = $ctrl_width_col
    $bottom_edge_y = $max_ctrl_height
    $top_edge_y = $ctrl_height_row

    # setup text box showing the distinguished name of the currently selected node
    $dn_text_box = New-Object System.Windows.Forms.TextBox
    # can not set the height for a single line text box, that's controlled by the font being used
    $dn_text_box.Width = (14 * $ctrl_width_col)
    $dn_text_box.Location = New-Object System.Drawing.Point($left_edge_x, ($bottom_edge_y - $dn_text_box.Height))
    $dn_text_box.Visible = $false
    $main_dlg_box.Controls.Add($dn_text_box)
    # /text box for dN

    # setup Ok button
    $ok_button = New-Object System.Windows.Forms.Button
    $ok_button.Size = New-Object System.Drawing.Size(($ctrl_width_col * 2), $dn_text_box.Height)
    $ok_button.Location = New-Object System.Drawing.Point(($right_edge_x - $ok_button.Width), ($bottom_edge_y - $ok_button.Height))
    $ok_button.Text = "Ok"
    $ok_button.DialogResult = 'OK'
    $main_dlg_box.Controls.Add($ok_button)
    # /Ok button

    # setup tree selector showing the domains
    $ad_tree_view = New-Object System.Windows.Forms.TreeView
    $ad_tree_view.Size = New-Object System.Drawing.Size($max_ctrl_width, ($max_ctrl_height - $dn_text_box.Height - $ctrl_height_row*1.5))
    $ad_tree_view.Location = New-Object System.Drawing.Point($left_edge_x, $top_edge_y)
    $ad_tree_view.Nodes.Add($(Add-ForestNodes $forest ([ref]$dc_hash))) | Out-Null
    $ad_tree_view.Add_BeforeExpand({Add-ChildNodes $_})
    $ad_tree_view.Add_AfterSelect({Get-NodeInfo $_ $dn_text_box})
    $main_dlg_box.Controls.Add($ad_tree_view)
    # /tree selector

    $main_dlg_box.ShowDialog() | Out-Null

    return  $dn_text_box.Text
}


function CreateBulkOU {
    param(

    )
    start-log -LogPath $LogFolder -LogName "CreateBulkOU"

    Try{
        $OUS = Import-Csv -Path "$scriptPath\OU\CSV\OUstructuur.csv" -Delimiter ";"
        Write-Log -Msg "Het CSV betand $scriptPath\OU\CSV\OUstructuur.csv is ingelezen." -Level Info
    }
    catch{
        Write-Log -Msg "CSV bestand is niet beschikbaar" -Level Error
        Write-Log -Msg "Message: [$($_.Exception.Message)]" -Level Error
    }

    ForEach ($OU in $OUS){
        # Variable
        $ADDomain   = (Get-ADDomain).DistinguishedName
        $OUName     = $OU.Name
        $OUPath     = $($OU.path) 
        $OUDesc     = $OU.Description
        $OUExsist   = " "
        $OUExsist   = (Get-ADOrganizationalUnit -Filter 'Name -like $OUName').DistinguishedName 
        
        # Als OUpath leeg is wordt het path ADDomain
        if (!$OUPath){
            $OUFullPath = $ADDomain
            #Write-Log -Msg "In de CSV bestaat geen path dan is het path $OUFullPath" -Level Info
        }
        Else {
            # Als OUPath wel bestaat word de ADDomain toegevoegd 
            $OUFullPath = $OUPath + "," + $ADDomain
            #Write-Log -Msg "Het path is $OUFullPath" -Level Info
        }
        If ($OUExsist){
            $OUNameFullPath = "OU="+ $OUname + "," + $OUFullPath
            # Als de OU als bestaat wordt er gecontroleerd of hij het zelfde path heeft
            if($OUExsist -eq $OUNameFullPath ){
                Write-Log -Msg "$OUNameFullPath bestaat al." -Level Info
            }
            Else{
                Try{ 
                    # Heeft de OU een ander path heeft wordt die als nog aangemaakt. 
                    New-ADOrganizationalUnit -Name $OUName -Path "$OUFullPath" -Description $OUDesc 
                    Write-Log -Msg "$OUExsist bestaat al maar wordt ook aangemaakt onder $OUFullPath" -Level Warning
                }
                Catch{
                    Write-Log -Msg "$OUName kan niet aangemaakt worden." -Level Error
                    Write-Log -Msg "Message: [$($_.Exception.Message)]" -Level Error
                }
            }
        }
        Else{
            try {
                # Bestaat de OU helemaal niet dan wordt die aangemaakt.
                New-ADOrganizationalUnit -Name $OUName -Path "$OUFullPath" -Description $OUDesc       
                Write-Log -Msg "$OUName wordt aangemaakt onder $OUFullPath" -Level Info           
            }
            catch {
                Write-Log -Msg "$OUName kan niet aangemaakt worden." -Level Error         
                Write-Log -Msg "Message: [$($_.Exception.Message)]" -Level Error
            }
        }
    }
    stop-log    

}

Function CreateOU{
    param(

    )

    Start-Log -LogPath $LogFolder -LogName "CreateOU"

    try {
        # Bestaat de OU helemaal niet dan wordt die aangemaakt.
        New-ADOrganizationalUnit -Name $OUName -Path "$OUFullPath" -Description $OUDesc       
        Write-Log -Msg "$OUName wordt aangemaakt onder $OUFullPath" -Level Info           
    }
    catch {
        Write-Log -Msg "$OUName kan niet aangemaakt worden." -Level Error         
        Write-Log -Msg "Message: [$($_.Exception.Message)]" -Level Error
    }

    Stop-log
}

