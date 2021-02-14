; A small shell implemented in LLVM IR for 64-bit linux systems.

; -- external declarations

%libc.File = type opaque

declare %libc.File* @fdopen(i32, i8*)

declare i64 @fclose(%libc.File*)

declare dso_local void @puts(i8*)

declare dso_local void @fputs(i8*, %libc.File*)

declare dso_local void @fflush(%libc.File*)

declare dso_local i64 @feof(%libc.File*)

declare dso_local i64 @getline(i8**, i64*, %libc.File*)

declare dso_local i64 @strlen(i8*)

declare dso_local i8* @strtok(i8*, i8*)

declare dso_local i64 @strcmp(i8*, i8*)

declare dso_local i32 @fork()

declare dso_local i32 @execvp(i8*, i8**)

declare dso_local i32 @waitpid(i32, i32*, i32)

declare dso_local void @perror(i8*)

declare dso_local void @exit(i32)

declare dso_local i8* @malloc(i64)

declare dso_local void @free(i8*)

; Function Attrs: argmemonly nofree nosync nounwind willreturn
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg) #3

attributes #3 = { argmemonly nofree nosync nounwind willreturn }

; -- various string constants

@shazam.prompt = private unnamed_addr constant [3 x i8] c"$ \00"

@.builtin.exit = private unnamed_addr constant [6 x i8] c"exit\0A\00"

@.str.unreachable = private unnamed_addr constant [28 x i8] c"Entered unreachable code...\00"

@.str.delims = private unnamed_addr constant [3 x i8] c" \0A\00"

@.str.read_only  = private unnamed_addr constant [2 x i8] c"r\00"
@.str.read_write = private unnamed_addr constant [3 x i8] c"r+\00"

@.str.write_only = private unnamed_addr constant [2 x i8] c"w\00"
@.str.write_read = private unnamed_addr constant [3 x i8] c"w+\00"

@.str.append      = private unnamed_addr constant [2 x i8] c"a\00"
@.str.append_read = private unnamed_addr constant [3 x i8] c"a+\00"

@.modes = constant [6 x i8*] [
    i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.read_only   , i32 0, i32 0), ; 0
    i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.read_write  , i32 0, i32 0), ; 1
    i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.write_only  , i32 0, i32 0), ; 2
    i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.write_read  , i32 0, i32 0), ; 3
    i8* getelementptr inbounds ([2 x i8], [2 x i8]* @.str.append      , i32 0, i32 0), ; 4
    i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.append_read , i32 0, i32 0)  ; 5
], align 16

; -- Vec<T>

%struct.VecT = type {
    i8*, ; data
    i64, ; length
    i64  ; capacity
}

define internal void @VecT_new(%struct.VecT* %0) {
    %2 = getelementptr inbounds %struct.VecT, %struct.VecT* %0, i32 0, i32 0
    store i8* null, i8** %2

    %3 = getelementptr inbounds %struct.VecT, %struct.VecT* %0, i32 0, i32 1
    store i64 0, i64* %3

    %4 = getelementptr inbounds %struct.VecT, %struct.VecT* %0, i32 0, i32 2
    store i64 0, i64* %4

    ret void
}

define internal i8* @VecT_with_capacity(%struct.VecT* %0, i64 %1, i64 %2) {
    call void @VecT_new(%struct.VecT* %0)

    %4 = mul i64 %1, %2

    %5 = call i8* @malloc(i64 %4)

    %6 = getelementptr inbounds %struct.VecT, %struct.VecT* %0, i32 0, i32 2
    store i64 %1, i64* %6

    %7 = getelementptr inbounds %struct.VecT, %struct.VecT* %0, i32 0, i32 0
    store i8* %5, i8** %7

    ret i8* %5
}

define internal i8* @VecT_pop(%struct.VecT* %0, i64 %size) {
    %2 = getelementptr inbounds %struct.VecT, %struct.VecT* %0, i32 0, i32 1
    %3 = load i64, i64* %2

    %4 = icmp eq i64 %3, 0

    br i1 %4, label %None, label %Some
None:
    ret i8* null
Some:
    %5 = sub i64 %3, 1
    store i64 %5, i64* %2

    %6 = mul i64 %5, %size
    %7 = getelementptr inbounds %struct.VecT, %struct.VecT* %0, i32 0, i32 0

    %8 = load i8*, i8** %7
    %9 = ptrtoint i8* %8 to i64
    %10 = add i64 %6, %9
    %11 = inttoptr i64 %10 to i8*

    ret i8* %11
}

