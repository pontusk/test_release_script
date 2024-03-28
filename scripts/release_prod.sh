#!/usr/bin/env bash

command -v op >/dev/null 2>&1 || {
  echo >&2 "I require 1Password CLI but it's not installed. Aborting."
  exit 1
}

usage="$0 <from branch> <to branch> [<package name>]"

from="$1"
to="$2"
if [ -z "$from" ] || [ -z "$to" ]; then
  echo "$usage"
fi

# token="$(op read 'op://Consume/GitHub Consume Service Account Token/credential')"

git pull origin "$from"

cur_origin="$(git remote get-url origin)"
# git remote set-url origin "https://te-conbot:$token@github.com/timeedit/te-consume.git"

# How many commits are ahead of main in the 'from' branch
ahead="$(git rev-list --left-right --count "$from"..."$to" | awk '{ print $1 }')"

if ((ahead > 0)); then
  echo "The '$from' branch is ahead by '$ahead' commits. Merge any quick fixes to '$from' into '$to' and try again."
  git remote set-url origin "$cur_origin"
  exit 1
fi

function question {
  read -r -p "Are you sure you want to release '$from'? This will reset the '$from' branch to '$to'. (y/N) " answer
  case $answer in
    y | Y) ;;
    n | N | "")
      git remote set-url origin "$cur_origin"
      exit 0
      ;;
    *)
      question
      echo "Answer with y or n."
      ;;
  esac
}
question

ver=$(perl -lane 'print if s/^\s*"version":\s?"(\d+\.\d+\.\d+)",?/$1/' package.json)

if [[ $to == "prod" ]]; then
  (git checkout "$from" \
    && git reset --hard "$to" \
    && git tag "v$ver" \
    && git push --tags --force) || {
    git remote set-url origin "$cur_origin"
  }
else
  (git checkout "$from" \
    && git reset --hard "$to" \
    && git push --force \
    && git checkout -) || {
    git remote set-url origin "$cur_origin"
  }
fi

git remote set-url origin "$cur_origin"
