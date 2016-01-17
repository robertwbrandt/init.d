#!/bin/bash
#
#     Wrapper startup script for NetApp SnapVault
#     Bob Brandt <projects@brandt.ie>
#          
#
### BEGIN INIT INFO
# Provides:          brandt-netapp
# Required-Start:    $ALL
# Required-Stop:
# Default-Start:     3 5
# Default-Stop:      0 1 2 6
# Short-Description: NetApp Snapvault
# Description:       Wrapper script for the NetApp Host and SnapVault Agent
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
_this_conf=/etc/brandt/netapp.conf
_this_script=/opt/brandt/init.d/netapp
_this_initd=/etc/init.d/brandt-netapp
_this_rc=/usr/local/bin/rcbrandt-netapp
_dir_snapvault=/usr/snapvault
_bin_netapp=/usr/snapvault/bin/svpmgr
_bin_snapvault=/usr/snapvault/bin/snapvault
_bin_svestimator=/usr/snapvault/bin/svestimator
_bin_ossvinfo=/usr/snapvault/bin/ossvinfo.pl
_bin_hostagent=/opt/NTAPagent/ntap_agent
_conf_netapp=/usr/snapvault/config/snapvault.cfg
_initd_netapp=/etc/init.d/snapvault
_initd_hostagent=/etc/init.d/NTAPagent

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
if [ ! -r "$_this_conf" ]; then
	( echo -e "#     Configuration file for NetApp Host and SnapVault wrapper startup script"
	  echo -e "#     Bob Brandt <projects@brandt.ie>\n#"
   	  echo -e "_setup_snapvault=/opt/netapp/install_ossv"
   	  echo -e "_setup_snapvault_upgrade=/opt/netapp/upgrade_ossv"
   	  echo -e "_setup_hostagent=/opt/netapp/install_hostagent"
   	  echo -e "_ossv_username=ossv"
   	  echo -e "_ossv_password=d00r5nt"
   	  echo -e "_ossv_bli_level=HIGH"
   	  echo -e "_ossv_backup_root=/backup" ) > "$_this_conf"
	echo "Unable to find required file: $_this_conf" 1>&2
fi

. "$_brandt_utils"
. "$_this_conf"

verbose=1

function installed() {
	local _status=0
    brandt_deamon_wrapper "NetApp daemon" "$_bin_netapp" installed
	_status=$(( $_status | $? ))
    brandt_deamon_wrapper "NetApp SnapVault daemon" "$_bin_snapvault" installed
	_status=$(( $_status | $? ))
    brandt_deamon_wrapper "NetApp Host Agent daemon" "$_bin_hostagent" installed
	return $(( $_status | $? ))
}

function configured() {
    brandt_deamon_wrapper "NetApp daemon" "$_conf_netapp" configured
	return $?
}

function start() {
	local _status=0
    brandt_deamon_wrapper "NetApp Host Agent deamon" "$_initd_hostagent" start
	_status=$(( $_status | $? ))
    brandt_deamon_wrapper "NetApp daemon" "$_initd_netapp" start
	return $(( $_status | $? ))
}

function stop() {
	local _status=0
    brandt_deamon_wrapper "NetApp daemon" "$_initd_netapp" stop
	_status=$(( $_status | $? ))
    brandt_deamon_wrapper "NetApp Host Agent deamon" "$_initd_hostagent" stop
	return $(( $_status | $? ))
}

function status() {
	local _status=0
    brandt_deamon_wrapper "NetApp Host Agent daemon" "$_bin_hostagent" status-process
	_status=$(( $_status | $? ))
    brandt_deamon_wrapper "NetApp daemon" "$_bin_netapp" status-process

    if [ "$_quiet" == "1" ]; then
        $_bin_snapvault status
    fi

	return $(( $_status | $? ))
}