define internal i8* @VecT_get_unchecked(%struct.VecT* %0, i64 %index, i64 %size) {
    %2 = getelementptr inbounds %struct.VecT, %struct.VecT* %0, i32 0, i32 0
    %3 = load i8*, i8** %2

    %4 = mul i64 %index, %size
    %5 = ptrtoint i8* %3 to i64

    %6 = add i64 %5, %4
    %7 = inttoptr i64 %6 to i8*

    ret i8* %7
}

define internal void @VecT_push(%struct.VecT* %0, i8* %1, i64 %size) {
    %3 = getelementptr inbounds %struct.VecT, %struct.VecT* %0, i32 0, i32 1
    %4 = load i64, i64* %3

    %5 = getelementptr inbounds %struct.VecT, %struct.VecT* %0, i32 0, i32 2
    %6 = load i64, i64* %5

    %7 = icmp eq i64 %4, %6

    br i1 %7, label %Grow, label %Write
Grow:
    %8 = mul i64 %6, 2

    %9 = getelementptr inbounds %struct.VecT, %struct.VecT* %0, i32 0, i32 0
    %10 = load i8*, i8** %9

    %11 = call i8* @VecT_with_capacity(%struct.VecT* %0, i64 %8, i64 %size)

    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %11, i8* %10, i64 %6, i1 true)

    call void @free(i8* %10)

    br label %Write
Write:
    %12 = mul i64 %4, %size
    %13 = getelementptr inbounds %struct.VecT, %struct.VecT* %0, i32 0, i32 0

    %14 = load i8*, i8** %13
    %15 = ptrtoint i8* %14 to i64
    %16 = add i64 %12, %15
    %17 = inttoptr i64 %16 to i8*

    call void @llvm.memcpy.p0i8.p0i8.i64(i8* %17, i8* %1, i64 %size, i1 true)

    %18 = add i64 %4, 1
    store i64 %18, i64* %3

    ret void
}

; -- functions

define internal %libc.File* @open(i32 %fd, i64 %mode) {
    %1 = getelementptr inbounds [6 x i8*], [6 x i8*]* @.modes, i64 0, i64 0
    %2 = getelementptr inbounds i8*, i8** %1, i64 %mode
    %3 = load i8*, i8** %2

    %4 = call %libc.File* @fdopen(i32 %fd, i8* %3)

    ret %libc.File* %4
}

define internal void @unreachable() {
    %1 = call %libc.File* @open(i32 2, i64 2) ; fd=stderr mode="w"
    %2 = bitcast [28 x i8]* @.str.unreachable to i8*

    call void @fputs(i8* %2, %libc.File* %1)

    call void @exit(i32 1)

    ret void
}

define internal i8* @input(i8* %prompt, %libc.File* %stdin, %libc.File* %stdout) {
    call void @fputs(i8* %prompt, %libc.File* %stdout)
    call void @fflush(%libc.File* %stdout)

    %1 = alloca i8*
    store i8* null, i8** %1

    %2 = alloca i64
    store i64 0, i64* %2

    %3 = call i64 @getline(i8** %1, i64* %2, %libc.File* %stdin)

    %4 = icmp eq i64 %3, -1

    br i1 %4, label %Err, label %Ok
Ok:
    %5 = load i8*, i8** %1
    ret i8* %5
Err:
    %6 = call i64 @feof(%libc.File* %stdin)
    %7 = icmp eq i64 %6, 0

    br i1 %7, label %Abort, label %Eof
Eof:
    br label %Abort
Abort:
    %8 = phi i32 [ 0, %Eof ], [ 1, %Err ]
    call void @exit(i32 %8)
    ret i8* null
}

define internal void @tokenize(i8* %string, %struct.VecT* %tokens) {
    %1 = alloca i64
    %2 = call i8* @VecT_with_capacity(%struct.VecT* %tokens, i64 8, i64 8)

    %3 = icmp eq i8* null, %2

    br i1 %3, label %OOM, label %Parse
OOM:
    call void @exit(i32 2)
    ret void
Parse:
    %delims = bitcast [3 x i8]* @.str.delims to i8*

    %t.head = call i8* @strtok(i8* %string, i8* %delims)

    %4 = ptrtoint i8* %t.head to i64
    store i64 %4, i64* %1
    %5 = bitcast i64* %1 to i8*

    br label %ParseOne
ParseOne:
    %token = phi i8* [ %t.head, %Parse ], [ %t.last, %ParseOne ]

    %6 = ptrtoint i8* %token to i64
    store i64 %6, i64* %1
    %7 = bitcast i64* %1 to i8*

    call void @VecT_push(%struct.VecT* %tokens, i8* %7, i64 8)

    %t.last = call i8* @strtok(i8* null, i8* %delims)

    %8 = icmp eq i8* %t.last, null
    br i1 %8, label %Exit, label %ParseOne
Exit:
    ret void
}

