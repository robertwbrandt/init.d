#!/bin/bash
#
#     Wrapper startup script for NAM deamon
#     Bob Brandt <projects@brandt.ie>
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
_this_script=/opt/brandt/init.d/oes/lum.sh
_this_rc=/usr/local/bin/rcbrandt-lum
_this_cron=/etc/cron.hourly/lum-reload

_bin_lum=/usr/sbin/namcd
_conf_lum=/etc/nam.conf
_initd_lum=/etc/init.d/namcd
_lum_sysconfig=/etc/sysconfig/novell/lum2_sp2
_nds_conf=/etc/opt/novell/eDirectory/conf/nds.conf

[ -f "$_lum_sysconfig" ] || _lum_sysconfig=/etc/sysconfig/novell/lum2_sp3

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
. "$_brandt_utils"
[ ! -r "$_lum_sysconfig" ] && echo "Unable to find required file: $_lum_sysconfig" 1>&2 && exit 6
. "$_lum_sysconfig"


function installed() {
    brandt_deamon_wrapper "Novell LUM NAMCD daemon" "$_bin_lum" installed
	return $?
}

function configured() {
	local _status=0
    brandt_deamon_wrapper "Novell NDS daemon" "$_nds_conf" configured
	_status=$(( $_status | $? ))
    brandt_deamon_wrapper "Novell LUM NAMCD daemon" "$_conf_lum" configured
	return $(( $_status | $? )) 
}

function get_defaults() {
	NDSSERVERCONTEXT=$( lower $( sed -n "s|n4u.nds.server-context\s*=\s*||pI" "$_nds_conf" ) )
	NDSBASE=$( lower $( echo "$NDSSERVERCONTEXT" | sed "s|.*\.\s*||" ) )
	TMP_HOSTNAME=$( lower "${HOSTNAME:0:11}" )
	TMP_PROPER_HOSTNAME=$( proper "$TMP_HOSTNAME" )

	SERVICE_CONFIGURED=${SERVICE_CONFIGURED:="yes"}

	CONFIG_LUM_LDAP_SERVER=$( lower ${CONFIG_SAMBA_LDAP_SERVER:="127.0.0.1"} )
	CONFIG_LUM_INTERFACE=$( lower ${CONFIG_SAMBA_INTERFACE:=""} )
	CONFIG_LUM_NETBIOS_NAME=$( lower ${CONFIG_SAMBA_NETBIOS_NAME:="$TMP_HOSTNAME-pdc"} )
	CONFIG_LUM_WORKGROUP_NAME=$( lower ${CONFIG_SAMBA_WORKGROUP_NAME:="$TMP_HOSTNAME-dom"} )
	CONFIG_LUM_SERVER_STRING=${CONFIG_SAMBA_SERVER_STRING:="$TMP_PROPER_HOSTNAME PDC Server (Samba %v)"}
	CONFIG_LUM_SID=$( upper ${CONFIG_SAMBA_SID:="S-1-5-21-0-0-0"} )
	CONFIG_LUM_ALGORITHMIC_RID_BASE=${CONFIG_SAMBA_ALGORITHMIC_RID_BASE:="1000"}
	CONFIG_LUM_LUM_CONTEXT=$( lower ${CONFIG_SAMBA_LUM_CONTEXT:="$CONFIG_LUM_WS_CONTEXT"} )
	CONFIG_LUM_SERVER_CONTEXT=$( lower ${CONFIG_EDIR_SERVER_CONTEXT:="$NDSSERVERCONTEXT"} )
	CONFIG_LUM_USER_CONTEXT=$( lower ${CONFIG_SAMBA_USER_CONTEXT:="$NDSBASE"} )
	CONFIG_LUM_DEFAULT_BASE_CONTEXT=$( lower ${CONFIG_SAMBA_DEFAULT_BASE_CONTEXT:="OU=Samba.$CONFIG_EDIR_SERVER_CONTEXT"} )
	CONFIG_LUM_PROXY_USER_CONTEXT=$( lower ${CONFIG_SAMBA_PROXY_USER_CONTEXT:="CN=SambaAdmin.$CONFIG_SAMBA_DEFAULT_BASE_CONTEXT"} )
	CONFIG_LUM_PROXY_USER_PASSWORD=${CONFIG_SAMBA_PROXY_USER_PASSWORD:="$defaultsambapasswd"}
	CONFIG_LUM_GROUP_CONTEXT=$( lower ${CONFIG_SAMBA_GROUP_CONTEXT:=$( echo "$CONFIG_EDIR_SERVER_CONTEXT" | sed "s|\.\s*$CONFIG_SAMBA_USER_CONTEXT||I" )} )
	CONFIG_LUM_MACHINE_CONTEXT=$( lower ${CONFIG_SAMBA_MACHINE_CONTEXT:=$( echo "$CONFIG_SAMBA_DEFAULT_BASE_CONTEXT" | sed "s|\.\s*$CONFIG_SAMBA_USER_CONTEXT||	I" )} )
	CONFIG_LUM_DOMAIN_ADMINS_GROUP_CONTEXT=$( lower ${CONFIG_SAMBA_DOMAIN_ADMINS_GROUP_CONTEXT:="CN=Domain Admins.$CONFIG_SAMBA_DEFAULT_BASE_CONTEXT"} )
	CONFIG_LUM_DOMAIN_USERS_GROUP_CONTEXT=$( lower ${CONFIG_SAMBA_DOMAIN_USERS_GROUP_CONTEXT:="CN=Domain Users.$CONFIG_SAMBA_DEFAULT_BASE_CONTEXT"} )
	CONFIG_LUM_DOMAIN_GUESTS_GROUP_CONTEXT=$( lower ${CONFIG_SAMBA_DOMAIN_GUESTS_GROUP_CONTEXT:="CN=Domain Guests.$CONFIG_SAMBA_DEFAULT_BASE_CONTEXT"} )
	CONFIG_LUM_DOMAIN_COMPUTERS_GROUP_CONTEXT=$( lower ${CONFIG_SAMBA_DOMAIN_COMPUTERS_GROUP_CONTEXT:="CN=Domain Computers.$CONFIG_SAMBA_DEFAULT_BASE_CONTEXT"} )
	CONFIG_LUM_TEST_USER=$( lower ${CONFIG_SAMBA_TEST_USER:="scanner"} )
	CONFIG_LUM_TEST_PASSWORD=${CONFIG_SAMBA_TEST_PASSWORD:="scanner"}
	CONFIG_LUM_TEST_SHARE=$( lower ${CONFIG_SAMBA_TEST_SHARE:="scanner$"} )
}


