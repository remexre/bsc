#!/usr/bin/env bash

if [ "${BREW_UPDATE}" != "false" ]; then
    brew update
fi

# ccache is not required to build bsc, but we use it in build.yml to improve
# the build performance by caching C++ obj files across multiple builds.
# Note: the cvc5 SMT solver is also required to build bsc, but it is not
# available from Homebrew; install it from
# https://github.com/cvc5/cvc5/releases or use the Nix flake (see INSTALL.md).
brew install \
  ccache \
  icarus-verilog \
  pkg-config
