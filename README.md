# run_eos

This tool is intended to make it easier to launch and manage multiple EOS.IO chains.

Sample snippet for including in a shell runcom file (e.g. ~/.bashrc):

```sh
source ${HOME}/git/run_eos/run_eos.sh

export tmux_eos_nets="superhero xbl"

alias eosioconf_superhero="eosioconf ${HOME}/SuperDawn-2018-03-18 ${HOME}/eos_superhero 127.0.0.1:8889 127.0.0.1:9989" # 9876

alias eosioconf_xbl="eosioconf /usr/local ${HOME}/eos_xbl 127.0.0.1:8888 127.0.0.1:9988" # 9872
```

This way you can launch separately each chain in its own tmux session, using the tmux_eos function.
To add a chain simply setup its alias and add it to tmux_eos_nets string.

