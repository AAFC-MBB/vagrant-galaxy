# -*- mode: ruby -*-
# vi: set ft=ruby :


def prompt_credentials()
  unless ENV.has_key?('GALAXY_USER') and ENV.has_key?('GALAXY_PASSWORD') then
    STDOUT.puts 'Please provide a username and password to register with Galaxy'
    STDOUT.puts 'Username: '
    ENV['GALAXY_USER'] = STDIN.gets
    STDOUT.puts 'Passsword: '
    ENV['GALAXY_PASSWORD'] = STDIN.gets
  else
    STDOUT.puts 'Using GALAXY_USER=%s parameter from environment ' % ENV['GALAXY_USER']
  end
end

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "precise64"

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  config.vm.box_url = "http://files.vagrantup.com/lucid64.box"

  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--memory", 4096]
  end


  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  config.vm.network :forwarded_port, guest: 8080, host: 8080
  config.vm.network :forwarded_port, guest: 9009, host: 9009


#  config.vm.provider "parallels" do |pa, override|
#  end

#  config.vm.provider "virtualbox" do |vb, override|
#  end


  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network :private_network, ip: "192.168.33.10"

  config.vm.provision "shell" do |script|
    script.path = "provision_galaxy.sh"
    script.args = [ ENV['GALAXY_USER'], ENV['GALAXY_PASSWORD'] ]
  end
end
