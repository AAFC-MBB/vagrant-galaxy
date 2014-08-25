# DEBUG FLAG to facilitate pinpointing problems
# 0 = off, 1 = minimal, 2 = verbose
_DEBUG=1
function DEBUG(){
	[ "$_DEBUG" == "1" ] && $@
	[ "$_DEBUG" == "2" ] && set -x; $@; set +x
}

export LOGFILE=/dev/null

DEBUG echo "$@"

# Load options from command line
# TODO: add validation to options
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

echo "Updating apt repository cache"
apt-get -y -q update 1>$LOGFILE

echo "Installing python, vim, bzip2, python-software-properties"
apt-get -y -q install python vim bzip2 python-software-properties 1>$LOGFILE


# Update mercurial repository to latest version
echo "Adding mercurial PPA and updating apt repository cache"
add-apt-repository -y ppa:mercurial-ppa/releases 2>&1 1>$LOGFILE
apt-get -y -q update 1> /dev/null

# Install required software
echo "Installing mercurial from PPA"
#apt-get -y -q install mercurial 1>$LOGFILE

# Make the galaxy folder if it doesn't already exist
if [ -d "$GALAXYPATH" ]; then
	echo "Galaxy folder already exists: $GALAXYPATH"
	echo 'Ending provisioning to avoid clobbering data!'
	echo 'To re-provision, either remove the /galaxy folder within the VM or use "vagrant destroy".' 1>&2
	exit 0
else
	echo "Creating galaxy folder: $GALAXYPATH"
	mkdir "$GALAXYPATH"
fi

chown vagrant.vagrant "$GALAXYPATH"

su vagrant << EOF
# Change directory to avoid specifying paths in other commands
cd /vagrant/

# Download the target release if it doesn't exist
if [ ! -f $GALAXYRELEASE.tar.bz2 ]; then
	# Get galaxy
	echo "Downloading Galaxy $GALAXYRELEASE: $GALAXYREPO/get/$GALAXYRELEASE.tar.bz2"
	wget $GALAXYREPO/get/$GALAXYRELEASE.tar.bz2
else
	echo "$GALAXYRELEASE.tar.bz2 already exists - skipping download."
fi

echo "Extracting $GALAXYRELEASE.tar.bz2"
tar xvf ${GALAXYRELEASE}.tar.bz2 1>$LOGFILE

echo "Moving extracted folder to $GALAXYPATH"
find . -type d -name "galaxy-galaxy-dist*" -exec cp -r '{}/.' "$GALAXYPATH/" \;
find . -type d -name "galaxy-galaxy-dist*" -exec rm -rf '{}' \;

cd "$GALAXYPATH"

chmod u+x run_tool_shed.sh

# Configure galaxy
echo "Configuring Galaxy"
cp -r "$CONFIGPATH/." "$GALAXYPATH/"

# Avoid storing cached eggs in Vagrant home folder
echo " - modifying location of egg cache"
mkdir 'egg-cache'
export PYTHON_EGG_CACHE="$GALAXYPATH/egg-cache"
echo "export PYTHON_EGG_CACHE=$GALAXYPATH/egg-cache" >> ~/.bashrc

# Change the ports in the configuration accordingly
echo " - modifying Galaxy and Tool Shed ports to $GALAXYPORT and $TOOLSHEDPORT, respectively."
perl -p -i -e 's/^#?port\s*=.*$/port = '$GALAXYPORT'/' "$GALAXYPATH/universe_wsgi.ini"
perl -p -i -e 's/^#?port\s*=.*$/port = '$TOOLSHEDPORT'/' "$GALAXYPATH/tool_shed_wsgi.ini"

# Set the GALAXYUSER as an admin in galaxy and the tool shed
echo " - setting the admin users parameter to $GALAXYUSER"
PERL_COMMAND='$user = "'$GALAXYUSER'"; $user =~ s/\@/\\\@/; s/^#?(admin_users\s*=.*)$/$1,$user/;'
perl -p -i -e "$PERL_COMMAND" "$GALAXYPATH/universe_wsgi.ini"
perl -p -i -e "$PERL_COMMAND" "$GALAXYPATH/tool_shed_wsgi.ini"

# Start galaxy & the tool shed
echo "Running Galaxy daemon"
sh run.sh --daemon --log-file=galaxy.log 1>$LOGFILE

echo "Running Galaxy Tool Shed"
sh run_tool_shed.sh --daemon 1>$LOGFILE

EOF

#Wait for the eggs to finish downloading and galaxy to start before trying to connect
sleep 10

echo "Registering Galaxy user $GALAXYUSER"
wget --retry-connrefused --waitretry=5 --tries=20 --output-file="$LOGFILE" --output-document="$GALAXYPATH/register_user_toolshed" --post-data="email=$GALAXYUSER&password=$GALAXYPASSWORD&confirm=$GALAXYPASSWORD&username=$GALAXYPUBLICID&bear_field=&create_user_button=Submit" "http://localhost:$TOOLSHEDPORT/user/create?cntrller=user"
wget --retry-connrefused --waitretry=5 --tries=20 --output-file="$LOGFILE" --output-document="$GALAXYPATH/register_user_galaxy" --post-data="email=$GALAXYUSER&password=$GALAXYPASSWORD&confirm=$GALAXYPASSWORD&username=$GALAXYPUBLICID&bear_field=&create_user_button=Submit" "http://localhost:$GALAXYPORT/user/create?cntrller=user"

echo "Galaxy setup completed successfully."
echo "To begin using galaxy, navigate to http://localhost:$GALAXYPORT/.  Your username and password are '$GALAXYUSER' and '$GALAXYPASSWORD'"
echo "To access the tool shed, navigate to http://localhost:$TOOLSHEDPORT/.  The credentials are the same as the above."
