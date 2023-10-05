# asmer 
A simple web server written in x86\_64 (AT&T) assembly.  

It serves the contents of the `index.html` file in the current directory on port 8080, and that's all, there's also some logging, but yeah. 
Might Implement a parser in the future, hot reload of the files served, and some cmdline args.


## Building

make sure you have `as` and `ld` in your `$PATH`, then run the following:

```
$ make
$ ./main
```

> **🚨 This project only supports x86\_64 Linux, Support for Windows or OSX isn't planned.**
