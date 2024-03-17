;predirectives
;defines of architectures
;you must uncomment one of needed by yourself ;)
%define INTEL186
;%define INTEL386

bits 16

%ifdef INTEL186
    %ifdef INTEL386
        %error OVERDEFINE OF ARCHITECTURES: You must define one of the architecture!!!
    %endif
%endif
%ifndef INTEL186
    %ifndef INTEL386
        %error UNDEFINED ARCHITECTURE: You must define one of the architecture!!!
    %endif
%endif

%ifdef INTEL186 
    cpu 186
%else
    %ifdef INTEL386
        cpu 386
    %endif
%endif

jmp short mbr                                   ;run MBR code
nop                                             ;pad before DDT

;Disk Description Table (DDT) for 1.44Mb 3.5 inch diskettes
OEMlabel            db "DECKER_OS_010"          ;disk label
BytesPerSector      dw 512                      ;bytes per sector
SectorsPerCluster   db 1                        ;sector in hdd = cluster in floppy
ReservedForBoot     dw 1                        ;reserved sectors for boot (normal - 1)
NumberOfFATs        db 2                        ;number of copies of File Allocation Table (FAT)
RootDirEntries      dw 224                      ;number of root entries (224 * 32 = 7168 = 14 sectors)
logicalSectors      dw 2880                     ;number of logical sectors
MediumByte          db 0x0F0                    ;medium descriptor byte
SectorsPerFAT       dw 9                        ;sectors per FAT
SectorsPerTrack     dw 18                       ;sectors per track (36 / cylinder)
Sides               dw 2                        ;number of sides/heads
HiddenSectors       dd 0                        ;number of hidden sectors
LargeSectors        dd 0                        ;number of Logical Block Addressing (LBA) sectors
DriveNo             dw 12                       ;drive number
Signature           db 41                       ;drive signature (80 - HDD, 41 - floppy)
VolumeID            dd 0x12244886               ;volume IDentificator (ID)
VolumeLabel         db "DECKER_OS  "            ;volume label (11 characters)
FileSystem          db "FAT12   "               ; ! file system type, do not change !

;Master Boot Record (MBR)
mbr:
    mov ax, 0x07C0                              ;set up 4K of stack space above kernel buffer
    add ax, 544                                 ;8K buffer = 512 paragraphs + 32 loader paragraphs
    cli                                         ;disable interrupts
    mov ss, ax                                  ;changing stack
    mov sp, 4096
    sti                                         ;restore interrupts
    mov ax, 0x07C0                              ;set Data Segment (DS) to ehwre we're loaded
    mov ds, ax
    ; # a few early BIOSes are reported to set DL improperly
    %ifdef INTEL386
        cmp dl, 0                               ; !!! for i386 !!!
        je mbr_nochange                         ; !!! for i386 !!!
    %endif
    mov [mbr_bootdevicenumber], dl              ;save bootdevice number
    mov ah, 8                                   ;get drive parameters
    int 0x13
    jc mbr_disk_fatalerror
    and cx, 0x3F                                ;maximum sector number
    mov [SectorsPerTrack], cx                   ;sector number starts at 1
    %ifdef INTEL386
        movzx dx, dh                            ;maximum head number ; !!! for i386 !!!
    %else
        %ifdef INTEL186
            mov al, dh                          ;maximum head number
            mov ah, 0x00
            mov dx, ax
        %endif
    %endif
    add dx, 1                                   ;head numbers start at 0 - add 1 for total
    mov [Sides], dx

%ifdef INTEL386
    mbr_nochange:
        mov eax, 0                              ; !!! for i386 !!!
%endif

;here we need to load kernel into memory
;there I choosed is 0x2000
;start of root = reservedforboot + numberofFATs * sectorsperFAT = 19
;number of root = rootdirentries * 32bytes/entry / 512bytes/sector = 14
;start of user data = start of root + number of root = 33

