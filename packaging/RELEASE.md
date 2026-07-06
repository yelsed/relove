# Releasing relove

The Homebrew formula and the install script both pull a tagged tarball from
GitHub. Cutting a release is three steps.

## 1. Tag and push a release

```sh
git tag v0.1.0
git push origin v0.1.0
```

Then create a GitHub release for the tag (or `gh release create v0.1.0 --generate-notes`).
GitHub serves the source tarball at:

```
https://github.com/yelsed/relove/archive/refs/tags/v0.1.0.tar.gz
```

## 2. Update the tap formula

The published formula lives in the **`yelsed/homebrew-relove`** tap as
`Formula/relove.rb`. Copy [`packaging/relove.rb`](./relove.rb) there, set `url` to
the new tag, and fill `sha256`:

```sh
curl -fsSL https://github.com/yelsed/relove/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
```

Commit and push the tap. `brew install yelsed/relove/relove` now serves the new
version; existing users get it with `brew upgrade relove`.

### First-time tap setup

Create an empty public repo named exactly `homebrew-relove` under the `yelsed`
org, add `Formula/relove.rb` (the copy from step 2). No other files are required.

## 3. Install script

`install.sh` defaults to `master`; users pin a release with
`RELOVE_VERSION=v0.1.0`. Nothing to update per release unless the layout changes.

## Testing the formula locally

```sh
brew install --build-from-source ./packaging/relove.rb   # after url/sha are valid
brew test relove
brew audit --strict relove
```
