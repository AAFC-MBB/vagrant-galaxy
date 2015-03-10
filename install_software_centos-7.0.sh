# Load options (GALAXYPATH, LOGFILE)

export LOGFILE=/dev/null

while getopts p: opt; do
    case $opt in
    p)
        export GALAXYPATH=$OPTARG
    ;;
    esac
done

#echo "Updating apt repository cache"
# apt-get -y -q update 1>$LOGFILE

echo "Updating yum repository cache"
yum --enablerepo=updates clean metadata
yum -y update 1>$LOGFILE

echo "Installing python, vim, bzip2, python-software-properties"
# apt-get -y -q install python vim bzip2 python-software-properties 1> $LOGFILE
yum -y install python vim bzip2 1>$LOGFILE

echo "Installing build essential"
# apt-get -y -q install build-essential 1>$LOGFILE
yum -y install make automake gcc gcc-c++ kernel-devel 1>$LOGFILE

# Update mercurial repository to latest version
echo "Adding mercurial PPA and updating apt repository cache"
#add-apt-repository -y ppa:mercurial-ppa/releases 2>&1 1> $LOGFILE
#apt-get -y -q update 1> /dev/null

# Install required software
#echo "Installing mercurial from PPA"
#apt-get -y -q install mercurial 1>$LOGFILE

echo "Installing mercurial"
yum -y install hg

# Specific to centos 7 (different even for centos 6.5)
# Warning: Disabling built-in firewall entirely to allow 
# forwarding of Galaxy and toolshed ports.
# See http://www.server-world.info/en/note?os=CentOS_7&p=initial_conf&f=2
systemctl stop firewalld
systemctl disable firewalld

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

