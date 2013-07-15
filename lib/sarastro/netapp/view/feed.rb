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

module VIC
  class FeedApp < Sinatra::Base    
    include FeedController
    register HMACAuth
    
    before '/feed/*' do
      #require_hmac_authentication
    end

    # only localhost is allowed to do posts
    post '/event' do
      if request.ip =~ /127.0.0.1/        
        connections.each { |out| 
          begin
            out << "data: #{params[:msg]}\n\n" 
          rescue
            # could happen that a connection closed while we want to send
            # something
          end
        }
      end
      
      204 # response without entity body
    end
    
#    get '/feed', :provides => 'text/event-stream' do
    get '/feed' do
      keep_alive
      
      stream :keep_open do |out|                        
        connections << out
        out.callback { connections.delete(out) }
        out.errback { connections.delete(out) }
      end
    end
  end
end