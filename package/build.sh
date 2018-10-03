#!/bin/bash
set -e

package_name='gridware-common'

cw_ROOT="${cw_ROOT:-/opt/clusterware}"
PATH="${cw_ROOT}"/opt/git/bin:"${cw_ROOT}"/opt/ruby/bin:$PATH

if [ -f ./${package_name}.zip ]; then
  echo "Replacing existing ${package_name}.zip in this directory"
  rm ./${package_name}.zip
fi

temp_dir=$(mktemp -d /tmp/${package_name}-build-XXXXX)

cp -r * "${temp_dir}"
mkdir -p "${temp_dir}"/data/opt/gridware

echo "Creating Forge package of Gridware from git rev $(git rev-parse --short HEAD)"

yum install -y gcc-c++ gmp-devel sqlite-devel cmake libcurl-devel openssl-devel

pushd .. > /dev/null
git archive HEAD | tar -x -C "${temp_dir}"/data/opt/gridware
popd > /dev/null

pushd "${temp_dir}"/data/opt/gridware > /dev/null
bundle config --local build.rugged --use-system-libraries
bundle install --without="development test" --path=vendor

rm -rf Rakefile vendor/cache bin .gitignore README.md \
       vendor/ruby/2.5.0/cache
popd

pushd "${temp_dir}" > /dev/null
zip -r ${package_name}.zip *
popd > /dev/null

mv "${temp_dir}"/${package_name}.zip .

rm -rf "${temp_dir}"
