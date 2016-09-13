#!/bin/bash
#
#     Wrapper startup script for Squid
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

_version=1.2
_brandt_utils=/opt/brandt/common/brandt.sh
_this_script=/opt/brandt/init.d/squid.sh
_this_rc=/usr/local/bin/rcbrandt-squid
_this_initd=/etc/init.d/brandt-squid
_initd_squid=/etc/init.d/squid
_conf_squid=/etc/squid/squid.conf

[ ! -r "$_initd_squid" ] && echo "Squid must be installed! Unable to find required file: $_initd_squid" 1>&2 && exit 6
[ ! -x "/usr/bin/php" ] && echo "PHP must be installed!" 1>&2 && exit 6

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
. "$_brandt_utils"


function installed() { return 0 ; }
function configured() { return 0 ; }

function setup() {
    local _status=0     
    ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
    _status=$?
    ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
    return $(( $_status | $? ))
}

function status() {
    local _status=0 

    if [ "$_verbose" == "1" ]; then
        $_initd_squid status
        _status=$?
    else
        echo -n "Checking for Squid deamon "
        $_initd_squid status > /dev/null 2>&1
        brandt_status status
        _status=$?
    fi

    return $_status
}

function start() {
    local _status=0 
    local _count=5
    local _waittime=5

    while [[ $((_count--)) -gt 0 ]]; do
        test -f "$_conf_squid" && break
        logger -st "squid" "Unable to open configuration file: $_conf_squid: No such file or directory. Waiting $_waittime seconds before attempting another start."
        mount -a
        sleep $_waittime
    done

    if [ -f "$_conf_squid" ]; then
        if [ "$_verbose" == "1" ]; then
            $_initd_squid start
            _status=$?
        else
            echo -n "Starting Squid deamon "
            $_initd_squid start > /dev/null 2>&1
            brandt_status start
            _status=$?
        fi
    else
        logger -st "squid" "Unable to open configuration file: $_conf_squid: No such file or directory"
        _status=7
    fi

    return $_status
}

function allothercommands() {
    local _status=0 
    local _command=$1

    if [ "$_verbose" == "1" ]; then
        $_initd_squid $_command
        _status=$?
    else
        brandt_deamon_wrapper "Squid deamon" "$_initd_squid" "$_command"
        _status=$?
    fi

    return $_status
}

function usage() {
    local _exitcode=${1-0}
    local _output=2
    [ "$_exitcode" == "0" ] && _output=1
    [ "$2" == "" ] || echo -e "$2"
    ( echo -e "Usage: $0 [options] command"
      echo -e "Commands:  start     stop         status"
      echo -e "           restart   condrestart  reload"
      echo -e "Options:"
      echo -e " -v, --verbose  be verbose"
      echo -e " -h, --help     display this help and exit"
      echo -e " -V, --version  output version information and exit" ) >&$_output
    exit $_exitcode
}

# Execute getopt
if ! _args=$( getopt -o vhV -l "verbose,help,version" -n "$0" -- "$@" 2>/dev/null ); then
    _err=$( getopt -o vhV -l "verbose,help,version" -n "$0" -- "$@" 2>&1 >/dev/null )
    usage 1 "${BOLD_RED}$_err${NORMAL}"
fi

#Bad arguments
#[ $? -ne 0 ] && usage 1 "$0: No arguments supplied!\n"

eval set -- "$_args";

_verbose=0
while /bin/true ; do
    case "$1" in
        -v | --verbose )   _verbose=1 ;;
        -h | --help )      usage 0 ;;
        -V | --version )   brandt_version $_version ;;
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
    "setup" )        setup ;;
    "status" )       status ;;
    "start" )        start ;;
    "stop" )         allothercommands "$_command" ;;
    "restart" )      allothercommands "$_command" ;;
    "force-reload" ) allothercommands "$_command" ;;
    "reload" )       allothercommands "$_command" ;;
    * )              usage 1 ;;
esac
exit $?
