# WindowsISOPatcher
An automated patcher for Windows 10 or 11.

## Feature
- Download and integrate updates from Microsoft server, then integrate into the ISO image you have.
- Update installer from sources directory to keep everything consistent.
- Update bootmgr to pass Secure Boot verification.
- Repackage it into ISOIMAGE.iso with original volume label to allow it boot from either UEFI or Legacy mode.
- Integrate the driver files you have for specific devices.

## Upcoming features
- Allow $OEM$ directory integration for custom post-installation procedures.

## Compatible ISO images and architectures
Windows build 15063 or newer, a.k.a. Windows 10 Version 1703 or newer, including server equivalent. 

Supported Architecture: amd64, x86, arm64

Unofficial images with mismatching build version and architecture are unsupported.

Reason:
- The update fetching procedure is based on UUPdump. Only build 15063 or newer are allowed to fetch update contents from UUPdump.

## Requirements
- Windows 10 Build 19041 or newer. Using Windows 11 is strongly recommended.
- Python 3.9 or newer. You should add Python to PATH then install requests from pip:
`pip install requests`


## Usage
1. Download the ISOPatcher from Releases section then extract.
2. Install Python and requests.
3. Copy driver files (which contain INF) you'd like to integrate into BootWimDrivers and InstallWimDrivers directories. Architecture specific drivers should be copied into respective architecture sub directory (e.g. amd64), drivers can be shared between architectures should be copied into common sub directory.
4. Drag eligible ISO image you'd like to patch onto PatchISO.cmd.
5. Grant Administrator elevation when prompted, since DISM requires elevated environment.
6. Wait for the procedure completes, then an updated ISO file named "ISOIMAGE_[sha256_checksum].iso" will be created under ISOPatcher directory. This image can be used for fresh install or in-place upgrade.

## Credits
- UUPdump for providing Windows Update API.
- Windows is a trademark of Microsoft Corporation.