#!/bin/bash
#
#     Wrapper startup script for iPrint
#     Bob Brandt <projects@brandt.ie>
#          
#
### BEGIN INIT INFO
# Provides:          brandt-iprint
# Required-Start:    $ALL
# Required-Stop:
# Default-Start:     3 5
# Default-Stop:      0 1 2 6
# Short-Description: iPrint-Server
# Description:       Wrapper for Standard Novell iPrint
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
_this_script=/opt/brandt/init.d/oes/iprint.sh
_this_initd=/etc/init.d/brandt-iprint
_this_rc=/usr/local/bin/rcbrandt-iprint
_this_conf=/etc/brandt/iprint.conf

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
if [ ! -r "$_this_conf" ]; then
	( echo -e "#     Configuration file for iPrint wrapper startup script"
	  echo -e "#     Bob Brandt <projects@brandt.ie>\n#"
	  echo -e "_bin_apache=/usr/sbin/httpd2-worker"
	  echo -e "_bin_iprint_idsd=/opt/novell/iprint/bin/idsd"
	  echo -e "_bin_iprint_ipsmd=/opt/novell/iprint/bin/ipsmd"
	  echo -e "_bin_pcounter=/opt/novell/iprint/bin/pcounter\n"
	  echo -e "_config_apache=/etc/apache2/httpd.conf"
	  echo -e "_config_iprint_idsd=/etc/opt/novell/iprint/conf/idsd.conf"
	  echo -e "_config_iprint_ipsmd=/etc/opt/novell/iprint/conf/ipsmd.conf"
	  echo -e "_config_pcounter=/etc/opt/novell/httpd/conf.d/pcounter.conf\n"
	  echo -e "_initd_apache=/etc/init.d/apache2"
	  echo -e "_initd_idsd=/etc/init.d/novell-idsd"
	  echo -e "_initd_ipsmd=/etc/init.d/novell-ipsmd\n"
	  echo -e "_this_cron=/etc/cron.hourly/iprint-reload\n"
	  echo -e "_iprint_client_htdocs=/var/opt/novell/iprint/htdocs"
	  echo -e "_iprint_client_base=${_iprint_client_htdocs}/clients"
	  echo -e "_iprint_client_default=nipp-s.exe\n"
	  echo -e "_iprint_sysconfig=/etc/sysconfig/novell/iprnt2_sp2"
	  echo -e "[ -f \"\$_iprint_sysconfig\" ] || _iprint_sysconfig=/etc/sysconfig/novell/iprnt2_sp3" ) > "$_this_conf"
	echo "Unable to find required file: $_this_conf" 1>&2
fi

. "$_brandt_utils"
. "$_this_conf"
[ ! -r "$_iprint_sysconfig" ] && echo "Unable to find required file: $_iprint_sysconfig" 1>&2 && exit 6
. "$_iprint_sysconfig"

function installed() {
	local _status=0
	brandt_deamon_wrapper "Apache daemon" "$_bin_apache" installed
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell iPrint DriverStore" "$_bin_iprint_idsd" installed
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell iPrint Manager" "$_bin_iprint_ipsmd" installed
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper " Pcounter deamon" "$_bin_pcounter" installed
	return $_status
}

function configured() {
	local _status=0
	brandt_deamon_wrapper "Apache daemon" "$_config_apache" configured
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell iPrint DriverStore" "$_config_iprint_idsd" configured	
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell iPrint Manager" "$_config_iprint_ipsmd" configured
	_status=$(( $_status | $? ))
	[ -x "$_bin_pcounter" ] && brandt_deamon_wrapper "Pcounter deamon" "$_config_pcounter" configured
	brandt_deamon_wrapper "Novell iPrint SysConfig" "$_iprint_sysconfig" configured
	return $(( $_status | $? ))	
}

function start() {
	local _command=${1:-start}	
	local _status=0
	brandt_deamon_wrapper "Apache2 httpd2 (worker)" "$_initd_apache"  "$_command"
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell iPrint Manager" "$_initd_ipsmd"  "$_command"
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell iPrint DriverStore" "$_initd_idsd" "$_command"	
	return $(( $_status | $? ))
}

