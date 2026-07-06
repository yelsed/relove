# typed: strict
# frozen_string_literal: true

# Reference Homebrew formula for the relove CLI.
#
# This file is the source of truth; the published copy lives in the tap repo
# yelsed/homebrew-relove as Formula/relove.rb, which is what
# `brew install yelsed/relove/relove` reads. On each release, copy this file
# into the tap and fill in `sha256` (see packaging/RELEASE.md).
class Relove < Formula
  desc "Drop-in hot-reload helper for LÖVE games"
  homepage "https://github.com/yelsed/relove"
  url "https://github.com/yelsed/relove/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "replace_with_release_tarball_sha256"
  license "MIT"
  head "https://github.com/yelsed/relove.git", branch: "master"

  depends_on "lua"

  def install
    # The CLI copies its runtime out of this bundle into each game, so ship the
    # runtime and wrappers alongside tools/relove.lua under libexec.
    libexec.install "dev", "tools", "relove", "relove.bat"

    (bin/"relove").write <<~SH
      #!/bin/sh
      export RELOVE_RUNTIME="#{libexec}"
      exec "#{formula_opt_bin("lua")}/lua" "#{libexec}/tools/relove.lua" "$@"
    SH
  end

  test do
    assert_match "hot reload", shell_output("#{bin}/relove")
    system bin/"relove", "init", testpath
    assert_path_exists testpath/"dev/relove/init.lua"
  end
end
