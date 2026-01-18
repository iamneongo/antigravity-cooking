param(
    [Parameter(Mandatory=$false, Position=0)]
    [string]$Command,

    [Parameter(Mandatory=$false, Position=1)]
    [string]$TargetAlias,

    [Parameter(ValueFromRemainingArguments=$true)]
    $RemainingArgs
)

$CONFIG_FILE = Join-Path $HOME ".gh-accounts.json"
$SSH_DIR = Join-Path $HOME ".ssh"
$SSH_CONFIG = Join-Path $SSH_DIR "config"

if (-not (Test-Path $SSH_DIR)) {
    New-Item -ItemType Directory -Path $SSH_DIR -Force | Out-Null
}

function Get-Accounts {
    if (Test-Path $CONFIG_FILE) {
        $content = Get-Content $CONFIG_FILE -Raw
        if (-not [string]::IsNullOrWhiteSpace($content)) {
            return $content | ConvertFrom-Json
        }
    }
    return @()
}

function Save-Accounts($accounts) {
    $accounts | ConvertTo-Json | Out-File $CONFIG_FILE -Encoding utf8
}

function Show-Status {
    $name = git config --global user.name
    $email = git config --global user.email
    Write-Host "`n--- Current GitHub Account ---" -ForegroundColor Cyan
    Write-Host "Name:  " -NoNewline; Write-Host $name -ForegroundColor White
    Write-Host "Email: " -NoNewline; Write-Host $email -ForegroundColor White
    
    if (Test-Path $SSH_CONFIG) {
        $content = Get-Content $SSH_CONFIG -Raw
        if ($content -match "Host github\.com\s+(?:.|\n)*?IdentityFile\s+(.*)") {
            Write-Host "SSH Identity: " -NoNewline; Write-Host $Matches[1].Trim() -ForegroundColor Gray
        }
    }
    Write-Host "----------------------------`n"
}

function Add-Account {
    param(
        [string]$Alias,
        [string]$GitName,
        [string]$GitEmail,
        [string]$SSHKeyPath
    )

    Write-Host "`n--- Add New GitHub Account ---" -ForegroundColor Cyan
    
    if ([string]::IsNullOrWhiteSpace($Alias)) { $Alias = Read-Host "Enter Account Alias (e.g., work, personal)" }
    if ([string]::IsNullOrWhiteSpace($Alias)) { Write-Host "Alias cannot be empty." -ForegroundColor Red; return }

    if ([string]::IsNullOrWhiteSpace($GitName)) { $GitName = Read-Host "Enter Git User Name" }
    if ([string]::IsNullOrWhiteSpace($GitEmail)) { $GitEmail = Read-Host "Enter Git Email" }
    if ($null -eq $SSHKeyPath) { $SSHKeyPath = Read-Host "Enter path to SSH private key (leave empty to generate new)" }

    if ([string]::IsNullOrWhiteSpace($SSHKeyPath)) {
        $sshKeyName = "id_ed25519_$Alias"
        $sshPath = Join-Path $SSH_DIR $sshKeyName
        Write-Host "Generating new SSH key at $sshPath..." -ForegroundColor Yellow
        ssh-keygen -t ed25519 -C $GitEmail -f $sshPath -N '""'
        $SSHKeyPath = $sshPath
        Write-Host "`nSUCCESS: New SSH key generated." -ForegroundColor Green
        Write-Host "PLEASE ADD THIS PUBLIC KEY TO YOUR GITHUB SETTINGS ($Alias):" -ForegroundColor White
        Write-Host "------------------------------------------------------------"
        Get-Content "$sshPath.pub" | Write-Host -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
    }

    $accounts = Get-Accounts
    if ($accounts) {
        $existing = $accounts | Where-Object { $_.Alias -eq $Alias }
        if ($existing) {
            Write-Host "Account with alias '$Alias' already exists. Overwriting..." -ForegroundColor Yellow
            $accounts = $accounts | Where-Object { $_.Alias -ne $Alias }
        }
    }

    $newAccount = [PSCustomObject]@{
        Alias = $Alias
        GitName = $GitName
        GitEmail = $GitEmail
        SSHKey = $SSHKeyPath
    }
    
    if ($accounts) {
        if ($accounts -is [Array]) {
            $accounts += $newAccount
        } else {
            $accounts = @($accounts, $newAccount)
        }
    } else {
        $accounts = @($newAccount)
    }

    Save-Accounts $accounts
    Write-Host "Account '$Alias' saved!" -ForegroundColor Green
}

