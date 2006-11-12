ideal
p386n
model flat
public C funcF
codeseg
;############################### sub_64AF70 ####################################
proc stack_alloc
    push ecx
    cmp eax, 1000h
    lea ecx, [dword esp+8]
    jb L64AF90
L64AF7C:
    sub ecx, 1000h
    sub eax, 1000h
    test [dword ecx], eax
    cmp eax, 1000h
    jnb L64AF7C
L64AF90:
    sub ecx, eax
    mov eax, esp
    test [dword ecx], eax
    mov esp, ecx
    mov ecx, [dword eax]
    mov eax, [dword eax+4]
    push eax
    retn
endp
;############################### sub_5098E0 ####################################
proc sub_5098E0
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,024h
    MOV     EAX,[DWORD EBP+010h]
    MOV     EDX,[DWORD EBP+0Ch]
    PUSH    EBX
    PUSH    ESI
    PUSH    EDI
    MOV     [DWORD EBP-8],EAX
    MOV     EDI,EDX
    MOV     ECX,EDX
    MOV     EBX,EDX
    MOV     EAX,EDX
    MOV     ESI,[DWORD EBP+8]
    MOV     [DWORD EBP+8],4
    SHL     EDI,018h
    SHR     ECX,8
    SHR     EBX,010h
    SHL     EAX,010h
    OR      EDI,ECX
    OR      EBX,EAX
    MOV     EAX,EDX
    MOV     ECX,EDX
    SHR     EAX,018h
    SHL     ECX,8
    OR      EAX,ECX
    MOV     [DWORD EBP-014h],EDI
    MOV     [DWORD EBP-0Ch],EAX
    MOV     [DWORD EBP-010h],EBX
    LEA     EAX,[DWORD ESI+0C48h]
    JMP     L509937
L509931:
    MOV     EDI,[DWORD EBP-014h]
    MOV     EBX,[DWORD EBP-010h]
L509937:
    XOR     EDI,[DWORD EAX]
    MOV     ECX,[DWORD EAX-4]
    XOR     ECX,EDX
    ADD     EAX,010h
    MOV     [DWORD EBP-4],EDI
    MOV     EDI,[DWORD EAX-0Ch]
    XOR     EDI,EBX
    MOV     EBX,[DWORD EBP-0Ch]
    MOV     [DWORD EBP+010h],EDI
    MOV     EDI,[DWORD EAX-8]
    XOR     EDI,EBX
    MOV     [DWORD EBP+0Ch],EDI
    MOV     EDI,[DWORD EBP+8]
    DEC     EDI
    MOV     [DWORD EBP+8],EDI
    JNZ     L509931
    MOV     [DWORD EBP-014h],2
L509967:
    MOV     EDX,[DWORD EBP-4]
    MOV     EAX,ECX
    SHR     EAX,2
    AND     EAX,01FFh
    MOV     [DWORD EBP-0Ch],0
    MOV     EBX,[DWORD ESI+EAX*4]
    ADD     EDX,EBX
    MOV     EBX,[DWORD EBP+010h]
    MOV     EAX,EDX
    SHR     EAX,2
    AND     EAX,01FFh
    MOV     EDI,[DWORD ESI+EAX*4]
    MOV     EAX,EDX
    SHL     EAX,017h
    SHR     EDX,9
    ADD     EBX,EDI
    MOV     EDI,[DWORD EBP+0Ch]
    OR      EAX,EDX
    MOV     EDX,EBX
    SHR     EDX,2
    AND     EDX,01FFh
    MOV     [DWORD EBP-024h],EAX
    ADD     EDI,[DWORD ESI+EDX*4]
    MOV     EDX,EBX
    SHL     EDX,017h
    SHR     EBX,9
    OR      EDX,EBX
    MOV     EBX,ECX
    SHL     EBX,017h
    SHR     ECX,9
    OR      EBX,ECX
    MOV     ECX,EDI
    SHR     ECX,2
    AND     ECX,01FFh
    MOV     [DWORD EBP+0Ch],EDI
    SHL     EDI,017h
    ADD     EBX,[DWORD ESI+ECX*4]
    MOV     ECX,[DWORD EBP+0Ch]
    SHR     ECX,9
    OR      EDI,ECX
    MOV     ECX,EBX
    SHR     ECX,2
    AND     ECX,01FFh
    MOV     [DWORD EBP-01Ch],EDX
    MOV     [DWORD EBP-020h],EDI
    MOV     [DWORD EBP-018h],EBX
    ADD     EAX,[DWORD ESI+ECX*4]
    MOV     ECX,EAX
    SHR     ECX,2
    AND     ECX,01FFh
    ADD     EDX,[DWORD ESI+ECX*4]
    MOV     ECX,EAX
    SHL     ECX,017h
    SHR     EAX,9
    OR      EAX,ECX
    MOV     ECX,EDX
    SHR     ECX,2
    AND     ECX,01FFh
    ADD     EDI,[DWORD ESI+ECX*4]
    MOV     ECX,EDX
    SHL     ECX,017h
    SHR     EDX,9
    OR      ECX,EDX
    MOV     EDX,EBX
    MOV     [DWORD EBP+010h],ECX
    MOV     ECX,EDI
    SHR     ECX,2
    SHL     EDX,017h
    SHR     EBX,9
    AND     ECX,01FFh
    OR      EDX,EBX
    ADD     EDX,[DWORD ESI+ECX*4]
    MOV     ECX,EDX
    MOV     EDX,EDI
    SHL     EDX,017h
    SHR     EDI,9
    OR      EDX,EDI
    MOV     [DWORD EBP+0Ch],EDX
    LEA     EDX,[DWORD ESI+0824h]
    MOV     [DWORD EBP-010h],EDX
    JMP     L509A5F
