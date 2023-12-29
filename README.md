# Protohackers Coding Problems

https://protohackers.com


## Notes

MacOS can't handle the connection storm for problem 9. TODO: try to fix limits to see if that helps:

```bash
# https://josephmate.github.io/2022-04-14-max-connections/
# For a bigSur 11.4 Mac, you can increase the file descriptor limit with:

> sudo sysctl kern.maxfiles=2000000 kern.maxfilesperproc=2000000
kern.maxfiles: 49152 -> 2000000
kern.maxfilesperproc: 24576 -> 2000000
> sysctl -a | grep maxfiles
kern.maxfiles: 2000000
kern.maxfilesperproc: 1000000

> ulimit -Hn 2000000
>ulimit -Sn 2000000
```

But for now I solved it by spinning up an EC2 t2.micro instance and running the server there.