function stop() {
	local _command=${1:-stop}	
	local _status=0	
	brandt_deamon_wrapper "Novell iPrint DriverStore" "$_initd_idsd" "$_command" "$( basename $_bin_iprint_idsd )"
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell iPrint Manager" "$_initd_ipsmd"  "$_command" "$( basename $_bin_iprint_ipsmd )"
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Apache2 httpd2 (worker)" "$_initd_apache"  "$_command" "$( basename $_bin_apache )"
	_status=$(( $_status | $? ))
	if [ -x "$_bin_pcounter" ] && [ "$_command" == "kill" ]; then
		brandt_deamon_wrapper "Pcounter for OES Linux" "" kill "$( basename $_bin_pcounter )"
		_status=$(( $_status | $? ))
	fi	
	return $_status
}

function status() {
	local _status=0	
	brandt_deamon_wrapper "Novell iPrint DriverStore" "$_initd_idsd" status
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell iPrint Manager" "$_initd_ipsmd" status
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Apache daemon" "$_initd_apache" status
	_status=$(( $_status | $? ))

	brandt_deamon_wrapper "Novell iPrint WebSite" "http://127.0.0.1/ipp/styles/iprint.css" status-web	
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Novell iPrint Manager PsmStatus" "https://scanner:scanner@127.0.0.1/PsmStatus" status-web	
	return $(( $_status | $? ))
}

function test_deamon() {
	if ! status
	then
		echo -e ""
		logger -st "$( basename $0 )" "${BOLD_RED}The Novell iPrint System is malfunctioning. Restarting system.${NORMAL}"
		stop kill
		sleep 5s
		start start
	fi
	return $?
}

function setup_initd() {
	local _status=0
	echo -n "Modifying system services (init.d scripts) "
	chkconfig $( basename "$_initd_apache" ) off > /dev/null 2>&1
	_status=$(( $_status | $? )) 
	chkconfig $( basename "$_initd_idsd" ) off > /dev/null 2>&1
	_status=$(( $_status | $? ))
	chkconfig $( basename "$_initd_ipsmd" ) off > /dev/null 2>&1
	_status=$(( $_status | $? ))
	chkconfig $( basename "$_this_initd" ) on > /dev/null 2>&1 && chkconfig $( basename "$_this_initd" ) 35 > /dev/null 2>&1
	returnvalue $(( $_status | $? ))
	brandt_status setup
	_status=$?

	if [ -x "$_bin_pcounter" ]; then
		echo -n "Setting up Pcounter for OES Linux "
		chownmod -Rf root:iprint 4750 "$_bin_pcounter" && chown wwwrun:www "$_config_pcounter"
		brandt_status setup
		_status=$(( $_status | $? ))
	fi

	return $_status
}

function changenipp() {
	local _status=0	
	for item in $( find $_iprint_client_base -iname nipp.exe ); do
		if [ -f "$item" ] && [ ! -h "$item" ]; then
			echo -n "Modifying default iPrint Client (${item#$_iprint_client_base}) "
			mv "$item" "${item%.exe}-orig.exe"
			_status=$(( $_status | $? )) 			
			ln -sf "${item%/*}/$_iprint_client_default" "$item"
			brandt_status setup
			_status=$(( $_status | $? ))
		fi
	done
	return $_status	
}

