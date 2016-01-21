#!/bin/bash
#
#     Wrapper startup script for SLP deamon
#     Bob Brandt <projects@brandt.ie>
#          
### BEGIN INIT INFO
# Provides:          brandt-slp
# Required-Start:    $network $named
# Required-Stop:
# Default-Start:     3 5
# Default-Stop:      0 1 2 4 6
# Description: slpd - OpenSLP daemon for the Service Location Protocol
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
_brandt_utils=/opt/brandt/common/brandt.sh
_this_script=/opt/brandt/init.d/oes/slp.sh
_this_rc=/usr/local/bin/rcbrandt-slp
_this_conf=/etc/brandt/slp.conf
_bin_slp=/usr/sbin/slpd
_conf_slp=/etc/slp.conf 
_initd_slp=/etc/init.d/slpd
_this_conf=/etc/brandt/dhcp.conf

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
if [ ! -r "$_this_conf" ]; then
	( echo -e "#     Configuration file for SLP wrapper startup script"
	  echo -e "#     Bob Brandt <projects@brandt.ie>\n#"
	  echo -e "_slp_scope=OPW-SCOPE"
	  echo -e "_slp_das=slp.opw.ie,slp1.opw.ie,slp2.opw.ie,slp3.opw.ie"
	  echo -e "_slp_broadcast=false" ) > "$_this_conf"
	echo "Unable to find required file: $_this_conf" 1>&2
fi

. "$_brandt_utils"
. "$_this_conf"

function installed() {
    brandt_deamon_wrapper "Novell SLP daemon" "$_bin_slp" installed
	return $?
}

function configured() {
    brandt_deamon_wrapper "Novell SLP daemon" "$_conf_slp" configured
	return $?
}

function setup_config() {
	local _status=0	
	echo -n "Modifying SLP Scope Definition: "
	sed -i "s|.*net\.slp\.useScopes.*|net\.slp\.useScopes = $SLP_SCOPE|g" "$_conf_slp"
	brandt_status setup
	_status=$(( $_status | $? ))

	echo -n "Modifying SLP DA Servers: "
	sed -i "s|.*net\.slp\.DAAddresses.*|net\.slp\.DAAddresses = $SLP_DAS|g" "$_conf_slp"
	brandt_status setup
	_status=$(( $_status | $? ))

	echo -n "Modifying SLP Broadcast Setting: "
	sed -i "s|.*net\.slp\.isBroadcastOnly.*|net\.slp\.isBroadcastOnly = $SLP_BROADCAST|g" "$_conf_slp"
	brandt_status setup
	return $(( $_status | $? ))
}

function setup() {
	local _status=0
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
	_status=$(( $_status | $? ))	

	setup_config
	return $(( $_status | $? ))
}

function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( echo -e "Usage: $0 [options] command"
	  echo -e "Commands:  start    stop     status"
	  echo -e "           restart  reload   setup"
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
	returnvalue $? 5 || exit $?

	( ( configured ) >&$_quiet ) 2>/dev/null
	returnvalue $? 6
	exit $?
else
	installed >/dev/null
	returnvalue $? 5 || becho --exit "${BOLD_RED}The necessary binarys are not installed!${NORMAL}"

	configured >/dev/null
	returnvalue $? 6 || becho --exit "${BOLD_RED}The necessary binarys are not configured!${NORMAL}"
fi

# Check to see if user is root, if not re-run script as root.
brandt_amiroot || { echo "${BOLD_RED}This program must be run as root!${NORMAL}" >&2 ; sudo "$0" $@ ; exit $?; }

case "$_command" in
	"start" | "stop" | "try-restart" | "restart" | "force-reload" | "reload" | "status" )
    			brandt_deamon_wrapper "Novell SLP daemon" "$_initd_slp" "$_command" $@ ;;
    "setup" )	setup ;;
    * )        	usage 1 ;;
esac
exit $?
