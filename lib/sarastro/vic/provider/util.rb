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

module VIC
  module Util
    # @public_ip_address[String]
    # @credentials[Hash]
    # @timeout[Integer] default 30 seconds
    # @interval[Integer] default 1 second    
    def wait_for(blk, timeout=30, interval=1) {
      timer = EM::PeriodicTimer.new(interval) do
        timer.cancel if blk.call
        timer.cancel if (timeout-=1) < 0
      end  
    end
    
    def sshable?(public_ip_address, username, credentials)
        begin
          Fog::SSH.new(public_ip_address, username, credentials).run('pwd')
        rescue Errno::ECONNREFUSED
          # next tick
        rescue Net::SSH::AuthenticationFailed
          timer.cancel                           
        end
        false
    end    
  end
end
