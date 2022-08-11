#Use this to generate the key that the passwordexpire script will use for authentication. The user you use needs an exchange mailbox/license.
#Do not leave this script saved with the actual password!
#"thepasswordhere" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File "C:\PasswordExpire\passwordsuser"
