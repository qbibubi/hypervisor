Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart

bcdedit /set testsigning on
bcdedit /dbgsettings net hostip:10.0.2.2 port:50000 key:1.2.3.4
bcdedit /debug on

bcdedit /set recoveryenabled no
bcdedit /set bootmenupolicy legacy

Get-ComputerInfo | Select-Object HyperV*

