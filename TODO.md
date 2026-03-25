# TODO 24-03-2026

- [ ] Setup debugger VM with MSVC toolchain for compilation
- [ ] What is `SVM` and `nSVM` in AMD CPUs
- [ ] What is `NPT` and how it operates in AMD CPUs
    - [ ] How is it different from Intel EPTs and what are the mechanisms behind it
- [ ] Create automation script
    - [x] Restarting and refreshing VM setups - applying snapshots
        - [ ] All automation sccripts could be connected into ONE script honestly with passing proper flags to do specific tasks
    - [ ] Opening two terminal windows and running `debuggee` and `debugger`
        - [ ] Make `tmux` specific tabs that would be open through sessions with names `debugger` and `debuggee`

# BUGS

- [ ] `virtiofsd` drives do not work for debuggee machine 
    - [ ] Missing virtiofs driver on debuggee
    - [ ] Missing viriotfsd setup on host
