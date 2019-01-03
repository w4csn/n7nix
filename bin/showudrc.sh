#!/bin/bash
#
# Uncomment this statement for debug echos
#DEBUG=1

function dbgecho { if [ ! -z "$DEBUG" ] ; then echo "$*"; fi }

# ===== function EEPROM id_check =====

# Return code:
# 0 = no EEPROM or no device tree found
# 1 = HAT found but not a UDRC
# 2 = UDRC
# 3 = UDRC II
# 4 = DRAWS
# 5 = 1WSpot

function id_check() {
# Initialize to EEPROM not found
udrc_prod_id=0

# Does firmware file exist
if [ -f $firmware_prodfile ] ; then
   # Read product file
   UDRC_PROD="$(tr -d '\0' < $firmware_prodfile)"
   # Read vendor file
   FIRM_VENDOR="$(tr -d '\0' < $firmware_vendorfile)"
   # Read product id file
   UDRC_ID="$(tr -d '\0' < $firmware_prod_idfile)"
   #get last character in product id file
   UDRC_ID=${UDRC_ID: -1}

   dbgecho "UDRC_PROD: $UDRC_PROD, ID: $UDRC_ID"

   if [[ "$FIRM_VENDOR" == "$NWDIG_VENDOR_NAME" ]] ; then
      case $UDRC_PROD in
         "Universal Digital Radio Controller")
            udrc_prod_id=2
         ;;
         "Universal Digital Radio Controller II")
            udrc_prod_id=3
         ;;
         "Digital Radio Amateur Work Station")
            udrc_prod_id=4
         ;;
         "1WSpot")
            udrc_prod_id=5
         ;;
         *)
            echo "Found something but not a UDRC: $UDRC_PROD"
            udrc_prod_id=1
         ;;
      esac
   else

      dbgecho "Probably not a NW Digital Radio product: $FIRM_VENDOR"
      udrc_prod_id=1
   fi

   if [ udrc_prod_id != 0 ] && [ udrc_prod_id != 1 ] ; then
      if (( UDRC_ID == udrc_prod_id )) ; then
         dbgecho "Product ID match: $udrc_prod_id"
      else
         echo "Product ID MISMATCH $UDRC_ID : $udrc_prod_id"
         udrc_prod_id=1
      fi
   fi
   dbgecho "Found HAT for ${PROD_ID_NAMES[$UDRC_ID]} with product ID: $UDRC_ID"
else
   # RPi HAT ID EEPROM may not have been programmed in engineering samples
   # or there is no RPi HAT installed.
   udrc_prod_id=0
fi

return $udrc_prod_id
}

# ===== function display_id_eeprom =====

function display_id_eeprom() {
   echo "     HAT ID EEPROM"
   echo "Name:        $(tr -d '\0' </sys/firmware/devicetree/base/hat/name)"
   echo "Product:     $(tr -d '\0' </sys/firmware/devicetree/base/hat/product)"
   echo "Product ID:  $(tr -d '\0' </sys/firmware/devicetree/base/hat/product_id)"
   echo "Product ver: $(tr -d '\0' </sys/firmware/devicetree/base/hat/product_ver)"
   echo "UUID:        $(tr -d '\0' </sys/firmware/devicetree/base/hat/uuid)"
   echo "Vendor:      $(tr -d '\0' </sys/firmware/devicetree/base/hat/vendor)"
}

# ===== function audio_display_ctrl

