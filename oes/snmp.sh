#!/bin/bash
#
#     Wrapper startup script for SNMP
#     Bob Brandt <projects@brandt.ie>
#          
#
### BEGIN INIT INFO
# Provides:          brandt-snmp
# Required-Start:    $ALL
# Required-Stop:
# Default-Start:     3 5
# Default-Stop:      0 1 2 6
# Short-Description: SNMP-Server
# Description:       Wrapper for Standard Novell SNMP
### END INIT INFO
#
# http://www.novell.com/coolsolutions/tip/5932.html
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
_this_script=/opt/brandt/init.d/snmp
_this_initd=/etc/init.d/brandt-snmp
_this_rc=/usr/local/bin/rcbrandt-snmp

_bin_snmp=/usr/sbin/snmpd
_bin_snmpsa=/opt/novell/eDirectory/bin/ndssnmpsa
_conf_snmp=/etc/snmp/snmpd.conf
_conf_snmpsa=/etc/opt/novell/eDirectory/conf/ndssnmp/ndssnmp.cfg
_initd_snmp=/etc/init.d/snmpd
_initd_snmpsa=/etc/init.d/ndssnmpsa
_snmp_sysconfig=/etc/sysconfig/net-snmp

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
. "$_brandt_utils"

[ ! -r "$_snmp_sysconfig" ] && echo "Unable to find required file: $_snmp_sysconfig" 1>&2 && exit 6
. "$_snmp_sysconfig"
SNMPD_LOGLEVEL=${SNMPD_LOGLEVEL:-"d"}
SNMPD_USE_SMUX=${SNMPD_USE_SMUX:-"yes"}
SNMPD_LOG_SUCCESSFUL_CONNECTIONS=${SNMPD_LOG_SUCCESSFUL_CONNECTIONS:-"yes"}
SNMPD_SYSNAME=${SNMPD_SYSNAME:-"$( hostname ) Novell Server"}
SNMPD_SYSLOCATION=${SNMPD_SYSLOCATION:-"Virtual Machine"}
SNMPD_SYSCONTACT=${SNMPD_SYSCONTACT:-"Sysadmin (root@localhost)"}
SNMPD_ROCOMMUNITY=${SNMPD_ROCOMMUNITY:-"opw_public,public"}
SNMPD_RWCOMMUNITY=${SNMPD_RWCOMMUNITY:-"opw_private"}
SNMPD_TRAPCOMMUNITY=${SNMPD_TRAPCOMMUNITY:-"opw_private"}
SNMPD_TRAPSINK=${SNMPD_TRAPSINK:-"snmptrap.opw.ie"}
SNMPD_TRAP2SINK=${SNMPD_TRAP2SINK:-"snmptrap.opw.ie"}
SNMPD_INFORMSINK=${SNMPD_INFORMSINK:-"snmptrap.opw.ie"}
SNMPD_MASTER_AGENTX=${SNMPD_MASTER_AGENTX:-"yes"}
SNMPSA_INTERACTIVE=${SNMPD_INTERACTIVE:-"no"} #yesno -> onoff
SNMPSA_INTERACTION=${SNMPD_INTERACTION:-"4"}
SNMPSA_MONITOR=${SNMPD_MONITOR:-"yes"} #yesno -> onoff
SNMPSA_SERVER=${SNMPD_SERVER:-"localhost"}

function installed() {
    local _status=0
    brandt_deamon_wrapper "SNMP daemon" "$_bin_snmp" installed
    _status=$(( $_status | $? ))
    brandt_deamon_wrapper "Novell SNMP subagent" "$_bin_snmpsa" installed
    return $(( $_status | $? ))
}

function configured() {
    local _status=0
    brandt_deamon_wrapper "SNMP daemon" "$_conf_snmp" configured
    _status=$(( $_status | $? ))
    brandt_deamon_wrapper "Novell SNMP subagent" "$_conf_snmpsa" configured
    return $(( $_status | $? ))
}

function deamons() {
    local _command=${1:-status}
    shift	
	local _status=0
	brandt_deamon_wrapper "SNMP daemon" "$_initd_snmp" "$_command" $@
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "NDS SNMP subagent" "$_initd_snmpsa" "$_command" $@
	return $(( $_status | $? ))
}

