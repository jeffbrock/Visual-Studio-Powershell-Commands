# Visual-Studio-Powershell-Commands

Write-3rdPartyDlls ($ProjectBasePath, $ExcludeLike)
 - writes all nuget and direct project references for all csproj files in a directory
 - optionally can exlcude references containing specified string

Write-ProjectReferenceReport ($SolutionBasePath)
 - writes all solutions in the specified base path, 
 - writes project references for solutions with deleted/not-found projects
 - writes project references for projects in a solution referenceing projects that are not included in the solution
