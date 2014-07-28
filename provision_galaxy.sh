#!/usr/bin/env bash
export GALAXY_PORT="8080"
export TOOLSHED_PORT="9009"
export GALAXYPATH="/galaxy"
export CONFIGPATH="/vagrant/config/galaxy"
export GALAXYREPO="https://bitbucket.org/galaxy/galaxy-dist"
export GALAXYRELEASE="release_2014.02.10"
export GALAXYBRANCH="stable"


GALAXY_USER=$1
GALAXY_PASSWORD=$2

if [[ -z "$GALAXY_USER" || -z "$GALAXY_PASSWORD" ]]; then
	echo "The GALAXY_USER and GALAXY_PASSWORD environment variables must be set before using vagrant up." 1>&2
	echo "Please export them from your .bashrc file or launch vagrant as follows:" 1>&2
	echo "GALAXY_USER='lastnamef@agr.gc.ca' GALAXY_PASSWORD='abc123' vagrant up" 1>&2

	exit 0
fi

IFS="@"
set -- $GALAXY_USER
if [ "${#@}" -ne 2 ];then
	echo "The GALAXY_USER parameter must be an e-mail address." 1>&2
	echo "$GALAXY_USER is invalid!" 1>&2
	exit 0
fi
GALAXY_PUBLICID="$1"


if [ $(echo ${#GALAXY_PASSWORD}) -lt 6 ]; then
	echo "The GALAXY_PASSWORD parameter must be 6 characters long." 1>&2
	exit 0
fi

apt-add-repository -y ppa:mercurial-ppa/releases &> /dev/null

apt-get update &> /dev/null

# Install Software
echo "Installing software: mercurial, python, pip, vim, bzip2"
apt-get -y install mercurial python2.6 pip vim bzip2  &> /dev/null

test ! -d "$GALAXYPATH" &&  mkdir "$GALAXYPATH"
chown vagrant "$GALAXYPATH"

# Get galaxy
echo "Downloading galaxy tag $GALAXYRELEASE"
#hg clone -b $GALAXYBRANCH -u $GALAXYRELEASE $GALAXYREPO:$GALAXYRELEASE "$GALAXYPATH"

su vagrant << EOF

# Download the target release if it doesn't exist
if [ ! -f /vagrant/$GALAXYRELEASE.tar.bz2 ]; then
	wget $GALAXYREPO/get/$GALAXYRELEASE.tar.bz2
fi

echo "Extracting $GALAXYRELEASE.tar.bz2"
tar xvf ${GALAXYRELEASE}.tar.bz2 &> /dev/null

find . -type d -name galaxy-galaxy-dist\* -exec cp -r '{}/.' "$GALAXYPATH/" \;
find . -type d -name galaxy-galaxy-dist\* -exec rm -rf '{}' \;

cd "$GALAXYPATH"

# Avoid storing cached eggs in Vagrant home folder
mkdir 'egg-cache'
export PYTHON_EGG_CACHE="$GALAXYPATH/egg-cache"

# Configure galaxy
echo "Configuring galaxy..."
cp -r "$CONFIGPATH/." "$GALAXYPATH/"

# Set the GALAXY_USER as an admin in galaxy and the tool shed
perl -p -i -e '$user = "'$GALAXY_USER'"; $user =~ s/\@/\\\@/; s/^#?(admin_users\s*=.*)$/$1,$user/;' "$GALAXYPATH/universe_wsgi.ini"
perl -p -i -e '$user = "'$GALAXY_USER'"; $user =~ s/\@/\\\@/; s/^#?(admin_users\s*=.*)$/$1,$user/;' "$GALAXYPATH/tool_shed_wsg.ini"

# Start galaxy & the tool shed
echo "Running Galaxy daemon"
sh run.sh --daemon --log-file=galaxy.log

echo "Running Galaxy Tool Shed"
sh run_tool_shed.sh &

EOF

sleep 2s

echo "Registering Galaxy user $GALAXY_USER"
wget "http://$(hostname -s):8080/user/create?cntrller=user" --post-data="email=$GALAXY_USER&password=$GALAXY_PASSWORD&confirm=$GALAXY_PASSWORD&username=$GALAXY_PUBLICID&bear_field=&create_user_button=Submit"

echo "Galaxy setup completed successfully."
echo "To begin using galaxy, navigate to http://localhost/"
