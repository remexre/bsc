#!/usr/bin/env bash

apt-get update

# ccache is not required to buid bsc, but we use it in build.yml to improve
# the build performance by caching C++ obj files across multiple builds.
# Note: the cvc5 SMT solver is also required to build bsc, but it is not
# available from apt; install it from https://github.com/cvc5/cvc5/releases
# or use the Nix flake (see INSTALL.md).
apt-get install -y \
  ccache \
  build-essential \
  git \
  iverilog \
  tcl-dev
