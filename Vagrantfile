# Launch and provision multiple Linux distributions with Vagrant <http://vagrantup.com>
#
# Support:
#
# * precise64:   Ubuntu 12.04 (Precise) 64 bit (primary box)
# * lucid32:     Ubuntu 10.04 (Lucid) 32 bit
# * lucid64:     Ubuntu 10.04 (Lucid) 64 bit
# * centos6:     CentOS 6 32 bit
#
# See:
#
#   $ vagrant status
#
# The virtual machines are automatically provisioned upon startup with Chef-Solo
# <http://vagrantup.com/v1/docs/provisioners/chef_solo.html>.
#

require 'json'

# Lifted from <https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/hash/deep_merge.rb>
#
class Hash
  def deep_merge!(other_hash)
    self.merge(other_hash) do |key, oldval, newval|
      oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
      newval = newval.to_hash if newval.respond_to?(:to_hash)
      oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash' ? oldval.dup.deep_merge!(newval) : newval
    end
  end unless respond_to?(:deep_merge!)
end

STDERR.puts "[Vagrant   ] #{Vagrant::VERSION}"

# Automatically install and mount cookbooks from Berksfile on old Vagrant
#
require 'berkshelf/vagrant' if Vagrant::VERSION < '1.1'

distributions = {
  :precise64 => {
    :url      => 'http://files.vagrantup.com/precise64.box',
    :run_list => %w| apt build-essential vim java monit elasticsearch elasticsearch::plugins elasticsearch::proxy elasticsearch::aws elasticsearch::data elasticsearch::monit |,
    :ip       => '33.33.33.10',
    :primary  => true,
    :node     => {
      :elasticsearch => {
        :path => {
          :data => %w| /usr/local/var/data/elasticsearch/disk1 /usr/local/var/data/elasticsearch/disk2 |
        },
        :data => {
          :devices   => {
            "/dev/sdb" => {
              :file_system      => "ext3",
              :mount_options    => "rw,user",
              :mount_path       => "/usr/local/var/data/elasticsearch/disk1",
              :format_command   => "mkfs.ext3 -F",
              :fs_check_command => "dumpe2fs"
            },
            "/dev/sdc" => {
              :file_system      => "ext3",
              :mount_options    => "rw,user",
              :mount_path       => "/usr/local/var/data/elasticsearch/disk2",
              :format_command   => "mkfs.ext3 -F",
              :fs_check_command => "dumpe2fs"
            }
          }
        }
      }
    }
  },

  :centos6 => {
    # Note: Monit cookbook broken on CentOS
    :url      => 'https://opscode-vm.s3.amazonaws.com/vagrant/boxes/opscode-centos-6.3.box',
    :run_list => %w| yum::epel build-essential vim java elasticsearch elasticsearch::proxy elasticsearch::data |,
    :ip       => '33.33.33.11',
    :primary  => false,
    :node     => {
      :elasticsearch => {
        :path => {
          :data => "/usr/local/var/data/elasticsearch/disk1"
        },
        :data => {
          :devices   => {
            "/dev/sdb" => {
              :file_system      => "ext3",
              :mount_options    => "rw,user",
              :mount_path       => "/usr/local/var/data/elasticsearch/disk1",
              :format_command   => "mkfs.ext3 -F",
              :fs_check_command => "dumpe2fs"
            }
          }
        },

        :nginx => {
          :user => 'nginx'
        }
      }
    }
  }
}

node_config = {
  :java => {
    :install_flavor => "openjdk",
    :jdk_version    => "7"
  },

  :elasticsearch => {
    :cluster => { :name => "elasticsearch_vagrant" },

    :plugins => {
      'karmi/elasticsearch-paramedic' => {
        :url => 'https://github.com/karmi/elasticsearch-paramedic/archive/master.zip'
      }
    },

    :limits => {
      :nofile  => 1024,
      :memlock => 512
    },

    :logging => {
      :discovery => 'TRACE',
      'index.indexing.slowlog' => 'INFO, index_indexing_slow_log_file'
    },

    :nginx => {
      :user  =>  'www-data',
      :users => [{ username: 'USERNAME', password: 'PASSWORD' }]
    },
    # For testing flat attributes:
    "index.search.slowlog.threshold.query.trace" => "1ms",
    # For testing deep attributes:
    :discovery => { :zen => { :ping => { :timeout => "9s" } } },
    # For testing custom configuration
    :custom_config => {
      'threadpool.index.type' => 'fixed',
      'threadpool.index.size' => '2'
    }
  }
}