function kill_deamon() {
	local _status=0
    brandt_deamon_wrapper "NetApp daemon" "$_initd_netapp" kill "$_bin_netapp"
	_status=$(( $_status | $? ))
	echo -n "Stopping NetApp Host Agent deamon "
	$_bin_hostagent -k > /dev/null 2>&1
  	brandt_status stop
	echo -n "Killing NetApp agents "
	( pkill -9 -f "$( basename $_bin_snapvault )" && ( pkill -9 svcmgr || pkill -9 svlistener ) ) > /dev/null 2>&1
  	brandt_status kill
	_status=$(( $_status | $? ))
    brandt_deamon_wrapper "NetApp Host agent" "$_initd_hostagent" kill "$_bin_hostagent"
	return $(( $_status | $? ))
}

function setup_ndmp_account() {
	echo -n "Modify NDMP Account Username and Password "
	"$_dir_snapvault/util/svsetstanza" config snapvault.cfg NDMP "Account" Value "$_ossv_username" FALSE && "$_dir_snapvault/bin/svpassword" "$_ossv_password"
  	brandt_status setup
  	return $?
}

function setup_check_QSM_ACL() {
	echo -n "Modify Check QSM Access List "
	"$_dir_snapvault/util/svsetstanza" config snapvault.cfg QSM "Check Access List" Value FALSE FALSE
  	brandt_status setup
  	return $?
}

function setup_BLI_Level() {
	echo -n "Modify BLI Level to High "
	"$_dir_snapvault/util/svsetstanza" config snapvault.cfg Configuration "Checksums" Value "$_ossv_bli_level" FALSE
  	brandt_status setup
  	return $?
}

function verify_fstab() {
	local _status=0	
	local _folder="$1"
	if [ -d "$_folder" ]; then
		[ -d "${_ossv_backup_root}${_folder}" ] || ( mkdir -p "${_ossv_backup_root}${_folder}" > /dev/null 2>&1 ; _status=$(( $_status | $? )) )
		tmp=$( sed -n "s|^${_folder}\s*${_ossv_backup_root}${_folder}\s*none\s*bind\s*0\s*0|&|p" /etc/fstab )
		[ -z "$tmp" ] && echo -e "${_folder}\t${_ossv_backup_root}${_folder}\tnone\tbind\t0 0" >> /etc/fstab
	else
		/bin/true
	fi
	return $(( $_status | $? ))
}

function setup_backup_folder() {
	local _status=0	
	echo -n "Create Mount Points for System Backup "
	verify_fstab "/boot" ; _status=$(( $_status | $? ))
	verify_fstab "/etc" ; _status=$(( $_status | $? ))
	verify_fstab "/var/opt/novell/eDirectory" ; _status=$(( $_status | $? ))
	verify_fstab "/var/opt/novell/iprint" ; _status=$(( $_status | $? ))
	mount -a
	returnvalue $(( $_status | $? ))
  	brandt_status setup
  	return $?
}

function setup_initd() {
	local _status=0
	echo -n "Modifying system services (init.d scripts) "
	chkconfig $( basename "$_initd_netapp" ) off > /dev/null 2>&1
	_status=$(( $_status | $? ))
	chkconfig $( basename "$_initd_hostagent" ) off > /dev/null 2>&1
	_status=$(( $_status | $? ))	
	chkconfig $( basename "$_this_initd" ) on > /dev/null 2>&1 && chkconfig $( basename "$_this_initd" ) 35 > /dev/null 2>&1
	returnvalue $(( $_status | $? ))
	brandt_status setup
	return $?
}