function verify_info() {
	echo -e "\n\nWe are about to use this information for the SNMP Setup."
	echo -e "\tLog level for the snmpd = $SNMPD_LOGLEVEL"
	echo -e "\tSNMP SMUX support = $SNMPD_USE_SMUX"
	echo -e "\tConnecion logging = $SNMPD_LOG_SUCCESSFUL_CONNECTIONS"
	echo -e "\tSNMP System Name = $SNMPD_SYSNAME"
	echo -e "\tSNMP System Location = $SNMPD_SYSLOCATION"
	echo -e "\tSNMP System Contact = $SNMPD_SYSCONTACT"
	echo -e "\tSNMP Read-Only Communities (Comma Separated) = $SNMPD_ROCOMMUNITY"
	echo -e "\tSNMP Read/Write Communities (Comma Separated) = $SNMPD_RWCOMMUNITY"
	echo -e "\tSNMP Trap Community = $SNMPD_TRAPCOMMUNITY"
	echo -e "\tSNMPv1 Trap Host = $SNMPD_TRAPSINK"
	echo -e "\tSNMPv2 Trap Host = $SNMPD_TRAP2SINK"
	echo -e "\tSNMPv2 Trap Inform Host = $SNMPD_INFORMSINK"
	echo -e "\tUse the Master Agentx Switch = $SNMPD_MASTER_AGENTX"
	echo -e "\tAsk for user-name/passwd = $SNMPSA_INTERACTIVE"
	echo -e "\tNumber of interaction table entries = $SNMPSA_INTERACTION"
	echo -e "\tMonitor NDS Statistics = $SNMPSA_MONITOR"
	echo -e "\tLocation of NDS Server = $SNMPSA_SERVER"

	ANSWER=$( brandt_get_input "Is this information correct? (yes/No/Exit)" "n" "lower" )
	ANSWER=${ANSWER:0:1}
}

function get_info() {
	SNMPD_LOGLEVEL=$( brandt_get_input "Log level for the snmpd (!,a,c,e,w,n,i,d,0,1,2,3,4,5,6,7) (Default=$SNMPD_LOGLEVEL)" "$SNMPD_LOGLEVEL" )
	SNMPD_USE_SMUX=$( brandt_get_input "SNMP SMUX support ($SNMPD_USE_SMUX)" "$SNMPD_USE_SMUX" )
	SNMPD_LOG_SUCCESSFUL_CONNECTIONS=$( brandt_get_input "Connecion logging ($SNMPD_LOG_SUCCESSFUL_CONNECTIONS)" "$SNMPD_LOG_SUCCESSFUL_CONNECTIONS" )
	SNMPD_SYSNAME=$( brandt_get_input "SNMP System Name ($SNMPD_SYSNAME)" "$SNMPD_SYSNAME" )
	SNMPD_SYSLOCATION=$( brandt_get_input "SNMP System Location ($SNMPD_SYSLOCATION)" "$SNMPD_SYSLOCATION" )
	SNMPD_SYSCONTACT=$( brandt_get_input "SNMP System Contact ($SNMPD_SYSCONTACT)" "$SNMPD_SYSCONTACT" )
	SNMPD_ROCOMMUNITY=$( brandt_get_input "SNMP Read-Only Communities (Comma Separated) ($SNMPD_ROCOMMUNITY)" "$SNMPD_ROCOMMUNITY" )
	SNMPD_RWCOMMUNITY=$( brandt_get_input "SNMP Read/Write Communities (Comma Separated) ($SNMPD_RWCOMMUNITY)" "$SNMPD_RWCOMMUNITY" )
	SNMPD_TRAPCOMMUNITY=$( brandt_get_input "SNMP Trap Community ($SNMPD_TRAPCOMMUNITY)" "$SNMPD_TRAPCOMMUNITY" )
	SNMPD_TRAPSINK=$( brandt_get_input "SNMPv1 Trap Host ($SNMPD_TRAPSINK)" "$SNMPD_TRAPSINK" )
	SNMPD_TRAP2SINK=$( brandt_get_input "SNMPv2 Trap Host ($SNMPD_TRAP2SINK)" "$SNMPD_TRAP2SINK" )
	SNMPD_INFORMSINK=$( brandt_get_input "SNMPv2 Trap Inform Host ($SNMPD_INFORMSINK)" "$SNMPD_INFORMSINK" )
	SNMPD_MASTER_AGENTX=$( brandt_get_input "Use the Master Agentx Switch ($SNMPD_MASTER_AGENTX)" "$SNMPD_MASTER_AGENTX" )
	SNMPSA_INTERACTIVE=$( brandt_get_input "Ask for user-name/passwd ($SNMPSA_INTERACTIVE)" "$SNMPSA_INTERACTIVE" )
	SNMPSA_INTERACTION=$( brandt_get_input "Number of interaction table entries ($SNMPSA_INTERACTION)" "$SNMPSA_INTERACTION" )
	SNMPSA_MONITOR=$( brandt_get_input "Monitor NDS Statistics ($SNMPSA_MONITOR)" "$SNMPSA_MONITOR" )
	SNMPSA_SERVER=$( brandt_get_input "Location of NDS Server ($SNMPSA_SERVER)" "$SNMPSA_SERVER" )
}

