#!/bin/bash
#
#     Wrapper startup script for freeradius
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
_this_conf=/etc/brandt/radius.conf
_this_script=/opt/brandt/init.d/oes/radius.sh
_this_rc=/usr/local/bin/rcbrandt-radius
_this_initd=/etc/init.d/brandt-radius
_this_cron=/etc/cron.hourly/radius-reload
_bin_radius=/usr/sbin/radiusd
_conf_radius=/etc/raddb/radiusd.conf
_initd_radius=/etc/init.d/freeradius

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
if [ ! -r "$_this_conf" ]; then
    ( echo -e "#     Configuration file for FreeRADIUS wrapper startup script"
	    echo -e "#     Bob Brandt <projects@brandt.ie>\n#"
   	  echo -e "_log_file=/var/log/messages"
   	  echo -e "_radius_sysconfig=/etc/sysconfig/brandtradius" ) > "$_this_conf"
	echo "Unable to find required file: $_this_conf" 1>&2
fi

. "$_brandt_utils"
. "$_this_conf"

if [ ! -r "$_radius_sysconfig" ]; then
    ( echo -e '## Path:    System/Yast2/brandt-radius'
      echo -e '## Description: Brandt Radius configuration (extra switch added by Bob Brandt (projects@brandt.ie)'
      echo -e '## Type:    yesno'
      echo -e '## Default: no\n#'
      echo -e '# Brandt RADIUS successfully configured\n#'
      echo -e 'SERVICE_CONFIGURED="yes"\n\n'
      echo -e '## Path:    System/Yast2/brandt-radius'
      echo -e '## Description: Brandt Radius configuration (extra switch added by Bob Brandt (projects@brandt.ie)'
      echo -e '## Type:    string'
      echo -e '## Default: none\n#'
      echo -e '# RADIUS User\n#'
      echo -e 'CONFIG_RADIUS_USER="radiusd"\n\n'
      echo -e '## Path:    System/Yast2/brandt-radius'
      echo -e '## Description: Brandt Radius configuration (extra switch added by Bob Brandt (projects@brandt.ie)'
      echo -e '## Type:    string'
      echo -e '## Default: none\n#'
      echo -e '# RADIUS Group\n#'
      echo -e 'CONFIG_RADIUS_GROUP="radiusd"\n\n'
      echo -e '## Path:    System/Yast2/brandt-radius'
      echo -e '## Description: Brandt Radius configuration (extra switch added by Bob Brandt (projects@brandt.ie)'
      echo -e '## Type:    string'
      echo -e '## Default: none\n#'
      echo -e '# RADIUS Secret\n#'
      echo -e 'CONFIG_RADIUS_SECRET="opwradius"\n\n'
      echo -e '## Path:    System/Yast2/brandt-radius'
      echo -e '## Description: Brandt Radius configuration (extra switch added by Bob Brandt (projects@brandt.ie)'
      echo -e '## Type:    string'
      echo -e '## Default: none\n#'
      echo -e '# RADIUS Short Name\n#'
      echo -e 'CONFIG_RADIUS_SHORTNAME="opw"\n\n'
      echo -e '## Path:    System/Yast2/brandt-radius'
      echo -e '## Description: Brandt Radius configuration (extra switch added by Bob Brandt (projects@brandt.ie)'
      echo -e '## Type:    string'
      echo -e '## Default: none\n#'
      echo -e '# RADIUS LDAP User\n#'
      echo -e 'CONFIG_RADIUS_LDAP_USER="cn=radiusadmin.ou=remoteaccess.o=opw"\n\n'
      echo -e '## Path:    System/Yast2/brandt-radius'
      echo -e '## Description: Brandt Radius configuration (extra switch added by Bob Brandt (projects@brandt.ie)'
      echo -e '## Type:    string'
      echo -e '## Default: none\n#'
      echo -e '# RADIUS LDAP User Password\n#'
      echo -e 'CONFIG_RADIUS_LDAP_PASSWORD="R@d1us@dmin"\n\n'
      echo -e '## Path:    System/Yast2/brandt-radius'
      echo -e '## Description: Brandt Radius configuration (extra switch added by Bob Brandt (projects@brandt.ie)'
      echo -e '## Type:    string'
      echo -e '## Default: none\n#'
      echo -e '# RADIUS Test User\n#'
      echo -e 'CONFIG_RADIUS_TEST_USER="radiustest"\n\n'
      echo -e '## Path:    System/Yast2/brandt-radius'
      echo -e '## Description: Brandt Radius configuration (extra switch added by Bob Brandt (projects@brandt.ie)'
      echo -e '## Type:    string'
      echo -e '## Default: none\n#'
      echo -e '# RADIUS Test User Password\n#'
      echo -e 'CONFIG_RADIUS_TEST_PASSWORD="R@d1usT3st"\n\n'
      echo -e '## Path:    System/Yast2/brandt-radius'
      echo -e '## Description: Brandt Radius configuration (extra switch added by Bob Brandt (projects@brandt.ie)'
      echo -e '## Type:    string'
      echo -e '## Default: none\n#'
      echo -e '# RADIUS Test Reply Message\n#'
      echo -e 'CONFIG_RADIUS_TEST_REPLYMSG="You did not match a Radius Group."\n\n'
      echo -e '## Path:    System/Yast2/brandt-radius'
      echo -e '## Description: Brandt Radius configuration (extra switch added by Bob Brandt (projects@brandt.ie)'
      echo -e '## Type:    string'
      echo -e '## Default: none\n#'
      echo -e '# RADIUS Test VLAN\n#'
      echo -e 'CONFIG_RADIUS_TEST_VLAN="99"\n\n' ) > "$_radius_sysconfig"
    echo "Unable to find required file: $_radius_sysconfig" 1>&2