function audio_display_ctrl() {
   alsa_ctrl="$1"
   PCM_STR="$(amixer -c $CARD get \""$alsa_ctrl"\" | grep -i "Simple mixer control")"
   dbgecho "$alsa_ctrl: $PCM_STR"
   PCM_VAL=$(amixer -c $CARD get \""$alsa_ctrl"\" | grep -i -m 1 "db")
   CTRL_VAL_L=${PCM_VAL##* }
   dbgecho "$alsa_ctrl: Left $PCM_VAL"
   PCM_VAL=$(amixer -c $CARD get \""$alsa_ctrl"\" | grep -i -m 2 "db" | tail -n 1 | cut -d ' ' -f5-)
   CTRL_VAL_R=${PCM_VAL##* }
   dbgecho "$alsa_ctrl: Right $PCM_VAL"
}

# ===== function audio_display_ctrl

function audio_display_ctrl() {
   alsa_ctrl="$1"
   PCM_STR="$(amixer -c $CARD get \""$alsa_ctrl"\" | grep -i "Simple mixer control")"
   dbgecho "$alsa_ctrl: $PCM_STR"
   PCM_VAL=$(amixer -c $CARD get \""$alsa_ctrl"\" | grep -i -m 1 "db")
   CTRL_VAL_L=${PCM_VAL##* }
   dbgecho "$alsa_ctrl: Left $PCM_VAL"
   PCM_VAL=$(amixer -c $CARD get \""$alsa_ctrl"\" | grep -i -m 2 "db" | tail -n 1 | cut -d ' ' -f5-)
   CTRL_VAL_R=${PCM_VAL##* }
   dbgecho "$alsa_ctrl: Right $PCM_VAL"
}

# ===== function display_ctrl

function display_ctrl() {
    alsa_ctrl="$1"
    CTRL_STR="$(amixer -c $CARD get \""$alsa_ctrl"\")"
#    dbgecho "$alsa_ctrl: $CTRL_STR"
    CTRL_VAL=$(amixer -c $CARD get \""$alsa_ctrl"\" | grep -i -m 1 "Item0:" | cut -d ':' -f2)
    # Remove preceeding white space
    CTRL_VAL="$(sed -e 's/^[[:space:]]*//' <<<"$CTRL_VAL")"
    # Remove surrounding quotes
    CTRL_VAL=${CTRL_VAL%\'}
    CTRL_VAL=${CTRL_VAL#\'}
}

# ===== function display alsa settings

function display_alsa() {
# Default card name
CARD="udrc"
echo "==== ALSA Controls for Radio Tansmit ===="

control="LO Driver Gain"
audio_display_ctrl "$control"
printf "%s  L:%s\tR:%s\n" "$control" $CTRL_VAL_L $CTRL_VAL_R

control="PCM"
audio_display_ctrl "$control"
printf "%s\t        L:%s\tR:%s\n" "$control" $CTRL_VAL_L $CTRL_VAL_R

# Running udrc-dkms version 1.0.5 or later
alsactrl_count=$(amixer scontrols | wc -l)

if (( alsactrl_count >= 44 )) ; then
    control="DAC Left Playback PowerTune"
    display_ctrl "$control"
    CTRL_PTM_L="$CTRL_VAL"

    control="DAC Right Playback PowerTune"
    display_ctrl "$control"
    CTRL_PTM_R="$CTRL_VAL"
    # Shorten control string for display
    control="DAC Playback PT"
    printf "%s\tL:[%s]\tR:[%s]\n" "$control" "$CTRL_PTM_L" "$CTRL_PTM_R"

    control="LO Playback Common Mode"
    display_ctrl "$control"
    # echo "DEBUG: CTRL_VAL: $CTRL_VAL"
    # Shorten control string for display
    control="LO Playback CM"
    printf "%s\t[%s]\n" "$control" "$CTRL_VAL"
fi

echo "==== ALSA Controls for Radio Receive ===="

control="ADC Level"
audio_display_ctrl "$control"
printf "%s\tL:%s\tR:%s\n" "$control" $CTRL_VAL_L $CTRL_VAL_R

control="IN1_L to Left Mixer Positive Resistor"
display_ctrl "$control"
CTRL_IN1_L="$CTRL_VAL"

control="IN1_R to Right Mixer Positive Resistor"
display_ctrl "$control"
CTRL_IN1_R="$CTRL_VAL"

control="IN2_L to Left Mixer Positive Resistor"
display_ctrl "$control"
CTRL_IN2_L="$CTRL_VAL"

control="IN2_R to Right Mixer Positive Resistor"
display_ctrl "$control"
CTRL_IN2_R="$CTRL_VAL"

control="IN1"
strlen=${#CTRL_IN1_L}
if ((strlen < 4)) ; then
    printf "%s\t\tL:[%s]\t\tR:[%s]\n" "$control" "$CTRL_IN1_L" "$CTRL_IN1_R"
else
    printf "%s\t\tL:[%s]\tR:[%s]\n" "$control" "$CTRL_IN1_L" "$CTRL_IN1_R"
fi

control="IN2"
strlen=${#CTRL_IN2_L}
if ((strlen < 4)) ; then
    printf "%s\t\tL:[%s]\t\tR:[%s]\n" "$control" "$CTRL_IN2_L" "$CTRL_IN2_R"
else
    printf "%s\t\tL:[%s]\tR:[%s]\n" "$control" "$CTRL_IN2_L" "$CTRL_IN2_R"
fi

}

# ===== Main

# Verify that aplay enumerates udrc sound card

CARDNO=$(aplay -l | grep -i udrc)

echo "==== Sound Card ===="
if [ ! -z "$CARDNO" ] ; then
   echo "udrc card number line: $CARDNO"
   CARDNO=$(echo $CARDNO | cut -d ' ' -f2 | cut -d':' -f1)
   echo "udrc is sound card #$CARDNO"
   display_alsa
else
   echo "No udrc sound card found."
fi

echo "==== Pi Ver ===="
# Raspberry Pi version check based on Revision number from cpuinfo

CPUINFO_FILE="/proc/cpuinfo"
HAS_WIFI=false

# This method works as well
#piver="$(grep "Revision" $CPUINFO_FILE | cut -d':' -f2- | tr -d '[[:space:]]')"

piver="$(grep "Revision" $CPUINFO_FILE)"
piver="$(echo -e "${piver##*:}" | tr -d '[[:space:]]')"

case $piver in
a01040)
   echo " Pi 2 Model B Mfg by Sony UK"
;;
a01041)
   echo " Pi 2 Model B Mfg by Sony UK"
;;
a21041)
   echo " Pi 2 Model B Mfg by Embest"
;;
a22042)
   echo " Pi 2 Model B with BCM2837 Mfg by Embest"
;;
a02082)
   echo " Pi 3 Model B Mfg by Sony UK"
   HAS_WIFI=true
;;
a22082)
   echo " Pi 3 Model B Mfg by Embest"
   HAS_WIFI=true
;;
a32082)
   echo " Pi 3 Model B Mfg by Sony Japan"
   HAS_WIFI=true
;;
a020d3)
   echo " Pi 3 Model B+ Mfg by Sony UK"
   HAS_WIFI=true
;;
*)
   echo -e "\n\t$(tput setaf 1)Unknown pi version: $piver $(tput setaf 7)\n"
;;
esac

if [ "$HAS_WIFI" = "true" ] ; then
   echo " Has WiFi"
fi

echo "==== udrc Ver ===="
# UDRC ID EEPROM check
# - return the product ID found in EEPROM
#
# 0 = no EEPROM or no device tree found
# 1 = HAT found but not a UDRC
# 2 = UDRC
# 3 = UDRC II
# 4 = DRAWS
# 5 = 1WSpot

firmware_prodfile="/sys/firmware/devicetree/base/hat/product"
firmware_prod_idfile="/sys/firmware/devicetree/base/hat/product_id"
firmware_vendorfile="/sys/firmware/devicetree/base/hat/vendor"

PROD_ID_NAMES=("INVALID" "INVALID" "UDRC" "UDRC II" "1WSpot")
NWDIG_VENDOR_NAME="NW Digital Radio"

id_check
return_val=$?
dbgecho "Return val: $return_val"

case $return_val in
0)
   echo "HAT firmware not initialized or HAT not installed."
   echo -e "\n\t$(tput setaf 1)No id eeprom found $(tput setaf 7)\n"
;;
1)
   echo "Found a HAT but not a UDRC, product not identified"
   display_id_eeprom
;;
2)
   echo "Found an original UDRC"
   echo
   display_id_eeprom
;;
3)
   echo "Found a UDRC II"
   echo
   display_id_eeprom
;;
4)
   echo "Found a DRAWS"
   echo
   display_id_eeprom
