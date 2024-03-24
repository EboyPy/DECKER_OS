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

%DEFINE DECKER_VER      '0.1.0'
%DEFINE DECKER_API_VER  1
%DEFINE RADDER_VER      '0.1.0'

;This is the location of disk operations
;24K after the point where the kernel has loaded
;it's 8K in size because programs load after it at the 32K point

disk_buffer equ 24576

;callvectors is a static locations for system functions
; ! they cannot be moved !
; # how they works:
; # name             position
; # callvector1      0x0000
; # callvector2      0x0003
; # callvector1      0x0006
; # callvector2      0x0009
; # callvector_n     0x000n
; # callvector_n + 1 0x000n + 0x0003
; # ...

kernel_callvectors:
    jmp kernel_main
    jmp kernel_shutdown
    jmp kernel_reboot
    jmp kernel_mode_safe
    jmp kernel_mode_highmemory
    jmp kernel_mode_memoryextender
    jmp kernel_autoexec
    jmp kernel_autoexecscript
    jmp kernel_setupfile
    jmp kernel_systemregistersfile
    jmp kernel_drivers_graphics
    jmp kernel_drivers_mouse
    jmp kernel_drivers_keyboard
    jmp kernel_drivers_sound
    jmp kernel_drivers_filesystems
    jmp kernel_drivers_fat12longnames
    jmp kernel_drivers_wifi
    jmp kernel_drivers_bluetooth
    jmp kernel_drivers_ethernet
    jmp kernel_drivers_more
    jmp kernel_radder
    jmp kernel_mode_video_comandline
    jmp kernel_mode_video_pseudogui
    jmp kernel_mode_video_gui
    jmp kernel_mode_video_amd
    jmp kernel_mode_video_intel
    jmp kernel_mode_video_nvidia
    jmp kernel_mode_video_other
    jmp kernel_userland_init
    jmp kernel_userland_startup
    jmp kernel_userland_exit
    jmp kernel_standartlibrary_init
    jmp kernel_standartinput_init
    jmp kernel_standartoutput_init
    jmp kernel_standartinputoutput_init
    jmp kernel_standartlibrary_setmode
    jmp kernel_standartlibrary_settextsize
    jmp kernel_standartlibrary_settextfont
    jmp kernel_standartlibrary_settextcolour
    jmp kernel_standartlibrary_setpixelsize
    jmp kernel_standartlibrary_setpixelcolour
    jmp kernel_standartlibrary_printstring
    jmp kernel_standartlibrary_printhex1
    jmp kernel_standartlibrary_printhex2
    jmp kernel_standartlibrary_printhex4
    jmp kernel_standartlibrary_printhex8
    jmp kernel_standartlibrary_printhex16
    jmp kernel_standartlibrary_printhex32
    jmp kernel_standartlibrary_printhex64
    jmp kernel_standartlibrary_getcharacter
    jmp kernel_standartlibrary_getstring
    jmp kernel_standartlibrary_getinterger
    jmp kernel_standartlibrary_getlong
    jmp kernel_standartlibrary_getlonglong
    jmp kernel_standartlibrary_getfloat
    jmp kernel_standartlibrary_getdouble
    jmp kernel_standartlibrary_gettime
    jmp kernel_standartlibrary_getosversion
    jmp kernel_standartlibrary_getapiversion
    jmp kernel_standartlibrary_getrandomint
    jmp kernel_standartlibrary_drawpixel
    jmp kernel_standartlibrary_drawchar
    jmp kernel_standartlibrary_drawline
    jmp kernel_standartlibrary_drawrectangle
    jmp kernel_standartlibrary_drawcircle
    jmp kernel_standartlibrary_drawtriangle
    jmp kernel_standartlibrary_movecursor
    jmp kernel_standartlibrary_showcursor
    jmp kernel_standartlibrary_hidecursor
    jmp kernel_standartlibrary_clearscreen
    jmp kernel_standartlibrary_waitkey
    jmp kernel_standartlibrary_inttostring
    jmp kernel_standartlibrary_stringtoint
    jmp kernel_standartlibrary_longtostring
    jmp kernel_standartlibrary_stringtolong
    jmp kernel_standartlibrary_port_init
    jmp kernel_standartlibrary_port_byteinput
    jmp kernel_standartlibrary_port_byteoutput
    jmp kernel_standartlibrary_port_getviaserial
    jmp kernel_standartlibrary_port_sendviaserial
    jmp kernel_standartlibrary_disk_createfile
    jmp kernel_standartlibrary_disk_findfile
    jmp kernel_standartlibrary_disk_readfile
    jmp kernel_standartlibrary_disk_writefile
    jmp kernel_standartlibrary_disk_loadfile
    jmp kernel_standartlibrary_disk_executefile
    jmp kernel_standartlibrary_disk_deletefile
    jmp kernel_standartlibrary_disk_createdirectory
    jmp kernel_standartlibrary_disk_readdirectory
    jmp kernel_standartlibrary_disk_writedirectory
    jmp kernel_standartlibrary_disk_deletedirectory
    jmp kernel_standartlibrary_time_set
    jmp kernel_standartlibrary_time_read
    jmp kernel_standartlibrary_time_setformat
    jmp kernel_standartlibrary_date_set
    jmp kernel_standartlibrary_date_read
    jmp kernel_standartlibrary_date_setformat
    jmp kernel_standartlibrary_dumpregisters
    jmp kernel_standartlibrary_processes_create
    jmp kernel_standartlibrary_processes_find
    jmp kernel_standartlibrary_processes_getinfo
    jmp kernel_standartlibrary_processes_delete

