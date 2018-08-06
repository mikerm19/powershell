## Basic setup ##
$emaildefault = ""                            # Where all the emails would go for non-human accounts, E.G. IT ticket system email
$creduser = ""                                # The user for the Office365 login credentials
$credfile = "C:\PasswordExpire\passwordsuser" # The encrypted password file generated with the partner script. See PasswordKeyGenerator.ps1 to generate a new key file if the user is changed.
$expiredays = 180                             # How many days until the password expires

#Set this to other special usernames you want to go force to the default email. Don't forget to keep this list updated! Comma separated
$emailspecial = ""

## E-Mail Setup ##
# With Office365, by default the From address must match the user you logged in with. Otherwise you have to give the login account permissions to the From account.
# Valid variables: $timeleft (How much time is left), $expireupn (username that's expiring), $lastchangedate (Date password was last changed), $expiredate (Date password is expiring)
# Keep subject text with variables in single quotes. Use double quotes inside the message to quote something if needed.
#First body is for service account, geared towards what an admin would need to know, or what should be in a ticket. The second one is what the user will see.
$emailbodyserviceacct = 'This password will expire in $timeleft.</b><br><br>Username: $serviceacct<br>Password Set Date: $lastchangedate<br>Password Expire Date: $expiredate'
$emailbodyzacct = 'This is an automatically generated message. Do not reply.<br><br><b>This password will expire in $timeleft.</b><br><br><b>Please reset your password ASAP to avoid work interruptions.</b><br><br>Go to https://portal.office.com and log in with your Z account. Click on the gear icon in the upper right and select Password. Follow the prompts to change your password.<br><br><br>Username: $upn<br>Password Set Date: $lastchangedate<br>Password Expire Date: $expiredate'
$emailbody = 'This is an automatically generated message. Do not reply.<br><br><b>Your MAG password will expire in $timeleft.</b><br><br><b>Please reset your password ASAP to avoid work interruptions.</b><br><br>If you are in East Lansing or Ann Arbor offices, simply press CTRL+ALT+DEL and click "Change a password"<br><br>If you are remote, go to https://portal.office.com, log in, click on the gear icon in the upper right and select Password. Then press CTRL+ALT+DEL and click "Change a password" to change your password on your laptop.<br><br>After changing your password, you may be prompted for your new password in Office, Outlook, Skype, SharePoint, and your phone if applicable. Be sure to check "Remember password" for your convenience.<br><br>If you have any questions or need any assistance, please contact us at <a href="mailto:itsupport@medadvgrp.com">itsupport@medadvgrp.com</a>.<br><br>Username: $emailto<br>Password Set Date: $lastchangedate<br>Password Expire Date: $expiredate'
$emailfrom = ""                        # The From address for the email
$emailsmtp = "smtp.office365.com"      # The SMTP server address to send from
$emailport = 587                       # The SMTP server port

## E-Mail Subject Customization ##
$subjectoneday = 'WARNING: YOUR MAG PASSWORD WILL EXPIRE IN 1 DAY!'     # Subject for 1 day left
$subjectthreedays = 'Warning: Your MAG password will expire in 3 days!' # Subject for 3 days out
$subjectfivedays = 'Notice: Your MAG password will expire in 5 days.'   # Subject for 5 days out
$subjectoneweek = 'Notice: Your MAG password will expire in 1 week.'    # Subject for one week out
$subjectserviceacct = 'Service Account ($upn) Password Expiring'  # Subject for non-human accounts (to keep the subject the same for ticketing systems)
## End Setup ##

## Main Script ##
####################################################################################################################################

Import-Module MsOnline
$pass = Get-Content $credfile | ConvertTo-SecureString
$mycreds = New-Object System.Management.Automation.PSCredential($creduser, $pass)
Connect-MsolService -Credential $mycreds

foreach($msolUser in (Get-MSOLUser | select UserPrincipalName, LastName, lastpasswordchangetimestamp, isLicensed)){
    $lastchangedate = Get-Date $msoluser.LastPasswordChangeTimestamp
    $emailto = $msoluser.UserPrincipalName
    $expiredate = $lastchangedate.AddDays($expiredays)
    $sendemail = $false
    If ($expiredate -gt (Get-Date)){
        $daysleft = $expiredate - (Get-Date)
        If ($daysleft.Days -eq 0) {
            $sendemail = $true
            $timeleft = "1 day"
            $subject = $ExecutionContext.InvokeCommand.ExpandString($subjectoneday)
        }elseIf ($daysleft.Days -eq 2) {
            $sendemail = $true
            $timeleft = "3 days"
            $subject = $ExecutionContext.InvokeCommand.ExpandString($subjectthreedays)
        }elseIf ($daysleft.Days -eq 4){
            $sendemail = $true
            $timeleft = "5 days"
            $subject = $ExecutionContext.InvokeCommand.ExpandString($subjectfivedays)
        }elseIf ($daysleft.Days -eq 6) {
            $sendemail = $true
            $timeleft = "1 week"
            $subject = $ExecutionContext.InvokeCommand.ExpandString($subjectoneweek)
        }    
    }
    If ($sendemail -eq $true){
        $body = $ExecutionContext.InvokeCommand.ExpandString($emailbody)
        #Z account check
        $upn = $msolUser.UserPrincipalName
        $emailto = $upn
        $pos = $upn.IndexOf("@")
        $username = $upn.Substring(0, $pos)
        $domainname = $upn.Substring($pos+1)
        $lastname = $msolUser.LastName
        If ($lastname -ne $null -and $lastname.Substring($lastname.Length - 2) -like " Z"){
            $emailto = $username.Substring(0,$username.Length - 1) + "@" + $domainname
            $subject = "(Z Account) " + $subject
            $body = $ExecutionContext.InvokeCommand.ExpandString($emailbodyzacct)
        }else{
            #Service/unlicensed account check
            If ($msolUser.IsLicensed -eq $false -or $msolUser.LastName -eq "Service"){
                $serviceacct = $msolUser.UserPrincipalName
                $emailto = $emaildefault
                $subject = $ExecutionContext.InvokeCommand.ExpandString($subjectserviceacct)
                $body = $ExecutionContext.InvokeCommand.ExpandString($emailbodyserviceacct)
            }
            #Special email check
            foreach ($specialupn in $emailspecial){
                If ($upn -eq $specialupn){
                    $emailto = $emaildefault
                    $subject = $ExecutionContext.InvokeCommand.ExpandString($subjectserviceacct)
                    $body = $ExecutionContext.InvokeCommand.ExpandString($emailbodyserviceacct)
                }
            }
        }
        Send-MailMessage -To $emailto -SmtpServer $emailsmtp -Credential $mycreds -UseSsl -Port $emailport -Subject $ExecutionContext.InvokeCommand.ExpandString($subject) -Body $ExecutionContext.InvokeCommand.ExpandString($body) -From $emailfrom -BodyAsHtml
    }
}
