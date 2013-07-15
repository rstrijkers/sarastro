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

require 'eventmachine'
require 'socket'
require 'net/telnet'

$nid=<%= nid %>
$old_server_state = {}
$old_client_state = {}

# delete interface and network from ospf
# only inactive interfaces can be removed, so if this function is used
# on an interface that changed address, but exists, it will return an 
# error. Should not be a problem though...
def remove_from_ospf(iface, network)
  ospf = Net::Telnet::new("Host" => "localhost",
                          "Port" => 2604,
                          "Timeout" => 2,
                          "Prompt" => /[$%#>] \z/)
  ospf.cmd("1234")
  ospf.cmd("enable\r1234\r")
  ospf.cmd("conf t")
  ospf.cmd("no interface #{iface}")
  ospf.cmd("router ospf")
  ospf.cmd("no network #{network} area 0")
  ospf.close
end

def get_iface_network(iface)
  puts "ip addr show dev #{iface} | grep inet | awk '{print $2}'"     
  `ip addr show dev #{iface} | grep inet | awk '{print $2}'`.gsub(/\s+/, "")
end

module AddressUtil
   def get_interface(ip)
     # retrieve configuration file with ps
     res=`ps axo args | grep #{ip}`.split("\n")
     config=res[0].split(" ")[3] if res.size > 1
     
     # cat configuration file to get device
     `cat #{config} | grep device | awk '{print $2}'`.sub(";","").gsub(/\s+/, "")
   end

   # take the last 8 bits from both vars
   def format_ip(sid, nid)
     octet_server=sid.to_s.unpack("b*")[0][-8..-1].to_i(2)
     octet_client=nid.to_s.unpack("b*")[0][-8..-1].to_i(2)
     "10.#{octet_server}.#{octet_client}"
   end

   def set_interface(iface, newip, addr)
     puts "ip addr flush dev #{iface}"
     `sudo ip addr flush dev #{iface}`
     
     puts "ip addr add #{newip}.#{addr}/30 broadcast #{newip}.3 dev #{iface}"
     `sudo ip addr add #{newip}.#{addr}/30 broadcast #{newip}.3 dev #{iface}`       
     
     # we should tell ospf that the interfaces exist and add the networks
     # to the configuration
     # XXX: so we expect an expect script here
     tell_to_ospf(iface, "#{newip}.0/30")
   end
   
   def tell_to_ospf(iface, network)
     # set link-detect in zebra, because we want the route removed once the
     # interface is gone
     zebra = Net::Telnet::new("Host" => "localhost",
                             "Port" => 2601,
                             "Timeout" => 2,
                             "Prompt" => /[$%#>] \z/)
     zebra.cmd("1234")
     zebra.cmd("enable\r1234\r")
     zebra.cmd("configure terminal")
     zebra.cmd("interface #{iface}")
     zebra.cmd("link-detect")
     zebra.close     
     
     # tell ospf about the network
     ospf = Net::Telnet::new("Host" => "localhost",
                             "Port" => 2604,
                             "Timeout" => 2,
                             "Prompt" => /[$%#>] \z/)
     ospf.cmd("1234")
     ospf.cmd("enable\r1234\r")
     ospf.cmd("conf t")
     ospf.cmd("router ospf")
     ospf.cmd("network #{network} area 0")
     ospf.cmd("exit")
     ospf.cmd("interface #{iface}")
     ospf.cmd("ospf dead-interval 2")
     ospf.cmd("ospf hello-interval 1")
     ospf.close
   end   
end

class AddressServer < EventMachine::Connection
  include AddressUtil
#   def post_init
#     puts "-- someone connected to the echo server!"
#   end

   def receive_data data
     port, ip = Socket.unpack_sockaddr_in(get_peername)
     puts "got #{data.inspect} from #{ip}:#{port}"

     get_id(data, ip) if data =~ /get_id/i
     close_connection_after_writing
   end

#   def unbind
#     puts "-- someone disconnected from the echo server!"
#   end

#--------
   def get_id(data, sip)
     sid = data.split(" ")
     sid = sid[1] if sid.size > 1

     # send back our own id
     send_data $nid.to_s

     # format the ip address:
     # 10.sid.cid.1/2
     # as we are the client we take the highest address,
     # the server will configure a lower address.
     newip = format_ip(sid, $nid)
     
     # use the server address to retrieve the interface
     # -> c5901-serverip 
     iface = get_interface(sip)

     # check if there was an address configured. If so, remove it from ospf
     network=get_iface_network(iface)
     remove_from_ospf(iface, network) if network

     set_interface(iface, newip, "1")
   end   
end

# list all servers
#   - find latest client connection
# maintain old and new list of:
#   - interface, client address
# 
# determine changes after last check
#   -> servers deleted: no action
#   -> client address changed: send request 
#   -> server added: send request
class CallHandler < EventMachine::Connection
  include AddressUtil

  def initialize *args
    super
    
    @iface = args[0]
  end

  # call get_id and send our own id
  def post_init
    puts "sending data!"
    send_data "get_id #{$nid}"
  end

  # the answer should be the id of the client
  def receive_data data
    puts "received: #{data}"
    close_connection

    # I'm the server and I got the client id
    newip = format_ip($nid, data)
    set_interface(@iface, newip, "2")    
  end
  
  def unbind
    puts "disconnect"
  end
end

def diff(old_h, new_h)
  new_list = {}
  # keys not in old list -> report
  # these interfaces were added, we must create address and add to ospf
  (new_h.keys - old_h.keys).each {|k| new_list[k] = new_h[k]}
  
  # these interfaces were deleted, we must remove them from ospf
  del_list = {}
  (old_h.keys - new_h.keys).each {|k| del_list[k] = old_h[k]}
  
  # values changed -> report
  # these interfaces got new addresses, must change address and update ospf 
  change_list = {}
  (new_h.keys & old_h.keys).each {|k| change_list[k] = new_h[k] if old_h[k] != new_h[k]}  
  puts "new links: #{new_list.inspect}"
  puts "removed links: #{del_list.inspect}"
  puts "changed links: #{change_list.inspect}"
  {:new => new_list, :removed => del_list, :changes => change_list}
end

EM.run {
  EM.start_server "0.0.0.0", 7654, AddressServer
 
  EM.add_periodic_timer(2) {
    new_server_state = {}
    new_client_state = {}
    
    # check servers
    Dir["s5*"].each {|f|      
      # it can happen that we are grepping the file before the connection is 
      # made... so, wait and give a few chances....
      res = ""
      5.times do
        res = `cat #{f} | grep opened$ | tail -1 | sed "s/^.*\\[//" | sed "s/:.*$//"`[0..-2]
        if res == ""
          puts "tunnel not ready: waiting"
          sleep 1 
        else
          puts "got endpoint: #{res}"
          break
        end
      end
      iface = f.sub("s", "vi")   
      
      # XXX: what shall we do with a connection that isn't made? just don't use it.. 
      new_server_state[iface] = {:remote => res, :network => get_iface_network(iface)} unless res == ""
    }
    puts "server state: #{new_server_state.inspect}"
    # the destination ip's here are the clients that connected after the last 
    # check. They wait for a request and we need to get the id.
    server_list = diff($old_server_state, new_server_state)
    
    # remove old network from ospf
    server_list[:removed].each {|iface, data|
      remove_from_ospf(iface, data[:network])
    }
    
    # create address and update OSPF (clients don't initiate address creation)
    server_list[:new].each {|iface, data|
      # XXX: Goal asynchronous connections    
      puts "connecting to #{data[:remote]}:7654 for interface #{iface}"
      EM.connect data[:remote], 7654, CallHandler, iface
    }

    # create address and update OSPF
    server_list[:changes].each {|iface, data|
      # remove old network from ospf
      remove_from_ospf(iface, data[:network])

      # XXX: Goal asynchronous connections    
      puts "connecting to #{data[:remote]}:7654 for interface #{iface}"
      EM.connect data[:remote], 7654, CallHandler, iface      
    }
    
    $old_server_state = new_server_state
    
    #------- Now do the same thing for clients. The procedure is slightly 
    #        different!!!

    #  - check if the interface exists and if it has an address
    #  - when the client is gone, it should be removed from ospf
    #  - when the network address changed, it should be updated
    Dir["c5*"].each {|f|      
      # extract interface
      iface = f.split("-")[0].sub("c","vi")
      network = get_iface_network(iface)    
      new_client_state[iface] = {:network => network} unless network == ""
    }
    client_list = diff($old_client_state, new_client_state)

    # remove old network from ospf
    client_list[:removed].each {|iface, data|
      remove_from_ospf(iface, data[:network])
    }    
  
    $old_client_state = new_client_state
    puts "client state: #{new_client_state.inspect}"
  }
}