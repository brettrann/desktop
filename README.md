# desktop
My arch/xmonad desktop environment configuration.

## Instructions

1. install Arch Linux along with the 'base' and `base-devel' packages. There is a good [Beginner's Guide] [arch_install_guide]
2. log in as root and install git, sudo, and zsh `pacman -S git sudo zsh`
3. create a dev user: `useradd -m -G wheel -s /bin/zsh dev` `passwd dev newpassword`
4. edit /etc/sudoers and uncomment the line which allows wheel group to sudo `%wheel ALL=(ALL) ALL`
5. log out as root and log in as the new dev user
6. put your ssh private key into ~/.ssh/
6. `git clone https://github.com/brettrann/desktop`
7. `cd desktop; git submodule init; git submodule update`
8. run the installer `./install`
9. on the first install aur will complain that gcc and gcc-multilib are in conflict.
   For this first case edit `install` and change Aur's `--noconfirm` to `--confirm` and rerun `./install`

[arch_install_guide]: https://wiki.archlinux.org/index.php/beginners'_guide