L509A5C:
    MOV     EAX,[DWORD EBP-4]
L509A5F:
    MOV     EBX,ECX
    MOV     EDI,ECX
    SHL     EBX,017h
    SHR     ECX,9
    AND     EDI,07FCh
    OR      EBX,ECX
    MOV     ECX,EDI
    AND     ECX,0FFFFh
    SHR     ECX,2
    MOV     ECX,[DWORD ESI+ECX*4]
    ADD     ECX,EAX
    XOR     ECX,EBX
    MOV     EDX,ECX
    MOV     EAX,ECX
    AND     EDX,07FCh
    MOV     [DWORD EBP+8],EDX
    AND     EDX,0FFFFh
    SHL     EAX,017h
    SHR     ECX,9
    SHR     EDX,2
    OR      EAX,ECX
    MOV     ECX,[DWORD EBP+010h]
    MOV     EDX,[DWORD ESI+EDX*4]
    XOR     EDX,ECX
    ADD     EDX,EAX
    ADD     EDI,EDX
    MOV     ECX,EDX
    AND     EDI,07FCh
    MOV     [DWORD EBP+010h],EDI
    AND     EDI,0FFFFh
    SHL     ECX,017h
    SHR     EDX,9
    SHR     EDI,2
    OR      ECX,EDX
    MOV     EDX,[DWORD EBP+0Ch]
    MOV     EDI,[DWORD ESI+EDI*4]
    ADD     EDI,EDX
    MOV     EDX,[DWORD EBP+8]
    XOR     EDI,ECX
    ADD     EDX,EDI
    AND     EDX,07FCh
    MOV     [DWORD EBP+8],EDX
    MOV     EDX,EDI
    SHL     EDX,017h
    SHR     EDI,9
    OR      EDX,EDI
    MOV     EDI,[DWORD EBP+8]
    AND     EDI,0FFFFh
    SHR     EDI,2
    MOV     EDI,[DWORD ESI+EDI*4]
    XOR     EDI,EBX
    MOV     EBX,[DWORD EBP+010h]
    ADD     EDI,EDX
    ADD     EBX,EDI
    AND     EBX,07FCh
    MOV     [DWORD EBP+010h],EBX
    AND     EBX,0FFFFh
    SHR     EBX,2
    XOR     EAX,[DWORD ESI+EBX*4]
    MOV     EBX,[DWORD EBP+8]
    ADD     EBX,EAX
    AND     EBX,07FCh
    MOV     [DWORD EBP+8],EBX
    AND     EBX,0FFFFh
    SHR     EBX,2
    ADD     ECX,[DWORD ESI+EBX*4]
    MOV     EBX,EAX
    SHL     EBX,017h
    SHR     EAX,9
    OR      EAX,EBX
    MOV     EBX,[DWORD EBP+010h]
    ADD     EBX,ECX
    MOV     [DWORD EBP-4],EAX
    SHR     EBX,2
    AND     EBX,01FFh
    XOR     EDX,[DWORD ESI+EBX*4]
    MOV     EBX,ECX
    SHL     EBX,017h
    SHR     ECX,9
    OR      EBX,ECX
    MOV     [DWORD EBP+010h],EBX
    MOV     ECX,EDI
    SHL     ECX,017h
    SHR     EDI,9
    OR      ECX,EDI
    MOV     EDI,[DWORD EBP+8]
    ADD     EDI,EDX
    SHR     EDI,2
    AND     EDI,01FFh
    ADD     ECX,[DWORD ESI+EDI*4]
    MOV     EDI,EDX
    SHL     EDI,017h
    SHR     EDX,9
    OR      EDI,EDX
    MOV     EDX,[DWORD EBP-010h]
    MOV     [DWORD EBP+0Ch],EDI
    MOV     EDI,[DWORD EDX-4]
    ADD     EDI,EAX
    MOV     EAX,[DWORD EBP-8]
    MOV     [DWORD EAX],EDI
    MOV     EDI,[DWORD EDX]
    ADD     EAX,4
    XOR     EDI,EBX
    MOV     EBX,[DWORD EBP+0Ch]
    MOV     [DWORD EAX],EDI
    MOV     EDI,[DWORD EDX+4]
    ADD     EAX,4
    ADD     EDI,EBX
    MOV     [DWORD EAX],EDI
    MOV     EDI,[DWORD EDX+8]
    ADD     EAX,4
    XOR     EDI,ECX
    MOV     [DWORD EAX],EDI
    ADD     EAX,4
    MOV     [DWORD EBP-8],EAX
    MOV     EAX,[DWORD EBP-0Ch]
    TEST    AL,1
    JZ      L509BC9
    MOV     EDI,[DWORD EBP-018h]
    ADD     ECX,EDI
    MOV     EDI,[DWORD EBP-01Ch]
    JMP     L509BD1
