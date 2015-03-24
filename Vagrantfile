require 'yaml'

debug = false

current_dir = File.dirname(__FILE__)

# Load all configuration from a single yaml file
conf = YAML.load_file("#{current_dir}/config/config.yml")

if debug
  puts "Galaxy configuration parameters:"
  puts conf['galaxy']
  puts "VM configuration parameters:"
  puts conf['vm']
end 

def get_credentials()
  if ENV['GALAXY_USER'].nil? or ENV['GALAXY_PASSWORD'].nil? then
    puts 'Using username and password from ./config/config.yml to register the user in Galaxy.'
    puts 'To override this behavior, please add the following in your ~/.bashrc file:'
    puts '  export GALAXY_USER="AAFC-UID@agr.gc.ca"'
    puts '  export GALAXY_PASSWORD="<A TEMP PASSWORD>"'
  else
    puts 'Using GALAXY_USER=%s parameter from environment ' % ENV['GALAXY_USER']
    conf['galaxy']['user'] = ENV['GALAXY_USER']
    conf['galaxy']['password'] = ENV['GALAXY_PASSWORD']
  end
end

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = conf['vm']['box']

  config.vm.define "galaxy" do |galaxy|

    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    galaxy.vm.network :private_network, ip: conf['vm']['galaxy']['ip']
  
    galaxy.vm.provider "virtualbox" do |v|
      v.gui = true
      v.customize ["modifyvm", :id, '--cpus', conf['vm']['galaxy']['cpus']]
      v.customize ["modifyvm", :id, "--memory", conf['vm']['galaxy']['memory']]
    end

    # Create a forwarded port mapping which allows access to a specific port
    # within the machine from a port on the host machine. In the example below,
    # accessing "localhost:8080" will access port 80 on the guest machine.
    conf['vm']['galaxy']['port_forward'].each do |guest_port, host_port|
      galaxy.vm.network :forwarded_port, guest: guest_port, host: host_port
    end

    config.vm.provision "shell" do |script|
      script.privileged = false
      script.path = "setup_galaxy.sh"
      script.args = '-p "%s" -s "%s" -r "%s" -o "%s" -t "%s" -u "%s" -a "%s" -i "%s" -z' % [ 
        conf['galaxy']['path'],
  #      conf['galaxy']['config-path'],
        conf['galaxy']['source-repo'],
        conf['galaxy']['release-tag'],
        conf['galaxy']['port'].to_s,
        conf['galaxy']['toolshed-port'].to_s,
        conf['galaxy']['user'],
        conf['galaxy']['password'],
        conf['galaxy']['publicid']
      ]
    end
  end

  config.vm.define "toolshed" do |toolshed|
    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    toolshed.vm.network :private_network, ip: conf['vm']['toolshed']['ip']
  
    toolshed.vm.provider "virtualbox" do |v|
      v.gui = true
      v.customize ["modifyvm", :id, '--cpus', conf['vm']['toolshed']['cpus']]
      v.customize ["modifyvm", :id, "--memory", conf['vm']['toolshed']['memory']]
    end

    # Create a forwarded port mapping which allows access to a specific port
    # within the machine from a port on the host machine. In the example below,
    # accessing "localhost:8080" will access port 80 on the guest machine.
    conf['vm']['toolshed']['port_forward'].each do |guest_port, host_port|
      toolshed.vm.network :forwarded_port, guest: guest_port, host: host_port
    end

    config.vm.provision "shell" do |script|
      script.privileged = false
      script.path = "setup_galaxy.sh"
      script.args = '-p "%s" -s "%s" -r "%s" -o "%s" -t "%s" -u "%s" -a "%s" -i "%s" -x' % [ 
        conf['galaxy']['path'],
  #      conf['galaxy']['config-path'],
        conf['galaxy']['source-repo'],
        conf['galaxy']['release-tag'],
        conf['galaxy']['port'].to_s,
        conf['galaxy']['toolshed-port'].to_s,
        conf['galaxy']['user'],
        conf['galaxy']['password'],
        conf['galaxy']['publicid']
      ]
    end

  end


  config.vm.provision "shell" do |script|
    if config.vm.box == "aafc/centos-7.0"
      script.path = "install_software_centos-7.0.sh"
    else
      script.path = "install_software.sh"
    end
      
    script.args = '-p "%s"' % [ 
      conf['galaxy']['path']
    ]
  end


#  config.vm.provider "parallels" do |pa, override|
#  end

#  config.vm.provider "virtualbox" do |vb, override|
#  end


end