if ENV['CONFIG']
  # See e.g. https://gist.github.com/karmi/2050769#file-node-example-json
  begin
    custom_config = JSON.parse(File.read(ENV['CONFIG']), symbolize_names: true)
  rescue Exception => e
    STDERR.puts "[!] Error when reading the configuration file:",
                e.inspect
  end
else
  custom_config = {}
end

Vagrant::Config.run do |config|

  distributions.each_pair do |name, options|

    config.vagrant.dotfile_name = '.vagrant-1' if Vagrant::VERSION < '1.1'

    config.vm.define name, :options => options[:primary] do |box_config|

      box_config.vm.box       = name.to_s
      box_config.vm.box_url   = options[:url]

      box_config.vm.host_name = name.to_s

      if Vagrant::VERSION < '1.1'
        box_config.vm.network   :hostonly, options[:ip]
      else
        config.vm.network :private_network, ip: options[:ip]
      end

      box_config.berkshelf.enabled = true if Vagrant::VERSION > '1.1'

      # Box customizations

      # 1. Limit memory to 512 MB
      #
      if Vagrant::VERSION < '1.1'
        box_config.vm.customize ["modifyvm", :id, "--memory", 512]
      else
        config.vm.provider :virtualbox do |vb|
          vb.customize ["modifyvm", :id, "--memory", 512]
        end
      end

      # 2. Create additional disks
      #
      if Vagrant::VERSION < '1.1'
        if name == :precise64 or name == :centos6
          disk1, disk2 = "tmp/disk-#{Time.now.to_f}.vdi", "tmp/disk-#{Time.now.to_f}.vdi"
          box_config.vm.customize ["createhd", "--filename", disk1, "--size", 250]
          box_config.vm.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 1,"--type", "hdd", "--medium", disk1]
          box_config.vm.customize ["createhd", "--filename", disk2, "--size", 250]
          box_config.vm.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 2,"--type", "hdd", "--medium", disk2]
        end
      else
        if name == :precise64 or name == :centos6
          config.vm.provider :virtualbox do |vb|
            disk1, disk2 = "tmp/disk-#{Time.now.to_f}.vdi", "tmp/disk-#{Time.now.to_f}.vdi"
            vb.customize ["createhd", "--filename", disk1, "--size", 250]
            vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 1,"--type", "hdd", "--medium", disk1]
            vb.customize ["createhd", "--filename", disk2, "--size", 250]
            vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 2,"--type", "hdd", "--medium", disk2]
          end
        end
      end

      # Update packages on the machine
      #
      config.vm.provision :shell do |shell|
        shell.inline = %Q{
          which apt-get > /dev/null 2>&1 && apt-get update --quiet --yes || true;
          which yum > /dev/null 2>&1 && yum update -y || true;
        }
      end if ENV['UPDATE']

      # Install latest Chef on the machine
      #
      config.vm.provision :shell do |shell|
        version   = ENV['CHEF'].match(/^\d+/) ? ENV['CHEF'] : nil

        if version
          shell.inline = %Q{
            which apt-get > /dev/null 2>&1 && apt-get install curl --quiet --yes || true;
            which yum > /dev/null 2>&1 && yum install curl -y || true;
            test -d "/opt/chef" && grep 'chef #{version}' /opt/chef/version-manifest.txt || curl -# -L http://www.opscode.com/chef/install.sh | sudo bash -s -- #{version ? "-v #{version}" : ''};
            /opt/chef/embedded/bin/gem list pry | grep pry || /opt/chef/embedded/bin/gem install pry --no-ri --no-rdoc || true;
          }
        else
          shell.inline = %Q{
            which apt-get > /dev/null 2>&1 && apt-get install curl --quiet --yes || true;
            which yum > /dev/null 2>&1 && yum install curl -y || true;
            test -d "/opt/chef" && chef-solo -v | grep 11 || curl -# -L http://www.opscode.com/chef/install.sh | sudo bash -s --;
            /opt/chef/embedded/bin/gem list pry | grep pry || /opt/chef/embedded/bin/gem install pry --no-ri --no-rdoc;
          }
        end
      end if ENV['CHEF']

      # Provision the machine with Chef Solo
      #
      box_config.vm.provision :chef_solo do |chef|
        chef.data_bags_path    = './tmp/data_bags'
        chef.provisioning_path = '/etc/vagrant-chef'
        chef.log_level         = :debug

        chef.run_list = options[:run_list]
        chef.run_list << 'elasticsearch::test' if ENV['TEST']
        chef.json     = node_config.dup.deep_merge!(options[:node]).deep_merge!(custom_config)
      end
    end

  end

