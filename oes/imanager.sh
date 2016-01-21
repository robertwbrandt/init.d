#!/bin/bash
#
#     Wrapper startup script for Novell iManager
#     Bob Brandt <projects@brandt.ie>
#          
### BEGIN INIT INFO
# Provides:	            brandt-imanager
# Required-Start:		$ALL
# Should-Start:
# Default-Start:		3 5
# Default-Stop:			0 1 2 6
# Short-Description:    Novell iManager
# Description:	        Wrapper for Standard Novell iManager
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
_brandt_utils=/opt/brandt/brandt-utils.sh
_this_script=/opt/brandt/init.d/oes/imanager.sh
_this_initd=/etc/init.d/brandt-imanager
_this_rc=/usr/local/bin/rcbrandt-imanager
_this_conf=/etc/brandt/imanager.conf

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
if [ ! -r "$_this_conf" ]; then
	( echo -e "#     Configuration file for iManager wrapper startup script"
	  echo -e "#     Bob Brandt <projects@brandt.ie>\n#"
	  echo -e "_bin_apache=/usr/sbin/httpd2-worker"
	  echo -e "_bin_tomcat=/usr/lib/jvm/java/bin/java"
	  echo -e "_config_apache=/etc/apache2/httpd.conf"
	  echo -e "_config_tomcat=/etc/sysconfig/j2ee\n"
	  echo -e "_initd_apache=/etc/init.d/apache2"
	  echo -e "_initd_tomcat=/etc/init.d/novell-tomcat5\n"
	  echo -e "_this_cron=/etc/cron.hourly/imanager-reload\n"
	  echo -e "_imanager_sysconfig=/etc/sysconfig/novell/iman2_sp2"
	  echo -e "[ -f \"\$_imanager_sysconfig\" ] || _imanager_sysconfig=/etc/sysconfig/novell/iman2_sp3" ) > "$_this_conf"
	echo "Unable to find required file: $_this_conf" 1>&2
fi

. "$_brandt_utils"
. "$_this_conf"
[ ! -r "$_imanager_sysconfig" ] && echo "Unable to find required file: $_imanager_sysconfig" 1>&2 && exit 6
. "$_imanager_sysconfig"


function installed() {
	local _status=0
	brandt_deamon_wrapper "Apache daemon" "$_bin_apache" installed
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell Tomcat daemon" "$_bin_tomcat" installed
	return $(( $_status | $? ))
}

function configured() {
	local _status=0
	brandt_deamon_wrapper "Apache daemon" "$_config_apache" configured
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell Tomcat daemon" "$_config_tomcat" configured
	return $(( $_status | $? ))
}

function start() {
	local _command=${1:-start}
	local _status=0
	brandt_deamon_wrapper "Apache daemon" "$_initd_apache" "$_command"	
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell Tomcat daemon" "$_initd_tomcat" "$_command"
	return $(( $_status | $? ))
}

function stop() {
	local _command=${1:-stop}
	local _status=0
	brandt_deamon_wrapper "Novell Tomcat daemon" "$_initd_tomcat" "$_command" "java.*-Djava.util.logging.config.file=/var/opt/novell/tomcat.*-Dcatalina.base=/var/opt/novell/tomcat.*-Dcatalina.home=/usr/share/tomcat.*org.apache.catalina.startup.Bootstrap"
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Apache daemon" "$_initd_apache" "$_command" "$( basename $_bin_apache )"
	return $(( $_status | $? ))
}

function status() {
	local _status=0
	brandt_deamon_wrapper "Apache daemon" "$_initd_apache" status
	_status=$(( $_status | $? ))
	#brandt_deamon_wrapper "Novell Tomcat daemon" "java.*-Djava.util.logging.config.file=/var/opt/novell/tomcat.*-Dcatalina.base=/var/opt/novell/tomcat.*-Dcatalina.home=/usr/share/tomcat.*org.apache.catalina.startup.Bootstrap" status-process
	brandt_deamon_wrapper "Novell Tomcat daemon" "$_initd_tomcat" status
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell iManager" "https://127.0.0.1/nps/portal/modules/fw/images/nlogo_100.gif" status-web	
	return $(( $_status | $? ))
}

function test_deamon() {
	if ! status
	then
		logger -st "$( basename $_this_initd )" "${BOLD_RED}The Novell iManager System is malfunctioning. Restarting system.${NORMAL}"
		kill_deamon
		sleep 5s
		$0 start
	fi
	return $?
}

function setup_initd() {
	local _status=0
	echo -n "Modifying system services (init.d scripts) "
	chkconfig $( basename "$_initd_apache" ) off > /dev/null 2>&1
	_status=$(( $_status | $? )) 
	chkconfig $( basename "$_initd_tomcat" ) off > /dev/null 2>&1
	_status=$(( $_status | $? ))
	chkconfig $( basename "$_this_initd" ) on > /dev/null 2>&1 && chkconfig $( basename "$_this_initd" ) 35 > /dev/null 2>&1
	returnvalue $(( $_status | $? ))
	brandt_status setup
	return $?
}

function setup_cron_job() {
	echo -en "Setup iManager Test cron job "
	( echo -e "#!/bin/bash\n$_this_script test\nexit $?\n" > "$_this_cron" && chownmod -Rf root:root 544 "$_this_cron" ) > /dev/null 2>&1
	brandt_status setup
	return $?
}

function setup() {
	local _status=0	
	ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1

	setup_initd
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
	  echo -e "Commands:  start    stop          status"
	  echo -e "           restart  try-restart   kill"
	  echo -e "           reload   force-reload"	
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
	"start" | "try-restart" | "restart" | "reload" | "force-reload" )
						start "$_command" ;;
    "stop" | "kill" )	stop  "$_command" ;;
    "status" )			status ;;
	"test" )			test_deamon ;;
    "setup" )			setup ;;
    * )        			usage 1 ;;
esac
exit $?
