# http://loicpefferkorn.net/2015/01/arch-linux-on-macbook-pro-retina-2014-with-dm-crypt-lvm-and-suspend-to-disk/
# https://wiki.archlinux.org/index.php/Intel_graphics#Module-based_Powersaving_Options
# https://bbs.archlinux.org/viewtopic.php?id=199388

{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Use the gummiboot efi boot loader.
  #boot.kernelPackages = pkgs.linuxPackages_4_4;
  boot.kernelModules = [ "msr" "coretemp" "applesmc" ];
  boot.loader.gummiboot.enable = true;
  boot.loader.gummiboot.timeout = 8;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernel.sysctl = {
    # Note that inotify watches consume 1kB on 64-bit machines.
    "fs.inotify.max_user_watches"   = 1048576;   # default:  8192
    "fs.inotify.max_user_instances" =    1024;   # default:   128
    "fs.inotify.max_queued_events"  =   32768;   # default: 16384
  };

  # Select internationalisation properties.
  time.timeZone = "US/Eastern";
  i18n.consoleUseXkbConfig = true;

  networking.hostName = "cstrahan-mbp-nixos"; # Define your hostname.
  networking.hostId = "0ae2b4e1";
  networking.networkmanager.enable = lib.mkForce true;
  networking.wireless.enable = lib.mkForce false;
  networking.firewall.enable = false;
  networking.firewall.allowedUDPPorts = [
    631 # IPP - printer discovery
  ];

  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "devicemapper";

  hardware = {
    opengl.driSupport32Bit = true;
    pulseaudio.enable = true;
    pulseaudio.support32Bit = true;
    bluetooth.enable = true;
  };

  programs.light.enable = true;
  programs.ssh.startAgent = false; # we'll use GPG from ~/.xsession

  services.logind.extraConfig = ''
    HandlePowerKey=suspend
  '';

  # Needed for GTK themes.
  environment.pathsToLink = [ "/share" ];

  environment.variables = {
    BROWSER = "google-chrome-stable";
    SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
  };

  #environment.etc."fuse.conf".text = ''
  #  user_allow_other
  #'';

  # Enable the backlight on rMBP
  # Disable USB-based wakeup
  # see: https://wiki.archlinux.org/index.php/MacBookPro11,x
  systemd.services.mbp-fixes = {
    description = "Fixes for MacBook Pro";
    wantedBy = [ "multi-user.target" "post-resume.target" ];
    after = [ "multi-user.target" "post-resume.target" ];
    script = ''
      if [[ "$(cat /sys/class/dmi/id/product_name)" == "MacBookPro11,3" ]]; then
        if [[ "$(${pkgs.pciutils}/bin/setpci  -H1 -s 00:01.00 BRIDGE_CONTROL)" != "0000" ]]; then
          ${pkgs.pciutils}/bin/setpci -v -H1 -s 00:01.00 BRIDGE_CONTROL=0
        fi
        echo 5 > /sys/class/leds/smc::kbd_backlight/brightness

        if ${pkgs.gnugrep}/bin/grep -q '\bXHC1\b.*\benabled\b' /proc/acpi/wakeup; then
          echo XHC1 > /proc/acpi/wakeup
        fi
      fi
    '';
    serviceConfig.Type = "oneshot";
  };

  services.printing = {
    enable = true;
    gutenprint = true;
    drivers = [
      pkgs.cups-bjnp
      pkgs.hplip
    ];
  };

  #services.mbpfan.enable = true; # seems to have stopped working recently...
  services.xserver = {
    enable = true;
    autorun = true;
    videoDrivers = [ "nvidia" ];
    xkbOptions = "ctrl:nocaps";

    deviceSection = ''
      Option   "NoLogo"         "TRUE"
      Option   "DPI"            "96 x 96"
      Option   "Backlight"      "gmux_backlight"
      Option   "RegistryDwords" "EnableBrightnessControl=1"
    '';

    # Settings can be tested out like so:
    #
    # $ synclient AccelFactor=0.0055 MinSpeed=0.95 MaxSpeed=1.15
    synaptics.enable = true;
    synaptics.twoFingerScroll = true;
    synaptics.buttonsMap = [ 1 3 2 ];
    synaptics.tapButtons = false;
    synaptics.accelFactor = "0.0055";
    synaptics.minSpeed = "0.95";
    synaptics.maxSpeed = "1.15";
    synaptics.palmDetect = true;
    synaptics.palmMinWidth = 10;
    # seems to default to 70 and 75
    synaptics.additionalOptions = ''
      Option "FingerLow" "80"
      Option "FingerHigh" "85"
    '';

    #desktopManager.kde4.enable = true;
    #displayManager.kdm.enable = true;
    #desktopManager.default = "kde4";

    desktopManager.default = "none";
    desktopManager.xterm.enable = false;
    displayManager.slim = {
      enable = true;
      defaultUser = "cstrahan";
      extraConfig = ''
        console_cmd ${pkgs.rxvt_unicode_with-plugins}/bin/urxvt -C -fg white -bg black +sb -T "Console login" -e ${pkgs.shadow}/bin/login
      '';
      theme = ./slim-theme;
    };
    windowManager.default = "xmonad";
    windowManager.xmonad.enable = true;
    windowManager.xmonad.extraPackages = hpkgs: [
      hpkgs.taffybar
      hpkgs.xmonad-contrib
      hpkgs.xmonad-extras
    ];

    displayManager.sessionCommands = ''
      # Set GTK_DATA_PREFIX so that GTK+ can find the themes
      export GTK_DATA_PREFIX=${config.system.path}

      # find theme engines
      export GTK_PATH=${config.system.path}/lib/gtk-3.0:${config.system.path}/lib/gtk-2.0

      # Find the mouse
      export XCURSOR_PATH=~/.icons:~/.nix-profile/share/icons:/var/run/current-system/sw/share/icons

      ${pkgs.xorg.xset}/bin/xset r rate 220 50

      if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
        eval "$(${pkgs.dbus.tools}/bin/dbus-launch --sh-syntax --exit-with-session)"
        export DBUS_SESSION_BUS_ADDRESS
      fi
    '';
  };

  #services.gitlab.enable = true;
  #services.gitlab.databasePassword = "gitlab";

  services.dbus.enable = true;
  services.upower.enable = true;

  services.redshift.enable = true;
  services.redshift.latitude = "39";
  services.redshift.longitude = "-77";
  services.redshift.temperature.day = 5500;
  services.redshift.temperature.night = 2300;

  services.actkbd.enable = true;
  services.actkbd.bindings = [
    { keys = [ 224 ]; events = [ "key" "rep" ]; command = "${pkgs.light}/bin/light -U 4"; }
    { keys = [ 225 ]; events = [ "key" "rep" ]; command = "${pkgs.light}/bin/light -A 4"; }
    { keys = [ 229 ]; events = [ "key" "rep" ]; command = "${pkgs.kbdlight}/bin/kbdlight down"; }
    { keys = [ 230 ]; events = [ "key" "rep" ]; command = "${pkgs.kbdlight}/bin/kbdlight up"; }
  ];

  services.mongodb.enable = true;
  services.zookeeper.enable = true;
  services.apache-kafka.enable = true;
  #services.elasticsearch.enable = true;
  #services.memcached.enable = true;
  services.redis.enable = true;

  # Make sure to run:
  #  sudo createuser -s postgres
  #
  # If not running gitlab on localhost:
  #  sudo createuser -P gitlab
  #  sudo createdb -e -T template1 -O gitlab gitlab
  #services.postgresql.enable = true;
  #services.postgresql.package = pkgs.postgresql93;
  #services.postgresql.authentication = lib.mkForce ''
  #  # Generated file; do not edit!
  #  local all all              trust
  #  host  all all 127.0.0.1/32 trust
  #  host  all all ::1/128      trust
  #'';

  environment.systemPackages =
    let stdenv = [ pkgs.stdenv.cc pkgs.stdenv.cc.binutils ] ++ pkgs.stdenv.initialPath;
    in [
    pkgs.google-chrome
    #pkgs.chromium
    pkgs.firefoxWrapper
    pkgs.torbrowser
    pkgs.idea.idea-community
    #pkgs.idea.idea-ultimate

    pkgs.glxinfo
    pkgs.wpa_supplicant_gui
    pkgs.dropbox
    pkgs.sublime3
    pkgs.kde4.kcachegrind
    pkgs.deluge

    # messaging
    pkgs.hipchat
    pkgs.irssi
    pkgs.weechat

    # media
    pkgs.spotify
    pkgs.mpv
    pkgs.libreoffice
    pkgs.abiword
    pkgs.gimp
    pkgs.inkscape
    pkgs.evince
    pkgs.zathura
    pkgs.cmus
    pkgs.sxiv
    pkgs.exiv2
    #pkgs.imagemagick

    # work around https://bugs.winehq.org/show_bug.cgi?id=36139
    pkgs.wineUnstable
    pkgs.winetricks

    # X11 stuff
    pkgs.termite
    pkgs.rxvt_unicode_with-plugins
    pkgs.anki
    pkgs.taffybar
    pkgs.dmenu2
    pkgs.xautolock
    pkgs.xss-lock
    pkgs.xsel
    pkgs.xclip
    pkgs.xlsfonts
    pkgs.dunst
    pkgs.stalonetray
    pkgs.scrot
    pkgs.haskellPackages.xmobar
    pkgs.texstudio
    pkgs.wmctrl
    pkgs.compton
    pkgs.xorg.xev
    pkgs.xorg.xprop
    pkgs.sxhkd

    # CLI tools
    pkgs.mosh
    pkgs.nssTools
    pkgs.openssl
    pkgs.urlview
    pkgs.lynx
    pkgs.pass
    pkgs.notmuch
    pkgs.mutt-kz
    pkgs.msmtp
    pkgs.isync
    pkgs.gnupg21
    pkgs.pinentry
    pkgs.strategoPackages.strategoxt
    pkgs.lsof
    pkgs.usbutils
    pkgs.xidel
    pkgs.mkpasswd
    pkgs.glib # e.g. `gdbus`
    pkgs.python2Full
    pkgs.rpm
    pkgs.skype
    pkgs.powertop
    pkgs.socat
    pkgs.nmap # `ncat`
    pkgs.iptables
    pkgs.bridge-utils
    pkgs.lxc
    pkgs.openvswitch
    pkgs.dnsmasq
    pkgs.dhcpcd
    pkgs.dhcp
    pkgs.bind
    pkgs.pciutils
    pkgs.awscli
    pkgs.peco
    pkgs.stunnel
    #pkgs.colordiff # TODO: fix url in nixpkgs
    pkgs.ncdu
    pkgs.graphviz
    pkgs.gtypist
    pkgs.nix-repl
    pkgs.zip
    pkgs.vifm
    pkgs.wget
    pkgs.unzip
    pkgs.hdparm
    pkgs.libsysfs
    pkgs.iomelt
    pkgs.htop
    pkgs.jq
    pkgs.binutils
    pkgs.psmisc
    pkgs.tree
    pkgs.silver-searcher
    pkgs.vimHuge
    pkgs.git
    pkgs.cvs
    pkgs.cvs_fast_export
    pkgs.bazaar
    pkgs.mercurialFull
    pkgs.darcs
    pkgs.subversion
    pkgs.zsh
    pkgs.tmux
    pkgs.nix-prefetch-scripts
    pkgs.mc
    pkgs.watchman
    pkgs.pythonPackages.pywatchman
    pkgs.emacs
    pkgs.ctags
    pkgs.global
    #pkgs.rtags
    pkgs.w3m-full
    pkgs.jdk
    pkgs.leiningen
    #pkgs.tweak

    pkgs.vanilla-dmz

    pkgs.fuse
    pkgs.sshfsFuse

    pkgs.gtk # To get GTK+'s themes.
    pkgs.hicolor_icon_theme
    pkgs.tango-icon-theme
    pkgs.shared_mime_info

    pkgs.networkmanagerapplet
    pkgs.blueman

    #pkgs.gitinspector
    pkgs.arandr
    pkgs.lr
    pkgs.xe
    pkgs.nq
    pkgs.taskwarrior
    pkgs.pagemon
    pkgs.rofi
    #pkgs.exa
    pkgs.vnstat
    # clipgrab diffoscope aws-shell
    # playerctl
  ];

  environment.shells = [
    "/run/current-system/sw/bin/zsh"
  ];

  users = {
    mutableUsers = false;
    extraGroups.docker.gid = lib.mkForce config.ids.gids.docker;
    extraUsers = [
      {
        uid             = 2000;
        name            = "cstrahan";
        group           = "users";
        extraGroups     = [ "wheel" "networkmanager" "docker" "fuse" ];
        isNormalUser    = true;
        passwordFile    = "/etc/nixos/passwords/cstrahan";
        useDefaultShell = false;
        shell           = "/run/current-system/sw/bin/zsh";
      }
    ];
  };

  nix.useChroot = true;
  nix.extraOptions = ''
    gc-keep-outputs = true
  '';
  nix.binaryCaches = [
    "http://cache.nixos.org"
    "http://hydra.nixos.org"
  ];
  nix.trustedBinaryCaches = [
    "http://hydra.cryp.to"
    "https://ryantrinkle.com:5443"
  ];
  # https://github.com/NixOS/nixpkgs/issues/9129
  nix.requireSignedBinaryCaches = true;
  nix.binaryCachePublicKeys = [
    "hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs="
  ];

  fonts = {
    fontconfig.enable = true;
    enableFontDir = true;
    enableGhostscriptFonts = true;
    fonts = with pkgs; [
      hack-font
      terminus_font
      anonymousPro
      freefont_ttf
      corefonts
      dejavu_fonts
      inconsolata
      ubuntu_font_family
      ttf_bitstream_vera
      pragmatapro
    ];
  };

  services.cron.systemCronJobs = [
    "0 2 * * * root fstrim /"
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.dmenu.enableXft = true;
  nixpkgs.config.firefox = {
   enableGoogleTalkPlugin = true;
   enableAdobeFlash = true;
  };
  nixpkgs.config.chromium = {
   enablePepperFlash = true;
   enableWideVine = true;
  };
  nixpkgs.config.packageOverrides = super: let self = super.pkgs; in
    rec {
      #iproute = super.iproute.override { enableFan = true; };
      linux_4_4 = super.linux_4_4.override {
        kernelPatches = super.linux_4_4.kernelPatches ++ [ self.kernelPatches.ubuntu_fan_4_4 ];
      };

      pass = super.pass.override {
        gnupg = self.gnupg21;
      };

      pragmatapro =
        self.stdenv.mkDerivation rec {
          version = "0.820";
          name = "pragmatapro-${version}";
          src = self.requireFile rec {
            name = "PragmataPro${version}.zip";
            url = "file://path/to/${name}";
            sha256 = "0dg7h80jaf58nzjbg2kipb3j3w6fz8z5cyi4fd6sx9qlkvq8nckr";
          };
          buildInputs = [ self.unzip ];
          phases = [ "installPhase" ];
          installPhase = ''
            unzip $src

            install_path=$out/share/fonts/truetype/public/pragmatapro-$version
            mkdir -p $install_path

            find -name "PragmataPro*.ttf" -exec mv {} $install_path \;
          '';
        };
      vimHuge =
        with self;
        with self.xorg;
        stdenv.mkDerivation rec {
          name = "vim-${version}";

          version = "7.4.827";

          dontStrip = 1;

          src = fetchFromGitHub {
            owner = "vim";
            repo = "vim";
            rev = "v${version}";
            sha256 = "1m34s2hsc5lcish6gmvn2iwaz0k7jc3kg9q4nf30fj9inl7gaybs";
          };

          buildInputs = [
            pkgconfig gettext glib
            libX11 libXext libSM libXpm libXt libXaw libXau libXmu libICE
            gtk ncurses
            cscope
            python2Full ruby luajit perl tcl
          ];

          configureFlags = [
              "--enable-cscope"
              "--enable-fail-if-missing"
              "--with-features=huge"
              "--enable-gui=none"
              "--enable-multibyte"
              "--enable-nls"
              "--enable-luainterp=yes"
              "--enable-pythoninterp=yes"
              "--enable-perlinterp=yes"
              "--enable-rubyinterp=yes"
              "--enable-tclinterp=yes"
              "--with-luajit"
              "--with-lua-prefix=${luajit}"
              "--with-python-config-dir=${python2Full}/lib"
              "--with-ruby-command=${ruby}/bin/ruby"
              "--with-tclsh=${tcl}/bin/tclsh"
              "--with-tlib=ncurses"
              "--with-compiledby=Nix"
          ];

          meta = with stdenv.lib; {
            description = "The most popular clone of the VI editor";
            homepage    = http://www.vim.org;
            maintainers = with maintainers; [ cstrahan ];
            platforms   = platforms.unix;
          };
        };
    };

    # https://wiki.archlinux.org/index.php/Systemd/User#D-Bus
    #systemd.services."user@".environment.DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/%I/bus";
    #systemd.user.sockets."dbus" = {
    #  description = "D-Bus User Message Bus Socket";
    #  wantedBy = [ "sockets.target" ];
    #  socketConfig = {
    #    ListenStream = "%t/bus";
    #  };
    #};
    #systemd.user.services."dbus" = {
    #  description = "D-Bus User Message Bus";
    #  requires = [ "dbus.socket" ];
    #  serviceConfig = {
    #    ExecStart = "${pkgs.dbus_daemon}/bin/dbus-daemon --session --address=systemd: --nofork --nopidfile --systemd-activation";
    #    ExecReload = "${pkgs.dbus_daemon}/bin/dbus-send --print-reply --session --type=method_call --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig";
    #  };
    #};
}
