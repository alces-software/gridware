#==============================================================================
# Copyright (C) 2007-2018 Stephen F. Norledge and Alces Software Ltd.
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
require 'rugged'

module Alces
  module Git
    class << self
      def head_revision(path)
        repo = Rugged::Repository.new(path)
        repo.last_commit.oid
      end

      def sync(path, url, branch = 'master')
        if File.writable?(path) || (!File.exist?(path) && File.writable?(File.dirname(path)))
          if File.directory?(File.join(path,'.git'))
            repo = Rugged::Repository.new(path)
          else
            repo = Rugged::Repository.init_at(path)
          end
          upstream = repo.remotes['upstream']
          if upstream.nil?
            remotes = repo.remotes
            remotes.create('upstream', url)
            upstream = remotes['upstream']
          end
          upstream.fetch
          upstream_head = repo.references["refs/remotes/upstream/#{branch}"].target.oid
          analysis = repo.merge_analysis(upstream_head)
          if analysis.include?(:unborn)
            repo.reset(upstream_head, :hard)
            :created
          elsif analysis.include?(:fastforward)
            repo.reset(upstream_head, :hard)
            :updated
          elsif analysis.include?(:up_to_date)
            :uptodate
          else
            :outofsync
          end
        else
          raise "Permission denied for repository: '#{path.split('/')[-2]}'"
        end
      end
    end
  end

  class << self
    def git
      @git ||= Alces::Git
    end
  end
end
