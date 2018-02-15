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
require 'yaml'
require 'alces/tools/logging'
require 'alces/tools/config'
require 'alces/packager/metadata'
require 'alces/git'

class ::Hash
  def deep_merge!(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
    self.merge!(second.to_h, &merger)
  end
end

module Alces
  module Packager
    class Repository < Struct.new(:path)
      class InvalidRepo < StandardError; end

      DEFAULT_CONFIG = {
        repo_paths: ['/opt/clusterware/installer/local/'],
      }

      class << self
        include Enumerable

        def config
          @config ||= DEFAULT_CONFIG.dup.tap do |h|
            cfgfile = Alces::Tools::Config.find("gridware.#{ENV['cw_DIST']}", false) ||
                      Alces::Tools::Config.find("gridware", false)
            h.merge!(YAML.load_file(cfgfile)) unless cfgfile.nil?

            if Config.userspace?
              user_cfgfile = File.expand_path("~#{ENV['cw_GRIDWARE_userspace']}/.config/gridware/gridware.yml")
              user = YAML.load_file(user_cfgfile) rescue {}
              check_user_config(h, user)
              h.deep_merge!(user) if File.exists?(user_cfgfile)
            end
          end
        end

        def check_user_config(global, user)
          global_repos = global[:repo_paths].map { |rp| File.basename(rp) }
          if user[:repo_paths]
            user[:repo_paths].each do |urp|
              urn = File.basename(urp)
              if global_repos.include?(urn)
                raise ConfigurationError, "User repo #{urp} conflicts with system-wide repo with the same name (#{urn}). Please correct your configuration in ~/.config/gridware/gridware.yml."
              end
            end
          end
        end

        def method_missing(s,*a,&b)
          if config.has_key?(s)
            config[s]
          else
            super
          end
        end

        def each(&block)
          all.each(&block)
        end

        def [](k)
          all[k]
        end

        def exists?(k)
          all.key?(k)
        end

        def all
          @all ||= repo_paths.map { |path| new(path) }
        end

        def requiring_update
          select do |repo|
            repo.last_update + Config.update_period < DateTime.now
          end
        end

        def find_definitions(a)
          map do |r|
            r.packages.select do |p|
              if (parts = a.split('/')).length == 1
                File.fnmatch?(a, p.name, File::FNM_CASEFOLD)
              elsif parts.length == 2
                # one of repo/type, type/name or name/version
                File.fnmatch?(a, "#{p.repo.name}/#{p.type}", File::FNM_CASEFOLD) || File.fnmatch?(a, "#{p.type}/#{p.name}", File::FNM_CASEFOLD) || File.fnmatch?(a, "#{p.name}/#{p.version}", File::FNM_CASEFOLD)
              elsif parts.length == 3
                # one of repo/type/name or type/name/version
                File.fnmatch?(a, "#{p.repo.name}/#{p.type}/#{p.name}", File::FNM_CASEFOLD) || File.fnmatch?(a, "#{p.type}/#{p.name}/#{p.version}", File::FNM_CASEFOLD)
              elsif parts.length == 4
                if File.fnmatch?(a, p.path, File::FNM_CASEFOLD)
                  true
                end
              end
            end
          end.flatten
        end
      end

      include Alces::Tools::Logging

      attr_accessor :package_path

      def initialize(path)
        self.path = File.expand_path(path)
        self.package_path = File.join(self.path,'pkg')
      end

      def metadata
        @metadata ||= load_metadata
      end

      def name
        @name ||= File.basename(path)
      end

      def empty?
        !File.directory?(path) || packages.empty?
      end

      def descriptor
        if metadata.key?(:source)
          "git+#{metadata[:source]}@#{head_revision}"
        else
          "file:#{path}"
        end
      end

      def packages
        @packages ||= load_packages
      end

      def update!
        return [:nopermission, nil] unless File.stat(path).writable?
        if metadata.key?(:source)
          case r = Alces.git.sync(repo_path, metadata[:source])
          when :created, :updated
            set_last_update
            # force reload of packages if needed
            @packages = nil
            [:ok, head_revision]
          when :outofsync
            [:outofsync, head_revision]
          when :uptodate
            set_last_update
            [:uptodate, head_revision]
          else
            raise "Unrecognized response from synchronization: #{r.chomp}"
          end
        else
          set_last_update
          [:not_updateable, nil]
        end
      rescue
        raise "Unable to sync repo: '#{name}' (#{$!.message})"
      end

      def last_update
        if File.exists?(last_update_file)
          datetime_str = File.readlines(last_update_file).first
          DateTime.parse(datetime_str)
        else
          # Return earliest possible datetime so update will (probably) run
          # when next needed.
          DateTime.new
        end
      end

      def last_update=(datetime)
        File.open(last_update_file, 'w') do |file|
          file.write(datetime)
        end
      end

      private
      def repo_path
        @repo_path ||= metadata[:schema] == 1 ? package_path : path
      end

      def head_revision
        Alces.git.head_revision(repo_path)[0..6] rescue 'unknown'
      end

      def load_packages
        info "Loading repo from path: #{path}"
        if File.directory?(package_path)
          Dir[File.join(package_path,'**','metadata.yml')].map do |f|
            begin
              if (parts = f.gsub(package_path,'').split('/')).length > 4
                name, version = parts[-3..-2]
              else
                name = parts[-2]
                version = nil
              end
              yaml = File.read(f, encoding: 'utf-8')
              metadata = YAML.load(yaml)
              checksum = Digest::MD5.hexdigest(yaml)
              Metadata.new(name, version, metadata, checksum, self)
            rescue Psych::SyntaxError
              raise "Unable to parse: #{f} (#{$!.class.name}: #{$!.message})"
            rescue
              raise "Unable to parse: #{f} (#{$!.class.name}: #{$!.message})"
            end
          end
        else
          []
        end
      end

      def load_metadata
        if File.exists?("#{path}/repo.yml")
          YAML.load_file("#{path}/repo.yml")
        else
          {}
        end
      end

      def last_update_file
        File.join(path, Config.last_update_filename)
      end

      def set_last_update
        self.last_update = DateTime.now
      end
    end
  end
end
