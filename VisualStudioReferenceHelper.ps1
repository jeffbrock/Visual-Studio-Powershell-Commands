# writes all nuget and direct project references for all csproj files in a directory
# optionally can exlcude references containing specified string
function Write-3rdPartyDlls ($ProjectBasePath, $ExcludeLike) {  
    Get-AllProjs $ProjectBasePath | 
    ForEach-Object {         
		$refs = Get-3rdPartyDllsForProject ($_ ) $ExcludeLike
		if ($refs) {
			Write-Host ($_)  -ForegroundColor "yellow" 
			$refs |
            ForEach-Object {
                Write-Host $_
            }
		}
	}
}

# writes all solutions in the specified base path, 
# writes project references for solutions with deleted/not-found projects
# writes project references for projects in a solution referenceing 
# projects that are not included in the solution
function Write-ProjectReferenceReport ($SolutionBasePath) {
    $slns = Get-AllSlns $SolutionBasePath
    Write-Host All solutions: $slns.Count -ForegroundColor "yellow"
    $slns | ForEach-Object { $_.FullName }
    Write-Host 
    Write-Host 
    Write-Host Solutions referencing deleted/not-found projects -ForegroundColor "yellow"
    $slns | 
    ForEach-Object { 
        Write-Host ($_.FullName)
        Write-Host (MissingProjectRefNamesFromSln $_.FullName).MissingProjects -ForegroundColor "red"
    } 
    Write-Host 
    Write-Host 
    Write-Host Solutions with projects referencing other projects not included in the solution -ForegroundColor "yellow"
    $slns | 
    ForEach-Object { 
        Write-Host ($_.FullName)
        (MissingProjectRefNamesFromSln $_.FullName).MissingReferencedProjects |
            ForEach-Object { 
                Write-Host $_ -ForegroundColor "red"
            }
    } 

}


$SolutionProjectPattern = @"
(?x)
^ Project \( " \{ FAE04EC0-301F-11D3-BF4B-00C04F79EFBC \} " \)
\s* = \s*
" (?<name> [^"]* ) " , \s+
" (?<path> [^"]* ) " , \s+
"@

function Get-AllSlns ($Path) {
    Get-ChildItem -recurse $Path -include *.sln |
	    Foreach-Object {
		    $_
	    }
}

function Get-AllProjs ($Path) {
    Get-ChildItem -recurse $Path -include *.csproj |
	    Foreach-Object {
		    $_
	    }
}

function Get-AllTestProjs ($Path) {
    Get-ChildItem -recurse $Path -include *.tests.csproj, *.test.csproj  |
	    Foreach-Object {
		    $_
	    }
}

function Get-IncludedProjects ($SlnPath) {
    Get-Content -Path $SlnPath |
        ForEach-Object {
            #if ($_ -match $SolutionProjectPattern) {
            if (!$_.Contains('|')) {
			   $_.ToString().Split("=")[1].Split(",")[0].Replace("""", "").Trim()
            }
    }
}

function Get-MissingProjectRefNamesFromSln ($SlnPath) {   
 
    $ErrorActionPreference = 'silentlycontinue'

    $SolutionRoot = $SlnPath | Split-Path
    $ProjectsInSln = Get-IncludedProjects $SlnPath

    $MissingReferencedProjects = @()
    $ProjectsWithMissingReferencedProjects = @()
    $MissingProjects = @()

	Get-Content -Path $SlnPath |
		ForEach-Object {
			if ($_ -match $SolutionProjectPattern) {
                try {				                    
                    $ProjectPath = ($SolutionRoot | Join-Path -ChildPath $Matches['path'] | Resolve-Path).ProviderPath
				    [xml]$Project = Get-Content -Path $ProjectPath
                    $nm = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList $Project.NameTable
				    $nm.AddNamespace('x', 'http://schemas.microsoft.com/developer/msbuild/2003')
                    $Project.SelectNodes('/x:Project/x:ItemGroup/x:ProjectReference', $nm) |
					    ForEach-Object {
						    if (!$ProjectsInSln.Contains($_.Name) -and !$MissingReferencedProjects.Contains($_.Name)) {
							    $MissingReferencedProjects += $_.Name 
                                $ProjInfo = $_.Name +  " (" + $ProjectPath + ")"
                                $ProjectsWithMissingReferencedProjects += $ProjInfo
						    }
					    }    
                }
                catch {
                   $name = $Matches['name'] 
                   if (!$MissingProjects.Contains($name)) {
                        $MissingProjects += $name
                   }
                }
			}
		}

    [hashtable]$Return = @{}
    $Return.MissingProjects = $MissingProjects
    $Return.MissingReferencedProjects = $MissingReferencedProjects
    $Return.ProjectsWithMissingReferencedProjects = $ProjectsWithMissingReferencedProjects
    return $Return
}

function Get-3rdPartyDllsForProject ($ProjPath, $ExcludeLike) {   
    $3rdPartyDlls = @()
    $ProjectRoot = $ProjPath | Split-Path
	[xml]$Project = Get-Content -Path $ProjPath 
    $nm = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList $Project.NameTable
    $nm.AddNamespace('x', 'http://schemas.microsoft.com/developer/msbuild/2003')
    $Project.SelectNodes('/x:Project/x:ItemGroup/x:Reference', $nm) |
		ForEach-Object { 
            if ($_.HintPath) { 
                if ([string]::IsNullOrEmpty($ExcludeLike)) {
                    $3rdPartyDlls += $_.HintPath                    
                }
                else {
                     if (-not $_.HintPath.Contains($ExcludeLike)) { $3rdPartyDlls += $_.HintPath }
                } 
            }
        }
    return $3rdPartyDlls;
}


