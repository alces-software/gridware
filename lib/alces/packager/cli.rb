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
require 'commander'
require 'commander/delegates'
require 'alces/packager/handler'
require 'highline'
HighLine.colorize_strings

STDOUT.sync = true

class Commander::Runner
  def enable_paging
    Alces::Packager::CLI.send(:enable_paging)
  end
end

class HighLine
  def wrap( text, wrap_col = nil )
    wrap_col = @wrap_at if wrap_col.nil?
    wrapped = [ ]
    text.each_line do |line|
      delta = line.length - actual_length(line)
      wrap_at = wrap_col + delta
      while line =~ /([^\n]{#{wrap_at + 1},})/
        search  = $1.dup
        replace = $1.dup
        if index = replace.rindex(" ", wrap_at)
          replace[index, 1] = "\n"
          replace.sub!(/\n[ \t]+/, "\n")
          line.sub!(search, replace)
        else
          line[$~.begin(1) + wrap_at, 0] = "\n"
        end
      end
      wrapped << line
    end
    return wrapped.join
  end

  def actual_length( string_with_escapes )
    string_with_escapes.to_s.gsub(/\e\[\d{1,2}(;5;\d{1,3})?m/, "").length
  end
end

module Alces
  module Packager
    class CLI
      extend Commander::UI
      extend Commander::UI::AskForClass
      extend Commander::Delegates

      class << self
        def add_package_options(c)
          c.option '-c', '--compiler STRING', String, 'Specify compiler'
          c.option '--variant STRING', String, 'Specify variant (defaults to all)'
          c.option '-t', '--tag STRING', String, 'Specify additional build tag'
        end

        def add_depot_options(c)
          c.option '-d', '--depot STRING', String, 'Specify depot'
        end

        def add_export_options(c, command = :export)
          suffix = command == :depot ? ' [export]' : ''
          c.option '--ignore-bad', "Allow packages containing hard coded paths to be exported#{suffix}"
          c.option '--accept-bad PATTERN(S)', String, "Allow packages containing hard coded paths in matching files to be exported (comma-separated glob patterns)#{suffix}"
          c.option '--accept-elf', "Allow ELF files with acceptable hard coded search path to be exported#{suffix}"
          c.option '--patch-binary PATTERN(S)', String, "Patch binary files containing hard coded paths in matching files (comma-separated glob patterns)#{suffix}"
        end

        def set_aliases(target, opts = {})
          opts = {min: 1}.merge(opts)
          s = target.to_s
          (s.length - 2).downto(opts[:min] - 1) do |n|
            alias_command s[0..n].to_sym, target
          end
          if opts.key?(:extra)
            case opts[:extra]
            when Array
              opts[:extra].each do |e|
                alias_command e.to_sym, target
              end
            when Symbol, String
              alias_command opts[:extra].to_sym, target
            end
          end
        end

        alias :original_enable_paging :enable_paging
        def enable_paging
          original_enable_paging unless ":#{ENV['cw_FLAGS']}:" =~ /nopager/
        end
      end

      if $stdin.tty?
        term_width = HighLine::SystemExtensions.terminal_size.first rescue 80
        $terminal.wrap_at = (term_width < 80 ? 80 : term_width) - 5
      end

      program :name, 'alces gridware'
      program :version, '1.0.0'
      program :description, 'Compile and install gridware for local environment.'

      global_option '--yes', 'Answer positively to any confirmations (DANGEROUS)'
      global_option '--non-interactive', 'Don\'t require terminal interaction'
      global_option '--verbose', 'Be verbose'

      command :list do |c|
        c.syntax = 'alces gridware list'
        c.description = 'Lists available packages'
        c.action HandlerProxy, :list
        c.option '-f', '--full', 'List full details'
        c.option '-1', '--oneline', 'List one package per line'
      end
      set_aliases(:list, extra: :ls)

      command :search do |c|
        c.syntax = 'alces gridware search'
        c.description = 'Search available packages'
        c.action HandlerProxy, :search
        c.option '-f', '--full', 'List full details'
        c.option '-1', '--oneline', 'List one package per line'
        c.option '-g', '--groups', 'Search package groups'
        c.option '-d', '--descriptions', 'Search package summaries and descriptions'
        c.option '-n', '--names', 'Search package names'
      end
      set_aliases(:search)

      command :info do |c|
        c.syntax = 'alces gridware info <package>'
        c.description = 'Display information about <package>'
        c.action HandlerProxy, :info
      end
      set_aliases(:info, min: 3, extra: [:show, :sho, :sh])

      command :install do |c|
        c.syntax = 'alces gridware install <package> [<param>=<value> [...]]'
        c.description = 'Install <package> with optional parameters'
        c.action HandlerProxy, :install
        add_package_options(c)
        add_depot_options(c)
        c.option '-g', '--global', 'Allow use of packages across all depots'
        c.option '-m', '--modules STRING', String, 'Specify modules to load before build'
        c.option '-l', '--latest', 'Install latest if multiple versions of package available'
        c.option '-b', '--[no-]binary', 'Toggle use of binary packages when available'
        c.option '--[no-]defaults', 'Toggle use of default parameters for package builds'
        c.option '--binary-depends', 'Prefer binary packages for dependencies when available'
        c.option '--binary-only', 'Fail if a binary package is not available'
      end
      set_aliases(:install, min: 3)

      command :purge do |c|
        c.syntax = 'alces gridware purge <package>'
        c.description = 'Purge installation and remove build directory for <package>'
        add_depot_options(c)
        c.action HandlerProxy, :purge
      end
      set_aliases(:purge, extra: :rm)

      command :clean do |c|
        c.syntax = 'alces gridware clean <package>'
        c.description = 'Remove build directory for <package>'
        add_depot_options(c)
        c.action HandlerProxy, :clean
      end
      set_aliases(:clean)

      command :update do |c|
        c.syntax = 'alces gridware update [REPO]'
        c.description = "Update repository cache for REPO (defaults to 'base')"
        c.action HandlerProxy, :update
      end
      set_aliases(:update)

      command :default do |c|
        c.syntax = 'alces gridware default <package path>'
        c.description = "Set package at <package path> as default"
        add_depot_options(c)
        c.action HandlerProxy, :default
      end
      set_aliases(:default, min: 3)

      command :depot do |c|
        c.syntax = 'alces gridware depot <operation> [<param>]'
        c.option '-o', '--output DIRECTORY', 'Write exported depot to directory (default: /tmp/<depot>) [export]'
        c.option '--[no-]packages', "Toggle package export (default: true) [export]"
        add_export_options(c, :depot)
        c.option '--disabled', "Don't enable depot [init, install]"
        c.option '-c', '--compile', "Compile depot content from source [install]"
        c.option '-d', '--depot STRING', String, 'Specify target depot [install]'
        c.option '-g', '--global', 'Allow use of packages across all depots when resolving missing dependencies [install]'
        c.option '-b', '--binary', 'Prefer binary downloads when resolving missing dependencies [install]'
        c.option '--[no-]defaults', 'Toggle use of default parameters for package builds [install]'
        c.option '--binary-only', 'Fail if a binary package is not available [install]'
        c.option '-1', '--oneline', 'List one depot per line [list]'
        c.option '--[no-]notify', "(Dis)allow clusterware notifications (default: allow) [init, install, enable, disable, purge]"
        c.summary = "Perform a depot operation"
        c.description = <<-EOF
Perform a depot operation. Supported operations:

  disable <depot> Disable <depot> making contained packages unavailable
  enable <depot>  Enable <depot> making contained packages available
  export <depot>  Export <depot>
  info <depot>    Display information about <depot>
  init <depot>    Initialize new empty <depot>
  install <depot> Install <depot>
  list            List available depots
  purge <depot>   Remove installed <depot> and contained packages
  update [<repo>] Update list of available depots (for <repo>)
        EOF
        c.action HandlerProxy, :depot
      end
      set_aliases(:depot, min: 3)

      command :requires do |c|
        c.syntax = 'alces gridware requires <package>'
        c.description = "Display requirements for package <package>"
        c.action HandlerProxy, :requires
        add_package_options(c)
        add_depot_options(c)
        c.option '--tree', 'Display dependency tree for package'
        c.option '--ignore-satisfied', 'Only display unsatisfied dependencies'
      end
      set_aliases(:requires, extra: :reqs, min: 4)

      command :export do |c|
        c.syntax = 'alces gridware export <package path>'
        c.description = "Export gridware package <package path> to a tarball"
        add_depot_options(c)
        add_export_options(c)
        c.option '-o', '--output DIRECTORY', String, 'Directory to which exported package should be written'
        c.action HandlerProxy, :export
      end
      set_aliases(:export)

      command :import do |c|
        c.syntax = 'alces gridware import <archive file>'
        c.description = "Import gridware package held in tarball <archive file> to a depot"
        c.option '-c', '--compile', "Compile dependencies from source even if binaries available"
        add_depot_options(c)
        c.action HandlerProxy, :import
      end
      set_aliases(:import, min: 2)

      command :dependencies do |c|
        c.syntax = 'alces gridware dependencies <package> [<package> [...]]'
        c.description = 'Install dependencies from the distribution\'s package manager for Gridware packages'
        c.action HandlerProxy, :distro_deps
        c.option '-p', '--phase STRING', String, 'Phase to install dependencies for (e.g. build, runtime)'
      end
      set_aliases(:dependencies, min: 4, extra: :deps)

      command :requests do |c|
        c.syntax = 'alces gridware requests <operation>'
        c.summary = 'Perform operations on distribution package installation requests'
        c.description = <<-EOF
Perform operations on distribution package installation requests. Supported operations:

  list     List all pending installation requests
  install  Install requested packages
        EOF
        c.action HandlerProxy, :package_requests
      end
      set_aliases(:requests, min: 4, extra: :rq)
    end
  end
end
