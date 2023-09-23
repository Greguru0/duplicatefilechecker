function Get-FileMD5Hash {
    param (
        [string]$filePath
    )
    $hashValue = certutil -hashfile $filePath MD5 | Select-Object -Index 1
    return $hashValue
}

function Get-DuplicateFiles {
    param (
        [string]$folderPath,
        [string]$logFilePath
    )

    $hashTable = @{}
    $duplicateGroups = @()

    # Get all files recursively from the folder
    $files = Get-ChildItem -Path $folderPath -Recurse | Where-Object { $_.PSIsContainer -eq $false }

    # Calculate MD5 hash for each file and store in hashtable
    $totalCount = $files.Count
    $currentCount = 0
    foreach ($file in $files) {
        $md5Hash = Get-FileMD5Hash -filePath $file.FullName

        if ($hashTable.ContainsKey($md5Hash)) {
            $hashTable[$md5Hash] += @($file.FullName)
        } else {
            $hashTable.Add($md5Hash, @($file.FullName))
        }

        $currentCount++
        $progressPercentage = ($currentCount / $totalCount) * 100
        Write-Progress -Activity "Calculating MD5 Hashes" -Status "Progress" -PercentComplete $progressPercentage
    }

    # Filter out non-duplicate files and prepare the output
    $duplicateGroups = $hashTable.Values | Where-Object { $_.Count -gt 1 }

    # Prepare the output string
    $output = "`n***********SUMMARY************`n"
    $output += Write-Output "Duplicate Scan done: " ;$output+= Get-Date
    $output += ("`nTotal Files: {0}`n" -f $files.Count)
    $output += ("Number of groups: {0}`n`n" -f $duplicateGroups.Count)

    $groupIndex = 1
    foreach ($group in $duplicateGroups) {
        $output += ("Duplicate files group {0}:`n" -f $groupIndex)
        $groupIndex++
        $group | ForEach-Object { $output += "$_`n" }
    }

    # Read the existing content of the log file, if any
    $existingContent = Get-Content -Path $logFilePath -Raw

    # Write the updated content (output + existing content) back to the log file
    $output + $existingContent | Set-Content -Path $logFilePath

    return $duplicateGroups
}

# Check if the user provided a folder path as an argument

if ($args.Length -eq 0) {
    Write-Host "Please provide a folder path as an argument."
} else {
    $folderPath = $args[0]
    $logFilePath = "DuplicateFilesLog.txt"
    $duplicateGroups = Get-DuplicateFiles -folderPath $folderPath -logFilePath $logFilePath

    Write-Host "Duplicate files are located at:"
    $groupIndex = 1
    foreach ($group in $duplicateGroups) {
        Write-Host "`nDuplicate file ${groupIndex}:"
        $group | ForEach-Object { Write-Host $_ }
        $groupIndex++
    }

    Write-Host "`nLog file saved to: $pwd\$logFilePath"
    start notepad $logFilePath

    # Ask the user if they want to clean the system of duplicate files
    $response = Read-Host "Do you want to clean the system of duplicate files? (Y/N)"
	Write-Host ""
    if ($response -eq 'Y' -or $response -eq 'y') {
        $KeptFiles = @() # Initialize an empty array to store kept file paths
        foreach ($group in $duplicateGroups) {
            # Keep the file in the deepest subdirectory and delete the others
            $deepestSubdirectoryFile = $group | Sort-Object { $_.Split("\").Count } -Descending | Select-Object -First 1
            $KeptFiles += $deepestSubdirectoryFile
            $group | Where-Object { $_ -ne $deepestSubdirectoryFile } | ForEach-Object {
                Write-Host "Deleting duplicate file: $_"
                Remove-Item -Path $_ -Force
            }
        }
        $KeptFiles = $KeptFiles -join "`n" # Join the kept file paths into a single string

        # Append information about deleted and kept files to the output
		$output = "`n***********************************`n"
		$output += Write-Output "Duplicate Deletion done: " ;$output+= Get-Date
        $output += "`nDeleted files:`n"
        $duplicateGroups | ForEach-Object {
            $group | Where-Object { $_ -ne $KeptFiles } | ForEach-Object {
                $output += "$_`n *DELETED*"
            }
        }

        $output += "`nKept files:`n$KeptFiles *KEPT*`n"
        # Append the updated content (output + existing content) to the log file
        $existingContent = Get-Content -Path $logFilePath -Raw
        $output + $existingContent | Set-Content -Path $logFilePath
        Write-Host "`nDuplicate files cleaned successfully.`n"
		start notepad $logFilePath
    } else {
		$output = "`n***********************************`n"
        Write-Host "`nDuplicate files were not cleaned.`n"
    }
}