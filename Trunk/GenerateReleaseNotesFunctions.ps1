$arrAssemblies = @(
    "Microsoft.TeamFoundation.Client",
    "Microsoft.TeamFoundation.Common",
    "Microsoft.TeamFoundation.Build.Client",
    "Microsoft.TeamFoundation.VersionControl.Client"
)
Foreach ($assembly in $arrAssemblies) {
    [void][Reflection.Assembly]::LoadWithPartialName($assembly)
}	
Remove-Variable assembly, arrAssemblies

Function Get-TFSCollectionURI {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, 
            Mandatory=$true)][String]$Server,
        [Parameter(Position=1, 
            Mandatory=$true)][String]$Collection,
        [Parameter(Position=2, 
            Mandatory=$false)][int]$Port,   
        [Parameter(Position=3, 
            Mandatory=$false)][String]$VirtualDir
        )
    Process {
        if (!$VirtualDir) {
            $VirtualDir = "TFS"
        }
        if (!$Port) {
            $Port = 8080
        }
        
        [Uri]$TFSCollectionURI = "http://" + $Server + ":" + $Port + "/" + $VirtualDir + "/" + $Collection
        $TFSCollectionURI
    }
}

Function Get-TFSTeamProjectCollection  {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, 
            ValueFromPipeline=$True, 
            Mandatory=$true)][alias("Uri")] [Uri]$TFSCollectionURI
    )
    Begin {
        $typ_TfsTeamProjectCollectionFactory = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]
    }
    Process {
        $typ_TfsTeamProjectCollectionFactory::GetTeamProjectCollection($TFSCollectionURI)
    }
}

Function Get-TFSService {
    [CmdletBinding(DefaultParameterSetName="BuildService")]
    Param(
    [Parameter(Position=0, 
        Mandatory=$true)][alias("TPC")][Microsoft.TeamFoundation.Client.TfsTeamProjectCollection]$TFSProjectCollection,
    [parameter(
        mandatory=$false,
        parametersetname="BuildService"
        )][Switch]$Build,     
    [parameter(
        mandatory=$false,
        parametersetname="VersionControlService"
        )][Switch]$VersionControl,
    [parameter(
        mandatory=$false,
        parametersetname="Linking"
        )][Switch]$LinkGenerator
    )
    Begin {
        $typ_VersionControlServer = [Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer]
        $typ_IBuildServer = [Microsoft.TeamFoundation.Build.Client.IBuildServer]
        $typ_ILinking = [Microsoft.TeamFoundation.ILinking]
        $psn = $PsCmdlet.ParameterSetName
    }
    Process {
        Switch ($psn) {
            "BuildService" {
                $Service = $TFSProjectCollection.GetService($typ_IBuildServer)
            }
            "VersionControlService" {
                $Service = $TFSProjectCollection.GetService($typ_VersionControlServer)
            }
            "Linking" {
                $Service = $TFSProjectCollection.GetService($typ_ILinking)
            }
        }
        $Service
    }
}

Function Get-TFSBuildController {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, 
            Mandatory=$true)][Microsoft.TeamFoundation.Build.Client.IBuildServer]$BuildService,
        [Parameter(Position=1, 
            Mandatory=$true)][String]$BuildControllerName
    )
    Process {
        $BuildService.GetBuildController($BuildControllerName)
    }
}

Function Get-TFSProjectBuildDefinitions {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, 
            Mandatory=$true)][Microsoft.TeamFoundation.Build.Client.IBuildServer]$BuildService,
        [Parameter(Position=1, 
            Mandatory=$true)][String]$TFSProject,
        [Parameter(Position=2, 
            Mandatory=$false)][String]$Filter
    )
    Process {
        if ($Filter) {
            $hshFilter = @{}
            $BuildDefs = @()
            $Filter.Split(",") | % {
                if (!$hshFilter.ContainsKey($_)) {
                    $hshFilter.Add($_,"")
                }
            }
            $BuildService.QueryBuildDefinitions($TFSProject) | % {
                if ($hshFilter.ContainsKey($_.Name)) {
                    $BuildDefs += $_
                }
            }
        } else {
            $BuildDefs = $BuildService.QueryBuildDefinitions($TFSProject)
        }
        $BuildDefs
    }
}