function update_sysconfig() {
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_LOGLEVEL" "$SNMPD_LOGLEVEL" "System/Net-SNMP" "=" "Log level of the snmp server." "string(!,a,c,e,w,n,i,d,0,1,2,3,4,5,6,7)" "d" 
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_USE_SMUX" "$SNMPD_USE_SMUX" "System/Net-SNMP" "=" "En-/Disables SNMP SMUX support." "yesno" "yes"
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_LOG_SUCCESSFUL_CONNECTIONS" "$SNMPD_LOG_SUCCESSFUL_CONNECTIONS" "System/Net-SNMP" "=" "Connecion logging." "yesno" "yes"
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_SYSNAME" "$SNMPD_SYSNAME" "System/Net-SNMP" "=" "SNMP System Name" "string" "$( hostname )"
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_SYSLOCATION" "$SNMPD_SYSLOCATION" "System/Net-SNMP" "=" "SNMP System Location" "string" "Virtual Machine" 
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_SYSCONTACT" "$SNMPD_SYSCONTACT" "System/Net-SNMP" "=" "SNMP System Contact" "string" "Sysadmin (root@localhost) 555-0123"
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_ROCOMMUNITY" "$SNMPD_ROCOMMUNITY" "System/Net-SNMP" "=" "SNMP Read-Only Communities (Comma Separated)" "string" "public"
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_RWCOMMUNITY" "$SNMPD_RWCOMMUNITY" "System/Net-SNMP" "=" "SNMP Read/Write Communities (Comma Separated)" "string" "private,secret"
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_TRAPCOMMUNITY" "$SNMPD_TRAPCOMMUNITY" "System/Net-SNMP" "=" "SNMP Trap Community" "string" "private"
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_TRAPSINK" "$SNMPD_TRAPSINK" "System/Net-SNMP" "=" "SNMPv1 Trap Host" "string" "snmptrap"
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_TRAP2SINK" "$SNMPD_TRAP2SINK" "System/Net-SNMP" "=" "SNMPv2 Trap Host" "string" "snmptrap"
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_INFORMSINK" "$SNMPD_INFORMSINK" "System/Net-SNMP" "=" "SNMPv2 Trap Inform Host" "string" "snmptrap"
	brandt_modify_config "$_snmp_sysconfig" "SNMPD_MASTER_AGENTX" "$SNMPD_MASTER_AGENTX" "System/Net-SNMP" "=" "En-/Disables SNMP Master Agentx support." "yesno" "yes"
	brandt_modify_config "$_snmp_sysconfig" "SNMPSA_INTERACTIVE" "$SNMPSA_INTERACTIVE" "System/Net-SNMP" "=" "Ask for user-name/passwd" "yesno" "no"
	brandt_modify_config "$_snmp_sysconfig" "SNMPSA_INTERACTION" "$SNMPSA_INTERACTION" "System/Net-SNMP" "=" "Number of interaction table entries" "Integer(0,1,2,3,4,5,6,7,8,9,10)" "4"
	brandt_modify_config "$_snmp_sysconfig" "SNMPSA_MONITOR" "$SNMPSA_MONITOR" "System/Net-SNMP" "=" "Monitor NDS Statistics" "yesno" "yes"
	brandt_modify_config "$_snmp_sysconfig" "SNMPSA_SERVER" "$SNMPSA_SERVER" "System/Net-SNMP" "=" "Location of NDS Server" "string" "localhost"
}

