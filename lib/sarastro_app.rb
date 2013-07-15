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

require 'net/http'
require 'uri'
require 'erb'
require 'json'
require 'thin'
require 'em-hiredis'
require 'redis'
require 'fog'
require 'fiber'
require 'rest-client'
require 'sinatra/base'
require 'eventmachine'
require 'rack/openid'
require 'uuidtools'
require 'singleton'
require 'tempfile'
require 'typhoeus'
require 'observer'

require 'sarastro/shared/util'
require 'sarastro/shared/uuid'
require 'sarastro/shared/auth/openid'
require 'sarastro/shared/auth/hmac'
require 'sarastro/shared/auth/hmac_signer'
require 'sarastro/shared/jobqueue'

require 'sarastro/vic/app/task'

require 'sarastro/vic/provider/ec2'
require 'sarastro/vic/provider/bbox'
require 'sarastro/vic/provider/query'

require 'sarastro/vic/model/cp'

require 'sarastro/vic/controller/cp'
require 'sarastro/vic/controller/netapp'
require 'sarastro/vic/controller/vic'

require 'sarastro/vic/model/vi' # rather an anomaly... shouldn't use the controller

require 'sarastro/vic/view/cp'
require 'sarastro/vic/view/vic'
require 'sarastro/vic/view/netapp'

require 'sarastro/vic/view/sarastro_app'