;main code of kernel
kernel_main:
    cli                                         ;clear interrupts
    mov ax, 0
    mov ss, ax                                  ;set stack segment and pointer
    mov sp, 0x0FFFF
    sti                                         ;restore interrupts
    cld                                         ;the default direction for string operations will be "upper"
                                                ;incrementing address in RAM
    mov ax, 0x2000                              ;set all segments to match the kernel position
    mov ds, ax                                  ;here we don't need to bother segments with programs and OS
    mov es, ax                                  ;they are living entirely in 64K
    mov fs, ax
    mov gs, ax
    cmp dl, 0
    je kernel_nochange
    mov [mbr_bootdevicenumber], dl              ;save boot device number
    push es
    mov ah, 8                                   ;get drive parameters
    int 0x13
    pop es
    and cx, 0x3F                                ;maximum sectors number
    mov [SectorsPerTrack], cx                      ;sectors numbers starts at 1
    %ifdef INTEL386
        movzx dx, dh                            ;maximum head number ; !!! for i386 !!!
    %else
        %ifdef INTEL186
            mov al, dh                          ;maximum head number
            mov ah, 0x00
            mov dx, ax
        %endif
    %endif
    add dx, 1
    mov [Sides], dx

kernel_nochange:
	mov ax, 1003h			                    ;set text output with certain attributes
	mov bx, 0			                        ;to be bright, and not blinking
	int 10h

kernel_autoexec:
    mov ax, kernel_autoexec_binary_filename
    call kernel_standartlibrary_disk_findfile
    jmp near kernel_userland_init
    mov cx, 32768
    call kernel_standartlibrary_disk_loadfile
    jmp kernel_standartlibrary_disk_executefile
    jmp near kernel_userland_init

kernel_autoexecscript:
    mov ax, kernel_autoexec_script_filename
    call kernel_standartlibrary_disk_findfile
    jmp near kernel_userland_init
    mov cx, 32768
    call kernel_standartlibrary_disk_loadfile
    mov ax, 32768
    jmp kernel_standartlibrary_disk_executefile

kernel_userland_init:
    mov si, kernel_welcome
    call kernel_standartlibrary_printstring
    mov si, kernel_API_version
    call kernel_standartlibrary_printstring
    mov si, kernel_radder_welcome
    call kernel_standartlibrary_printstring

kernel_shutdown:
    mov ax, 0x1000
    mov ax, ss
    mov sp, 0xf000
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15

kernel_reboot:
    mov ax, 0                                   ;reboot the system
    int 0x19

;variables
kernel_welcome:         db 'DECKER ', DECKER_VER, 0
kernel_API_version:     db 'DECKER API VER', DECKER_API_VER, 0
kernel_radder_welcome:  db 'RADDER SI', RADDER_VER, 0x0D, 0x0A, 'TYPE HELP FOR MORE INFO', 0

kernel_autoexec_binary_filename db 'AUTOEXEC.EXE'
kernel_autoexec_script_filename db 'AUTOEXEC.BAS'
kernel_setup_filename           db 'SETUP.INI'
