#!/bin/bash
#
#     Wrapper startup script for Samba
#     Bob Brandt <projects@brandt.ie>
#          
#
### BEGIN INIT INFO
# Provides:          brandt-samba
# Required-Start:    $ALL
# Required-Stop:
# Default-Start:     3 5
# Default-Stop:      0 1 2 6
# Short-Description: Samba-Server
# Description:       Wrapper for Standard Novell Samba
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
_this_conf=/etc/brandt/samba.conf
_this_script=/opt/brandt/init.d/oes/samba.sh
_this_initd=/etc/init.d/brandt-samba
_this_rc=/usr/local/bin/rcbrandt-samba
_this_cron1=/etc/cron.hourly/samba-reload
_this_cron2=/etc/cron.hourly/samba-cleanup
_bin_smbd=/usr/sbin/smbd
_bin_nmbd=/usr/sbin/nmbd
_conf_samba=/etc/samba/smb.conf
_initd_smbd=/etc/init.d/smb
_initd_nmbd=/etc/init.d/nmb
_initd_lum=/opt/brandt/init.d/oes/lum.sh

_setup_samba_sysconfig=/etc/sysconfig/novell/nvlsamba2_sp2
test -f "$_setup_samba_sysconfig" || _setup_samba_sysconfig=/etc/sysconfig/novell/nvlsamba2_sp3
_setup_default_conf=/opt/brandt/samba/samba.conf.default

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
[ ! -r "$_this_conf" ] && [ ! "$1" == "setup" ] && echo "Unable to find required file: $_this_conf" 1>&2 && exit 6
. "$_brandt_utils"
[ -r "$_this_conf" ] && . "$_this_conf"
. "$_setup_samba_sysconfig"

SAMBA_SETUP_CONFIG="/opt/brandt/samba/samba-config"
SAMBA_SETUP_DOMAIN="/opt/brandt/samba/samba-domainobject"
SAMBA_SETUP_COMPUTER="/opt/brandt/samba/samba-computer"
SAMBA_SETUP_USERS="/opt/brandt/samba/samba-users"
SAMBA_SMBD="/opt/brandt/smb.d"
SAMBA_SCANNER_CLEANUP_DAYS=4

function installed() {
	local _status=0
	brandt_deamon_wrapper "Samba SMB daemon" "$_bin_smbd" installed
	_status=$(( $_status | $? ))

	brandt_deamon_wrapper "Samba NMB deamon" "$_bin_nmbd" installed
	return $(( $_status | $? ))	
}

function configured() {
	brandt_deamon_wrapper "Samba daemon" "$_conf_samba" configured
	return $?
}

function deamons() {
    local _command=${1:-status}
    shift	
	local _status=0
	brandt_deamon_wrapper "Samba SMB daemon" "$_initd_smbd" "$_command" $@
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Samba NMB deamon" "$_initd_nmbd" "$_command" $@
	return $(( $_status | $? ))	
}

function start() {
	local _status=0
	brandt_deamon_wrapper "Novell LUM NAMCD daemon" "$_initd_lum" start $@
	_status=$(( $_status | $? ))
	mount -a
	deamons start $@
	return $(( $_status | $? ))
}

function status() {
	local _status=0
	if [ "$_quiet" == "1" ]; then
    	brandt_deamon_wrapper "Novell LUM NAMCD daemon" "$_initd_lum" status $@
		_status=$(( $_status | $? ))
	fi
	brandt_deamon_wrapper "Samba SMB daemon" "$_initd_smbd" status $@
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Samba NMB deamon" "$_initd_nmbd" status $@
	return $_status
}

function reload() {
	local _status=0
    brandt_deamon_wrapper "Novell LUM NAMCD daemon" "$_initd_lum" reload $@
	_status=$(( $_status | $? ))
	mount -a
	brandt_deamon_wrapper "Samba SMB daemon" "$_initd_smbd" reload $@
	return $(( $_status | $? ))
}

