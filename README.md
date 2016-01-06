# tfspsadminscripts

All scripts use Powershell v2

TFSAdminFunctions - Functions to control TFS from the command prompt (dot source this in your profile)

GenerateReleaseNotes* - Will generate Release notes for a build - Requires: SkipGetChangesetsAndUpdateWorkItems="False" and SkipWorkItemCreation="False" to be set for the build. Call ./GenerateReleaseNotes.ps1

ExecPowershell.bat - Used to run a powershell script from within another script.

Scripts to administer TFS 2010/2012.

Note: Merge-TFSMergeCandidates is not fully implemented yet and should only preview the changes.

Current Functions:
* Get-TFSCollectionURI
* Get-TFSCollection
* Get-TFSService
* Get-TFSProjects
* Get-TFSBuildsInProgress
* Queue-TFSBuild
* Get-TFSWorkspace
* Get-TFSPendingChanges
* Undo-TFSPendingChange
* Get-TFSMergeCandidates
* Merge-TFSMergeCandidates

http://ninet.org
