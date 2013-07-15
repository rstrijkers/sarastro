# Copyright (C) 2012 Rudolf Strijkers <rudolf.strijkers@tno.nl>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
#
# A Netapp encapsulates the programmable network element of a Virtual 
# Internet (VI). Although a VI may consist of multiple Netapps the current 
# code assumes a one Netapp per VI. Another assumption is that Netapps always
# receive a public IP address for control.
#
# The Netapp Factory creates Netapps on basis of an image (Netapp selection)
# and constraints (location, price, features). Each cloud provider uses 
# different methods for VM allocation, but the biggest problem is the range 
# of possible constraints. The Netapp Factory should have some smart method 
# for selection and allocation of cloud resources.
#

#
# OBSOLETE

# functionality specific to a netapp...
module VIC
  module NetappStore < Hash
    include Singleton
  end
end


# id="i-5c973972",
        # ami_launch_index=0,
        # availability_zone="us-east-1b",
        # block_device_mapping=[],
        # client_token=nil,
        # dns_name="ec2-25-2-474-44.compute-1.amazonaws.com",
        # groups=["default"],
        # flavor_id="m1.small",
        # image_id="test",
        # ip_address="25.2.474.44",
        # kernel_id="aki-4e1e1da7",
        # key_name=nil,
        # created_at=Mon Nov 29 18:09:34 -0500 2010,
        # monitoring=false,
        # product_codes=[],
        # private_dns_name="ip-19-76-384-60.ec2.internal",
        # private_ip_address="19.76.384.60",
        # ramdisk_id="ari-0b3fff5c",
        # reason=nil,
        # root_device_name=nil,
        # root_device_type="instance-store",
        # state="running",
        # state_reason={},
        # subnet_id=nil,
        # tags={},
        # user_data=nil
        # >
        #

#        def setup(credentials = {})
#                  requires :public_ip_address, :username
#                  require 'multi_json'
#                  require 'net/ssh'
#
#                  commands = [
#                    %{mkdir .ssh},
#                    %{passwd -l #{username}},
#                    %{echo "#{MultiJson.encode(Fog::JSON.sanitize(attributes))}" >> ~/attributes.json}
#                  ]
#                  if public_key
#                    commands << %{echo "#{public_key}" >> ~/.ssh/authorized_keys}
#                  end
#
#                  # wait for aws to be ready
#                  Timeout::timeout(360) do
#                    begin
#                      Timeout::timeout(8) do
#                        Fog::SSH.new(public_ip_address, username, credentials.merge(:timeout => 4)).run('pwd')
#                      end
#                    rescue Errno::ECONNREFUSED
#                      sleep(2)
#                      retry
#                    rescue Net::SSH::AuthenticationFailed, Timeout::Error
#                      retry
#                    end
#                  end
#                  Fog::SSH.new(public_ip_address, username, credentials).run(commands)
#                end
#

#        def get(server_id)
#          if server_id
#            self.class.new(:connection => connection).all('instance-id' => server_id).first
#          end
#        rescue Fog::Errors::NotFound
#          nil
#
#
# Test if netapp is ready
#def setup(credentials = {})
#          requires :public_ip_address, :username
#          require 'multi_json'
#          require 'net/ssh'
#
#          commands = [
#            %{mkdir .ssh},
#            %{passwd -l #{username}},
#            %{echo "#{MultiJson.encode(Fog::JSON.sanitize(attributes))}" >> ~/attributes.json}
#          ]
#          if public_key
#            commands << %{echo "#{public_key}" >> ~/.ssh/authorized_keys}
#          end
#
#          # wait for aws to be ready
#          Timeout::timeout(360) do
#            begin
#              Timeout::timeout(8) do
#                Fog::SSH.new(public_ip_address, username, credentials.merge(:timeout => 4)).run('pwd')
#              end
#            rescue Errno::ECONNREFUSED
#              sleep(2)
#              retry
#            rescue Net::SSH::AuthenticationFailed, Timeout::Error
#              retry
#            end
#          end
#         Fog::SSH.new(public_ip_address, username, credentials).run(commands)