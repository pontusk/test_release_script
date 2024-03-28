#!/bin/bash

package="$1"
if [[ "$package" == "repo" ]]; then
  package=""
else
  package=" @timeedit/registration-$package"
fi
release_branch="$2"
usage="scripts/$(basename "$0") <package name|'repo'>] [<release branch>]"

if [ -z "$package" ]; then
  echo "$usage"
  exit 1
fi

old_version=$(perl -lane 'print if s/^\s*"version":\s?"(\d+\.\d+\.\d+)",?/$1/' package.json)
version=

function question {
  printf "Your current version is '%s'.\nWhat would you like the new version to be?\nLeave blank to keep the current version." "$old_version"
  read -r answer
  if ! [[ "$answer" =~ ^\d+\.\d+\.\d+$ ]]; then
    echo "Please input a semver number ex. '1.0.4'."
    question
  fi
  if [[ "$answer" == "" ]]; then
    exit 0
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