L509BC9:
    MOV     EDI,[DWORD EBP-020h]
    ADD     ECX,EDI
    MOV     EDI,[DWORD EBP-024h]
L509BD1:
    MOV     EBX,[DWORD EBP+010h]
    ADD     EDX,010h
    ADD     EBX,EDI
    INC     EAX
    CMP     EAX,040h
    MOV     [DWORD EBP+010h],EBX
    MOV     [DWORD EBP-0Ch],EAX
    MOV     [DWORD EBP-010h],EDX
    JL      L509A5C
    MOV     EAX,[DWORD EBP-014h]
    DEC     EAX
    MOV     [DWORD EBP-014h],EAX
    JNZ     L509967
    POP     EDI
    POP     ESI
    XOR     EAX,EAX
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_509C80 ####################################
proc sub_509C80
    PUSH    EBP
    MOV     EBP,ESP
    PUSH    EBX
    MOV     EBX,[DWORD EBP+010h]
    TEST    EBX,EBX
    JLE     L509CF6
    PUSH    ESI
    MOV     ESI,[DWORD EBP+8]
    PUSH    EDI
    MOV     EDI,[DWORD EBP+0Ch]
L509C93:
    CMP     [DWORD ESI+01C98h],0400h
    JL      L509CCD
    MOV     ECX,[DWORD ESI+0C94h]
    LEA     EAX,[DWORD ESI+0C98h]
    PUSH    EAX
    PUSH    ECX
    PUSH    ESI
    CALL    sub_5098E0
    MOV     EAX,[DWORD ESI+0C94h]
    ADD     ESP,0Ch
    INC     EAX
    MOV     [DWORD ESI+01C98h],0
    MOV     [DWORD ESI+0C94h],EAX
L509CCD:
    MOV     EDX,[DWORD ESI+01C98h]
    MOV     ECX,[DWORD EDI]
    ADD     EDI,4
    MOV     EAX,[DWORD ESI+EDX*4+0C98h]
    XOR     ECX,EAX
    MOV     [DWORD EDI-4],ECX
    MOV     EDX,[DWORD ESI+01C98h]
    INC     EDX
    DEC     EBX
    MOV     [DWORD ESI+01C98h],EDX
    JNZ     L509C93
    POP     EDI
    POP     ESI
L509CF6:
    POP     EBX
    POP     EBP
    RET
