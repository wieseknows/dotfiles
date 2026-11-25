# Dotfiles GUI Setup Wizard (WPF)
# Runs on Windows PowerShell 5.1+ / PowerShell 7+ with -STA.

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$ErrorActionPreference = "Stop"

$DotfilesDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$HomeDir = $env:USERPROFILE
$BashrcLocalPath = Join-Path $HomeDir ".bashrc.local"

function Convert-WindowsPathToGitBash {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }

    $trimmed = $Path.Trim()
    # Preserve bash-style paths and $HOME references as-is
    if ($trimmed.StartsWith("/") -or $trimmed.StartsWith('$HOME')) {
        return ($trimmed -replace '\\', '/')
    }

    $normalized = $trimmed -replace '\\', '/'
    $homeNorm = ($HomeDir -replace '\\', '/').TrimEnd('/')
    if ($normalized.StartsWith($homeNorm + "/", [System.StringComparison]::OrdinalIgnoreCase)) {
        return '$HOME/' + $normalized.Substring($homeNorm.Length + 1)
    }

    if ($normalized -match '^([A-Za-z]):/(.*)$') {
        $drive = $Matches[1].ToLowerInvariant()
        $rest = $Matches[2]
        return "/$drive/$rest"
    }

    return $normalized
}

function Convert-GitBashPathToWindows {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }

    $p = $Path.Trim()
    if ($p.StartsWith('$HOME/')) {
        $p = Join-Path $HomeDir ($p.Substring(6) -replace '/', '\')
        return $p
    }
    if ($p.StartsWith('~/')) {
        $p = Join-Path $HomeDir ($p.Substring(2) -replace '/', '\')
        return $p
    }
    if ($p -match '^/([A-Za-z])/(.*)$') {
        return ($Matches[1].ToUpperInvariant() + ":\" + ($Matches[2] -replace '/', '\'))
    }
    return ($p -replace '/', '\')
}

function Find-GitBash {
    $candidates = @(
        "C:\Program Files\Git\bin\bash.exe",
        (Join-Path $env:LOCALAPPDATA "Programs\Git\bin\bash.exe"),
        "C:\Program Files (x86)\Git\bin\bash.exe"
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }

    $gitCmd = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $gitRoot = Split-Path (Split-Path $gitCmd.Source -Parent) -Parent
        foreach ($rel in @("bin\bash.exe", "usr\bin\bash.exe")) {
            $p = Join-Path $gitRoot $rel
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}

function Unquote-BashValue {
    param([string]$Raw)
    $s = $Raw.Trim()
    if ($s.Length -ge 2) {
        if (($s.StartsWith('"') -and $s.EndsWith('"')) -or ($s.StartsWith("'") -and $s.EndsWith("'"))) {
            return $s.Substring(1, $s.Length - 2)
        }
    }
    return $s
}

function Escape-BashDoubleQuoted {
    param([string]$Value)
    if ($null -eq $Value) { return "" }
    # Escape backslashes and double quotes, but preserve $HOME prefix
    $escaped = $Value -replace '\\', '\\' -replace '"', '\"'
    return $escaped
}

function Read-ExistingConfig {
    $cfg = @{
        GitUserName       = ""
        GitUserEmail      = ""
        SshKeys           = [System.Collections.Generic.List[string]]::new()
        AzureSshKey       = ""
        OpenRouterApiKey  = ""
        OpenRouterModel   = "poolside/laguna-s-2.1:free"
        GitReviewProvider = "openrouter"
        GeminiApiKey      = ""
        DeepSeekApiKey    = ""
        ProjectsRoot      = "/c/dev/projects"
        ProjectPaths      = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    if (Test-Path $BashrcLocalPath) {
        $lines = Get-Content -Path $BashrcLocalPath -Encoding UTF8
        $inSshArray = $false
        $inProjArray = $false

        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed.StartsWith("#") -or [string]::IsNullOrWhiteSpace($trimmed)) { continue }

            if ($trimmed -match '^SSH_KEYS=\(') { $inSshArray = $true; continue }
            if ($inSshArray) {
                if ($trimmed -eq ")") { $inSshArray = $false; continue }
                $val = Unquote-BashValue $trimmed
                if (-not [string]::IsNullOrWhiteSpace($val)) { $cfg.SshKeys.Add($val) }
                continue
            }

            if ($trimmed -match '^declare\s+.*PROJECT_PATHS=\(') { $inProjArray = $true; continue }
            if ($inProjArray) {
                if ($trimmed -eq ")") { $inProjArray = $false; continue }
                if ($trimmed -match '^\[([^\]]+)\]=(.+)$') {
                    $alias = Unquote-BashValue $Matches[1]
                    $rel = Unquote-BashValue $Matches[2]
                    if (-not [string]::IsNullOrWhiteSpace($alias)) {
                        $cfg.ProjectPaths.Add([PSCustomObject]@{ Alias = $alias; Path = $rel })
                    }
                }
                continue
            }

            if ($trimmed -match '^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
                $key = $Matches[1]
                $val = Unquote-BashValue $Matches[2]
                switch ($key) {
                    "GIT_USER_NAME"       { $cfg.GitUserName = $val }
                    "GIT_USER_EMAIL"      { $cfg.GitUserEmail = $val }
                    "AZURE_SSH_KEY"       { $cfg.AzureSshKey = $val }
                    "OPENROUTER_API_KEY"  { if ($val -ne "your_openrouter_api_key_here") { $cfg.OpenRouterApiKey = $val } }
                    "OPENROUTER_MODEL"    { if ($val) { $cfg.OpenRouterModel = $val } }
                    "GIT_REVIEW_PROVIDER" { if ($val) { $cfg.GitReviewProvider = $val } }
                    "GEMINI_API_KEY"      { if ($val -ne "your_gemini_api_key_here") { $cfg.GeminiApiKey = $val } }
                    "DEEPSEEK_API_KEY"    { if ($val -ne "your_deepseek_api_key_here") { $cfg.DeepSeekApiKey = $val } }
                    "PROJECTS_ROOT"       { if ($val) { $cfg.ProjectsRoot = $val } }
                }
            }
        }
    }

    # Fallback to current git config if name/email are still empty
    if ([string]::IsNullOrWhiteSpace($cfg.GitUserName)) {
        $gitName = (& git config user.name 2>$null)
        if ($gitName) { $cfg.GitUserName = $gitName.Trim() }
    }
    if ([string]::IsNullOrWhiteSpace($cfg.GitUserEmail)) {
        $gitEmail = (& git config user.email 2>$null)
        if ($gitEmail) { $cfg.GitUserEmail = $gitEmail.Trim() }
    }

    return $cfg
}

function Write-BashrcLocalFile {
    param([hashtable]$Config)

    if (Test-Path $BashrcLocalPath) {
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$BashrcLocalPath.bak.$ts"
        Copy-Item -Path $BashrcLocalPath -Destination $backupPath -Force
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("# ==============================================================================`n")
    [void]$sb.Append("# LOCAL CONFIGURATION (Generated by Dotfiles GUI Installer)`n")
    [void]$sb.Append("# ==============================================================================`n`n")

    [void]$sb.Append("# 1. Git Identity`n")
    [void]$sb.Append("export GIT_USER_NAME=`"$(Escape-BashDoubleQuoted $Config.GitUserName)`"`n")
    [void]$sb.Append("export GIT_USER_EMAIL=`"$(Escape-BashDoubleQuoted $Config.GitUserEmail)`"`n`n")

    [void]$sb.Append("# 2. SSH Keys`n")
    [void]$sb.Append("SSH_KEYS=(`n")
    foreach ($k in $Config.SshKeys) {
        $bashKey = Convert-WindowsPathToGitBash $k
        [void]$sb.Append("    `"$bashKey`"`n")
    }
    [void]$sb.Append(")`n")
    if (-not [string]::IsNullOrWhiteSpace($Config.AzureSshKey)) {
        $azureBash = Convert-WindowsPathToGitBash $Config.AzureSshKey
        [void]$sb.Append("export AZURE_SSH_KEY=`"$azureBash`"`n")
    }
    [void]$sb.Append("`n")

    [void]$sb.Append("# 3. API Keys & AI Providers`n")
    [void]$sb.Append("export GIT_REVIEW_PROVIDER=`"$(Escape-BashDoubleQuoted $Config.GitReviewProvider)`"`n")
    [void]$sb.Append("export OPENROUTER_MODEL=`"$(Escape-BashDoubleQuoted $Config.OpenRouterModel)`"`n")
    if (-not [string]::IsNullOrWhiteSpace($Config.OpenRouterApiKey)) {
        [void]$sb.Append("export OPENROUTER_API_KEY=`"$(Escape-BashDoubleQuoted $Config.OpenRouterApiKey)`"`n")
    }
    if (-not [string]::IsNullOrWhiteSpace($Config.GeminiApiKey)) {
        [void]$sb.Append("export GEMINI_API_KEY=`"$(Escape-BashDoubleQuoted $Config.GeminiApiKey)`"`n")
    }
    if (-not [string]::IsNullOrWhiteSpace($Config.DeepSeekApiKey)) {
        [void]$sb.Append("export DEEPSEEK_API_KEY=`"$(Escape-BashDoubleQuoted $Config.DeepSeekApiKey)`"`n")
    }
    [void]$sb.Append("`n")

    [void]$sb.Append("# 4. Project Navigation`n")
    $projRootBash = Convert-WindowsPathToGitBash $Config.ProjectsRoot
    [void]$sb.Append("export PROJECTS_ROOT=`"$projRootBash`"`n`n")
    [void]$sb.Append("declare -g -A PROJECT_PATHS=(`n")
    foreach ($item in $Config.ProjectPaths) {
        $a = Escape-BashDoubleQuoted $item.Alias
        $p = Escape-BashDoubleQuoted ($item.Path -replace '\\', '/')
        [void]$sb.Append("    [`"$a`"]=`"$p`"`n")
    }
    [void]$sb.Append(")`n")

    # Write UTF-8 without BOM and LF line endings for Git Bash compatibility
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($BashrcLocalPath, $sb.ToString(), $utf8NoBom)
}

function Show-OpenFileDialog {
    param([string]$Title, [string]$InitialDir)
    $dlg = [Microsoft.Win32.OpenFileDialog]::new()
    $dlg.Title = $Title
    $dlg.Filter = "All files (*.*)|*.*"
    if (-not [string]::IsNullOrWhiteSpace($InitialDir) -and (Test-Path $InitialDir)) {
        $dlg.InitialDirectory = $InitialDir
    }
    if ($dlg.ShowDialog() -eq $true) {
        return $dlg.FileName
    }
    return $null
}

function Show-FolderDialog {
    param([string]$Description, [string]$InitialPath)
    $dlg = [System.Windows.Forms.FolderBrowserDialog]::new()
    $dlg.Description = $Description
    if (-not [string]::IsNullOrWhiteSpace($InitialPath) -and (Test-Path $InitialPath)) {
        $dlg.SelectedPath = $InitialPath
    }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dlg.SelectedPath
    }
    return $null
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Dotfiles Setup Wizard"
        Height="640" Width="760"
        MinHeight="560" MinWidth="680"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E2E" Foreground="#CDD6F4"
        FontFamily="Segoe UI" FontSize="13">
    <Window.Resources>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#CDD6F4"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="CaretBrush" Value="#89B4FA"/>
        </Style>
        <Style TargetType="PasswordBox">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#1E1E2E"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="Padding" Value="8,5"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#313244"/>
            <Setter Property="Foreground" Value="#CDD6F4"/>
            <Setter Property="BorderBrush" Value="#45475A"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="Background" Value="#252538"/>
            <Setter Property="Foreground" Value="#A6ADC8"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
    </Window.Resources>

    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Grid.Row="0" Margin="0,0,0,14">
            <TextBlock Text="Dotfiles Setup Wizard" FontSize="22" FontWeight="Bold" Foreground="#89B4FA"/>
            <TextBlock Text="Configure Git identity, SSH keys, AI API tokens, and project shortcuts without editing local files manually."
                       Foreground="#A6ADC8" Margin="0,4,0,0"/>
        </StackPanel>

        <!-- Main Tabs -->
        <TabControl x:Name="MainTabs" Grid.Row="1" Background="#252538" BorderBrush="#45475A">
            <!-- Tab 1: Git & SSH -->
            <TabItem Header="Git &amp; SSH">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="14">
                    <StackPanel>
                        <TextBlock Text="Git Identity" FontSize="15" FontWeight="SemiBold" Foreground="#89B4FA" Margin="0,0,0,8"/>
                        <Grid Margin="0,0,0,14">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Grid.Column="0">
                                <TextBlock Text="User Name (GIT_USER_NAME)" Margin="0,0,0,4" Foreground="#A6ADC8"/>
                                <TextBox x:Name="TxtGitName"/>
                            </StackPanel>
                            <StackPanel Grid.Column="2">
                                <TextBlock Text="Email (GIT_USER_EMAIL)" Margin="0,0,0,4" Foreground="#A6ADC8"/>
                                <TextBox x:Name="TxtGitEmail"/>
                            </StackPanel>
                        </Grid>

                        <TextBlock Text="SSH Keys (OpenSSH format, loaded into ssh-agent)" FontSize="15" FontWeight="SemiBold" Foreground="#89B4FA" Margin="0,4,0,8"/>
                        <ListBox x:Name="LstSshKeys" Height="130" Background="#1E1E2E" Foreground="#CDD6F4" BorderBrush="#45475A" Margin="0,0,0,8"/>
                        <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
                            <Button x:Name="BtnAddSshKey" Content="Browse &amp; Add Key..." Margin="0,0,8,0"/>
                            <Button x:Name="BtnRemoveSshKey" Content="Remove Selected"/>
                        </StackPanel>
                        <TextBlock x:Name="TxtPpkWarning" Text="" Foreground="#F9E2AF" TextWrapping="Wrap" Margin="0,0,0,12"/>

                        <TextBlock Text="Azure DevOps SSH Key (optional)" FontSize="15" FontWeight="SemiBold" Foreground="#89B4FA" Margin="0,4,0,8"/>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBox x:Name="TxtAzureSshKey" Grid.Column="0"/>
                            <Button x:Name="BtnBrowseAzureKey" Grid.Column="1" Content="Browse..." Margin="8,0,0,0"/>
                            <Button x:Name="BtnClearAzureKey" Grid.Column="2" Content="Clear" Margin="6,0,0,0"/>
                        </Grid>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- Tab 2: AI & API Keys -->
            <TabItem Header="AI &amp; API Keys">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="14">
                    <StackPanel>
                        <TextBlock Text="GitReview / AI Provider Settings" FontSize="15" FontWeight="SemiBold" Foreground="#89B4FA" Margin="0,0,0,8"/>
                        <TextBlock Text="Leave API key fields blank if you do not use that provider." Foreground="#A6ADC8" Margin="0,0,0,12"/>

                        <Grid Margin="0,0,0,12">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="12"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Grid.Column="0">
                                <TextBlock Text="Default Provider (GIT_REVIEW_PROVIDER)" Margin="0,0,0,4" Foreground="#A6ADC8"/>
                                <ComboBox x:Name="CmbProvider" IsEditable="True">
                                    <ComboBoxItem Content="openrouter"/>
                                    <ComboBoxItem Content="gemini"/>
                                    <ComboBoxItem Content="deepseek"/>
                                </ComboBox>
                            </StackPanel>
                            <StackPanel Grid.Column="2">
                                <TextBlock Text="OpenRouter Model (OPENROUTER_MODEL)" Margin="0,0,0,4" Foreground="#A6ADC8"/>
                                <TextBox x:Name="TxtOpenRouterModel"/>
                            </StackPanel>
                        </Grid>

                        <TextBlock Text="OpenRouter API Key (OPENROUTER_API_KEY)" Margin="0,0,0,4" Foreground="#A6ADC8"/>
                        <Grid Margin="0,0,0,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <PasswordBox x:Name="PwdOpenRouter" Grid.Column="0"/>
                            <TextBox x:Name="TxtOpenRouterVisible" Grid.Column="0" Visibility="Collapsed"/>
                            <CheckBox x:Name="ChkShowOpenRouter" Grid.Column="1" Content="Show" Margin="8,0,0,0"/>
                        </Grid>

                        <TextBlock Text="Gemini API Key (GEMINI_API_KEY)" Margin="0,0,0,4" Foreground="#A6ADC8"/>
                        <Grid Margin="0,0,0,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <PasswordBox x:Name="PwdGemini" Grid.Column="0"/>
                            <TextBox x:Name="TxtGeminiVisible" Grid.Column="0" Visibility="Collapsed"/>
                            <CheckBox x:Name="ChkShowGemini" Grid.Column="1" Content="Show" Margin="8,0,0,0"/>
                        </Grid>

                        <TextBlock Text="DeepSeek API Key (DEEPSEEK_API_KEY)" Margin="0,0,0,4" Foreground="#A6ADC8"/>
                        <Grid Margin="0,0,0,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <PasswordBox x:Name="PwdDeepSeek" Grid.Column="0"/>
                            <TextBox x:Name="TxtDeepSeekVisible" Grid.Column="0" Visibility="Collapsed"/>
                            <CheckBox x:Name="ChkShowDeepSeek" Grid.Column="1" Content="Show" Margin="8,0,0,0"/>
                        </Grid>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- Tab 3: Projects & Tools -->
            <TabItem Header="Projects &amp; Tools">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="14">
                    <StackPanel>
                        <TextBlock Text="Project Navigation (`proj &lt;alias&gt;`)" FontSize="15" FontWeight="SemiBold" Foreground="#89B4FA" Margin="0,0,0,8"/>
                        <TextBlock Text="Projects Root (PROJECTS_ROOT)" Margin="0,0,0,4" Foreground="#A6ADC8"/>
                        <Grid Margin="0,0,0,12">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBox x:Name="TxtProjectsRoot" Grid.Column="0"/>
                            <Button x:Name="BtnBrowseProjectsRoot" Grid.Column="1" Content="Browse Folder..." Margin="8,0,0,0"/>
                        </Grid>

                        <TextBlock Text="Configured Project Aliases" Margin="0,0,0,4" Foreground="#A6ADC8"/>
                        <ListView x:Name="LvProjects" Height="150" Background="#1E1E2E" Foreground="#CDD6F4" BorderBrush="#45475A" Margin="0,0,0,8">
                            <ListView.View>
                                <GridView>
                                    <GridViewColumn Header="Alias" Width="140" DisplayMemberBinding="{Binding Alias}"/>
                                    <GridViewColumn Header="Relative Path (inside PROJECTS_ROOT)" Width="460" DisplayMemberBinding="{Binding Path}"/>
                                </GridView>
                            </ListView.View>
                        </ListView>

                        <Grid Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="130"/>
                                <ColumnDefinition Width="8"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBox x:Name="TxtNewAlias" Grid.Column="0" ToolTip="Alias (e.g. app)"/>
                            <TextBox x:Name="TxtNewProjPath" Grid.Column="2" ToolTip="Relative path (e.g. my-app/web)"/>
                            <Button x:Name="BtnBrowseProjectSubdir" Grid.Column="3" Content="..." Margin="6,0,0,0" ToolTip="Pick project folder"/>
                            <Button x:Name="BtnAddProject" Grid.Column="4" Content="Add" Margin="6,0,0,0"/>
                            <Button x:Name="BtnRemoveProject" Grid.Column="5" Content="Remove" Margin="6,0,0,0"/>
                        </Grid>

                        <TextBlock Text="Optional Tools" FontSize="15" FontWeight="SemiBold" Foreground="#89B4FA" Margin="0,8,0,8"/>
                        <CheckBox x:Name="ChkInstallGitReview" Content="Install / Update wieseknows.GitReview (.NET global tool)" IsChecked="True"/>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>

            <!-- Tab 4: Install Log -->
            <TabItem Header="Install Log" x:Name="TabLog">
                <Grid Margin="14">
                    <TextBox x:Name="TxtLog" IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                             TextWrapping="Wrap" FontFamily="Consolas" FontSize="12" Background="#11111B" Foreground="#A6E3A1"/>
                </Grid>
            </TabItem>
        </TabControl>

        <!-- Footer -->
        <Grid Grid.Row="2" Margin="0,14,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="TxtStatus" Grid.Column="0" VerticalAlignment="Center" Foreground="#A6ADC8" Text="Ready to configure."/>
            <Button x:Name="BtnInstall" Grid.Column="1" Content="Install &amp; Apply" Background="#89B4FA" Foreground="#11111B"
                    FontWeight="Bold" Padding="18,8" BorderThickness="0" Margin="0,0,8,0"/>
            <Button x:Name="BtnClose" Grid.Column="2" Content="Close" Padding="16,8"/>
        </Grid>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Bind controls
$mainTabs              = $window.FindName("MainTabs")
$tabLog                = $window.FindName("TabLog")
$txtGitName            = $window.FindName("TxtGitName")
$txtGitEmail           = $window.FindName("TxtGitEmail")
$lstSshKeys            = $window.FindName("LstSshKeys")
$btnAddSshKey          = $window.FindName("BtnAddSshKey")
$btnRemoveSshKey       = $window.FindName("BtnRemoveSshKey")
$txtPpkWarning         = $window.FindName("TxtPpkWarning")
$txtAzureSshKey        = $window.FindName("TxtAzureSshKey")
$btnBrowseAzureKey     = $window.FindName("BtnBrowseAzureKey")
$btnClearAzureKey      = $window.FindName("BtnClearAzureKey")
$cmbProvider           = $window.FindName("CmbProvider")
$txtOpenRouterModel    = $window.FindName("TxtOpenRouterModel")
$pwdOpenRouter         = $window.FindName("PwdOpenRouter")
$txtOpenRouterVisible  = $window.FindName("TxtOpenRouterVisible")
$chkShowOpenRouter     = $window.FindName("ChkShowOpenRouter")
$pwdGemini             = $window.FindName("PwdGemini")
$txtGeminiVisible      = $window.FindName("TxtGeminiVisible")
$chkShowGemini         = $window.FindName("ChkShowGemini")
$pwdDeepSeek           = $window.FindName("PwdDeepSeek")
$txtDeepSeekVisible    = $window.FindName("TxtDeepSeekVisible")
$chkShowDeepSeek       = $window.FindName("ChkShowDeepSeek")
$txtProjectsRoot       = $window.FindName("TxtProjectsRoot")
$btnBrowseProjectsRoot = $window.FindName("BtnBrowseProjectsRoot")
$lvProjects            = $window.FindName("LvProjects")
$txtNewAlias           = $window.FindName("TxtNewAlias")
$txtNewProjPath        = $window.FindName("TxtNewProjPath")
$btnBrowseProjectSubdir = $window.FindName("BtnBrowseProjectSubdir")
$btnAddProject         = $window.FindName("BtnAddProject")
$btnRemoveProject      = $window.FindName("BtnRemoveProject")
$chkInstallGitReview   = $window.FindName("ChkInstallGitReview")
$txtLog                = $window.FindName("TxtLog")
$txtStatus             = $window.FindName("TxtStatus")
$btnInstall            = $window.FindName("BtnInstall")
$btnClose              = $window.FindName("BtnClose")

function Bind-PasswordToggle {
    param($PasswordBox, $TextBox, $CheckBox)
    $CheckBox.Add_Checked({
        $TextBox.Text = $PasswordBox.Password
        $PasswordBox.Visibility = "Collapsed"
        $TextBox.Visibility = "Visible"
    }.GetNewClosure())
    $CheckBox.Add_Unchecked({
        $PasswordBox.Password = $TextBox.Text
        $TextBox.Visibility = "Collapsed"
        $PasswordBox.Visibility = "Visible"
    }.GetNewClosure())
}

function Get-SecretValue {
    param($PasswordBox, $TextBox, $CheckBox)
    if ($CheckBox.IsChecked) { return $TextBox.Text.Trim() }
    return $PasswordBox.Password.Trim()
}

Bind-PasswordToggle $pwdOpenRouter $txtOpenRouterVisible $chkShowOpenRouter
Bind-PasswordToggle $pwdGemini $txtGeminiVisible $chkShowGemini
Bind-PasswordToggle $pwdDeepSeek $txtDeepSeekVisible $chkShowDeepSeek

# Load initial config
$initial = Read-ExistingConfig
$txtGitName.Text = $initial.GitUserName
$txtGitEmail.Text = $initial.GitUserEmail
foreach ($k in $initial.SshKeys) { [void]$lstSshKeys.Items.Add($k) }
$txtAzureSshKey.Text = $initial.AzureSshKey
$cmbProvider.Text = $initial.GitReviewProvider
$txtOpenRouterModel.Text = $initial.OpenRouterModel
$pwdOpenRouter.Password = $initial.OpenRouterApiKey
$pwdGemini.Password = $initial.GeminiApiKey
$pwdDeepSeek.Password = $initial.DeepSeekApiKey
$txtProjectsRoot.Text = $initial.ProjectsRoot

$projectsCollection = [System.Collections.ObjectModel.ObservableCollection[PSCustomObject]]::new()
foreach ($p in $initial.ProjectPaths) { $projectsCollection.Add($p) }
$lvProjects.ItemsSource = $projectsCollection

function Update-PpkWarning {
    $hasPpk = $false
    foreach ($item in $lstSshKeys.Items) {
        if ($item.ToString().EndsWith(".ppk", [System.StringComparison]::OrdinalIgnoreCase)) {
            $hasPpk = $true
            break
        }
    }
    if ($hasPpk) {
        $txtPpkWarning.Text = "Warning: .ppk (PuTTY) keys are not supported by OpenSSH. Export them as OpenSSH keys in PuTTYgen."
    } else {
        $txtPpkWarning.Text = ""
    }
}
Update-PpkWarning

# Event handlers
$btnAddSshKey.Add_Click({
    $sshDir = Join-Path $HomeDir ".ssh"
    $startDir = if (Test-Path $sshDir) { $sshDir } else { $HomeDir }
    $file = Show-OpenFileDialog -Title "Select OpenSSH Private Key" -InitialDir $startDir
    if ($file) {
        $bashPath = Convert-WindowsPathToGitBash $file
        if (-not $lstSshKeys.Items.Contains($bashPath)) {
            [void]$lstSshKeys.Items.Add($bashPath)
            Update-PpkWarning
        }
    }
})

$btnRemoveSshKey.Add_Click({
    if ($lstSshKeys.SelectedIndex -ge 0) {
        $lstSshKeys.Items.RemoveAt($lstSshKeys.SelectedIndex)
        Update-PpkWarning
    }
})

$btnBrowseAzureKey.Add_Click({
    $sshDir = Join-Path $HomeDir ".ssh"
    $startDir = if (Test-Path $sshDir) { $sshDir } else { $HomeDir }
    $file = Show-OpenFileDialog -Title "Select Azure DevOps SSH Key" -InitialDir $startDir
    if ($file) {
        $txtAzureSshKey.Text = Convert-WindowsPathToGitBash $file
    }
})

$btnClearAzureKey.Add_Click({ $txtAzureSshKey.Text = "" })

$btnBrowseProjectsRoot.Add_Click({
    $winCurrent = Convert-GitBashPathToWindows $txtProjectsRoot.Text
    $folder = Show-FolderDialog -Description "Select Projects Root Folder" -InitialPath $winCurrent
    if ($folder) {
        $txtProjectsRoot.Text = Convert-WindowsPathToGitBash $folder
    }
})

$btnBrowseProjectSubdir.Add_Click({
    $winRoot = Convert-GitBashPathToWindows $txtProjectsRoot.Text
    $folder = Show-FolderDialog -Description "Select Project Folder" -InitialPath $winRoot
    if ($folder) {
        if (-not [string]::IsNullOrWhiteSpace($winRoot) -and $folder.StartsWith($winRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $rel = $folder.Substring($winRoot.Length).TrimStart('\', '/') -replace '\\', '/'
            $txtNewProjPath.Text = $rel
        } else {
            $txtNewProjPath.Text = Convert-WindowsPathToGitBash $folder
        }
        if ([string]::IsNullOrWhiteSpace($txtNewAlias.Text)) {
            $txtNewAlias.Text = (Split-Path $folder -Leaf).ToLowerInvariant()
        }
    }
})

$btnAddProject.Add_Click({
    $alias = $txtNewAlias.Text.Trim()
    $path = ($txtNewProjPath.Text.Trim() -replace '\\', '/')
    if ([string]::IsNullOrWhiteSpace($alias) -or [string]::IsNullOrWhiteSpace($path)) {
        [System.Windows.MessageBox]::Show("Please enter both an alias and a relative path.", "Validation", "OK", "Warning") | Out-Null
        return
    }
    for ($i = 0; $i -lt $projectsCollection.Count; $i++) {
        if ($projectsCollection[$i].Alias -eq $alias) {
            $projectsCollection.RemoveAt($i)
            break
        }
    }
    $projectsCollection.Add([PSCustomObject]@{ Alias = $alias; Path = $path })
    $txtNewAlias.Text = ""
    $txtNewProjPath.Text = ""
})

$btnRemoveProject.Add_Click({
    if ($lvProjects.SelectedIndex -ge 0) {
        $projectsCollection.RemoveAt($lvProjects.SelectedIndex)
    }
})

$btnClose.Add_Click({ $window.Close() })

$btnInstall.Add_Click({
    $gitName = $txtGitName.Text.Trim()
    $gitEmail = $txtGitEmail.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($gitName) -or [string]::IsNullOrWhiteSpace($gitEmail)) {
        [System.Windows.MessageBox]::Show("Git User Name and Email are required.", "Missing Git Identity", "OK", "Warning") | Out-Null
        $mainTabs.SelectedIndex = 0
        return
    }

    $gitBash = Find-GitBash
    if (-not $gitBash) {
        [System.Windows.MessageBox]::Show("Git Bash (bash.exe) was not found. Please install Git for Windows.", "Missing Git Bash", "OK", "Error") | Out-Null
        return
    }

    $btnInstall.IsEnabled = $false
    $txtStatus.Text = "Applying configuration..."
    $mainTabs.SelectedItem = $tabLog
    $txtLog.Text = "Writing $BashrcLocalPath ...`r`n"

    try {
        $sshList = [System.Collections.Generic.List[string]]::new()
        foreach ($item in $lstSshKeys.Items) { $sshList.Add($item.ToString()) }

        $cfgToWrite = @{
            GitUserName       = $gitName
            GitUserEmail      = $gitEmail
            SshKeys           = $sshList
            AzureSshKey       = $txtAzureSshKey.Text.Trim()
            GitReviewProvider = $cmbProvider.Text.Trim()
            OpenRouterModel   = $txtOpenRouterModel.Text.Trim()
            OpenRouterApiKey  = Get-SecretValue $pwdOpenRouter $txtOpenRouterVisible $chkShowOpenRouter
            GeminiApiKey      = Get-SecretValue $pwdGemini $txtGeminiVisible $chkShowGemini
            DeepSeekApiKey    = Get-SecretValue $pwdDeepSeek $txtDeepSeekVisible $chkShowDeepSeek
            ProjectsRoot      = $txtProjectsRoot.Text.Trim()
            ProjectPaths      = $projectsCollection
        }

        Write-BashrcLocalFile -Config $cfgToWrite
        $txtLog.AppendText("Saved ~/.bashrc.local successfully.`r`n")
        $txtLog.AppendText("Running install.sh via $gitBash ...`r`n`r`n")

        $installSh = (Join-Path $DotfilesDir "install.sh") -replace '\\', '/'
        $env:NONINTERACTIVE = "1"
        $env:FORCE_SYNC_GIT_IDENTITY = "1"
        $env:INSTALL_GITREVIEW = if ($chkInstallGitReview.IsChecked) { "1" } else { "0" }

        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $gitBash
        $psi.Arguments = "`"$installSh`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        if ($stdout) { $txtLog.AppendText($stdout + "`r`n") }
        if ($stderr) { $txtLog.AppendText("STDERR:`r`n" + $stderr + "`r`n") }

        if ($proc.ExitCode -eq 0) {
            $txtStatus.Text = "Installation completed successfully."
        } else {
            $txtStatus.Text = "install.sh exited with code $($proc.ExitCode)."
        }
    }
    catch {
        $txtLog.AppendText("ERROR: $($_.Exception.Message)`r`n")
        $txtStatus.Text = "Installation failed."
    }
    finally {
        $btnInstall.IsEnabled = $true
        $txtLog.ScrollToEnd()
    }
})

[void]$window.ShowDialog()

