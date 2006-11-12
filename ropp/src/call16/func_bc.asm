section .data use32 CLASS=data
    d06A453Ch dd 1
    d0723748h dd 0
    d072374Ch dd 0
    d0723750h dd 0
    d0723754h dd 0
    d0723758h dd 0
    d072375Ch dd 0
    d0723760h dd 0
    d0723764h dd 0
    d072376Ch dd 0
    d0724910h dd 0
    d0724914h dd 0
    d0724918h dd 0
; Please check a dup block
section .bss use32 CLASS=bss
    d0723728h RESB 20h
    d074491Ch RESB 100h
section .code use32 CLASS=code
;############################### sub_4209E0 ####################################
global _funcB
_funcB:
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,018h
    LEA     EAX,[EBP-8]
    MOV     byte [EBP-8],012h
    PUSH    EAX
    MOV     byte [EBP-7],043h
    MOV     byte [EBP-6],09Fh
    MOV     byte [EBP-5],01Fh
    MOV     byte [EBP-4],0ABh
    MOV     byte [EBP-3],0FFh
    MOV     byte [EBP-2],03Ah
    MOV     byte [EBP-1],06Fh
    CALL    sub_50A140
    XOR     ECX,ECX
    MOV     EDX,dword [EBP+8]
    MOV     dword [EBP-0Fh],ECX
    LEA     EAX,[EBP-018h]
    MOV     word [EBP-0Bh],CX
    PUSH    EAX
    MOV     byte [EBP-9],CL
    LEA     ECX,[EBP-010h]
    PUSH    ECX
    MOV     dword [EBP-010h],EDX
    CALL    sub_509E50
    MOV     EAX,dword [EBP-018h]
    ADD     ESP,0Ch
    MOV     ESP,EBP
    POP     EBP
    RET

;############################### sub_420A40 ####################################
global _funcC
_funcC:
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,018h
    LEA     EAX,[EBP-8]
    MOV     byte [EBP-8],022h
    PUSH    EAX
    MOV     byte [EBP-7],043h
    MOV     byte [EBP-6],09Fh
    MOV     byte [EBP-5],01Fh
    MOV     byte [EBP-4],0ACh
    MOV     byte [EBP-3],0FFh
    MOV     byte [EBP-2],03Ah
    MOV     byte [EBP-1],06Fh
    CALL    sub_50A140
    XOR     ECX,ECX
    MOV     EDX,dword [EBP+8]
    MOV     dword [EBP-0Fh],ECX
    LEA     EAX,[EBP-018h]
    MOV     word [EBP-0Bh],CX
    PUSH    EAX
    MOV     byte [EBP-9],CL
    LEA     ECX,[EBP-010h]
    PUSH    ECX
    MOV     dword [EBP-010h],EDX
    CALL    .sub_509DA0
    MOV     EAX,dword [EBP-018h]
    ADD     ESP,0Ch
    MOV     ESP,EBP
    POP     EBP
    RET

;############################### sub_509E20 ####################################
.sub_509E20:
    PUSH    EBP
    MOV     EBP,ESP
    MOV     EAX,dword [EBP+0Ch]
    MOV     ECX,dword [EBP+8]
    MOV     DL,byte [EBP+0Bh]
    MOV     byte [EAX],CL
    MOV     CL,byte [EBP+0Ah]
    INC     EAX
    MOV     byte [EAX],CH
    INC     EAX
    MOV     byte [EAX],CL
    MOV     byte [EAX+1],DL
    POP     EBP
    RET

;############################### sub_509DA0 ####################################
.sub_509DA0:
    PUSH    EBP
    MOV     EBP,ESP
    PUSH    EBX
    PUSH    ESI
    MOV     ESI,dword [EBP+8]
    PUSH    EDI
    PUSH    ESI
    CALL    sub_509FE0
    ADD     ESI,4
    MOV     EDI,EAX
    PUSH    ESI
    CALL    sub_509FE0
    MOV     EDX,dword [d0724910h]
    MOV     ESI,dword [d0724914h]
    XOR     EDI,EDX
    XOR     ESI,EAX
    ADD     ESP,8
    XOR     ESI,EDI
    MOV     EBX, d0723728h + 1Ch ;0723744h
