#!/bin/bash
#-- Script to automate https://help.github.com/articles/why-is-git-always-asking-for-my-password

exec 3<&0

set_to_ssh () {
    echo
    echo
    echo
    echo "---- ----  --- -- Next -- ---  ---- ----"
    echo
    echo 'Do you want to switch this repository to ssh?'
    echo $1
    echo
    cd $1
    echo 'The origin would be:'
    printf "$(git remote -v)"
    echo
    echo

    echo "switch to ssh? [y/N] "
    read ans <&3

    echo answer: $ans

    if  [ "$ans" != "y" ] && [ "$ans" != "Y" ]; then
        echo "Will not change this repository. Continuing."
        cd ..
        return
    fi


    REPO_URL=`git remote -v | grep -m1 '^origin' | sed -Ene's#.*(https://[^[:space:]]*).*#\1#p'`
    if [ -z "$REPO_URL" ]; then
      echo "-- ERROR:  Could not identify Repo url."
      echo "   It is possible this repo is already using SSH instead of HTTPS."
      cd ..
      return
    fi

    REPO=`echo $REPO_URL | sed -Ene's#https://github.com/([^/]*)/(.*).git#\2#p'`
    if [ -z "$REPO" ]; then
        REPO=`echo $REPO_URL | sed -Ene's#https://github.com/([^/]*)/(.*)#\2#p'`
        if [ -z "$REPO" ]; then
          echo "-- ERROR:  Could not identify Repo."
          cd ..
          return
        fi
    fi

    USER="fkarg"
    # USER=`echo $REPO_URL | sed -Ene's#https://github.com/([^/]*)/(.*).git#\1#p'`
    # if [ -z "$USER" ]; then
    #   echo "-- ERROR:  Could not identify User."
    # fi

    NEW_URL="git@github.com:$USER/$REPO.git"
    echo "Changing repo url from "
    echo "  '$REPO_URL'"
    echo "      to "
    echo "  '$NEW_URL'"
    echo ""

    CHANGE_CMD="git remote set-url origin $NEW_URL"
    `$CHANGE_CMD`

    echo "Success"
    cd ..
}

find ~/Coding/ -type d -name .git \
| xargs -n 1 dirname \
| grep -v high-gamma-dataset \
| grep -v eeg-interpolation-mapping \
| grep -v EEGLearn \
| while read line; do set_to_ssh $line; done