function modifyiprintini() {
	local _status=0	
	echo -n "Modifying iprint.ini AllowAutoUpdate "
#                              ;0 = Don't automatically update client.
#                              ;1 = Update client at boot time, prompt user.
#                              ;2 = Update client at boot time, don't prompt user.
	sed -i "s|AllowAutoUpdate =.*|AllowAutoUpdate = 1           ;Get newer iPrint client from Server?|" $_iprint_client_htdocs/iprint.ini > /dev/null 2>&1
	brandt_status setup
	_status=$(( $_status | $? )) 

	echo -n "Modifying iprint.ini AllowUserPrinters "
#                              ;0 = Add GLOBAL OR WORKSTATION PRINTER.
#                              ;1 = Add PRIVATE OR USER PRINTER.
#                              ;2 = Only add USER PRINTERS.  No rights required.
#                              ;3 = Only add WORKSTATION PRINTERS.  No rights required.
	sed -i "s|AllowUserPrinters =.*|AllowUserPrinters = 3         ;Printer Installation Profile|" $_iprint_client_htdocs/iprint.ini > /dev/null 2>&1
	brandt_status setup
	_status=$(( $_status | $? )) 

	echo -n "Modifying iprint.ini UpgradeNDPSPrinters "
#                              ;0 = Leave NDPS installed printers alone (DEFAULT).
#                              ;1 = Prompt the user to upgrade the printer to an iPrint printer.
#                              ;2 = Silently upgrade the printer to an iPrint printer.
	sed -i "s|UpgradeNDPSPrinters =.*|UpgradeNDPSPrinters = 2       ;Upgrade NDPS Printers Profile|" $_iprint_client_htdocs/iprint.ini > /dev/null 2>&1
	brandt_status setup
	_status=$(( $_status | $? )) 

	echo -n "Modifying iprint.ini InformUserOfUpdates "
#                              ;0 = Do not inform the user of changes.
#                              ;1 = Inform user of changes via message box (DEFAULT).
	sed -i "s|InformUserOfUpdates =.*|InformUserOfUpdates = 1       ;Inform user that printer has|" $_iprint_client_htdocs/iprint.ini > /dev/null 2>&1
	brandt_status setup
	return $(( $_status | $? )) 
}

function modifypermissions() {
	local _status=0	
	echo -n "Modifying iprint file permissions "
#		If the ownerships and permissions are not exactly as shown below, then a 1344 or 1345 Error can occur.
#		Under the /var/opt/novell/iprint directory the ownerships and permissions are not exactly as shown below, then a Error can occur.
#		drwxrwxr-x iprint iprint [Print Manager Name].psm 
#		drwxrwxr-x root   www    mod_ipp
#		drwxr-xr-x wwwrun www    mod_ipp/drivers 
#		drwxr-xr-x wwwrun www    mod_ipp/drivers/[OS_name] 
#		-rw-r--r-- wwwrun www    mod_ipp/drivers/[OS_name]/[Driver_file]
	(
	chownmod -Rf iprint:iprint u+rwx,g+rwx,o+rx /var/opt/novell/iprint/*.psm
	return $(( $_status | $? )) 

	if [ -d /var/opt/novell/iprint/mod_ipp ]; then
		chownmod -Rf :www u+rwx,g+rwx,o+rx /var/opt/novell/iprint/mod_ipp
		return $(( $_status | $? )) 
	fi

	if [ -d /var/opt/novell/iprint/mod_ipp/drivers ]; then
		chownmod -Rf wwwrun:www u+rwx,g+rx,o+rx /var/opt/novell/iprint/mod_ipp/drivers
		return $(( $_status | $? ))		
	fi
	)
	returnvalue $_status
	brandt_status setup
	return $?
}

function setup_cron_job() {
	echo -en "Setup iPrint Test cron job "
	( echo -e "#!/bin/bash\n$_this_script test\nexit $?\n" > "$_this_cron" && chownmod -Rf root:root 544 "$_this_cron" ) > /dev/null 2>&1
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
	chownmod root:root 644 "$_iprint_sysconfig" > /dev/null 2>&1
	_status=$(( $_status | $? )) 

	setup_initd
	_status=$(( $_status | $? ))
	changenipp
	_status=$(( $_status | $? ))
	modifyiprintini
	_status=$(( $_status | $? ))
	modifypermissions
	_status=$(( $_status | $? ))
	setup_cron_job
	#_status=$(( $_status | $? ))
	#$0 restart
	return $(( $_status | $? ))	
}

function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( echo -e "Usage: $0 [options] command"
	  echo -e "Commands:  start     stop            status"
	  echo -e "           restart   try-restart     kill"
	  echo -e "           reload    force-reload    setup"
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
    "stop" | "kill")	stop "$_command" ;;
    "status" )			status ;;
	"test" )			test_deamon ;;
    "setup" )			setup ;;
    * )        			usage 1 ;;
esac
exit $?