end<<<<<<< HEAD
# Launch and provision multiple Linux distributions with Vagrant <http://vagrantup.com>
#
# Support:
#
# * precise64:   Ubuntu 12.04 (Precise) 64 bit (primary box)
# * lucid32:     Ubuntu 10.04 (Lucid) 32 bit
# * lucid64:     Ubuntu 10.04 (Lucid) 64 bit
# * centos6:     CentOS 6 32 bit
#
# See:
#
#   $ vagrant status
#
# The virtual machines are automatically provisioned upon startup with Chef-Solo
# <http://vagrantup.com/v1/docs/provisioners/chef_solo.html>.
#

require 'json'

# Lifted from <https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/hash/deep_merge.rb>
#
class Hash
  def deep_merge!(other_hash)
    self.merge(other_hash) do |key, oldval, newval|
      oldval = oldval.to_hash if oldval.respond_to?(:to_hash)
      newval = newval.to_hash if newval.respond_to?(:to_hash)
      oldval.class.to_s == 'Hash' && newval.class.to_s == 'Hash' ? oldval.dup.deep_merge!(newval) : newval
    end
  end unless respond_to?(:deep_merge!)
end

STDERR.puts "[Vagrant   ] #{Vagrant::VERSION}"

# Automatically install and mount cookbooks from Berksfile on old Vagrant
#
require 'berkshelf/vagrant' if Vagrant::VERSION < '1.1'

distributions = {
  :precise64 => {
    :url      => 'http://files.vagrantup.com/precise64.box',
    :run_list => %w| apt build-essential vim java monit elasticsearch elasticsearch::plugins elasticsearch::proxy elasticsearch::aws elasticsearch::data elasticsearch::monit |,
    :ip       => '33.33.33.10',
    :primary  => true,
    :node     => {
      :elasticsearch => {
        :path => {
          :data => %w| /usr/local/var/data/elasticsearch/disk1 /usr/local/var/data/elasticsearch/disk2 |
        },
        :data => {
          :devices   => {
            "/dev/sdb" => {
              :file_system      => "ext3",
              :mount_options    => "rw,user",
              :mount_path       => "/usr/local/var/data/elasticsearch/disk1",
              :format_command   => "mkfs.ext3 -F",
              :fs_check_command => "dumpe2fs"
            },
            "/dev/sdc" => {
              :file_system      => "ext3",
              :mount_options    => "rw,user",
              :mount_path       => "/usr/local/var/data/elasticsearch/disk2",
              :format_command   => "mkfs.ext3 -F",
              :fs_check_command => "dumpe2fs"
            }
          }
        }
      }
    }
  },

  :centos6 => {
    # Note: Monit cookbook broken on CentOS
    :url      => 'https://opscode-vm.s3.amazonaws.com/vagrant/boxes/opscode-centos-6.3.box',
    :run_list => %w| yum::epel build-essential vim java elasticsearch elasticsearch::proxy elasticsearch::data |,
    :ip       => '33.33.33.11',
    :primary  => false,
    :node     => {
      :elasticsearch => {
        :path => {
          :data => "/usr/local/var/data/elasticsearch/disk1"
        },
        :data => {
          :devices   => {
            "/dev/sdb" => {
              :file_system      => "ext3",
              :mount_options    => "rw,user",
              :mount_path       => "/usr/local/var/data/elasticsearch/disk1",
              :format_command   => "mkfs.ext3 -F",
              :fs_check_command => "dumpe2fs"
            }
          }
        },

        :nginx => {
          :user => 'nginx'
        }
      }
    }
  }
}

