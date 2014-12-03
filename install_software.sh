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

