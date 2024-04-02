#!/usr/bin/env bash

command -v op >/dev/null 2>&1 || {
  echo >&2 "I require 1Password CLI but it's not installed. Aborting."
  exit 1
}

usage="scripts/$(basename "$0") <from branch> <to branch>"

cur_branch="$(git rev-parse --abbrev-ref HEAD)"
cur_origin="$(git remote get-url origin)"

from="$1"
to="$2"
if [ -z "$from" ] || [ -z "$to" ]; then
  echo "$usage"
  exit 1
fi

function post {
  (git checkout "$from" \
    && git push --no-verify) || return 1
}

function cleanup_commit {
  message="$(git log -1 --pretty=%B)"
  cur_branch="$(git rev-parse --abbrev-ref HEAD)"
  # Avoid removing commits if remote is up to date
  ahead="$(git rev-list --left-right --count "$cur_branch"...origin/"$cur_branch" | perl -F -lane '{ print $F[0] }')"
  if [[ $message =~ 'Bump version' ]] && ((ahead > 0)); then
    git reset --hard HEAD~1
    echo "Removing commit '$message'"
  fi
}

function cleanup {
  cleanup_commit
  git checkout "$from" && cleanup_commit
  git remote set-url origin "$cur_origin"
}

if [[ "$cur_branch" != "$from" ]]; then
  echo "On the wrong branch. Swiching to '$from'. Please try again."
  cleanup
  exit 1
fi

# token="$(op read 'op://Consume/GitHub Consume Service Account Token/credential')"

git pull origin "$to" || exit 1

# git remote set-url origin "https://te-conbot:$token@github.com/timeedit/te-consume.git"

# How many commits are ahead of 'from' in the 'to' branch
ahead="$(git rev-list --left-right --count "$to"..."$from" | perl -F -lane '{ print $F[0] }')"

function tag {
  ver=$(perl -lane 'print if s/^\s*"version":\s?"(\d+\.\d+\.\d+)",?/$1/' package.json)
  git tag "v$ver" || return 1
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

if [[ $to == "prod" ]]; then
  (git checkout "$to" \
    && git reset --hard "$from" \
    && tag \
    && git push --tags --force) || cleanup
else
  (git checkout "$to" \
    && git reset --hard "$from" \
    && git push --force) || cleanup
fi

git remote set-url origin "$cur_origin"

post
