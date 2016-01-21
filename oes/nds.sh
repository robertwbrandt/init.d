#!/bin/bash
#
#     Wrapper startup script for eDirectory (NDS)
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
_brandt_utils=/opt/brandt/brandt-utils.sh
_this_script=/opt/brandt/init.d/oes/nds.sh
_this_rc=/usr/local/bin/rcbrandt-nds
_bin_nds=/opt/novell/eDirectory/sbin/ndsd
_conf_nds=/etc/opt/novell/eDirectory/conf/nds.conf
_initd_nds=/etc/init.d/ndsd
_ldap_sysconfig=/etc/sysconfig/novell/oes-ldap

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
. "$_brandt_utils"
[ ! -r "$_ldap_sysconfig" ] && echo "Unable to find required file: $_ldap_sysconfig" 1>&2 && exit 6
. "$_ldap_sysconfig"

_nds_ip=$( sed -n "s|n4u.server.interfaces\s*=\s*||pI" "$_conf_nds" | sed "s|@.*||" )
_nds_context=$( sed -n "s|n4u.nds.server-context\s*=\s*||pI" "$_conf_nds" )

function installed() {
    brandt_deamon_wrapper "eDirectory for Linux daemon" "$_bin_nds" installed	
	return $?
}

function configured() {
    brandt_deamon_wrapper "eDirectory for Linux daemon" "$_conf_nds" configured	
	return $?
}

function status() {
	local _status=0	
	if [ "$_quiet" == "1" ]; then
		$_initd_nds status
		_status=$(( $_status | $? ))
		echo "Checking Novell eDirectory LDAP Server is listening on the TCP port "
		nldap -c
		_status=$(( $_status | $? ))
		echo "Checking Novell eDirectory LDAP Server is listening on the TLS port "
		nldap -s
		_status=$(( $_status | $? ))		
	else
		echo -n "Checking for eDirectory for Linux daemon "
		/sbin/checkproc $_bin_nds
		if brandt_status status
		then
			_status=$(( $_status | $? ))

			_nds_context_ldap=$( convertContext "ldap" "$_nds_context" )
			echo -n "Checking Novell eDirectory LDAP Server is listening on the TCP port "
			nldap -c > /dev/null 2>&1
			if brandt_status status
			then 
				echo -n "Verifying LDAP server responds on clear port "
				ldapsearch -h "$_nds_ip" -x -b "$_nds_context_ldap" -LLL "(objectClass=ncpServer)" "1.1" > /dev/null 2>&1
				brandt_status status
			fi

			echo -n "Checking Novell eDirectory LDAP Server is listening on the TLS port "
			nldap -c > /dev/null 2>&1
			if brandt_status status
			then 
				echo -n "Verifying LDAP server responds on secure port "
				ldapsearch -h "$_nds_ip" -x -Z -b "$_nds_context_ldap" -LLL "(objectClass=ncpServer)" "1.1" > /dev/null 2>&1
				brandt_status status
			fi
		fi
	fi
	return $(( $_status | $? ))
}
function setup() {
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
	return $?
}

function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( echo -e "Usage: $0 [options] command"
	  echo -e "Commands:  start     stop     status"
	  echo -e "           restart   reload"
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
	exit $?
fi

# Check to see if user is root, if not re-run script as root.
brandt_amiroot || { echo "${BOLD_RED}This program must be run as root!${NORMAL}" >&2 ; sudo "$0" $@ ; exit $?; }

case "$_command" in
	"start" | "stop" | "restart" | "reload" )
			    brandt_deamon_wrapper "eDirectory for Linux daemon" "$_initd_nds" "$_command" $@ ;;	
	"status" ) 	status "$_quiet" ;;
    "setup" )	setup ;;
    * )        	usage 1 ;;
esac
exit $?
