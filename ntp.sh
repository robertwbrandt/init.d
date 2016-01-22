#!/bin/bash
#
#     Wrapper startup script for NTP
#     Bob Brandt <projects@brandt.ie>
#          
#
### BEGIN INIT INFO
# Provides:       brandt-ntp
# Required-Start: network $remote_fs $syslog $named
# Required-Stop:  $remote_fs $syslog
# Default-Start:  2 3 5
# Default-Stop:   0 1 6
# Short-Description: NTP Client
# Description:       Wrapper for Standard NTP Client
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
_this_conf=/etc/brandt/ntp.conf
_this_script=/opt/brandt/init.d/ntp.sh
_this_rc=/usr/local/bin/rcbrandt-ntp
_this_initd=/etc/init.d/brandt-ntp
_initd_ntp=/etc/init.d/ntp
_this_cron=/etc/cron.hourly/ntprestart

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
if [ ! -r "$_this_conf" ]; then
    ( echo -e "#     Configuration file for NTP wrapper startup script"
      echo -e "#     Bob Brandt <projects@brandt.ie>\n#"
      echo -e "      _bin_ntp=/usr/sbin/ntpd"
      echo -e "     _conf_ntp=/etc/ntp.conf"
      echo -e "    _initd_ntp=/etc/init.d/ntp\n"
      echo -e " _ntp_stratum1=external.ntp,stratum1.ntp"
      echo -e "  _ntp_servers=stratum1.ntp,nds"
      echo -e "_ntp_sysconfig=/etc/sysconfig/ntp" ) > "$_this_conf"
    echo "Unable to find required file: $_this_conf" 1>&2
fi

. "$_brandt_utils"
. "$_this_conf"

function installed() {
    brandt_deamon_wrapper "NTP daemon" "$_bin_ntp" installed
    return $?
}

function configured() {
    brandt_deamon_wrapper "NTP daemon" "$_conf_ntp" configured
    return $?
}

function setup_cron_job() {
    echo -n "Create CRON Job to update NTP "
    ( echo -e "#!/bin/bash\n$_this_script restart\nexit $?\n" > "$_this_cron" && chownmod -Rf root:root 544 "$_this_cron" ) > /dev/null 2>&1
    brandt_status setup
    return $?
}

function setup_chroot() {
    echo -n "Modifying $_ntp_sysconfig to chroot NTP "
    sed -i 's|^NTPD_RUN_CHROOTED=".*|NTPD_RUN_CHROOTED="yes"|g' "$_ntp_sysconfig"
    brandt_status setup
    return $?
}

function setup_servers() {
    local _status=0 
    echo -n "Modifying $_conf_ntp to remove all NTP servers "
    sed -i 's|^server [a-z,A-Z].*||g' "$_conf_ntp"
    brandt_status setup
    _status=$(( $_status | $? ))

    IFS_OLD="$IFS"
    IFS=","
    declare -i count=0
    for server in $_ntp_servers; do
        count=count+1
        server="$server."`dnsdomainname`

        if [ $count -eq 1 ]; then
            echo -n "Modifying $_ntp_sysconfig initial update "
            sed -i "s|^NTPD_INITIAL_NTPDATE=\".*|NTPD_INITIAL_NTPDATE=\"$server\"|" "$_ntp_sysconfig"
            brandt_status setup
            _status=$(( $_status | $? ))
        fi

        echo -n "Modifying $_conf_ntp to add NTP Server ($server) "
        echo "server $server" >> "$_conf_ntp" 
        brandt_status setup
        _status=$(( $_status | $? ))
    done
    IFS="$IFS_OLD"
    return $_status
}

function setup() {
    local _status=0     
    ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
    _status=$?
    ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
    _status=$(( $_status | $? ))
    chownmod root:root 644 "$_this_conf" > /dev/null 2>&1
    _status=$(( $_status | $? ))
    chkconfig ntpd on && chkconfig ntpd 35
    _status=$(( $_status | $? ))
    setup_cron_job
    _status=$(( $_status | $? ))

    [ ! -r "$_ntp_sysconfig" ] && echo "Unable to find required file: $_ntp_sysconfig" 1>&2 && exit 6
    . "$_ntp_sysconfig"

    setup_chroot
    _status=$(( $_status | $? ))
    setup_servers "$_ntp_servers"
    return $(( $_status | $? ))
}

function usage() {
    local _exitcode=${1-0}
    local _output=2
    [ "$_exitcode" == "0" ] && _output=1
    [ "$2" == "" ] || echo -e "$2"
    ( echo -e "Usage: $0 [options] command"
      echo -e "Commands:  start         stop     status"
      echo -e "           try-restart   restart  try-restart-iburst"
      echo -e "           force-reload  reload   probe"
      echo -e "           ntptimeset    setup"
      echo -e "Options:"
      echo -e " -s, --servers  comma seperated list of ntp servers"
      echo -e " -q, --quiet    be quiet"
      echo -e " -h, --help     display this help and exit"
      echo -e " -v, --version  output version information and exit" ) >&$_output
    exit $_exitcode
}

# Execute getopt
if ! _args=$( getopt -o sqvh -l "servers:quiet,help,version" -n "$0" -- "$@" 2>/dev/null ); then
    _err=$( getopt -o sqvh -l "servers:quiet,help,version" -n "$0" -- "$@" 2>&1 >/dev/null )
    usage 1 "${BOLD_RED}$_err${NORMAL}"
fi

#Bad arguments
#[ $? -ne 0 ] && usage 1 "$0: No arguments supplied!\n"

eval set -- "$_args";
_quiet=1
while /bin/true ; do
    case "$1" in
        -s | --servers )   _ntp_servers="$2" ; shift ;;     
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
    "start" | "stop" | "try-restart" | "restart" | "try-restart-iburst" | "force-reload" | "reload" | "probe" | "ntptimeset" )
                brandt_deamon_wrapper "NTP daemon" "$_initd_ntp"  $_command $@ ;;
    "status" )  brandt_deamon_wrapper "NTP daemon ($( date ))" "$_initd_ntp" status $@ ;;
    "setup" )   setup ;;                
    * )         usage 1 ;;
esac
exit $?
