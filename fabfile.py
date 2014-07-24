#!/usr/bin/env python

# Notes
# * use this instead: http://cfgparse.sourceforge.net/


from fabric.api import *
from fabtools.vagrant import vagrant
import ConfigParser

galaxy_path = '/galaxy'
universe_wsgi = "%s/universe_wsgi.ini" % galaxy_path
galaxy_log = "%s/galaxy.log" % galaxy_path

################
# Galaxy process

@task
def galaxy(cmd):
    if(cmd=='status'):
        status()
    elif(cmd=='start'):
        start_galaxy()        
    elif(cmd=='stop'):
        stop_galaxy()
    elif(cmd=='restart'):
        restart_galaxy()
    elif(cmd=='log'):
        showlog_galaxy()
    else:
        print "Invalid directive to Galaxy"
        
def start_galaxy():
    with cd(galaxy_path):
        run('./run.sh --daemon --log-file=%s' % galaxy_log)
def stop_galaxy():
    with cd(galaxy_path):
        run('./run.sh --stop-daemon')
        
def restart_galaxy():
    with cd(galaxy_path):
        run('./run.sh --stop-daemon')
        run('./run.sh --daemon --log-file=%s' % galaxy_log)

def status_galaxy():
    with cd(galaxy_path):
        run('./run.sh --status')

def showlog_galaxy():
    with cd(galaxy_path):
        run('cat %s' % galaxy_log)

# Tool Shed
@task
def toolshed(cmd):
    if(cmd=='status'):
        toolshed_status()
    elif(cmd=='start'):
        start_toolshed()        
    elif(cmd=='stop'):
        stop_toolshed()
    elif(cmd=='restart'):
        restart_toolshed()
    elif(cmd=='log'):
        showlog_toolshed()
    else:
        print "Invalid directive to Galaxy Toolshed"
        
def start_toolshed():
    with cd(galaxy_path):
        run('./run_tool_shed.sh --daemon')
def stop_toolshed():
    with cd(galaxy_path):
        run('./run_tool_shed.sh --stop-daemon')
        
def restart_toolshed():
    with cd(galaxy_path):
        run('./run_tool_shed.sh --stop-daemon')
        run('./run_tool_shed.sh --daemon')

def toolshed_status():
    with cd(galaxy_path):
        run('./run_tool_shed.sh --status')

def showlog_toolshed():
    with cd(galaxy_path):
        run('%s/tool_shed_webapp.log' % galaxy_path)
#############################
# software package management
@task
def install(package):
    sudo('apt-get install %s' % (package))

##########################
# Galaxy config management
@task
def add_admin():
    pass

@task
def conf_set(k,v):
    Config = ConfigParser.ConfigParser()
    Config.read(universe_wsgi)
    Config.set('app:main',k,v)
    cfg = open(universe_wsgi,'w')
    Config.write(cfg)

@task 
def conf_get(k):
    Config = ConfigParser.ConfigParser()
    Config.read(universe_wsgi)
    print Config.get('app:main',k)
    
########################
# Vagrant on Galaxy test
@task
def install_vagrant():
    run('wget http://files.vagrantup.com/packages/0ac2a87388419b989c3c0d0318cc97df3b0ed27d/vagrant_1.3.4_x86_64.deb')
    sudo('sudo dpkg -i vagrant_1.3.4_x86_64.deb')

########################
# StarCluster on Galaxy test
#@task
#def install_starcluster():
#   pass

