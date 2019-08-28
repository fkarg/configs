#!/bin/bash
# this is just a little script to rebase-pulling all git-directories from their respective sources in your ~/Coding dir, but you can change that
# You can push too or any other command you wanna execute in such a directory

# # Documenting exclude-function failure:
#
# excludestr=(
#     high-gamma-dataset
#     eeg-interpolation-mapping
#     EEGLearn
# )
#
#
# exclude () {
#     name=${1:-$(</dev/stdin)};
#
#     if [ -z "$name" ]
#     then
#         echo "something is broken, no argument passed"
#         # exit 1
#     fi
#     echo new
#     echo $name
#     args=" -v "
#
#     for ename in "${excludestr[@]}"; do
#         args+=" -e $ename"
#         # echo "name: $name"
#         # echo "ename: $ename"
#         # name=$(echo $name | grep -v $ename)
#         # echo name: $name
#     done
#     echo $args
#     res=$(echo $name | grep $args)
#
#     if [ -z "$res" ]
#     then
#         echo "something is broken, name is empty"
#     fi
#
#     return $res
# }
#
# echo searching repositories ...
# find ~/Coding/ -type d -name .git \
# | xargs -n 1 dirname \
# | sort \
# | exclude \
# | while read line; do echo $line; done
#
# exit 0

find ~/Coding/ -type d -name .git \
| xargs -n 1 dirname \
| grep -v high-gamma-dataset \
| grep -v eeg-interpolation-mapping \
| grep -v EEGLearn \
| while read line; do echo ' ' && echo "---- ----  --- -- Next -- ---  ---- ----" && echo ' ' &&
    echo $line && echo ' ' && cd $line && git fetch && git stash && git pull --rebase --all && git stash pop; done
#    echo $line && echo ' ' && cd $line && get fetch && git stash && git push && git stash pop; done
exit 0

# removing all local branches that have been fully merged in
# git branch -D `git branch --merged origin/master | grep "^  " | xargs`

