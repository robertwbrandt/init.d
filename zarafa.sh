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
      echo -e "        Apache=/etc/init.d/apache2"
      echo -e "         MySQL=/etc/init.d/mysql"
      echo -e " MySQLCredFile=/etc/mysql/debian.cnf"
      echo -e "ZarafaTestUser='castrof'"
      echo -e "ZarafaTestPass='cubacuba'" ) > "$_this_conf"
    echo "Unable to find required file: $_this_conf" 1>&2
fi
. "$_brandt_utils"
. "$_this_conf"

function setup() {
    local _status=0
    echo -n "Create Symbolic Links "
    ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
    _status=$?
    ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
    _status=$(( $_status | $? ))
    chownmod root:root 644 "$_this_conf" > /dev/null 2>&1
    _status=$(( $_status | $? ))
    brandt_status status

    echo -n "Modify Zarafa init.d Scripts "
    for file in $( find /etc/init.d/ -type f -iname "zarafa-*" )
    do
        sysv-rc-conf $( basename $file ) off
        _status=$(( $_status | $? ))
    done

    sysv-rc-conf zarafa on
    _status=$(( $_status | $? ))
    brandt_status status

    return $(( $_status | $? ))
}

runCommand() {
    local _initd="$1"
    local _cmd="$2"
    local _string="$3"
    if [ -n "$_initd" ]; then
        brandt_deamon_wrapper "$_string" "$_initd" "$_cmd"
        return $?
    fi
    return 0    
}

function checkSMTPServer() {
    IP=${1:-'127.0.0.1'}
    if [ -n "$IP" ] && [ -n "$Postfix" ]; then    
        echo -n "Verifying SMTP Service on $IP is responding"
        tmp=$( ( sleep 1 ; echo "helo client.test.com"; sleep 1; echo "noop" ; sleep 1 ; echo "quit" ) | telnet "$IP" 25 2> /dev/null )
        echo "$tmp" | grep -i "250.*OK" > /dev/null 2>&1
        brandt_status status
        return $?
    fi
    return 0
}

function checkIMAPServer() {
    IP=${1:-'127.0.0.1'}
    if [ -n "$IP" ] && [ -n "$ZarafaGateway" ] && [ -n "$ZarafaTestUser" ] && [ -n "$ZarafaTestPass" ]; then    
        echo -n "Verifying IMAP Service on $IP is responding"
        tmp=$( ( sleep 1 ; echo -e "a1 login \"$ZarafaTestUser\" \"$ZarafaTestPass\""; sleep 1; echo 'a2 list "" "*"' ; sleep 1 ; echo 'a3 logout' ) | openssl s_client -connect $IP:993 -quiet 2> /dev/null )
        ( echo "$tmp" | grep -i "a1.*OK.*LOGIN.*completed" && echo "$tmp" | grep -i "a2.*OK.*LIST.*completed" ) > /dev/null 2>&1
        brandt_status status
        return $?
    fi
    return 0
}

function checkCalDavServer() {
    IP=${1:-'127.0.0.1'}
    if [ -n "$IP" ] && [ -n "$ZarafaICal" ] && [ -n "$ZarafaTestUser" ] && [ -n "$ZarafaTestPass" ]; then   
        echo -n "Verifying CalDav Service on $IP:8443 is responding"
        wget --no-check-certificate --proxy=off --user="$ZarafaTestUser" --password="$ZarafaTestPass" -O - -o /dev/null "https://$IP:8443/caldav/$ZarafaTestUser/calendar" > /dev/null 2>&1
        brandt_status status
        return $?
    fi
    return 0
}

function checkZarafaWebApp() {
    IP=${1:-'127.0.0.1'}
    if [ -n "$IP" ] && [ -n "$Apache" ]; then
        echo -n "Verifying HTTP WebApp Service on $IP is responding"
        wget --no-check-certificate --proxy=off -O - -o /dev/null "https://$IP/webapp" | grep '<title>Zarafa WebApp</title>' > /dev/null 2>&1
        brandt_status status
        return $?
    fi
    return 0
}

function checkZPushActiveSync() {
    IP=${1:-'127.0.0.1'}
    if [ -n "$IP" ] && [ -n "$Apache" ] && [ -n "$ZarafaTestUser" ] && [ -n "$ZarafaTestPass" ]; then    
        echo -n "Verifying ActiveSync Service on $IP is responding"
        wget --no-check-certificate --proxy=off --user="$ZarafaTestUser" --password="$ZarafaTestPass" -O - -o /dev/null "https://$IP/Microsoft-Server-ActiveSync" | grep '<title>Z-Push ActiveSync</title>' > /dev/null 2>&1
        brandt_status status
        return $?
    fi
    return 0
}

function checkMySQL() {
    if [ -n "$MySQL" ] && [ -n "$MySQLCredFile" ]; then
        echo -n "Verifying MySQL Service is responding"
        mysql --defaults-extra-file=$MySQLCredFile -e "SHOW DATABASES;" > /dev/null 2>&1
        brandt_status status
        return $?
    fi
    return 0
}

