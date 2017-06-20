#==============================================================================
# Copyright (C) 2017 Stephen F. Norledge and Alces Software Ltd.
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
module Alces
  module Packager
    class PackageRequestsHandler

      class << self
        def handle(options)
          ENV['cw_GRIDWARE_notify'] = 'false' unless options.notify
          handler_opts = OptionSet.new(options)
          op = options.args.first
          handler_opts.args = options.args[1..-1]
          @handler = new(handler_opts)
          instance_methods(false).each do |m|
            if is_method_shortcut(op, m)
              @handler.send(m)
              return
            end
          end
          raise InvalidParameterError, "Unrecognised installation request operation: #{op}"
        end

        def is_method_shortcut(operation, method_identifier)
          is_prefix = method_identifier =~ /^#{Regexp.escape(operation)}/
          is_list_shortcut = method_identifier == :list && operation == 'ls'
          is_prefix || is_list_shortcut
        end
      end

      attr_accessor :options
      def initialize(options)
        self.options = options
      end

    end
  end
end
