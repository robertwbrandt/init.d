#!/bin/bash
#
#     Wrapper startup script for the domino init.d script
#     Bob Brandt <projects@brandt.ie>
#
### BEGIN INIT INFO
# Provides:          Domino 
# Required-Start:    $ALL
# Required-Stop:
# Default-Start:     3 5
# Default-Stop:      0 1 2 6
# Short-Description: Domino providing IBM Lotus 
# Description:       Start Domino to provide an IBM Lotus Domino Server
#                    Created by Bob Brandt <projects@brandt.ie>
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
_this_conf=/etc/brandt/domino.conf
_this_initd=/etc/init.d/domino
_this_script=/opt/brandt/init.d/domino
_this_rc=/usr/local/bin/rcbrandt-domino
_this_rc2=/usr/local/bin/rcdomino

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
if [ ! -r "$_this_conf" ]; then
	( echo -e "#     Configuration file for Domino startup script"
	  echo -e "#     Bob Brandt <projects@brandt.ie>\n#"
   	  echo -e "           NotesLog=/var/log/domino"
   	  echo -e "          RunAsUser=notes"
   	  echo -e "         RunAsGroup=notes"
   	  echo -e "          DominoBin=/opt/ibm/lotus/bin/server"
   	  echo -e "         DominoConf=/local/notesdata/notes.ini"
   	  echo -e "      DominoDataDir=/local/notesdata"
   	  echo -e "  DominoLicenseFile=/local/notesdata/Domino8.lic"
   	  echo -e "    DominoServerBin=/opt/ibm/lotus/notes/latest/linux/server"
   	  echo -e "       DominoMTABin=/opt/ibm/lotus/notes/latest/linux/smtp"
   	  echo -e "       DominoMDABin=/opt/ibm/lotus/notes/latest/linux/router"
   	  echo -e "    DominoCalDavBin=/opt/ibm/lotus/notes/latest/linux/calconn"
   	  echo -e "       DominoWebBin=/opt/ibm/lotus/notes/latest/linux/http"
	  echo -e "      DominoWebUser='Fidel Castro'"
	  echo -e "      DominoWebPass='cuba'"
	  echo -e "DominoWebTestString='<title>IBM Lotus iNotes Login</title>'"
   	  echo -e "      DominoIMAPBin=/opt/ibm/lotus/notes/latest/linux/imap"
	  echo -e "     DominoIMAPUser='Fidel Castro'"
	  echo -e "     DominoIMAPPass='cuba'" ) > "$_this_conf"
	echo "Unable to find required file: $_this_conf" 1>&2
fi
. "$_brandt_utils"
. "$_this_conf"

function installed() {
	brandt_deamon_wrapper "Domino Server" "$DominoBin" installed
	return $?
}

function configured() {
	brandt_deamon_wrapper "Domino Server" "$DominoConf" configured
	return $?
}

function setup() {
	local _status=0
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
	_status=$?
	ln -sf "$_this_script" "$_this_rc2" > /dev/null 2>&1
	_status=$(( $_status | $? ))
	ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
	_status=$(( $_status | $? ))

	echo -n "Modifying system services (init.d scripts) "
	chkconfig $( basename "$_this_initd" ) on > /dev/null 2>&1 && chkconfig $( basename "$_this_initd" ) 35 > /dev/null 2>&1
	returnvalue $(( $_status | $? ))
	brandt_status setup
	_status=$(( $_status | $? ))

	chownmod root:root 644 "$_this_conf" > /dev/null 2>&1
	_status=$(( $_status | $? ))
	touch $NotesLog > /dev/null 2>&1
	_status=$(( $_status | $? ))	
	chown $RunAsUser:$RunAsGroup $NotesLog > /dev/null 2>&1
	_status=$(( $_status | $? ))	
	chmod 664 $NotesLog > /dev/null 2>&1
	return $(( $_status | $? ))
}

function start() {
	# Verify that log file has the correct permissions
	touch $NotesLog
	chown $RunAsUser:$RunAsGroup $NotesLog
	chmod 664 $NotesLog
	local _uptime=$( cat /proc/uptime | sed "s|\(\S\+\)\..*|\1|" )

	while [[ $_uptime -lt 100 ]]; do
		_waittime=$(( 150 - $_uptime ))
		msg="System was booted $_uptime seconds ago. Waiting $_waittime seconds before attempting another start."
		echo $(date "+%d/%m/%Y %H:%M:%S" )"  $msg" >> "$NotesLog"
		logger -st "Domino" "$msg"
		mount -a
		sleep $_waittime
		_uptime=$( cat /proc/uptime | sed "s|\(\S\+\)\..*|\1|" )
	done

	if [ -f "$DominoLicenseFile" ] && [ -w "$DominoLicenseFile" ]; then
		echo -n "Starting Domino "
		ulimit -n 20000
		if pgrep -U notes "server" > /dev/null
		then
			echo -n "(Domino is already running) "
		else
			cd $DominoDataDir
			su - $RunAsUser -c "$DominoBin >> $NotesLog &"
		fi
		brandt_status start
		return $?
	else
		msg="Unable to file or open Domino License File! ($DominoLicenseFile)"
		echo $(date "+%d/%m/%Y %H:%M:%S" )"  $msg" >> "$NotesLog"
		logger -st "Domino" "$msg"
		return 1
	fi
}

