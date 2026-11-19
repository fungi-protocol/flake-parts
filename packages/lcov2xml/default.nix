# Converts lcov tracefiles to Cobertura XML. It does not support lcov 2.x's
# merged FNL/FNA function records, so feed it original tracefiles, with FN and
# FNDA records (see concurrent-psbt PR #45).
{
  fetchCrate,
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "lcov2xml";
  version = "1.0.10";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-j2skkCNAV/5iPU3qxxTs5ddR05NNPJWqEmMCKl2Duu8=";
  };

  cargoHash = "sha256-LbxjP7Rchlb5hTuL/9bs83b2sCeEJEXZvNeb4Vbn+Sc=";

  meta = {
    description = "Converts lcov tracefiles to Cobertura XML";
    homepage = "https://github.com/mike-kfed/lcov2cobertura";
    license = lib.licenses.asl20;
    mainProgram = "lcov2xml";
  };
}
