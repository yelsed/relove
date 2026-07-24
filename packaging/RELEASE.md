# Releasing relove

The Homebrew formula and the install script both pull a tagged tarball from
GitHub. Cutting a release is three steps.

## 1. Create a GitHub release from the automatic tag

Every pull request merged into `master` is tagged automatically at its exact
merge commit. The merge workflow finds the latest stable tag matching
`vMAJOR.MINOR.PATCH` and increments only `PATCH`. If the repository has no stable
semantic version tag, the first tag is `v0.0.1`. Prerelease and unrelated tags
do not affect the next version, and tagging jobs are serialized to prevent
concurrent merges from receiving the same version. Closing a pull request
without merging it, or merging into a branch other than `master`, does not
create a tag.

After the merge workflow finishes, note the tag it created. Creating the GitHub
release remains a deliberate manual step: in GitHub, create a release and select
that existing tag, or run:

```sh
gh release create v0.1.0 --verify-tag --generate-notes
```

Replace `v0.1.0` with the automatically created tag. `--verify-tag` prevents the
command from creating a different tag if the expected tag is unavailable.
GitHub serves the source tarball for the example tag at:

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
account, add `Formula/relove.rb` (the copy from step 2). No other files are required.

## 3. Install script

`install.sh` defaults to `master`; users pin a release with
`RELOVE_VERSION=v0.1.0`. Nothing to update per release unless the layout changes.

## Testing the formula locally

```sh
brew install --build-from-source ./packaging/relove.rb   # after url/sha are valid
brew test relove
brew audit --strict relove
```
