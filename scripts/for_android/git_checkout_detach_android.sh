#!/bin/bash

proj_header="ssh://gerrit.transsion.com:29418/"
revision_regex="[_a-zA-Z0-9\.\-]*"

function finddir()
{
  if [ $# -ne 2 ]; then
    echo "only takes 2 parameters, but get $# paremater(s), exit..."
    exit 1
  fi

  if [ ! -d $1 ]; then
    echo "$1: should be directory, exit"
    exit 1
  fi

  dir=`cd $1 && /bin/pwd`
  dest_dir="$2"

  while :
  do
    founddir=`find $dir -maxdepth 1 -type d -name "$dest_dir"`
    if [ "$founddir" != "" ]; then
      echo "path: $founddir has be found"
      break
    fi

    if [ "$dir" == "/" ]; then
      echo "couldn't find $dest_dir in root directory"
      exit 1
    fi

    dir=`cd $dir/.. && /bin/pwd`
  done
}

function get_gitproject()
{
  if [ -f "$founddir/config" ]; then
    remote=`git remote show`
    if [ "$remote" != "" ]; then
      url=`git remote get-url $remote`
      proj=`echo $url | sed "s/${proj_header//\//\\\/}//g"`
      if [ "$proj" = "" ]; then
        echo "hasn't found git project in $remote server, exit"
        exit 1
      fi

      echo "git project: $proj"
    fi
  else
    echo "hasn't found git project repository, exit"
    exit 1
  fi
}

function git_branch_in_repo()
{
  if [ -f "$founddir/manifest.xml" ]; then
    # get default revision in manifest.xml
    default_revision=`grep '<default' $founddir/manifest.xml | grep -oE "revision=\"${revision_regex}" | sed 's/revision="//g'`

    # get git project branch in_repo
    revision=`grep "$proj" $founddir/manifest.xml | grep -oE "revision=\"${revision_regex}" | sed 's/revision="//g'`
    if [ "$revision" = "" ]; then
      echo "no revision for git project: $proj, use default revision"

      if [ "$default_revision" = "" ]; then
        echo "hasn't found default revision, exit"
        exit 1
      fi

      echo "default revision: $default_revision"
      revision=$default_revision
    fi

    echo "revision: $revision"
  else
    echo "hasn't found repo manifest.xml, exit"
    exit 1
  fi
}

function git_checkout_detach()
{
  if [ "$remote" = "" ];then
    echo "git remote is null, exit"
    exit 1
  fi

  if [ "$proj" = "" ];then
    echo "git project is null, exit"
    exit 1
  fi

  if [ "$revision" = "" ];then
    echo "git project revision is null, exit"
    exit 1
  fi

  git checkout --detach $remote/$revision
}

finddir . .git
get_gitproject
finddir . .repo
git_branch_in_repo
git_checkout_detach
