
function on_exit --on-process %self
  echo "fish is now exiting"
end

function fish_greeting
#  echo "If you can't do it, who will?"
#  set ran random
  fortune -as | cowthink
  echo
end

if status --is-interactive
  echo "-- (tux) --"
  echo "Think about reading a page or more today!"
end



# setting the path ... annoying
for i in ~/.cabal/bin ~/.local/bin /opt/cabal/1.20/bin /opt/ghc/*/bin /opt/ghc/bin ~/.local/bin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/games/ /usr/lib/postgresql/9.3/bin ~/.nvm ~/Documents/scripts+configs/scripts ~/.local/bin
  if not contains $i $PATH
    set -x PATH $i $PATH
  end
end
# maybe additional places: /usr/local/sbin

env eval "(!stack --bash-completion-script stack)"

set NVM_DIR ~/.nvm
if test -s "$NVM_DIR/nvm.sh"
  bash . "$NVM_DIR/nvm.sh"
end


# set -gx PATH "~/.local/bin:~/.cabal/bin:~/.local/bin:/opt/cabal/1.20/bin:/opt/ghc/*/bin:/opt/ghc/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games/"
set -x PATH ~/.local/bin $PATH
set -x PATH ~/.cargo/bin $PATH


# set for factis-environment
# set -x way f
# set -x DOCKER_HOST tcp://127.0.0.1:2375
# 

# transset --id $WINDOWID >/dev/null
