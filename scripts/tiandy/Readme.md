## Description
This script is designed for the Tiandy camera running OpenIPC firmware. At random intervals, the camera's exposure increases, causing the image to turn completely white. Restarting the majestic process resolves this issue temporarily.

## Installation
To install the script that restarts the majestic process, run the following commands on your device:
```sh
curl -L -o /etc/init.d/S94moloko https://raw.githubusercontent.com/OpenIPC/sandbox/tree/main/scripts/tiandy/refs/heads/main/S94moloko
chmod +x /etc/init.d/S94moloko
reboot
```

## Usage
The script runs in the background and continuously monitors the isp_avelum metric. If isp_avelum reaches or exceeds 250, the script will automatically restart the majestic process.
