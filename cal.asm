COM_8255    EQU	0273H
PA_8255     EQU	0270H
PB_8255     EQU	0271H
PC_8255     EQU	0272H

DATA_MAX_H  EQU 05F5H ; �����ֵ����99999999
;DATA_MAX_L  EQU 0E0FFH
SEG_ERR_H   EQU 0FFFFH ; �������λ
SHARP_H	    EQU 05FEH ; #
OPC_ADD_H   EQU 05F7H ; �ӺŸ�λ
OPC_SUB_H   EQU 05F8H ; ����
OPC_MUL_H   EQU 05F9H ; �˺�
OPC_BKL_H   EQU 05FAH ; ������
OPC_BKR_H   EQU 05FBH ; ������

STACK1       SEGMENT STACK
            DW 512 DUP(?)
STACK1       ENDS

DATA        SEGMENT
LAST_IS_NUM DB 0 ; ��һ��������Ƿ�Ϊ���֣������������ŵ��ж�
DWORD_BUF   DW 2 DUP(0) ; 32λ���ֻ�����
MUL_BUF	    DW 2 DUP(0)
MUL_BUF2    DW 2 DUP(0)
INPUT_P     DW ? ; ������ʽ������ָ��
INPUT_EXPR  DW 60 DUP(SHARP_H) ; ������ʽ������
SIG_STACK   DW 60 DUP(0)
DATA_STACK  DW 60 DUP(0)

TEMP DW 400 DUP(0)
; LED��ʾ���ݻ���������ӦSEG_TAB�±�LED�����0��1��
BUFFER      DB 8 DUP(?)
; LED�����0��1��
SEG_TAB		DB 0C0H,0F9H,0A4H,0B0H, 99H, 92H, 82H,0F8H, 080H, 90H ; ����0~9
            DB 86H, 0FFH ; E��ȫ��
