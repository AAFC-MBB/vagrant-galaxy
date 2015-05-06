#get options

# Load options from command line
while getopts p:s:r:o:t:u:i:a:h: opt; do
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
	h)
	    export HOSTNAME=$OPTARG
	    ;;
	
	esac
done

export LOGFILE=/dev/null

#sudo mkdir -p "$GALAXYPATH"
sudo chown vagrant.vagrant "$GALAXYPATH"

# TODO this should perhaps be a parameter and /galaxy/shed_tool_conf.xml updated accordingly
sudo mkdir /shed_tools
sudo chown vagrant.vagrant /shed_tools

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

TSLCONFSAMPLE=$(find "$GALAXYPATH" -name "tool_sheds_conf.xml.sample")
if [[ -z $TSLCONFSAMPLE ]]; then
	echo "Failed to locate the tool shed configuration file - tool_shed_wsgi.ini.sample or tool_shed.ini.sample ." 1>&2
	exit 1
fi



GALAXYCONF=${GALAXYCONFSAMPLE%.sample}
TSCONF=${TSCONFSAMPLE%.sample}
TSLCONF=${TSLCONFSAMPLE%.sample}

# Create the configuration files from the provided samples
cp "$GALAXYCONFSAMPLE" "$GALAXYCONF"
cp "$TSCONFSAMPLE" "$TSCONF"
cp "$TSLCONFSAMPLE" "$TSLCONF"

# The run tool shed script must be executable for the fab commands to work
chmod u+x run_tool_shed.sh

# Avoid storing cached eggs in Vagrant home folder
echo " - modifying location of egg cache"
mkdir 'egg-cache'
export PYTHON_EGG_CACHE="$GALAXYPATH/egg-cache"
echo "export PYTHON_EGG_CACHE=$GALAXYPATH/egg-cache" >> ~/.bashrc

# Change the tool dependency directory
echo " - modifying Galaxy's tool depedency directory to $GALAXYPATH/tool-dep"
perl -p -i -e "s#^\#?tool_dependency_dir\s*=.*\$#tool_dependency_dir = $GALAXYPATH/tool-dep#" "$GALAXYCONF"

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
perl -p -i -e "my \$user = qw/$GALAXYUSER/; s/^#?(admin_users\s*=\s*)None$/\$1 \$user/;" "$GALAXYCONF"
# different example text in  tool_shed_wsgi.ini
perl -p -i -e "my \$user = qw/$GALAXYUSER/; s/^#?(admin_users\s*=\s*)user1.*$/\$1 \$user/;" "$TSCONF"

# Enable the local toolshed
echo " - adding local Tool Shed to $TSLCONF"
perl -p -i -e 's#</tool_sheds>#    <tool_shed name="Local tool shed" url="http://'$HOSTNAME':'$TOOLSHEDPORT'/"/>\n</tool_sheds>#' "$TSLCONF"

# Function that starts Galaxy and Tool Shed and waits for the 'serving on' message to appear in their logs
function start_and_wait {
	COMMAND=$1
	PIDFILE=$2
	GLOGFILE=$3

	./$COMMAND --daemon --pid-file=$PIDFILE --log-file=$GLOGFILE 2>&1 > $LOGFILE
	if [ ! -f $PIDFILE ]; then
		echo "The PID file $PIDFILE was not found after running ./$COMMAND" 1>&2
		exit 1
	fi

	while ps < $PIDFILE > /dev/null; do
		grep "^serving on" $GLOGFILE && echo " - started successfully!" && return 0
		sleep 1
	done

	echo " - failed to start!" 1>&2
	return 1
}

# Start galaxy & the tool shed

echo "Starting Galaxy"
echo " - this can take several minutes"
start_and_wait "run.sh" "galaxy.pid" "galaxy.log"

echo "Starting Galaxy Tool Shed"
start_and_wait "run_tool_shed.sh" "toolshed.pid" "toolshed.log"

echo "Registering Galaxy and Tool Shed user $GALAXYUSER"
wget --output-file="$LOGFILE" --output-document="$GALAXYPATH/register_user_toolshed" --post-data="email=$GALAXYUSER&password=$GALAXYPASSWORD&confirm=$GALAXYPASSWORD&username=$GALAXYPUBLICID&bear_field=&create_user_button=Submit" "http://$HOSTNAME:$TOOLSHEDPORT/user/create?cntrller=user"
wget --output-file="$LOGFILE" --output-document="$GALAXYPATH/register_user_galaxy" --post-data="email=$GALAXYUSER&password=$GALAXYPASSWORD&confirm=$GALAXYPASSWORD&username=$GALAXYPUBLICID&bear_field=&create_user_button=Submit" "http://$HOSTNAME:$GALAXYPORT/user/create?cntrller=user"

echo "=========================================================="
echo "Galaxy setup completed successfully."
echo "Galaxy URL - http://$HOSTNAME:$GALAXYPORT/"
echo "Galaxy Tool Shed URL - http://$HOSTNAME:$TOOLSHEDPORT/"
echo " Username: $GALAXYUSER   Password: $GALAXYPASSWORD"
echo "=========================================================="
