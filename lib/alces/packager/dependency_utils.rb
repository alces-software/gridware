module Alces
  module Packager
    class DependencyUtils
      class << self

        def generate_dependency_script(package_path, phase)
          %(#=Alces-Gridware-Dependencies:2
cw_GRIDWARE_userspace=#{ENV['cw_GRIDWARE_userspace']}
sudo -E #{ENV['cw_ROOT']}/bin/alces gridware distro_deps #{package_path} --phase #{phase})
        end

      end
    end
  end
end
