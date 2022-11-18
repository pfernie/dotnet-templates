#!/usr/bin/env bash

git_status=`git status --porcelain`
if [[ ! -z $git_status ]]; then
  echo -e "\e[31muncommitted state:\e[0m"
  git status -s
  echo -e "\e[31mplease commit or tidy uncommitted state before running release\e[0m"
  exit
fi

# takes the tag as an argument (e.g. v0.1.0)
if [ -n "$1" ]; then
  if ! $(echo "${1}"|grep -q '^v[0-9]\+\.[0-9]\+\.[0-9]\+$'); then
    echo -e "\e[31m${1} not a version of the expected format; please use v#.#.# format\e[0m"
    exit
  fi

  if [ -n "$2" ]; then
    if [ ! -e "${2}" ]; then
      echo -e "\e[31mTarget .csproj file ${2} does not exist current directory\e[0m"
      exit
    fi
    csproj_file="$2"
  else
    csproj_count=$(find . -maxdepth 1 -type f -name '*.csproj'|wc -l)
    if [[ "${csproj_count}" -eq 0 ]]; then
      echo -e "\e[31mNo .csproj file found in current directory\e[0m"
      exit
    elif [[ "${csproj_count}" -gt 1 ]]; then
      echo -e "\e[31mMultiple .csproj files found in current directory, specify one explicitly (./release.sh ${1} <.csproj>)\e[0m"
      echo $(find . -maxdepth 1 -type f -name '*.csproj')
      exit
    else
      csproj_file=$(find . -maxdepth 1 -type f -name '*.csproj' -print -quit)
    fi
  fi

  # update the version
  msg="<!-- managed by release.sh -->"
  csproj_file=$(find . -maxdepth 1 -type f -name '*.csproj')
  sed "s/<Version>.*<\/Version>\s*${msg}/<Version>${1#v}<\/Version> ${msg}/" -i "${csproj_file}"
  # update the changelog
  git cliff --date-order --sort newest --unreleased --tag "$1" --prepend CHANGELOG.md
  git diff
  echo -e -n "\e[33mProceed? \e[0m"
  read -n 1 -s -p "[y/N] " proceed
  echo
  if [[ "${proceed}" != "y" ]]; then
    echo -e "\e[31maborting; leaving dirty state:\e[0m"
    git status -s
    exit
  fi
  git add -A
  git commit -m "chore(release): prepare for $1"
  git show
  # generate a changelog for the tag message
  export GIT_CLIFF_TEMPLATE="\
    {% for group, commits in commits | group_by(attribute=\"group\") %}
    {{ group | upper_first }}\
      {% for commit in commits %}
      - {% if commit.breaking %}(breaking) {% endif %}{{ commit.message | upper_first }} ({{ commit.id | truncate(length=7, end=\"\") }})\
        {% endfor %}
        {% endfor %}"
  changelog=$(git cliff --date-order --sort newest --unreleased --strip all)
  git tag "$1" -m "Release $1" -m "$changelog"
  git show -q "$1"
else
  echo "warn: please provide a tag"
fi
