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
require 'date'

require 'alces/tools/logging'
require 'alces/tools/execution'
require 'alces/packager/config'
require 'alces/packager/depot'
require 'alces/packager/repository'
require 'alces/packager/actions'
require 'alces/packager/archive_exporter'
require 'alces/packager/archive_importer'
require 'alces/packager/errors'
require 'alces/packager/io_handler'
require 'alces/packager/dependency_handler'
require 'alces/packager/depot_handler'
require 'alces/packager/distro_deps_handler'
require 'alces/packager/package_requests_handler'
require 'alces/packager/option_set'
require 'terminal-table'
require 'memoist'
require 'alces/packager/display_handler'
require 'alces/packager/definition_handler'

Alces::Tools::Logging.default = Alces::Tools::Logger.new(File::expand_path(File.join(Alces::Packager::Config.log_root,'packager.log')),
                                                         :progname => 'packager',
                                                         :formatter => :full)

module Alces
  module Packager
    class HandlerProxy
      ACTIONS_REQUIRING_PACKAGE_REPO_UPDATE = [
        :import,
        :info,
        :install,
        :list,
        :requires,
        :search
      ]

      def method_missing(s,*a,&b)
        if Handler.instance_methods.include?(s)
          handle_action(s, a)
        else
          super
        end
      rescue Alces::Tools::CLI::BadOutcome
        say "#{'ERROR'.underline.color(:red)}: #{$!.message}"
        exit(1)
      rescue Interrupt
        say "\n#{'WARNING'.underline.color(:yellow)}: Cancelled by user"
        exit(130)
      end

      private

      def handle_action(action, args)
        Bundler.with_clean_env do
          @handler = Handler.new(*args)
          if action_requires_package_repo_update?(action)
            update_package_repositories
          end
          @handler.send(action)
        end
      end

      def action_requires_package_repo_update?(action)
        ACTIONS_REQUIRING_PACKAGE_REPO_UPDATE.include? action
      end

      def update_package_repositories
        repos_requiring_update = Repository.requiring_update
        say_repos_requiring_update_message(repos_requiring_update)
        repos_requiring_update.map do |repo|
          @handler.update_repository(repo)
        end
      end

      def say_repos_requiring_update_message(repos_requiring_update)
        if repos_requiring_update.any?
          num_repos = repos_requiring_update.length
          repo_needs_str = num_repos  > 1 ? 'repositories need' : 'repository needs'
          say "#{repos_requiring_update.length} #{repo_needs_str} to update ..."
        end
      end
    end

    class Handler
      extend Memoist

      include Alces::Tools::Logging
      include Alces::Tools::Execution

      attr_accessor :options

      delegate :doing, :colored_path, :to => IoHandler

      def initialize(args, options)
        self.options = OptionSet.new(options)
        self.options.args = args
        if ":#{ENV['cw_FLAGS']}:" =~ /nocolou?r/ || ENV['cw_COLOUR'] == '0'
          HighLine.use_color = false
        end
      end

      def list
        DisplayHandler.list(options)
      end

      def search
        DisplayHandler.search(options)
      end

      def info
        DisplayHandler.info(options)
      end

      def export
        with_depot do
          raise MissingArgumentError, 'Please supply a package path' if package_path.nil? || !package_path.include?('/')
          ArchiveExporter.export(package_path, options)
        end
      end

      def import
        with_depot do
          raise MissingArgumentError, 'Please supply path to archive' if package_path.nil?
          ArchiveImporter.import(nil, package_path, options)
        end
      end

      def depot
        raise MissingArgumentError, 'Please supply the depot operation' if options.args.empty?
        DepotHandler.handle(options)
      end

      def purge
        with_depot do
          with_live_package do |package|
            say "Purging #{colored_path(package)}"
            Actions.purge(package, action_opts, IoHandler)
          end
        end
      end

      def clean
        with_depot do
          begin
            with_live_package do |package|
              say "Cleaning up #{colored_path(package)}"
              Actions.clean(package, action_opts, IoHandler)
            end
          rescue
            with_definition do |defn|
              say "Cleaning up #{colored_path(defn)}"
              opts = action_opts.tap do |o|
                o[:compiler] = (options.compiler == :first ? defn.compilers.keys.first : options.compiler)
              end
              Actions.clean(defn, opts, IoHandler)
            end
          end
        end
      end

      def update
        # update the specified repo, or 'main' if none specified
        repo_name = options.args.first || 'main'
        repo = Repository.find { |r| r.name == repo_name }
        raise NotFoundError, "Repository #{repo_name} not found" if repo.nil?
        update_repository(repo)
      end

      def update_repository(repo)
        say "Updating repository: #{repo.name}"
        doing 'Update'
        begin
          status, rev = repo.update!
          case status
          when :ok
            say "#{'OK'.color(:green)} (At: #{rev})"
          when :uptodate
            say "#{'OK'.color(:green)} (Up-to-date: #{rev})"
          when :not_updateable
            say "#{'SKIP'.color(:yellow)} (Not updateable, no remote configured)"
          when :outofsync
            say "#{'SKIP'.color(:yellow)} (Out of sync: #{rev})"
          when :nopermission
            say "#{'SKIP'.color(:yellow)} (No permission)"
          end
        rescue
          say "#{'FAIL'.color(:red)} (#{$!.message})"
        end
      end

      def default
        with_depot do
          # set the specified package as default
          if package_path.nil?
            raise MissingArgumentError, 'Please supply a package path'
          end
          package_parts = package_path.split('/')
          package_prefix = package_parts[0..-2].join('/')
          version = package_parts.last
          package = Package.first(path: package_path) || Version.first(path: package_prefix, version: version)
          raise NotFoundError, "Package '#{colored_path(package_path)}' not found" if package.nil?
          Actions.set_default(package, action_opts, IoHandler)
        end
      end

      def install
        with_depot do
          with_definition do |defn|
            DefinitionHandler.install(defn, options)
          end
        end
      end

      def requires
        with_depot do
          with_definition do |defn|
            DefinitionHandler.requires(defn, options)
          end
        end
      end

      def distro_deps
        with_depot do
          with_definition do |defn|
            DistroDepsHandler.install(defn, options)
          end
        end
      end

      def package_requests
        raise MissingArgumentError, 'Please supply an operation' if options.args.empty?
        PackageRequestsHandler.handle(options)
      end

      private
      def with_definition(&block)
        with_resource(definitions, &block)
      end

      def with_live_package(&block)
        with_resource(packages, &block)
      end

      def with_resource(collection, &block)
        if package_path.nil?
          raise MissingArgumentError, 'Please supply a package name'
        end
        if collection.length == 0
          raise NotFoundError, "No matching package found for: #{package_path}"
        elsif options.latest
          block.call(collection.last)
        elsif collection.length > 1
          l = collection.map {|p| colored_path(p) }
          say "More than one matching package found, please choose one of:"
          say $terminal.list(l,:columns_across)
        else
          block.call(collection.first)
        end
      end

      def with_depot(&block)
        if d = Depot.find(options.depot)
          if d.enabled?
            DataMapper.repository(options.depot, &block)
          else
            raise DepotError, "Depot is not enabled: #{options.depot}"
          end
        else
          raise NotFoundError, "Could not find depot: #{options.depot}"
        end
      end

      def action_opts
        {
          compiler: options.compiler,
          variant: options.variant,
          verbose: options.verbose,
          noninteractive: (options.yes ? :force : options.non_interactive),
          tag: options.tag,
          depot: options.depot,
          global: options.global
        }
      end

      def package_path
        @package_path ||= options.args.first
      end

      def definitions
        @definitions ||= Metadata.sort(Repository.find_definitions(package_path || '*'))
      end

      def packages
        @packages ||= begin
                        ps = Package.all(:path.like => "#{package_path}")
                        ps.empty? ? Package.all(:path.like => "#{package_path}%") : ps
                      end
      end
    end
  end
end
