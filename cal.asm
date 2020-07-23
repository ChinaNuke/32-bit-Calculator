COM_8255    EQU	0273H
PA_8255     EQU	0270H
PB_8255     EQU	0271H
PC_8255     EQU	0272H

DATA_MAX_H  EQU 05F5H ; 最大数值，即99999999
;DATA_MAX_L  EQU 0E0FFH
SEG_ERR_H   EQU 0FFFFH ; 错误码高位
SHARP_H	    EQU 05FEH ; #
OPC_ADD_H   EQU 05F7H ; 加号高位
OPC_SUB_H   EQU 05F8H ; 减号
OPC_MUL_H   EQU 05F9H ; 乘号
OPC_BKL_H   EQU 05FAH ; 左括号
OPC_BKR_H   EQU 05FBH ; 右括号

STACK1       SEGMENT STACK
            DW 512 DUP(?)
STACK1       ENDS

DATA        SEGMENT
LAST_IS_NUM DB 0 ; 上一个读入的是否为数字，用于左右括号的判断
DWORD_BUF   DW 2 DUP(0) ; 32位数字缓冲区
MUL_BUF	    DW 2 DUP(0)
MUL_BUF2    DW 2 DUP(0)
INPUT_P     DW ? ; 输入表达式缓冲区指针
INPUT_EXPR  DW 60 DUP(SHARP_H) ; 输入表达式缓冲区
SIG_STACK   DW 60 DUP(0)
DATA_STACK  DW 60 DUP(0)

TEMP DW 400 DUP(0)
; LED显示内容缓冲区，对应SEG_TAB下标LED段码表，0亮1灭
BUFFER      DB 8 DUP(?)
; LED段码表，0亮1灭
SEG_TAB		DB 0C0H,0F9H,0A4H,0B0H, 99H, 92H, 82H,0F8H, 080H, 90H ; 数字0~9
            DB 86H, 0FFH ; E和全灭
; 键盘映射表
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
            CLD ; DF置0，地址递增
            

; 初始化8255芯片
            MOV DX, COM_8255
            MOV AL, 89H ; PA，PB输出，PC输入
            OUT DX, AL
            
; 屏幕清0
	    
            CALL CLEAR


; 等待键盘读入，读入数据放在AL
	    ;LEA BX, INPUT_EXPR
WAIT_IN:    CALL KEYI
	    CALL KEY_PROCESS
	    JMP WAIT_IN
	    




; ----------------------------------------
; 内容处理子程序
; 对读入的键码进行区分，判断其是数字、运算符、等号还是清零
; 并将内容存入INPUT_EXPR
; ----------------------------------------
KEY_PROCESS PROC
            PUSH BX
            PUSH DX
            PUSH AX
            PUSH CX
            LEA BX, KEY_TAB
            XLAT
            CMP AL, 0AH ; 判断是否是数字
            JA K_NOT_NUM
            MOV AH, 0
            PUSH AX ; 暂存AX
            MOV AX, DWORD_BUF
            MOV DX, DWORD_BUF + 2
            MOV CX, 0
            MOV BX, 10
            CALL MULDW
            POP BX
            ADD AX, BX
            ADC DX, 0
            CMP DX, 05F5H
            JA K_OF ; 显示溢出
            MOV DWORD_BUF, AX 
            MOV DWORD_BUF + 2, DX
            JMP K_NOF
K_OF:	    MOV DX, SEG_ERR_H
	    MOV AX, 0
K_NOF:      MOV BYTE PTR LAST_IS_NUM, 1
            CALL DISP_NUM
            JMP K_END
K_NOT_NUM:  CMP AL, 0FCH ; 判断是否为清零
            JNZ K_N1
            CALL CLEAR ; 调用清零子程序
            JMP K_END
K_N1:       CMP AL, 0FDH ; 判断是否为等号
            JNZ K_N2
            CMP LAST_IS_NUM, 1
            JNZ K_N1_1
            MOV DI, INPUT_P
	    MOV BL, AL ; 暂存AL
	    MOV AX, DWORD_BUF
            STOSW
            MOV AX, DWORD_BUF + 2
            STOSW
            MOV DWORD_BUF, 0
            MOV DWORD_BUF + 2, 0
            MOV AL, BL ; 恢复AL
K_N1_1:	    CALL CAL
            MOV BYTE PTR LAST_IS_NUM, 0
            JMP K_END
