# Preview one-click entry: invoke install.ps1 with -Preview.
# $script:Preview is also honored by install.ps1 as a fallback.
$script:Preview = $true
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/yuloop/pi/main/pi-i18n/install.ps1' -UseBasicParsing))) -Preview