Function Get-TFSBuilds {
    [CmdletBinding(DefaultParameterSetName="BuildDef")]
    Param(
        [Parameter(Position=0,Mandatory=$true)][Microsoft.TeamFoundation.Build.Client.IBuildServer]$BuildService,
        [Parameter(Position=1,ParameterSetName='BuildDef')]
        [Parameter(Position=99,ParameterSetName='BuildUri')]
            [Array]$BuildDefinitions,
        [Parameter(Position=1,ParameterSetName='BuildUri')][Uri]$BuildURI,
        [Parameter(Position=2,Mandatory=$false)][Int]$MaxBuildsPerDefinition = 1,
        [Parameter(Position=3,Mandatory=$false)][DateTime]$MinFinishTime = ([DateTime]::Now.AddDays(-1))
    )
    Begin {
        $typ_QueryOptions       = [Microsoft.TeamFoundation.Build.Client.QueryOptions]
        $typ_BuildStatus        = [Microsoft.TeamFoundation.Build.Client.BuildStatus]
        $typ_BuildQueryOrder    = [Microsoft.TeamFoundation.Build.Client.BuildQueryOrder]
        $psn = $PsCmdlet.ParameterSetName
    }
    Process {
        Switch ($psn) {
            "BuildDef" {
                $BuildDefURIs = [Activator]::CreateInstance([Collections.Generic.List[Uri]])
                $BuildDefinitions | % { $BuildDefURIs.Add([Uri]$_.Uri)  }
                $spec = $BuildService.CreateBuildDetailSpec($BuildDefURIs)
                $spec.InformationTypes = $null
                $spec.MaxBuildsPerDefinition = $MaxBuildsPerDefinition
                $spec.Status = (($typ_BuildStatus::InProgress).value__ + ($typ_BuildStatus::Succeeded).value__)
                $spec.QueryOrder = $typ_BuildQueryOrder::FinishTimeDescending
                $spec.MinFinishTime = $MinFinishTime
                $spec.QueryOptions = (($typ_QueryOptions::Definitions).value__ + ($typ_QueryOptions::Controllers).value__)
                $rtn = $BuildService.QueryBuilds($spec).Builds
            }
            "BuildUri" {
                $rtn = $BuildService.QueryBuildsByUri($BuildURI,"*",($typ_QueryOptions::Definitions).value__)                
            }
        }
        $rtn
    }
}

Function Get-TFSBuildConfigSummary {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, 
            ValueFromPipeline=$True,
            Mandatory=$true)][Object]$BuildDetail
    )
    Begin {
        $typ_InformationNodeConverters = [Microsoft.TeamFoundation.Build.Client.InformationNodeConverters]
    }
    Process {
        $BuildCfgs = @()
        $typ_InformationNodeConverters::GetConfigurationSummaries($BuildDetail) | % {
            $objCfgSum = "" | Select Flavour, Platform, TotalCompilationWarnings, TotalCompilationErrors
            $objCfgSum.Flavour					= $_.Flavor.ToString()
            $objCfgSum.Platform					= $_.Platform.ToString()
            $objCfgSum.TotalCompilationWarnings	= $_.TotalCompilationWarnings.ToString()
            $objCfgSum.TotalCompilationErrors	= $_.TotalCompilationErrors.ToString()
            $BuildCfgs += $objCfgSum
        }
        $BuildCfgs
    }
}

