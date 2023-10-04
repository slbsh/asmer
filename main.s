.equ AF_INET, 2
.equ SOCK_STREAM, 1
.equ INADDR_ANY, 0
.equ O_RDONLY, 0

.equ SYS_OPEN,     0x02
.equ SYS_STAT,     0x04
.equ SYS_BIND,     0x31
.equ SYS_SOCKET,   0x29
.equ SYS_ACCEPT,   0x2b
.equ SYS_LISTEN,   0x32

.equ INDEX_BUF_SIZE, 4096 /* 4kb */

.section .rodata
index_file:    .string "index.html\0"

read_msg:     .string "\x1b[1m[INFO]:\x1b[0m Reading File\n\0"
starting_msg: .string "\x1b[1m[INFO]:\x1b[0m Starting Server!\n\0"
closing_msg:  .string "\x1b[1m[INFO]:\x1b[0m Closing Socket!\n\0"
recieved_msg: .string "\x1b[1m[INFO]:\x1b[0m Recieved Request\n\0"


ERROR:        .string "\x1b[31;1m[ERROR]\x1b[0m \0"
NEWLINE:      .string "\n\0"

header:       .string "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n\0"

sockaddr_in:  .word AF_INET
              .word 0x901f     /* port (8080) */ 
              .long INADDR_ANY /* addr */
              .quad 0x0        /* pad */
sockaddr_len: .long 18

backlog:      .long 5

.section .bss
exit_code:    .word 0
fd:           .long 0
conn_fd:      .long 0

index_fd:     .long 0
index_len:    .quad 0
index_buf:    .space INDEX_BUF_SIZE

conv_buf:     .quad 0  /* for uint -> ascii */

.section .text
.globl   _start 

.macro write dest, msg, len
   movq $0x01, %rax
   movl \dest, %edi
   movq \msg, %rsi
   movq \len, %rdx
   syscall
.endm

.macro exit code
   movq $0x3c, %rax
   movw \code, %di
   syscall
.endm

.macro close fd
   movq $0x03, %rax
   movq \fd, %rdi
   syscall
.endm

.macro print dest, msg 
   leaq \msg, %rsi
   movl \dest, %edi
   call print
.endm

.macro print_num num
   movw \num, %ax
   call print_num
.endm

.macro read dest, buf, len
   movq $0x00, %rax
   movq \dest, %rdi
   leaq \buf, %rsi
   movq \len, %rdx
   syscall
.endm

_start:
/* open index file */
   print $1, read_msg(%rip)

   movq $SYS_OPEN, %rax
   leaq index_file(%rip), %rdi
   movq $O_RDONLY, %rsi 
   syscall

   pushq %rax /* save fd */
   call test_error

   read (%rsp), index_buf(%rip), $INDEX_BUF_SIZE

   movq %rax, index_len(%rip) /* bytes read */
   call test_error

   close (%rsp) /* close index file */
   popq %rax /* clear stack */

/* create */ 
   print $1, starting_msg(%rip)

   movq $SYS_SOCKET, %rax
   movq $AF_INET, %rdi
   movq $SOCK_STREAM, %rsi
   syscall
   
   movl %eax, fd(%rip)  /* save fd */
   call test_error

/* bind */
   movq $SYS_BIND, %rax
   movl fd(%rip), %edi
   leaq sockaddr_in(%rip), %rsi
   movl sockaddr_len(%rip), %edx
   syscall

   call test_error

/* listen */
   movq $SYS_LISTEN, %rax
   movl fd(%rip), %edi
   movl backlog(%rip), %esi
   syscall

   call test_error

accept_loop: /* accept */
   movq $SYS_ACCEPT, %rax
   movl fd(%rip), %edi
   movq $0, %rsi
   movl $0, %edx
   syscall

   pushq %rax /* save connection fd */
   print $1, recieved_msg(%rip)
   call test_error

/* write */
   print (%rsp), header(%rip)
   print (%rsp), index_buf(%rip)
   close (%rsp) /* close connection */
   popq %rax /* clear stack */

   jmp accept_loop 
/* infinite loop */


print:  /* msg in rsi ; dest in edi*/
   xorq %rdx, %rdx
_print_loop:
   movb (%rsi, %rdx), %al /* load char */
   cmp $0, %al
   je _print_done
   incq %rdx  /* inc index */
   jmp _print_loop

_print_done:
   write %edi, %rsi, %rdx
   xorq %rdx, %rdx /* clear rdx */
   ret


print_num: /* num in ax  ; signed ints cause UB*/
   movb $10, %bl /* divisor */
   movq $7, %rcx /* max digits */
   leaq conv_buf(%rip), %rdi

_conv_loop:
   cmp $0, %ax
   je _conv_done

   divb %bl
   addb $48, %ah
   movb %ah, (%rdi, %rcx)
   decb %cl
   xorb %ah, %ah

   cmp $7, %cl
   jl _conv_loop

_conv_done:
   leaq conv_buf(%rip), %rsi
   write $1, %rsi, $8
   movq $0, conv_buf(%rip) /* clear buffer */
   ret
   

test_error:
   cmp $0, %rax
   jl error
   ret

error:
   pushq %rax

   print $1, ERROR(%rip)

   popq  %rax
   negq  %rax
   print_num %ax

   print $1, NEWLINE(%rip)

/* socket close */
   print $1, closing_msg(%rip)

   close fd(%rip)
   exit $1
