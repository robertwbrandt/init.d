#!/bin/bash
#
#     Wrapper startup script for Network
#     Bob Brandt <projects@brandt.ie>
#          

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
_this_script=/opt/brandt/init.d/oes/network.sh
_this_rc=/usr/local/bin/rcbrandt-network
_initd_network=/etc/init.d/network

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
. "$_brandt_utils"


function installed() { return 0 ; }
function configured() { return 0 ; }

function setup() {
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
	return $?
}

function status() {
    if [ "$_quiet" == "2" ]; then
        local _status=0
    	local _ip=""
        echo -n "Checking Network Interfaces "
    	$_initd_network status  > /dev/null 2>&1
    	_status=$?

    	if [ "$_status" == "0" ] && tmp=$( /sbin/ifconfig eth0 | grep "inet addr:" )
    	then
    		MASK=$( echo $tmp | sed "s| |:|g" | cut -f7 -d: )
    		MASK1=$( echo $MASK | cut -f1 -d. )
    		MASK2=$( echo $MASK | cut -f2 -d. )
    		MASK3=$( echo $MASK | cut -f3 -d. )
    		MASK4=$( echo $MASK | cut -f4 -d. )
    		MASKBIN=$( echo "ibase=10;obase=2;$MASK1" | bc )$( echo "ibase=10;obase=2;$MASK2" | bc )$( echo "ibase=10;obase=2;$MASK3" | bc )$( echo "ibase=10;obase=2;$MASK4" | bc )
    		echo -n "("$( echo $tmp | sed "s| |:|g" | cut -f3 -d: )"/"$( echo "$MASKBIN" | tr -dc '1' | wc -c )$(  ip r | sed -n "s|default||p" | sed -n "s| dev.*||p" )"): "
    	fi
        returnvalue $_status
        brandt_status status
    else
        $_initd_network status
        return $?
    fi
	return $(( $_status | $? ))
}

function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( $_initd_network | sed "s|Usage:.*<action>|Usage: $0 <action>|" ) >&$_output
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
    "setup" )	setup ;;
    "status" )	status "$_command" $@ ;;
	"start" | "stop" | "reload" | "force-reload" | "try-restart" | "restart" | "stop-all-dhcp-clients" | "restart-all-dhcp-clients" )
				brandt_deamon_wrapper "Network deamon" "$_initd_network" "$command" "$@" ;;
    * )			usage 1 ;;
esac
exit $?
