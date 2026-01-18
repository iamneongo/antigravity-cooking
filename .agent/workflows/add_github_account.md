---
description: Add a new GitHub account and generate SSH key
---

1. Execute the add command. Replace placeholders with actual values.
   To auto-generate a new SSH key, leave the last argument as "".
   
   powershell -ExecutionPolicy Bypass -File c:\CongViec\Extension\scripts\gh-switch.ps1 add <ALIAS> <GIT_NAME> <GIT_EMAIL> ""

2. If a new key was generated, display the public key to copy to GitHub.
   Replace <ALIAS> with the alias used in step 1.
   
   powershell -Command "Get-Content $HOME\.ssh\id_ed25519_<ALIAS>.pub"

3. Verification (Optional): List accounts to confirm addition.
   powershell -ExecutionPolicy Bypass -File c:\CongViec\Extension\scripts\gh-switch.ps1 list
