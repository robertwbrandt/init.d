#!/bin/bash
#
#     Wrapper startup script for the Zarafa
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
_this_conf=/etc/brandt/zarafa.conf
_this_script=/opt/brandt/init.d/zarafa
_this_rc=/usr/local/bin/rcbrandt-zarafa

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
if [ ! -r "$_this_conf" ]; then
    ( echo -e "#     Configuration file for Zarafa script"
      echo -e "#     Bob Brandt <projects@brandt.ie>\n#"
      echo -e "ZarafaConf=/etc/zarafa/server.cfg"
      echo -e "ZarafaServerBin=/usr/bin/zarafa-server"
      echo -e "ZarafaCalDavBin=/usr/bin/zarafa-ical"
      echo -e "ZarafaIMAPBin=/usr/bin/zarafa-gateway"
      echo -e "ZarafaIMAPUser='castrof'"
      echo -e "ZarafaIMAPPass='cuba'"
      echo -e "ZarafaZPushURL='http://zarafa1.i.opw.ie/Microsoft-Server-ActiveSync'"
      echo -e "ZarafaZPushUser='castrof'"
      echo -e "ZarafaZPushPass='cuba'" ) > "$_this_conf"
    echo "Unable to find required file: $_this_conf" 1>&2
fi
. "$_brandt_utils"
. "$_this_conf"

function installed() {
    brandt_deamon_wrapper "Zarafa Server" "$ZarafaServerBin" installed
    return $?
}

function configured() {
    brandt_deamon_wrapper "Zarafa Server" "$ZarafaConf" configured
    return $?
}

function setup() {
    local _status=0
    ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
    _status=$?

    chownmod root:root 644 "$_this_conf" > /dev/null 2>&1
    _status=$(( $_status | $? ))
    return $(( $_status | $? ))
}

function start() {
    echo -n "Starting up Zarafa Deamon"
    zentyal zarafa start > /dev/null 2>&1
    brandt_status start    
    return $?
}

function stop() {
    echo -n "Shutting down Zarafa Deamon"
    zentyal zarafa stop > /dev/null 2>&1
    brandt_status stop    
    return $?
}

function restart() {
    echo -n "Restart Zarafa Deamon"
    zentyal zarafa restart > /dev/null 2>&1
    brandt_status restart    
    return $?
}

function status() {
    local _status=0 
    local _substatus=$( lower ${1:-all} )

    echo -n "Checking for Zarafa Deamon"
    zentyal zarafa status > /dev/null 2>&1
    brandt_status status  
    _status=$?
    
    if [ "$_substatus" == "mta" ] || [ "$_substatus" == "all" ]; then
        echo -n "Checking for SMTP Service"
        service postfix status > /dev/null 2>&1
        brandt_status status  
        _status=$(( $_status | $? ))

        echo -n "Verifying SMTP Service is responding"
        tmp=$( ( sleep 1 ; echo "helo client.test.com"; sleep 1; echo "noop" ; sleep 1 ; echo "quit" ) | telnet 127.0.0.1 25 2> /dev/null )
        echo "$tmp" | grep -i "250.*OK" > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi
    if [ "$_substatus" == "mda" ] || [ "$_substatus" == "all" ]; then
        echo -n "Checking for Zarafa Deamon"
        zentyal zarafa status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi
    if [ "$_substatus" == "web" ] || [ "$_substatus" == "all" ]; then
        echo -n "Checking for Apache Deamon"
        service apache2 status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))

        echo -n "Verifying HTTP WebApp Service is responding"
        wget --no-check-certificate -O - -o /dev/null "https://127.0.0.1/webapp" | grep '<title>Zarafa WebApp</title>' > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi
    if [ "$_substatus" == "imap" ] || [ "$_substatus" == "all" ]; then
        brandt_deamon_wrapper "Zarafa IMAP Service" "$ZarafaIMAPBin" "status-process"
        _status=$(( $_status | $? ))

        echo -n "Verifying IMAP Service is responding"
        tmp=$( ( sleep 1 ; echo -e "a1 login \"$ZarafaIMAPUser\" \"$ZarafaIMAPPass\""; sleep 1; echo 'a2 list "" "*"' ; sleep 1 ; echo 'a3 logout' ) | openssl s_client -connect 127.0.0.1:993 -quiet 2> /dev/null )
        ( echo "$tmp" | grep -i "a1.*OK.*LOGIN.*completed" && echo "$tmp" | grep -i "a2.*OK.*LIST.*completed" ) > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi
    if [ "$_substatus" == "caldav" ] || [ "$_substatus" == "all" ]; then
        brandt_deamon_wrapper "Zarafa CalDav Service" "$ZarafaCalDavBin" "status-process"
        _status=$(( $_status | $? ))
    fi
    if [ "$_substatus" == "mobile" ] || [ "$_substatus" == "all" ]; then
        echo -n "Verifying ActiveSync Service is responding"
        wget --user="$ZarafaZPushUser" --password="$ZarafaZPushPass" -O - -o /dev/null "$ZarafaZPushURL" | grep '<title>Z-Push ActiveSync</title>' > /dev/null 2>&1
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
      echo -e "Commands:  start     stop     status     restart"
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
    "start" )               start ;;
    "stop" )                stop ;;
    "status" )              status $@ ;;
    "restart"|"reload")     $0 restart ;;
    "setup" )               setup ;;                            
    * )                     usage 1 ;;
esac
exit $?
