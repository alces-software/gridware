module Alces
  module Packager
    class DependencyUtils
      class << self

        def generate_dependency_script(package_path, phase)
          %(#=Alces-Gridware-Dependencies:2
cw_GRIDWARE_userspace=#{ENV['cw_GRIDWARE_userspace']}
sudo -E #{ENV['cw_ROOT']}/bin/alces gridware distro_deps #{strip_variant(package_path)} --phase #{phase})
        end

        private

        def strip_variant(package_path)
          # In the second-to-last component of the path (e.g. allow _ in version)
          # remove _ and everything subsequent up until the next /
          # This assumes we always get a full package path including version...
          package_path.gsub(/_[^\/]+(\/[^\/]+)$/, '\1')
        end

      end
    end
  end
end
