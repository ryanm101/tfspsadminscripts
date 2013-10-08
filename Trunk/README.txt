All scripts use Powershell v2

TFSAdminFunctions - Functions to control TFS from the command prompt (dot source this in your profile)

GenerateReleaseNotes* - Will generate Release notes for a build - Requires: SkipGetChangesetsAndUpdateWorkItems="False" and SkipWorkItemCreation="False" to be set for the build. Call ./GenerateReleaseNotes.ps1

ExecPowershell.bat - Used to run a powershell script from within another script.