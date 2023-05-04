# PSNative

Provides wrapper commands to launch external applications and interact with them from PowerShell.

## Installation

To install this module from the PSGallery, run the following command:

```powershell
Install-Module PSNative -Scope CurrentUser
```

## Use

> Start a process, wait for it to complete and receive results

```powershell
Invoke-NativeCommand nslookup 'wikipedia.org' '1.1.1.1'
```

```text
File     : nslookup
Success  : True
Output   : Server:  one.one.one.one
           Address:  1.1.1.1

           Name:    wikipedia.org
           Addresses:  2620:0:862:ed1a::1
                  91.198.174.192


Error    : Non-authoritative answer:

ExitCode : 0
```

> Start an interactive process

```powershell
$cmd = Start-NativeProcess cmd
$cmd.ReadOutput()
```

```text
Microsoft Windows [Version 10.0.22624.1616]
(c) Microsoft Corporation. All rights reserved.

```

```powershell
$cmd.Send("dir c:\")
$cmd.ReadOutput()
```

```text
C:\Temp>dir c:\
 Volume in drive C is Windows
 Volume Serial Number is EA0E-5651

 Directory of c:\

...
2023-04-11  23:25    <DIR>          Program Files
2023-03-22  10:16    <DIR>          Program Files (x86)
2023-01-13  14:04    <DIR>          Users
...
2023-04-26  09:48    <DIR>          Windows
               2 File(s)         19.845 bytes
              17 Dir(s)  229.840.195.584 bytes free
```

```powershell
$cmd.Stop()
```
