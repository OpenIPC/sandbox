## OpenIPC VisualMotion
Add to `majestic_webui` **visual editor** for regions of interest and ecluded from motion detection.

Worked on fresh Firefox, Chromium, Edge.

### How to use
- copy all files from `m` directory into `/var/www/m` directory on camera
- add this line in /var/www/cgi-bin/status.cgi after `<%in p/header.cgi %>`
```
<%in ../m/roi.html %>
```
- open in broser http://ca.me.ra.ip/

### ToDo
- read current values from `roi/roe` fields and draw rectangles