Function Get-TFSBuildChangesets {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, 
            ValueFromPipeline=$True,
            Mandatory=$true)][alias("VCS")][Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer]$VersionControlService,
        [Parameter(Position=1, 
            ValueFromPipeline=$True,
            Mandatory=$true)][alias("LG")]$LinkingService,
        [Parameter(Position=2, 
            ValueFromPipeline=$True,
            Mandatory=$true)][Object]$BuildInfo,
        [Parameter(Position=3, 
            Mandatory=$false)][alias("Exclude")][String]$AccountExcludeList,
        [Parameter(Position=4, 
            Mandatory=$false)][alias("ExcludeWI")][String]$WorkItemExcludeList
    )
    Begin {
        $typ_InformationNodeConverters  = [Microsoft.TeamFoundation.Build.Client.InformationNodeConverters]
        $typ_CultureInfo                = [System.Globalization.CultureInfo]
        $hshExclude = @{}
        $arrChangesets = @()
        $WorkItemExcludeHash = @{}
        
        if ($AccountExcludeList) {
            $AccountExcludeList.Split(",") | % {
                if (!$hshExclude.ContainsKey($_)) {
                    $hshExclude.Add($_,"")
                }
            }
        }
        If ($WorkItemExcludeList) {
            $WorkItemExcludeList.split(",")  | % {
                if (!$WorkItemExcludeHash.ContainsKey($_)) {
                    $WorkItemExcludeHash.Add($_,"")
            }
        }
    }
    }
    Process {
        $arrUnassignedChangesets = @()
        $RtnHash = @{}
        $hshWorkItems = @{}
        $typ_InformationNodeConverters::GetAssociatedChangesets($BuildInfo) | % {
            if (!$hshExclude.ContainsKey($_.CheckedInBy)) {
                $ChangesetDetail = $VersionControlService.GetChangeset($_.ChangesetId)
                if ($ChangesetDetail.WorkItems.Count -eq 0) {
                    $Changeset = "" | Select ID, Uri, Url, CommittedBy, CommittedOn, Comment
                    
                    $Changeset.ID			= $ChangesetDetail.ChangesetId.ToString($typ_CultureInfo::InvariantCulture)
                    $Changeset.Uri			= $ChangesetDetail.ArtifactUri.ToString()
                    $Changeset.Url			= $LinkingService.GetArtifactUrl($ChangesetDetail.ArtifactUri.AbsoluteUri)
                    $Changeset.CommittedBy	= $ChangesetDetail.Owner
                    $Changeset.CommittedOn	= $ChangesetDetail.CreationDate.ToString($typ_CultureInfo::InvariantCulture)
                    $Changeset.Comment		= $ChangesetDetail.Comment

                    $arrUnassignedChangesets += $Changeset
                } else {
                    $ChangesetDetail.WorkItems | % { 
                        if (!$hshWorkItems.ContainsKey($_.ID)) {
                            if (!$WorkItemExcludeHash.ContainsKey($_.Type.Name)) {
                                $WorkItem = "" | Select ID, Type, Uri, Url, Title, CreatedBy
                                $WorkItem.ID        = $_.ID
                                $WorkItem.Type      = $_.Type.Name
                                $WorkItem.Uri       = $_.Uri
                                $WorkItem.Url       = $LinkingService.GetArtifactUrl($_.Uri.AbsoluteUri)
                                $WorkItem.Title     = $_.Title
                                $WorkItem.CreatedBy = $_.CreatedBy
                                $hshWorkItems.Add($_.ID,$WorkItem)
                            }
                        }
                    }
                }
            }
        }
        $arrUnassignedChangesets = $arrUnassignedChangesets | Sort -Property ID
        $RtnHash.Add("UnassignedChangesets",$arrUnassignedChangesets)
        $arrWI = @() 
        $hshWorkItems.Keys | % {
            $arrWI += $hshWorkItems[$_]
        }
        $arrWI = $arrWI | sort -Property ID
        $RtnHash.Add("WorkItems",$arrWI)
        $RtnHash
    }
}