endp
;############################### sub_509490 ####################################
proc sub_509490
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,015Ch
    MOV     EAX,[DWORD EBP+8]
    XOR     ECX,ECX
    XOR     EDX,EDX
    PUSH    EBX
    MOV     CH,[BYTE EAX]
    MOV     DL,[BYTE EAX+2]
    MOV     CL,[BYTE EAX+1]
    ADD     EAX,4
    SHL     ECX,8
    OR      ECX,EDX
    XOR     EDX,EDX
    MOV     DL,[BYTE EAX-1]
    PUSH    ESI
    SHL     ECX,8
    OR      ECX,EDX
    XOR     EDX,EDX
    MOV     DH,[BYTE EAX]
    MOV     ESI,ECX
    MOV     DL,[BYTE EAX+1]
    XOR     ECX,ECX
    MOV     CL,[BYTE EAX+2]
    ADD     EAX,4
    SHL     EDX,8
    OR      EDX,ECX
    XOR     ECX,ECX
    MOV     CL,[BYTE EAX-1]
    XOR     EBX,EBX
    SHL     EDX,8
    MOV     BL,[BYTE EAX+2]
    OR      EDX,ECX
    XOR     ECX,ECX
    PUSH    EDI
    MOV     CH,[BYTE EAX]
    LEA     EDI,[DWORD EBP-0158h]
    MOV     CL,[BYTE EAX+1]
    ADD     EAX,4
    SHL     ECX,8
    OR      ECX,EBX
    XOR     EBX,EBX
    MOV     BL,[BYTE EAX-1]
    ADD     EAX,4
    SHL     ECX,8
    OR      ECX,EBX
    XOR     EBX,EBX
    MOV     BL,[BYTE EAX-2]
    MOV     [DWORD EBP-010h],ECX
    XOR     ECX,ECX
    MOV     [DWORD EBP-01Ch],ESI
    MOV     CH,[BYTE EAX-4]
    MOV     [DWORD EBP-014h],EDX
    MOV     CL,[BYTE EAX-3]
    SHL     ECX,8
    OR      ECX,EBX
    XOR     EBX,EBX
    MOV     BL,[BYTE EAX-1]
    SHL     ECX,8
    OR      ECX,EBX
    XOR     EBX,EBX
    MOV     BH,[BYTE EAX]
    MOV     [DWORD EBP-0Ch],ECX
    MOV     BL,[BYTE EAX+1]
    XOR     ECX,ECX
    MOV     CL,[BYTE EAX+2]
    SHL     EBX,8
    OR      EBX,ECX
    XOR     ECX,ECX
    MOV     CL,[BYTE EAX+3]
    MOV     EAX,[DWORD EBP+0Ch]
    SHL     EBX,8
    OR      EBX,ECX
    MOV     [DWORD EBP-015Ch],EAX
    MOV     ECX,0Fh
    XOR     EAX,EAX
    REP     STOS [DWORD ES:EDI]
    MOV     [DWORD EBP-018h],EBX
    LEA     EAX,[DWORD EBP-0154h]
    MOV     ECX,040h
L509567:
    MOV     EDI,[DWORD EAX+02Ch]
    XOR     EDI,[DWORD EAX+018h]
    ADD     EAX,4
    XOR     EDI,[DWORD EAX-0Ch]
    XOR     EDI,[DWORD EAX-4]
    DEC     ECX
    MOV     [DWORD EAX+034h],EDI
    JNZ     L509567
    MOV     EDI,ESI
    MOV     ESI,[DWORD EBP-0Ch]
    LEA     ECX,[DWORD EBP-015Ch]
    MOV     EAX,EDX
    MOV     EDX,[DWORD EBP-010h]
    MOV     [DWORD EBP+8],EDI
    MOV     [DWORD EBP+0Ch],EBX
    MOV     [DWORD EBP-8],ECX
    MOV     [DWORD EBP-4],014h
