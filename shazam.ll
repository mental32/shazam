; A bare bones shell for linux systems written in LLVM IR.
;
; This was incredibly painful to write...

%struct.Str = type { i8*, i64 }

@stdin = global %FILE* undef, align 8
@stdout = global %FILE* undef, align 8
@stderr = global %FILE* undef, align 8

@.prompt = private unnamed_addr constant [9 x i8] c"shazam$ \00"

@.builtin_exit = private unnamed_addr constant [6 x i8] c"exit\0A\00"

@.parser_delimiters = private unnamed_addr constant [2 x i8] c" \00"

@.read_mode = constant [2 x i8] c"r\00"
@.write_mode = constant [2 x i8] c"w\00"

define private void @setup() {
    %read = getelementptr inbounds [2 x i8], [2 x i8]* @.read_mode, i32 0, i32 0
    %stdin = call %FILE* @fdopen(i32 0, i8* %read)
    store %FILE* %stdin, %FILE** @stdin

    %write = getelementptr inbounds [2 x i8], [2 x i8]* @.write_mode, i32 0, i32 0
    %stdout = call %FILE* @fdopen(i32 0, i8* %write)
    store %FILE* %stdout, %FILE** @stdout

    ret void
}

define private void @read_line(%struct.Str* %0) {
    %stdout = load %FILE*, %FILE** @stdout

    %.prompt = bitcast [9 x i8]* @.prompt to i8*
    call void @fputs(i8* %.prompt, %FILE* %stdout)
    call void @fflush(%FILE* %stdout)

    %2 = getelementptr inbounds %struct.Str, %struct.Str* %0, i32 0, i32 0
    store i8* undef, i8** %2

    %3 = getelementptr inbounds %struct.Str, %struct.Str* %0, i32 0, i32 1
    store i64 0, i64* %3

    %stdin = load %FILE*, %FILE** @stdin
    %4 = call i64 @getline(i8** %2, i64* %3, %FILE* %stdin)

    store i64 %4, i64* %3

    ret void
}

define private i8** @parze(%struct.Str* %string, i64 %capacity, i64* %n) {
    ; Allocate a zeroed token buffer of 255 parts.
    %1 = call i8* @malloc(i64 %capacity)

    %2 = icmp eq i8* %1, null

    br i1 %2, label %Abort, label %AttemptParsing
AttemptParsing:
    call void @llvm.memset.p0i8.i64(i8* %1, i8 0, i64 %capacity, i1 true)

    %tokens = bitcast i8* %1 to i8**

    %3 = bitcast [2 x i8]* @.parser_delimiters to i8*

    %4 = getelementptr inbounds %struct.Str, %struct.Str* %string, i32 0, i32 0
    %string_as_c_str = load i8*, i8** %4

    %t.head = call i8* @strtok(i8* %string_as_c_str, i8* %3)

    %5 = icmp eq i8* %t.head, null
    br i1 %5, label %Abort, label %BeginParsing
BeginParsing:
    %6 = alloca i64, align 4
    store i64 0, i64* %6, align 4

    %7 = ptrtoint i8** %tokens to i64

    br label %ContinueParsing
BoundsCheck:
    %i = load i64, i64* %6, align 4
    %g = icmp eq i64 %i, %capacity

    br i1 %g, label %FinishParsing, label %ContinueParsing
ContinueParsing:
    %t = phi i8* [ %t.head, %BeginParsing ], [ %14, %BoundsCheck ]

    %8 = load i64, i64* %6, align 4
    %9 = add i64 %8, 1
    store i64 %9, i64* %6, align 4

    %10 = add i64 %9, %7
    %11 = inttoptr i64 %10 to i8*

    %12 = ptrtoint i8* %t to i64
    %13 = bitcast i8** %tokens to i64*

    store i64 %12, i64* %13

    ; call void @puts(i8* %t)

    %14 = call i8* @strtok(i8* null, i8* %3)

    %15 = icmp eq i8* %14, null
    br i1 %15, label %FinishParsing, label %BoundsCheck
FinishParsing:
    %16 = load i64, i64* %6
    store i64 %16, i64* %n
    ret i8** %tokens
Abort:
    ret i8** null
}

define private i1 @spawn(%struct.Str* %string) {
    ; tokenize input string
    %n = alloca i64
    %1 = call i8** @parze(%struct.Str* %string, i64 1024, i64* %n)

    %2 = load i64, i64* %n
    %3 = icmp eq i64 %2, 1

    ; check if its a builtin command
    ; otherwise try to spawn it with fork+exec
    br i1 %3, label %CheckBuiltin, label %TryForkExec
CheckBuiltin:
    %4 = load i8*, i8** %1

    %builtin_exit = bitcast [6 x i8]* @.builtin_exit to i8*

    %5 = call i64 @strcmp(i8* %4, i8* %builtin_exit)

    %6 = icmp eq i64 0, %5

    br i1 %6, label %Abort, label %TryForkExec
Abort:
    ret i1 true
TryForkExec:
    ret i1 false
}

define dso_local i64 @main() {
    call void @setup()

    %stdout = load %FILE*, %FILE** @stdout

    %string = alloca %struct.Str
    %string_as_ptr = bitcast %struct.Str* %string to i8*

    br label %Loop
Loop:
    call void @llvm.memset.p0i8.i64(i8* %string_as_ptr, i8 0, i64 9, i1 true)

    call void @read_line(%struct.Str* %string)

    %1 = getelementptr inbounds  %struct.Str, %struct.Str* %string, i32 0, i32 1
    %string_length = load i64, i64* %1

    %err = icmp eq i64 %string_length, -1

    br i1 %err, label %Exit, label %Body
Body:
    %2 = getelementptr inbounds %struct.Str, %struct.Str* %string, i32 0, i32 0
    %string_as_c_str = load i8*, i8** %2

    %exiting = call i1 @spawn(%struct.Str* %string)

    call void @free(i8* %string_as_c_str)

    br i1 %exiting, label %Exit, label %LoopTail
LoopTail:
    switch i64 %string_length, label %Loop [ i64 1, label %Exit ]
Exit:
    ret i64 %string_length
}

; libc decls

declare void @llvm.memset.p0i8.i64(i8* nocapture writeonly, i8, i64, i1 immarg)

%FILE = type opaque

declare %FILE* @fdopen(i32, i8*)

declare dso_local void @puts(i8*)

declare dso_local void @fputs(i8*, %FILE*)

declare dso_local void @fflush(%FILE*)

declare dso_local i64 @feof(%FILE*)

declare dso_local i64 @getline(i8**, i64*, %FILE*)

declare dso_local i8* @strtok(i8*, i8*)

declare dso_local i64 @strcmp(i8*, i8*)

declare dso_local noalias i8* @malloc(i64)

declare dso_local void @free(i8*)
