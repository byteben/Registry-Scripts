<#	
	===========================================================================
	 Created on:   	04/03/2020 07:08
	 Created by:   	Ben Whitmore
	 Organization: 	
	 Filename:     	setup_add_registry.ps1
    ===========================================================================
    
    Version:
    1.0.0   04/03/2020  Ben Whitmore
    Initial Release
#>

#Define Registry Keys to create for each user
$RegistryKeys = @(
    "\Software\Key 1"
    "\Software\Key 1\SubKey 1"
    "\Software\Key 2"
    "\Software\Key 2\SubKey 2"
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

#Close Handle or Hives will not unload
$UserHives.Handle.Close()

#Write Reg keys in $RegistryKeys to Hives in HKU PSDrive
Foreach ($User in $UserHives) {

    ##############################################
    #Create Registry Keys
    ##############################################
    ForEach ($Key in $RegistryKeys) {
        If (!(Test-Path $Key)) {
            Try {
                New-Item (Join-Path $User.Name $Key) -Force -ErrorAction Stop | Out-Null
            }
            Catch [System.Management.Automation.ItemNotFoundException] {
                Write-Warning "$Key was somehow deleted between the time we ran the test path and now."
            }
            Catch {
                Write-Warning "Some other error $($error[0].Exception). Most likely access denied"
            }
        }
    }

    ##############################################
    #Create Registry Values Here
    ##############################################

    New-ItemProperty -Path (Join-Path $User.Name "\Software\Key 1\SubKey 1") -Name 'Setting1a' -Value 'SomeSetting' -PropertyType String -Force -ErrorAction Stop | Out-Null
    New-ItemProperty -Path (Join-Path $User.Name "\Software\Key 1\SubKey 1") -Name 'Setting1b' -Value 'SomeSetting' -PropertyType String -Force -ErrorAction Stop | Out-Null
    New-ItemProperty -Path (Join-Path $User.Name "\Software\Key 2\SubKey 2") -Name 'Setting2a' -Value 'SomeSetting' -PropertyType String -Force -ErrorAction Stop | Out-Null
    New-ItemProperty -Path (Join-Path $User.Name "\Software\Key 2\SubKey 2") -Name 'Setting2b' -Value 'SomeSetting' -PropertyType String -Force -ErrorAction Stop | Out-Null

    ##############################################
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