function debug() {
	case "$1" in
	    on)
			echo -n "Turning on debug "
			"$_dir_snapvault/util/svsetstanza" config configure.cfg Trace "Trace To File" Value true FALSE &&
			"$_dir_snapvault/util/svsetstanza" config programs.cfg "Process Manager" "Trace Level" Value VERBOSE FALSE &&
			"$_dir_snapvault/util/svsetstanza" config programs.cfg "Communication Manager" "Trace Level" value VERBOSE FALSE &&
			"$_dir_snapvault/util/svsetstanza" config programs.cfg "SnapVault Listener" "Trace Level" value VERBOSE FALSE &&
			"$_dir_snapvault/util/svsetstanza" config programs.cfg "NDMP Server" "Trace Level" value VERBOSE FALSE &&
			"$_dir_snapvault/util/svsetstanza" config programs.cfg "QSM Server" "Trace Level" value VERBOSE FALSE
		;;
	    *)
			echo -n "Turning off debug "
			"$_dir_snapvault/util/svsetstanza" config configure.cfg Trace "Trace To File" Value false FALSE &&
			"$_dir_snapvault/util/svsetstanza" config programs.cfg "Process Manager" "Trace Level" Value NORMAL FALSE &&
			"$_dir_snapvault/util/svsetstanza" config programs.cfg "Communication Manager" "Trace Level" value NORMAL FALSE &&
			"$_dir_snapvault/util/svsetstanza" config programs.cfg "SnapVault Listener" "Trace Level" value NORMAL FALSE &&
			"$_dir_snapvault/util/svsetstanza" config programs.cfg "NDMP Server" "Trace Level" value NORMAL FALSE &&
			"$_dir_snapvault/util/svsetstanza" config programs.cfg "QSM Server" "Trace Level" value NORMAL FALSE
		;;
	esac
	brandt_status setup
	return $?
}

function setup() {
	local _status=0	
	ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
	_status=$(( $_status | $? ))	
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
	_status=$(( $_status | $? ))
	chownmod root:root 644 "$_this_conf" > /dev/null 2>&1
	_status=$(( $_status | $? ))

	setup_ndmp_account
	_status=$(( $_status | $? ))
	setup_check_QSM_ACL
	_status=$(( $_status | $? ))
	setup_BLI_Level
	_status=$(( $_status | $? ))
	setup_backup_folder
	_status=$(( $_status | $? ))
	debug off
	_status=$(( $_status | $? ))
	setup_initd
	return $(( $_status | $? ))
}

function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( echo -e "Usage: $0 [options] command"
	  echo -e "Commands:  start     stop    restart"
	  echo -e "           status    kill    setup"
	  echo -e "           installcheck"
	  echo -e "Options:"
	  echo -e " -s, --servers  comma seperated list of ntp servers"
	  echo -e " -q, --quiet    be quiet"
	  echo -e " -h, --help     display this help and exit"
	  echo -e " -v, --version  output version information and exit\n" 
	  $_bin_snapvault 2>&1 | tail -n 2 | sed "s|^[^U]|\t&|g"
	  $_bin_svestimator 2>&1 | sed -e "s|$_bin_svestimator|$0 estimate|" -e "s|^[^U]|\t&|g"
	  $_bin_ossvinfo 2>&1 | sed -e "s|usage.*||" -e "s|.*version||" -e "s|.*ossvinfo.pl|Usage: $0 ossvinfo|g" -e "s|^[^U]|\t&|g" ) >&$_output
	exit $_exitcode
}

function version() {	
	echo -n "    NetApp Host Agent "
	wget -q -O - "http://localhost:4092/about" | grep -A 1 "Agent Version" | tail -n 1 | sed -e "s|</..>||" -e "s|.*>||"

	echo -n "    NetApp OSSV Agent "
	head -n 1 "/usr/snapvault/RELEASEDEF"

	echo -n "NetApp OSSV Installer "
	head -n 1 "/opt/netapp/ossv/RELEASEDEF"

    echo -e "$( basename $0 ) $_version"
	echo -e "Copyright (C) 2011 Free Software Foundation, Inc."
	echo -e "License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>."
	echo -e "This is free software: you are free to change and redistribute it."
	echo -e "There is NO WARRANTY, to the extent permitted by law.\n"
	echo -e "Written by Bob Brandt <projects@brandt.ie>."

	exit 0
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
        -v | --version )   version $_version ;;
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
	"start" | "stop" | "status" )
						$_command $@ ;;
    "kill" )			kill_deamon ;;
    "restart" )       	( stop || kill_deamon ) ; start ;;
    "snapvault" )     	shift 1 ; "$_bin_snapvault" $@ ;;
    "estimate" | "installcheck" )	
						shift 1 ; "$_bin_svestimator" $@ ;;
    "ossvinfo" )      	shift 1 ; "$_bin_ossvinfo" $@ ;;
    "setup" )			setup ;;
    * )					usage 1 ;;
esac
exit $?
