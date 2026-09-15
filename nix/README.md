# Description

This folder contains configuration for [Nix](https://nixos.org/), a purely functional package manager used by the Status App for its build process.

## Prerequisites

Install Nix:

```sh
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
```

Install direnv:

```sh
brew install direnv     # macOS
sudo apt install direnv # Ubuntu
sudo dnf install direnv # Fedora
```

## Configuration

The main config file is [`nix/nix.conf`](/nix/nix.conf) and its main purpose is defining the [binary caches](https://nixos.org/nix/manual/#ch-basic-package-mgmt) which allow download of packages to avoid having to compile them yourself locally.

## Shell

In order to access an interactive Nix shell a user should run `nix develop`.

But better way is to use `direnv allow`. So it will run a nix shell every time you enter the workdir.
It will also reload the shell in case of nix configuration changes.

## Resources

You can learn more about Nix by watching these presentations:

* [Nix Fundamentals](https://www.youtube.com/watch?v=m4sv2M9jRLg) ([PDF](https://drive.google.com/file/d/1Tt5R7QOubudGiSuZIGxuFWB1OYgcThcL/view?usp=sharing), [src](https://github.com/status-im/infra-docs/tree/master/presentations/nix_basics))
* [Nix in Status](https://www.youtube.com/watch?v=rEQ1EvRG8Wc) ([PDF](https://drive.google.com/file/d/1Ti0wppMoj40icCPdHy7mJcQj__DeaYBE/view?usp=sharing), [src](https://github.com/status-im/infra-docs/tree/master/presentations/nix_in_status))