mbr_disk_ok:                                    ;when ready to read first block of data
    mov ax, 19                                  ;root dir starts at logical sector 19
    call mbr_disk_lba2hts
    mov si, mbr_buffer                          ;set ES:BX to point to our buffer (in the end of code)
    mov bx, ds
    mov es, bx
    mov bx, si
    mov ah, 2                                   ;parameters for int 0x13: read sectors
    mov al, 14                                  ;floppy have 14 of them
    pusha                                       ;prepare to enter loop

mbr_disk_readrootdir:
    popa                                        ;in case, registers are altered by int 0x13
    pusha
    stc                                         ;a few BIOSes do not set porperly on error
    int 0x13                                    ;read sectors using BIOS
    jnc mbr_disk_searchdir                      ;if read went ok - skip
    call mbr_disk_reset                         ;else, reset and try again
    jnc mbr_disk_readrootdir                    ;if reset is ok - try
    jmp mbr_reboot                              ;else - double fatality for user :_(

mbr_disk_searchdir:
    popa
    mov ax, ds                                  ;root dir is now in [buffer]
    mov es, ax                                  ;set DI ti this information
    mov di, mbr_buffer
    mov cx, word [RootDirEntries]               ;searching all entries
    mov ax, 0                                   ;at offset 0

mbr_disk_nextrootentry:
    xchg cx, dx
    mov si, mbr_kernel_filename                 ;search for kernel file
    mov cx, 11
    rep cmpsb
    je mbr_disk_foundkernel                     ;pointer Di will be at offset 11
    add ax, 32                                  ;bump searched entries by 1 (32bytes/entry)
    mov di, mbr_buffer                          ;point to next entry
    add di, ax
    xchg dx, cx                                 ;get the original CX back
    loop mbr_disk_nextrootentry
    mov si, mbr_disk_message_kernelnotfound     ;if kernel not found - bail out
    call mbr_video_tty_printstring
    jmp mbr_reboot

mbr_disk_foundkernel:                           ;fetch cluster and load FAT into RAM
    mov ax, word [es:di + 0x0F]                 ;offset 11 + 15 = 26, contains 1st cluster
    mov word [mbr_cluster], ax
    mov ax, 1                                   ;sector 1 - 1st sector of 1st FAT
    call mbr_disk_lba2hts
    mov di, mbr_buffer                          ;ES:BX points to our buffer
    mov bx, di
    mov ah, 2                                   ;parameters for int 0x13: read (FAT) sectors
    mov al, 9                                   ;9 sectors of 1st FAT
    pusha                                       ;prepare to enter loop

mbr_disk_readFAT:
    popa                                        ;in case, registers are altered by int 0x13
    pusha
    stc
    int 0x13                                    ;read sectors using BIOS
    jnc mbr_disk_readFATok                      ;if read went ok - skip
    call mbr_disk_reset                         ;else, reset disk and try again
    jnc mbr_disk_readFAT                        ;reset is ok?

mbr_disk_fatalerror:
    mov si, mbr_diskfatalerror                  ;if not, print arror and reboot
    call mbr_video_tty_printstring
    jmp mbr_reboot

mbr_disk_readFATok:
    popa
    mov ax, 0x2000                              ;kernel segment
    mov es, ax
    mov bx, 0
    mov ah, 2                                   ;parameters for int 0x13: read
    mov al, 1
    push ax

;here we must load the FAT fromthe disk
;here's how we find out where is starts:
;FAT cluster 0 = mediumbyte (he is also media decrsiptor) = 0x0F0
;FAT cluster 1 = filler cluster = 0x0FF
;cluster start = (cluster - 2) * sectorspercluster + start of user

mbr_disk_loadfilesector:
    mov ax, word [mbr_cluster]                  ;convertation from sector to logical
    add ax, 31
    call mbr_disk_lba2hts                       ;make appropriate parameters forint 0x13
    mov ax, 0x2000                              ;set buffer past what we have already read
    mov es, ax
    mov bx, word [mbr_pointer]
    pop ax                                      ;save in case we/int calls lose it
    push ax
    stc
    int 0x13
    jnc mbr_disk_calculatenextcluster           ;if there no error...
    call mbr_disk_reset                         ;else reset
    jmp mbr_disk_loadfilesector                 ;and retry

;in the FAT, clusters values are stored in 12 bits
;so we have to do a bit of maths to work out
;whenever we are dealing with a byte and 4 bits ofthe next byte
;or the last 4 bits of one byte and then
;the subsequent byte

mbr_disk_calculatenextcluster:
    mov ax, [mbr_cluster]
    mov dx, 0
    mov bx, 3
    mul bx
    mov bx, 2
    div bx                                      ;DX = [mbr_cluster] mod 2
    mov si, mbr_buffer
    add si, ax                                  ;AX - word in FAT for th e12 bit entry
    mov ax, word [ds:si]
    or dx, dx                                   ;if dx = 0 - even, else if 1 - odd
    jz even                                     ;if cluster is even - drop last 4 bits of word with next cluster
                                                ;else if odd - frop first 4 bits

odd:
    shr ax, 4                                   ;shift out first 4 bits (they are in another entry)
    jmp short mbr_disk_calculatenextcluster

even:
    and ax, 0x0FFF                              ;mask final 4 bits

mbr_disk_calculatenextcluster_continue:
    mov word [mbr_cluster], ax                  ;store cluster
    cmp ax, 0x0FF8                              ;oxoFF8 = end of file marker for FAT 12
    jae mbr_disk_calculatenextcluster_end
    add word [mbr_pointer], 512                 ;increase buffer pointer 1 sector length
    jmp mbr_disk_loadfilesector

mbr_disk_calculatenextcluster_end:              ;we have got the kernel to load
    pop ax                                      ;cleanup the stack (AX was pushed earlier)
    mov dl, byte [mbr_bootdevicenumber]         ;provide kernel with boot device info
    jmp 0x2000:0x0000

; # additional functions

mbr_reboot:
    mov ax, 0                                   ;wait for keystroke
    int 0x16
    mov ax, 0                                   ;reboot the system
    int 0x19

mbr_video_tty_printstring:                      ;output from SI to string
    pusha
    mov ah, 0x0E

.repeat:
    lodsb                                       ;get char from string
    cmp al, 0
    je .done                                    ;if char is zero, end of string
    int 0x10                                    ;else, print it
    jmp short .repeat

.done:
    popa
    ret

mbr_disk_reset:                                 ;reset disk by device boot number, if error - carry set
    push ax
    push dx
    mov ax, 0
    mov dl, byte [mbr_bootdevicenumber]
    stc
    int 0x13
    pop dx
    pop ax
    ret

mbr_disk_lba2hts:                               ;calculate head, track and sector settings, using logical sector in AX
                                                ;and he set correct registers
                                                ;which needed by int 0x13
    push bx
    push ax
    mov bx, ax                                  ;save logical sector
    mov dx, 0                                   ;first the sector
    div word [SectorsPerTrack]
    add dl, 0x01                                ;physycal sector starts at 1
    mov cl, dl                                  ;sectors belong in CL for int 0x13
    mov ax, bx
    mov dx, 0                                   ;now calculate the head
    div word [SectorsPerTrack]
    mov dx, 0
    div word [Sides]
    mov dh, dl                                  ;head/side
    mov ch, al                                  ;track
    pop ax
    pop bx
    mov dl, byte [mbr_bootdevicenumber]         ;set correct device
    ret

;variables
mbr_kernel_filename             db "KERNEL  SYS"                ;kernel filename
mbr_diskfatalerror              db "ERROR: DISK ERROR", 0
mbr_disk_message_kernelnotfound db "ERROR: KERNEL.SYS NOT FOUND"
mbr_bootdevicenumber            db 0                            ;boot device number
mbr_cluster                     dw 0                            ;cluster of the kernel
mbr_pointer                     dw 0                            ;pointer to buffer for kernel

times 510 - ($ - $$) db 0                       ;pad remainder of mbr with zeros
dw 0xAA55                                       ; ! boot signature, do not change !

mbr_buffer:                                     ;8K disk buffer, stack starts