function runCommands() {
    local _status=0
    local _delay=15
    local _cmd="$1"

    runCommand "$ZarafaDAgent" "$_cmd" "Zarafa DAgent Deamon"
    _status=$(( $_status | $? ))

    runCommand "$ZarafaLicensed" "$_cmd" "Zarafa License Deamon"
    _status=$(( $_status | $? ))

    runCommand "$ZarafaMonitor" "$_cmd" "Zarafa Monitor Deamon"
    _status=$(( $_status | $? ))

    runCommand "$ZarafaSearch" "$_cmd" "Zarafa Search Deamon"
    _status=$(( $_status | $? ))

    runCommand "$ZarafaSpooler" "$_cmd" "Zarafa Spooler Deamon"
    _status=$(( $_status | $? ))

    runCommand "$ZarafaPresence" "$_cmd" "Zarafa Presence Deamon"
    _status=$(( $_status | $? ))

    if [ "$_cmd" == "start" ]; then
        declare -i _count=3
        while ! runCommand "$MySQL" "status" "MySQL Database Deamon"
        do
            _count=_count-1
            [[ _count == 0 ]] && break
            echo "Waiting for the MySQL Service to start."
            sleep $_delay
        done
        declare -i _count=3
        while ! checkMySQL
        do
            _count=_count-1
            [[ _count == 0 ]] && break
            echo "Waiting for the MySQL Service to become available."
            sleep $_delay
        done
    fi

    runCommand "$ZarafaServer" "$_cmd" "Zarafa Server Deamon"
    _status=$(( $_status | $? ))

    runCommand "$ZarafaICal" "$_cmd" "Zarafa iCal (CalDav) Deamon"
    _status=$(( $_status | $? ))

    runCommand "$ZarafaGateway" "$_cmd" "Zarafa Gateway (IMAP/POP) Deamon"
    _status=$(( $_status | $? ))

    return $_status
}

function status() {
    local _status=0
    subcmd=$( lower ${1:-'all'} )

    if [ "$subcmd" == "mta" ] || [ "$subcmd" == "all" ]; then
        runCommand "$Postfix" status "Postfix (MTA) Deamon"
        _status=$(( $_status | $? ))
        checkSMTPServer '127.0.0.1'
        _status=$(( $_status | $? ))
    fi

    if [ "$subcmd" == "mda" ] || [ "$subcmd" == "all" ]; then
        runCommand "$ZarafaDAgent" status "Zarafa DAgent Deamon"
        _status=$(( $_status | $? ))

        runCommand "$ZarafaLicensed" status "Zarafa License Deamon"
        _status=$(( $_status | $? ))

        runCommand "$ZarafaMonitor" status "Zarafa Monitor Deamon"
        _status=$(( $_status | $? ))

        runCommand "$ZarafaSearch" status "Zarafa Search Deamon"
        _status=$(( $_status | $? ))

        runCommand "$ZarafaSpooler" status "Zarafa Spooler Deamon"
        _status=$(( $_status | $? ))

        runCommand "$ZarafaPresence" status "Zarafa Presence Deamon"
        _status=$(( $_status | $? ))

        runCommand "$MySQL" status "MySQL Database Deamon"
        _status=$(( $_status | $? ))
        checkMySQL
        _status=$(( $_status | $? ))

        runCommand "$ZarafaServer" status "Zarafa Server Deamon"
        _status=$(( $_status | $? ))        
    fi

    if [ "$subcmd" == "web" ] || [ "$subcmd" == "all" ]; then
        runCommand "$Apache" status "Apache Webserver Deamon"
        _status=$(( $_status | $? ))
        checkZarafaWebApp '127.0.0.1'
        _status=$(( $_status | $? ))
    fi

    if [ "$subcmd" == "imap" ] || [ "$subcmd" == "all" ]; then
        runCommand "$ZarafaGateway" status "Zarafa Gateway (IMAP/POP) Deamon"
        _status=$(( $_status | $? ))
        checkIMAPServer '127.0.0.1'
        _status=$(( $_status | $? ))
    fi

    if [ "$subcmd" == "caldav" ] || [ "$subcmd" == "all" ]; then
        runCommand "$ZarafaICal" status "Zarafa iCal (CalDav) Deamon"
        _status=$(( $_status | $? ))
        checkCalDavServer '127.0.0.1'     
        _status=$(( $_status | $? ))
    fi

    if [ "$subcmd" == "mobile" ] || [ "$subcmd" == "all" ]; then
        runCommand "$Apache" status "Apache Webserver Deamon"
        _status=$(( $_status | $? ))
        checkZPushActiveSync '127.0.0.1'
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
      echo -e "Commands:  start     stop     restart"
      echo -e "           reload    force-reload"
      echo -e "           status [all|mda|mta|web|imap|caldav|mobile]"
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
brandt_amiroot || { echo "${BOLD_RED}This program must be run as root!${NORMAL}" >&2 ; sudo "$0" "$_command" $@ ; exit $?; }

case "$_command" in
    "status" )  status $@ ;;
    "start"|"stop"|"restart"|"reload"|"force-reload")
                runCommands "$_command" $@ ;;
    "setup" )   setup ;; 
    * )         usage 1 ;;
esac
exit $?
