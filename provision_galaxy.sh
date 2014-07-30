# DEBUG FLAG to facilitate pinpointing problems
# 0 = off, 1 = minimal, 2 = verbose
DEBUG=1

[[ $DEBUG -eq 2 ]] && set -x

[[ $DEBUG -eq 1 ]] && echo $@

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
		export GALAXY_USER=$OPTARG
	;;
	a)
		export GALAXY_PASSWORD=$OPTARG
	;;
	esac
done

# Validate that the username and password are set
if [[ -z "$GALAXY_USER" || -z "$GALAXY_PASSWORD" ]]; then
	echo "The GALAXY_USER and GALAXY_PASSWORD environment variables must be set before using vagrant up." 1>&2
	echo "Please export them from your .bashrc file or  set them in the ./config/config.yml" 1>&2

	exit 0
fi

# Parse the public id from e-mail by discarding the domain portion
IFS="@"
set -- $GALAXY_USER
if [ "${#@}" -ne 2 ];then
	echo "The GALAXY_USER parameter must be an e-mail address." 1>&2
	echo "$GALAXY_USER is invalid!" 1>&2
	exit 0
fi
GALAXY_PUBLICID="$1"

# Validate password is at least 6 characters
if [ $(echo ${#GALAXY_PASSWORD}) -lt 6 ]; then
	echo "The GALAXY_PASSWORD parameter must be 6 characters long." 1>&2
	exit 0
fi

# Update mercurial repository to latest version
echo "Adding mercurial PPA and updating Apt cache"
echo 'deb http://ppa.launchpad.net/mercurial-ppa/releases/ubuntu precise main' > /etc/apt/sources.list.d/mercurial-precise.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys f59ce3a8323293ee 2>/dev/null

apt-get update 1> /dev/null

# Install required software
echo "Installing software: mercurial, python, vim, bzip2"
apt-get -y install mercurial python vim bzip2  1> /dev/null

# Make the galaxy folder if it doesn't already exist
if [ -d "$GALAXYPATH" ]; then
	echo "Galaxy folder already exists: $GALAXYPATH"
	echo 'Ending provisioning to avoid clobbering data!'
	echo 'To re-provision, either remove the /galaxy folder within the VM or use "vagrant destroy".' 1>&2
	exit 0
else
	echo "Creating galaxy folder: $GALAXYPATH"
	mkdir -p "$GALAXYPATH"
fi

chown vagrant "$GALAXYPATH"

su vagrant << EOF

[[ $DEBUG -eq 2 ]] && set -x

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
tar xvf ${GALAXYRELEASE}.tar.bz2 1> /dev/null

echo "Moving extracted folder to $GALAXYPATH"
find . -type d -name "galaxy-galaxy-dist*" -exec cp -r '{}/.' "$GALAXYPATH/" \;
find . -type d -name "galaxy-galaxy-dist*" -exec rm -rf '{}' \;

cd "$GALAXYPATH"

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
PERL_COMMAND='s/^#?port\s*=.*$/port = '$GALAXYPORT
perl -p -i -e "$PERL_COMMAND" "$GALAXYPATH/universe_wsgi.ini"
PERL_COMMAND='s/^#?port\s*=.*$/port = '$TOOLSHEDPORT
perl -p -i -e "$PERL_COMMAND" "$GALAXYPATH/tool_shed_wsgi.ini"

# Set the GALAXY_USER as an admin in galaxy and the tool shed
echo " - setting the admin users parameter to $GALAXY_USER"
PERL_COMMAND='$user = "'$GALAXY_USER'"; $user =~ s/\@/\\\@/; s/^#?(admin_users\s*=.*)$/$1,$user/;'
perl -p -i -e "$PERL_COMMAND" "$GALAXYPATH/universe_wsgi.ini"
perl -p -i -e "$PERL_COMMAND" "$GALAXYPATH/tool_shed_wsgi.ini"

# Start galaxy & the tool shed
echo "Running Galaxy daemon"
sh run.sh --daemon --log-file=galaxy.log 1> /dev/null

echo "Running Galaxy Tool Shed"
sh run_tool_shed.sh &

EOF

echo "Registering Galaxy user $GALAXY_USER"
wget "http://$(hostname -s):$GALAXY_PORT/user/create?cntrller=user" --post-data="email=$GALAXY_USER&password=$GALAXY_PASSWORD&confirm=$GALAXY_PASSWORD&username=$GALAXY_PUBLICID&bear_field=&create_user_button=Submit"

echo "Galaxy setup completed successfully."
echo "To begin using galaxy, navigate to http://localhost/"
