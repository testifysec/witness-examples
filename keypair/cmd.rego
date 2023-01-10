package commandrun

deny[msg] {
    input.exitcode != 0
    msg := "exitcode not 0"
}

deny[msg] {
    input.cmd[2] != "echo 'hello' > hello.txt"
    msg := "cmd not correct"
}
