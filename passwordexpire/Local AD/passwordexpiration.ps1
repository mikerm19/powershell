#Simple Password Expiration Script for local Microsoft Active Directory Domains.
#Run on a non-domain controller server that has the Active Directory PowerShell module installed.
#By Michael Mason
# v1 - 8/6/2018
# v1.1 - 8/11/2022 

#Setup
$emailFrom = "from@email.com"                          #The address where the email is sending from. Visible by recepient.
$alertemail = "alert@email.com"                        #The address to send alerts to
$errorsubject = "Password expiry script error"         #The subject of the error alert emails
$smtpserver = "email.server.address"                   #The SMTP server
$warndays = 30,15,7,3                                  #Days left to send password expire warnings. A reminder email will be sent to the user on each remaining days specified. Comma separated.
$logdate = Get-Date -format yyyyMMdd                   #Format of the date for the log file name
$logpath = "$PSScriptRoot\logs\"                       #Path to the logs
$logfile = "maillog-$logdate.txt"                      #Filename of the log
$logstokeep = 30                                       #Number of old logs to keep
$logfullpath = $logpath + $logfile                     #Complete log path and filename for writing
$maxPwdAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge.Days #Get the domain policy for max password age.

#Body of the reminder email that is sent on the days specified above.
$body += "Your password is going to expire. To change your password while in the office: Press [CTRL]+[ALT]+[DELETE] and click 'Change a Password...'`n`n"
$body += "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor `n"
$body += "incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud `n"
$body += "exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure `n"
$body += "dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."
#

if (-not (Test-Path -LiteralPath $logpath)) {
     try {
        New-Item -Path $logpath -ItemType Directory -ErrorAction Stop | Out-Null
    }
    catch {
        Send-MailMessage -To $alertemail -From $emailFrom -Subject $errorsubject -Body "There was a script error. Unable to create directory. `n $($_)" -SmtpServer $smtpserver
        Write-Error -Message "Unable to create directory '$logpath'. $_" -ErrorAction Stop
    }
}

try{
    Add-Content $logfullpath "$(Get-Date): Script started."
    $adusers = Get-ADUser -filter {Enabled -eq $True -and PasswordNeverExpires -eq $False -and PasswordLastSet -gt 0 -and mail -ne $False} –Properties * | Select mail,PasswordLastSet
    If ($adusers){
        Foreach ($user in $adusers){
            Foreach ($days in $warndays){
                $daysleft=(get-date).AddDays($days-$maxPwdAge).ToShortDateString()
                    If ($user.PasswordLastSet.ToShortDateString() -eq $daysleft){
                        $subject = "Your password will expire in $days days"
                        Send-MailMessage -To $user.mail -From $emailFrom -Subject $subject -Body $body -SmtpServer $smtpserver
                        Add-Content $logfullpath "$(Get-Date): Email was sent to $($user.mail)"
                    }
            }
        }
    Get-ChildItem $logpath -Recurse| Where{-not $_.PsIsContainer}| Sort CreationTime -desc | Select -Skip $logstokeep| Remove-Item -Force
    }else{
        Add-Content $logfullpath "$(Get-Date): Script error: There was a problem getting users from AD, command returned empty."
        Send-MailMessage -To $erroremail -From $emailFrom -Subject $errorsubject -Body "There was a problem getting users from AD, command returned empty." -SmtpServer $smtpserver
    }
}
Catch{
    Send-MailMessage -To $alertemail -From $emailFrom -Subject $errorsubject -Body "There was a script error. `n $($_)" -SmtpServer $smtpserver
    Add-Content $logfullpath "$(Get-Date): Script error: $($_)"
}
Finally{
    Add-Content $logfullpath "$(Get-Date): Finished."
}