L50959C:
    MOV     ECX,EAX
    MOV     EBX,EDX
    NOT     ECX
    AND     ECX,ESI
    AND     EBX,EAX
    OR      ECX,EBX
    MOV     EBX,EDI
    SHR     EBX,01Bh
    SHL     EDI,5
    OR      EBX,EDI
    ADD     ECX,EBX
    MOV     EBX,[DWORD EBP-8]
    MOV     EDI,[DWORD EBX]
    ADD     EBX,4
    ADD     ECX,EDI
    MOV     EDI,[DWORD EBP+0Ch]
    MOV     [DWORD EBP+0Ch],ESI
    MOV     ESI,EDX
    MOV     EDX,EAX
    MOV     [DWORD EBP-8],EBX
    MOV     EBX,[DWORD EBP-4]
    LEA     ECX,[DWORD ECX+EDI+05A827998h]
    SHL     EDX,01Eh
    SHR     EAX,2
    OR      EDX,EAX
    MOV     EAX,[DWORD EBP+8]
    MOV     EDI,ECX
    DEC     EBX
    MOV     [DWORD EBP+8],EDI
    MOV     [DWORD EBP-4],EBX
    JNZ     L50959C
    LEA     EBX,[DWORD EBP-010Ch]
    MOV     [DWORD EBP-4],014h
    MOV     [DWORD EBP+8],EBX
L5095FB:
    MOV     EBX,ECX
    SHR     EBX,01Bh
    SHL     ECX,5
    OR      EBX,ECX
    MOV     ECX,ESI
    XOR     ECX,EDX
    XOR     ECX,EAX
    ADD     EBX,ECX
    MOV     ECX,[DWORD EBP+8]
    ADD     EBX,[DWORD ECX]
    MOV     ECX,[DWORD EBP+0Ch]
    MOV     [DWORD EBP+0Ch],ESI
    MOV     ESI,EDX
    MOV     EDX,EAX
    LEA     ECX,[DWORD EBX+ECX+06EF9EBA1h]
    MOV     EBX,[DWORD EBP+8]
    ADD     EBX,4
    SHL     EDX,01Eh
    SHR     EAX,2
    MOV     [DWORD EBP+8],EBX
    MOV     EBX,[DWORD EBP-4]
    OR      EDX,EAX
    DEC     EBX
    MOV     EAX,EDI
    MOV     EDI,ECX
    MOV     [DWORD EBP-4],EBX
    JNZ     L5095FB
    MOV     [DWORD EBP+8],EDI
    LEA     EDI,[DWORD EBP-0BCh]
    MOV     [DWORD EBP-8],EDI
    MOV     [DWORD EBP-4],014h
L509654:
    MOV     EDI,EDX
    MOV     EBX,EDX
    OR      EDI,EAX
    AND     EBX,EAX
    AND     EDI,ESI
    OR      EDI,EBX
    MOV     EBX,ECX
    SHR     EBX,01Bh
    SHL     ECX,5
    OR      EBX,ECX
    MOV     ECX,[DWORD EBP-8]
    ADD     EDI,EBX
    MOV     EBX,[DWORD ECX]
    MOV     ECX,[DWORD EBP+0Ch]
    ADD     EDI,EBX
    MOV     EBX,[DWORD EBP-8]
    ADD     EBX,4
    LEA     ECX,[DWORD EDI+ECX+07F1CBCDCh]
    MOV     EDI,ESI
    MOV     ESI,EDX
    MOV     EDX,EAX
    SHL     EDX,01Eh
    SHR     EAX,2
    MOV     [DWORD EBP-8],EBX
    MOV     EBX,[DWORD EBP-4]
    OR      EDX,EAX
    MOV     EAX,[DWORD EBP+8]
    DEC     EBX
    MOV     [DWORD EBP+0Ch],EDI
    MOV     [DWORD EBP+8],ECX
    MOV     [DWORD EBP-4],EBX
    JNZ     L509654
    LEA     EBX,[DWORD EBP-06Ch]
    MOV     [DWORD EBP-4],014h
    MOV     [DWORD EBP+0Ch],EBX
