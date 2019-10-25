# hueiot: Follow the sun and activities to control Philips Hue lights.

# Background

I am certainly thrilled with IoT, but I prefer to keep as much as I can within the 'firewall'. This suite of ```bash``` scripts managed were built under Ubuntu/Raspbian on a low power Raspberry Pi for 24-7/365 management of the Philips Hue lights in the home.

# Usage
## Configure
### Lighting Schedules
Modify ```hue.sched``` for your lighting preferences
* ```lightnames```: these are logical and can essentially be anything desired.
* ```lightstate```: should be initialized to ```OFF```.
* ```lights```: the assigned light number by the HUE bridge. May take some testing to get the correct ordinal number to correspond to the logical light.
* ```lightsON```: The date time (in Linux epoch) when the light is to come on.
* ```lightsOFF```: The date time (in Linux epoch) when the light is to go out.
* ```bynite```: ```TRUE``` means the scheduled event should follow Sun up/down, otherwise set to ```FALSE```.
* ```bytv```: ```TRUE``` means the scheduled event should follow state of another IOT device in the household, like a TV/Home Theater. Otherwise set to ```FALSE```.
* ```byvacation```: ```TRUE``` means the scheduled event should follow state of being away (such as on vacation) for a longer period of time.  Otherwise set to ```FALSE```.
Rules:
*  ```lightnames``` and ```lightstate``` have the same number of elements equal to the number of lights you want to control.
*  ```lights```, ```lightsON```, ```lightsOFF```, ```bynite```, ```bytv```, and ```byvacation``` have the same number of elements equal to the number of scheduled ```lightsON events ``` (or ```lightsOFF``` if you prefer).
Determining the Linux epoch for ```lightsON``` and ```lightsOFF```
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