Function Get-TFSBuildAgent {
    # Only works if build is currently running 
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, 
            Mandatory=$true)][Array]$BuildAgents,
        [Parameter(Position=1, 
            Mandatory=$true)][Uri]$BuildUri
    )
    Process {
        $AgentName = ""
        $i = 0
        $found = $false
        do {
            if ([Uri]::Equals($BuildAgents[$i].ReservedForBuild, $BuildUri)){
                $AgentName = $BuildAgents[$i].MachineName
                    $found = $true
            }
            $i++
        } until (($found) -or ($i -eq $BuildAgents.Count))
        $AgentName
    }
}

Function Get-TFSBuildDetails {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, 
            ValueFromPipeline=$True,
            Mandatory=$true)][Object]$Build,
        [Parameter(Position=1, 
            Mandatory=$true)][Microsoft.TeamFoundation.Build.Client.IBuildServer]$BuildService,
        [Parameter(Position=2, 
            Mandatory=$true)][Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer]$VersionControlService,
        [Parameter(Position=3, 
            Mandatory=$true)]$LinkingService,
        [Parameter(Position=4, 
            Mandatory=$false)][String]$AccountExcludeList,
        [Parameter(Position=5, 
            Mandatory=$false)][String]$WorkItemExcludeList
            
    )
    Process {
        $objBuild = "" | Select BuildDef, BuildController, BuildAgent, BuildNumber, 
            BuildQuality, BuildTeamProject, BuildStartTime, BuildEndTime, BuildRunTime,
            BuildReason, BuildLogLocation, BuildDropLocation, BuildLastChangeOn, 
            BuildLastChangeBy, BuildLabelName, BuildSrcVersion,
            BuildRequestedBy, BuildRequestedFor, ConfigSummary, Changes
        
        $BuildDetail = $BuildService.GetBuild($Build.Uri)
        
        $objBuild.BuildDef 			= $BuildDetail.BuildDefinition.Name
        $objBuild.BuildController	= $BuildDetail.BuildController.Name.ToString()
        $objBuild.BuildAgent        = Get-TFSBuildAgent $BuildDetail.BuildController.Agents $BuildDetail.Uri
        $objBuild.BuildNumber		= $BuildDetail.BuildNumber.ToString()
        $objBuild.BuildQuality		= $BuildDetail.Quality
        $objBuild.BuildTeamProject	= $BuildDetail.TeamProject.ToString()
        $objBuild.BuildStartTime	= $BuildDetail.StartTime.ToString("yyyy-MM-dd HH:mm:ss")
        $objBuild.BuildEndTime		= $BuildDetail.FinishTime.ToString("yyyy-MM-dd HH:mm:ss")
        if ($objBuild.BuildEndTime -eq "0001-01-01 00:00:00") { # If build is still running use NOW() as should be close enough to the end of the build
            [DateTime]$tmpTime          = [DateTime]::Now
            $objBuild.BuildEndTime		= $tmpTime.ToString("yyyy-MM-dd HH:mm:ss")
            $objBuild.BuildRunTime		= [int]($tmpTime - $BuildDetail.StartTime).TotalMinutes
        } else {
            $objBuild.BuildRunTime		= [int]($BuildDetail.FinishTime - $BuildDetail.StartTime).TotalMinutes
        }
        $objBuild.BuildReason		= $BuildDetail.Reason.ToString()
        $objBuild.BuildDropLocation	= $BuildDetail.DropLocation.ToString()
        $objBuild.BuildLogLocation	= $BuildDetail.LogLocation
        $objBuild.BuildLastChangeOn	= $BuildDetail.LastChangedOn.ToString("yyyy-MM-dd HH:mm:ss")
        $objBuild.BuildLastChangeBy	= $BuildDetail.LastChangedBy.ToString()
        $objBuild.BuildLabelName	= $BuildDetail.LabelName.ToString()
        $objBuild.BuildSrcVersion 	= $BuildDetail.SourceGetVersion.ToString()
        $objBuild.BuildRequestedBy	= $BuildDetail.RequestedBy.ToString()
        $objBuild.BuildRequestedFor	= $BuildDetail.RequestedFor.ToString()
        $objBuild.ConfigSummary     = Get-TFSBuildConfigSummary $BuildDetail
        if ($AccountExcludeList) {
            $objBuild.Changes    = Get-TFSBuildChangesets -VersionControlService $VersionControlService -LinkingService $LinkingService -BuildInfo $BuildDetail.Information -AccountExcludeList $AccountExcludeList -WorkItemExcludeList $WorkItemExcludeList
        } else {
            $objBuild.Changes    = Get-TFSBuildChangesets -VersionControlService $VersionControlService -LinkingService $LinkingService -BuildInfo $BuildDetail.Information -WorkItemExcludeList $WorkItemExcludeList
        }
        $objBuild
    }
}