function kill_deamon() {
	local _status=0
	brandt_deamon_wrapper "Samba SMB daemon" "$_initd_smbd" kill "$_bin_smbd"
	_status=$(( $_status | $? ))
	brandt_deamon_wrapper "Samba NMB deamon" "$_initd_nmbd" kill "$_bin_nmbd"
	return $(( $_status | $? ))	
}

function cleanup() {
	local _status=0	
	OLDIFS="$IFS"
	IFS=$'\n'
	for scannerpath in $( sed -n "s|\s*path\s*=\s*||gIp" /etc/samba/smb.d/scanner )
	do
		tmp=
		for deletefile in $( find "$scannerpath" -ctime +$SAMBA_SCANNER_CLEANUP_DAYS -print 2> /dev/null )
		do
			rm "$deletefile" && tmp="$tmp\n Deleting file: $deletefile"
		done
		for deletefolder in $( find "$scannerpath" -type d -mindepth 1 -empty -print 2> /dev/null )
		do
			rm -r "$deletefolder" && tmp="$tmp\n Removing Empty Folder: $deletefolder"
		done

		if [ -n "$tmp" ]; then
			echo -e "Checking Scanner Path ($scannerpath)$tmp" | logger -s -t "samba-cleanup"
			_status=1
		fi
	done
	IFS="$OLDIFS"

	return $_status
}

function log() {
	tail -n 200 -f /var/log/samba/log.nmbd -f /var/log/samba/log.smbd
	return $_status	
}

function setup_config_file() {
	echo -n "Creating Samba Config file "
	if [ -r "$_setup_samba_sysconfig" ]; then
		ln -sf "$_setup_samba_sysconfig" "$_this_conf"
	else
		cp "$_setup_default_conf" "$_this_conf"
	fi
	brandt_status setup
	return $?	
}

function setup_initd() {
	local _status=0
	echo -n "Modifying system services (init.d scripts) "
	chkconfig $( basename "$_initd_smbd" ) off > /dev/null 2>&1
	_status=$(( $_status | $? ))
	chkconfig $( basename "$_initd_nmbd" ) off > /dev/null 2>&1
	_status=$(( $_status | $? ))
	chkconfig $( basename "$_this_initd" ) on > /dev/null 2>&1 && chkconfig $( basename "$_this_initd" ) 35 > /dev/null 2>&1
	returnvalue $(( $_status | $? ))
	brandt_status setup
	return $?
}

function setup_cron_job() {
	local _status=0	
	echo -en "Setup Samba Test cron job "
	( echo -e "#!/bin/bash\n$_this_script test || $_this_script restart\nexit $?\n" > "$_this_cron1" && chownmod -Rf root:root 544 "$_this_cron1" ) > /dev/null 2>&1
	brandt_status setup
	_status=$(( $_status | $? ))
	echo -en "Setup Samba Cleanup Test cron job "
	( echo -e "#!/bin/bash\n$_this_script cleanup\nexit $?\n" > "$_this_cron2" && chownmod -Rf root:root 544 "$_this_cron2" ) > /dev/null 2>&1
	brandt_status setup
	return $?
}

function setup() {
	local _status=0	
	ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
	_status=$(( $_status | $? ))	
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
	_status=$(( $_status | $? ))

	setup_config_file
	_status=$(( $_status | $? ))

	setup_initd
	return $(( $_status | $? ))


	# if $SAMBA_SETUP_CONFIG setup
	# then
	# 	$SAMBA_SETUP_DOMAIN setup
	# 	setup_cron_job
	# 	$INITD_SCRIPT_LUM refresh
	# 	$ORIG_SCRIPT restart
	# fi
	# return $(( $_status | $? ))
}