L5096B3:
    MOV     EBX,ECX
    SHR     EBX,01Bh
    SHL     ECX,5
    OR      EBX,ECX
    MOV     ECX,ESI
    XOR     ECX,EDX
    XOR     ECX,EAX
    ADD     EBX,ECX
    MOV     ECX,[DWORD EBP+0Ch]
    ADD     EBX,[DWORD ECX]
    LEA     ECX,[DWORD EBX+EDI+0AA62D1D6h]
    MOV     EBX,[DWORD EBP+0Ch]
    MOV     EDI,ESI
    MOV     ESI,EDX
    MOV     EDX,EAX
    ADD     EBX,4
    SHL     EDX,01Eh
    SHR     EAX,2
    MOV     [DWORD EBP+0Ch],EBX
    MOV     EBX,[DWORD EBP-4]
    OR      EDX,EAX
    MOV     EAX,[DWORD EBP+8]
    DEC     EBX
    MOV     [DWORD EBP+8],ECX
    MOV     [DWORD EBP-4],EBX
    JNZ     L5096B3
    MOV     EBX,[DWORD EBP-01Ch]
    ADD     EBX,ECX
    MOV     ECX,[DWORD EBP+010h]
    MOV     [DWORD ECX],EBX
    MOV     EBX,[DWORD EBP-014h]
    ADD     EAX,EBX
    MOV     [DWORD ECX+4],EAX
    MOV     EAX,[DWORD EBP-010h]
    ADD     EDX,EAX
    MOV     EAX,[DWORD EBP-018h]
    MOV     [DWORD ECX+8],EDX
    MOV     EDX,[DWORD EBP-0Ch]
    ADD     EDI,EAX
    ADD     ESI,EDX
    MOV     [DWORD ECX+010h],EDI
    MOV     [DWORD ECX+0Ch],ESI
    POP     EDI
    POP     ESI
    XOR     EAX,EAX
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_509730 ####################################
proc sub_509730
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,014h
    PUSH    EBX
    MOV     EBX,[DWORD EBP+8]
    PUSH    ESI
    MOV     ESI,[DWORD EBP+0Ch]
    PUSH    EDI
    XOR     EDI,EDI
L509741:
    MOV     EAX,066666667h
    PUSH    EBX
    IMUL    EDI
    SAR     EDX,1
    MOV     EAX,EDX
    SHR     EAX,01Fh
    ADD     EDX,EAX
    PUSH    EDX
    PUSH    ESI
    CALL    sub_509490
    ADD     EDI,5
    ADD     ESP,0Ch
    ADD     EBX,014h
    CMP     EDI,01FEh
    JL      L509741
    LEA     ECX,[DWORD EBP-014h]
    PUSH    ECX
    PUSH    066h
    PUSH    ESI
    CALL    sub_509490
    MOV     EBX,[DWORD EBP+8]
    ADD     ESP,0Ch
    LEA     EAX,[DWORD EBP-014h]
    MOV     EDX,2
    LEA     ECX,[DWORD EBX+07F8h]
L50978A:
    MOV     EDI,[DWORD EAX]
    ADD     EAX,4
    MOV     [DWORD ECX],EDI
    ADD     ECX,4
    DEC     EDX
    JNZ     L50978A
    LEA     EDX,[DWORD EBP-014h]
    PUSH    EDX
    PUSH    0333h
    PUSH    ESI
    CALL    sub_509490
    MOV     EAX,[DWORD EBP-010h]
    MOV     ECX,[DWORD EBP-0Ch]
    MOV     EDX,[DWORD EBP-8]
    MOV     [DWORD EBX+0820h],EAX
    MOV     EAX,[DWORD EBP-4]
    MOV     [DWORD EBX+0824h],ECX
    MOV     [DWORD EBX+0828h],EDX
    ADD     ESP,0Ch
    MOV     [DWORD EBX+082Ch],EAX
    MOV     EDI,4
    ADD     EBX,0830h
L5097D8:
    LEA     ECX,[DWORD EDI+01000h]
    MOV     EAX,066666667h
    IMUL    ECX
    SAR     EDX,1
    MOV     ECX,EDX
    PUSH    EBX
    SHR     ECX,01Fh
    ADD     EDX,ECX
    PUSH    EDX
    PUSH    ESI
    CALL    sub_509490
    ADD     EDI,5
    ADD     ESP,0Ch
    ADD     EBX,014h
    CMP     EDI,0FEh
    JL      L5097D8
    LEA     EDX,[DWORD EBP-014h]
    PUSH    EDX
    PUSH    0366h
    PUSH    ESI
    CALL    sub_509490
    MOV     EBX,[DWORD EBP+8]
    ADD     ESP,0Ch
    LEA     EAX,[DWORD EBP-014h]
    MOV     EDX,2
    LEA     ECX,[DWORD EBX+0C18h]
