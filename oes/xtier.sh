#!/bin/bash
#
#     Wrapper startup script for Novell XTier Deamons (HTTP to and from NCP)
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
_this_script=/opt/brandt/init.d/oes/xtier.sh
_this_rc=/usr/local/bin/rcbrandt-xtier
_bin_xtier_xreg=/opt/novell/xtier/bin/novell-xregd
_bin_xtier_xsrv=/opt/novell/xtier/bin/novell-xsrvd
_initd_xtier_xreg=/etc/init.d/novell-xregd
_initd_xtier_xsrv=/etc/init.d/novell-xsrvd

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
. "$_brandt_utils"

function installed() {
    local _status=0
    brandt_deamon_wrapper "Novell XTier HTTP daemon" "$_bin_xtier_xreg" installed
    _status=$(( $_status | $? ))
    brandt_deamon_wrapper "Novell XTier NCP daemon" "$_bin_xtier_xsrv" installed
    return $(( $_status | $? ))
}

function configured() {
    local _status=0
    # brandt_deamon_wrapper "Novell XTier HTTP daemon" "$_bin_xtier_xreg" installed
    # _status=$(( $_status | $? ))
    # brandt_deamon_wrapper "Novell XTier NCP daemon" "$_bin_xtier_xsrv" installed
    return $(( $_status | $? ))
}

function deamons() {
    local _command=${1:-status}
    shift   
    local _status=0
    if [ -x "$_bin_xtier_xreg" ]; then
        brandt_deamon_wrapper "Novell XTier (HTTP to NCP) daemon" "$_initd_xtier_xreg" "$_command" $@
        _status=$(( $_status | $? ))
    fi
    if [ -x "$_bin_xtier_xsrv" ]; then   
        brandt_deamon_wrapper "Novell XTier (NCP to HTTP) daemon" "$_initd_xtier_xsrv" "$_command" $@
        _status=$(( $_status | $? ))
    fi        
    return $_status
}

function setup() {
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
	return $?
}

function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( echo -e "Usage: $0 [options] command"
	  echo -e "Commands:  start    stop     status"
	  echo -e "           restart  reload   force-reload"
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
	"start" | "stop" | "reload" | "force-reload" | "restart" | "status" )	
				deamons $_command $@ ;;
    "setup" )	setup ;;
    * )        	usage 1 ;;
esac
exit $?
