function StatusCheck{
    [hashtable]$ToReturn = @{}
    $IPorHostname = Read-Host -Prompt "Please enter the IP address or hostname of the remote computer"
    try {
        if($IPorHostname -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"){
            $RemoteHostname = (Resolve-DnsName $IPorHostname -ErrorAction Stop).NameHost
        }
        else{
            $RemoteHostname = (Resolve-DnsName $IPorHostname -ErrorAction Stop).Name | Select-Object -First 1
        }
    }
    catch {
        Write-Host "`nAn error occured.`nMost likely $IPorHostname is not resolving.`nPlease make sure it is correct and try again.`nThis script needs to exit to clear some variables.`nPlease re-run the script.`n" -ForegroundColor Red -BackgroundColor Black
        #StatusCheck
        # Some vars still get set that throw a weird error even though the script still works if a wrong hostname is entered followed by a correct one. Need to fix this in later versions so the script doesn't have to exit.
        exit
    }
    if (Test-WSMan -ComputerName $RemoteHostname){
        $RemoteUser = (Get-WmiObject Win32_ComputerSystem -ComputerName $RemoteHostname).Username
        Write-Host "`n$RemoteHostname is up.`nWinRm is enabled.`n$RemoteUser is logged on.`nScript will continue.`n" -ForegroundColor Yellow
        $ToReturn.RemoteUser = $RemoteUser
        $ToReturn.RemoteHostname = $RemoteHostname
        Write-Host "`nPlease be sure the above username/host is correct before continuing.`nNOTE: This script should not be run on servers- only user workstations (thick clients and VDIs)`n" -ForegroundColor Cyan
        [void](Read-Host 'By pressing Enter to continue you understand and acknowledge the above...')
        return $ToReturn            
    }
    elseif (Test-Connection $RemoteHostname -C 1 -Quiet){
        Write-Host "$RemoteHostname is up but WinRm is not enable. Script will exit.`n" -ForegroundColor Yellow
        exit
    }
    else {
        Write-Host "$RemoteHostname is not up. Script will exit`n" -ForegroundColor Yellow
        exit
    }
}

function Menu{
    Write-Host "Please select where to search for the software`n" -ForegroundColor Yellow
    Write-Host "1. Add or Remove Programs list`n2. Software installed via MSI and Windows Installer (HKLM- 32 and 64 bit)`n3. User-specific installs e.g. Zoom, MS Teams (HKCU)`n4. Packages installed with PackageManagement`n5. App packages installed to in a user profile`n6. Standalone executables on the H: drive`n7. File, EXE, and DLL search on C:\`n8. Exit"
    $Selection = Read-Host "`nPlease enter a number from the menu above"
    Switch($Selection){
        1 {AddorRemove}
        2 {HKLM}
        3 {HKCU}
        4 {PackageMgmt}
        5 {AppxPackages}
        6 {Drives}
        7 {CDrive}
        8 {exit}
        Default {Write-Host "Not a valid selection`n" -ForegroundColor Red ; Menu}
    }
    Menu
}

function AddorRemove{
    Invoke-Command -Session $RemoteSession -ScriptBlock {
        function Search {
            $SearchTerm = Read-Host -Prompt 'Input software to search for in Add or Remove Programs List'
            Write-Host "Searching Add or Remove Program list for $SearchTerm...."
            $AddorRemoveList = Get-CimInstance Win32Reg_AddRemovePrograms | Where-Object DisplayName -Like "*$SearchTerm*"
            function List {
                if (($AddorRemoveList | Measure-Object).count -eq 1){
                    Write-Host "`n1 item found called $($AddorRemoveList.DisplayName) " -ForegroundColor Yellow
                    Write-Host "Item details are:" -ForegroundColor Yellow
                    $AddorRemoveList
                    Write-Host "Is "$($AddorRemoveList.DisplayName)" what you want to remove?" -ForegroundColor Yellow
                    $confirmation = Read-Host "Type [yes] to confirm. Type [s] to search again. Type [m] to go to main menu"
                    Switch ($confirmation){
                        yes {
                            Write-Host "Removing "$($AddorRemoveList.DisplayName)"..." -ForegroundColor Yellow
                            $toUninstall = Get-WmiObject -Class Win32Reg_AddRemovePrograms -Filter "DisplayName = '$($AddorRemoveList.DisplayName)'"
                            $toUninstall.Uninstall()
                            if($?) {Write-Host "Removed successfully"}
                            if(!$?) {Write-Host "Error during removal"}
                        }
                        s {Search}
                        m {Exit-PSSession}
                        Default {Write-Host "Invalid selection."; Exit-PSSession}
                    }
                } elseif ($AddorRemoveList.count -gt 1){
                        Write-Host "`n$($AddorRemoveList.count) installed programs with that name were found" -ForegroundColor Yellow
                        Write-Host "`nPlease select a program to confirm details" -ForegroundColor Yellow
                        for($i = 0; $i -lt $AddorRemoveList.count; $i++){
                            Write-Host "$($i): "$($AddorRemoveList[$i].DisplayName)""
                        }
                        $selection = Read-Host -Prompt "Enter the number of the program"
                        $displayDetails = $AddorRemoveList[$selection]
                        Write-Host "Details for "$($AddorRemoveList[$selection].DisplayName)"`n" -ForegroundColor Yellow
                        $displayDetails
                        Write-Host "Is "$($AddorRemoveList[$selection].DisplayName)" what you want to remove?" -ForegroundColor Yellow
                        $confirmation = Read-Host "Type [yes] to confirm. Type [s] to search again. Type [l] to view list again. Type [m] to go to main menu"
                        Switch ($confirmation){
                            yes {
                                Write-Host "Removing "$($AddorRemoveList[$selection].DisplayName)"..." -ForegroundColor Yellow
                                $toUninstall = Get-WmiObject -Class Win32Reg_AddRemovePrograms -Filter "DisplayName = '$($AddorRemoveList[$selection].DisplayName)'"
                                $toUninstall.Uninstall()
                                if($?) {Write-Host "Removed successfully"}
                                if(!$?) {Write-Host "Error during removal"}                                
                            }
                            s {Search}
                            l {List}
                            m {Exit-PSSession}
                            Default {Write-Host "Invalid selection."; Exit-PSSession}                        
                        }
            
                } else {
                    Write-Host "`nNo programs found in the Add or Remove Software list" -ForegroundColor Yellow
                    $confirmation = Read-Host "Type [s] to search again. Type [m] to go to main menu"
                    Switch ($confirmation){                        
                        s {Search}
                        m {Exit-PSSession}
                        Default {Write-Host "Invalid selection.";Exit-PSSession}                             
                    }
                }
            }
            List
        }
        Search
    }
}

