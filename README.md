RustDesk Installer Generator
============================

This PowerShell script generates a customized RustDesk installer script and a batch file to run it with appropriate execution policy settings. It supports optional encryption of configuration data and optional email notification after installation.

Features
--------

-   Generates a PowerShell installer script with your custom RustDesk relay server, public key, and password.

-   Supports encrypting sensitive configuration data for enhanced security.

-   Supports optional email notifications to send installation logs and RustDesk ID.

-   Automatically creates a `ClientInstall` folder containing:

    -   `ClientInstall.ps1` --- the installer PowerShell script

    -   `RunMe.bat` --- a batch file that runs the installer script with proper execution policy bypass.

-   Handles PowerShell execution policy restrictions and self-elevates to Administrator when needed.

-   Automatically downloads the RustDesk installer, performs a silent install, configures the RustDesk service, and sets the password.

-   Logs installation progress and errors to `rustdesk_install.log`.

Usage
-----

1.  Run the generator script in PowerShell with administrator privileges.

2.  Provide the requested configuration values:

    -   Relay server address

    -   Public key

    -   Password for RustDesk client login

    -   Optionally, choose to encrypt data and/or enable email notifications.

3.  If encrypting, provide a password to secure the configuration data.

4.  If enabling email notifications, provide SMTP and email account details.

5.  The script generates the installation files in the `ClientInstall` subfolder.

6.  Distribute the `ClientInstall` folder contents to the target machines.

7.  Run `RunMe.bat` on the target machine to launch the installer script.

Requirements
------------

-   Windows operating system with PowerShell 5.1 or higher.

-   Administrator privileges to run the scripts.

-   Internet connection on target machine to download RustDesk installer.

-   SMTP credentials if using email notifications.

Notes
-----

-   The installer script handles execution policy restrictions and will prompt to set the policy if needed.

-   The batch file `RunMe.bat` launches the installer PowerShell script with execution policy bypass and keeps the window open for any messages.

-   Installation logs are saved in `rustdesk_install.log` located in the installer script folder on the target machine.

-   Email notifications send the RustDesk ID and installation logs to the configured recipient if enabled.

License
-------

This project is provided as-is under the MIT License. Use at your own risk.
