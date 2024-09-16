@echo off

set basetitle=HCTSW Care Windows ISO Patcher
title %basetitle%

set path=%~dp0bin;%path%
set ISOPath=%1
set "_null=1>nul 2>nul"

echo.
echo HCTSW Care Windows ISO Patcher
echo 2015-2024 (C) Hikari Calyx Tech. All Rights Reserved.
echo Windows is a trademark of Microsoft Corporation.
echo.

::========================================================================================================================================

::  Elevate script as admin and pass arguments and preventing loop
::  Thanks to @hearywarlot [ https://forums.mydigitallife.net/threads/.74332/ ] for the VBS method.
::  Thanks to @abbodi1406 for the powershell method and solving special characters issue in file path name.

set "batf_=%~f0"
set "batp_=%batf_:'=''%"

%_null% reg query HKU\S-1-5-19 && (
goto :_Passed
) || (
if defined _elev goto :_E_Admin
)

set "_vbsf=%temp%\admin.vbs"
set _PSarg="""%~f0"""

setlocal EnableDelayedExpansion
(
echo Set strArg=WScript.Arguments.Named
echo Set strRdlproc = CreateObject^("WScript.Shell"^).Exec^("rundll32 kernel32,Sleep"^)
echo With GetObject^("winmgmts:\\.\root\CIMV2:Win32_Process.Handle='" ^& strRdlproc.ProcessId ^& "'"^)
echo With GetObject^("winmgmts:\\.\root\CIMV2:Win32_Process.Handle='" ^& .ParentProcessId ^& "'"^)
echo If InStr ^(.CommandLine, WScript.ScriptName^) ^<^> 0 Then
echo strLine = Mid^(.CommandLine, InStr^(.CommandLine , "/File:"^) + Len^(strArg^("File"^)^) + 8^)
echo End If
echo End With
echo .Terminate
echo End With
echo CreateObject^("Shell.Application"^).ShellExecute "cmd.exe", "/c " ^& chr^(34^) ^& chr^(34^) ^& strArg^("File"^) ^& chr^(34^) ^& strLine ^& chr^(34^), "", "runas", 1
)>"!_vbsf!"

(%_null% cscript //NoLogo "!_vbsf!" /File:"!batf_!" %1) && (
del /f /q "!_vbsf!"
exit /b
) || (
del /f /q "!_vbsf!"
%_null% %_psc% "start cmd.exe -arg '/c \"!_PSarg:'=''!\"' -verb runas" && (
exit /b
) || (
goto :_E_Admin
)
)
exit /b

:_E_Admin
echo This script require administrator privileges.
echo To do so, right click on this script and select 'Run as administrator'.
pause>nul
goto PatchISOend

:_Passed
cd /d %~dp0
if exist ISOFOLDER (
echo Cleaning up file...
rd /s /q ISOFOLDER
)
if exist MountedWim rd /s /q MountedWim
if exist WIMFOLDER rd /s /q WIMFOLDER

::========================================================================================================================================

::  Now checks if ISO file matches expectation.
title %basetitle% - Extracting ISO image...
echo ISO Image Location: %ISOPath%
7z l %ISOPath% | findstr /I "sources" | findstr /I "install.wim install.esd boot.wim" > nul
if %errorlevel%==1 goto :_E_InvalidISO else (
7z x -bso0 -bsp2 %ISOPath% -oISOFOLDER
for /f "tokens=1* delims= " %%A in (' bin\7z l %ISOPath% ^| findstr LogicalVolumeId ') do set ISOLABEL=%%B
)

echo Checking major build version of boot.wim...
set bwimpath=ISOFOLDER\sources\boot.wim
%_null% 7z e -aoa %bwimpath% 2/Windows/system32/config/SOFTWARE -oRegStorageTemp
%_null% 7z e -aoa %bwimpath% 2/Windows/system32/config/SYSTEM -oRegStorageTemp
%_null% reg load HKLM\TMPSW RegStorageTemp\SOFTWARE
%_null% reg load HKLM\TMPSYS RegStorageTemp\SYSTEM
for /f "tokens=2* delims= " %%A in ('Reg Query "HKLM\TMPSW\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber') Do Set target_build_pe=%%B
for /f "tokens=2* delims= " %%A in ('Reg Query "HKLM\TMPSYS\ControlSet001\Control\Session Manager\Environment" /v PROCESSOR_ARCHITECTURE') Do Set target_arch_pe=%%B
%_null% reg unload HKLM\TMPSW
%_null% reg unload HKLM\TMPSYS
echo %target_build_pe% %target_arch_pe%

echo Checking major build version of install.wim or esd...
if exist ISOFOLDER\sources\install.wim set iwimpath=ISOFOLDER\sources\install.wim
if exist ISOFOLDER\sources\install.esd set iwimpath=ISOFOLDER\sources\install.esd
for /f "tokens=2* delims= " %%A in (' dism /get-imageinfo /imagefile:%iwimpath% /English ^| findstr /C:"Index" ') do set lastindex=%%B
if %lastindex% gtr 1 (
set indexprefix=1/
) else (
set indexprefix= 
)
%_null% 7z e -aoa %iwimpath% %indexprefix%Windows/system32/config/SOFTWARE -oRegStorageTemp
%_null% 7z e -aoa %iwimpath% %indexprefix%Windows/system32/config/SYSTEM -oRegStorageTemp
%_null% reg load HKLM\TMPSW RegStorageTemp\SOFTWARE
%_null% reg load HKLM\TMPSYS RegStorageTemp\SYSTEM
for /f "tokens=2* delims= " %%A in ('Reg Query "HKLM\TMPSW\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber') Do Set target_build_os=%%B
for /f "tokens=2* delims= " %%A in ('Reg Query "HKLM\TMPSYS\ControlSet001\Control\Session Manager\Environment" /v PROCESSOR_ARCHITECTURE') Do Set target_arch_os=%%B
%_null% reg unload HKLM\TMPSW
%_null% reg unload HKLM\TMPSYS
echo %target_build_os% %target_arch_os%

rd /s /q RegStorageTemp
if %target_build_pe% lss 15063 goto :_E_TooOldVersion
if %target_build_pe:~0,3%==226 (
set target_build_pe=22631
set target_build_os=22631
)
if %target_build_pe:~0,4%==1836 (
set target_build_pe=18363
set target_build_os=18363
)
if %target_build_pe:~0,4%==1904 (
set target_build_pe=19045
set target_build_os=19045
)
if %target_build_pe% gtr 21996 (
if not "%target_build_pe:~0,3%%target_arch_pe%"=="%target_build_os:~0,3%%target_arch_os%" goto :_E_MajorBuildMismatch
) else (
if not "%target_build_pe:~0,4%%target_arch_pe%"=="%target_build_os:~0,4%%target_arch_os%" goto :_E_MajorBuildMismatch
)

::========================================================================================================================================

::  Attempt to get accumulative update files.
title %basetitle% - Downloading update files...
:RetryFetch
GetPatchFiles.py %target_build_os% %target_arch_os%
if exist updates_%target_build_os%_%target_arch_os% rd /s /q updates_%target_build_os%_%target_arch_os%
md updates_%target_build_os%_%target_arch_os%
if not exist patchfilelist_%target_build_os%_%target_arch_os%.txt (
echo Retrying...
timeout /t 5 /nobreak > nul
goto RetryFetch
)
aria2c -i patchfilelist_%target_build_os%_%target_arch_os%.txt -d updates_%target_build_os%_%target_arch_os%
del patchfilelist_%target_build_os%_%target_arch_os%.txt

::========================================================================================================================================

:: Update boot WIM
title %basetitle% - Updating boot.wim...
md WIMFOLDER
%_null% move %bwimpath% WIMFOLDER\boot.wim
md MountedWim
title %basetitle% - Updating boot.wim, Index 1 of 2...
dism /mount-image /imagefile:WIMFOLDER\boot.wim /index:1 /mountdir:MountedWim
for /f %%i in (' dir /b /s updates_%target_build_os%_%target_arch_os%\ ') do dism /image:MountedWim /add-package /packagepath:"%%i"
dism /image:MountedWim /add-driver /driver:BootWimDrivers\common\ /recurse
dism /image:MountedWim /add-driver /driver:BootWimDrivers\%target_arch_pe%\ /recurse
dism /image:MountedWim /cleanup-image /startcomponentcleanup
dism /unmount-image /mountdir:MountedWim /commit
title %basetitle% - Updating boot.wim, Index 2 of 2...
dism /mount-image /imagefile:WIMFOLDER\boot.wim /index:2 /mountdir:MountedWim
for /f %%i in (' dir /b /s updates_%target_build_os%_%target_arch_os%\ ') do dism /image:MountedWim /add-package /packagepath:"%%i"
dism /image:MountedWim /add-driver /driver:BootWimDrivers\common\ /recurse
dism /image:MountedWim /add-driver /driver:BootWimDrivers\%target_arch_pe%\ /recurse
dism /image:MountedWim /cleanup-image /startcomponentcleanup
dism /unmount-image /mountdir:MountedWim /commit
title %basetitle% - Recreating boot.wim, Index 1 of 2...
dism /export-image /sourceimagefile:WIMFOLDER\boot.wim /sourceindex:1 /destinationimagefile:%bwimpath% /compress:max /bootable
title %basetitle% - Recreating boot.wim, Index 2 of 2...
dism /export-image /sourceimagefile:WIMFOLDER\boot.wim /sourceindex:2 /destinationimagefile:%bwimpath% /compress:max /bootable
del WIMFOLDER\boot.wim

::========================================================================================================================================

:: Update WinRE WIM
title %basetitle% - Updating WinRE.wim...
7z e -bso0 -bsp2 %iwimpath% %indexprefix%Windows/system32/Recovery/Winre.wim -oWIMFOLDER
dism /mount-image /imagefile:WIMFOLDER\Winre.wim /index:1 /mountdir:MountedWim
for /f %%i in (' dir /b /s updates_%target_build_os%_%target_arch_os%\ ') do dism /image:MountedWim /add-package /packagepath:"%%i"
dism /image:MountedWim /add-driver /driver:BootWimDrivers\common\ /recurse
dism /image:MountedWim /add-driver /driver:BootWimDrivers\%target_arch_pe%\ /recurse
dism /image:MountedWim /cleanup-image /startcomponentcleanup
dism /unmount-image /mountdir:MountedWim /commit
title %basetitle% - Recreating Winre.wim...
dism /export-image /sourceimagefile:WIMFOLDER\Winre.wim /sourceindex:1 /destinationimagefile:WIMFOLDER\Winre2.wim /compress:max /bootable
del WIMFOLDER\Winre.wim
move WIMFOLDER\Winre2.wim WIMFOLDER\Winre.wim

::========================================================================================================================================

:: Update Install WIM
title %basetitle% - Updating install.wim...
%_null% move %iwimpath% WIMFOLDER\install.wim
set CurrentIndex=1
:LoopUpdate1
if %CurrentIndex% gtr %lastindex% goto OutOfLoop1
title %basetitle% - Updating install.wim, Index %CurrentIndex% of %lastindex%...
dism /mount-image /imagefile:WIMFOLDER\install.wim /index:%CurrentIndex% /mountdir:MountedWim
for /f %%i in (' dir /b /s updates_%target_build_os%_%target_arch_os%\ ') do dism /image:MountedWim /add-package /packagepath:"%%i"
copy /y WIMFOLDER\Winre.wim MountedWim\Windows\System32\Recovery\
dism /image:MountedWim /add-driver /driver:InstallWimDrivers\common\ /recurse
dism /image:MountedWim /add-driver /driver:InstallWimDrivers\%target_arch_os%\ /recurse
dism /image:MountedWim /cleanup-image /startcomponentcleanup
dism /unmount-image /mountdir:MountedWim /commit
%_null% set /a CurrentIndex=%CurrentIndex%+1
goto LoopUpdate1
:OutOfLoop1

set CurrentIndex=1
:LoopUpdate2
if %CurrentIndex% gtr %lastindex% goto OutOfLoop2
title %basetitle% - Generating install.esd, Index %CurrentIndex% of %lastindex%...
dism /export-image /sourceimagefile:WIMFOLDER\install.wim /sourceindex:%CurrentIndex% /destinationimagefile:ISOFOLDER\sources\install.esd /compress:recovery
%_null% set /a CurrentIndex=%CurrentIndex%+1
goto LoopUpdate2
:OutOfLoop2



::========================================================================================================================================

:: Update Installation Media Files
title %basetitle% - Updating installation media files for consistency...
if exist MountedWim rd /s /q MountedWim
if exist WIMFOLDER rd /s /q WIMFOLDER
7z x %bwimpath% 2/sources -oTmpNewSrc
cd TmpNewSrc\2\sources
for /f %%i in (' dir /a-d /b ') do if exist %~dp0ISOFOLDER\sources\%%i move /y %%i %~dp0ISOFOLDER\sources\
cd %~dp0
rd /s /q TmpNewSrc

title %basetitle% - Updating executable files for consistency...
%_null% 7z e -aoa %bwimpath% 2/Windows/Boot/PCAT/bootmgr -oISOFOLDER
%_null% 7z e -aoa %bwimpath% 2/Windows/Boot/DVD/PCAT/boot.sdi -oISOFOLDER\boot
%_null% 7z e -aoa %bwimpath% 2/Windows/Boot/DVD/PCAT/etfsboot.com -oISOFOLDER\boot
%_null% 7z e -aoa %bwimpath% 2/Windows/Boot/PCAT/memtest.exe -oISOFOLDER\boot
%_null% 7z e -aoa %bwimpath% 2/Windows/System32/bootsect.exe -oISOFOLDER\boot

%_null% 7z e -aoa %bwimpath% 2/Windows/Boot/EFI/bootmgr.efi -oISOFOLDER
%_null% 7z e -aoa %bwimpath% 2/Windows/Boot/EFI/memtest.efi -oISOFOLDER\efi\microsoft\boot
%_null% 7z e -aoa %bwimpath% 2/Windows/Boot/EFI/winsipolicy.p7b -oISOFOLDER\efi\microsoft\boot
%_null% 7z e -aoa %bwimpath% 2/Windows/Boot/EFI/bootmgfw.efi -oISOFOLDER\efi\boot

if %target_arch_os%==amd64 set target_mgfw=bootx64.efi
if %target_arch_os%==x86 set target_mgfw=bootia32.efi
if %target_arch_os%==arm64 set target_mgfw=bootaa64.efi

move /Y ISOFOLDER\efi\boot\bootmgfw.efi ISOFOLDER\efi\boot\%target_mgfw%

%_null% 7z e ISOFOLDER\sources\install.esd%indexprefix%Windows/Boot/DVD/EFI/en-US/ -oISOFOLDER\EFI\Microsoft\Boot
%_null% 7z e ISOFOLDER\EFI\Microsoft\Boot\efisys.bin EFI\BOOT\%target_mgfw% -oISOFOLDER\EFI\Microsoft\Boot
move /Y ISOFOLDER\EFI\Microsoft\Boot\%target_mgfw% ISOFOLDER\EFI\Microsoft\Boot\cdboot.efi
%_null% 7z e ISOFOLDER\EFI\Microsoft\Boot\efisys_noprompt.bin EFI\BOOT\BOOTX64.EFI -oISOFOLDER\EFI\Microsoft\Boot
move /Y ISOFOLDER\EFI\Microsoft\Boot\%target_mgfw% ISOFOLDER\EFI\Microsoft\Boot\cdboot_noprompt.efi

::========================================================================================================================================

:: Repackaging ISO file
title %basetitle% - Repackaging ISO file...
oscdimg -m -o -u2 -udfver102 -bootdata:2#p0,e,bISOFOLDER\boot\etfsboot.com#pEF,e,bISOFOLDER\EFI\Microsoft\Boot\efisys.bin -l"%ISOLABEL%" ISOFOLDER ISOIMAGE.iso

echo All Done.
goto :_P_Cleanup
pause
goto :PatchISOend
::========================================================================================================================================

::  Error Handler: Too old version.
:_E_TooOldVersion
echo ERROR: This ISO image contains too old version of OS.
goto :_P_Cleanup

::========================================================================================================================================

::  Error Handler: Mismatch build version.
:_E_MajorBuildMismatch
echo ERROR: Build version of boot.wim and install.wim mismatches with each other.
goto :_P_Cleanup

::========================================================================================================================================

::  Post operation: Cleanup ISOFOLDER.
:_P_Cleanup
echo Cleaning up ISOFOLDER...
rd /s /q ISOFOLDER
pause
goto PatchISOend

:PatchISOend