function HKLM{
    Invoke-Command -Session $RemoteSession -ScriptBlock {
        function Search{
            $SearchTerm = Read-Host -Prompt 'Input software to search for in Local Machine hive'
            Write-Host "Searching registry for 32 and 64-bit programs installed via MSI file..."
            #Wow6432Node is for 64-bit programs, HKCU will be for "per-user" installs like MS Teams
            function List {
                $RegSoftwareList = (Get-ChildItem 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' | 
                    % { 
                        if((Get-ItemProperty -Path $_.PsPath) -match "$SearchTerm")
                        { 
                            $_.PsChildName
         
                        } 
                    })
                if (($RegSoftwareList | Measure-Object).count -eq 1){
                    Write-Host "`nOne item in registry list of software contains the word "$($SearchTerm)", item is called "$($RegSoftwareList)"" -ForegroundColor Yellow
                    Write-Host "Item details are:" -ForegroundColor Yellow
                    Get-Item "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$RegSoftwareList","HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$RegSoftwareList" -ErrorAction SilentlyContinue
                    Write-Host "`nIs "$($RegSoftwareList)" what you want to remove? Doing so start a process containg the command below." -ForegroundColor Yellow
                    $UninstallString = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$RegSoftwareList","HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$RegSoftwareList" -ErrorAction SilentlyContinue | Select-Object UninstallString
                    $UninstallString
                    $UninstallStringOnly = (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$RegSoftwareList","HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$RegSoftwareList" -ErrorAction SilentlyContinue).UninstallString
                    $confirmation = Read-Host "Type [yes] to confirm. Type [s] to search again. Type [m] to go to main menu"
                    Switch ($confirmation){
                        yes {
                            Write-Host "Removing "$($RegSoftwareList)"..." -ForegroundColor Yellow
                            Start-Process -NoNewWindow -FilePath $UninstallStringOnly -ArgumentList " /s"
                            if($?) {Write-Host "Removed successfully"}
                            if(!$?) {Write-Host "Error during removal"}
                        }
                        s {Search}
                        m {Exit-PSSession}
                        Default {Write-Host "Invalid selection."; Exit-PSSession}
                    }
                }
                elseif(($RegSoftwareList | Measure-Object).count -gt 1){
                    Write-Host "`n"$($RegSoftwareList | Measure-Object).count" objects in the registry list of software contains the "$($SearchTerm)""
                    for($i = 0; $i -lt $($RegSoftwareList | Measure-Object ).count; $i++){
                            Write-Host "$($i): "$($RegSoftwareList[$i])""
                        }
                        Write-Host "Please select a registry entry to view details" -ForegroundColor Yellow
                        $selection = Read-Host -Prompt "Enter the number of the registy item to view details"
                        $selected = $RegSoftwareList[$selection]
                        Get-Item "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$selected","HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$selected" -ErrorAction SilentlyContinue
                        Write-Host "`nIs "$($selected)" what you want to remove? Doing so start a process containg the command below." -ForegroundColor Yellow
                        $UninstallString = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$selected","HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$selected" -ErrorAction SilentlyContinue | Select-Object UninstallString
                        $UninstallString
                        $UninstallStringOnly = (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$selected","HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$selected" -ErrorAction SilentlyContinue).UninstallString
                        $confirmation = Read-Host "Type [yes] to confirm. Type [s] to search again. Type [l] to view list again. Type [m] to go to main menu"
                        Switch ($confirmation){
                            yes {
                                Write-Host "Removing "$($selected)"..." -ForegroundColor Yellow
                                $UninstallStringOnly
                                Start-Process -NoNewWindow -FilePath $UninstallStringOnly -ArgumentList " /s"
                                if($?) {Write-Host "Removed successfully"}
                                if(!$?) {Write-Host "Error during removal"}                                
                            }
                            s {Search}
                            l {List}
                            m {Exit-PSSession}
                            Default {Write-Host "Invalid selection."; Exit-PSSession}
                        }
                }
                else {
                Write-Host "`nNothing matched $SearchTerm in HKLM." -ForegroundColor Yellow
                $confirmation = Read-Host "Type [s] to search again. Type [m] to go to main menu"
                    Switch ($confirmation){                        
                        s {Search}
                        m {Exit-PSSession}
                        Default {Write-Host "Invalid selection.";Exit-PSSession}                             
                    }
                }
            }
            List
        }
        Search
    }
}

function HKCU{
    # This is quite an undocumented reg key, but some programs do use this for local installs.
    Invoke-Command -Session $RemoteSession -ScriptBlock {
        function Search{
            $SearchTerm = Read-Host -Prompt 'Input software to search for in the Current User hive'
            function List{
                $HKCUfullList = (Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' | 
                % { 
                    if((Get-ItemProperty -Path $_.PsPath) -match "$SearchTerm")
                    { 
                        $_.PsChildName
         
                    } 
                })
                if (($HKCUfullList | Measure-Object).count -eq 1){
                    Write-Host "`nOne item in HKCU list of software contains the word "$($SearchTerm)", item is called "$($HKCUfullList)"" -ForegroundColor Yellow
                    Write-Host "Item details are:" -ForegroundColor Yellow
                    Get-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$HKCUfullList"
                    Write-Host "Although this registry key is commonly used, it is not well documented, and applications utilize it differently." -ForegroundColor Yellow
                    Write-Host "The next version of this script will have some ability to unistall software installed with this key set." -ForegroundColor Yellow
                    Write-Host "For now, entry details should be reviewed to look for propertes called UninstallString, QuietlyUninstallString, or something of the like." -ForegroundColor Yellow
                    Write-Host "If one is included, take note, exit this script and run the uninstaller." -ForegroundColor Yellow
                    Write-Host "If one is not included, the software removal goes beyond the scope of this script" -ForegroundColor Yellow
                    $confirmation = Read-Host "Type [s] to search again. Type [m] to go to main menu."
                    Switch ($confirmation){
                        s {Search}
                        m {Exit-PSSession}
                        Default {Write-Host "Invalid selection."; Exit-PSSession}
                    }
                    
                }
                elseif (($HKCUfullList | Measure-Object).count -gt 1){
                    Write-Host "`n"$($HKCUfullList | Measure-Object).count" items in HKCU list of software contain the word "$($SearchTerm)"" -ForegroundColor Yellow
                    for($i = 0; $i -lt $($HKCUfullList | Measure-Object ).count; $i++){
                            Write-Host "$($i): "$($HKCUfullList[$i])""
                        }
                    Write-Host "Please select a registry entry to view details" -ForegroundColor Yellow
                    $selection = Read-Host -Prompt "Enter the number of the registy item to view details"
                    $selected = $HKCUfullList[$selection]
                    Write-Host "Item details are:" -ForegroundColor Yellow
                    Get-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$selected"
                    Write-Host "Although this registry key is commonly used, it is not well documented, and applications utilize it differently." -ForegroundColor Yellow
                    Write-Host "The next version of this script will have some ability to unistall software installed with this key set." -ForegroundColor Yellow
                    Write-Host "For now, entry details should be reviewed to look for propertes called UninstallString, QuietlyUninstallString, or something of the like." -ForegroundColor Yellow
                    Write-Host "If one is included, take note, exit this script and run the uninstaller." -ForegroundColor Yellow
                    Write-Host "If one is not included, the software removal goes beyond the scope of this script" -ForegroundColor Yellow
                    $confirmation = Read-Host "Type [s] to search again. Type [l] to view list again. Type [m] to go to main menu."
                    Switch ($confirmation){
                        s {Search}
                        l {List}
                        m {Exit-PSSession}
                        Default {Write-Host "Invalid selection."; Exit-PSSession}
                    }
                }
                else {
                    Write-Host "`nNothing matched $SearchTerm in HKCU." -ForegroundColor Yellow
                    $confirmation = Read-Host "Type [s] to search again. Type [m] to go to main menu"
                    Switch ($confirmation){                        
                        s {Search}
                        m {Exit-PSSession}
                        Default {Write-Host "Invalid selection.";Exit-PSSession}
                    }
                }
            }
            List
        }
        Search
    }
}

function PackageMgmt{
    Invoke-Command -Session $RemoteSession -ScriptBlock {
        Write-Host "This will search across packages that were installed via or connected to Package Management such as NuGet, Chocolatey, and PowershellGet"
        Write-Host "This system has the following Package Management available"
        Get-PackageProvider
        function PackageMgmtMenu{
            Write-Host "`n`n1. Search across all package providers for package names only"
            Write-Host "2. Serach across all providers in all properties (source, provider, publisher, metadata, etc)"
            $Selection = Read-Host -Prompt 'Select number'
            Switch($Selection){
                1 {
                    $SearchTerm = Read-Host -Prompt 'Enter a pacakge name to search for'
                    function List {
                        $SearchResults= Get-Package *$SearchTerm* -ErrorAction SilentlyContinue
                        if(($SearchResults | Measure-Object).count -eq 1){
                            $Package = $($SearchResults).Name
                            Write-Host "`n1 item found called "$Package"" -ForegroundColor Yellow
                            Write-Host "Item details:"
                            $SearchResults | Select-Object -Property *
                            Write-Host "Would you like to uninstall $Package?" -ForegroundColor Yellow
                            $Selection = Read-Host "Type [yes] to confirm. Type [s] to search with a new term. Type [m] to return to main menu"
                            Switch($Selection){
                                yes {
                                    Write-Host "Deleting $Package..." -ForegroundColor Yellow
                                    $Package | Uninstall-Package
                                    if($?) {Write-Host "Uninstalled successfully"}
                                    if(!$?) {Write-Host "Error during removal"}
                                }
                                s {PackageMgmtMenu}
                                m {Exit-PSSession}
                                Defaut {Write-Host "Invalid selection."; Exit-PSSession}       
                            }

                        }
                        elseif(($SearchResults | Measure-Object).count -gt 1){
                            Write-Host "`n"$($SearchResults | Measure-Object).count" items found with that name" -ForegroundColor Yellow
                            for($i = 0; $i -lt $($SearchResults | Measure-Object ).count; $i++){
                                Write-Host "$($i): "$($SearchResults[$i]).Name""
                            }
                            Write-Host "Please select a number" -ForegroundColor Yellow
                            $Selection = Read-Host -Prompt "Enter the number of the registy item to view details"
                            $Selected = $SearchResults[$Selection]
                            $Selected
                            Write-Host "Would you like to uninstall "$($Selected).Name"?" -ForegroundColor Yellow
                            $Confirmation = Read-Host -Prompt 'Enter [yes] to confirm. Type [s] to search again. Type [l] to view list again. Type [m] to go to main menu.'
                                Switch($Confirmation){
                                    yes {
                                        Write-Host "Uninstalling "$($Selected).Name"..." -ForegroundColor Yellow
                                        $($Selected).Name | Uninstall-Package
                                        if($?) {Write-Host "Uninstalled successfully"}
                                        if(!$?) {Write-Host "Error during removal"}
                                        Exit-PSSession
                                    }
                                    s {PackageMgmtMenu}
                                    l {List}
                                    m {Exit-PSSession}
                                    Default {Write-Host "Ivalid selection."; Exit-PSSession}                                   
                                }
                        }
                        else {
                            Write-Host "`nNo results found for $SearchTerm`n" -ForegroundColor Yellow
                            $Confirmation = Read-Host -Prompt 'Type [s] to search again. Type [m] to go to main menu.'
                            Switch($Confirmation){
                                s {PackageMgmtMenu}
                                m {Exit-PSSession}
                                Default {Write-Host "Ivalid selection."; Exit-PSSession}                                   
                            }
                        }
                    }
                    List
                }
                2 {
                    Write-Host "`nThis is a placeholder for later functionality. Please enter 1 to search package names only, at this time." -ForegroundColor Yellow
                    PackageMgmtMenu
                }
                Default {
                    Write-Host "Invalid selection. Returning to main menu..."
                    Exit-PSSession
                }
    
            }
        }
        PackageMgmtMenu
    }
}

function AppxPackages{
    Invoke-Command -Session $RemoteSession -ScriptBlock {
        function Search{
            $SearchTerm = Read-Host -Prompt 'Input name to search for app packages that were installed to a user profile'
                function List{
                $List = Get-AppxPackage *$SearchTerm*
                if(($List | Measure-Object).count -eq 1){
                    $Item = $List.Name
                    Write-Host "`n1 item found containg $SearchTerm, called $Item" -ForegroundColor Yellow
                    Write-Host "`nItem details:"
                    Get-AppxPackage $Item
                    Write-Host "Would you like to uninstall $Item?" -ForegroundColor Yellow
                    $Confimation = Read-Host -Prompt "Enter [yes] to confirm. Enter [s] to search again. Enter [m] to go back to main menu."
                    Switch($Confimation){
                        yes {
                            Write-Host "Uninstalling $Name..." -ForegroundColor Yellow
                            Get-AppxPackage $Name | Remove-AppxPackage
                            if($?) {Write-Host "Uninstalled successfully"}
                            if(!$?) {Write-Host "Error during removal"}
                        }
                        s {Search}
                        m {Exit-PSSession}
                        Default {Write-Host "Invalid selection. Returning to menu...";Exit-PSSession}
                    }
                }
                elseif(($List | Measure-Object).count -gt 1){
                    Write-Host "`n"$($List | Measure-Object).count" items found with that name" -ForegroundColor Yellow
                    for($i = 0; $i -lt $($List | Measure-Object ).count; $i++){
                        Write-Host "$($i): "$($List[$i]).Name""
                    }
                    Write-Host "Please select a number to view more details" -ForegroundColor Yellow
                    $Selection = Read-Host -Prompt "Enter number"
                    $Selected = $List[$Selection]
                    $Selected
                    $Item = $Selected.Name
                    Write-Host "Would you like to uninstall $Item ?" -ForegroundColor Yellow
                    $Confirmation = Read-Host -Prompt 'Enter [yes] to confirm. Enter [l] to view result list again. Enter [s] to search again. Enter [m] to go back to main menu.'
                        Switch($Confirmation){
                            yes {
                                Write-Host "Uninstalling $Item..." -ForegroundColor Yellow
                                Get-AppxPackage $Name | Remove-AppxPackage
                                if($?) {Write-Host "Uninstalled successfully"}
                                if(!$?) {Write-Host "Error during removal"}
                            }
                            l {List}
                            s {Search}
                            m {Exit-PSSession}
                            Default {Write-Host "Not a valid selection. Returing to menu...";Exit-PSSession}
                        }
                }
                else{
                    Write-Host "`nNo results found for $SearchTerm."
                    $Confirmation = Read-Host -Prompt 'Enter [s] to search again. Enter [m] to go back to main menu.'
                        Switch($Confirmation){
                            s {Search}
                            m {Exit-PSSession}
                            Default {Write-Host "Not a valid selection. Returing to menu...";Exit-PSSession}
                        }
                }
            }
            List
        }
        Search
    }
}

function Drives{
    $DriveLocation = $RemoteUserHomeDir
    Write-Host "User's H drive is located at $DriveLocation" -ForegroundColor Yellow
    Write-Host "`n1. Search user drive for all user added exes and dlls`n2. Search for a file with a specific name`n3. Return to main menu"
    $Selection = Read-Host -Prompt "Please make select a number"
    Switch($Selection){
        1 {
            Write-Host "`nThis may take a minute or two...`n"
            $ExeList = Get-ChildItem -Path $DriveLocation -Recurse -Force | ForEach-Object {
                [byte[]] $Bytes = Get-Content -Encoding Byte -Path $_.FullName -TotalCount 2 -ErrorAction SilentlyContinue
                if($Bytes){
                    $StringBytes = [System.BitConverter]::ToString($Bytes)
                    if($StringBytes -eq "4D-5A"){
                        $_.FullName
                    }
                }
            } -ErrorAction SilentlyContinue
            function ExeSelection {
                if($($ExeList | Measure-Object ).count -ge 1){
                    Write-Host "`n"$($ExeList | Measure-Object ).count" dll(s) or exeuctable(s) found on drive`n" -ForegroundColor Yellow
                    for($i = 0; $i -lt $($ExeList | Measure-Object ).count; $i++){
                        Write-Host "$($i): "$($ExeList[$i])""
                    }
                    $Selection = Read-Host -Prompt "Select a number to view details"
                    $Selected = $ExeList[$Selection]
                    Get-ChildItem $Selected | Select-Object -ExpandProperty VersionInfo | Select-Object -Property *
                    Get-ChildItem $Selected | Select-Object -Property *
                    function LocalMenu{
                        Write-Host "What would you like to do?`n1. Hash $Selected `n2. Delete $Selected `n3. Select different executable or dll `n4. Return to main menu" -ForegroundColor Yellow
                        $NextSelection = Read-Host -Prompt "Please enter a number"
                        Switch($NextSelection){
                            1{
                                Get-ChildItem $Selected | Select FullName | ForEach-Object {Get-FileHash -Algorithm MD5 -Path $_.FullName ; Get-FileHash -Algorithm SHA1 -Path $_.FullName} | Select-Object -Property Algorithm,Hash
                                LocalMenu
                            }
                            2{
                                Write-Host "Deleting $Selected..." -ForegroundColor Yellow
                                Remove-Item -Path $Selected -Force
                                if($?) {Write-Host "Successfully removed"}
                                if(!$?) {Write-Host "Error during deletion"} 
                                Menu
                            }
                            3{ExeSelection}
                            4{Menu}
                            Default{Write-Host "Invalid selction. Returning to menu...`n" -ForegroundColor Yellow; Menu}
                        }
                    }
                    LocalMenu
                }
                else{
                    Write-Host "`nNo dlls or exes found on this host.`n" -ForegroundColor Yellow
                    Drive
                }
            }
            ExeSelection
        }
        2 {
            $SearchTerm = Read-Host -Prompt "Enter a filename"
            $SearchResults = Get-ChildItem -Path $DriveLocation -Include *$SearchTerm* -Recurse -ErrorAction SilentlyContinue
            function FileSearch {
                if($($SearchResults | Measure-Object ).count -ge 1){
                    Write-Host "`n"$($SearchResults | Measure-Object ).count" file(s) with that search term found on drive`n" -ForegroundColor Yellow
                    for($i = 0; $i -lt $($SearchResults | Measure-Object ).count; $i++){
                        Write-Host "$($i): "$($SearchResults[$i])""
                    }
                    $Selection = Read-Host -Prompt "Select a number to view details"
                    $Selected = $SearchResults[$Selection]
                    Get-ChildItem $Selected | Select-Object -ExpandProperty VersionInfo | Select-Object -Property *
                    Get-ChildItem $Selected | Select-Object -Property *
                    function LocalMenu{
                        Write-Host "What would you like to do?`n1. Hash $Selected `n2. Delete $Selected `n3. Select a different file `n4. Return to main menu" -ForegroundColor Yellow
                        $NextSelection = Read-Host -Prompt "Please enter a number"
                        Switch($NextSelection){
                            1{
                                Get-ChildItem $Selected | Select FullName | ForEach-Object {Get-FileHash -Algorithm MD5 -Path $_.FullName ; Get-FileHash -Algorithm SHA1 -Path $_.FullName} | Select-Object -Property Algorithm,Hash
                                LocalMenu
                            }
                            2{
                                Write-Host "Deleting $Selected..." -ForegroundColor Yellow
                                Remove-Item -Path $Selected -Force
                                if($?) {Write-Host "Successfully removed"}
                                if(!$?) {Write-Host "Error during deletion"} 
                            }
                            3{FileSearch}
                            4{Menu}
                            Default{Write-Host "Invalid selction. Returning to menu...`n" -ForegroundColor Yellow; Menu}
                        }
                    }
                    LocalMenu
                }
                else{
                    Write-Host "`nNo files found with that searchterm.`nTry again?`n" -ForegroundColor Yellow
                    Drives
                }
            }
            FileSearch
        }
        3 {
            Menu
        }
        Default {
            Write-Host "`nInvalid selection. Returning to menu.."
            Menu
        }
    }
}

function CDrive {
    Invoke-Command -Session $RemoteSession -ScriptBlock {
        $DriveLocation = "C:\"
        Write-Host "`n1. Search C:\ for all exes and dlls`n2. Search for a file with a specific name`n3. Return to main menu"
        $Selection = Read-Host -Prompt "Please make select a number"
        Switch($Selection){
            1 {
                Write-Host "`nThis will take a while...`n"
                $ExeList = Get-ChildItem $DriveLocation -Recurse -Force | ForEach-Object {
                    [byte[]] $Bytes = Get-Content -Encoding Byte -Path $_.FullName -TotalCount 2 -ErrorAction SilentlyContinue
                    if($Bytes){
                        $StringBytes = [System.BitConverter]::ToString($Bytes)
                        if($StringBytes -eq "4D-5A"){
                            $_.FullName
                        }
                    }
                }
                function ExeSelection {
                    if($($ExeList | Measure-Object ).count -ge 1){
                        Write-Host "`n"$($ExeList | Measure-Object ).count" dll(s) or exeuctable(s) found on drive`n" -ForegroundColor Yellow
                        for($i = 0; $i -lt $($ExeList | Measure-Object ).count; $i++){
                            Write-Host "$($i): "$($ExeList[$i])""
                        }
                        $Selection = Read-Host -Prompt "Select a number to view details"
                        $Selected = $ExeList[$Selection]
                        Get-ChildItem $Selected | Select-Object -ExpandProperty VersionInfo | Select-Object -Property *
                        Get-ChildItem $Selected | Select-Object -Property *
                        Write-Host "What would you like to do?`n1. Delete $Selected `n2. Select different executable or dll `n3. Return to main menu" -ForegroundColor Yellow
                        $NextSelection = Read-Host -Prompt "Please enter a number"
                        Switch($NextSelection){
                            1{
                                Write-Host "Deleting $Selected..." -ForegroundColor Yellow
                                Remove-Item -Path $Selected -Force
                                if($?) {Write-Host "Successfully removed"}
                                if(!$?) {Write-Host "Error during deletion"} 
                                Menu
                            }
                            2{ExeSelection}
                            3{Menu}
                            Default{Write-Host "Invalid selction. Returning to menu...`n" -ForegroundColor Yellow; Menu}
                        }
                    }
                    else{
                        Write-Host "`nNo dlls or exes found on this host.`n" -ForegroundColor Yellow
                        Drive
                    }
                }
                ExeSelection
            }
            2 {
                $SearchTerm = Read-Host -Prompt "Enter a filename"
                $SearchResults = Get-ChildItem -Path $DriveLocation -Include *$SearchTerm* -Recurse -ErrorAction SilentlyContinue
                function FileSearch {
                    if($($SearchResults | Measure-Object ).count -ge 1){
                        Write-Host "`n"$($SearchResults | Measure-Object ).count" file(s) with that search term found on drive`n" -ForegroundColor Yellow
                        for($i = 0; $i -lt $($SearchResults | Measure-Object ).count; $i++){
                            Write-Host "$($i): "$($SearchResults[$i])""
                        }
                        $Selection = Read-Host -Prompt "Select a number to view details"
                        $Selected = $SearchResults[$Selection]
                        Get-ChildItem $Selected | Select-Object -ExpandProperty VersionInfo | Select-Object -Property *
                        Get-ChildItem $Selected | Select-Object -Property *
                        Write-Host "What would you like to do?`n1. Delete $Selected `n2. Select a different file `n3. Return to main menu" -ForegroundColor Yellow
                        $NextSelection = Read-Host -Prompt "Please enter a number"
                        Switch($NextSelection){
                            1{
                                Write-Host "Deleting $Selected..." -ForegroundColor Yellow
                                Remove-Item -Path $Selected -Force
                                if($?) {Write-Host "Successfully removed"}
                                if(!$?) {Write-Host "Error during deletion"} 
                            }
                            2{
                                FileSearch
                            }
                            3{
                                Menu
                            }
                            Default{
                                Write-Host "Invalid selction. Returning to menu...`n" -ForegroundColor Yellow
                                Menu
                            }
                        }
                    }
                    else{
                        Write-Host "`nNo files found with that searchterm.`nTry again?`n" -ForegroundColor Yellow
                        Drives
                    }
                }
                FileSearch
            }
            3 {
                Menu
            }
            Default {
                Write-Host "`nInvalid selection. Returning to menu.."
                Menu
            }
        }
    }
}

<#
Try, catch, finally are commented out becuase it's catching an unsupressable error.
The error comes from (Get-Content -Encoding Byte) in the Drives and CDrive functions.
It appears -Encoding is a dynamic parameter to Get-Content and not available to all -Path supplied
The type for the variable supplied as path should be [System.String].
I'm not sure what where to go from here.. Potentially for next version can bake in some error handling that says
if -Encodning can't be found, skip skip the object and continue the foreach, but I couldn't find a way to make it work.

I would like to be able to re-enable the try, and finally, as the finally will execute Remove-PSSession even if someone
ctrl+C's out of the command which will tear down the session and give the host back all of its resources.
#>

#try{
    $ExportedVars = StatusCheck
    $RemoteHostname = $ExportedVars.RemoteHostname
    $RemoteUserHomeDir = (Get-ADUser "$($ExportedVars.RemoteUser -replace '^GOLD\\','')" -Properties HomeDirectory).HomeDirectory
    $RemoteSession = New-PSSession -ComputerName $RemoteHostname
    Menu
#} catch{
    Write-Host "A terminating error occured. Please record the following for the author...`n`n" -ForegroundColor Black -BackgroundColor Red
    Write-Host $_.ScriptStackTrace
    Write-Host $_
    Write-Host $_.ErrorDetails
#} finally{
    Exit-PSSession -ErrorAction SilentlyContinue
    Remove-PSSession -Session $RemoteSession
#}
# SIG # Begin signature block
# MIIbFAYJKoZIhvcNAQcCoIIbBTCCGwECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUFG0MeWh+wzBqqlMa4zig8ihv
# GL6gghaHMIIEhzCCA2+gAwIBAgIDFb30MA0GCSqGSIb3DQEBCwUAMFoxCzAJBgNV
# BAYTAlVTMRgwFgYDVQQKDA9VLlMuIEdvdmVybm1lbnQxDDAKBgNVBAsMA0RvRDEM
# MAoGA1UECwwDUEtJMRUwEwYDVQQDDAxET0QgSUQgQ0EtNDkwHhcNMTkwNzA5MDAw
# MDAwWhcNMjExMDMxMjM1OTU5WjCBhDELMAkGA1UEBhMCVVMxGDAWBgNVBAoTD1Uu
# Uy4gR292ZXJubWVudDEMMAoGA1UECxMDRG9EMQwwCgYDVQQLEwNQS0kxEzARBgNV
# BAsTCkNPTlRSQUNUT1IxKjAoBgNVBAMTIUFOREVSU09OLkpBTUVTLkVMTElPVFQu
# MTEyMzI1MDEwNTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJUCfwfq
# A7HMfik2tct9Sg57PvWkjrFHDz1ihBDiHHvALEKfWaIqUtDzrYduothihtPVpCCY
# yNvgjyZE9m2J6u3MCI+GpmS6DWNY8fQck+R70hx1Dl3heMccodUjbGxAf1QguWAW
# WO5p9N7eSuU896TNDTSL4Rj7q3Lj/zNSZ87c0tFVnLmUPK0elAHu0GqQI+M15/rJ
# ymlAZx2+TqKwaEISPOgpvnQX09jUfFrIZDxEFFjYj98tmU9DeifttZiqBLHMtvr8
# F0XLNqcx7DDfr42a2tZpk7omZOgTpqiUA6KLtvKX9hVhugwFZCGD25AmZyW+J3i/
# Y6Nx0h0ERvHGiqkCAwEAAaOCASkwggElMB8GA1UdIwQYMBaAFNhnk8pG3MmVppSz
# BBicziU6lhxNMDcGA1UdHwQwMC4wLKAqoCiGJmh0dHA6Ly9jcmwuZGlzYS5taWwv
# Y3JsL0RPRElEQ0FfNDkuY3JsMA4GA1UdDwEB/wQEAwIGwDAWBgNVHSAEDzANMAsG
# CWCGSAFlAgELKjAdBgNVHQ4EFgQUlo6WVdanfblX3qR3TwTtqB33epswZQYIKwYB
# BQUHAQEEWTBXMDMGCCsGAQUFBzAChidodHRwOi8vY3JsLmRpc2EubWlsL3NpZ24v
# RE9ESURDQV80OS5jZXIwIAYIKwYBBQUHMAGGFGh0dHA6Ly9vY3NwLmRpc2EubWls
# MBsGA1UdCQQUMBIwEAYIKwYBBQUHCQQxBBMCVVMwDQYJKoZIhvcNAQELBQADggEB
# AE8aoFJDdSPPK41fBdEa8kTAdiBIwZY/O0lB9Lcax9dgMhz/zVczOz52wEK37wzw
# wPhsbKsMION8oyXIxqdwhcpMd3J43X0oaYnazlD1ZmZcFj+gM/uDs9+/sD8UxZSz
# xXE3bK9hyiqujAIwQ9nl1z46PQN/DkvjP4G67q+rqTzKBOQV6wtVVGDL3+eDZJqV
# XBLXjesajEttjZ9SNL9EeOGTrhweqccloOt73uwcwocDJxSZ+dcD6774M5WnBdxt
# hh36tfZ+LQ2LsjmFb9N6jtjVvLdk4Z7I6P6PYdRTPNLCYpwgQmA0ltt0K1hD8wzq
# 5YIgjelDfLfRh8tjurjorMkwggS5MIIDoaADAgECAgIBJzANBgkqhkiG9w0BAQsF
# ADBbMQswCQYDVQQGEwJVUzEYMBYGA1UEChMPVS5TLiBHb3Zlcm5tZW50MQwwCgYD
# VQQLEwNEb0QxDDAKBgNVBAsTA1BLSTEWMBQGA1UEAxMNRG9EIFJvb3QgQ0EgMzAe
# Fw0xNjExMjIxMzQ4MTVaFw0yMjExMjMxMzQ4MTVaMFoxCzAJBgNVBAYTAlVTMRgw
# FgYDVQQKDA9VLlMuIEdvdmVybm1lbnQxDDAKBgNVBAsMA0RvRDEMMAoGA1UECwwD
# UEtJMRUwEwYDVQQDDAxET0QgSUQgQ0EtNDkwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDYSeAojA8KX352wgHI7a4400sqGmcXKkEAT4szz6R6S3j8cbpK
# 1pT9+aoVNGJUjRSH6130FZ7w1c5iuFBGjoVVLEGQu1Zlfw/HYgfGKpDWWetkr1SU
# KjyHcw+mI3xUSMfZs/9ZJrShkRbMQMosHm1Ip6t11z5Ava4Qdv4Z/KbqL7mo84te
# NXTQVjbgV007IdpGNBMz8t+yNagUi0dMqnkH1CiB0qfKD5aQABFi1t3Weq0Ne/oW
# mHkdpPf1ISdGFz6WStEOkNhz4cBTpfLCKT6y2C/bIWTUyEWkXn+ud0TAwshJPT6V
# KlqEkoaZi2DVUpycNyrkIRELfWCXpivt9+MDAgMBAAGjggGGMIIBgjAfBgNVHSME
# GDAWgBRsipSid7GAch2Behaq8tzOZu5FwDAdBgNVHQ4EFgQU2GeTykbcyZWmlLME
# GJzOJTqWHE0wDgYDVR0PAQH/BAQDAgGGMGcGA1UdIARgMF4wCwYJYIZIAWUCAQsk
# MAsGCWCGSAFlAgELJzALBglghkgBZQIBCyowCwYJYIZIAWUCAQs7MAwGCmCGSAFl
# AwIBAw0wDAYKYIZIAWUDAgEDETAMBgpghkgBZQMCAQMnMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwDAYDVR0kBAUwA4ABADA3BgNVHR8EMDAuMCygKqAohiZodHRwOi8vY3Js
# LmRpc2EubWlsL2NybC9ET0RST09UQ0EzLmNybDBsBggrBgEFBQcBAQRgMF4wOgYI
# KwYBBQUHMAKGLmh0dHA6Ly9jcmwuZGlzYS5taWwvaXNzdWVkdG8vRE9EUk9PVENB
# M19JVC5wN2MwIAYIKwYBBQUHMAGGFGh0dHA6Ly9vY3NwLmRpc2EubWlsMA0GCSqG
# SIb3DQEBCwUAA4IBAQBOZ89A+SiUXk8HR9L/0OueBfS2Z1LCWJ0G2uRjq8v9Xsgw
# qomTuv6EdbqT36fGKMcWPpgnX7gSWkf8/BY+yrBUiyFDEQK8kp+jc583drwyfoei
# DmRcmXl0xvS8k6lZD1SGYbab1RRn3zjvBKVtbS8wcvSm65OyjTfrm+KU87kmRqkR
# dwVd1zcsPFdbwFHk0fJo3dWa98P+oCp7gGIHHb5YDGyiVMlDkgyMbm0g3tYTpUl1
# QCboQiBu4V+8bUqJZAkseQtd1O/B1ROpf0lBizB++gLC8dGH4jaZlf7+Ifkcotxr
# Gpbxv0mccK18xIFmot0jecYgHDjy1G6XyVuuDSYnMIIGajCCBVKgAwIBAgIQAwGa
# Ajr/WLFr1tXq5hfwZjANBgkqhkiG9w0BAQUFADBiMQswCQYDVQQGEwJVUzEVMBMG
# A1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEw
# HwYDVQQDExhEaWdpQ2VydCBBc3N1cmVkIElEIENBLTEwHhcNMTQxMDIyMDAwMDAw
# WhcNMjQxMDIyMDAwMDAwWjBHMQswCQYDVQQGEwJVUzERMA8GA1UEChMIRGlnaUNl
# cnQxJTAjBgNVBAMTHERpZ2lDZXJ0IFRpbWVzdGFtcCBSZXNwb25kZXIwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCjZF38fLPggjXg4PbGKuZJdTvMbuBT
# qZ8fZFnmfGt/a4ydVfiS457VWmNbAklQ2YPOb2bu3cuF6V+l+dSHdIhEOxnJ5fWR
# n8YUOawk6qhLLJGJzF4o9GS2ULf1ErNzlgpno75hn67z/RJ4dQ6mWxT9RSOOhkRV
# fRiGBYxVh3lIRvfKDo2n3k5f4qi2LVkCYYhhchhoubh87ubnNC8xd4EwH7s2AY3v
# J+P3mvBMMWSN4+v6GYeofs/sjAw2W3rBerh4x8kGLkYQyI3oBGDbvHN0+k7Y/qpA
# 8bLOcEaD6dpAoVk62RUJV5lWMJPzyWHM0AjMa+xiQpGsAsDvpPCJEY93AgMBAAGj
# ggM1MIIDMTAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8E
# DDAKBggrBgEFBQcDCDCCAb8GA1UdIASCAbYwggGyMIIBoQYJYIZIAYb9bAcBMIIB
# kjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzCCAWQG
# CCsGAQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMA
# IABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMA
# IABhAGMAYwBlAHAAdABhAG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMA
# ZQByAHQAIABDAFAALwBDAFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkA
# bgBnACAAUABhAHIAdAB5ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgA
# IABsAGkAbQBpAHQAIABsAGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUA
# IABpAG4AYwBvAHIAcABvAHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAA
# cgBlAGYAZQByAGUAbgBjAGUALjALBglghkgBhv1sAxUwHwYDVR0jBBgwFoAUFQAS
# KxOYspkH7R7for5XDStnAs0wHQYDVR0OBBYEFGFaTSS2STKdSip5GoNL9B6Jwcp9
# MH0GA1UdHwR2MHQwOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRENBLTEuY3JsMDigNqA0hjJodHRwOi8vY3JsNC5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRBc3N1cmVkSURDQS0xLmNybDB3BggrBgEFBQcBAQRrMGkw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcw
# AoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Q0EtMS5jcnQwDQYJKoZIhvcNAQEFBQADggEBAJ0lfhszTbImgVybhs4jIA+Ah+WI
# //+x1GosMe06FxlxF82pG7xaFjkAneNshORaQPveBgGMN/qbsZ0kfv4gpFetW7ea
# sGAm6mlXIV00Lx9xsIOUGQVrNZAQoHuXx/Y/5+IRQaa9YtnwJz04HShvOlIJ8Oxw
# YtNiS7Dgc6aSwNOOMdgv420XEwbu5AO2FKvzj0OncZ0h3RTKFV2SQdr5D4HRmXQN
# JsQOfxu19aDxxncGKBXp2JPlVRbwuwqrHNtcSCdmyKOLChzlldquxC5ZoGHd2vNt
# omHpigtt7BIYvfdVVEADkitrwlHCCkivsNRu4PQUCjob4489yq9qjXvc2EQwggbN
# MIIFtaADAgECAhAG/fkDlgOt6gAK6z8nu7obMA0GCSqGSIb3DQEBBQUAMGUxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBD
# QTAeFw0wNjExMTAwMDAwMDBaFw0yMTExMTAwMDAwMDBaMGIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAOiCLZn5ysJClaWAc0Bw0p5WVFypxNJBBo/J
# M/xNRZFcgZ/tLJz4FlnfnrUkFcKYubR3SdyJxArar8tea+2tsHEx6886QAxGTZPs
# i3o2CAOrDDT+GEmC/sfHMUiAfB6iD5IOUMnGh+s2P9gww/+m9/uizW9zI/6sVgWQ
# 8DIhFonGcIj5BZd9o8dD3QLoOz3tsUGj7T++25VIxO4es/K8DCuZ0MZdEkKB4YNu
# gnM/JksUkK5ZZgrEjb7SzgaurYRvSISbT0C58Uzyr5j79s5AXVz2qPEvr+yJIvJr
# GGWxwXOt1/HYzx4KdFxCuGh+t9V3CidWfA9ipD8yFGCV/QcEogkCAwEAAaOCA3ow
# ggN2MA4GA1UdDwEB/wQEAwIBhjA7BgNVHSUENDAyBggrBgEFBQcDAQYIKwYBBQUH
# AwIGCCsGAQUFBwMDBggrBgEFBQcDBAYIKwYBBQUHAwgwggHSBgNVHSAEggHJMIIB
# xTCCAbQGCmCGSAGG/WwAAQQwggGkMDoGCCsGAQUFBwIBFi5odHRwOi8vd3d3LmRp
# Z2ljZXJ0LmNvbS9zc2wtY3BzLXJlcG9zaXRvcnkuaHRtMIIBZAYIKwYBBQUHAgIw
# ggFWHoIBUgBBAG4AeQAgAHUAcwBlACAAbwBmACAAdABoAGkAcwAgAEMAZQByAHQA
# aQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMAdABpAHQAdQB0AGUAcwAgAGEAYwBjAGUA
# cAB0AGEAbgBjAGUAIABvAGYAIAB0AGgAZQAgAEQAaQBnAGkAQwBlAHIAdAAgAEMA
# UAAvAEMAUABTACAAYQBuAGQAIAB0AGgAZQAgAFIAZQBsAHkAaQBuAGcAIABQAGEA
# cgB0AHkAIABBAGcAcgBlAGUAbQBlAG4AdAAgAHcAaABpAGMAaAAgAGwAaQBtAGkA
# dAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAAYQBuAGQAIABhAHIAZQAgAGkAbgBjAG8A
# cgBwAG8AcgBhAHQAZQBkACAAaABlAHIAZQBpAG4AIABiAHkAIAByAGUAZgBlAHIA
# ZQBuAGMAZQAuMAsGCWCGSAGG/WwDFTASBgNVHRMBAf8ECDAGAQH/AgEAMHkGCCsG
# AQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8v
# Y3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqg
# OKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURS
# b290Q0EuY3JsMB0GA1UdDgQWBBQVABIrE5iymQftHt+ivlcNK2cCzTAfBgNVHSME
# GDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQUFAAOCAQEARlA+
# ybcoJKc4HbZbKa9Sz1LpMUerVlx71Q0LQbPv7HUfdDjyslxhopyVw1Dkgrkj0bo6
# hnKtOHisdV0XFzRyR4WUVtHruzaEd8wkpfMEGVWp5+Pnq2LN+4stkMLA0rWUvV5P
# sQXSDj0aqRRbpoYxYqioM+SbOafE9c4deHaUJXPkKqvPnHZL7V/CSxbkS3BMAIke
# /MV5vEwSV/5f4R68Al2o/vsHOE8Nxl2RuQ9nRc3Wg+3nkg2NsWmMT/tZ4CMP0qqu
# AHzunEIOz5HXJ7cW7g/DvXwKoO4sCFWFIrjrGBpN/CohrUkxg0eVd3HcsRtLSxwQ
# nHcUwZ1PL1qVCCkQJjGCA/cwggPzAgEBMGEwWjELMAkGA1UEBhMCVVMxGDAWBgNV
# BAoMD1UuUy4gR292ZXJubWVudDEMMAoGA1UECwwDRG9EMQwwCgYDVQQLDANQS0kx
# FTATBgNVBAMMDERPRCBJRCBDQS00OQIDFb30MAkGBSsOAwIaBQCgWjAYBgorBgEE
# AYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMCMG
# CSqGSIb3DQEJBDEWBBSFNFZeCpZMFk9zRNf9dzEZGmN28DANBgkqhkiG9w0BAQEF
# AASCAQBiaJSt476CjMdvGVVfUTtKNgCTBdkSdaf3x2Erg+hJWn0B8QAZPAvIaAOB
# 8z5/wtxABIvye08KA/i+KZchTNOtPglAod3bxN/ajyZEr+6jlirvwvsolCgkNw06
# OsNHaSHzwMzGVVl354qUIfnl9yd2jizG/Q+OLjvj8Ly2vtCLiuGKJCPrKhb9U1XG
# 2eF4WHOAOBpqY9eVa0ZtS/yaXTm4eX/0hodbkziEB96fF3TOh6xP/zKz+iK6ACz5
# IHblL3JkVlIqYNJhxmP0+Y+J6FTpzoeXOdYmXLFz/qli6k+bvV1QOFH0so+oGb48
# XFctQRMoGygGBuzujB0lutTrnEDgoYICDzCCAgsGCSqGSIb3DQEJBjGCAfwwggH4
# AgEBMHYwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgQXNzdXJl
# ZCBJRCBDQS0xAhADAZoCOv9YsWvW1ermF/BmMAkGBSsOAwIaBQCgXTAYBgkqhkiG
# 9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yMDA1MDcxNzM4MDJa
# MCMGCSqGSIb3DQEJBDEWBBQk6HDrZ/dgMAabBZStkm9YuaaJeTANBgkqhkiG9w0B
# AQEFAASCAQA5v4rW2KKtHJ/c8HL4IAXqDCroP5I57QfKzvCFJToQJG58KeM8MDUf
# BCVu8JRKoez/2/h/26Lkxr/Zi78LChHfWhVm20g8FMAMMgvPRKPfWwZiFk2L/NJg
# psCaltLXHTUqmT6jejVG6+fV5RihIXd3T1Pi81uuA7BS4PdVpqUTiP7Q5h7fNjyG
# Fe99KtXd3bsyCKJueZDiWgPLltrK6+JrWmEFGTWV3xAOMFOVq1yfdFGE9JTxw5D1
# T63NzWZhPIdUrzAPbDKj0oPRhx51d+XI7I4sjfmEK1PKOQwAWoxKv+YKzlUNhceK
# fHW4YayQIfaP+WQhkzcstRMKxj3fvSKe
# SIG # End signature block
