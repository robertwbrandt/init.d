#!/bin/bash
#
#     Wrapper startup script for the nfsserver init.d script
#     Bob Brandt <projects@brandt.ie>
#          
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
_this_script=/opt/brandt/init.d/oes/nfs.sh
_this_rc=/usr/local/bin/rcbrandt-nfs
_this_cron=/etc/cron.weekly/nfs-reload
_bin_nfs=/usr/sbin/exportfs
_initd_nfs=/etc/init.d/nfsserver
_nfs_sysconfg=/etc/sysconfig/nfs
_nfs_defaults="*(rw,sync,root_squash)"

[ ! -r "$_brandt_utils" ] && echo "Unable to find required file: $_brandt_utils" 1>&2 && exit 6
. "$_brandt_utils"
[ ! -r "$_nfs_sysconfg" ] && echo "Unable to find required file: $_nfs_sysconfg" 1>&2 && exit 6
. "$_nfs_sysconfg"


function installed() {
    brandt_deamon_wrapper "NFS Server daemon" "$_bin_nfs" installed
	return $?
}

function configured() {
    brandt_deamon_wrapper "NFS Server daemon" "$_nfs_sysconfg" configured
	return $?
}

function nfsexport_ncpvolumes() {
	for location in `grep "^VOLUME" /etc/opt/novell/ncpserv.conf`; do
		if [[ ${location:0:1} == "/" ]] && [ -d "$location" ]; then
			if ! grep "^$location" /etc/exports > /dev/null; then
				echo -n "Adding export information for $location "
				echo -e "$location\t$_nfs_defaults" >> /etc/exports
				brandt_status setup
			fi
		fi
	done
}

function nfsexport_sambashares() {
	for location in `grep -v "^#"  /etc/samba/smb.conf | grep "path = /"`; do
		if [[ ${location:0:1} == "/" ]] && [ -d "$location" ]; then
			if ! grep "^$location" /etc/exports > /dev/null; then
				echo -n "Adding export information for $location "
				echo -e "$location\t$_nfs_defaults" >> /etc/exports
				brandt_status setup				
			fi
		fi
	done
}

function setup_cron_job() {
	echo -en "Setup NFS Export reload cron job "
	( echo -e "#!/bin/bash\n$_this_script test\nexit $?\n" > "$_this_cron" && chownmod -Rf root:root 544 "$_this_cron" ) > /dev/null 2>&1
	brandt_status setup
	return $?
}

function setup() {
	ln -sf "$_this_script" "$_this_rc" > /dev/null 2>&1
	_status=$?
}

function usage() {
	local _exitcode=${1-0}
	local _output=2
	[ "$_exitcode" == "0" ] && _output=1
	[ "$2" == "" ] || echo -e "$2"
	( echo -e "Usage: $0 [options] command"
	  echo -e "Commands:  start     stop     status"
	  echo -e "           restart   reload   setup"
	  echo -e "           force-reload"
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
	"start" | "stop" | "restart" | "try-restart" | "status" )
			    brandt_deamon_wrapper "NFS Server daemon" "$_initd_nfs" "$_command"  $@ ;;
	"force-reload" | "reload" )
				## Do something before passing parameters to INIT.D Script
				nfsexport_ncpvolumes
				nfsexport_sambashares
				## Pass command lines parameters to INIT.D Script
			    brandt_deamon_wrapper "NFS Server daemon" "$_initd_nfs" "$_command"  $@ ;;
    "setup" )	setup ;;
    * )        	usage 1 ;;
esac
exit $?
