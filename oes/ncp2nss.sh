#!/bin/bash
#
#     Wrapper startup script for Novell Novell NCP/NSS IPC Deamon
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
_this_script=/opt/brandt/init.d/oes/ncp2nss.sh
_this_rc=/usr/local/bin/rcbrandt-ncp2nss
_bin_ncp2nss=/opt/novell/httpstkd/sbin/httpstkd
_initd_ncp2nss=/etc/init.d/novell-httpstkd

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
. "$_brandt_utils"


function installed() {
    brandt_deamon_wrapper "Novell NCP/NSS IPC daemon" "$_bin_ncp2nss" installed
	return $?
}

function status() {
	local _quiet=${1:-1}
	if [ "$_quiet" == "2" ]; then
		$_initd_ncp2nss status
	else
	    brandt_deamon_wrapper "Novell NCP/NSS IPC daemon" "$_bin_ncp2nss" status-checkproc
	fi
	return $?
}

function setup() {
	local _status=0		
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
	_status=$?

	ncpcon SET SYNC_TRUSTEES_TO_NSS_AT_VOLUME_MOUNT=1
	_status=$(( $_status | $? ))
	ncpcon SET SENDFILE_SUPPORT=1
	_status=$(( $_status | $? ))
	ncpcon SET COMMIT_FILE=1
	_status=$(( $_status | $? ))
	ncpcon SET LOCAL_CODE_PAGE=CP850
	_status=$(( $_status | $? ))
	ncpcon SET OPLOCK_SUPPORT_LEVEL=0
	_status=$(( $_status | $? ))
	ncpcon SET CROSS_PROTOCOL_LOCKS=1	
	return $(( $_status | $? ))
}

function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( echo -e "Usage: $0 [options] command"
	  echo -e "Commands:  start     stop     status"
	  echo -e "           restart   setup"
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
	"start" | "stop" | "restart" )
			    brandt_deamon_wrapper "Novell NCP/NSS IPC daemon" "$_initd_ncp2nss" "$_command" $@ ;;
	"status" ) 	status "$_quiet" ;;
    "setup" )	setup ;;
    * )        	usage 1 ;;
esac
exit $?
