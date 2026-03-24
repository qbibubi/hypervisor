# TODO 24-03-2026

- [ ] Create automation script
    - [ ] Restarting and refreshing VM setups - applying snapshots
    - [ ] Opening two terminal windows and running `debuggee` and `debugger`
        - [ ] Make `tmux` specific tabs that would be open through sessions with names `debugger` and `debuggee`
- [ ] What is `SVM` and `nSVM` in AMD CPUs
- [ ] What is `NPT` and how it operates in AMD CPUs
    - [ ] How is it different from Intel EPTs and what are the mechanisms behind it
- [ ] Talk with Tristan about the way of putting the hypervisor into memory
    - [ ] Is this gonna be a driver -> does it have to be signed if yes or do we have a method to conceal it
    - [ ] Are we gonna use a bootkit to load it?
    - [ ] How `Secure Boot` and `TPM` affect the place where the hypervisor is in memory
        - Seems like it has to be in memory as a driver or something like that