node_config = {
  :java => {
    :install_flavor => "openjdk",
    :jdk_version    => "7"
  },

  :elasticsearch => {
    :cluster => { :name => "elasticsearch_vagrant" },

    :plugins => {
      'karmi/elasticsearch-paramedic' => {
        :url => 'https://github.com/karmi/elasticsearch-paramedic/archive/master.zip'
      }
    },

    :limits => {
      :nofile  => 1024,
      :memlock => 512
    },

    :logging => {
      :discovery => 'TRACE',
      'index.indexing.slowlog' => 'INFO, index_indexing_slow_log_file'
    },

    :nginx => {
      :user  =>  'www-data',
      :users => [{ username: 'USERNAME', password: 'PASSWORD' }]
    },
    # For testing flat attributes:
    "index.search.slowlog.threshold.query.trace" => "1ms",
    # For testing deep attributes:
    :discovery => { :zen => { :ping => { :timeout => "9s" } } },
    # For testing custom configuration
    :custom_config => {
      'threadpool.index.type' => 'fixed',
      'threadpool.index.size' => '2'
    }
  }
}

if ENV['CONFIG']
  # See e.g. https://gist.github.com/karmi/2050769#file-node-example-json
  begin
    custom_config = JSON.parse(File.read(ENV['CONFIG']), symbolize_names: true)
  rescue Exception => e
    STDERR.puts "[!] Error when reading the configuration file:",
                e.inspect
  end
else
  custom_config = {}
end

Vagrant::Config.run do |config|

  distributions.each_pair do |name, options|

    config.vagrant.dotfile_name = '.vagrant-1' if Vagrant::VERSION < '1.1'

    config.vm.define name, :options => options[:primary] do |box_config|

      box_config.vm.box       = name.to_s
      box_config.vm.box_url   = options[:url]

      box_config.vm.host_name = name.to_s

      if Vagrant::VERSION < '1.1'
        box_config.vm.network   :hostonly, options[:ip]
      else
        config.vm.network :private_network, ip: options[:ip]
      end

      box_config.berkshelf.enabled = true if Vagrant::VERSION > '1.1'

      # Box customizations

      # 1. Limit memory to 512 MB
      #
      if Vagrant::VERSION < '1.1'
        box_config.vm.customize ["modifyvm", :id, "--memory", 512]
      else
        config.vm.provider :virtualbox do |vb|
          vb.customize ["modifyvm", :id, "--memory", 512]
        end
      end

      # 2. Create additional disks
      #
      if Vagrant::VERSION < '1.1'
        if name == :precise64 or name == :centos6
          disk1, disk2 = "tmp/disk-#{Time.now.to_f}.vdi", "tmp/disk-#{Time.now.to_f}.vdi"
          box_config.vm.customize ["createhd", "--filename", disk1, "--size", 250]
          box_config.vm.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 1,"--type", "hdd", "--medium", disk1]
          box_config.vm.customize ["createhd", "--filename", disk2, "--size", 250]
          box_config.vm.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 2,"--type", "hdd", "--medium", disk2]
        end
      else
        if name == :precise64 or name == :centos6
          config.vm.provider :virtualbox do |vb|
            disk1, disk2 = "tmp/disk-#{Time.now.to_f}.vdi", "tmp/disk-#{Time.now.to_f}.vdi"
            vb.customize ["createhd", "--filename", disk1, "--size", 250]
            vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 1,"--type", "hdd", "--medium", disk1]
            vb.customize ["createhd", "--filename", disk2, "--size", 250]
            vb.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", 2,"--type", "hdd", "--medium", disk2]
          end
        end
      end

      # Update packages on the machine
      #
      config.vm.provision :shell do |shell|
        shell.inline = %Q{
          which apt-get > /dev/null 2>&1 && apt-get update --quiet --yes || true;
          which yum > /dev/null 2>&1 && yum update -y || true;
        }
      end if ENV['UPDATE']

      # Install latest Chef on the machine
      #
      config.vm.provision :shell do |shell|
        version   = ENV['CHEF'].match(/^\d+/) ? ENV['CHEF'] : nil

        if version
          shell.inline = %Q{
            which apt-get > /dev/null 2>&1 && apt-get install curl --quiet --yes || true;
            which yum > /dev/null 2>&1 && yum install curl -y || true;
            test -d "/opt/chef" && grep 'chef #{version}' /opt/chef/version-manifest.txt || curl -# -L http://www.opscode.com/chef/install.sh | sudo bash -s -- #{version ? "-v #{version}" : ''};
            /opt/chef/embedded/bin/gem list pry | grep pry || /opt/chef/embedded/bin/gem install pry --no-ri --no-rdoc || true;
          }
        else
          shell.inline = %Q{
            which apt-get > /dev/null 2>&1 && apt-get install curl --quiet --yes || true;
            which yum > /dev/null 2>&1 && yum install curl -y || true;
            test -d "/opt/chef" && chef-solo -v | grep 11 || curl -# -L http://www.opscode.com/chef/install.sh | sudo bash -s --;
            /opt/chef/embedded/bin/gem list pry | grep pry || /opt/chef/embedded/bin/gem install pry --no-ri --no-rdoc;
          }
        end
      end if ENV['CHEF']

      # Provision the machine with Chef Solo
      #
      box_config.vm.provision :chef_solo do |chef|
        chef.data_bags_path    = './tmp/data_bags'
        chef.provisioning_path = '/etc/vagrant-chef'
        chef.log_level         = :debug

        chef.run_list = options[:run_list]
        chef.run_list << 'elasticsearch::test' if ENV['TEST']
        chef.json     = node_config.dup.deep_merge!(options[:node]).deep_merge!(custom_config)
      end
    end

  end

