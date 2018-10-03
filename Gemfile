#==============================================================================
# Copyright (C) 2007-2015 Stephen F. Norledge and Alces Software Ltd.
#
# This file/package is part of Alces Clusterware.
#
# Alces Clusterware is free software: you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# Alces Clusterware is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this package.  If not, see <http://www.gnu.org/licenses/>.
#
# For more information on the Alces Clusterware, please visit:
# https://github.com/alces-software/clusterware
#==============================================================================
source 'http://rubygems.org'
source 'http://gems.alces-software.com'

# The vanilla version of 'do' has a ::Fixnum deprecation warning, the vhost-api
# fork removes the use of ::Fixnum and replaces it with Integer
gem 'data_objects', git: 'https://github.com/vhost-api/do'

gem 'alces-tools', '>= 0.13.0'
gem 'commander'
gem 'terminal-table'
gem 'rugged'
gem 'dm-rest-adapter', '1.3.0.alces0'
gem 'dm-sqlite-adapter', '>= 1.2.0'
gem 'dm-migrations', '>= 1.2.0'
gem 'dm-aggregates', '>= 1.2.0'
gem 'memoist'

# Forked of a fork containing a logger fix. The main gem can be used
# again once StructuredWarnings is removed
gem 'rubytree', git: 'https://github.com/alces-software/RubyTree'

group :test do
  gem 'minitest'
  gem 'mocha'
  gem 'bourne'
end
