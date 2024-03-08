# Copyright (C) 2015, Wazuh Inc.
# Wazuh repository installation
class wazuh::repo (
) {

  case $::osfamily {
    'Debian' : {
      if $::lsbdistcodename =~ /(jessie|wheezy|stretch|precise|trusty|vivid|wily|xenial|yakketi|groovy)/
      and ! defined(Package['apt-transport-https']) {
        ensure_packages(['apt-transport-https'], {'ensure' => 'present'})
      }
      exec { 'import-wazuh-key':
        path =>  [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
        command => '/bin/curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | /usr/bin/gpg --no-default-keyring --keyring /usr/share/keyrings/wazuh.gpg --import',
        unless  => '/usr/bin/gpg --no-default-keyring --keyring /usr/share/keyrings/wazuh.gpg --list-keys | /bin/grep -q 29111145',
      }

      # Ensure permissions on the keyring
      file { '/usr/share/keyrings/wazuh.gpg':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
        require => Exec['import-wazuh-key'],
      }
      case $::lsbdistcodename {
        /(jessie|wheezy|stretch|buster|bullseye|bookworm|sid|precise|trusty|vivid|wily|xenial|yakketi|bionic|focal|groovy|jammy)/: {
          apt::source { 'wazuh':
            ensure   => present,
            comment  => 'This is the WAZUH Ubuntu repository',
            location => 'https://packages-dev.wazuh.com/pre-release/apt',
            release  => 'unstable',
            repos    => 'main',
            include  => {
              'src' => false,
              'deb' => true,
            },
          }
          # Manage the APT source list file content using concat
          concat { '/etc/apt/sources.list.d/wazuh.list':
            ensure  => present,
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
          }

          concat::fragment { 'wazuh-source':
            target  => '/etc/apt/sources.list.d/wazuh.list',
            content => "deb [signed-by=/usr/share/keyrings/wazuh.gpg] $wazuh_repo_url unstable main\n",
            order   => '01',
          }
        }
        default: { fail('This ossec module has not been tested on your distribution (or lsb package not installed)') }
      }
      # Define an exec resource to run 'apt-get update'
      exec { 'apt-update':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        path        => ['/bin', '/usr/bin'],
      }
    }
    'Linux', 'RedHat', 'Suse' : {
        case $::os[name] {
          /^(CentOS|RedHat|OracleLinux|Fedora|Amazon|AlmaLinux|Rocky|SLES)$/: {

            if ( $::operatingsystemrelease =~ /^5.*/ ) {
              $baseurl  = 'https://packages.wazuh.com/4.x/yum/5/'
              $gpgkey   = 'http://packages.wazuh.com/key/GPG-KEY-WAZUH'
            } else {
              $baseurl  = 'https://packages.wazuh.com/4.x/yum/'
              $gpgkey   = 'https://packages.wazuh.com/key/GPG-KEY-WAZUH'
            }
          }
          default: { fail('This ossec module has not been tested on your distribution.') }
        }
        # Set up OSSEC repo
        case $::os[name] {
          /^(CentOS|RedHat|OracleLinux|Fedora|Amazon|AlmaLinux)$/: {
            yumrepo { 'wazuh':
              descr    => 'WAZUH OSSEC Repository - www.wazuh.com',
              enabled  => true,
              gpgcheck => 1,
              gpgkey   => $gpgkey,
              baseurl  => $baseurl
            }
          }
          /^(SLES)$/: {
            zypprepo { 'wazuh':
              ensure        => present,
              name          => 'WAZUH OSSEC Repository - www.wazuh.com',
              enabled       => 1,
              gpgcheck      => 0,
              repo_gpgcheck => 0,
              pkg_gpgcheck  => 0,
              gpgkey        => $gpgkey,
              baseurl       => $baseurl
            }
          }
        }
    }
  }
}