.L509DD4:
    MOV     EAX,dword [EBX]
    PUSH    EAX
    PUSH    ESI
    CALL    sub_509EF0
    SUB     EBX,4
    ADD     ESP,8
    XOR     EAX,EDI
    MOV     EDI,ESI
    CMP     EBX, d0723728h
    MOV     ESI,EAX
    JAE     .L509DD4 ;JGE     .L509DD4
    MOV     EDX,dword [d0724918h]
    MOV     ECX,dword [d072376Ch]
    MOV     ESI,dword [EBP+0Ch]
    XOR     EDX,EAX
    XOR     ECX,EAX
    PUSH    ESI
    PUSH    EDX
    XOR     EDI,ECX
    CALL    .sub_509E20
    ADD     ESI,4
    PUSH    ESI
    PUSH    EDI
    CALL    .sub_509E20
    ADD     ESP,010h
    POP     EDI
    POP     ESI
    POP     EBX
    POP     EBP
    RET

;############################### sub_509EF0 ####################################
sub_509EF0:
    PUSH    EBP
    MOV     EBP,ESP
    PUSH    ECX
    MOV     CL,byte [EBP+0Ah]
    MOV     EAX,dword [EBP+0Ch]
    PUSH    EBX
    MOV     BL,byte [EBP+0Bh]
    XOR     CL,AH
    PUSH    ESI
    XOR     CL,BL
    MOV     EBX,dword [EBP+8]
    MOV     DL,BH
    MOV     byte [EBP-4],CL
    MOV     ESI,dword [EBP-4]
    XOR     DL,AL
    PUSH    EDI
    XOR     DL,BL
    PUSH    ESI
    PUSH    EDX
    CALL    sub_50A0E0
    MOV     byte [EBP+0Ch],AL
    MOV     EDI,dword [EBP+0Ch]
    PUSH    EDI
    PUSH    ESI
    CALL    sub_50A080
    MOV     CL,byte [EBP+0Ch]
    PUSH    EDI
    PUSH    EBX
    MOV     byte [EBP-4],AL
    MOV     byte [EBP+0Dh],CL
    MOV     byte [EBP+0Eh],AL
    CALL    sub_50A080
    MOV     EDX,dword [EBP-4]
    MOV     byte [EBP+0Ch],AL
    MOV     EAX,dword [EBP+0Bh]
    PUSH    EDX
    PUSH    EAX
    CALL    sub_50A0E0
    ADD     ESP,020h
    MOV     byte [EBP+0Fh],AL
    MOV     EAX,dword [EBP+0Ch]
    POP     EDI
    POP     ESI
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET

;############################### sub_509FE0 ####################################
sub_509FE0:
    PUSH    EBP
    MOV     EBP,ESP
    MOV     EAX,dword [EBP+8]
    MOV     CL,byte [EAX]
    MOV     DL,byte [EAX+1]
    INC     EAX
    MOV     byte [EBP+8],CL
    INC     EAX
    MOV     byte [EBP+9],DL
    MOV     CL,byte [EAX]
    MOV     DL,byte [EAX+1]
    MOV     byte [EBP+0Ah],CL
    MOV     byte [EBP+0Bh],DL
    MOV     EAX,dword [EBP+8]
    POP     EBP
    RET

;############################### sub_509E50 ####################################
sub_509E50:
    PUSH    EBP
    MOV     EBP,ESP
    PUSH    ECX
    PUSH    EBX
    PUSH    ESI
    MOV     ESI,dword [EBP+8]
    PUSH    EDI
    PUSH    ESI
    CALL    sub_509FE0
    ADD     ESI,4
    MOV     EBX,EAX
    PUSH    ESI
    CALL    sub_509FE0
    MOV     EDX,dword [d0724918h]
    MOV     ESI,dword [d072376Ch]
    XOR     EBX,EDX
    XOR     ESI,EAX
    ADD     ESP,8
    XOR     ESI,EBX
    MOV     EDI, d0723728h