L50982A:
    MOV     EDI,[DWORD EAX]
    ADD     EAX,4
    MOV     [DWORD ECX],EDI
    ADD     ECX,4
    DEC     EDX
    JNZ     L50982A
    LEA     EAX,[DWORD EBP-014h]
    PUSH    EAX
    PUSH    0666h
    PUSH    ESI
    CALL    sub_509490
    MOV     ECX,[DWORD EBP-0Ch]
    MOV     EDX,[DWORD EBP-8]
    MOV     EAX,[DWORD EBP-4]
    MOV     [DWORD EBX+0C44h],ECX
    MOV     [DWORD EBX+0C48h],EDX
    ADD     ESP,0Ch
    MOV     [DWORD EBX+0C4Ch],EAX
    MOV     EDI,3
    ADD     EBX,0C50h
L50986F:
    LEA     ECX,[DWORD EDI+02000h]
    MOV     EAX,066666667h
    IMUL    ECX
    SAR     EDX,1
    MOV     ECX,EDX
    PUSH    EBX
    SHR     ECX,01Fh
    ADD     EDX,ECX
    PUSH    EDX
    PUSH    ESI
    CALL    sub_509490
    ADD     EDI,5
    ADD     ESP,0Ch
    ADD     EBX,014h
    CMP     EDI,0Dh
    JL      L50986F
    LEA     EDX,[DWORD EBP-014h]
    PUSH    EDX
    PUSH    0669h
    PUSH    ESI
    CALL    sub_509490
    MOV     EAX,[DWORD EBP+8]
    ADD     ESP,0Ch
    MOV     EDX,3
    LEA     ECX,[DWORD EAX+0C78h]
    LEA     EAX,[DWORD EBP-014h]
L5098BE:
    MOV     ESI,[DWORD EAX]
    ADD     EAX,4
    MOV     [DWORD ECX],ESI
    ADD     ECX,4
    DEC     EDX
    JNZ     L5098BE
    POP     EDI
    POP     ESI
    XOR     EAX,EAX
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET
endp
;############################### sub_509C50 ####################################
proc sub_509C50
    PUSH    EBP
    MOV     EBP,ESP
    MOV     EAX,[DWORD EBP+0Ch]
    PUSH    ESI
    MOV     ESI,[DWORD EBP+8]
    PUSH    EAX
    PUSH    ESI
    CALL    sub_509730
    ADD     ESP,8
    MOV     [DWORD ESI+0C94h],0
    MOV     [DWORD ESI+01C98h],0400h
    POP     ESI
    POP     EBP
    RET
endp
;############################### sub_420BA0 ####################################
proc funcF
    PUSH    EBP
    MOV     EBP,ESP
    MOV     EAX,01CB8h
    CALL    stack_alloc
    LEA     EAX,[DWORD EBP-014h]
    LEA     ECX,[DWORD EBP-01CB8h]
    PUSH    EAX
    PUSH    ECX
    MOV     [BYTE EBP-014h],040h
    MOV     [BYTE EBP-013h],0F2h
    MOV     [BYTE EBP-012h],0FFh
    MOV     [BYTE EBP-011h],0B2h
    MOV     [BYTE EBP-010h],069h
    MOV     [BYTE EBP-0Fh],0F6h
    MOV     [BYTE EBP-0Eh],0F1h
    MOV     [BYTE EBP-0Dh],0AFh
    MOV     [BYTE EBP-0Ch],063h
    MOV     [BYTE EBP-0Bh],0F4h
    MOV     [BYTE EBP-0Ah],05Dh
    MOV     [BYTE EBP-9],041h
    MOV     [BYTE EBP-8],0Eh
    MOV     [BYTE EBP-7],01Ch
    MOV     [BYTE EBP-6],011h
    MOV     [BYTE EBP-5],09Bh
    MOV     [BYTE EBP-4],0F0h
    MOV     [BYTE EBP-3],045h
    MOV     [BYTE EBP-2],0BEh
    MOV     [BYTE EBP-1],0EAh
    CALL    sub_509C50
    XOR     EDX,EDX
    MOV     EAX,[DWORD EBP+8]
    MOV     [DWORD EBP-01Bh],EDX
    LEA     ECX,[DWORD EBP-01Ch]
    MOV     [WORD EBP-017h],DX
    PUSH    2
    MOV     [BYTE EBP-015h],DL
    LEA     EDX,[DWORD EBP-01CB8h]
    PUSH    ECX
    PUSH    EDX
    MOV     [DWORD EBP-01Ch],EAX
    CALL    sub_509C80
    MOV     EAX,[DWORD EBP-01Ch]
    ADD     ESP,014h
    MOV     ESP,EBP
    POP     EBP
    RET
endp
end
