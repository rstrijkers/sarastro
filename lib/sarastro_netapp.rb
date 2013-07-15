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

require 'erb'
require 'json'
require 'thin'
require 'em-hiredis'
require 'redis'
require 'sinatra/base'
require 'eventmachine'
require 'uuidtools'
require 'singleton'
require 'typhoeus'

require 'sarastro/shared/auth/hmac'
require 'sarastro/shared/auth/hmac_signer'

require 'sarastro/netapp/controller/feed'
require 'sarastro/netapp/controller/tunnel'

require 'sarastro/netapp/view/tunnel'
require 'sarastro/netapp/view/feed'
require 'sarastro/netapp/view/sarastro_netapp'