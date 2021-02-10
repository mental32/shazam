; A small shell implemented in LLVM IR for 64-bit linux systems.

; -- external declarations

%libc.File = type opaque

declare %libc.File* @fdopen(i32, i8*)

declare dso_local void @puts(i8*)

declare dso_local void @fputs(i8*, %libc.File*)

declare dso_local void @fflush(%libc.File*)

declare dso_local i64 @feof(%libc.File*)

declare dso_local void @exit(i32)

declare dso_local i8* @malloc(i64)

declare dso_local void @free(i8*)

; Function Attrs: argmemonly nofree nosync nounwind willreturn
declare void @llvm.memcpy.p0i8.p0i8.i64(i8* noalias nocapture writeonly, i8* noalias nocapture readonly, i64, i1 immarg) #3

attributes #3 = { argmemonly nofree nosync nounwind willreturn }

; -- local definitions

@shazam.prompt = private unnamed_addr constant [3 x i8] c"$ \00"

@.str.unreachable = private unnamed_addr constant [28 x i8] c"Entered unreachable code...\00"

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

%struct.IO = type { %libc.File*, %libc.File*, %libc.File* }

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

define internal i1 @VecT_push(%struct.VecT* %0, i8* %1, i64 %size) {
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

    ret i1 false
}

; -- functions

define private %libc.File* @open(i32 %fd, i64 %mode) {
    %1 = getelementptr inbounds [6 x i8*], [6 x i8*]* @.modes, i64 0, i64 0
    %2 = getelementptr inbounds i8*, i8** %1, i64 %mode
    %3 = load i8*, i8** %2

    %4 = call %libc.File* @fdopen(i32 %fd, i8* %3)

    ret %libc.File* %4
}

define private void @unreachable() {
    %1 = call %libc.File* @open(i32 2, i64 2) ; fd=stderr mode="w"
    %2 = bitcast [28 x i8]* @.str.unreachable to i8*

    call void @fputs(i8* %2, %libc.File* %1)

    call void @exit(i32 1)

    ret void
}

define dso_local i64 @main() {
    ; %1 = alloca %struct.VecT
    ; call i8* @VecT_with_capacity(%struct.VecT* %1, i64 8, i64 8)

    ; %3 = alloca i64
    ; store i64 0, i64* %3
    ; %4 = bitcast i64* %3 to i8*

    ; call i1 @VecT_push(%struct.VecT* %1, i8* %4, i64 8)
    ; call i8* @VecT_pop(%struct.VecT* %1, i64 8)

    ; %a = getelementptr inbounds %struct.VecT, %struct.VecT* %1, i32 0, i32 1
    ; %b = load i64, i64* %a

    ; %c = getelementptr inbounds %struct.VecT, %struct.VecT* %1, i32 0, i32 0
    ; %d = load i8*, i8** %c

    ; call void @free(i8* %d)

    ret i64 420
}
