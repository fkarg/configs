#!/bin/sh
# this is just a little script to rebase-pulling all git-directories from their respective sources in your ~/Coding dir, but you can change that
# You can push too or any other command you wanna execute in such a directory

find ~/Coding/ -type d -name .git \
| xargs -n 1 dirname \
| sort \
| while read line; do echo ' ' && echo "---- ----  --- -- Next -- ---  ---- ----" && echo ' ' &&
    echo $line && echo ' ' && cd $line && git fetch && git stash && git pull --rebase && git stash pop; done
#    echo $line && echo ' ' && cd $line && get fetch && git stash && git push && git stash pop; done

# removing all local branches that have been fully merged in
# git branch -D `git branch --merged origin/master | grep "^  " | xargs`
