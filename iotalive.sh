#!/bin/bash
#
# see: https://melgrubb.com/2014/09/05/raspberry-pi-home-server-part-15power-failures/
#

#
# where to record state (on/off)
#
IOTDIR=/home/pi/iot

#
# minimum interval for checking device state (in sec)
#
SLEEPYTIME=6

#
# maximum time to wait for device state response (in sec)
#
DEVICETIME=3

#
# list of devices to check, names can be anything
# a state of on/off will be visibile in the ${IOTDIR}
# as the device name in this array ending in ".on"
# e.g., ${IOTDIR}/lgtv.on
#
declare -a deviceID=("lgtv"   \
                     "phtv"   \
                     "hue1"   \
                     "scam01" \
                     "sndbr"  \
                     "nexus"  \
                     "hpjet"  \
                     "sbv3a"  \
                     "win81"  )

#
# device name as it appears on the net (by DNS) or
# by IP address
#
declare -a deviceDNS=("lg55LF6090-UB."   \
                      "phil32pfl4907."   \
                      "hue1."   \
                      "piscam01." \
                      "321BCCSNDBRmain."  \
                      "nexus7a."  \
                      "HPJ610a."  \
                      "SBv3A."  \
                      "liva-pc."  )

#
# sends and waits for ping response to sense if
# device is on
#
deviceison()
{
  ping -c 1 -W ${DEVICETIME} ${1} 1>/dev/null 2>&1 || \
    ping -c 1 -W ${DEVICETIME} ${1} 1>/dev/null 2>&1 || \
    ping -c 1 -W ${DEVICETIME} ${1} 1>/dev/null 2>&1
  return ${?}
}

#
# walk through the list of devices and see if they are on
#
liveon()
{
  for device in $(seq 0 $((${#deviceID[@]}-1))) # {
  do
    _dv=${deviceDNS[${device}]}
    _id=${deviceID[${device}]}
    deviceison ${deviceDNS[${device}]}
    if [ "${?}" = "0" ]; then
       touch ${IOTDIR}/${_id}.on
    else
       rm -f ${IOTDIR}/${_id}.on
    fi

  done # }
}

# main

[ ! -d "${IOTDIR}" ] && mkdir ${IOTDIR}

while true
do

   liveon

   sleep ${SLEEPYTIME}
done

echo done
exit 0
