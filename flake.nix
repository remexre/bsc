{
  outputs = { self, nixpkgs, ... }: {
    devShells = builtins.mapAttrs (
      system: pkgs:
      let
        hs = pkgs.haskell.packages.ghc967;
      in
      {
        default = pkgs.mkShell {
          # Compiler, SMT solver (cvc5) and Tcl deps all come from the package.
          inputsFrom = [ self.packages.${system}.default ];
          # Dev-only tools: cabal, HLS (matching the package set's GHC), and
          # the testsuite deps.
          nativeBuildInputs = [
            hs.haskell-language-server
            pkgs.cabal-install
            pkgs.dejagnu
            pkgs.iverilog
            pkgs.m4
          ];
        };
      }
    ) nixpkgs.legacyPackages;
    packages = builtins.mapAttrs (
      system: pkgs:
      let
        hs = pkgs.haskell.packages.ghc967;

      in
      {
        default = hs.mkDerivation {
          pname = "bsc";
          version = "2026.1";
          src = ./.;

          isLibrary = true;
          isExecutable = true;

          # The test suites need the BLUESPECDIR runtime in inst/lib, which
          # is not built by cabal (yet); run them via `cabal test` instead.
          doCheck = false;

          buildTools = [
            pkgs.perl
            pkgs.tcl
            pkgs.which
          ];

          setupHaskellDepends = [
            hs.Cabal_3_16_1_0
            hs.Cabal-hooks
            hs.process_1_6_28_0
          ];

          libraryHaskellDepends = [
            hs.array
            hs.base
            hs.bytestring
            hs.containers
            hs.deepseq
            hs.directory
            hs.filepath
            hs.integer-gmp
            hs.mtl
            hs.old-locale
            hs.old-time
            hs.process_1_6_28_0
            hs.regex-compat
            hs.split
            hs.strict-concurrency
            hs.syb
            hs.text
            hs.time
            hs.unix
          ];
          libraryPkgconfigDepends = [ pkgs.tcl ];
          librarySystemDepends = [
            pkgs.cvc5
            pkgs.gmp
            pkgs.zlib
          ];

          executableHaskellDepends = [
            hs.base
            hs.bytestring
            hs.containers
            hs.directory
            hs.filepath
            hs.mtl
            hs.old-time
            hs.process_1_6_28_0
            hs.regex-compat
            hs.split
            hs.syb
            hs.time
            hs.unix
          ];

          postPatch = "patchShebangs .";

          preConfigure = "export NOGIT=1";

          preCompileBuildDriver = ''
            cat > Setup.hs <<EOF
            import Distribution.Simple
            import SetupHooks
            main = defaultMainWithSetupHooks setupHooks
            EOF
          '';
        };
      }
    ) nixpkgs.legacyPackages;
  };
}
