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
require 'csv'
require 'yaml'

module Alces
  module Packager
    class PackageRequestsHandler

      class << self

        def handle(options)

          if Process.euid != 0
            raise PermissionDeniedError, 'This command must be executed as root.'
          end

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

      delegate :say, :confirm, :doing, :title, :warning, :with_spinner, to: IoHandler

      attr_accessor :options
      def initialize(options)
        self.options = options
      end

      def list
        Alces::Packager::CLI.send(:enable_paging)
        say Terminal::Table.new(title: 'Pending installation requests',
                                headings: ['User', 'Gridware package', 'Distro package', 'Repo path', 'Date'],
                                rows: request_files.map { |rid| metadata(rid) })
      end

      def install
        rqs = request_files
        title "Processing #{rqs.length} installation request#{rqs.length != 1 ? 's' : ''}"
        rqs.each_with_index do |rq, idx|
          md = metadata(rq)

          confirm = confirm_install(rq, md)

          doing "(#{idx + 1}/#{rqs.length}) Installing #{md[2].color(:bold)}" + " on behalf of #{md[0]}".color(:cyan)
          if confirm
            if actually_install(md[2])
              File.unlink(request_file(rq))
              notify_user(md)
              DependencyUtils.whitelist_package(md[2])
              say 'Done'.color(:green)
            else
              say 'INSTALL FAILED'.color(:red)
            end
          else
            say 'NOT INSTALLED'.color(:red)
          end
        end
      end

      private

      def request_files
        return [] unless Dir.exists?(requests_dir)
        Dir.entries(requests_dir).reject do |f|
          f[0] == '.'
        end
      end

      def requests_dir
        File.join(Config.gridware, 'etc', 'package-requests')
      end

      def metadata(request_id)
        rq_file = request_file(request_id)
        CSV.read(rq_file, {col_sep: ' ', encoding: 'UTF-8'}).first.tap { |m| m << File.mtime(rq_file)}
      end

      def request_file(request_id)
        File.join(requests_dir, request_id)
      end

      def confirm_install(rqid, metadata)
        return true if options.yes

        action = $terminal.ask("\nUser #{metadata[0]} wants to install package #{metadata[2].bold}. (I)nstall, install (A)ll, (S)kip, (D)elete?") { |q| q.validate = /[IiDdSsAa]/ }

        case action.downcase
          when 'd'
            File.unlink(request_file(rqid))
            return false
          when 's'
            return false
          when 'i'
            return true
          when 'a'
            options.yes = true
            return true
          else
            return false
        end

      end

      def actually_install(package)
        with_spinner do
          system(sprintf(install_cmd, package))
        end
      end

      def install_cmd
        case cw_dist
          when /^el/
            "env -i /usr/bin/yum install -y %s >>#{Config.log_root}/depends.log 2>&1"
          when /^ubuntu/
            "/usr/bin/apt-get install -y %s >>#{Config.log_root}/depends.log 2>&1"
        end
      end

      def notify_user(metadata)
        system(
            sprintf(
                user_notify_command,
                *metadata[0..-2],
                user_email(metadata[0])
            )
        )
      end

      def user_email(username)
        fp = File.expand_path("~#{username}/gridware/etc/gridware.yml")
        if File.exists?(fp)
          user_conf = YAML.load_file(fp)
          if user_conf.has_key?(:user_email)
            return user_conf[:user_email]
          end
        end

        ''
      end

      def user_notify_command
        "#{File.join(ENV['cw_ROOT'], 'libexec', 'share', 'package-install-notify')} \"%s\" \"%s\" \"%s\" \"%s\" \"%s\""
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