K_N2:       CMP AL, 0FAH ; 判断是否为括号
            JNZ K_N3
            MOV DI, INPUT_P
            CMP LAST_IS_NUM, 1 ; 前一个读入的是否为数字
            JNZ K_BKL ; 不为数字则当前括号为左括号，否则为右括号
            MOV BL, AL ; 暂存AL
	    MOV AX, DWORD_BUF
            STOSW
            MOV AX, DWORD_BUF + 2
            STOSW
            MOV WORD PTR DWORD_BUF, 0
            MOV WORD PTR DWORD_BUF + 2, 0
            MOV AL, BL ; 恢复AL
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
K_N3:       ; 是加/减/乘
	    MOV DI, INPUT_P
	    MOV BL, AL ; 暂存AL
	    CMP LAST_IS_NUM, 1
	    JNZ K_N3_1
	    MOV AX, DWORD_BUF
            STOSW
            MOV AX, DWORD_BUF + 2
            STOSW
            MOV DWORD_BUF, 0
            MOV DWORD_BUF + 2, 0
            ;MOV AL, BL ; 恢复AL
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
; LED显示程序
; 主要是根据参数生成BUFFER中的内容
; 然后调用DIR子程序
; 参数：DX:AX（32位数字或错误码）
; ----------------------------------------
DISP_NUM    PROC
            PUSH CX
            PUSH BX
            PUSH AX
            PUSH DX
            LEA DI, BUFFER
            CMP DX, SEG_ERR_H ; 判断参数是否为错误码
            JNZ NOT_ERR
; 参数为错误码，最高位为E，其余位熄灭  
            MOV AL, 0BH
            MOV CX, 7
            REP STOSB
            MOV AL, 0AH
            STOSB
            JMP DEND
; 参数为数字，将BUFFER中存入数字对应的段码
NOT_ERR:    CMP AX, 0 ; display 0
            JNZ NZ
            CMP DX, 0
            JNZ NZ
            MOV AL, 00H
            STOSB
            JMP FILL 
            
NZ:         CALL DIVDW
            MOV BX, AX ; 将AX暂存
            MOV AL, CL ; 把求得的余数存入BUFFER
            STOSB
            MOV AX, BX
            CMP AX, 0
            JNZ NZ
            CMP DX, 0
            JNZ NZ

FILL:	    LEA BX, BUFFER + 7
            MOV AL, 0BH ; 单个LED全灭
AGAIN:      CMP BX, DI ; 把剩余高位LED置为全灭
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
; LED显示驱动子程序
; 根据BUFFER中的值，查找SEG_TAB得到段码
; 送到LED端口
; ----------------------------------------
DIR         PROC    NEAR	
            PUSH AX	
            PUSH BX	
            PUSH DX	
            LEA	SI, buffer ;置显示缓冲器初值
            MOV	AH, 0FEH	
            LEA	BX, SEG_TAB	
LD0:        MOV	DX, PA_8255	
            LODSB		
            XLAT ;取显示数据
            OUT	DX, AL	;段数据->8255 PA口
            INC	DX	;扫描模式->8255 PB口
            MOV	AL, AH	
            OUT	DX, AL	
            CALL DELAY1	;延迟1ms
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
; 键盘读入子程序
; 返回：AL（读入的键号）
; ----------------------------------------
KEYI        PROC	NEAR	
            PUSH BX	
            PUSH DX	
LK:         CALL AllKey		;调用判有无闭合键子程序
            JNZ	LK1	
            CALL DIR	
            CALL DIR	;调用显示子程序,延迟6ms
            JMP	LK	
LK1:        CALL DIR	
            CALL DIR	
            CALL AllKey		;调用判有无闭合键子程序
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
            XOR	AL,AL	;0行有键闭合
            JMP	LKP	
LONE:       TEST AL,02H	
            JNZ	NEXT	
            MOV	AL,08H	;1行有键闭合
LKP:        ADD	BH,AL	
LK3:        CALL DIR	;判断释放否
            CALL AllKey	
            JNZ	LK3	
            MOV	AL,BH	;键号->AL
            POP	DX	
            POP	BX	
            RET		
NEXT:       INC BH	;列计数器加1
	        TEST BL,80H	
            JZ	KND	;判是否已扫到最后一列
            ROL	BL,01H	
            JMP	LK4	
KND:        JMP	LK	
KEYI        ENDP		

; ----------------------------------------
; 判断有无闭合键子程序
; ----------------------------------------
AllKey      PROC	NEAR	
            MOV	DX,PB_8255	
            XOR	AL,AL	
            OUT	DX,AL	;全"0"->扫描口
            INC	DX	
            IN AL,DX	;读键状态
            NOT	AL	
            AND	AL,03H	;取低二位
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
; 无溢出除法(除数固定为10)
; 参数: DX:AX（32位被除数）
; 返回: DX:AX（商）
;       CX（余数）
; ----------------------------------------
DIVDW       PROC
            PUSH BX
            MOV CX, 10 ; 设定除数为10
            PUSH AX ; 保存低位
            MOV AX, DX ; 把高位放在低位
            MOV DX, 0 ; 高位清零
            DIV CX
            MOV BX, AX ; 把商暂存
            POP AX ; 取出原先的低位
            DIV CX
            MOV CX, DX ; 把最终余数放在CX
            MOV DX, BX
            POP BX
            RET
DIVDW       ENDP

; ----------------------------------------
; 32位乘法
; 参数: DX:AX（32位乘数）,CX:BX(32位被乘数)
; 返回: DX:AX（32位结果，可能为溢出标志）
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
; 优先级比较子程序
; 参数：AH,AL两个运算符的最低8位
; 返回：AL:0:>,1:<,2:=
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
; 清零子程序
; 将缓冲区清空
; 将屏幕清零
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
; 延迟子程序
; 延迟1ms
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
