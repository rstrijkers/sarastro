#!/usr/bin/env ruby
#
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

require 'sarastro_netapp'

Thin::Logging.debug=:log
$root_dir = File.dirname(__FILE__)

# Signal.trap("TERM") do
#     puts "Terminating..."
#     NetappApp.kill
#     exit
# end
# 

EM.threadpool_size = 50
REDIS = Redis.new
REDIS.del("port:taken")
REDIS.del("tap:taken")

EM.run {
  Rack::Handler::Thin.run VIC::SarastroNetappApp, :Port => 4567
}