Function Get-HtmlSafe {
    [CmdletBinding()]
    Param (
        [Parameter(Position=0, 
            ValueFromPipeline=$True,
            Mandatory=$true)][String]$comment
    )
    Process {
        $comment = $comment.Replace("&","&amp;")
        $comment = $comment.Replace("<","&lt;")
        $comment = $comment.Replace(">","&gt;")
        $comment
    }
}

Function Import-XMLReleaseNotes {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, 
            ValueFromPipeline=$True,
            Mandatory=$true)][String]$XML,
        [Parameter(Position=1, 
            Mandatory=$true)][String]$AdditionalNotes,
        [Parameter(Position=2, 
            Mandatory=$true)][Microsoft.TeamFoundation.Build.Client.IBuildServer]$BuildService
        
    )
    Process {
        $XMLDoc = [Xml]$XML    
        
        ## Get hash tables to save time ##
        $hshProj = @{}
        $emptyhsh = @{}
        $XMLDoc.Releasenotes.Projects.Project | % { 
            if ($hshProj.ContainsKey($_.Name)) { # if proj already exists
                $cproj = $_.Name
                $_.Definitions.Definition | % {
                    if ($hshProj[$cproj].ContainsKey($_.Name)) { # If the def already exists in this proj
                        $cdef = $_.Name
                        $_.Builds.Build | % {
                            if (!$hshProj[$cproj][$cdef].ContainsKey($_.Number)) {
                                $hshProj[$cproj][$cdef].Add($_.Number,$null)
                            }
                        }
                    } else {
                        $hshProj[$cproj].Add($_.Name,$emptyhsh)
                    }
                }
            } else {
                $hshProj.Add($_.Name,$emptyhsh)
            }
         }
        
        $arrAddNotes = $AdditionalNotes.split(";")
        foreach ($proj in $arrAddNotes) {
            $arrDefs = $proj.split(",")
            foreach ($Def in $arrDefs[1 .. ($arrDefs.Count-1)]) {
                $BuildDef = Get-TFSProjectBuildDefinitions -BuildService $BuildService -TFSProject $arrDefs[0] -Filter $Def
                $Build = Get-TFSBuilds -BuildService $BuildService -BuildURI $BuildDef.LastGoodBuildUri
                [xml]$RNTemp = get-content ($Build.DropLocation + "`\" + $AdditionalNotesFileName) -Encoding UTF8
                
                $RNTemp.ReleaseNotes.Projects.Project | % { # iterate over imported releasenotes
                    if ($hshProj.ContainsKey($_.Name)) { # if project is in hshtable
                        $pnode = $_
                        $pnodename = $pnode.Name
                        $_.Definitions.Definition | % {
                            if ($hshProj[$pnode.Name].ContainsKey($_.Name)) { # if definition is in hshtable
                                $dnode = $_
                                $dnodename = $dnode.Name
                                $_.Builds.Build | % {
                                    if (!$hshProj[$pnode.Name][$dnode.Name].ContainsKey($_.Name)) { # if buildnumber is *not* in hshtable
                                        $destNode = $XMLDoc.SelectSingleNode("/Releasenotes/Projects/Project[@Name='$pnodename']/Definitions/Definition[@Name='$dnodename']/Builds")
                                        $destNode.AppendChild($XMLDoc.ImportNode($_,$true)) | Out-Null
                                        $hshProj[$pnode.Name][$dnode.Name].Add($_.Name,$emptyhsh)
                                    }
                                }
                            } else { ###### ADD Def Node under Proj ######
                                $destNode = $XMLDoc.SelectSingleNode("/Releasenotes/Projects/Project[@Name='$pnodename']/Definitions")
                                $destNode.AppendChild($XMLDoc.ImportNode($_,$true)) | Out-Null
                                $hshProj[$pnode.Name].Add($_.Name,$emptyhsh)
                            }
                        }
                    } else {
                        ## Add Proj ##
                        $XMLDoc.Releasenotes.Projects.AppendChild($XMLDoc.ImportNode($_,$true)) | Out-Null
                        $hshProj.Add($_.Name,$emptyhsh)
                    }
                }
            }
        }
        [Xml]$XMLDoc
    }
} 

