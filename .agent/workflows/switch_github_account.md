---
description: Switch active GitHub account
---

1. List all available GitHub accounts to see aliases
   powershell -ExecutionPolicy Bypass -File c:\CongViec\Extension\scripts\gh-switch.ps1 list

2. Switch to the desired account (Replace <ALIAS> with the target account alias)
   powershell -ExecutionPolicy Bypass -File c:\CongViec\Extension\scripts\gh-switch.ps1 switch <ALIAS>

3. Verify the connection
   powershell -ExecutionPolicy Bypass -File c:\CongViec\Extension\scripts\gh-switch.ps1 test
