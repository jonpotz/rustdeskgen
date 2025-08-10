RustDesk Config Generator & Encrypted Installer
===============================================

A PowerShell-based solution for securely generating and deploying a preconfigured RustDesk client. The script encrypts your connection details into a standalone installer script that prompts for a decryption password during install, ensuring sensitive information remains protected.

* * * * *

Features
--------

-   Self-Elevating --- Automatically prompts for Administrator privileges (UAC) when needed.

-   Config Encryption --- Relay server, public key, and password are stored AES-256 encrypted.

-   Silent Installation --- Downloads and installs RustDesk without user interaction.

-   Automated Service Setup --- Installs and starts the RustDesk Windows service.

-   Config Injection --- Automatically writes your custom RustDesk configuration for both the service and current user.

-   Password Configuration --- Sets the RustDesk client password automatically.

-   RustDesk ID Retrieval --- Fetches the RustDesk ID after install.

-   Activity Logging --- Creates a timestamped log file of installation steps and results.

-   Post-Install Log Viewer --- Opens the log file when installation completes.

* * * * *

How It Works
------------

There are two scripts:

1.  **Generator Script** (RustDesk_Config_Generator.ps1)\
    Prompts for:

    -   Relay server

    -   Public key

    -   Client password

    -   Encryption password

    Outputs a fully self-contained encrypted installer script:

    RustDesk_Install_Encrypted.ps1

    This file is created in the same folder as the generator script.

2.  **Installer Script** (RustDesk_Install_Encrypted.ps1)

    -   Prompts the user for the encryption password during installation

    -   Decrypts and applies your custom configuration

    -   Installs RustDesk silently, configures it, and logs everything to a file

* * * * *

Usage
-----

### 1\. Run the Generator Script

Run in PowerShell:\
.\RustDesk_Config_Generator.ps1

Or right click and select Open in Powershell.

You will be prompted for:

-   Relay server (IP or domain)

-   Public key

-   Client password

-   Encryption password (needed during installation)

Output:\
RustDesk_Install_Encrypted.ps1 will be created in the same directory.

* * * * *

### 2\. Distribute the Installer

Send the encrypted installer script to the target machine.\
Share the encryption password securely (never include it in plain text in the script).

* * * * *

### 3\. Run the Installer Script on the Target Machine

Run in PowerShell:\
.\RustDesk_Install_Encrypted.ps1

or right click and select Open in Powershell.

-   Click Yes when prompted by UAC.

-   Enter the encryption password.

-   Wait for installation to complete.\
    The script will automatically open the log file.

* * * * *

Log File
--------

-   Created in the same directory where the installer script is executed.

-   Includes:

    -   Step-by-step installation details

    -   Errors (if any)

    -   The installed RustDesk ID

* * * * *

Notes
-----

-   You may need to allow script execution:\
    Set-ExecutionPolicy Bypass -Scope Process -Force

-   Windows only.

-   Tested with RustDesk 1.4.1 (update the download URL in the installer for newer versions).

* * * * *

License
-------

MIT License --- modify and distribute freely with attribution.
