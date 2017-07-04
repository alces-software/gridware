
# Gridware

This is the repository for the Alces Gridware tool for installing and managing
HPC software. Alces Gridware is intended to be used in an [Alces
Clusterware](https://github.com/alces-software/clusterware) environment, such
as [Alces Flight Compute](http://alces-flight.com/).

## Development

Gridware can be developed within an existing Clusterware environment. For
example, to use a local version of the Gridware source inside an Alces
Clusterware development Vagrant VM you can do the following:

1. Mount the Gridware source to the appropriate location within the VM by
   adding something like the following to the Vagrantfile, then running
   `vagrant up`:

   ```ruby
      config.vm.synced_folder "path/to/gridware", "/opt/clusterware/opt/gridware"
   ```

2. Install the mounted version of Gridware within the VM by running
   `bin/setup`.

Gridware also has some tests; these can be run using `bin/rake test`.