fi

. "$_radius_sysconfig"

function installed() {
    brandt_deamon_wrapper "FreeRADIUS daemon" "$_bin_radius" installed
	return $?
}

function configured() {
    brandt_deamon_wrapper "FreeRADIUS daemon" "$_conf_radius" configured
	return $?
}

function kill_deamon() {
	if pgrep "radiusd" 2>&1 > /dev/null
	then
		while pgrep "radiusd" 2>&1 > /dev/null
		do
			sleep 1
			brandt_deamon_wrapper "FreeRADIUS daemon" "$_initd_radius" kill
		done
		/bin/true
	fi
	return $?
}

function test_deamon() {
	local _status=0

	[ "$_username" == "$CONFIG_RADIUS_TEST_USER" ] && _password="$CONFIG_RADIUS_TEST_PASSWORD"

	if [ -n "$_username" ] && [ -z "$_password" ]; then
		_verbose=1
		read -sp "Password for $_username: " _password; echo		
	fi

	echo -n "Testing the RADIUS Authentication ($_username) "
    tmp=$( echo "User-Name=$_username,CHAP-Password=$_password" | radclient localhost auth $CONFIG_RADIUS_SECRET 2>&1 )    
    brandt_status status
    _status=$?	
    if [ "$_verbose" == "1" ]; then
        echo -e "Running the following command:\necho \"User-Name=$_username,CHAP-Password=**********\" | radclient localhost auth $CONFIG_RADIUS_SECRET"
        echo "Testing the RADIUS Configuration ($_username)"
        echo "$tmp"
    fi

	if [ "$_username" == "$CONFIG_RADIUS_TEST_USER" ]; then
		echo -n "Testing the RADIUS Response ($_username) "
        ReplyMessage=$( echo $tmp | sed -e "s|.*Reply-Message[^\"]*\"||I" -e "s|\".*||" )
        VLAN=$( echo $tmp | sed -e "s|.*Tunnel-Private-Group-Id[^\"]*\"||I" -e "s|\".*||" )
        test "$ReplyMessage" == "$CONFIG_RADIUS_TEST_REPLYMSG" && test "$VLAN" == "$CONFIG_RADIUS_TEST_VLAN"
        brandt_status status
        _status=$(( $_status | $? ))
	fi
	exit $_status
}

function setup_cron_job() {
	echo -en "Setup RADIUS Test cron job "
	( echo -e "#!/bin/bash\n$_this_script test\nexit $?\n" > "$_this_cron" && chownmod -Rf root:root 544 "$_this_cron" ) > /dev/null 2>&1
	brandt_status setup
	return $?
}

function setup() {
    local _status=0 
    ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
    ln -sf "$_this_script" "$_this_initd" > /dev/null 2>&1
    _status=$?

    # chkconfig freeradius on && chkconfig freeradius 35
    # _status=$(( $_status | $? ))
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
	  echo -e "Commands:  start    stop     status"
	  echo -e "           restart  reload   force-reload"
	  echo -e "           debug    follow   setup"
	  echo -e "           kill     test"
	  echo -e "Options:"
      echo -e " -q, --quiet    be quiet"
      echo -e " -V, --verbose  be verbose"
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
_verbose=2
_username="$CONFIG_RADIUS_TEST_USER"
_password="$CONFIG_RADIUS_TEST_PASSWORD"
while /bin/true ; do
    case "$1" in
        -q | --quiet )     _quiet=2 && _verbose=2;;
        -V | --verbose )   _quiet=1 && _verbose=1;;
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
    "start" | "stop" | "status" | "restart" | "try-restart" | "force-reload" | "reload" | "reload" | "force-reload" | "probe" | "check-syntax" | "kill" )
    				brandt_deamon_wrapper "FreeRADIUS daemon" "$_initd_radius"  $_command $@ ;;
    "debug" )		## Run radiusd in Debug Mode
    				brandt_deamon_wrapper "FreeRADIUS daemon" "$_initd_radius"  kill
					$_bin_radius -X
					;;
    "follow" )		brandt_deamon_wrapper "FreeRADIUS daemon" "$_initd_radius"  restart
					_syslog=$( sed -n "s|^\s*destination.*=\s*||p" $_conf_radius | sed "s|\s*$||" )
					if [ "$_syslog" == "syslog" ]; then 
						tail -F $_log_file | grep "radiusd"
					else
						_log_file=`sed -n "s|^_log_file.*=\s*||p" $_conf_radius | sed "s|\s*$||"`
						tail -F $_log_file
					fi
					;;		
    "setup" )		setup ;;
	"test" )		test_deamon ;;
    * )        		usage 1 ;;
esac
exit $?
