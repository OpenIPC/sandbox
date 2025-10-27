## Introduction

This experimental solution is designed for sending JPEG images to Yandex Disk via the Poligon app and OAUTH.

The old method of sending via open authorization is no longer available.

### Step one: Register an account

Go to the [registration page](https://passport.yandex.ru/auth/reg/portal) and create an account on Yandex.

### Step two: Obtaining an OAUTH key

Go to the Poligon [app page](https://yandex.ru/dev/disk/poligon) and get an OAUTH key for installation.

### Step three: Installing the key on the OpenIPC camera

Run the installation command with your OAUTH key in UART, SSH or WEB console:

```
fw_setenv yandex_oauth YOU_OAUTH_KEY
```

### Step four: Obtaining the script and installing it

Run the installation command in UART, SSH or WEB console:

```
curl -L -o /usr/sbin/yandex https://raw.githubusercontent.com/OpenIPC/sandbox/refs/heads/main/scripts/yandex/yandex ; chmod +x /usr/bin/yandex
```

### Features and Usage

The script will likely be modified soon and possibly integrated into the WebUI interface later. 

However, it can already be used via crontab or manually launched.
