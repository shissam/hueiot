#!/bin/bash

SW=/home/pi/src/sunwait-20041208/sunwait
IOTDIR=/home/pi/iot
VACA=/home/pi/iot

#
# Hue bridge DEVICE IP or Name and API key
#
HUEDEV=hue1.
#
# replace with your Hue bridge API key
#
HUEAPIKEY=h141PPBfcgxbN5NG

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
#LOC="37.331730N 122.030733W"
#

#
# minimum interval for checking/chaning lights (in sec)
#
SLEEPYTIME=30

#
# controls when the lighting schedule is re-read
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
# issues HUE command to switch a light on an off, designed to 
# track internally actual state of light to reduce unnecessary
# API calls (if the light is ON and we're switching ON, no need
# to make the API call)
#
# TODO: works for up to 5 lights, make this dynamic for 
#       number of unique lights in schedule
#
declare -a _realState=( "unk" "unk" "unk" "unk" "unk" )

switchLight()
{
  if [ "${2}" = "ON" ]; then
    [ "${_realState[${1}]}" != "ON" ] && \
      curl -H "Accept: application/json" \
         -X PUT \
         --silent \
         -o /dev/null \
         --data '{"on":true}' \
         http://${HUEDEV}/api/${HUEAPIKEY}/lights/${1}/state && \
      echo ${1} curled ON $(date +"%m-%d %H:%M:%S")
    _realState[${1}]="ON"
  else
    [ "${_realState[${1}]}" != "OFF" ] && \
      curl -H "Accept: application/json" \
         -X PUT \
         --silent \
         -o /dev/null \
         --data '{"on":false}' \
         http://${HUEDEV}/api/${HUEAPIKEY}/lights/${1}/state && \
      echo ${1} curled OFF $(date +"%m-%d %H:%M:%S")
    _realState[${1}]="OFF"
  fi
}

# main

_ON=false

while true  # {
do
  touch ${NOWFILE}
  if [ ! -f ${TOMFILE} -o ${NOWFILE} -nt ${TOMFILE} ]; then  # {
    getdates
    echo reading today"'"s schedule $(date) or ${_NOW}
    source ${VACA}/hue.sched
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
    #
    # state set up: assume all lights should be OFF
    #
    # TODO: works for up to 5 lights, make this dynamic for 
    #       number of unique lights in schedule
    #
    declare -a lightstate=("OFF" \
                           "OFF" \
                           "OFF" )
  fi  # }

  if daylight ; then  # {

    # ensure all lights are off, it's daytime

    switchLight 1 OFF
    switchLight 2 OFF
    switchLight 3 OFF
    _ON=false

    # now, wait for sunset

    if [ -f /tmp/sunwdebug ]; then
      echo waiting for sunset.
    fi
    ${SW} -v ${WHENDARK} ${LOC}

  else # }  {

    #
    # it's night time, walk through light's schedule
    # turn those on which are supposed to be ON
    #

    for LIGHT in $(seq 0 $((${#lights[@]}-1)))  # {
    do

      _light=$((${lights[${LIGHT}]}-1))

      _NOW=$(date +%s);

      #echo checking ${_light} 
      if [ ${lightsON[${LIGHT}]} -lt ${_NOW} -a \
          ${lightsOFF[${LIGHT}]} -gt ${_NOW} ]; then
        lightstate[${_light}]=ON
        #echo making ${_light} = ON
      fi

    done # }

    tvison
    TVISON=${?}

    for LIGHT in $(seq 0 $((${#lightstate[@]}-1)))  # {
    do

#echo ${LIGHT} should be ${lightstate[${LIGHT}]}
#continue;

      #
      # lights can be drive by night time (bynite) or if
      # on vacation
      #
      if [ ${bynite[${LIGHT}]} -eq ${TRUE} ]; then
        switchLight ${lights[${LIGHT}]} ${lightstate[${LIGHT}]}
      elif onvacation && [ ${byvacation[${LIGHT}]} -eq ${TRUE} ]; then
        switchLight ${lights[${LIGHT}]} ${lightstate[${LIGHT}]}
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
          switchLight ${lights[${LIGHT}]} ON
        else
          switchLight ${lights[${LIGHT}]} OFF
        fi
      fi

    done # }

    #
    # wait for the next interval to change light state
    #
    sleep ${SLEEPYTIME}

  fi  # }

done  # }

exit 1