# base-name=o=opw
# admin-fdn=cn=brandtb,ou=it,o=opw
# num-threads=10
# schema=rfc2307
# enable-persistent-cache=yes
# user-hash-size=211
# group-hash-size=211
# persistent-cache-refresh-period=28800
# persistent-cache-refresh-flag=all
# create-home=yes
# ldap-port=389
# support-alias-name=no
# support-outside-base-context=yes
# cache-only=no
# persistent-search=yes
# case-sensitive=no
# convert-lowercase=no

# preferred-server=127.0.0.1
# alternative-ldap-server-list=10.200.200.2,10.200.200.1,10.201.200.1
# type-of-authentication=2
# certificate-file-type=der
# ldap-ssl-port=636





function verify_info() {
	echo -e "\n\nWe are about to use this information for the Novell LUM Setup."
	echo -e "\tRoot Partition = $CONFIG_LUM_PARTITION_ROOT"
	echo -e "\tPreferred Server = $CONFIG_LUM_LDAP_SERVER"
	echo -e "\tAlternate LDAP Servers = $alternative-ldap-server-list"
	echo -e "\tLDAP Port = $ldap-port"
	echo -e "\tLDAP SSL Port = $ldap-ssl-port"
	echo -e "\tCertificate File Type= $certificate-file-type"
	echo -e "\tAdministrator FQDN = $admin-fdn"

	echo -e "\tNumber of Threads = $num-threads"
	echo -e "\tSchema RFC = $schema"
	echo -e "\tUser Hash Size = $user-hash-size"
	echo -e "\tGroup Hash Size = $group-hash-size"
	echo -e "\tPersistant Cache = $enable-persistent-cache"
	echo -e "\tPersistant Cache Refresh Period (s) = $persistent-cache-refresh-period"
	echo -e "\tPersistant Cache Refresh Flag = $persistent-cache-refresh-flag"
	echo -e "\tCreate Home Directory = $create-home"
	echo -e "\tSupport Alias Name = $support-alias-name"
	echo -e "\tSupport Outside Base Context = $support-outside-base-context"
	echo -e "\tCache Only = $cache-only"
	echo -e "\tPersistant Search = $persistent-search"
	echo -e "\tCase Sensitive = $case-sensitive"
	echo -e "\tConvert to Lowercase = $convert-lowercase"
	echo -e "\tType of Authentication = $type-of-authentication"

	ANSWER=$( brandt_get_input "Is this information correct? (yes/No/exit)" "n" "lower" )
	ANSWER=${ANSWER:0:1}
}

function setup_cron_job() {
	echo -en "Setup LUM NAMCD reload cron job "
	( echo -e "#!/bin/bash\n$_this_script reload\nexit $?\n" > "$_this_cron" && chownmod -Rf root:root 544 "$_this_cron" ) > /dev/null 2>&1
	brandt_status setup
	return $?
}

function setup() {
	local _status=0	
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
	setup_cron_job
	_status=$(( $_status | $? ))

	get_defaults
	ANSWER="n"
	while [ "$ANSWER" != "y" ]; do
		verify_info
		test "$ANSWER" == "e" && return 1
		test "$ANSWER" == "x" && return 1
		test "$ANSWER" == "n" && get_info
	done

	return $_status
}

function namconfig_cache_refresh() {
	echo -n "Refresh NAM Cache "
	/usr/bin/namconfig cache_refresh > /dev/null 2>&1
	brandt_status installed
	return $?
}

function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( echo -e "Usage: $0 [options] command"
	  echo -e "Commands:  start     stop     status"
	  echo -e "           restart   reload   setup"
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
    "refresh" | "reload" | "cache" )
				namconfig_cache_refresh ;;
	"start" | "stop" | "status" | "restart" )
    			brandt_deamon_wrapper "Novell LUM NAMCD daemon" "$_initd_lum" "$_command" $@ ;;
#	"test" )	test_deamon ;;
    "setup" )	setup ;;
    * )        	usage 1 ;;
esac
exit $?
