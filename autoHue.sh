#!/bin/bash

SW=/home/pi/src/sunwait-20041208/sunwait
IOTDIR=/home/pi/iot
VACA=/home/pi/iot

#
# Hue DEVICE IP or Name and API key
#
HUEDEV=hue1.
HUEAPIKEY=h141PPBfcgxbN5NG

#
# 433Mhz Transmitter server
#
_433DEV=bpluspi.

CURL=curl

#
# these args are custom for the sunwait program
#
WHENDARK="sun down"
WHENLITE="Sun rises"
ARGSET=6
ARGUP=3

#
# location data where lights are controlled
#
# Apple HQ, Cupertino, CA, US
LOC="37.331730N 122.030733W"
#

SLEEPYTIME=30
#

NOWFILE=/tmp/schedV4.now
TOMFILE=/tmp/schedV4.tomorrow
rm -f ${TOMFILE}

# use ${WHENLITE} for sunup (starts) and ${WHENDARK} sundown (ends)
# darkness, then is today (ends) through to tomorrow (starts)
#
# sets _SUNSET and _SUNUP for time calculation
#
_NOW=
_SUNSET=
_SUNUP=

getdates()
{
  _ny=$(date +%Y)
  _nm=$(date +%m)
  _nd=$(date +%d)

  _darkstart_hm=$(${SW} -p -y ${_ny} -m ${_nm} -d ${_nd} ${LOC} 2>/dev/null|\
   grep "${WHENLITE}"|\
     sed 's/^[ ]*//g'|cut -d\  -f${ARGSET}|\
       sed 's/^\(.\{2\}\)/\1:/')

  _darkends_hm=$(${SW} -p -y ${_ny} -m ${_nm} -d ${_nd} ${LOC} 2>/dev/null|\
   grep "${WHENLITE}"|\
     sed 's/^[ ]*//g'|cut -d\  -f${ARGUP}|\
       sed 's/^\(.\{2\}\)/\1:/')

  _SUNUP=$(date --date="Today ${_darkends_hm}" +%s)
  _SUNSET=$(date --date="Today ${_darkstart_hm}" +%s)
  _NOW=$(date +%s)

  if [ -f /tmp/sunwdebug ]; then
    echo night begins at $_darkstart_hm on ${_ny} ${_nm} ${_nd} \($_SUNSET\)
    echo night   ends at  $_darkends_hm on ${_ny} ${_nm} ${_nd} \($_SUNUP\)
  fi
}

#
# determines if home theater TV is ON (returns 0) or not ON (returns 1)
#
tvison()
{
  if [ -f ${IOTDIR}/lgtv.on ]; then
    return 0
  else
    return 1
  fi
}

#
# determines if we're ON vacation (returns 0) or not ON vacation (returns 1)
#
onvacation()
{
  if [ -f ${VACA}/onvacation.state \
       -a ! -f /tmp/overrideHueControl ]; then
    return 0
  else
    return 1
  fi
}

#
# determines if it is daylight (returns 0) or not daylight (return 1)
#
daylight()
{
  getdates
  #echo if [ ${_NOW} -gt ${_SUNUP} -a ${_NOW} -lt ${_SUNSET} ]
  #
  # its daylight if NOW is between SUNUP and SUNSET
  #
  if [ ${_NOW} -gt ${_SUNUP} -a ${_NOW} -lt ${_SUNSET} ]; then
    return 0
  else
    return 1
  fi
}

#
# issue HUE or 433mhz command to switch a light on an off, designed to 
# track, internally, actual state of light to reduce unnecessary
# API calls (if the light is ON and we're switching ON, no need
# to make the Hue API call). Some 433mhz lights (RF LED kits) use
# the same code to toggle on/off - so if ON and needs to be ON
# don't send code otherwise the light will toggle OFF
#

switch433mhz()
{
  if [ "${2}" = "ON" -a "${_realState[${1}]}" = "ON" ]; then
    return 0
  fi

  if [ "${2}" = "OFF" -a "${_realState[${1}]}" = "unk" ]; then
    #
    # if codes for ON/OFF are same (a toggle); on 'unknown' state
    # assume OFF and don't send an initial OFF code (which could
    # inadvertly toggle the light 'ON'
    #
    if [ "${light433mhzON[${1}]}" = "${light433mhzOFF[${1}]}" ]; then
      _realState[${1}]="OFF"
    fi
  fi

  if [ "${2}" = "OFF" -a "${_realState[${1}]}" = "OFF" ]; then
    return 0
  fi

  if [ "${2}" = "ON" ]; then
    _code=${light433mhzON[${1}]}
  else
    _code=${light433mhzOFF[${1}]}
  fi
  #
  # 433mhz have specific pulse lengths, use what was discovered
  #
  _pulse=${light433mhzPULSE[${1}]}

  _realState[${1}]=${2}

  if [ -f /tmp/overrideLEDcontrol ]; then
    return 0
  fi

  ${CURL} --silent \
       -o /dev/null \
       http://${_433DEV}/led/433send.php?433code=${_code}\&433pulse=${_pulse}  && \
    echo ${1} curled LED ${2} $(date +"%m-%d %H:%M:%S")

}

