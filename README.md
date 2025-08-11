RustDesk Client Generator with Encrypted Credentials
============================

This PowerShell script generates a customized RustDesk installer script and a batch file to run it with appropriate execution policy settings. It supports optional encryption of configuration data ( public key / perm password ) and optional email notification ( also can be encrypted ) after installation.

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

1.  Run the Runme.bat.

2.  Provide the requested configuration values:

    -   Version of RustDesk you want baked into the installation script   

    -   Relay server address

    -   Public key

    -   Password for RustDesk client login

    -   Optionally, choose to encrypt data and/or enable email notifications.

4.  If encrypting, provide a password to secure the configuration data.

5.  If enabling email notifications, provide SMTP and email account details.

6.  The script generates the installation files in the `ClientInstall` subfolder.

7.  Distribute the `ClientInstall` folder contents to the target machines.

8.  Run `RunMe.bat` on the target machine to launch the installer script.

9.  If you have chosen to encrypt the sensitive data ( key and password ), it will not show in your client script. Your client will need the password you set for encryption during generating the script.

Requirements
------------

-   Windows operating system with PowerShell 5.1 or higher. ( I've tested this on Windows 10 and Windows 11 )

-   Administrator privileges to run the scripts. ( Will automatically request higher privledges if you don't run as Admin )

-   SMTP credentials if using email notifications. ( I've tested with office 365 )

Notes
-----

-   The installer script handles execution policy restrictions and will prompt to set the policy if needed.

-   The batch file `RunMe.bat` launches the installer PowerShell script with execution policy bypass and keeps the window open for any messages.

-   Installation logs are saved in `rustdesk_install.log` located in the installer script folder on the target machine.

-   Email notifications send the RustDesk ID and installation logs to the configured recipient if enabled.

License
-------

This project is provided as-is under the MIT License.
