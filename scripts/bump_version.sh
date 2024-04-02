#!/bin/bash

package="$1"
if [ -z "$package" ]; then
  echo "$usage"
  exit 1
fi
if [[ "$package" == "repo" ]]; then
  package=""
else
  package=" @timeedit/registration-$package"
fi
release_branch="$2"
usage="scripts/$(basename "$0") <package name|'repo'> [<release branch>]"

old_version=$(perl -lane 'print if s/^\s*"version":\s?"(\d+\.\d+\.\d+)",?/$1/' package.json)
version=

function check_version {
  perl -sle '''
    my ($major, $minor, $patch) = $version =~ /(\d+)\.(\d+)\.(\d+)/;
    my ($o_major, $o_minor, $o_patch) = $old_version =~ /(\d+)\.(\d+)\.(\d+)/;

    if ($major > $o_major) { exit 0; }
    if ($major == $o_major && $minor > $o_minor) { exit 0; }
    if ($major == $o_major && $minor == $o_minor && $patch > $o_patch) { exit 0; }

    die "Invalid version $version.";
''' -- -version="$1" -old_version="$old_version"
}

function question {
  printf "Your current version is '%s'. Input new version.\nLeave blank to keep the current version.\n" "$old_version"
  read -r answer
  if [[ "$answer" == "" ]]; then
    echo "Keeping version $old_version."
    if [ -n "$release_branch" ]; then
      git commit -m "chore: Release to '$release_branch'."
    fi
    exit 0
  fi
  if ! check_version "$answer"; then
    echo "Please input a semver number ex. '1.0.4', which is larger than the current version."
    question
  fi
  version="$answer"
}
question

perl -i -slane '''
if (/^\s*"version"/) {
    my ($pre) = $_ =~ /^(\s*"version":\s?)"\d+\.\d+\.\d+"/;
    print "$pre\"$version\",";
} else {
    print $_;
}
''' -- -version="$version" package.json

changed=$(git diff --shortstat)

regex='^.*1 file.*1 insertion.*1 deletion.*$'

if [[ $changed =~ $regex ]]; then
  git add . \
    && git commit -m "chore: Bump${package} version to $version.${release_branch:+" Release to '$release_branch'."}"
else
  echo "You have additional diffs beyond the version change. Please commit, push and try again."
  echo "$changed"
  exit 1
fi
