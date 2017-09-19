#!/bin/bash
#
#     Wrapper startup script for syslog-ng
#     Bob Brandt <projects@brandt.ie>
#          
### BEGIN INIT INFO
# Provides:       brandt-syslog
# Required-Start: network 
# Should-Start:   earlysyslog
# Required-Stop:  network
# Default-Start:  2 3 5
# Default-Stop:
# Description:    Start the system logging daemons
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
_this_script=/opt/brandt/init.d/oes/syslog.sh
_this_rc=/usr/local/bin/rcbrandt-syslog
_this_initd=/etc/init.d/brandt-syslog
_this_cron=/etc/cron.weekly/syslog-cleanup

_bin_syslog=/sbin/syslog-ng
_conf_syslog=/etc/syslog-ng/syslog-ng.conf
_initd_syslog=/etc/init.d/syslog
_initd_apache=/etc/init.d/apache2
_initd_smb=/etc/init.d/smb

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
. "$_brandt_utils"

function installed() {
    brandt_deamon_wrapper "Syslog daemon" "$_bin_syslog" installed
    return $?
}

function configured() {
    brandt_deamon_wrapper "Syslog daemon" "$_conf_syslog" configured
    return $?
}

function cleanup() {
    declare -i logspace=

    if [[ $( df /var/log | sed -n "s|.* [0-9]\+%|&|p" | sed -e "s|%.*||" -e "s|.* ||" ) -gt 80 ]]; then
        logger -st $( basename $_this_script ) "running out of log space, cleaning up old logs."
        rm /var/log/messages /var/log/localmessages /var/log/apache2/rewrite_log /var/log/samba/audit /var/log/warn /var/log/wtmp
        find /var/log -iname "*.bz2" -delete
        find /var/log -iname "*.old" -delete
        $_initd_apache reload
        $_initd_smb reload;
        $_initd_syslog reload

    fi
}

function showfiles() {
    num=${1:-20}
    find -P /var/log -type f -exec ls -s {} \; | sort -nr | head -n $num
}

function syslog_service() {
    if ! grep "syslog.opw.ie" "$_conf_syslog" | grep "port(514)" > /dev/null
    then
        echo -n "Setting up System Log (syslog-ng) service "
        ( echo -e "# send everything to syslog host (Bob Brandt)"
          echo -e "destination loghost {"
          echo -e " udp(\"syslog.i.opw.ie\" port(514));"
          echo -e "# tcp(\"syslog.i.opw.ie\" port(514));"
          echo -e "};\nlog {\n source(src);"
          echo -e " destination(loghost);\n};" ) >> "$_conf_syslog"
        brandt_status setup
    fi
}

function setup_cron_job() {
    echo -en "Setup Syslog reload cron job "
    ( echo -e "#!/bin/bash\n$_this_script cleanup\nexit $?\n" > "$_this_cron" && chownmod -Rf root:root 544 "$_this_cron" ) > /dev/null 2>&1
    brandt_status setup
    return $?
}

function setup() {
    local _status=0     
    ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
    _status=$?
    ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
    _status=$(( $_status | $? ))
    syslog_service
    _status=$(( $_status | $? ))
    setup_cron_job
    return $(( $_status | $? ))
}

function usage() {
    local _exitcode=${1-0}
    local _output=2
    [ "$_exitcode" == "0" ] && _output=1
    [ "$2" == "" ] || echo -e "$2"
    ( echo -e "Usage: $0 [options] command"
      echo -e "Commands:  start    stop      status"
      echo -e "           restart  reload    probe"
      echo -e "           setup    cleanup   showfiles"
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
    "start" | "stop" | "status" | "restart" | "try-restart" | "force-reload" | "reload" | "probe" )
                    brandt_deamon_wrapper "Syslog daemon" "$_initd_syslog" "$_command" $@ ;;
    "setup" )       setup ;;
    "cleanup" )     cleanup ;;
    "showfiles" )   showfiles ;;
    * )             usage 1 ;;
esac
exit $?
