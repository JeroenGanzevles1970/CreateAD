<#
.SYNOPSIS
  Macrobestand voor het maken van Log bestanden.
  
.DESCRIPTION
  Dit macrobestand bevat functies voor het schrijven van log bestanden.
  
.AUTHOR
  Ben I. Carolus
  
.DATE
  17-07-2017
  
.VERSION
  0.2
#>

#
# Houd de lijst met log files bij.
#
[System.Collections.ArrayList]$Script:Entries = @()

#
# Geeft de tijd in een bepaald formaat weer
#
Function TimeStamp() {
  
  Get-Date -UFormat "%H:%M"
  
} # TimeStamp

#
# Geeft een unique key terug gebaseerd op de tijd
#
Function Get-Key(){
  
  Get-Date -Format "HHmmssfff"
  
} # Get-Key

<#
.SYNOPSIS
  Maakt een log file.
  
.DESCRIPTION
  Deze functie maakt een log file op een bepaalde locatie met een bepaalde naam.
  De naam bevat ook de datum en de tijd in de bestandsnaam.
  
.PARAMETER LogPath
  De locatie waar de logfile geschreven moet worden. 
  De standaardlocatie is $PSScriptRoot (locatie van het opstart script)
  
.PARAMETER LogName
  De naam va de logfile.
  De standaardnaam is Log.
  
.OUTPUT LogID
  Een unique ID die gebruikt kan worden om onderscheidt te kunnen maken tussen
  verschillende logbestanden vanuit één programma.
  
.EXAMPLE
  Start-Log
    Er wordt een standaard logbestand gemaakt in de standaardlocatie.
  
  Start-Log -LogPath "C:\Log\LogFile.txt" -LogName "Main"
    Het logbestand "Main" wordt geschreven in locatie "C:\Log\LogFile.txt"
  
  $LCID = Start-Log -LogPath "C:\Log" -LogName "Child"
    Het logbestand "Child" wordt geschreven in locatie "C:\Log".
    De LCID kan gebruikt worden naar een specifieke logbestand te schrijven.
  
#>
Function Start-Log() {
  
  [CmdletBinding()]
  Param ( 
    [Parameter(Mandatory = $false)] 
    [string]$LogPath = $PSScriptRoot, 
    
    [Parameter(Mandatory = $false)] 
    [string]$LogName = "Log"
  )
  
  #$TimeStamp = TimeStamp
  #$LogFile = $LogPath + "\" + $LogName + "-" + $TimeStamp + ".log"
  $LogFile = $LogPath + "\" + $LogName + ".log"
  
  # 
  # Test of LogName al voorkomt
  #
  If($Script:Entries | Where-Object {$_.LogName -eq $LogName}){
    Write-Host ("Log naam: {0} bestaat al." -f $LogName) -ForegroundColor Red
    Exit 0
  }
  Else{
    
    $LogEntry = @{} | Select-Object LogID, LogName, LogFile
    
    $LogEntry.LogID = Get-Key
    $LogEntry.LogName = $LogName
    $LogEntry.LogFile = $LogFile
    
    $Script:Entries += $LogEntry
    
    Write-Log -LogID $LogEntry.LogID -Msg ("Logging started for {0}, writing to {1}" -f $LogName, $LogFile)
    Write-Log -LogID $LogEntry.LogID -Msg "-------------------------------------------------------------------------------"
    
  }
  
} # Start-Log

<#
.SYNOPSIS
  Sluit een logbestand

.DESCRIPTION
  Deze functie schrijft de laatste meldingen naar het logbestand en verwijderd de lognaam uit de lijst.
  
.PARAMETER LogID
  De ID van het logbestand die gesloten moet worden.
  
.EXAMPLE
  Stop-Log
    Sluit het eerste logbestand
    
  Stop-Log -LogID $LCID
    Sluit logbestand met LogID $LCID
#>
Function Stop-Log() {
  
[CmdletBinding()] 
  Param ( 
    [Parameter(Mandatory = $false)] 
    [Int]$LogID = $Script:Entries[0].LogID
  ) 
  
  $LogName = ($Script:Entries | Where-Object {$_.LogID -eq $LogID}).LogName
  
  Write-Log -LogID $LogID -Msg "-------------------------------------------------------------------------------"
  Write-Log -LogID $LogID -Msg ("Logging ended for {0}" -f $LogName)
  Write-Log -LogID $LogID -Msg "   " 

  
  $Script:Entries.Remove(($Script:Entries | Where-Object {$_.LogID -eq $LogID}))
  
} # Stop-Log

<#
.SYNOPSIS
  Schrijf een melding.
  
.DESCRIPTION
  Schrijft een melding naar zowel het scherm als het logbestand.
  
.PARAMETER LogID
  LogID van het logbestand dat geschreven moet worden.
  
.PARAMETER Msg
  Het bericht dat geschreven moet worden.
  
.PARAMETER Level
  Het type bericht dat geschreven wordt.
    Error     Error    Rood op het scherm
    Warning   Warning  Geel op het scherm
    Info      Info     Groen op het scherm

.EXAMPLE
  Write-Log
    Schrijft een lege regel naar het scherm en naar het eerste logbestand van het type Info
  Write-Log -Msg "Bericht"
    Schrijft een bericht naar het scherm en naar het eerste logbestand van het type Info
  Write-Log -LogID $LCID -Msg "Bericht" -Level Error
    Schrijft een bericht naar het scherm en naar logbestand met LogID=$LCID van het type Error
  
#>
Function Write-Log() {
  
  [CmdletBinding()] 
  Param 
  (
    [Parameter(Mandatory = $false)]
    [Int]$LogID = $Script:Entries[0].LogID,
    
[Parameter(Mandatory = $false)]
    [string]$Msg,
    
    [Parameter(Mandatory = $false)] 
    [ValidateSet("Error","Warning","Info","Header")] 
    [string]$Level = "Info"
)
  
  $Entry = $Script:Entries | Where-Object {$_.LogID -eq $LogID}
  $LogFileName = [String]$Entry.LogFile
  $LogName = [String]$Entry.LogName
  
  If($LogFileName.Length -gt 0){
    
    $LogText = TimeStamp
    $LogText = ("{0} {1,-15}{2}" -f $LogText, $Level, $Msg)
    
    $LogText | Out-File $LogFileName -append
    switch ($Level) {
      "ERROR"    { $TextColor = 'red'}
      "WARNING"  { $TextColor = 'yellow'}
      "INFO"     { $TextColor = 'green'}
      "HEADER"   { $TextColor = 'white'}
    }
    write-host ("{0} {1}" -f $LogName, $Msg) -ForegroundColor $TextColor
  }
  
} # Write-Log

# Publiceer de functies in deze Module
#
Export-ModuleMember -function Start-Log
Export-ModuleMember -function Stop-Log
Export-ModuleMember -function Write-Log 
