<#	
	===========================================================================
	 Created on:   	04/03/2020 07:08
	 Created by:   	Ben Whitmore
	 Organization: 	
     Filename:     	setup_remove_registry.ps1
     
     Credit: Kris Powell @ https://www.pdq.com/blog/modifying-the-registry-of-another-user/
    ===========================================================================
    
    Version:
    1.0.0   04/03/2020  Ben Whitmore
    Initial Release
#>

#Define Registry Keys to delete for each user
$RegistryKeys = @(
    "\Software\Key 1\SubKey 1"
    "\Software\Key 1"
    "\Software\Key 2\SubKey 2"
    "\Software\Key 2"
)

#SID Regex pattern
$SID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
 
#Get SID, ntuser.dat location and username for all users
$ProfileList = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object { $_.PSChildName -match $SID } | Select  @{name = "SID"; expression = { $_.PSChildName } }, @{name = "UserHive"; expression = { "$($_.ProfileImagePath)\ntuser.dat" } }, @{name = "Username"; expression = { $_.ProfileImagePath -replace '^(.*[\\\/])', '' } }
 
#Get all user SIDs found in HKEY_USERS
$LoadedHives = Get-ChildItem Registry::HKEY_USERS | Where-Object { $_.PSChildname -match $PatternSID } | Select  @{name = "SID"; expression = { $_.PSChildName } }
 
#Get Hives not currently loaded
$UnloadedHives = Compare-Object $ProfileList.SID $LoadedHives.SID | Select @{name = "SID"; expression = { $_.InputObject } }, UserHive, Username

#Get Default Hive
$DefaultUserHive = "C:\Users\Default\NTUSER.DAT"
reg load HKU\DefaultHive $DefaultUserHive

#Load each Unloaded Hive into the Registry
Foreach ($UserProfile in $ProfileList) {
    
    If ($UserProfile.SID -in $UnloadedHives.SID) {
        reg load HKU\$($UserProfile.SID) $($UserProfile.UserHive)
    }   
}

#Create enw PSDrive for HKU Editing
try {
    New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -erroraction stop | Out-Null
}
catch [System.Management.Automation.SessionStateException] {
    Write-Warning "Drive Already exists"
}

#Set location to PSDrive
Set-Location HKU:

#Get Profiles in HKU PSDrive
$UserHives = Get-ChildItem | Where-Object { $_.PSChildName -in $ProfileList.SID -or $_.PSChildName -eq "DefaultHive" -or $_.PSChildName -eq ".Default" }
$UserHives.Handle.Close()

#Write Reg keys in $RegistryKeys to Hives in HKU PSDrive
Foreach ($User in $UserHives) {

    ##############################################
    #Remove Registry Keys
    ##############################################
    ForEach ($Key in $RegistryKeys) {

        Remove-Item (Join-Path $User.Name $Key) -Force -Recurse | Out-Null
    }

}

#Remove PSDrive HKU
Remove-PSDrive "HKU" -Force

#Garbage Can
[gc]::collect()

# Unload User Hives
Foreach ($UserProfile in $ProfileList) {
    If ($UserProfile.SID -in $UnloadedHives.SID) {
        reg unload HKU\$($UserProfile.SID)
    }
}

# Unload Default Hive
reg unload HKU\DefaultHive