define internal i1 @try_exec_builtin(i8* %token) {
TryExit:
    %str.exit = bitcast [6 x i8]* @.builtin.exit to i8*

    %0 = call i64 @strcmp(i8* %token, i8* %str.exit)
    %1 = icmp eq i64 0, %0

    br i1 %1, label %Exit, label %Default
Exit:
    call void @exit(i32 0)
    br label %Default
Default:
    ret i1 false
}

define internal void @spawnvp_pwait(%struct.VecT* %tokens) {
    %pid = alloca i32
    %status = alloca i32, align 4

    %1 = call i32 @fork()

    %2 = icmp eq i32 %1, 0

    br i1 %2, label %Child, label %Parent
Child:
    %3 = call i8* @VecT_get_unchecked(%struct.VecT* %tokens, i64 0, i64 8)

    %a = bitcast i8* %3 to i64*
    %b = load i64, i64* %a 
    %c = inttoptr i64 %b to i8*

    %argv = bitcast i8* %3 to i8**

    %_ = call i32 @execvp(i8* %c, i8** %argv)

    call void @perror(i8* null)
    call void @exit(i32 1)

    br label %Return
Parent:
    %4 = call i32 @waitpid(i32 %1, i32* %status, i32 2)
    store i32 %4, i32* %status, align 4
    br label %CheckExited
CheckExited:
    %5 = load i32, i32* %status, align 4
    %6 = and i32 %5, 127
    %7 = icmp eq i32 %6, 0
    %8 = xor i1 %7, true
    br i1 %8, label %Return, label %Parent

; CheckSignaled:
;   %31 = load i32, i32* %5, align 4, !dbg !62
;   %32 = and i32 %31, 127, !dbg !62
;   %33 = add nsw i32 %32, 1, !dbg !62
;   %34 = trunc i32 %33 to i8, !dbg !62
;   %35 = sext i8 %34 to i32, !dbg !62
;   %36 = ashr i32 %35, 1, !dbg !62
;   %37 = icmp sgt i32 %36, 0, !dbg !62
;   %38 = xor i1 %37, true, !dbg !63
;   br label %39
Return:
    ret void
}

define internal void @execute(i8* %string) {
    %tokens = alloca %struct.VecT

    call void @tokenize(i8* %string, %struct.VecT* %tokens)

    %sentinel = alloca i8*
    store i8* null, i8** %sentinel
    %xx = bitcast i8** %sentinel to i8*

    call void @VecT_push(%struct.VecT* %tokens, i8* %xx, i64 8)

    ; Check if it's a builtin command and go from there.
    ;
    ; >> tokens.get_unchecked(0) as *const i8 // where tokens: Vec<i64>
    ; // it's also worth noting the resultant byte pointer is a CString...
    %addr = call i8* @VecT_get_unchecked(%struct.VecT* %tokens, i64 0, i64 8)

    %1 = bitcast i8* %addr to i64*
    %2 = load i64, i64* %1 
    %3 = inttoptr i64 %2 to i8*

    %4 = call i1 @try_exec_builtin(i8* %3)

    br i1 %4, label %Exit, label %ForkExec
ForkExec:
    ; * fork and then execvp(tokens)
    call void @spawnvp_pwait(%struct.VecT* %tokens)
    br label %Exit
Exit:
    %buf_ptr = getelementptr inbounds %struct.VecT, %struct.VecT* %tokens, i32 0, i32 0
    %buf = load i8*, i8** %buf_ptr

    call void @free(i8* %buf)

    ret void
}

define dso_local i64 @main() {
    %stdin = call %libc.File* @open(i32 0, i64 0); fd=stdin mode=read
    %stdout = call %libc.File* @open(i32 1, i64 3); fd=stdin mode=write

    %prompt = bitcast [3 x i8]* @shazam.prompt to i8*

    br label %LoopHead
LoopHead:
    %string = call i8* @input(i8* %prompt, %libc.File* %stdin, %libc.File* %stdout)
    %n = call i64 @strlen(i8* %string)

    ; the length includes the CR/LF which is always there
    ; so when `strlen(string) == 1` then it's an empty string.
    %is_empty = icmp eq i64 %n, 1 

    br i1 %is_empty, label %Exit, label %LoopTail
LoopTail:
    call void @execute(i8* %string)
    call void @free(i8* %string)
    br label %LoopHead
Exit:
    call i64 @fclose(%libc.File* %stdin)
    call i64 @fclose(%libc.File* %stdout)
    call void @free(i8* %string)

    ret i64 0
}
