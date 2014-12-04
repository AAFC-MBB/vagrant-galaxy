# DEBUG FLAG to facilitate pinpointing problems
# 0 = off, 1 = minimal, 2 = verbose
_DEBUG=1
function DEBUG(){
	[ "$_DEBUG" == "1" ] && $@
	[ "$_DEBUG" == "2" ] && set -x; $@; set +x
}

export LOGFILE=/dev/null

echo $LOGFILE

DEBUG echo "$@"

# Get the directory, which contains all the other scripts
scriptdir=`dirname "$0"`

# Load options from command line
while getopts p:c:s:r:o:t:u:a: opt; do
	case $opt in
	p)
		export GALAXYPATH=$OPTARG
	;;
	c)
		export CONFIGPATH=$OPTARG
	;;
	s)
		export GALAXYREPO=$OPTARG
	;;
	r)
		export GALAXYRELEASE=$OPTARG
	;;
	o)
		export GALAXYPORT=$OPTARG
	;;
	t)
		export TOOLSHEDPORT=$OPTARG
	;;
	u)
		export GALAXYUSER=$OPTARG
	;;
	i)
		export GALAXYPUBLICID=$OPTARG
	;;
	a)
		export GALAXYPASSWORD=$OPTARG
	;;
	esac
done

# Validate that the username and password are set
if [[ -z "$GALAXYUSER" || -z "$GALAXYPASSWORD" ]]; then
	echo "The GALAXY_USER and GALAXY_PASSWORD environment variables must be set before using vagrant up." 1>&2
	echo "Please export them from your .bashrc file or  set them in the ./config/config.yml" 1>&2

	exit 0
fi

# Parse the public id from e-mail by discarding the domain portion
IFS="@"
set -- $GALAXYUSER
if [ "${#@}" -ne 2 ];then
	echo "The GALAXY_USER parameter must be an e-mail address." 1>&2
	echo "$GALAXYUSER is invalid!" 1>&2
	exit 0
fi

# Validate password is at least 6 characters
if [ $(echo ${#GALAXYPASSWORD}) -lt 6 ]; then
	echo "The GALAXY_PASSWORD parameter must be 6 characters long." 1>&2
	exit 0
fi

# Install some essentials in the vm
#"$scriptdir/install_software.sh"

# Setup Galaxy parameters
#"$scriptdir/setup_galaxy.sh"