function List-Accounts {
    $accounts = Get-Accounts
    if (-not $accounts -or $accounts.Count -eq 0) {
        Write-Host "No accounts saved yet. Use 'add' to add one." -ForegroundColor Yellow
        return
    }

    $currentEmail = git config --global user.email
    Write-Host "`n--- Saved GitHub Accounts ---" -ForegroundColor Cyan
    foreach ($acc in $accounts) {
        $isCurrent = $acc.GitEmail -eq $currentEmail
        $prefix = if ($isCurrent) { "-> " } else { "   " }
        $color = if ($isCurrent) { "Green" } else { "White" }
        Write-Host "$($prefix)$($acc.Alias.PadRight(15)) ($($acc.GitEmail))" -ForegroundColor $color
    }
    Write-Host "----------------------------`n"
}

function Switch-Account($Alias) {
    if ([string]::IsNullOrWhiteSpace($Alias)) {
        Write-Host "Error: Please specify an account alias." -ForegroundColor Red
        Write-Host "Usage: ./gh-switch.ps1 switch <alias>"
        return
    }

    $accounts = Get-Accounts
    $target = $accounts | Where-Object { $_.Alias -eq $Alias }

    if (-not $target) {
        Write-Host "Error: Account '$Alias' not found." -ForegroundColor Red
        return
    }

    Write-Host "Switching to account '$Alias'..." -ForegroundColor Yellow

    git config --global user.name $target.GitName
    git config --global user.email $target.GitEmail

    $newIdentityFile = $target.SSHKey -replace '\\', '/'
    $sshBlock = "Host github.com`n  HostName github.com`n  User git`n  IdentityFile `"$newIdentityFile`""
    
    if (Test-Path $SSH_CONFIG) {
        $existingContent = Get-Content $SSH_CONFIG -Raw
        if ($existingContent -match "(?s)Host github\.com.*?(?=\r?\nHost|\z)") {
            $existingContent = [regex]::Replace($existingContent, "(?s)Host github\.com\s+.*?(?=\r?\nHost|\z)", $sshBlock)
        } else {
            $existingContent = $existingContent.Trim() + "`n`n" + $sshBlock
        }
        $existingContent | Out-File $SSH_CONFIG -Encoding Ascii
    } else {
        $sshBlock | Out-File $SSH_CONFIG -Encoding Ascii
    }

    Write-Host "SUCCESS: Switched to $($target.Alias)!" -ForegroundColor Green
    Show-Status
}

switch ($Command) {
    "status" { Show-Status }
    "add"    { 
        $AliasArg = $TargetAlias
        $NameArg = $RemainingArgs[0]
        $EmailArg = $RemainingArgs[1]
        $KeyArg = $RemainingArgs[2]
        Add-Account -Alias $AliasArg -GitName $NameArg -GitEmail $EmailArg -SSHKeyPath $KeyArg 
    }
    "list"   { List-Accounts }
    "switch" { Switch-Account $TargetAlias }
    "test"   { 
        Write-Host "Testing connection to GitHub..." -ForegroundColor Yellow
        ssh -T git@github.com
    }
    "help"   {
         Write-Host "GitHub Account Switcher Tool" -ForegroundColor Cyan
         Write-Host "Usage:"
         Write-Host "  ./gh-switch.ps1 status          - Show current active account"
         Write-Host "  ./gh-switch.ps1 list            - List all saved accounts"
         Write-Host "  ./gh-switch.ps1 add             - Add a new account (or generate SSH key)"
         Write-Host "  ./gh-switch.ps1 switch <alias>  - Switch to another account"
         Write-Host "  ./gh-switch.ps1 test            - Test SSH connection to GitHub"
    }
    default  {
        if (-not [string]::IsNullOrWhiteSpace($Command)) {
            Write-Host "Unknown command: $Command" -ForegroundColor Red
        }
        Show-Status
        List-Accounts
        Write-Host "Use './gh-switch.ps1 help' for more commands." -ForegroundColor Gray
    }
}
