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

require 'pp'

module VIC
  class SarastroNetappApp < Sinatra::Base
    use TunnelApp
    use FeedApp
    register HMACAuth   
    
    before '/auth*' do      
      require_hmac_authentication
    end
    
    get '/auth' do
      File.read(File.join('./public/', 'index.html'))
    end

#    get '/static/:file' do
#      send_file "./public/#{params[:file]}"
#    end      
    
    get '/static/up' do
      [200, {}, "alive"]
    end  
  end
end