.L509E85:
    MOV     EAX,dword [EDI]
    PUSH    EAX
    PUSH    ESI
    CALL    sub_509EF0
    ADD     EDI,4
    ADD     ESP,8
    XOR     EAX,EBX
    MOV     EBX,ESI
    CMP     EDI, d0723748h
    MOV     ESI,EAX
    JB      .L509E85    ;JL      .L509E85
    MOV     ESI,dword [d0724914h]
    MOV     ECX,dword [d0724910h]
    XOR     EBX,EAX
    XOR     ECX,EAX
    XOR     EBX,ESI
    MOV     ESI,dword [EBP+0Ch]
    MOV     dword [EBP+8],ECX
    MOV     dword [EBP-4],EBX
    MOV     DL,byte [EBP+0Bh]
    LEA     EAX,[ESI+1]
    MOV     byte [ESI],CL
    MOV     CL,byte [EBP+0Ah]
    MOV     byte [EAX],CH
    INC     EAX
    POP     EDI
    MOV     byte [EAX],CL
    MOV     byte [EAX+1],DL
    LEA     EAX,[ESI+4]
    MOV     CL,byte [EBP-2]
    MOV     DL,byte [EBP-1]
    POP     ESI
    MOV     byte [EAX],BL
    INC     EAX
    MOV     byte [EAX],BH
    INC     EAX
    POP     EBX
    MOV     byte [EAX],CL
    MOV     byte [EAX+1],DL
    MOV     ESP,EBP
    POP     EBP
    RET

;############################### sub_50A080 ####################################
sub_50A080:
    PUSH    EBP
    MOV     EBP,ESP
    MOV     EAX,dword [d06A453Ch]
    TEST    EAX,EAX
    JZ      .L50A0BE
    XOR     ECX,ECX
    XOR     EAX,EAX
    PUSH    EBX
    XOR     EDX,EDX
.L50A093:
    MOV     BL,DL
    ADD     BL,AL
    ADD     EAX,4
    CMP     EAX,0FFh
    MOV     byte [ECX+d074491Ch],BL
    JLE     .L50A0AA
    XOR     EAX,EAX
    INC     EDX
.L50A0AA:
    INC     ECX
    CMP     ECX,0100h
    JL      .L50A093
    MOV     dword [d06A453Ch],0
    POP     EBX
.L50A0BE:
    MOV     AL,byte [EBP+8]
    MOV     DL,byte [EBP+0Ch]
    ADD     AL,DL
    AND     EAX,0FFh
    MOV     AL,byte [EAX+d074491Ch]
    POP     EBP
    RET

;############################### sub_50A0E0 ####################################
sub_50A0E0:
    PUSH    EBP
    MOV     EBP,ESP
    MOV     EAX,dword [d06A453Ch]
    PUSH    EBX
    TEST    EAX,EAX
    JZ      .L50A11D
    XOR     ECX,ECX
    XOR     EAX,EAX
    XOR     EDX,EDX
.L50A0F3:
    MOV     BL,DL
    ADD     BL,AL
    ADD     EAX,4
    CMP     EAX,0FFh
    MOV     byte [ECX+d074491Ch],BL
    JLE     .L50A10A
    XOR     EAX,EAX
    INC     EDX
.L50A10A:
    INC     ECX
    CMP     ECX,0100h
    JL      .L50A0F3
    MOV     dword [d06A453Ch],0
.L50A11D:
    MOV     AL,byte [EBP+8]
    MOV     BL,byte [EBP+0Ch]
    ADD     AL,BL
    POP     EBX
    INC     AL
    AND     EAX,0FFh
    MOV     AL,byte [EAX+d074491Ch]
    POP     EBP
    RET

;############################### sub_509F60 ####################################
sub_509F60:
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,8
    MOV     AL,byte [EBP+0Ah]
    MOV     CL,byte [EBP+0Bh]
    XOR     AL,CL
    MOV     CL,byte [EBP+0Ch]
    MOV     byte [EBP-8],AL
    XOR     CL,AL
    MOV     EAX,dword [EBP+8]
    PUSH    EBX
    MOV     DL,AH
    PUSH    ECX
    XOR     DL,AL
    PUSH    EDX
    CALL    sub_50A0E0
    MOV     ECX,dword [EBP-8]
    MOV     BL,AL
    MOV     AL,byte [EBP+0Dh]
    XOR     AL,BL
    PUSH    EAX
    PUSH    ECX
    CALL    sub_50A080
    MOV     DL,byte [EBP+0Eh]
    MOV     byte [EBP-8],AL
    MOV     byte [EBP-2],AL
    MOV     EAX,dword [EBP+8]
    XOR     DL,BL
    MOV     byte [EBP-3],BL
    PUSH    EDX
    PUSH    EAX
    CALL    sub_50A080
    MOV     CL,byte [EBP+0Fh]
    MOV     DL,byte [EBP-8]
    XOR     CL,DL
    MOV     EDX,dword [EBP+0Bh]
    PUSH    ECX
    PUSH    EDX
    MOV     byte [EBP-4],AL
    CALL    sub_50A0E0
    ADD     ESP,020h
    MOV     byte [EBP-1],AL
    MOV     EAX,dword [EBP-4]
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET

;############################### sub_50A140 ####################################
sub_50A140:
    PUSH    EBP
    MOV     EBP,ESP
    SUB     ESP,8
    MOV     EAX,dword [EBP+8]
    PUSH    EBX
    PUSH    ESI
    PUSH    EDI
    MOV     CL,byte [EAX]
    MOV     DL,byte [EAX+1]
    INC     EAX
    MOV     byte [EBP+8],CL
    INC     EAX
    MOV     byte [EBP+9],DL
    MOV     ESI, d0723728h
    MOV     dword [EBP-8],8
    MOV     CL,byte [EAX]
    MOV     DL,byte [EAX+1]
    INC     EAX
    MOV     byte [EBP+0Ah],CL
    INC     EAX
    MOV     byte [EBP+0Bh],DL
    MOV     EDI,dword [EBP+8]
    MOV     CL,byte [EAX]
    MOV     DL,byte [EAX+1]
    INC     EAX
    MOV     byte [EBP-4],CL
    INC     EAX
    MOV     byte [EBP-3],DL
    MOV     CL,byte [EAX]
    MOV     DL,byte [EAX+1]
    MOV     byte [EBP-2],CL
    MOV     byte [EBP-1],DL
    MOV     EBX,dword [EBP-4]
    XOR     ECX,ECX
.L50A192:
    XOR     ECX,EBX
    PUSH    ECX
    PUSH    EDI
    CALL    sub_509F60
    MOV     ECX,EDI
    MOV     EDI,EBX
    MOV     dword [EBP-4],EAX
    MOV     DL,byte [EBP-2]
    MOV     EBX,EAX
    MOV     byte [EBP+8],AL
    MOV     byte [EBP+9],AH
    MOV     EAX,dword [EBP+8]
    MOV     dword [ESI],EAX
    MOV     AL,byte [EBP-1]
    ADD     ESI,4
    MOV     byte [EBP+8],DL
    MOV     byte [EBP+9],AL
    MOV     EDX,dword [EBP+8]
    MOV     EAX,dword [EBP-8]
    MOV     dword [ESI],EDX
    ADD     ESP,8
    ADD     ESI,4
    DEC     EAX
    MOV     dword [EBP-8],EAX
    JNZ     .L50A192
    MOV     EAX,dword [d0723748h]
    MOV     ECX,dword [d072374Ch]
    MOV     byte [EBP+8],AL
    MOV     byte [EBP+9],AH
    MOV     byte [EBP+0Ah],CL
    MOV     byte [EBP+0Bh],CH
    MOV     EAX,dword [EBP+8]
    MOV     ECX,dword [d0723754h]
    MOV     dword [d0724918h],EAX
    MOV     EAX,dword [d0723750h]
    MOV     byte [EBP+8],AL
    MOV     byte [EBP+9],AH
    MOV     EAX,dword [d0723758h]
    MOV     byte [EBP+0Ah],CL
    MOV     byte [EBP+0Bh],CH
    MOV     ECX,dword [EBP+8]
    MOV     dword [d072376Ch],ECX
    MOV     ECX,dword [d072375Ch]
    MOV     byte [EBP+8],AL
    MOV     byte [EBP+9],AH
    MOV     EAX,dword [d0723760h]
    MOV     byte [EBP+0Ah],CL
    MOV     byte [EBP+0Bh],CH
    MOV     ECX,dword [d0723764h]
    MOV     EDX,dword [EBP+8]
    MOV     byte [EBP+8],AL
    MOV     byte [EBP+9],AH
    MOV     byte [EBP+0Ah],CL
    MOV     byte [EBP+0Bh],CH
    MOV     EAX,dword [EBP+8]
    POP     EDI
    POP     ESI
    MOV     dword [d0724910h],EDX
    MOV     dword [d0724914h],EAX
    POP     EBX
    MOV     ESP,EBP
    POP     EBP
    RET

end

