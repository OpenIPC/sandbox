# OpenIPC-onvif-XM-530
OpenIPC PTZ Configuration on the Xiongmai XM530 for an Onvif client

## Introduction
The current default build of [OpenIPC](https://openipc.org/) has limited support for an Onvif client. There is however a module named [onvif_simple_server](https://github.com/roleoroleo/onvif_simple_server) that can be included to provide enough features to support pan and tilt controls as well as the storage of the home position and presets.

These are my notes on how to set this up on an XM530 camera which, uses the xm-kmotor module to drive the pan and tilt functions through a cgi script, and has been tested using the Windows Onvif Device Manger Client (v2.2.250).

The main objective is simply to get pan and tilt working however if you also want to utilise other features then the approach below could be scaled to include such things as events by looking at the onvif_simple_server source.

## What is Onvif ?
In simple terms [Onvif](https://www.onvif.org/) is a set of standards that provide a common, well documented approach for an Onvif client to be able to connect to a device and interact with it. The actual formal description is 

**ONVIF is an open industry forum that provides and promotes standardized interfaces
for effective interoperability of IP-based physical security products and services**

To set up an IP camera therefore we need to respond to the onvif client (such as [Onvif Device Manager](https://sourceforge.net/projects/onvifdm/))
in the expected way as defined in the specific profiles e.g. get_presets expects a list of presets to be returned in the format name,x,y. This is where the onvif_simple_server module comes in to give us the functionality to receive the client request and respond accordingly. 

## Ensure you can successfully build the default firmware
The steps to get a working result are relatively straightforward however it does require that you are able to build the software yourself since the module required is not currently included in an off the shelf binary. If you need to set this up then take a look at the [firmware development wiki article](https://github.com/OpenIPC/wiki/blob/master/en/source-code.md)

From this point forward it is expected that you have succesfully built, installed and tested your ability to make and deploy the firmware for your camera.

## What needs to be done to make it work in our custom XM530 build?
The onvif-simple-server package provides us an application that responds to a client xml onvif request such as goto_home_position or get_presets etc. however it needs a helper type script that translates the requests into appropriate commands for our camera. In this case our XM530 has the xm-kmotor module which we need to tell what to do in response to the specific requests. 

The requests and how to handle them are setup in **onvif.conf**

Our script **onvif_presetsxm530.sh** provides the ability to support the use of presets and a home position which are stored in **/etc/ptz_presets.conf** and **/etc/ptz_home.conf** which are created as required.

The following instructions will explain how to ensure the onvif_simple_server package is built and what else you need to complete for everything to work correctly. 

### Include the onvif_simple_server module
For each manufacturer and camera module there is a list of packages that will be included in the build. The first step we need to do is ensure that the onvif_simple_server package is included in this list.

In your local copy of the firmware navigate to the directory **br-ext-chip-xiongmai/configs** and open the file **xm530_lite_defconfig**

In the section under the comment # Packages, if it is not included, insert **BR2_PACKAGE_ONVIF_SIMPLE_SERVER=y** as shown below.

    # Packages
    BR2_PACKAGE_DROPBEAR_OPENIPC=y
    BR2_PACKAGE_IPCTOOL=y
    BR2_PACKAGE_JSONFILTER=y
    BR2_PACKAGE_LIBCURL_OPENIPC=y
    BR2_PACKAGE_LIBCURL_OPENIPC_CURL=y
    # BR2_PACKAGE_LIBCURL_OPENIPC_PROXY_SUPPORT is not set
    # BR2_PACKAGE_LIBCURL_OPENIPC_COOKIES_SUPPORT is not set
    # BR2_PACKAGE_LIBCURL_OPENIPC_EXTRA_PROTOCOLS_FEATURES is not set
    BR2_PACKAGE_LIBEVENT_OPENIPC=y
    BR2_PACKAGE_LIBOGG_OPENIPC=y
    BR2_PACKAGE_LINUX_FIRMWARE_OPENIPC=y
    BR2_PACKAGE_LINUX_FIRMWARE_OPENIPC_MEDIATEK_MT7601U=y
    BR2_PACKAGE_MAJESTIC_FONTS=y
    BR2_PACKAGE_MAJESTIC_WEBUI=y
    BR2_PACKAGE_MAJESTIC=y
    BR2_PACKAGE_MBEDTLS_OPENIPC=y
    BR2_PACKAGE_MOTORS=y
    BR2_PACKAGE_ONVIF_SIMPLE_SERVER=y
    BR2_PACKAGE_OPUS_OPENIPC=y
    BR2_PACKAGE_VTUND_OPENIPC=y
    BR2_PACKAGE_XIONGMAI_OSDRV_XM530=y
    BR2_PACKAGE_YAML_CLI=y

### Including our updates in the build
If you have not made any changes to the build of the firmware before it can be a bit daunting however there is a well designed logic to all the components  which we will need to tweak.

If you look at the directory named **general/package** you will find that every available package has a section with the make file (build instructions) and any supporting patches/files.

If you navigate to the onvif-simple-server directory you will see

![image](https://github.com/user-attachments/assets/a02386ca-a9f6-4504-b511-6766325c636a)

The two patch files ensure the required security system is chosen (mbedtls) and support for the OpenIPC directory structure. If you open the make file **onvif-simple-server.mk** you will see the definition for onvif_simple_server source location and the directories where the component files get copied to during the build process.

Firstly we need to copy the files **onvif_presetsXM530.sh** and **onvif.conf** to our copy of the firmware.

Copy the file **[onvif_presetsXM530.sh](https://github.com/cdg123/OpenIPC-Onvif-XM-530/blob/main/onvif_presetsXM530.sh)** into your local **general/package/onvif-simple-server/files** directory and **[onvif.conf](https://github.com/cdg123/OpenIPC-Onvif-XM-530/blob/main/onvif.conf)** to the same location overwriting the existing file.

Now update the **onvif-simple-server.mk** file by inserting the line

	$(INSTALL) -m 0755 -t $(TARGET_DIR)/usr/sbin $(ONVIF_SIMPLE_SERVER_PKGDIR)/files/onvif_presetsXM530.sh

after the line

    $(INSTALL) -m 0644 -t $(TARGET_DIR)/etc $(ONVIF_SIMPLE_SERVER_PKGDIR)/files/onvif.conf

### Setting up our own httpd instance on port 8080
At the time of testing this setup I couldn't see an obvious way to get Majestic to use our onvif solution, instead of its own, and so we need to run a parrallel httpd instance on a different port to make it work seamlessly (we are still using the same web content location though)

To achieve this we are going to create a script to load the httpd deamon on port 8080 in the same way the other modules are started using init.d.

Copy the script **[S96onvifhttpd](https://github.com/cdg123/OpenIPC-Onvif-XM-530/blob/main/S96onvifhttpd)** to the **onvif-simple-server/files** directory as in the step above

Now add an additional entry to the onvif makefile so the S96onvifhttpd script file gets copied to the /etc/init.d folder during the build.

Add to the makefile along with the other INSTALL lines.

    $(INSTALL) -m 0755 -d $(TARGET_DIR)/etc/init.d
    $(INSTALL) -m 0755 -t $(TARGET_DIR)/etc/init.d $(ONVIF_SIMPLE_SERVER_PKGDIR)/files/S96onvifhttpd

Your onvif-simple-server.mk should now include the following:

    define ONVIF_SIMPLE_SERVER_INSTALL_TARGET_CMDS
    $(INSTALL) -m 0755 -d $(TARGET_DIR)/usr/sbin
    $(INSTALL) -m 0755 -t $(TARGET_DIR)/usr/sbin $(@D)/onvif_simple_server
    $(INSTALL) -m 0755 -t $(TARGET_DIR)/usr/sbin $(@D)/wsd_simple_server
    $(INSTALL) -m 0755 -d $(TARGET_DIR)/etc
    $(INSTALL) -m 0644 -t $(TARGET_DIR)/etc $(ONVIF_SIMPLE_SERVER_PKGDIR)/files/onvif.conf
    $(INSTALL) -m 0755 -d $(TARGET_DIR)/var/www/onvif/device_service_files
    $(INSTALL) -m 0644 -t $(TARGET_DIR)/var/www/onvif/device_service_files $(@D)/device_service_files/*
    $(INSTALL) -m 0755 -d $(TARGET_DIR)/var/www/onvif/generic_files
    $(INSTALL) -m 0644 -t $(TARGET_DIR)/var/www/onvif/generic_files $(@D)/generic_files/*
    $(INSTALL) -m 0755 -d $(TARGET_DIR)/var/www/onvif/media_service_files
    $(INSTALL) -m 0644 -t $(TARGET_DIR)/var/www/onvif/media_service_files $(@D)/media_service_files/*
    $(INSTALL) -m 0755 -d $(TARGET_DIR)/var/www/onvif/ptz_service_files
    $(INSTALL) -m 0644 -t $(TARGET_DIR)/var/www/onvif/ptz_service_files $(@D)/ptz_service_files/*
    $(INSTALL) -m 0755 -d $(TARGET_DIR)/var/www/onvif/wsd_files
    $(INSTALL) -m 0644 -t $(TARGET_DIR)/var/www/onvif/wsd_files $(@D)/wsd_files/*
    $(INSTALL) -m 0755 -d $(TARGET_DIR)/etc/init.d
    $(INSTALL) -m 0755 -t $(TARGET_DIR)/etc/init.d $(ONVIF_SIMPLE_SERVER_PKGDIR)/files/S96onvifhttpd
    
    ln -s /usr/sbin/onvif_simple_server $(TARGET_DIR)/var/www/onvif/device_service
    ln -s /usr/sbin/onvif_simple_server $(TARGET_DIR)/var/www/onvif/events_service
    ln -s /usr/sbin/onvif_simple_server $(TARGET_DIR)/var/www/onvif/media_service
    ln -s /usr/sbin/onvif_simple_server $(TARGET_DIR)/var/www/onvif/ptz_service
    endef

You can see in the above that this copies files into an onvif area under the /var/www web content directory. It is these onvif folders that contain the xml templates used to respond to the onvlif client by inserting our content. (useful if you want to change the default xml response) 

## Ensure xm-kmotor is loaded
By default the module for controlling pan and tilt is not loaded and so we need to add this to the script that runs when the camera boots up.

In the directory **general/package/xiongmai-osdrv-xm530/files/script** edit the file **load_xiongmai** and add the following line to the bottom of the insert_ko() section

    insmod /lib/modules/3.10.103\+/xiongmai/kmotor.ko gpio_pin=3,70,75,77,74,76,69,71,-1,-1,-1,-1 auto_test=1 MAX_DEGREE_X=280 MAX_DEGREE_Y=127

## Set the IP Adddress
The initial IP Address by default will be assigned through DHCP and can be found by using the address "openipc.local". If you prefer you can amend the eth0 file found in general/overlay/etc/network/interfaces.d/ to set a static address or of course update it later through the web ui.

    iface eth0 inet static
        hwaddress ether $(fw_printenv -n ethaddr || echo 00:00:23:34:45:66)
        address 192.168.1.123
        netmask 255.255.255.0
        gateway 192.168.1.254
        pre-up echo nameserver 192.168.1.254 > /tmp/resolv.conf

## Build and Deploy
This completes all the tweaks that are required to be built and deployed so now run make as usual and update the camera software via tftp or your preferred way. If you need reminding of the options then check the [Upgrading firmware wiki article](https://github.com/OpenIPC/wiki/blob/master/en/sysupgrade.md).

I find that having a tftp server instance on my dev machine, where I have just built the firmware, and copying the required rootfs.squashfs.xm530 and uImage.xm530 files from the output/images directory is simplest.

Then from an SSH session into the camera do

    soc=$(fw_printenv -n soc)
    serverip=$(fw_printenv -n serverip)
    cd /tmp
    busybox tftp -r rootfs.squashfs.${soc} -g ${serverip}
    busybox tftp -r uImage.${soc} -g ${serverip}
    sysupgrade --kernel=/tmp/uImage.${soc} --rootfs=/tmp/rootfs.squashfs.${soc} -z --force_ver

Remember to clear any existing configuration you may need to run firstboot.

## Final configuration
- On my version of the XM530 the initial camera feed is in black and white to fix this I had to change the majestic night mode settings so colorToGray is false and lightMonitor & lightSensorInvert are set to true.

- For some reason the jpeg snapshot won't work unless Video1 is enabled and so enable this from the majestic web interface.

- Check and set the timezone appropriately from the web interface.


## Confirm expected operation
Now from an onvif client you should be able to add your camera (don't forget it needs to be on port 8080 as port 80 gives you the Majestic response if onvif is on) this should be in the format **http://yourcamip:8080/onvif/device_service**

The client will then interrogate the camera for all supported functions however you will need to enter the username and password in the client.

If you are using the Windows version of the ONVIF Device Manager then it will display a number of options like this

![image](https://github.com/user-attachments/assets/d32d5b7b-eae9-46b4-b7a4-d1fac42faef1)


If you select the PTZ control link then you will get the obvious controls for up, down, left, right. In the Settings box, bottom right, there is a button to Set Home, which is at the current camera position, and by entering a name in the text box below you can create a preset, again at the current camera location by hitting the set preset button. After a short period you should see the name appear as a button in the bottom left hand side box with the Home button at the top. The Home button should take you to your home position. To use the presets you first click on one and then use the Goto button

## Security
By default there is no security configured for the onvif xml interaction with the onvif server however to see the image snapshot and rtsp streams in an onvif client you must have provided the camera username password to get them via the majestic RTSP streams.

It is recommend to enable the onvif username/password security by editting the onvif.conf file located at /etc/onvif.conf file by entering

    vi onvif.conf

Use the arrows key to navigate to the password setting, press the insert key to enable editting and then update your password. To save press the ESC key and then press :wq which is the command to write and then quit.

You should now find that the onvif client can get access (assuming you have entered the name and password in it of course)

## Troubleshooting
The one problem I have not resolved is not actually related to the onvif setup but the more recent builds I have made of the firmware and that is that the preview page appears to freeze and not return the snapshot image so something for another day however if for some reason your onvif things aren't working try looking at the following

- Is Video-1 enabled in majestic ?
- Is the xm-kmotor module loaded properly ?
   Easiest way to check this is to ssh into the camera and just type xm-kmotor. This should return the current status and x,y positions.

   The xm-kmotor helper module should be installed as part of the build if not then enter:

    insmod /lib/modules/3.10.103\+/xiongmai/kmotor.ko gpio_pin=3,70,75,77,74,76,69,71,-1,-1,-1,-1 auto_test=1 MAX_DEGREE_X=280 MAX_DEGREE_Y=127

  If you reboot the camera this will be lost.

- Is the http instance loaded on port 8080 ?
  This should load at startup so check using ps command to show running process and you should see httpd running on port 8080
- Is the /etc/onvif.conf file correct ? 
  Double check onvif.conf has the correct username/password etc.
- Is the /usr/sbin/onvif_presetsxm530.sh setup correctly
  Check that our onvif_presets script is running ok and is executable.

  Entering **/usr/sbin/onvif_presetsxm530.sh** on the camera should respond with a message saying it is not designed to be run directly.
  Using one of the onvif options like **/usr/sbin/onvif_presetsxm530.sh get_position** should return the camera current x,y numbers which proves the connection out to xm-kmotor.

- Are all the onvif files copied correctly into the webui area at /var/www/onvif?
Check the xml templates are all copied across and under the service_files etc directories.

## Further Tweaks
As mentioned above the xml files in the /var/www/onvif directory contain the templates for the response to an OnVif client. If you want more than just the PTZ functionality then you can edit these to reflect the camera setup such as using the printenv command to get the actual IP address etc. in the device_files.

Just remember any new builds you do will pull in content from the respective sources such as majestic-webui and onvif simple server sources and may overwrite any changes you make.