function stop() {
	echo -n "Shutting down Domino "
	if ! pgrep -U notes "server" > /dev/null
	then
		echo -n "(Domino isn't running) "
	else
		cd $DominoDataDir
		su - $RunAsUser -c "$DominoBin -q >> $NotesLog"
	fi
	brandt_status stop
	return $?
}

function killdomino() {
	echo -n "Killing Domino "
	if ! pgrep -U notes "server" > /dev/null
	then
		echo -n "(Domino isn't running) "
	else
		pkill -9 -U $RunAsUser
	fi
	brandt_status kill
	return $?
}

function status() {
	local _status=0	
	local _substatus=$( lower ${1:-all} )
	brandt_deamon_wrapper "Domino Server Service" "$DominoServerBin" "status-checkproc"
	_status=$?

	echo -n "Checking for Domino Log activity"
	_lag=$( dateDiff "$( stat -c '%y' $NotesLog )" "" "minutes" )
	test $_lag -lt 2
	brandt_status status
	_status=$(( $_status | $? ))
	
	if [ "$_substatus" == "mta" ] || [ "$_substatus" == "all" ]; then
		brandt_deamon_wrapper "Domino SMTP Service" "$DominoMTABin" "status-checkproc"
		_status=$(( $_status | $? ))

		echo -n "Verifying SMTP Service is responding"
		tmp=$( ( sleep 1 ; echo "helo client.test.com"; sleep 1; echo "noop" ; sleep 1 ; echo "quit" ) | telnet 127.0.0.1 25 2> /dev/null )
		echo "$tmp" | grep "250 OK" > /dev/null 2>&1
		brandt_status status
		_status=$(( $_status | $? ))
	fi
	if [ "$_substatus" == "mda" ] || [ "$_substatus" == "all" ]; then
		brandt_deamon_wrapper "Domino Router Service" "$DominoMDABin" "status-checkproc"
		_status=$(( $_status | $? ))
	fi
	if [ "$_substatus" == "web" ] || [ "$_substatus" == "all" ]; then
		brandt_deamon_wrapper "Domino HTTP Service" "$DominoWebBin" "status-checkproc"
		_status=$(( $_status | $? ))

		echo -n "Verifying HTTP Service is responding"
		wget --user="$DominoWebUser" --password="$DominoWebPass" -O - -o /dev/null http://127.0.0.1/ | grep "$DominoWebTestString" > /dev/null 2>&1
		brandt_status status
		_status=$(( $_status | $? ))
	fi
	if [ "$_substatus" == "imap" ] || [ "$_substatus" == "all" ]; then
		brandt_deamon_wrapper "Domino IMAP Service" "$DominoIMAPBin" "status-checkproc"
		_status=$(( $_status | $? ))

		echo -n "Verifying IMAP Service is responding"
		tmp=$( ( sleep 1 ; echo -e "a1 login \"$DominoIMAPUser\" \"$DominoIMAPPass\""; sleep 1; echo 'a2 list "" "*"' ; sleep 1 ; echo 'a3 logout' ) | telnet 127.0.0.1 143 2> /dev/null )
		( echo "$tmp" | grep -i "a1 OK LOGIN completed" && echo "$tmp" | grep -i "a2 OK LIST completed" ) > /dev/null 2>&1
		brandt_status status
		_status=$(( $_status | $? ))
	fi
	if [ "$_substatus" == "caldav" ] || [ "$_substatus" == "all" ]; then
		brandt_deamon_wrapper "Domino CalDav Service" "$DominoCalDavBin" "status-checkproc"
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
	  echo -e "Commands:  start     stop     status"
	  echo -e "           restart   reload   kill"
	  echo -e "           force-reload"
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
	"start" )				start ;;
	"stop" )				stop ;;
	"kill" )				killdomino  ;;
	"status" )				status $@ ;;
	"restart"|"reload")		$0 stop && $0 start ;;
	"force-reload" ) 		$0 stop || $0 kill
							$0 start ;;
    "setup" )				setup ;;							
    * )        				usage 1 ;;
esac
exit $?
