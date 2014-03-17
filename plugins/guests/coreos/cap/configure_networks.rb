require "tempfile"
require "securerandom"

require "vagrant/util/template_renderer"

module VagrantPlugins
  module GuestCoreOS
    module Cap
      class ConfigureNetworks
        @@discovery_uuid = SecureRandom.uuid
        include Vagrant::Util
        def self.configure_networks(machine, networks)
          machine.communicate.tap do |comm|
            # Disable default etcd
            comm.sudo("systemctl stop etcd")
            comm.sudo("systemctl disable etcd")

            # Read network interface names
            interfaces = []
            comm.sudo("ifconfig | grep enp0 | cut -f1 -d:") do |_, result|
              interfaces = result.split("\n")
            end

            # Configure interfaces
            # FIXME: fix matching of interfaces with IP adresses
            networks.each do |network|
              comm.sudo("ifconfig #{interfaces[network[:interface].to_i]} #{network[:ip]} netmask #{network[:netmask]}")
            end

            primary_machine_config = machine.env.active_machines.first
            primary_machine = machine.env.machine(*primary_machine_config, true)

            get_ip = lambda do |machine|
              ip = nil
              machine.config.vm.networks.each do |type, opts|
                if type == :private_network && opts[:ip]
                  ip = opts[:ip]
                  break
                end
              end

              ip
            end

            primary_machine_ip = get_ip.(primary_machine)
            current_ip = get_ip.(machine)
            discovery_string = "http://#{primary_machine_ip}:4002/v2/keys/#{@@discovery_uuid}"
            entry = TemplateRenderer.render("guests/coreos/etcd.service", :options => {
              :discovery_string => discovery_string,
              :my_ip => current_ip
            })

            if current_ip == primary_machine_ip
              Tempfile.open("vagrant") do |temp|
                discovery_entry = TemplateRenderer.render("guests/coreos/etcd-discovery.service", :options => {
                  :my_ip => current_ip
                })
                temp.binmode
                temp.write(discovery_entry)
                temp.close
                comm.upload(temp.path, "/tmp/etcd-discovery.service")
              end
            end

            Tempfile.open("vagrant") do |temp|
              temp.binmode
              temp.write(entry)
              temp.close
              comm.upload(temp.path, "/tmp/etcd-cluster.service")
            end

            if current_ip == primary_machine_ip
              comm.sudo("mv /tmp/etcd-discovery.service /media/state/units/")
            end

            comm.sudo("mv /tmp/etcd-cluster.service /media/state/units/")
            comm.sudo("systemctl restart local-enable.service")
          end

        end
      end
    end
  end
end
