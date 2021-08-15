class GitRepoMetaData {
    $BranchName
}

$commitHash = (git rev-parse HEAD).Substring(0,16)
$versionDatePart = [System.DateTime]::Now.ToString('yyyyMMdd.HHmmss')
"1.$versionDatePart-git-$commitHash"