switchLight()
{
echo sL: ${1} is ${lightclass[${1}]} \(${lightnames[${1}]}\) to be ${2} and is really ${_realState[${1}]}

  if [ "${lightclass[${1}]}" = "433mhz" ]; then
    switch433mhz ${1} ${2}
    return 0
  fi

  _hueLight=${lightHueID[${1}]}

  if [ "${2}" = "ON" ]; then
    [ "${_realState[${1}]}" != "ON" ] && \
      ${CURL} -H "Accept: application/json" \
         -X PUT \
         --silent \
         -o /dev/null \
         --data '{"on":true}' \
         http://${HUEDEV}/api/${HUEAPIKEY}/lights/${_hueLight}/state && \
      echo ${1} curled ON $(date +"%m-%d %H:%M:%S")
    _realState[${1}]="ON"
  else
    [ "${_realState[${1}]}" != "OFF" ] && \
      ${CURL} -H "Accept: application/json" \
         -X PUT \
         --silent \
         -o /dev/null \
         --data '{"on":false}' \
         http://${HUEDEV}/api/${HUEAPIKEY}/lights/${_hueLight}/state && \
      echo ${1} curled OFF $(date +"%m-%d %H:%M:%S")
    _realState[${1}]="OFF"
  fi
}

# main

while true  # {
do
  touch ${NOWFILE}
  if [ ! -f ${TOMFILE} -o ${NOWFILE} -nt ${TOMFILE} ]; then  # {
    getdates
    echo reading today"'"s schedule $(date) or ${_NOW}
    source ${VACA}/hue.sched
    #
    # do this ONLY ONCE
    #
    [ "${#_realState[@]}" = "0" ] && for LIGHT in $(seq 0 $((${#lightnames[@]}-1))) # {
    do
      _realState[${LIGHT}]="unk"
      echo looping ${_realState[${1}]}
    done

    #
    # reread schedule 10 minutes after the last light is turned off
    # for the day
    # 
    touch -d \
      "$(date --date="@$(($(echo ${lightsOFF[*]} | \
                tr " " "\n" | \
                sort -n | \
                tail -1)+(60*10)))" +"%Y-%m-%d %H:%M:%S")" \
      ${TOMFILE}
    : # ls --full-time ${TOMFILE}
  else  # } {
    : #echo NOT reading today"'"s schedule
  fi  # }

  if daylight ; then  # {

    # ensure all lights are off, it's daytime

echo dL: before ${_realState[*]}
    for LIGHT in $(seq 0 $((${#lightnames[@]}-1))) # {
    do
      switchLight ${LIGHT} OFF
    done # }
echo dL: after ${_realState[*]}

    # now, wait for sunset

    if [ -f /tmp/sunwdebug ]; then
      echo waiting for sunset.
    fi
    ${SW} -v ${WHENDARK} ${LOC}

  else # }  {

    #
    # it's night time, walk through light schedules
    # turn those on which are supposed to be ON
    #

    for LIGHT in $(seq 0 $((${#sched[@]}-1)))  # {
    do

      _light=${sched[${LIGHT}]}

      _NOW=$(date +%s);

      #
      # determine if a light should be ON based on its
      # scheduled period
      #
      # NB: for a light that is ONLY bytv its schedule is ignored
      #
      #echo checking ${_light} for ${LIGHT}
      if [ ${lightsON[${LIGHT}]} -lt ${_NOW} -a \
          ${lightsOFF[${LIGHT}]} -gt ${_NOW} ]; then
        lightstate[${_light}]=ON
        #echo making ${_light} \(${LIGHT}\) = ON
      fi

    done # }

#exit; continue;

    tvison
    TVISON=${?}

    for LIGHT in $(seq 0 $((${#lightnames[@]}-1))) # {
    do

      #
      # lights can be driven by night time (bynite) or if
      # on vacation
      #
      if [ ${bynite[${LIGHT}]} -eq ${TRUE} ]; then
        #
        # then light is either ON or OFF according to schedule
        #
        switchLight ${LIGHT} ${lightstate[${LIGHT}]}
      elif onvacation && [ ${byvacation[${LIGHT}]} -eq ${TRUE} ]; then
        #
        # then light is either ON or OFF according to schedule
        #
        switchLight ${LIGHT} ${lightstate[${LIGHT}]}
      else
        :
      fi

      #
      # exception case: some lights only are to be ON if the
      # home theater is ON and it is night (unless we're on
      # vacation -- so fake it and let vacation sched override)
      #
      if (! onvacation) && [ ${bytv[${LIGHT}]} -eq ${TRUE} ]; then
        if [ ${TVISON} -eq 0 ] ; then
          #
          # then light is ON since TV is on
          #
          lightstate[${LIGHT}]=ON
          switchLight ${LIGHT} ${lightstate[${LIGHT}]}
        else
          #
          # then light is OFF since TV is on
          #
          lightstate[${LIGHT}]=OFF
          switchLight ${LIGHT} ${lightstate[${LIGHT}]}
        fi
      fi

    done # }

    #
    # wait for the next interval to change light state
    #
    sleep ${SLEEPYTIME}
    echo checking lights $(date)

  fi  # }

done  # }

exit 1

