# PSScriptSigning
 
A PowerShell GUI (WPF) for signing PowerShell scripts with a code-signing certificate and for managing self-signed code-signing certificates.
 
> **Warning:** Do not use in a production environment until you have tested it thoroughly in a lab environment. Use at your own risk.
 
## Features
 
- List certificates with code-signing usage from the current user's certificate store
  (columns: Thumbprint, FriendlyName, NotAfter, HashAlgorithm, KeyLength)
- Create a new self-signed code-signing certificate (validity in years)
- Remove a self-signed code-signing certificate (with confirmation prompt)
- Sign PowerShell scripts
- Test script signatures
## Requirements
 
- Windows with PowerShell and WPF support (the script loads `PresentationFramework`, `PresentationCore` and `System.Windows.Forms`)
- Must be run **as Administrator** (`#Requires -RunAsAdministrator`)
## Project structure
 
The script expects the following layout next to `PSScriptSigning.ps1`:
 
```
PSScriptSigning.ps1
├── xaml\PSScriptSigning.xaml        # GUI definition
├── config\PSScriptSigning.json      # Configuration
├── config\Style.json                # Style settings
├── module\*.psm1                    # PowerShell modules (imported automatically)
└── images\                          # Ribbon icons
```
 
## Usage
 
1. Open PowerShell **as Administrator**.
2. Run the script:
```powershell
.\PSScriptSigning.ps1
```
 
3. The GUI opens maximized. Use the ribbon buttons:
   | Button | Action |
   |---|---|
   | New certificate | Create a self-signed code-signing certificate |
   | Remove certificate | Remove the selected certificate (asks for confirmation) |
   | Start signing | Sign PowerShell scripts |
   | Test signing | Test signing |
   | Exit | Close the application |
## Notes on self-signed certificates
 
- A self-signed certificate is only suitable for testing. Other machines will not trust it unless it is imported into their trusted stores.
- Never commit private keys or `.pfx` files to this repository.
- Re-sign a script after every change, otherwise the signature becomes invalid.
## Author
 
Andreas Werner, 13.11.2026
 
## License
 
`<ADD LICENSE>`
 
