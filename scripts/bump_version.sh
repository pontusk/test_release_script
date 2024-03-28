#!/bin/bash

version="$1"
package="$2"

function version_bump {
  perl -i -slane '''
if (/^\s*"version"/) {
    my ($pre, $major, $minor, $patch) = $_ =~ /^(\s*"version":\s?)"(\d+)\.(\d+)\.(\d+)"/;

    if ($version =~ /major/) { $major++; $minor = 0; $patch = 0; }
    if ($version =~ /minor/) { $minor++; $patch = 0; }
    if ($version =~ /patch/) { $patch++; }

    print "$pre\"$major.$minor.$patch\",";
} else {
    print $_;
}
''' -- -version="$version" "$1"
}

version_bump package.json

ver=$(perl -lane 'print if s/^\s*"version":\s?"(\d+\.\d+\.\d+)",?/$1/' package.json)

changed=$(git diff --shortstat)

regex='^.*1 file.*1 insertion.*1 deletion.*$'

if [[ $changed =~ $regex ]]; then
  git add . \
    && git commit -m "chore: Bump${package:+"@timeedit/registration-$package "} version to $ver"
else
  echo "You have additional diffs beyond the version change. Please commit, push and try again."
  echo "$changed"
  exit 1
fi
