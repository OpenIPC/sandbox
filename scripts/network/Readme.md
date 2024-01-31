![OpenIPC logo][logo]

## OpenIPC MultiNet
**_Experimental system for manage several network interfaces that are available on OpenIPC devices simultaneously_**


### Switch to new network configuration
```
curl -s https://raw.githubusercontent.com/OpenIPC/sandbox/main/scripts/network/multinet | sh -s -- install
```


### Restore to the original
```
curl -s https://raw.githubusercontent.com/OpenIPC/sandbox/main/scripts/network/multinet | sh -s -- uninstall
```

### What has changed
- Enable eth0 by default if there's an Ethernet port
- Set different metrics to all interfaces. eth0 will have the highest priority over any other connections. All traffic will go through eth0 if there's Ethnetnet connections. All other interfaces can still listen for incoming traffic at the same time
- Monitor Ethernet port status changes, so Ethernet is now plug and play

### Notes
We would be deeply grateful if you could test this and send us feedback and any suggestions or improvements you have.


### Technical support and donations

Please **_[support our project](https://openipc.org/support-open-source)_** with donations or orders for development or maintenance. Thank you!


[logo]: https://openipc.org/assets/openipc-logo-black.svg