; ����ӳ���
KEY_TAB     DB 07H, 08H, 09H, 0F7H      ;   7   8   9   +
            DB 04H, 05H, 06H, 0F8H      ;   4   5   6   -
            DB 01H, 02H, 03H, 0F9H      ;   1   2   3   *
            DB 0FCH, 00H, 0FDH, 0FAH    ;   C   0   =   (
DATA        ENDS

CODE        SEGMENT
            ASSUME CS:CODE, DS:DATA, SS:STACK1
START:      MOV AX, DATA
            MOV DS, AX
            MOV ES, AX
            MOV AX, STACK1
            MOV SS, AX
            CLD ; DF��0����ַ����
            

; ��ʼ��8255оƬ
            MOV DX, COM_8255
            MOV AL, 89H ; PA��PB�����PC����
            OUT DX, AL
            
; ��Ļ��0
	    
            CALL CLEAR


; �ȴ����̶��룬�������ݷ���AL
	    ;LEA BX, INPUT_EXPR
WAIT_IN:    CALL KEYI
	    CALL KEY_PROCESS
	    JMP WAIT_IN
	    




; ----------------------------------------
; ���ݴ����ӳ���
; �Զ���ļ���������֣��ж��������֡���������ȺŻ�������
; �������ݴ���INPUT_EXPR
; ----------------------------------------
KEY_PROCESS PROC
            PUSH BX
            PUSH DX
            PUSH AX
            PUSH CX
            LEA BX, KEY_TAB
            XLAT
            CMP AL, 0AH ; �ж��Ƿ�������
            JA K_NOT_NUM
            MOV AH, 0
            PUSH AX ; �ݴ�AX
            MOV AX, DWORD_BUF
            MOV DX, DWORD_BUF + 2
            MOV CX, 0
            MOV BX, 10
            CALL MULDW
            POP BX
            ADD AX, BX
            ADC DX, 0
            CMP DX, 05F5H
            JA K_OF ; ��ʾ���
            MOV DWORD_BUF, AX 
            MOV DWORD_BUF + 2, DX
            JMP K_NOF
K_OF:	    MOV DX, SEG_ERR_H
	    MOV AX, 0
K_NOF:      MOV BYTE PTR LAST_IS_NUM, 1
            CALL DISP_NUM
            JMP K_END
K_NOT_NUM:  CMP AL, 0FCH ; �ж��Ƿ�Ϊ����
            JNZ K_N1
            CALL CLEAR ; ���������ӳ���
            JMP K_END
K_N1:       CMP AL, 0FDH ; �ж��Ƿ�Ϊ�Ⱥ�
            JNZ K_N2
            CMP LAST_IS_NUM, 1
            JNZ K_N1_1
            MOV DI, INPUT_P
	    MOV BL, AL ; �ݴ�AL
	    MOV AX, DWORD_BUF
            STOSW
            MOV AX, DWORD_BUF + 2
            STOSW
            MOV DWORD_BUF, 0
            MOV DWORD_BUF + 2, 0
            MOV AL, BL ; �ָ�AL
K_N1_1:	    CALL CAL
            MOV BYTE PTR LAST_IS_NUM, 0
            JMP K_END
K_N2:       CMP AL, 0FAH ; �ж��Ƿ�Ϊ����
            JNZ K_N3
            MOV DI, INPUT_P
            CMP LAST_IS_NUM, 1 ; ǰһ��������Ƿ�Ϊ����
            JNZ K_BKL ; ��Ϊ������ǰ����Ϊ�����ţ�����Ϊ������
            MOV BL, AL ; �ݴ�AL
	    MOV AX, DWORD_BUF
            STOSW
            MOV AX, DWORD_BUF + 2
            STOSW
            MOV WORD PTR DWORD_BUF, 0
            MOV WORD PTR DWORD_BUF + 2, 0
            MOV AL, BL ; �ָ�AL
            MOV AX, 0
            STOSW
            MOV AX, OPC_BKR_H
            STOSW
            MOV INPUT_P, DI
            MOV BYTE PTR LAST_IS_NUM, 0
            JMP K_END
K_BKL:      MOV AX, 0
            STOSW
            MOV AX, OPC_BKL_H
            STOSW
            MOV INPUT_P, DI
            MOV BYTE PTR LAST_IS_NUM, 0
            JMP K_END
K_N3:       ; �Ǽ�/��/��
	    MOV DI, INPUT_P
	    MOV BL, AL ; �ݴ�AL
	    CMP LAST_IS_NUM, 1
	    JNZ K_N3_1
	    MOV AX, DWORD_BUF
            STOSW
            MOV AX, DWORD_BUF + 2
            STOSW
            MOV DWORD_BUF, 0
            MOV DWORD_BUF + 2, 0
            ;MOV AL, BL ; �ָ�AL
	    ;MOV BL, AL
K_N3_1:     MOV AX, 0
            STOSW
            MOV AL, BL
            MOV AH, 05H
            STOSW
            MOV INPUT_P, DI
            MOV BYTE PTR LAST_IS_NUM, 0
K_END:      POP CX
	    POP AX
	    POP DX
            POP BX
            RET
KEY_PROCESS ENDP


; ----------------------------------------
; LED��ʾ����
; ��Ҫ�Ǹ��ݲ�������BUFFER�е�����
; Ȼ�����DIR�ӳ���
; ������DX:AX��32λ���ֻ�����룩
; ----------------------------------------
DISP_NUM    PROC
            PUSH CX
            PUSH BX
            PUSH AX
            PUSH DX
            LEA DI, BUFFER
            CMP DX, SEG_ERR_H ; �жϲ����Ƿ�Ϊ������
            JNZ NOT_ERR
; ����Ϊ�����룬���λΪE������λϨ��  
            MOV AL, 0BH
            MOV CX, 7
            REP STOSB
            MOV AL, 0AH
            STOSB
            JMP DEND
; ����Ϊ���֣���BUFFER�д������ֶ�Ӧ�Ķ���
NOT_ERR:    CMP AX, 0 ; display 0
            JNZ NZ
            CMP DX, 0
            JNZ NZ
            MOV AL, 00H
            STOSB
            JMP FILL 
            
NZ:         CALL DIVDW
            MOV BX, AX ; ��AX�ݴ�
            MOV AL, CL ; ����õ���������BUFFER
            STOSB
            MOV AX, BX
            CMP AX, 0
            JNZ NZ
            CMP DX, 0
            JNZ NZ

FILL:	    LEA BX, BUFFER + 7
            MOV AL, 0BH ; ����LEDȫ��
AGAIN:      CMP BX, DI ; ��ʣ���λLED��Ϊȫ��
            JB  DEND
            STOSB
            JMP AGAIN
DEND:       CALL DIR
	    POP DX
	    POP AX
	    POP BX
            POP CX
            RET
DISP_NUM    ENDP

; ----------------------------------------
; LED��ʾ�����ӳ���
; ����BUFFER�е�ֵ������SEG_TAB�õ�����
; �͵�LED�˿�
; ----------------------------------------
DIR         PROC    NEAR	
            PUSH AX	
            PUSH BX	
            PUSH DX	
            LEA	SI, buffer ;����ʾ��������ֵ
            MOV	AH, 0FEH	
            LEA	BX, SEG_TAB	
LD0:        MOV	DX, PA_8255	
            LODSB		
            XLAT ;ȡ��ʾ����
            OUT	DX, AL	;������->8255 PA��
            INC	DX	;ɨ��ģʽ->8255 PB��
            MOV	AL, AH	
            OUT	DX, AL	
            CALL DELAY1	;�ӳ�1ms
            MOV	DX, PB_8255	
            MOV	AL, 0FFH	
            OUT	DX, AL	
            TEST AH,80H	
            JZ LD1	
            ROL	AH, 01H	
            JMP	LD0	
LD1:	    POP	DX	
            POP	BX	
            POP	AX	
            RET		
DIR         ENDP

; ----------------------------------------
; ���̶����ӳ���
; ���أ�AL������ļ��ţ�
; ----------------------------------------
KEYI        PROC	NEAR	
            PUSH BX	
            PUSH DX	
LK:         CALL AllKey		;���������ޱպϼ��ӳ���
            JNZ	LK1	
            CALL DIR	
            CALL DIR	;������ʾ�ӳ���,�ӳ�6ms
            JMP	LK	
LK1:        CALL DIR	
            CALL DIR	
            CALL AllKey		;���������ޱպϼ��ӳ���
            JNZ	LK2	
            CALL DIR	
            JMP	LK	
LK2:        MOV	BL,0FEH		;R2
            MOV	BH,0	;R4
LK4:        MOV	DX,PB_8255	
            MOV	AL,BL	
            OUT	DX,AL	
            INC	DX	
            IN	AL,DX	
            TEST AL,01H	
            JNZ	LONE	
            XOR	AL,AL	;0���м��պ�
            JMP	LKP	
LONE:       TEST AL,02H	
            JNZ	NEXT	
            MOV	AL,08H	;1���м��պ�
LKP:        ADD	BH,AL	
LK3:        CALL DIR	;�ж��ͷŷ�
            CALL AllKey	
            JNZ	LK3	
            MOV	AL,BH	;����->AL
            POP	DX	
            POP	BX	
            RET		
NEXT:       INC BH	;�м�������1
	        TEST BL,80H	
            JZ	KND	;���Ƿ���ɨ�����һ��
            ROL	BL,01H	
            JMP	LK4	
KND:        JMP	LK	
KEYI        ENDP		

; ----------------------------------------
; �ж����ޱպϼ��ӳ���
; ----------------------------------------
AllKey      PROC	NEAR	
            MOV	DX,PB_8255	
            XOR	AL,AL	
            OUT	DX,AL	;ȫ"0"->ɨ���
            INC	DX	
            IN AL,DX	;����״̬
            NOT	AL	
            AND	AL,03H	;ȡ�Ͷ�λ
            RET		
AllKey      ENDP		

CAL	    PROC
	    PUSH AX
	    PUSH BX
	    PUSH CX
	    PUSH DX
	    
	    LEA SI, SIG_STACK
	    LEA DI, DATA_STACK
	    LEA BX, INPUT_EXPR
	    MOV WORD PTR [SI], 0
	    ADD SI, 2
	    MOV WORD PTR [SI], SHARP_H
	    ADD SI, 2
	    
C_LOOP:	    CMP WORD PTR [BX + 2], DATA_MAX_H
	    JA IS_SIGNAL
	    MOV AX, [BX]
	    MOV DX, [BX + 2]
	    ADD BX, 4
	    MOV [DI], AX
	    ADD DI, 2
	    MOV [DI], DX
	    ADD DI, 2
	    JMP C_END
	    
IS_SIGNAL:  MOV AH, [BX + 2]
	    MOV AL, [SI - 2]
	    CALL PRIORITY
	    CMP AL, 0
	    JNZ C_N1
	    MOV AX, [BX]
	    MOV DX, [BX + 2]
	    ADD BX, 4
	    MOV [SI], AX
	    ADD SI, 2
	    MOV [SI], DX
	    ADD SI, 2
	    JMP C_END
C_N1:	    CMP AL, 2
	    JNZ C_N2
	    SUB SI, 4
	    ADD BX, 4
	    JMP C_END
C_N2:	    MOV AL, [SI - 2]
	    CMP AL, 0F7H ; +
	    JNZ C_N3
	    SUB SI, 4
	    PUSH AX
	    PUSH BX
	    ;MOV CX, [DI - 2]
	    ;MOV BX, [DI - 4]
	    ;SUB DI, 4
	    ;MOV DX, [DI - 2]
	    ;MOV AX, [DI - 4]
	    ;SUB DI, 4
	    CALL GET_NUM
	    CALL ADDDW
	    CMP DX, SEG_ERR_H 
	    JZ C_OF_MID
	   ;; JZ C_OF
	    MOV [DI], AX
	    MOV [DI + 2], DX
	    ADD DI, 4
	    POP BX
	    POP AX
	    JMP C_END
	    
C_LOOP_MID: JMP C_LOOP
	    
C_N3:	    MOV AL, [SI - 2]
	    CMP AL, 0F8H ; -
	    JNZ C_N4
	    SUB SI, 4
	    PUSH AX
	    PUSH BX
	    ;MOV CX, [DI - 2]
	    ;MOV BX, [DI - 4]
	    ;SUB DI, 4
	    ;MOV DX, [DI - 2]
	    ;MOV AX, [DI - 4]
	    ;SUB DI, 4
	    CALL GET_NUM
	    CALL SUBDW
	    MOV [DI], AX
	    MOV [DI + 2], DX
	    ADD DI, 4
	    POP BX
	    POP AX
	    JMP C_END
	    
C_OF_MID:   JMP C_OF
	    
C_N4:	    MOV AL, [SI - 2]
	    SUB SI, 4
	    ;CMP AL, 0F9H ; *
	    ;JNZ C_N5
	    PUSH AX
	    PUSH BX
	    ;MOV CX, [DI - 2]
	    ;MOV BX, [DI - 4]
	    ;SUB DI, 4
	    ;MOV DX, [DI - 2]
	    ;MOV AX, [DI - 4]
	    ;SUB DI, 4
	    CALL GET_NUM
	    CALL MULDW
	    
	   ; MOV DX, 06FH
	   ; MOV AX, 0000H
	    
	    ;CMP DX, SEG_ERR_H 
	    ;JZ C_OF
	    MOV [DI], AX
	    MOV [DI + 2], DX
	    ADD DI, 4
	    POP BX
	    POP AX
    
C_END:	    LEA CX, SIG_STACK
	    CMP SI, CX
	    JA C_LOOP_MID
	   ;;JA C_LOOP
	    ;ADD DI, 4
	    MOV AX, [DI - 4]
	    MOV DX, [DI - 2]
	    
	    SUB DI, 4
	    CMP DX, 05F5H
	    JB C_DISP
	    ;CMP DX, 05F5H
	    JA C_OF
	    CMP AX, 0E0FFH
	    JBE C_DISP	    
C_OF:	    MOV DX, SEG_ERR_H
	    MOV AX, 0
C_DISP:	    CALL DISP_NUM

	    POP DX
	    POP CX
	    POP BX
	    POP AX
	    RET
CAL	    ENDP

; ----------------------------------------
; ���������(�����̶�Ϊ10)
; ����: DX:AX��32λ��������
; ����: DX:AX���̣�
;       CX��������
; ----------------------------------------
DIVDW       PROC
            PUSH BX
            MOV CX, 10 ; �趨����Ϊ10
            PUSH AX ; �����λ
            MOV AX, DX ; �Ѹ�λ���ڵ�λ
            MOV DX, 0 ; ��λ����
            DIV CX
            MOV BX, AX ; �����ݴ�
            POP AX ; ȡ��ԭ�ȵĵ�λ
            DIV CX
            MOV CX, DX ; ��������������CX
            MOV DX, BX
            POP BX
            RET
DIVDW       ENDP

; ----------------------------------------
; 32λ�˷�
; ����: DX:AX��32λ������,CX:BX(32λ������)
; ����: DX:AX��32λ���������Ϊ�����־��
; ----------------------------------------
MULDW       PROC
	    MOV MUL_BUF2, AX
	    MOV MUL_BUF2 + 2, DX
	    MUL BX
	    MOV MUL_BUF, AX
	    MOV MUL_BUF+2, DX
	    MOV AX, MUL_BUF2 + 2
	    MUL BX
	    CMP DX, 0
	    JNZ OVERFLOW
	    ADD MUL_BUF + 2, AX
	    JC OVERFLOW
	    MOV AX, MUL_BUF2
	    MUL CX
	    CMP DX, 0
	    JNZ OVERFLOW
	    ADD MUL_BUF+2, AX
	    JC OVERFLOW
	    MOV DX, MUL_BUF2 + 2
	    MUL CX
	    CMP AX, 0
	    JNZ OVERFLOW
	    CMP DX, 0
	    JNZ OVERFLOW
	    
	    MOV AX, MUL_BUF
	    MOV DX, MUL_BUF+2
	    JMP M_END
OVERFLOW:   MOV DX, 06FCH
	    MOV AX, 0
M_END:	    RET
MULDW       ENDP

ADDDW	    PROC
	    ADD AX, BX
	    ADC DX, CX
	    JNC A_END
	    MOV DX, SEG_ERR_H
	    MOV AX, 0
A_END:	    RET
ADDDW	    ENDP

SUBDW	    PROC
	    SUB AX, BX
	    SBB DX, CX
	    RET
SUBDW	    ENDP

; ----------------------------------------
; ���ȼ��Ƚ��ӳ���
; ������AH,AL��������������8λ
; ���أ�AL:0:>,1:<,2:=
; ----------------------------------------
PRIORITY    PROC
	    CMP AH, 0FAH ; (
	    JNZ P_N2
	    MOV AL, 0
	    JMP P_END
P_N2:	    CMP AH, 0F7H ; +
	    JNZ P_N3
	    CMP AL, 0FEH ; #
	    JNZ P_N2_1
	    MOV AL, 0
	    JMP P_END
P_N2_1:	    CMP AL, 0FAH ; (
	    JNZ P_N2_2
	    MOV AL, 0
	    JMP P_END
P_N2_2:	    MOV AL, 1
	    JMP P_END
P_N3:	    CMP AH, 0F8H ; -
	    JNZ P_N4
	    CMP AL, 0FEH ; #
	    JNZ P_N3_1
	    MOV AL, 0
	    JMP P_END
P_N3_1:	    CMP AL, 0FAH ; (
	    JNZ P_N3_2
	    MOV AL, 0
	    JMP P_END
P_N3_2:	    MOV AL, 1
	    JMP P_END
P_N4:	    CMP AH, 0F9H ; *
	    JNZ P_N5
	    CMP AL, 0F9H ; *
	    JNZ P_N4_1
	    MOV AL, 1
	    JMP P_END
P_N4_1:	    MOV AL, 0
	    JMP P_END
P_N5:	    CMP AH, 0FBH ; )
	    JNZ P_N6
	    CMP AL, 0FAH ; (
	    JNZ P_N5_1
	    MOV AL, 2
	    JMP P_END
P_N5_1:	    MOV AL, 1
	    JMP P_END
P_N6:	    ;CMP AH, 0FEH ; #
	    CMP AL, 0FEH
	    JNZ P_N6_1
	    MOV AL, 2
	    JMP P_END
P_N6_1:	    MOV AL, 1	    
P_END:	    RET
PRIORITY    ENDP

GET_NUM	    PROC
	    ;SUB SI, 4
	   ; PUSH AX
	   ; PUSH BX
	    MOV CX, [DI - 2]
	    MOV BX, [DI - 4]
	    SUB DI, 4
	    MOV DX, [DI - 2]
	    MOV AX, [DI - 4]
	    SUB DI, 4
	    RET
GET_NUM	    ENDP

SAVE_NUM    PROC
	    RET
SAVE_NUM    ENDP

; ----------------------------------------
; �����ӳ���
; �����������
; ����Ļ����
; ----------------------------------------
CLEAR       PROC
            PUSH AX
            PUSH CX
            PUSH DX
            PUSH BX
            MOV DWORD_BUF, 0
            MOV DWORD_BUF + 2, 0
            LEA DI, INPUT_EXPR
            MOV AX, SHARP_H
            MOV CX, 60
            REP STOSW
            LEA AX, INPUT_EXPR
            MOV INPUT_P, AX
            MOV BYTE PTR LAST_IS_NUM, 0
            MOV DX, 0
            MOV AX, 0
            CALL DISP_NUM
            POP BX
            POP DX
            POP CX
            POP AX
            RET
CLEAR       ENDP
; ----------------------------------------
; �ӳ��ӳ���
; �ӳ�1ms
; ----------------------------------------
DELAY1      PROC NEAR
            PUSH CX	
            MOV	CX, 500	
	        LOOP $	
            POP	CX	
            RET		
DELAY1      ENDP		

CODE        ENDS
            END START