function update_snmpd_conf() {
	touch "$_conf_snmp"
	brandt_modify_config "$_conf_snmp" "sysname" "$SNMPD_SYSNAME"
	brandt_modify_config "$_conf_snmp" "syslocation" "$SNMPD_SYSLOCATION"
	brandt_modify_config "$_conf_snmp" "syscontact" "$SNMPD_SYSCONTACT"
	brandt_modify_config "$_conf_snmp" "rocommunity" "$SNMPD_ROCOMMUNITY"
	brandt_modify_config "$_conf_snmp" "rwcommunity" "$SNMPD_RWCOMMUNITY"
	brandt_modify_config "$_conf_snmp" "trapcommunity" "$SNMPD_TRAPCOMMUNITY"
	brandt_modify_config "$_conf_snmp" "trapsink" "$SNMPD_TRAPSINK"
	brandt_modify_config "$_conf_snmp" "trap2sink" "$SNMPD_TRAP2SINK"
	brandt_modify_config "$_conf_snmp" "informsink" "$SNMPD_INFORMSINK"

	sed -i "s|\s*master\s*agentx.*||I" "$_conf_snmp"
	test "$SNMPD_MASTER_AGENTX" == "yes" && echo "master agentx" >> "$_conf_snmp"
}

function update_ndssnmp_conf() {
	touch "$_conf_snmpsa"
	[ "$SNMPSA_INTERACTIVE" == "yes" ] && tmp="on" || tmp="off"
	brandt_modify_config "$_conf_snmpsa" "INTERACTIVE" "$tmp"
	brandt_modify_config "$_conf_snmpsa" "INTERACTION" "$SNMPSA_INTERACTION"
	[ "$SNMPSA_MONITOR" == "yes" ] && tmp="on" || tmp="off"
	brandt_modify_config "$_conf_snmpsa" "MONITOR" "$tmp"
	brandt_modify_config "$_conf_snmpsa" "SERVER" "$SNMPSA_SERVER"
}

function setup_initd() {
	local _status=0
	echo -n "Modifying system services (init.d scripts) "
	chkconfig $( basename "$_initd_snmp" ) off > /dev/null 2>&1
	_status=$(( $_status | $? ))
	chkconfig $( basename "$_initd_snmpsa" ) off > /dev/null 2>&1
	_status=$(( $_status | $? ))
	chkconfig $( basename "$_this_initd" ) on > /dev/null 2>&1 && chkconfig $( basename "$_this_initd" ) 35 > /dev/null 2>&1
	brandt_status setup
	return $(( $_status | $? ))
}

function setup() {
	local _status=0	
	ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
	_status=$(( $_status | $? ))
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
	_status=$(( $_status | $? ))

	get_defaults
	ANSWER="n"
	while [ "$ANSWER" != "y" ]; do
		verify_info
		test "$ANSWER" == "e" && exit 0
		test "$ANSWER" == "x" && exit 0
		test "$ANSWER" == "n" && get_info
	done

	echo -n "Update snmpd.conf file "
	update_snmpd_conf
	brandt_status setup
	_status=$(( $_status | $? ))

	echo -n "Update ndssnmp.cfg file "
	update_ndssnmp_conf
	brandt_status setup
	_status=$(( $_status | $? ))	

	setup_initd
	_status=$(( $_status | $? ))

	restart
	return $(( $_status | $? ))
}

function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( echo -e "Usage: $0 [options] command"
	  echo -e "Commands:  start     stop     status"
	  echo -e "           restart   setup"
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
	"start" | "stop" | "status" | "restart" )
				deamons $_command $@ ;;
    "setup" )	setup ;;
    * )        	usage 1 ;;
esac
exit $?