=======
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  config.vm.hostname = "vcy-elasticsearch-berkshelf"

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "Berkshelf-CentOS-6.3-x86_64-minimal"

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  config.vm.box_url = "https://dl.dropbox.com/u/31081437/Berkshelf-CentOS-6.3-x86_64-minimal.box"

  # Assign this VM to a host-only network IP, allowing you to access it
  # via the IP. Host-only networks can talk to the host machine as well as
  # any other machines on the same network, but cannot be accessed (through this
  # network interface) by any external networks.
  config.vm.network :private_network, ip: "33.33.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.

  # config.vm.network :public_network

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider :virtualbox do |vb|
  #   # Don't boot with headless mode
  #   vb.gui = true
  #
  #   # Use VBoxManage to customize the VM. For example to change memory:
  #   vb.customize ["modifyvm", :id, "--memory", "1024"]
  # end
  #
  # View the documentation for the provider you're using for more
  # information on available options.

  config.ssh.max_tries = 40
  config.ssh.timeout   = 120

  # The path to the Berksfile to use with Vagrant Berkshelf
  # config.berkshelf.berksfile_path = "./Berksfile"

  # Enabling the Berkshelf plugin. To enable this globally, add this configuration
  # option to your ~/.vagrant.d/Vagrantfile file
  config.berkshelf.enabled = true

  # An array of symbols representing groups of cookbook described in the Vagrantfile
  # to exclusively install and copy to Vagrant's shelf.
  # config.berkshelf.only = []

  # An array of symbols representing groups of cookbook described in the Vagrantfile
  # to skip installing and copying to Vagrant's shelf.
  # config.berkshelf.except = []

  config.vm.provision :chef_solo do |chef|
    chef.json = {
      :mysql => {
        :server_root_password => 'rootpass',
        :server_debian_password => 'debpass',
        :server_repl_password => 'replpass'
      }
    }

    chef.run_list = [
        "recipe[vcy-elasticsearch::default]"
    ]
  end
>>>>>>> initial commit
end
