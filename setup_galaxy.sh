#get options

# Load options from command line
while getopts p:s:r:o:t:u:i:a: opt; do
	case $opt in
	p)
		export GALAXYPATH=$OPTARG
	;;
#	c)
#		export CONFIGPATH=$OPTARG
#	;;
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

export LOGFILE=/dev/null

#sudo mkdir -p "$GALAXYPATH"
sudo chown vagrant.vagrant "$GALAXYPATH"

#su vagrant <<'EOF'
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
find . -depth -type d -name "galaxy-galaxy-dist*" -exec rm -rf '{}' \;

cd "$GALAXYPATH"

# Locate the sample configuration files as they get moved depending on the galaxy version
GALAXYCONFSAMPLE=$(find "$GALAXYPATH" -name "universe_wsgi.ini.sample" -or -name "galaxy.ini.sample")
if [[ -z $GALAXYCONFSAMPLE ]]; then
	echo "Failed to locate Galaxy's configuration file - galaxy.ini.sample or universe_wsgi.ini.sample ." 1>&2
	exit 1
fi

TSCONFSAMPLE=$(find "$GALAXYPATH" -name "tool_shed_wsgi.ini.sample" -or -name "tool_shed.ini.sample")
if [[ -z $TSCONFSAMPLE ]]; then
	echo "Failed to locate the tool shed configuration file - tool_shed_wsgi.ini.sample or tool_shed.ini.sample ." 1>&2
	exit 1
fi

GALAXYCONF=${GALAXYCONFSAMPLE%.sample}
TSCONF=${TSCONFSAMPLE%.sample}

# Create the configuration files from the provided samples
cp "$GALAXYCONFSAMPLE" "$GALAXYCONF"
cp "$TSCONFSAMPLE" "$TSCONF"

# The run tool shed script must be executable for the fab commands to work
chmod u+x run_tool_shed.sh

# Avoid storing cached eggs in Vagrant home folder
echo " - modifying location of egg cache"
mkdir 'egg-cache'
export PYTHON_EGG_CACHE="$GALAXYPATH/egg-cache"
echo "export PYTHON_EGG_CACHE=$GALAXYPATH/egg-cache" >> ~/.bashrc

# Change the tool dependency directory
echo " - modifying Galaxy's tool depedency directory to $GALAXYPATH/tool-dep"
perl -p -i -e 's#^\#?tool_dependency_dir\s*=.*$#tool_dependency_dir = $GALAXYPATH/tool-dep#' "$GALAXYCONF"

# Change the default interface that Galaxy binds to 0.0.0.0
# restrict context to first 40 or 20 lines as a hack to keep within the [server:main] section
echo " - modifying Galaxy and tool Shed interface bindings"
perl -p -i -e 's/^#?host\s=.*$/host = 0.0.0.0/ if 1 .. 40' "$GALAXYCONF"
# tool_shed_wsgi.ini.sample has host twice, once commented out and once not;
# update the uncommented version
perl -p -i -e 's/^host\s=.*$/host = 0.0.0.0/ if 1 .. 20' "$TSCONF"

# Change the ports in the configuration accordingly
# restrict context to first 40 or 20 lines as a hack to keep within the [server:main] section
echo " - modifying Galaxy and Tool Shed ports to $GALAXYPORT and $TOOLSHEDPORT, respectively."
perl -p -i -e 's/^#?port\s*=.*$/port = '$GALAXYPORT'/ if 1 .. 40' "$GALAXYCONF"
perl -p -i -e 's/^#?port\s*=.*$/port = '$TOOLSHEDPORT'/ if 1 .. 20' "$TSCONF"

# Set the GALAXYUSER as an admin in galaxy and the tool shed
echo " - setting the admin users parameter to $GALAXYUSER"
PERL_COMMAND='$user = "'$GALAXYUSER'"; $user =~ s/\@/\\\@/; s/^#?(admin_users\s*=\s*)$/$1 $user/;'
perl -p -i -e "$PERL_COMMAND" "$GALAXYCONF"
perl -p -i -e "$PERL_COMMAND" "$TSCONF"

# Start galaxy & the tool shed
echo "Running Galaxy daemon"
sh run.sh --daemon --log-file=galaxy.log 1>$LOGFILE

echo "Running Galaxy Tool Shed"
sh run_tool_shed.sh --daemon 1>$LOGFILE

#Wait for the eggs to finish downloading and galaxy to start before trying to connect
sleep 10

echo "Registering Galaxy user $GALAXYUSER"
wget --retry-connrefused --waitretry=5 --tries=20 --output-file="$LOGFILE" --output-document="$GALAXYPATH/register_user_toolshed" --post-data="email=$GALAXYUSER&password=$GALAXYPASSWORD&confirm=$GALAXYPASSWORD&username=$GALAXYPUBLICID&bear_field=&create_user_button=Submit" "http://localhost:$TOOLSHEDPORT/user/create?cntrller=user"
wget --retry-connrefused --waitretry=5 --tries=20 --output-file="$LOGFILE" --output-document="$GALAXYPATH/register_user_galaxy" --post-data="email=$GALAXYUSER&password=$GALAXYPASSWORD&confirm=$GALAXYPASSWORD&username=$GALAXYPUBLICID&bear_field=&create_user_button=Submit" "http://localhost:$GALAXYPORT/user/create?cntrller=user"

echo "Galaxy setup completed successfully."
echo "To begin using galaxy, navigate to http://localhost:$GALAXYPORT/.  Your username and password are '$GALAXYUSER' and '$GALAXYPASSWORD'"
echo "To access the tool shed, navigate to http://localhost:$TOOLSHEDPORT/.  The credentials are the same as the above."
