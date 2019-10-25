# hueiot: Follow the sun and activities to control Philips Hue lights.

# Background

I am certainly thrilled with IoT, but I prefer to keep as much as I can within the 'firewall'. This suite of ```bash``` scripts managed were built under Ubuntu/Raspbian on a low power Raspberry Pi for 24-7/365 management of the Philips Hue lights in the home.

# Usage
## Configure
### Lighting Schedules
Modify ```hue.sched``` for your lighting preferences
* _lights
* _lightsON
* _lightsOFF
* _bynite
* _bytv
### Local Settings
Modify ```autoHue.sh``` for local settings
* LOC
* IOTDIR
* VACA
* 
Modify ```iotalive.sh``` for your devices (if only a TV)
* _deviceID
* _deviceDNS
## Install to Run at Boot
Copy/move ```hue.sched``` to ```${IOTDIR}```
Add ```iotalive.sh``` and ```autoHue.sh``` to ```/etc/rc.local```

```
TBD
```

# References/Dependencies
Motivated and inspired by ```Risacher's Sunwait``` program which provides celestial times for solar movement by GPS location. The version used pre-dates Risacher's current version of Sunwait now on GitHub (see Task List below).
# Task List
- [x] Debian/Ubuntu
- [ ] Place localizations, API keys in a configuration/parameters file
- [ ] Revise to work with [Risacher's Sunwait](https://github.com/risacher/sunwait.git) (new version of sunwait from 2004)
- [ ] Move startup from /etc/rc.local to systemd
- [ ] Create a GUI to generate a schedule
- [ ] Port to work with BSD ```date```
- [ ] Port to php (takes care of BSD ```date```)

