# this is just a little script to rebase-pulling all git-directorys from their respective sources in your ~/Coding dir, but you can change that

find ~/Coding/ -type d -name .git \
| xargs -n 1 dirname \
| sort \
| while read line; do echo ' ' && echo "---- ----  --- -- Next -- ---  ---- ----" && echo ' ' &&
    echo $line && echo ' ' && cd $line && git stash && git pull --rebase && git stash apply; done

