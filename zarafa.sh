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
_brandt_utils=/opt/brandt/common/brandt.sh
_this_conf=/etc/brandt/zarafa.conf
_this_script=/opt/brandt/init.d/zarafa.sh
_this_initd=/etc/init.d/zarafa
_this_rc=/usr/local/bin/rcbrandt-zarafa

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
if [ ! -r "$_this_conf" ]; then
    ( echo -e "#     Configuration file for Zarafa script"
      echo -e "#     Bob Brandt <projects@brandt.ie>\n#"
      echo -e "  ZarafaServer=/etc/init.d/zarafa-server"
      echo -e "  ZarafaDAgent=/etc/init.d/zarafa-dagent"
      echo -e "ZarafaLicensed=/etc/init.d/zarafa-licensed"
      echo -e " ZarafaMonitor=/etc/init.d/zarafa-monitor"
      echo -e "  ZarafaSearch=/etc/init.d/zarafa-search"
      echo -e " ZarafaSpooler=/etc/init.d/zarafa-spooler"
      echo -e "ZarafaPresence=/etc/init.d/zarafa-presence"
      echo -e "    ZarafaICal=/etc/init.d/zarafa-ical"
      echo -e " ZarafaGateway=/etc/init.d/zarafa-gateway"
      echo -e "       Postfix=/etc/init.d/postfix"
      echo -e "         MySQL=/etc/init.d/postfix"
      echo -e "        Apache=/etc/init.d/apache2"
      echo -e "ZarafaTestUser='castrof'"
      echo -e "ZarafaTestPass='cubacuba'" ) > "$_this_conf"
    echo "Unable to find required file: $_this_conf" 1>&2
fi
. "$_brandt_utils"
. "$_this_conf"


function setup() {
    local _status=0
    ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
    _status=$?

    ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
    _status=$(( $_status | $? ))

    chownmod root:root 644 "$_this_conf" > /dev/null 2>&1
    _status=$(( $_status | $? ))
    return $(( $_status | $? ))
}

function start() {
    local _status=0    
    echo "Starting up Zarafa Deamons"
    if [ -z "$ZarafaServer" ]; then
        echo -n "Starting Zarafa Server Deamon "
        $ZarafaServer start > /dev/null 2>&1
        brandt_status start
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaDAgent" ]; then
        echo -n "Starting Zarafa DAgent Deamon "
        $ZarafaDAgent start > /dev/null 2>&1
        brandt_status start
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaLicensed" ]; then
        echo -n "Starting Zarafa License Deamon "
        $ZarafaLicensed start > /dev/null 2>&1
        brandt_status start
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaMonitor" ]; then
        echo -n "Starting Zarafa Monitor Deamon "
        $ZarafaMonitor start > /dev/null 2>&1
        brandt_status start
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaSearch" ]; then
        echo -n "Starting Zarafa Search Deamon "
        $ZarafaSearch start > /dev/null 2>&1
        brandt_status start
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaSpooler" ]; then
        echo -n "Starting Zarafa Spooler Deamon "
        $ZarafaSpooler start > /dev/null 2>&1
        brandt_status start
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaPresence" ]; then
        echo -n "Starting Zarafa Presence Deamon "
        $ZarafaPresence start > /dev/null 2>&1
        brandt_status start
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaICal" ]; then
        echo -n "Starting Zarafa iCal Deamon "
        $ZarafaICal start > /dev/null 2>&1
        brandt_status start
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaGateway" ]; then
        echo -n "Starting Zarafa Gateway (IMAP/POP) Deamon "
        $ZarafaGateway start > /dev/null 2>&1
        brandt_status start
        _status=$(( $_status | $? ))
    fi

    return $_status
}

function stop() {
    local _status=0    
    echo "Shutting down Zarafa Deamons"
    if [ -z "$ZarafaICal" ]; then
        echo -n "Stopping Zarafa iCal Deamon "
        $ZarafaICal stop > /dev/null 2>&1
        brandt_status stop
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaGateway" ]; then
        echo -n "Stopping Zarafa Gateway (IMAP/POP) Deamon "
        $ZarafaGateway stop > /dev/null 2>&1
        brandt_status stop
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaDAgent" ]; then
        echo -n "Stopping Zarafa DAgent Deamon "
        $ZarafaDAgent stop > /dev/null 2>&1
        brandt_status stop
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaMonitor" ]; then
        echo -n "Stopping Zarafa Monitor Deamon "
        $ZarafaMonitor stop > /dev/null 2>&1
        brandt_status stop
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaSearch" ]; then
        echo -n "Stopping Zarafa Search Deamon "
        $ZarafaSearch stop > /dev/null 2>&1
        brandt_status stop
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaSpooler" ]; then
        echo -n "Stopping Zarafa Spooler Deamon "
        $ZarafaSpooler stop > /dev/null 2>&1
        brandt_status stop
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaPresence" ]; then
        echo -n "Stopping Zarafa Presence Deamon "
        $ZarafaPresence stop > /dev/null 2>&1
        brandt_status stop
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaServer" ]; then
        echo -n "Stopping Zarafa Server Deamon "
        $ZarafaServer stop > /dev/null 2>&1
        brandt_status stop
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaLicensed" ]; then
        echo -n "Stopping Zarafa License Deamon "
        $ZarafaLicensed stop > /dev/null 2>&1
        brandt_status stop
        _status=$(( $_status | $? ))
    fi

    return $_status
}

