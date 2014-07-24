export GALAXYPATH="/galaxy"
export CONFIGPATH="/vagrant/config/galaxy"
export GALAXYREPO="https://bitbucket.org/galaxy/galaxy-dist/"

# install prereqs
echo "Installing dependencies"
sudo apt-get -y install mercurial python2.6 pip vim

# install galaxy
echo "Cloning galaxy repository"

hg clone $GALAXYREPO "$GALAXYPATH"

cd $GALAXYPATH

echo "Changing to Galaxy's stable branch"
hg update stable
hg checkout release_2014.02.10

# configure galaxy
echo "Configuring galaxy..."
# copy default configurations over
cp "$CONFIGPATH/*" "$GALAXYPATH/"

# start galaxy
echo "Running Galaxy daemon"
sh run.sh --daemon --logfile=galaxy.log
echo "Running Galaxy Tool Shed"
sh run_tool_shed.sh &

echo "Galaxy setup completed successfully."
echo "To begin using galaxy, navigate to http://localhost/"