function test_deamon() {
	local _status=0	

	[ -z "$_username" ] && _username="$CONFIG_SAMBA_TEST_USER"
	[ -z "$_share" ] && _share="//$CONFIG_SAMBA_NETBIOS_NAME/$CONFIG_SAMBA_TEST_SHARE"
	[ "${_share:0:2}" != "//" ] && _share="//$CONFIG_SAMBA_NETBIOS_NAME/$_share"

	[ -z "$_password" ] &&  [ "$_username" == "$CONFIG_SAMBA_TEST_USER" ] && _password="$CONFIG_SAMBA_TEST_PASSWORD"
    [ -n "$_username" ] && [ -z "$_password" ] && read -sp "Password for $_username: " _password && echo
    
    [ "$_quiet" == "1" ] && echo -e "Running the following command:\nsmbclient \"$_share\" -U \"$_username\" -c \"exit\""

    echo -en "Testing if $_username can connect to $_share "
    tmp=$( smbclient "$_share" "$_password" -U "$_username" -c "exit" 2>&1 )
	brandt_status setup
    _status=$?

    [ "$_quiet" == "1" ] && echo "$tmp"
    [ "$_status" != "0" ] && _quiet=1 && status
    return $_status
}


function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( echo -e "Usage: $0 [options] command"
	  echo -e "Commands:  start    stop     status"
	  echo -e "           restart  reload   setup"
	  echo -e "           kill     log      cleanup"
	  echo -e "Options:"
	  echo -e " -u, --username  username for testing (default: $CONFIG_SAMBA_TEST_USER)"
	  echo -e " -p, --password  password for testing (default: $CONFIG_SAMBA_TEST_PASSWORD)"
	  echo -e " -s, --share     share for testing (default: //$CONFIG_SAMBA_NETBIOS_NAME/$CONFIG_SAMBA_TEST_SHARE)"
	  echo -e " -q, --quiet     be quiet"
	  echo -e " -h, --help      display this help and exit"
	  echo -e " -v, --version   output version information and exit" ) >&$_output
	exit $_exitcode
}

# Execute getopt
if ! _args=$( getopt -o u:p:s:qvh -l "username:,password:,share:,quiet,help,version" -n "$0" -- "$@" 2>/dev/null ); then
	_err=$( getopt -o u:p:s:qvh -l "username:,password:,share:,quiet,help,version" -n "$0" -- "$@" 2>&1 >/dev/null )
	usage 1 "${BOLD_RED}$_err${NORMAL}"
fi

#Bad arguments
#[ $? -ne 0 ] && usage 1 "$0: No arguments supplied!\n"

eval set -- "$_args";
_quiet=1
_username=
_password=
_share=
while /bin/true ; do
    case "$1" in
        -u | --username )  _username="$2" ; shift ;;
        -p | --password )  _password="$2" ; shift ;;
        -s | --share )     _share="$2" ; shift ;;
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
    "start" | "status" | "reload" )
                $_command $@ ;;
    "stop" | "restart" )
		deamons "$_command" $@ ;;
    "kill" ) 	kill_deamon $@ ;;
    "test" ) 	test_deamon ;;
    "setup" )	setup ;;
    "cleanup" )	cleanup ;;
    "log" )	log ;;
    * )        	usage 1 ;;
esac
exit $?



















version=0.1
verbose=
username="$CONFIG_SAMBA_TEST_USER"
password=
share="$CONFIG_SAMBA_TEST_SHARE"

run_command() {
	TEXT="$1"
	COMMAND="$2"
	rc_reset	
	echo -en "$TEXT "
	( ( eval "$COMMAND" > /dev/null 2>&1 ) > /dev/null 2>&1 ) > /dev/null 2>&1
	rc_status -v
	return $?
}


set_ldap_admin_password() {
	rc_reset	
	echo -en "Set the Samba Admin Password: "
	smbpasswd -w "$CONFIG_SAMBA_PROXY_USER_PASSWORD" > /dev/null 2>&1
	rc_status -v
	return $?
}

check_samba_users() {
	sambauser=$( echo "$CONFIG_SAMBA_PROXY_USER_CONTEXT" | sed -n "s|cn=\([^\.]*\).*|\1|pI" )

	rc_reset

	echo -n "Verify Samba Admin User ($sambauser) "
	( id $sambauser 2>&1 ) > /dev/null
	rc_status -v
	tmp=$?

	echo -n "Verify Samba Test User ($CONFIG_SAMBA_TEST_USER) "
	( id $CONFIG_SAMBA_TEST_USER 2>&1 ) > /dev/null
	rc_status -v
	tmp2=$?

	return $(( $tmp | $tmp2 ))
}

