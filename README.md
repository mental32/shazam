# shazam

## Messed around with LLVM IR and wrote a shell.

### Brief

I've been wanting to write something in LLVM-IR for a while now and I've come to the conclusion that it's not a great experience at all... but that's okay! LLVM IR is and **IR** it's an _intermediate representation_, something for the rest of the llvm toolchain to consume and something that compilers should be emitting.

Now if you want to write some low level non-platform specific logic I think it does a lovely job considering its very high level when compared with assembly **BUT** the second you need platform specific logic get ready to link against a libc or shell out to inline assembly in your functions (at which point you might as well be writing assembly and linking against that.)

### Why is it called "shazam"?

I originally wanted to write this shell using x86 assembly so I thought of the name: "sh" + "asm" -> "shazam"

Check out the first commit if you don't believe me.

[![asciicast](https://asciinema.org/a/iRbZdGXzDMFYT9pTOFI5I2K0e.png)](https://asciinema.org/a/iRbZdGXzDMFYT9pTOFI5I2K0e)
