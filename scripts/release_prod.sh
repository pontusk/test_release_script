#!/usr/bin/env bash

command -v op >/dev/null 2>&1 || {
  echo >&2 "I require 1Password CLI but it's not installed. Aborting."
  exit 1
}

# token="$(op read 'op://Consume/GitHub Consume Service Account Token/credential')"

git pull origin prod

cur_origin="$(git remote get-url origin)"
# git remote set-url origin "https://te-conbot:$token@github.com/timeedit/te-consume.git"

cur_branch="$(git rev-parse --abrev-ref HEAD)"
branch="${1:-main}"

# How many commits are ahead of main in the prod branch
ahead="$(git rev-list --left-right --count prod..."$branch" | awk '{ print $1 }')"

if ((ahead > 0)); then
  echo "The 'prod' branch is ahead by '$ahead' commits. Merge any quick fixes to 'prod' into '$branch' and try again."
  git remote set-url origin "$cur_origin"
  exit 1
fi

function question {
  read -r -p "Are you sure you want to release prod? This will reset the 'prod' branch to '$branch'. (y/N) " answer
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

if [[ $cur_branch == "prod" ]]; then
  (git reset --hard "$branch" \
    && git push --force) || {
    git remote set-url origin "$cur_origin"
  }
else
  (git checkout prod \
    && git reset --hard "$branch" \
    && git push --force \
    && git checkout -) || {
    git remote set-url origin "$cur_origin"
  }
fi

git remote set-url origin "$cur_origin"