;;
5)
   echo "Found a One Watt Spot"
   echo
   display_id_eeprom
;;
*)
   echo "Undefined return code: $return_val"
;;
esac

echo
echo "==== sys Ver ===="

echo "----- /proc/version"
cat /proc/version
echo
echo "----- /etc/*version: $(cat /etc/*version)"
echo
echo "----- /etc/*release"
cat /etc/*release
echo
echo "----- lsb_release"
lsb_release -a
echo
echo "---- systemd"
hostnamectl
echo
echo "---- modules"
lsmod | egrep -e '(udrc|tlv320)'
dkmsdir="/lib/modules/$(uname -r)/updates/dkms"
echo
if [ -d "$dkmsdir" ] ; then
   ls -o $dkmsdir/udrc.ko $dkmsdir/tlv320aic32x4*.ko
else
   echo "Command 'apt-get install udrc-dkms' failed or was not run."
fi

echo
echo "---- kernel"
dpkg -l "*kernel" "udrc-dkms" | tail -n 4

echo
echo "---- compass"
preference_file="/etc/apt/preferences.d/compass"
if [ -f "$preference_file" ] ; then
   echo "---- compass preference file"
   cat "$preference_file"
else
   echo "Compass preference file not found: $preference_file"
fi

sources_list_file="/etc/apt/sources.list.d/compass.list"
if [ -f "$sources_list_file" ] ; then
   echo "---- compass apt sources list file"
   cat "$sources_list_file"
else
   echo "Compass apt sources list file not found: $sources_list_file"
fi
echo "---- compass package files"
ls -o /var/lib/apt/lists/archive.compasslinux.org_*
echo
# Check version of direwolf installed
type -P direwolf &>/dev/null
if [ $? -ne 0 ] ; then
   echo "----- No direwolf program found in path"
else
   verstr="$(direwolf -v 2>/dev/null |  grep -m 1 -i version)"
   # Get rid of escape characters
   echo "----- D${verstr#*D}"
fi
echo
echo "==== boot config ===="
tail -n 15 /boot/config.txt
echo
echo "---- gpsd"
systemctl status gpsd
echo
echo "---- chrony"
systemctl status gpsd
echo "-- chrony sources"
chronyc sources
echo "-- chrony tracking"
chronyc tracking
echo "-- chrony sourcestats"
chronyc sourcestats
echo
echo "---- sensors"
ls -alt /etc/sensors.d/*
sensors

