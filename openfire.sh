#!/bin/bash
#
#     Wrapper startup script for OpenFire
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
_this_script=/opt/brandt/init.d/openfire.sh
_this_rc=/usr/local/bin/rcbrandt-openfire
_this_initd=/etc/init.d/brandt-openfire
_initd_openfire=/etc/init.d/openfire
_initd_apache=/etc/init.d/apache2

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
    local _substatus=$( lower ${1:-all} )
    brandt_deamon_wrapper "Openfire IM Deamon" "$_initd_openfire" "status"
    _status=$?

    if [ "$_substatus" == "web" ] || [ "$_substatus" == "all" ]; then
        brandt_deamon_wrapper "Openfire SparkWeb Service" "$_initd_apache" "status"
        _status=$(( $_status | $? ))

        echo -n "Verifying SparkWeb Service is responding"
        wget --no-check-certificate -O - -o /dev/null "https://im.i.opw.ie/" | grep '<title>SparkWeb</title>' > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
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
      echo -e " -h, --help     display this help and exit"
      echo -e " -v, --version  output version information and exit" ) >&$_output
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
    "setup" )   setup ;;
    "status" )  status "$@" ;;
    "start" | "stop" | "restart" | "condrestart" | "reload" )
            brandt_deamon_wrapper "Openfire IM Deamon" "$_initd_openfire" "$command" ;;         
    * )         usage 1 ;;
esac
exit $?
