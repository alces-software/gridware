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
require 'memoist'

module Alces
  module Packager
    class DistroDepsHandler
      extend Memoist
      include Alces::Tools::Logging

      class << self
        def install(*a)
          new(*a).install
        end
      end

      delegate :say, :warning, :to => IoHandler

      attr_accessor :defn, :options
      def initialize(defn, options)
        self.defn = defn
        self.options = options
      end

      def install
        if ENV['cw_GRIDWARE_userspace'] == 'true'
          warning 'This command must be executed with sudo.'
        else
          install_deps
        end
      end

      private

      def install_deps
        p required_distro_packages
      end

      def required_distro_packages
        deps_hashes = [].tap do |a|
          if defn.metadata[:dependencies][options.phase]
            a << defn.metadata[:dependencies][options.phase]
            if options.phase == :build && defn.metadata[:dependencies].key?(:runtime)
              a << defn.metadata[:dependencies][:runtime]
            end
          else
            a << defn.metadata[:dependencies]
          end
        end

        deps = deps_hashes.map do |deps_hash|
          [*deps_hash[stem]] + [*deps_hash[ENV['cw_DIST']]]
        end.flatten

        return deps
      end

      def install_cmd
        case cw_dist
          when /^el/
            "/usr/bin/yum install -y %s >>#{Config.log_root}/depends.log 2>&1"
          when /^ubuntu/
            "/usr/bin/apt-get install -y %s >>#{Config.log_root}/depends.log 2>&1"
        end
      end

      def stem
        case cw_dist
          when /^el/
            'el'
          when /^ubuntu/
            'ubuntu'
        end
      end

      def cw_dist
        @cw_dist ||= if !ENV['cw_DIST']
            warning 'cw_DIST environment variable not set, defaulting to el7'
          'el7'
        else
          ENV['cw_DIST']
        end
      end

    end
  end
end

