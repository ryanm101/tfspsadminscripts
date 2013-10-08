<#
.SYNOPSIS
  Generate Relasenotes for Current/Last Build
  
.DESCRIPTION
  If called as part of a build script will generate the release notes containing all the checkins / workitems for that build.
  If called manually then will generate the release notes for either the last build of the definition specified or if there is a 
  build in progress for the definition then for that build.
  
.NOTES
  Author: Ryan McLean
  Copyright 2013
  Website: http://ninet.org
  
.PARAMETER Project
  Mandatory: Name of the project to look in for the build definition
.PARAMETER Definition
  Mandatory: Name of the Build Definition to get
.PARAMETER TFSServer
  Mandatory: Name of the TFS server
.PARAMETER TFSCollection
  Optional: Name of the TFS Collection to look in.
  Default:  DefaultCollection
.PARAMETER TFSServerPort
  Optional: Port TFS Server listens on.
  Default:  8080
.PARAMETER outfile
  Optional: Name of file to output to
  Default:  ReleaseNotes.xml
.PARAMETER LastNumDays
  Optional: Number of days to look back over for builds  
  Default:  7
.PARAMETER MaxBuildsPerDef
  Optional: Maximum number of builds to return
  Default:  1
.PARAMETER ExcludeAccounts
  Optional: If build runs as a service account then specify the account(s) here and any checkins made by it will be ignored.
  Default:  ""
  
.EXAMPLE
  PS> ./GenerateReleaseNotes.ps1 -Project proj1 -Definition Proj1Release -TFSServer tfs1.example.com
  
.EXAMPLE
  PS> ./GenerateReleaseNotes.ps1 -Project proj1 -Definition Proj1Release -TFSServer tfs1.example.com -Collection Col1 -ExcludeAccounts Domain\Build1
  
.EXAMPLE
  PS> ./GenerateReleaseNotes.ps1 -Project proj1 -Definition Proj1Release -TFSServer tfs1.example.com -Collection Col1 -ExcludeAccounts Domain\Build1,Domain\Build2
#>
Param (
    [CmdletBinding()]
    [Parameter(Position=0, 
        ValueFromPipeline=$True,
		Mandatory=$true)][alias("proj")][String]$Project,
    [Parameter(Position=1,
		Mandatory=$true)][alias("def")][String]$Definition,
    [Parameter(Position=2,
		Mandatory=$true)][alias("srv")][String]$TFSServer,
    [Parameter(Position=3,
		Mandatory=$false)][alias("TPC")][String]$TFSCollection = "DefaultCollection",
    [Parameter(Position=4,
		Mandatory=$false)][alias("Port")][int]$TFSServerPort = 8080,
    [Parameter(Position=5,
		Mandatory=$false)][alias("of")][String]$outfile = "ReleaseNotes.xml",
    [Parameter(Position=6,
		Mandatory=$false)][alias("LD")][int]$LastNumDays = 7,
    [Parameter(Position=7,
		Mandatory=$false)][alias("MBD")][int]$MaxBuildsPerDef = 1,
    [Parameter(Position=8,
		Mandatory=$false)][alias("ServiceAccounts")][String]$ExcludeAccounts = ""
)
Begin {
    clear
    $thisScript = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    . ($thisScript + '.\GenerateReleaseNotesFunctions.ps1')
    
    $TFS = "" | Select Server, Port, Collection, BuildAccounts, BuildService, LinkGen, VCServer, URI, TPC

	$TFS.Server = $TFSServer
	$TFS.Port = $TFSServerPort
	$TFS.Collection = $TFSCollection
	$TFS.BuildAccounts = $ExcludeAccounts

    $LookBackDate = [DateTime]::Now.AddDays(-$LastNumDays)

    $arrBuildtails = @()
    $Doc = "" | Select NotesTitle, NotesCreatedOn, NotesCreatedBy, Projects
    $Doc.NotesCreatedOn	= [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
    $Doc.NotesCreatedBy	= "$env:userdomain\$env:username"
    $Doc.Projects = @()
}
Process {
    $TFS.URI            = Get-TFSCollectionURI -Server $TFS.Server -Port $TFS.Port -Collection $TFS.Collection
    $TFS.TPC            = Get-TFSTeamProjectCollection -TFSCollectionURI $TFS.URI
    $TFS.BuildService   = Get-TFSService -TFSProjectCollection $TFS.TPC -Build
    $TFS.VCServer       = Get-TFSService -TFSProjectCollection $TFS.TPC -VersionControl
    $TFS.LinkGen        = Get-TFSService -TFSProjectCollection $TFS.TPC -LinkGenerator
    
    $BuildDefs = Get-TFSProjectBuildDefinitions -BuildService $TFS.BuildService -TFSProject $Project -Filter $Definition

    $hshProjects = @{}
    $hshDefBuilds = @{}
    $BuildDefs | sort -Property Name -Descending | % {
        $Builds = @()
        $Def = $_
        Get-TFSBuilds -BuildService $TFS.BuildService -BuildDefinitions $Def -MaxBuildsPerDefinition $MaxBuildsPerDef -MinFinishTime $LookBackDate | % {
            $Builds += Get-TFSBuildDetails -Build $_ -BuildService $TFS.BuildService -LinkingService $TFS.LinkGen -VersionControlService $TFS.VCServer -AccountExcludeList $TFS.BuildAccounts
        }
        $hshDefBuilds.Add($Def.Name,$Builds)
    }
    
    $hshProjects.Add($Project,$hshDefBuilds)
    
    $Doc.Projects = $hshProjects
    
    if ($Doc.Projects) {
        $Doc.NotesTitle = $hshProjects[$Project][$Definition][0].BuildNumber
        $Doc | Generate-TFSBuildXML |Out-File -Encoding "UTF8" $outfile
    }       
}