Function Generate-TFSBuildXML {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, 
            ValueFromPipeline=$True,
            Mandatory=$true)][Object]$Document
    )
    Begin {
        $XMLHeader  = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?>`r`n"
        $XMLHeader += "<?xml-stylesheet type=`"text/xsl`" href=`"ReleaseNotes.xsl`"?>`r`n"
        $XMLRoot = "<Releasenotes>`r`n"
        $XMLRootClose = "</Releasenotes>"
        $XMLBody = ""
    }
    Process {
        $XMLBody += " <Title>" + $Document.NotesTitle + "</Title>`r`n"
        $XMLBody += " <Createdby>" + $Document.NotesCreatedBy + "</Createdby>`r`n"
        $XMLBody += " <Createdon>" + $Document.NotesCreatedOn + "</Createdon>`r`n"
        $XMLBody += " <Projects>`r`n"

        foreach ($pkey in $Document.Projects.Keys) {
            $XMLBody += "  <Project Name=`"$pkey`">`r`n"
            $XMLBody += "   <Definitions>`r`n"
            foreach ($dkey in $Document.Projects[$pkey].Keys) {
                $XMLBody += "   <Definition Name=`"$dkey`">`r`n"
                $XMLBody += "    <Builds>`r`n"
                $Document.Projects[$pkey][$dkey] | % {
                    $XMLBody += "     <Build Number=`"" + $_.BuildNumber + "`">`r`n"
                    $XMLBody += "      <Quality>"       + $_.BuildQuality       + "</Quality>`r`n"
                    $XMLBody += "      <Agent>"         + $_.BuildAgent         + "</Agent>`r`n"
                    $XMLBody += "      <Starttime>"     + $_.BuildStartTime     + "</Starttime>`r`n"
                    $XMLBody += "      <Endtime>"       + $_.BuildEndTime       + "</Endtime>`r`n"
                    $XMLBody += "      <Runtime>"       + $_.BuildRunTime       + "</Runtime>`r`n"
                    $XMLBody += "      <Reason>"        + $_.BuildReason        + "</Reason>`r`n"
                    $XMLBody += "      <Log>"           + $_.BuildLogLocation   + "</Log>`r`n"
                    $XMLBody += "      <Drop>"          + $_.BuildDropLocation  + "</Drop>`r`n"
                    $XMLBody += "      <Lastchangeon>"  + $_.BuildLastChangeOn  + "</Lastchangeon>`r`n"
                    $XMLBody += "      <Lastchangeby>"  + $_.BuildLastChangeBy  + "</Lastchangeby>`r`n"
                    $XMLBody += "      <Sourceversion>" + $_.BuildSrcVersion    + "</Sourceversion>`r`n"
                    $XMLBody += "      <Requestedby>"   + $_.BuildRequestedBy   + "</Requestedby>`r`n"
                    $XMLBody += "      <Requestedfor>"  + $_.BuildRequestedFor  + "</Requestedfor>`r`n"
                    $XMLBody += "      <Configurations>`r`n"
                    $_.ConfigSummary | % {
                        $XMLBody += "       <Configuration>`r`n"
                            $XMLBody += "      <Flavour>"               + $_.Flavour                    + "</Flavour>`r`n"
                            $XMLBody += "      <Platform>"              + $_.Platform                   + "</Platform>`r`n"
                            $XMLBody += "      <CompilationWarnings>"   + $_.TotalCompilationWarnings   + "</CompilationWarnings>`r`n"
                            $XMLBody += "      <CompilationErrors>"     + $_.TotalCompilationErrors     + "</CompilationErrors>`r`n"
                        $XMLBody += "       </Configuration>`r`n"
                    }
                    $XMLBody += "      </Configurations>`r`n"
                    $XMLBody += "      <Workitems>`r`n"
                    $_.Changes["WorkItems"] | % {
                        $XMLBody += "       <Workitem>`r`n"
                        $XMLBody += "        <ID>"          + $_.ID         + "</ID>`r`n"
                        $XMLBody += "        <Type>"        + $_.Type       + "</Type>`r`n"
                        $XMLBody += "        <Uri>"         + $_.Uri        + "</Uri>`r`n"
                        $XMLBody += "        <Url>"         + $_.Url        + "</Url>`r`n"
                        if ($_.Title) { $_.Title = $_.Title.Replace("&","&amp;") } 
                        $XMLBody += "        <Title>"       + $_.Title      + "</Title>`r`n"
                        $XMLBody += "        <Createdby>"   + $_.CreatedBy  + "</Createdby>`r`n"
                        $XMLBody += "       </Workitem>`r`n"
                    }
                    $XMLBody += "      </Workitems>`r`n"
                    
                    $XMLBody += "      <UnassignedChangesets>`r`n"
                    $_.Changes["UnassignedChangesets"] | % {
                        $XMLBody += "       <Changeset>`r`n"
                        $XMLBody += "        <ID>"          + $_.ID             + "</ID>`r`n"
                        $XMLBody += "        <Uri>"         + $_.Uri            + "</Uri>`r`n"
                        $XMLBody += "        <Url>"         + $_.Url            + "</Url>`r`n"
                        $XMLBody += "        <Committedby>" + $_.CommittedBy    + "</Committedby>`r`n"
                        $XMLBody += "        <Committedon>" + $_.CommittedOn    + "</Committedon>`r`n"
                        if ($_.Comment) { $_.Comment = Get-HtmlSafe $_.Comment } 
                        $XMLBody += "        <Comment>"     +   $_.Comment  + "</Comment>`r`n"
                        $XMLBody += "        <Files>`r`n"
                        $_.Changes | % {
                        $XMLBody += "         <File Name=`"$_`" />`r`n"
                        }
                        $XMLBody += "        </Files>`r`n"
                        $XMLBody += "       </Changeset>`r`n"
                    }
                    $XMLBody += "      </UnassignedChangesets>`r`n"
                    $XMLBody += "     </Build>`r`n"
                }
                $XMLBody += "    </Builds>`r`n"
                $XMLBody += "   </Definition>`r`n"
            }
            $XMLBody += "   </Definitions>`r`n"
            $XMLBody += "  </Project>`r`n"
        }
        $XMLBody += " </Projects>`r`n"

        $xmldoc =  $XMLHeader
        $xmldoc += $XMLRoot
        $xmldoc += $XMLBody
        $xmldoc += $XMLRootClose
        $xmldoc
    }
}