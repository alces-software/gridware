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
require 'alces/packager/dependency_utils'

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
        if Process.euid != 0
          warning 'This command must be executed with sudo.'
        else
          install_deps
        end
      end

      private

      def install_deps
        packages_without_permission = []
        required_distro_packages.each do |pkg|
          maybe_doing pkg
          if installed?(pkg)
            maybe_say 'already installed'.color(:green)
            DependencyUtils.whitelist_package(pkg) if user_is_root
          elsif available?(pkg)
            if have_permission_to_install?(pkg)
              installed_ok = false
              with_spinner do
                installed_ok = system(sprintf(DependencyUtils.install_command, pkg))
              end
              if installed_ok
                DependencyUtils.whitelist_package(pkg) if user_is_root
                maybe_say 'OK'.color(:green)
              else
                say 'FAILED'.color(:red)
              end
            else
              say 'PERMISSION DENIED'.color(:red)
              packages_without_permission << pkg
              STDERR.puts "Permission denied when trying to install #{pkg}"
              make_install_request(pkg)

            end
          else
            raise NotFoundError, "Package #{pkg} is required but not available."
          end
        end
        if !packages_without_permission.empty?
          STDERR.puts 'Some packages failed to install. A request has been filed with your system administrator.'
          raise PermissionDeniedError, 'Some packages failed to install. A request has been filed with your system administrator.'
        end
      end

      def required_distro_packages
        deps_hashes = [].tap do |a|
          if defn.metadata[:dependencies]
            if defn.metadata[:dependencies][options.phase.to_sym]
              a << defn.metadata[:dependencies][options.phase.to_sym]
              if options.phase.to_sym == :build && defn.metadata[:dependencies].key?(:runtime)
                a << defn.metadata[:dependencies][:runtime]
              end
            else
              a << defn.metadata[:dependencies]
            end
          end
        end

        deps = deps_hashes.map do |deps_hash|
          [*deps_hash[DependencyUtils.stem]] + [*deps_hash[ENV['cw_DIST']]]
        end.flatten

        return deps
      end

      def installed?(pkg)
        return system(sprintf(DependencyUtils.check_command, pkg))
      end

      def available?(pkg)
        return system(sprintf(DependencyUtils.available_command, pkg))
      end

      def have_permission_to_install?(pkg)
        allow_all || user_whitelisted || package_whitelisted(pkg) || repo_whitelisted
      end

      def user_whitelisted
         user_is_root || whitelist[:users].include?(ENV['SUDO_USER'])
      end

      def user_is_root
        Process.uid == 0 && !ENV.has_key?('SUDO_USER')
      end

      def package_whitelisted(pkg)
        whitelist[:packages].include?(pkg)
      end

      def repo_whitelisted
        whitelist[:repos].include?(defn.repo.path)
      end

      def allow_all
        whitelist[:allow_all] || false
      end

      def make_install_request(pkg)
        system(
          sprintf(
            install_request_command,
            ENV['SUDO_USER'],
            defn.name,
            pkg,
            defn.repo.path
          )
        )
      end

      def install_request_command
        "#{File.join(ENV['cw_ROOT'], 'libexec', 'share', 'distro-deps-notify')} \"%s\" \"%s\" \"%s\" \"%s\""
      end

      def whitelist
        DependencyUtils.whitelist
      end

      def maybe_doing(text)
        doing(text) unless self.options.non_interactive
      end

      def maybe_say(text)
        say(text) unless self.options.non_interactive
      end

    end
  end
end