test_samba() {
	[ "$username" == "$CONFIG_SAMBA_TEST_USER" ] && password="$CONFIG_SAMBA_TEST_PASSWORD"

	if [ -n "$username" ] && [ -z "$password" ]; then
		verbose=1
		read -sp "Password for $username: " password; echo		
	fi

	[ "$verbose" == "1" ] && echo -e "Running the following command:\nsmbclient \"//$CONFIG_SAMBA_NETBIOS_NAME/$share\" -U \"$username\" -c \"exit\""

	rc_reset
	echo -en "Testing if $username can connect to //$CONFIG_SAMBA_NETBIOS_NAME/$share "
	test=$( smbclient "//$CONFIG_SAMBA_NETBIOS_NAME/$share" "$password" -U "$username" -c "exit" 2>&1 )
	rc_status -v
	status1=$?

	[ "$verbose" == "1" ] && echo "$test"
	[ "$status1" != "0" ] && verbose=1 && status
	return $status1
}

check_admin_login() {
	sambauser=$( echo "$CONFIG_SAMBA_PROXY_USER_CONTEXT" | sed -n "s|cn=\([^\.]*\).*|\1|pI" )
	sambaadmin=$( echo "$CONFIG_SAMBA_PROXY_USER_CONTEXT" | sed "s|\.|,|g" )
	sambacontext=$( echo "$CONFIG_SAMBA_DEFAULT_BASE_CONTEXT" | sed "s|\.|,|g" )

	rc_reset
	echo -en "Testing if $sambauser can authenticate to ldaps://$CONFIG_SAMBA_LDAP_SERVER "
	ldapsearch  -b "$sambacontext" -LLL -s "sub" -D "$sambaadmin" -h "$CONFIG_SAMBA_LDAP_SERVER" -w "$CONFIG_SAMBA_PROXY_USER_PASSWORD" -x -Z "(&(objectClass=person)(cn=$sambauser))" 1.1 > /dev/null 2>&1
	rc_status -v
	return $?
}

check_ldap_clear() {
	rc_reset
	echo -n "Checking Novell eDirectory LDAP Server is listening on the TCP port "
	nldap -c > /dev/null 2>&1
	rc_status -v
}

check_ldap_secure() {
	rc_reset
	echo -n "Checking Novell eDirectory LDAP Server is listening on the TLS port "
	nldap -s > /dev/null 2>&1
	rc_status -v
}





restart() {
	check_samba_users || $INITD_SCRIPT_LUM stop
	$0 kill
	$0 start
	return $?
}



status() {
	## Pass command lines parameters to INIT.D Script
	$INITD_SCRIPT_NMB status
	status1=$?			
	if ! $INITD_SCRIPT_SMB status || [ "$verbose" == "1" ]; then
		$INITD_SCRIPT_LUM status
		check_samba_users
		check_ldap_clear && check_ldap_secure && check_admin_login
	fi
	status2=$?	
	exit $(( $status1 | $status2 ))
}


usage() {
	[ "$2" == "" ] || echo -e "$2"
	echo -e "Usage: $0 [options] command"
	echo -e "Commands:  start    stop     status"
	echo -e "           restart  reload   setup"
	echo -e "           kill     log      cleanup"
	echo -e "Options:"
	echo -e " -v, --verbose   be verbose"	
	echo -e " -u, --username  username (default: $CONFIG_SAMBA_TEST_USER)"
	echo -e " -p, --password  password"
	echo -e " -s, --share     CIFS share (default: $CONFIG_SAMBA_TEST_SHARE)"
	echo -e " -h, --help      display this help and exit"
	echo -e " -V, --version   output version information and exit"
	exit ${1-0}
}
