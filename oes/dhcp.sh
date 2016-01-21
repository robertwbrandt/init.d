#!/bin/bash
#
#     Wrapper startup script for dhcpd
#     Bob Brandt <projects@brandt.ie>
#          
### BEGIN INIT INFO
# Provides:	            brandt-dhcp
# Required-Start:		$ALL
# Should-Start:
# Default-Start:		3 5
# Default-Stop:			0 1 2 6
# Short-Description:    Novell DHCP Server
# Description:	        Wrapper for Standard Novell DHCP (Dynamic Host Configuration Protocol) Server
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
_this_conf=/etc/brandt/dhcp.conf
_this_script=/opt/brandt/init.d/oes/dhcp.sh
_this_rc=/usr/local/bin/rcbrandt-dhcp
_this_cron=/etc/cron.hourly/dhcp-reload
_bin_dhcpd=/usr/sbin/dhcpd
_conf_dhcpd=/etc/dhcpd.conf
_conf_dhcpd_ldap=/etc/openldap/ldap.conf
_initd_dhcpd=/etc/init.d/dhcpd

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
if [ ! -r "$_this_conf" ]; then
	( echo -e "#     Configuration file for DHCP wrapper startup script"
	  echo -e "#     Bob Brandt <projects@brandt.ie>\n#"
   	  echo -e "_dhcpd_sysconfig=/etc/sysconfig/dhcpd" ) > "$_this_conf"
	echo "Unable to find required file: $_this_conf" 1>&2
fi

. "$_brandt_utils"
. "$_this_conf"
[ ! -r "$_dhcpd_sysconfig" ] && echo "Unable to find required file: $_dhcpd_sysconfig" 1>&2 && exit 6
. "$_dhcpd_sysconfig"


function installed() {
	brandt_deamon_wrapper "Novell DHCP daemon" "$_bin_dhcpd" installed
	return $?
}

function configured() {
	local _status=0
	brandt_deamon_wrapper "Novell DHCP daemon" "$_conf_dhcpd" configured
	_status=$(( $_status | $? ))

	brandt_deamon_wrapper "Novell DHCP LDAP" "$_conf_dhcpd_ldap" configured
	_status=$(( $_status | $? ))

	brandt_deamon_wrapper "Novell DHCP" "$_dhcpd_sysconfig" configured
	return $(( $_status | $? ))	
}

function test_deamon() {
	if ! $0 status
	then
		echo -e ""
		logger -st "$( basename $0 )" "${BOLD_RED}The Novell DHCP System is malfunctioning. Restarting system.${NORMAL}"
		$0 kill
		sleep 5s
		$0 start			
	fi
	return $?
}

function setup_cron_job() {
	echo -en "Setup DHCP Test cron job "
	( echo -e "#!/bin/bash\n$_this_script test\nexit $?\n" > "$_this_cron" && chownmod -Rf root:root 544 "$_this_cron" ) > /dev/null 2>&1
	brandt_status setup
	return $?
}

function setup() {
	local _status=0	
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
	_status=$?	
	chownmod root:root 644 "$_this_conf" > /dev/null 2>&1
	_status=$(( $_status | $? ))

	setup_cron_job
	_status=$(( $_status | $? ))
	test_deamon
	return $(( $_status | $? ))
}

function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( echo -e "Usage: $0 [options] command"
	  echo -e "Commands:  start     stop            status"
	  echo -e "           restart   try-restart     probe"
	  echo -e "           reload    force-reload    check-syntax"
	  echo -e "           setup     test            kill"
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
	"start" | "stop" | "status" | "kill" | "try-restart" | "restart" | "reload" | "force-reload" )
								brandt_deamon_wrapper "Novell DHCP" "$_initd_dhcpd" "$_command" "$_bin_dhcpd" ;;
    "probe" | "check-syntax" )	$_initd_dhcpd "$_command" ;;
	"test" )					test_deamon ;;
    "setup" )					setup ;;
    * )        				    usage 1 ;;
esac
exit $?
