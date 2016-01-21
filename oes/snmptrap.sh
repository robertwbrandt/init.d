#!/bin/bash
#
#     Script to launch SNMP Trap Deamon
#     Bob Brandt <projects@brandt.ie>
#          
#
### BEGIN INIT INFO
# Provides: brandt-snmptrap
# Required-Start: $ALL
# Required-Stop:
# Default-Start: 3 5
# Default-Stop: 0 1 2 6
# Description: this script launches the snmp trap deamon
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
_this_script=/opt/brandt/init.d/oes/snmptrap.sh
_this_initd=/etc/init.d/brandt-snmptrap
_this_rc=/usr/local/bin/rcbrandt-snmptrap
_bin_snmptrap=/usr/sbin/slpd
_conf_snmptrap=/etc/slp.conf 
_initd_snmptrap=/etc/init.d/slpd
_snmptrap_sysconfig=/etc/sysconfig/net-snmp

. "$_brandt_utils"
[ ! -r "$_snmptrap_sysconfig" ] && echo "Unable to find required file: $_snmptrap_sysconfig" 1>&2 && exit 6
. "$_snmptrap_sysconfig"


function installed() {
    brandt_deamon_wrapper "Novell SNMP Trap daemon" "$_bin_snmptrap" installed
    return $?
}

function configured() {
    brandt_deamon_wrapper "Novell SNMP Trap daemon" "$_conf_snmptrap" configured
    return $?
}

function setup() {
    local _status=0     
	ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
    _status=$(( $_status | $? ))
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
    return $(( $_status | $? ))
}

function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( echo -e "Usage: $0 [options] command"
	  echo -e "Commands:  start     stop     status   restart"
	  echo -e "Options:"
	  echo -e " -q, --quiet    be quiet"
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
	"start" | "stop" | "status" | "restart" )	
                    brandt_deamon_wrapper "Novell SNMP Trap daemon" "$_initd_snmptrap" $_command $@ ;;
    "setup" )		setup ;;
    * )        		usage 1 ;;
esac
exit $?
