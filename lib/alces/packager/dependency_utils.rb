require 'yaml'

module Alces
  module Packager
    class DependencyUtils
      class << self

        def generate_dependency_script(package_path, phase)
          %(#!/bin/bash
#=Alces-Gridware-Dependencies:2
if [ $UID -ne 0 ]; then
  SUDO='sudo -E cw_GRIDWARE_userspace=#{ENV['cw_GRIDWARE_userspace']}'
fi
${SUDO} #{ENV['cw_ROOT']}/bin/alces gridware dependencies #{strip_variant(package_path)} --phase #{phase} --non-interactive)
        end

        def whitelist
          @whitelist ||= empty_whitelist.merge(whitelist_from_file)
        end

        def whitelist_package(pkg)
          my_wl = whitelist

          return whitelist if my_wl[:packages].include?(pkg)

          my_wl[:packages] << pkg
          File.open(whitelist_file, 'w') do |wf|
            wf.write(my_wl.to_yaml)
          end

          @whitelist = my_wl
        end

        private

        def strip_variant(package_path)
          # In the second-to-last component of the path (e.g. allow _ in version)
          # remove _ and everything subsequent up until the next /
          # This assumes we always get a full package path including version...
          package_path.gsub(/_[^\/]+(\/[^\/]+)$/, '\1')
        end

        def whitelist_from_file
          YAML.load_file(whitelist_file) rescue {}
        end

        def whitelist_file
          File.join(Config.gridware, 'etc', 'whitelist.yml')
        end

        def empty_whitelist
          { users: [], packages: [], repos: [] }
        end

      end
    end
  end
end
