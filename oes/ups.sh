#!/bin/sh
#
#     Wrapper for UPS software
#     Bob Brandt <projects@brandt.ie>
#          
#
### BEGIN INIT INFO
# Provides:          UPS
# Required-Start:    $ALL
# Default-Start:     3 5
# Default-Stop:      0 1 2 6
# Short-Description: UPS Shutdown Software
# Description:       This script is a generic script desinged to
#	allow for easy switch between different makes of UPS
#	software.
### END INIT INFO

_version=1.1
_brandt_utils=/opt/brandt/brandt-utils.sh
_this_script=/opt/brandt/init.d/ups
_this_rc=/usr/local/bin/rcbrandt-ups
_this_conf=/etc/brandt/ups.conf

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
if [ ! -r "$_this_conf" ]; then
    ( echo -e "#     Configuration file for UPS wrapper startup script"
      echo -e "#     Bob Brandt <projects@brandt.ie>\n#"
      echo -e "_ups_provider='rccmd'" ) > "$_this_conf"
    echo "Unable to find required file: $_this_conf" 1>&2
fi

. "$_brandt_utils"
. "$_this_conf"

declare -a _ups_scripts=("/etc/init.d/PowerChute" "/etc/init.d/powerd" "/etc/init.d/uGuard" "/etc/init.d/rccmd_start")
declare -a _ups_names=("apc" "powerd" "uguard" "rccmd")

# Remove UPS Scripts that are not present on the system.
#  and set the chosen INITD_SCRIPT
_length=${#_ups_scripts[*]}
for (( i=0; i<${_length}; i++ )); do
    if [ ! -x "${_ups_scripts[$i]}" ]; then
        unset _ups_scripts[$i]
        unset _ups_names[$i]
    fi
    if [ "${_ups_names[$i]}" == "$_ups_provider" ]; then
        _ups_script=${_ups_scripts[$i]}
    fi
done
_ups_DisplayNames=$( echo ${_ups_names[*]}  | sed "s/ /|/g" )

if [ "$1" != "setup" ] && [ -z "$_ups_script" ]; then
    logger -st "$( basename $0 )" "Unable to find a startup script for $_ups_provider. Please run the following command: $( basename $0 ) setup [$_ups_DisplayNames]"
    exit 1
fi

function installed() { return 0; }
function configured() { return 0; }

function setup() {
    local _status=0
    ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
    _status=$?

    for (( i=0; i<${_length}; i++ )); do
        if [ -n "${_ups_scripts[$i]}" ]; then
            echo "Turning off the ${_ups_names[$i]} script ${_ups_scripts[$i]}"
            chkconfig $( basename ${_ups_scripts[$i]} ) off > /dev/null 2>&1
            ${_ups_scripts[$i]} stop > /dev/null 2>&1
        fi
    done
    chkconfig $( echo $WRAPPER_SCRIPT  | sed 's|.*/||' ) on > /dev/null 2>&1
    [ -n "$_script" ] && $0 set $_script

    return $(( $_status | $? ))
}

function usage() {
    local _exitcode=${1-0}
    local _output=2

    [ "$_exitcode" == "0" ] && _output=1
    [ "$2" == "" ] || echo -e "$2"
    ( echo -e "Usage: $0 {start|stop|status|try-restart|restart|force-reload|reload|probe|get|set(up) [$_ups_DisplayNames]}"
      echo -e "Options:"
      echo -e " -h, --help     display this help and exit"
      echo -e " -v, --version  output version information and exit\n" 
      [ -n "$_ups_script" ] && $_ups_script --help 2>&1
      echo -e "\nvSphere Management Assistant - https://$( hostname ):5480/"
      [ "$_ups_provider" == "apc" ] && echo -e "PowerChute Network Shutdown  - https://$( hostname ):6547/"
      [ "$_ups_provider" == "rccmd" ] && echo -e "RCCMD Admin                  - https://$( hostname ):8443/" ) >&$_output
    exit $_exitcode
}

# Execute getopt
if ! _args=$( getopt -o vh -l "help,version" -n "$0" -- "$@" 2>/dev/null ); then
    _err=$( getopt -o vh -l "help,version" -n "$0" -- "$@" 2>&1 >/dev/null )
    usage 1 "${BOLD_RED}$_err${NORMAL}"
fi

#Bad arguments
#[ $? -ne 0 ] && usage 1 "$0: No arguments supplied!\n"

eval set -- "$_args";
_quiet=1
while /bin/true ; do
    case "$1" in
        -h | --help )      usage 0 ;;
        -v | --version )   brandt_version $_version ;;
        -- )               shift ; break ;;
        * )                usage 1 "${BOLD_RED}$0: Invalid argument!${NORMAL}" ;;
    esac
    shift
done
_command=$( lower "$1" )
shift 1

# Check to see if installed and configured
if [ "$_command" == "installed" ] || [ "$_command" == "configured" ]; then
    ( ( installed ) >&$_quiet ) 2>/dev/null
    exit $?
fi

# Check to see if user is root, if not re-run script as root.
brandt_amiroot || { echo "${BOLD_RED}This program must be run as root!${NORMAL}" >&2 ; sudo "$0" $@ ; exit $?; }

case "$_command" in
    start|stop|status|try-restart|restart|probe|force-reload|reload)
        ## Pass command lines parameters to UPS INIT.D Script
        brandt_deamon_wrapper "$( upper $_ups_provider ) UPS Software" "$_ups_script" "$_command" "$@"
        ;;
    set)
        tmp=$( echo "$@" | sed 's|.*/||' )
        tmp=$( lower $tmp )
        sed -i "s|^_ups_provider=.*|_ups_provider=$tmp|" $_this_conf
        $0 get
        ;;
    get)
        echo "This script is using the $( upper $_ups_provider ) UPS Software."
        echo " The $_ups_provider startup script is $_ups_script"
        ;;
    setup)
        setup
        [ -n "$@" ] && $0 set $@
        $0 restart
        ;;      
    * )         usage 1 ;;

esac
exit $?
