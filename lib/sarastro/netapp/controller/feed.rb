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

module VIC
  module FeedController
    def self.included(base)
      class << base
  			attr_accessor :connections, :keep_alive
      end
  	end

    def connections
      puts "connections doesn't exist" unless self.class.connections
      self.class.connections = [] unless self.class.connections
      self.class.connections
    end

    def keep_alive
      unless self.class.keep_alive
        puts "starting timer"

        # needs to run as long as the application runs
        self.class.keep_alive = EM::PeriodicTimer.new(20) { 
          connections.each {|out|
            begin
              out << "data: pong!\n\n"
            rescue
              # it can be that the connection was closed when we try to read
            end               
          } 
        }
      end
    end
  end
end
