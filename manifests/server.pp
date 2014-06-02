# == Class: ssh_hardening::server
#
# The default SSH class which installs the SSH server
#
# === Parameters
#
# [*cbc_required*]
#   CBC-meachnisms are considered weaker and will not be used as ciphers by
#   default. Set this option to true if you really need CBC-based ciphers.
#
# [*weak_hmac*]
#   The HMAC-mechanisms are selected to be cryptographically strong. If you
#   require some weaker variants, set this option to true to get safe selection.
#
# [*weak_kex*]
#   The KEX-mechanisms are selected to be cryptographically strong. If you
#   require some weaker variants, set this option to true to get safe selection.
#
# [*ports*]
#   A list of ports that SSH expects to run on. Defaults to 22.
#
# [*listen_to*]
#   A list of addresses which SSH listens on. Best to specify only on address of
#   one interface.
#
# [*host_key_files*]
#   A list of host key files to use.
#
# [*client_alive_interval*]
#   Interval after which the server checks if the client is alive (in seconds).
#
# [*client_alive_count*]
#   The maximum number of failed client alive checks before the client is
#   forcefully disconnected.
#
# [*allow_root_with_key*]
#   Whether to allow login of root. If true, root may log in using the key files
#   specified in authroized_keys. Otherwise any login attempts as user root
#   are forbidden.
#
# [*ipv6_enabled*]
#   Set to true if you need IPv6 support in SSH.
#
# === Copyright
#
# Copyright 2014, Deutsche Telekom AG
#
class ssh_hardening::server (
  $cbc_required          = false,
  $weak_hmac             = false,
  $weak_kex              = false,
  $ports                 = [ 22 ],
  $listen_to             = [ '0.0.0.0' ],
  $host_key_files        = [
    '/etc/ssh/ssh_host_rsa_key',
    '/etc/ssh/ssh_host_dsa_key',
    '/etc/ssh/ssh_host_ecdsa_key'
    ],
  $client_alive_interval = 600,
  $client_alive_count    = 3,
  $allow_root_with_key   = false,
  $ipv6_enabled          = false,
  $use_pam               = false,
) {

  $addressfamily = $ipv6_enabled ? {
    true  => 'any',
    false => 'inet',
  }

  case $operatingsystem {
    default: {
      $ciphers = $cbc_required ? {
        true  => 'aes256-ctr,aes192-ctr,aes128-ctr,aes256-cbc,aes192-cbc,aes128-cbc',
        false => 'aes256-ctr,aes192-ctr,aes128-ctr',
      }

      $macs = $weak_hmac ? {
        true  => 'hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,hmac-sha1',
        false => 'hmac-sha2-512,hmac-sha2-256,hmac-ripemd160',
      }

      $kex = $weak_kex ? {
        true  => 'diffie-hellman-group-exchange-sha256,diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1,diffie-hellman-group1-exchange-sha1',
        false => 'diffie-hellman-group-exchange-sha256,diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1',
      }
    }
  }

  $permit_root_login = $allow_root_with_key ? {
    true  => 'without-password',
    false => 'no',
  }

  $use_pam_option = $use_pam ? {
    true  => 'yes',
    false => 'no',
  }

  class { 'ssh::server':
    storeconfigs_enabled => false,
    options              => {
      # Basic configuration
      # ===================

      # Either disable or only allow root login via certificates.
      'PermitRootLogin'                 => $permit_root_login,

      # Define which port sshd should listen to. Default to `22`.
      'Port'                            => $ports,

      # Address family should always be limited to the active
      # network configuration.
      'AddressFamily'                   => $addressfamily,

      # Define which addresses sshd should listen to.
      # Default to `0.0.0.0`, ie make sure you put your desired address
      # in here, since otherwise sshd will listen to everyone.
      'ListenAddress'                   => $listen_to,

      # Security configuration
      # ======================

      # Set the protocol family to 2 for security reasons.
      # Disables legacy support.
      'Protocol'                        => 2,

      # Make sure sshd checks file modes and ownership before accepting logins.
      # This prevents accidental misconfiguration.
      'StrictModes'                     => 'yes',

      # Logging, obsoletes QuietMode and FascistLogging
      'SyslogFacility'                  => 'AUTH',
      'LogLevel'                        => 'VERBOSE',

      # Cryptography
      # ------------

      # **Ciphers** -- If your clients don't support CTR (eg older versions),
      #   cbc will be added
      # CBC: is true if you want to connect with OpenSSL-base libraries
      # eg Ruby's older Net::SSH::Transport::CipherFactory requires CBC-versions
      # of the given openssh ciphers to work
      #
      'Ciphers'                         => $ciphers,

      # **Hash algorithms** -- Make sure not to use SHA1 for hashing,
      # unless it is really necessary.
      # Weak HMAC is sometimes required if older package versions are used
      # eg Ruby's Net::SSH at around 2.2.* doesn't support sha2 for hmac,
      # so this will have to be set true in this case.
      #
      'MACs'                            => $macs,

      # Alternative setting, if OpenSSH version is below v5.9
      #MACs hmac-ripemd160

      # **Key Exchange Algorithms** -- Make sure not to use SHA1 for kex,
      # unless it is really necessary
      # Weak kex is sometimes required if older package versions are used
      # eg ruby's Net::SSH at around 2.2.* doesn't support sha2 for kex,
      # so this will have to be set true in this case.
      #
      'KexAlgorithms'                   => $kex,

      # Lifetime and size of ephemeral version 1 server key
      'KeyRegenerationInterval'         => '1h',
      'ServerKeyBits'                   => 2048,

      # Authentication
      # --------------

      # Secure Login directives.
      'UseLogin'                        => 'no',
      'UsePrivilegeSeparation'          => 'yes',
      'PermitUserEnvironment'           => 'no',
      'LoginGraceTime'                  => '30s',
      'MaxAuthTries'                    => 2,
      'MaxSessions'                     => 10,
      'MaxStartups'                     => '10:30:100',

      # Enable public key authentication
      'RSAAuthentication'               => 'yes',
      'PubkeyAuthentication'            => 'yes',

      # Never use host-based authentication. It can be exploited.
      'IgnoreRhosts'                    => 'yes',
      'IgnoreUserKnownHosts'            => 'yes',
      'RhostsRSAAuthentication'         => 'no',
      'HostbasedAuthentication'         => 'no',

      # Disable password-based authentication, it can allow for
      # potentially easier brute-force attacks.
      'UsePAM'                          => $use_pam_option,
      'PasswordAuthentication'          => 'no',
      'PermitEmptyPasswords'            => 'no',
      'ChallengeResponseAuthentication' => 'no',

      # Only enable Kerberos authentication if it is configured.
      'KerberosAuthentication'          => 'no',
      'KerberosOrLocalPasswd'           => 'no',
      'KerberosTicketCleanup'           => 'yes',
      #KerberosGetAFSToken no

      # Only enable GSSAPI authentication if it is configured.
      'GSSAPIAuthentication'            => 'no',
      'GSSAPICleanupCredentials'        => 'yes',

      # In case you don't use PAM (`UsePAM no`), you can alternatively
      # restrict users and groups here. For key-based authentication
      # this is not necessary, since all keys must be explicitely enabled.
      #DenyUsers *
      #AllowUsers user1
      #DenyGroups *
      #AllowGroups group1


      # Network
      # -------

      # Disable TCP keep alive since it is spoofable. Use ClientAlive
      # messages instead, they use the encrypted channel
      'TCPKeepAlive'                    => 'no',

      # Manage `ClientAlive..` signals via interval and maximum count.
      # This will periodically check up to a `..CountMax` number of times
      # within `..Interval` timeframe, and abort the connection once these fail.
      'ClientAliveInterval'             => $client_alive_interval,
      'ClientAliveCountMax'             => $client_alive_count,

      # Disable tunneling
      'PermitTunnel'                    => 'no',

      # Disable forwarding tcp connections.
      # no real advantage without denied shell access
      'AllowTcpForwarding'              => 'yes',

      # Disable agent formwarding, since local agent could be accessed through
      # forwarded connection. No real advantage without denied shell access
      'AllowAgentForwarding'            => 'yes',

      # Do not allow remote port forwardings to bind to non-loopback addresses.
      'GatewayPorts'                    => 'no',

      # Disable X11 forwarding, since local X11 display could be
      # accessed through forwarded connection.
      'X11Forwarding'                   => 'no',
      'X11UseLocalhost'                 => 'yes',

      # Misc. configuration
      # ===================

      'PrintMotd'                       => 'no',
      'PrintLastLog'                    => 'no',
      #Banner /etc/ssh/banner.txt
      #UseDNS yes
      #PidFile /var/run/sshd.pid
      #MaxStartups 10
      #ChrootDirectory none
      #ChrootDirectory /home/%u

      # Configuratoin, in case SFTP is used
      ## override default of no subsystems
      ## Subsystem sftp /opt/app/openssh5/libexec/sftp-server
      #Subsystem sftp internal-sftp -l VERBOSE
      #
      ## These lines must appear at the *end* of sshd_config
      #Match Group sftponly
      #ForceCommand internal-sftp -l VERBOSE
      #ChrootDirectory /sftpchroot/home/%u
      #AllowTcpForwarding no
      #AllowAgentForwarding no
      #PasswordAuthentication no
      #PermitRootLogin no
      #X11Forwarding no
    },
  }
}
