#!/usr/bin/env bash

trap cleanup 1 2 3 6

red=$(tput setaf 1)
green=$(tput setaf 2)
normal=$(tput setaf 7)

command -v op >/dev/null 2>&1 || {
  echo >&2 "${red}I require 1Password CLI but it's not installed. Aborting.${normal}"
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
  if [[ "$from" == "main" ]]; then
    (git checkout "$from" \
      && git push --no-verify origin "$from") || return 1
  else
    git checkout "$from" && {
      local message
      message="$(git log -1 --pretty=%B)"
      local revs
      revs="$(git rev-list --left-right --count main..."$from")"
      echo "revs $revs"
      if [[ "$revs" =~ 0' '+1 ]]; then
        echo "revs match"
      fi
      if [[ "$message" =~ (Bump version)|(Release to) ]]; then
        echo "commit match"
      fi
      # If the latest commit is one that the script created, and it's the only
      # difference between the branches, rebase with main to make sure all
      # branches are equal when releasing from a branch that is not main.
      if [[ "$message" =~ (Bump version)|(Release to) ]] && perl -ne 'exit 1 unless /0\s+1/' <<<"$revs"; then
        git checkout main \
          && git rebase "$from" \
          && git push --no-verify origin main "$from"
      else
        git push --no-verify origin "$from"
      fi
    } || return 1
    git checkout "$cur_branch"
  fi

}

function cleanup_commit {
  local message
  message="$(git log -1 --pretty=%B)"
  local cur_branch
  cur_branch="$(git rev-parse --abbrev-ref HEAD)"
  local ahead
  ahead="$(git rev-list --left-right --count "$cur_branch"...origin/"$cur_branch" | perl -F -lane '{ print $F[0] }')"
  # Remove commits that the script created if the release fails, but only if
  # the changes are still not pushed to remote.
  if [[ $message =~ (Bump version)|(Release to) ]] && ((ahead > 0)); then
    git reset --hard HEAD~1
    echo "Removing commit '$message'"
  fi
}

function cleanup {
  cleanup_commit
  git checkout "$from" && cleanup_commit
  printf "\nRestoring remote url back to '%s'.\n\n" "$cur_origin"
  git remote set-url origin "$cur_origin"
}

if [[ "$cur_branch" != "$from" ]]; then
  printf "\n${red}On the wrong branch. Swiching to '%s'. Please try again.${normal}\n\n" "$from"
  cleanup
  exit 1
fi

# token="$(op read 'op://Consume/GitHub Consume Service Account Token/credential')"

git fetch || exit 1

# Set remote url to one with the te-conbot token. Must be restored after the
# script runs or if it fails!
url_for_message="$(perl -ne 'if (/te-conbot/) { print "<project url from github>"; } else { print $_; }' <<<"$cur_origin")"
printf "\nSetting remote url to accredited service account. Look for confirmation that remote url has been restored to '%s'. If you are suspicious that this did not occur, run \`git remote get-url origin\` to check. If the url looks wrong, run \`git remote set-url origin %s\` to fix it.\n\n" "$url_for_message" "$url_for_message"
# git remote set-url origin "https://te-conbot:$token@github.com/timeedit/te-consume.git"

# How many commits are ahead of 'from' in the 'to' branch?
ahead="$(git rev-list --left-right --count "$to".."$from" | perl -F -lane '{ print $F[0] }')"

function tag {
  ver=$(perl -lane 'print if s/^\s*"version":\s?"(\d+\.\d+\.\d+.*)",?/$1/' package.json)
  git tag "v$ver" || return 1
}

if ((ahead > 0)); then
  printf "\n${red}The '%s' branch is ahead by '%s' commits. Merge any quick fixes to '%s' into '%s' and try again.${normal}\n\n" "$to" "$ahead" "$to" "$from"
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
  (
    git checkout "$to" \
      && git reset --hard "$from" \
      && tag \
      && git push --force --tags origin "$to" \
      && echo "${green}Successfully released to '${to}'.${normal}"
  ) || cleanup
else
  (
    git checkout "$to" \
      && git reset --hard "$from" \
      && git push --force origin "$to" \
      && echo "${green}Successfully released to '${to}'.${normal}"
  ) || cleanup
fi

post || {
  git remote set-url origin "$cur_origin"
}
git remote set-url origin "$cur_origin"
