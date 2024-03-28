#!/usr/bin/env bash

command -v op >/dev/null 2>&1 || {
  echo >&2 "I require 1Password CLI but it's not installed. Aborting."
  exit 1
}

usage="scripts/$(basename "$0") <from branch> <to branch> [<package name>]"

from="$1"
to="$2"
if [ -z "$from" ] || [ -z "$to" ]; then
  echo "$usage"
  exit 1
fi

# token="$(op read 'op://Consume/GitHub Consume Service Account Token/credential')"

git pull origin "$to"

cur_origin="$(git remote get-url origin)"
# git remote set-url origin "https://te-conbot:$token@github.com/timeedit/te-consume.git"

# How many commits are ahead of main in the 'from' branch
ahead="$(git rev-list --left-right --count "$to"..."$from" | awk '{ print $1 }')"

function post {
  (git checkout "$from" \
    && git push --no-verify) || return 1
}

function cleanup {
  message="$(git log -1 --pretty=%B)"
  git checkout "$from"

  if [[ $message =~ 'Bump version' ]]; then
    git reset --hard HEAD~1
    echo "Removing commit '$message'"
  fi

  git remote set-url origin "$cur_origin"
}

if ((ahead > 0)); then
  echo "The '$to' branch is ahead by '$ahead' commits. Merge any quick fixes to '$to' into '$from' and try again."
  cleanup
  exit 1
fi

function question {
  read -r -p "Are you sure you want to release '$to'? This will reset the '$to' branch to '$from'. (y/N) " answer
  case $answer in
    y | Y) ;;
    n | N | "")
      cleanup
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
  (git checkout "$to" \
    && git reset --hard "$from" \
    && git tag "v$ver" \
    && git push --tags --force \
    && post) || cleanup
else
  (git checkout "$to" \
    && git reset --hard "$from" \
    && git push --force \
    && post) || cleanup
fi

git remote set-url origin "$cur_origin"
