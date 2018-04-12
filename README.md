# run_eos

This tool is intended to make it easier to launch and manage multiple EOS.IO chains.

Sample snippet for including in a shell runcom file (e.g. ~/.bashrc):

```sh
source ${HOME}/git/run_eos/run_eos.sh

export tmux_eos_nets="superhero2 xbl"

superhero2="${HOME}/eos_superhero_dawn2"
alias eosconf_superhero2="eosconf ${HOME}/SuperDawn-2018-03-18 ${superhero2}/data ${superhero2}/config ${superhero2}/wallet 127.0.0.1 8889 127.0.0.1 9999" # 9876

xbl="${HOME}/eos_xbl_dawn3"
alias eosconf_xbl="eosconf /usr/local ${xbl}/data ${xbl}/config ${xbl}/wallet 127.0.0.1 8888 127.0.0.1 8890" # 9872
```

This way you can launch separately each chain in its own tmux session, using the tmux_eos function.
To add a chain simply setup its alias and add it to tmux_eos_nets string.

