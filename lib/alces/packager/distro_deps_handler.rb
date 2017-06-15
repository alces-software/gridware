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
require 'yaml'

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

      delegate :doing, :say, :warning, :with_spinner, :to => IoHandler

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
        packages_without_permission = []
        required_distro_packages.each do |pkg|
          doing pkg
          if installed?(pkg)
            say 'already installed'.color(:green)
          elsif available?(pkg)
            if have_permission_to_install?(pkg)
              installed_ok = false
              with_spinner do
                installed_ok = system(sprintf(install_cmd, pkg))
              end
              if installed_ok
                say 'OK'.color(:green)
              else
                say 'FAILED'.color(:red)
              end
            else
              say 'PERMISSION DENIED'.color(:red)
              packages_without_permission << pkg
            end
          else
            raise NotFoundError, "Package #{pkg} is required but not available."
          end
        end
        if !packages_without_permission.empty?
          raise PermissionDeniedError, 'Some packages failed to install. Please contact your system administrator.'
        end
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

      def installed?(pkg)
        return system(sprintf(check_command, pkg))
      end

      def available?(pkg)
        return system(sprintf(available_command, pkg))
      end

      def have_permission_to_install?(pkg)
        user_whitelisted || package_whitelisted(pkg) || repo_whitelisted
      end

      def user_whitelisted
        whitelist[:users].include?(ENV['SUDO_USER'])
      end

      def package_whitelisted(pkg)
        whitelist[:packages].include?(pkg)
      end

      def repo_whitelisted
        whitelist[:repos].include?(defn.repo.path)
      end

      def install_cmd
        case cw_dist
          when /^el/
            "/usr/bin/yum install -y %s >>#{Config.log_root}/depends.log 2>&1"
          when /^ubuntu/
            "/usr/bin/apt-get install -y %s >>#{Config.log_root}/depends.log 2>&1"
        end
      end

      def check_command
        case cw_dist
          when /^el/
            'rpm -q %s >/dev/null 2>/dev/null'
          when /^ubuntu/
            'dpkg -l %s >/dev/null 2>/dev/null'
        end
      end

      def available_command
        case cw_dist
          when /^el/
            'env -i yum info %s >/dev/null 2>/dev/null'
          when /^ubuntu/
            'apt-cache show %s >/dev/null 2>/dev/null'
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

      def whitelist
        @whitelist ||= empty_whitelist.merge(whitelist_from_file)
      end

      def whitelist_from_file
        YAML.load_file(File.join(Config.gridware, 'etc', 'whitelist.yml')) rescue {}
      end

      def empty_whitelist
        { users: [], packages: [], repos: [] }
      end

    end
  end
end