function checkSMTPServer() {
    IP=${1:-'127.0.0.1'}
    echo -n "Verifying SMTP Service on $IP is responding"
    tmp=$( ( sleep 1 ; echo "helo client.test.com"; sleep 1; echo "noop" ; sleep 1 ; echo "quit" ) | telnet "$IP" 25 2> /dev/null )
    echo "$tmp" | grep -i "250.*OK" > /dev/null 2>&1
    brandt_status status
    return $?
}

function checkZarafaWebApp() {
    IP=${1:-'127.0.0.1'}
    echo -n "Verifying HTTP WebApp Service on $IP is responding"
    wget --no-check-certificate -O - -o /dev/null "https://$IP/webapp" | grep '<title>Zarafa WebApp</title>' > /dev/null 2>&1
    brandt_status status
    return $?
}

function checkIMAPServer() {
    IP=${1:-'127.0.0.1'}
    echo -n "Verifying IMAP Service on $IP is responding"
    tmp=$( ( sleep 1 ; echo -e "a1 login \"$ZarafaTestUser\" \"$ZarafaTestPass\""; sleep 1; echo 'a2 list "" "*"' ; sleep 1 ; echo 'a3 logout' ) | openssl s_client -connect $IP:993 -quiet 2> /dev/null )
    ( echo "$tmp" | grep -i "a1.*OK.*LOGIN.*completed" && echo "$tmp" | grep -i "a2.*OK.*LIST.*completed" ) > /dev/null 2>&1
    brandt_status status
    return $?
}

function checkZPushActiveSync() {
    IP=${1:-'127.0.0.1'}
    echo -n "Verifying ActiveSync Service on $IP is responding"
    wget --user="$ZarafaZPushUser" --password="$ZarafaZPushPass" -O - -o /dev/null "https://$IP/Microsoft-Server-ActiveSync" | grep '<title>Z-Push ActiveSync</title>' > /dev/null 2>&1
    brandt_status status
    return $?
}

function status() {
    local _status=0    
    if [ -z "$Postfix" ]; then
        echo -n "Checking Postfix Deamon "
        $Postfix status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))

        checkSMTPServer '127.0.0.1'
        _status=$(( $_status | $? ))        
    fi

    if [ -z "$MySQL" ]; then
        echo -n "Checking MySQL Database Deamon "
        $MySQL status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi    

    echo "Checking Zarafa Deamons"

    if [ -z "$ZarafaServer" ]; then
        echo -n "Checking Zarafa Server Deamon "
        $ZarafaServer status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaDAgent" ]; then
        echo -n "Checking Zarafa DAgent Deamon "
        $ZarafaDAgent status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaLicensed" ]; then
        echo -n "Checking Zarafa License Deamon "
        $ZarafaLicensed status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaMonitor" ]; then
        echo -n "Checking Zarafa Monitor Deamon "
        $ZarafaMonitor status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaSearch" ]; then
        echo -n "Checking Zarafa Search Deamon "
        $ZarafaSearch status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaSpooler" ]; then
        echo -n "Checking Zarafa Spooler Deamon "
        $ZarafaSpooler status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaPresence" ]; then
        echo -n "Checking Zarafa Presence Deamon "
        $ZarafaPresence status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaICal" ]; then
        echo -n "Checking Zarafa iCal Deamon "
        $ZarafaICal status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))
    fi

    if [ -z "$ZarafaGateway" ]; then
        echo -n "Checking Zarafa Gateway (IMAP/POP) Deamon "
        $ZarafaGateway status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))

        checkIMAPServer '127.0.0.1'
        _status=$(( $_status | $? ))        
    fi

    if [ -z "$Apache" ]; then
        echo -n "Checking Apache Webserver Deamon "
        $Apache status > /dev/null 2>&1
        brandt_status status
        _status=$(( $_status | $? ))

        tmp=$( find -L /etc/apache2/sites-enabled/ -type f -exec grep "Alias /webapp " "{}" \; )
        if [ -z "$tmp" ]; then
            checkZarafaWebApp '127.0.0.1'
            _status=$(( $_status | $? ))
        fi

        tmp=$( find -L /etc/apache2/sites-enabled/ -type f -exec grep "/Microsoft-Server-ActiveSync" "{}" \; )
        if [ -z "$tmp" ]; then
            checkZPushActiveSync '127.0.0.1'
            _status=$(( $_status | $? ))
        fi
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

# Check to see if user is root, if not re-run script as root.
brandt_amiroot || { echo "${BOLD_RED}This program must be run as root!${NORMAL}" >&2 ; sudo "$0" $@ ; exit $?; }

case "$_command" in
    "start" )               start ;;
    "stop" )                stop ;;
    "status" )              status $@ ;;
    "restart"|"reload")     stop ; start ;;
    "setup" )               setup ;; 
    * )                     usage 1 ;;
esac
exit $?
