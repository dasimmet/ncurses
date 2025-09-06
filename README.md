# ncurses built with zig

my try at building ncurses without autotools.
still a big todo...working on gettig the demo to run...

also, the c files in `src` are copied from an autotools build on ubuntu amd64...
most of them use `awk` to process the capability data files,
maybe those tools could become zig build steps.

```
zig build
```
