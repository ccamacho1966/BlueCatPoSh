# BlueCatPoSh - Our BlueCat IPAM PowerShell Library

Leveraging the BlueCat IPAM API has generally been complex in our environment so we have been experimenting with libraries to standardize and simplify this access for us. BlueCatPoSh is the 3rd generation of my local library implementation for PowerShell and I'm working to clean it up and make it useful to a larger audience.

BlueCatPoSh attempts to move beyond a simple one-for-one implementation of the IPAM API and incorporate sanity and prerequisite testing at the most basic level. There are a few more robust functions to simplify or expand the data collection/update process as well.

This library is still very much an imperfect work in progress, but I am still actively working on it.

## Supported Environments

BlueCatPoSh has been tested with PowerShell v5.1 on Windows.

The library is known to work with BlueCat v9.4 and v9.6 at this time.

## Installation

Manual installation at this time.

## Usage

BlueCatPoSh uses PowerShell classes. The 'using' command is how you should load such modules:
``` powershell
using module BlueCatPoSh
```

Using Import-Module or #Requires will not properly load the required classes and will impact your ability to fully use the module.

As this module uses the IPAM API, any connection must be with an API authorized account.

To create a new BlueCat session, use the following command:
``` powershell
# API enabled username and password for your IPAM appliance
$bcCredential = Get-Credential

# Create an API session with your IPAM appliance
Connect-BlueCat -Server 'ipam.example.com' -Credential $bcCredential
```

Your session will be stored in the $BlueCatSession variable. This session will be used as the default if you do not specify a session for other library cmdlets. You can create non-default sessions by using the -PassThru flag and catching the session variable as a return value.

For more information see:

``` powershell
Get-Help Connect-BlueCat -Full
```

You can also set a default View or Configuration. Setting these will establish defaults for any library cmdlet that requires a View or Configuration parameter. For example:

``` powershell
Set-BlueCatConfig -Name 'CORPORATE'
```

Will update the default $BlueCatSession object with the name and entity ID of your chosen Configuration.

Similarly, you can set a default View instead:

``` powershell
Set-BlueCatView -Name 'Developers'
```

This will update the default $BlueCatSession object with the name and entity ID of your chosen View. To set the View by name you must set the default Configuration first.

> [!IMPORTANT]
> Names of Configurations and Views are case-sensitive.

Alternatively you can set the View directly by Entity ID:

``` powershell
Set-BlueCatView -ID 23456
```

This will set both the default View as well as the default Configuration since the library can do the lookup directly by Entity ID.

To get lists of all available Configurations or Views:

``` powershell
# Get a list of all available Configurations
Get-BlueCatConfig -All

# Get a list of all available Views in your default Configuration
Get-BlueCatView -All

# Get a list of all available Views in all available Configurations
Get-BlueCatView -All -EveryConfig
```

## Support

I have a small team that assists me with the support of our tools and libraries. Please feel free to log issues/bugs and feature requests. Code contributions are welcome as well. We'll respond as quickly as time permits.
