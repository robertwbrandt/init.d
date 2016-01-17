#!/bin/bash
#
#     Wrapper startup script for McAfee startup script
#     Bob Brandt <projects@brandt.ie>
#          
#
### BEGIN INIT INFO
# Provides:          brandt-mcafee
# Required-Start:    $ALL
# Required-Stop:
# Default-Start:     3 5
# Default-Stop:      0 1 2 6
# Short-Description: McAfee Antivirus
# Description:       Wrapper for McAfee Antivirus
### END INIT INFO
#
# exit status 0)  success
# exit status 1)  generic or unspecified error
# exit status 2)  invalid or excess args
# exit status 3)  unimplemented feature
# exit status 4)  insufficient privilege
# exit status 5)  program is not installed
# exit status 6)  program is not configured
# exit status 7)  program is not running
# exit status *)  unknown (maybe used in future)

_version=1.1
_brandt_utils=/opt/brandt/brandt-utils.sh
_bin_cma=/opt/McAfee/cma/bin/cma
_bin_linuxshield=/opt/NAI/LinuxShield/libexec/scanner
# _conf_cma=/etc/dhcpd.conf
# _conf_linuxshield=/etc/openldap/ldap.conf
_initd_cma=/etc/init.d/cma
_initd_linuxshield=/etc/init.d/nails
_this_script=/opt/brandt/init.d/mcafee
_this_initd=/etc/init.d/brandt-mcafee
_this_rc=/usr/local/bin/rcbrandt-mcafee
_this_cron=/etc/cron.hourly/mcafee-reload

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
. "$_brandt_utils"

function installed() {
    local _status=0
    brandt_deamon_wrapper "LinuxShield daemon" "$_bin_linuxshield" installed
    _status=$(( $_status | $? ))
    brandt_deamon_wrapper "CMA daemon" "$_bin_cma" installed
    return $(( $_status | $? ))
}

function configured() {
    local _status=0
    # brandt_deamon_wrapper "LinuxShield daemon" "$_conf_linuxshield" configured
    # _status=$(( $_status | $? ))
    # brandt_deamon_wrapper "CMA daemon" "$_conf_cma" configured
    return $(( $_status | $? ))
}

function start() {
    local _command=${1:-start}
    shift
    local _status=0 
    brandt_deamon_wrapper "McAfee Agent services" "$_initd_cma" "$_command" $@
    _status=$(( $_status | $? ))
    brandt_deamon_wrapper "McAfeeVSEForLinux services" "$_initd_linuxshield" "$_command" $@
    return $(( $_status | $? ))
}

function stop() {
    local _command=${1:-stop}
    shift    
    local _status=0 
    brandt_deamon_wrapper "McAfeeVSEForLinux services" "$_initd_linuxshield"  "$_command" $@
    _status=$(( $_status | $? ))
    brandt_deamon_wrapper "McAfee Agent services" "$_initd_cma"  "$_command" $@
    return $(( $_status | $? ))
}

function status() {
    local _status=0 
    brandt_deamon_wrapper "McAfee Agent services" "$_initd_cma" status
    _status=$(( $_status | $? ))
    brandt_deamon_wrapper "McAfeeVSEForLinux services" "$_bin_linuxshield" status-checkproc
    return $(( $_status | $? ))
}

function setup_initd() {
    local _status=0
    echo -n "Modifying system services (init.d scripts) "
    chkconfig $( basename "$_initd_cma" ) off > /dev/null 2>&1
    _status=$(( $_status | $? ))
    chkconfig $( basename "$_initd_linuxshield" ) off > /dev/null 2>&1
    _status=$(( $_status | $? ))
    #chkconfig $( basename "$_this_initd" ) on > /dev/null 2>&1 && chkconfig $( basename "$_this_initd" ) 35 > /dev/null 2>&1
    #returnvalue $(( $_status | $? ))
    brandt_status setup
    return $?
}

function setup() {
    local _status=0
    ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
    _status=$(( $_status | $? ))
    ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
    _status=$(( $_status | $? ))
    if ! installed > /dev/null
    then
        echo -e "Installing McAfee"
        /opt/McAfee/install.sh -i
    _status=$(( $_status | $? ))
    fi
    setup_initd
    return $(( $_status | $? ))
}

function usage() {
    local _exitcode=${1-0}
    local _output=2
    [ "$_exitcode" == "0" ] && _output=1
    [ "$2" == "" ] || echo -e "$2"
    ( echo -e "Usage: $0 [options] command"
      echo -e "Commands:  start      stop       status"
      echo -e "           restart    basedir    configdir"
      echo -e "           reload SOFTWAREID"
      echo -e "           unload SOFTWAREID"
      echo -e "           setup"
      echo -e "Options:"
      echo -e " -h, --help     display this help and exit"
      echo -e " -v, --version  output version information and exit" ) >&$_output
    exit $_exitcode
}

# Execute getopt
if ! _args=$( getopt -o qvh -l "quiet,help,version" -n "$0" -- "$@" 2>/dev/null ); then
    _err=$( getopt -o qvh -l "quiet,help,version" -n "$0" -- "$@" 2>&1 >/dev/null )
    usage 1 "${BOLD_RED}$_err${NORMAL}"
fi

#Bad arguments
#[ $? -ne 0 ] && usage 1 "$0: No arguments supplied!\n"

eval set -- "$_args";
_quiet=1
while /bin/true ; do
    case "$1" in
        -q | --quiet )     _quiet=2 ;;
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
    "start" | "restart" | "reload" ) 
                start $_command $@ ;;
    "stop" | "kill" )
                stop $_command $@ ;;
    "status" )  status ;;
    "setup" )   setup ;;
    "basedir" | "configdir" | "unload" )    
                $_initd_cma "$_command" $@ ;;
    * )         usage 1 ;;
esac
exit $?
