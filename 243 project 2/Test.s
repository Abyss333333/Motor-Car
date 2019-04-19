.section .vectors, "ax"

B _start
B SERVICE_UND
B SERVICE_SVC
B SERVICE_ABT_DATA
B SERVICE_ABT_INST
.word 0
B IRQ_HANDLER
B SERVICE_FIQ




.text
.global main
main: 

	//ldr r0, =0x00000430
    //mov r1, #0b1
    //strb r1, [r0], #1
    //mov r1, #0b10
    //strb r1, [r0], #1
    //mov r1, #0b11
    //strb r1, [r0], #1
    //mov r1, #0b100
    //strb r1, [r0]
    
    
	mov r0, #0b10010
    msr cpsr_c, r0
    ldr SP, =0xffffffff -3
    
    mov r0, #0b10011
    msr cpsr_c, r0
    ldr SP, =0xffffffff -3
	
    bl GIC_CONTROLLER

  
    BL CONFIG_KEYS
	BL CONFIG_PS2
	BL CONFIG_PRIV_TIMER

	
    


    MOV R0, #0b01010011 // IRQ unmasked, MODE = SVC
    MSR CPSR_c, R0


LOOP:                                          
                  
                  B        LOOP                



				  .global TIMER
TIMER:			  .word 0x2500000
				  .global Direction
Direction:  	   .word 0x1
				   .global VALUE
VALUE: 			.word 0x0


     /* Undefined instructions */
SERVICE_UND:                                
                    B   SERVICE_UND         
/* Software interrupts */
SERVICE_SVC:                                
                    B   SERVICE_SVC         
/* Aborted data reads */
SERVICE_ABT_DATA:                           
                    B   SERVICE_ABT_DATA    
/* Aborted instruction fetch */
SERVICE_ABT_INST:                           
                    B   SERVICE_ABT_INST    
SERVICE_FIQ:                                
                    B   SERVICE_FIQ   
                    
.global IRQ_HANDLER                   
IRQ_HANDLER: 
			push {r0-r7, LR}
            ldr r4, =0xfffec100
            ldr r5, [r4, #0x0c] // ICCIAR aknowledge register
            
  
Priv_Timer_Check:
			cmp r5, #29
            bne PS2_Check
            bl PRIV_TIMER_ISR
            B EXIT_IRQ
  
PS2_Check:
			cmp r5, #79
            bne Key_Check
            bl PS2_ISR
            B EXIT_IRQ

Key_Check:          	
			cmp r5, #73
UNEXPECTED: BNE UNEXPECTED

			BL KEY_ISR
            
EXIT_IRQ:   
			
			str r5, [r4, #0x10]  // read into ICCEOIR end of INST reg
			pop {r0-r7, pc}
           // subs pc, lr, #4
	
                
                             
 
GIC_CONTROLLER:

push {LR}
mov r0, #73 // key interrupt number
mov r1, #1
bl Config_Key_Interrupt

mov r0, #29
bl Config_Priv_Timer_Interrupt

mov r0, #79 // PS2 interrupt number
bl Config_ps2_Interrupt

ldr r0, =0xFFFEC100 // address of cpu register interface
ldr r1, =0xffff // enable all interput of all priority levels
str r1, [r0, #0x04]

mov r1, #1
str r1, [r0] // enable interrupts in gic

pop {pc}


Config_ps2_Interrupt:

push {R4-R5, LR}

mov r4, #8 // (79/32) *4
ldr r2, =0xFFFED100
add r4,r2,r4

mov r2, #15 // 79 mod 32
mov r5, #1
lsl r2, r5, r2 // move 1 to index 9

ldr r3, [r4]
orr r3,r2,r3
str r3, [r4] // store in IDCISERN aka the intterupt set enable register

mov r4, #76 // (79/4) *4
ldr r2, =0xfffed800 // address for IDCIPTRN aka so the cpu can forward the specific interrupt
add r4, r2, r4

mov r2, #3 // 79 mod 4
add r4, r2, r4
strb r5, [r4]
pop { r4-r5, pc}


Config_Key_Interrupt:

push {R4-R5, LR}

mov r4, #8 // (73/32) *4
ldr r2, =0xFFFED100
add r4,r2,r4

mov r2, #9 // 73 mod 32
mov r5, #1
lsl r2, r5, r2 // move 1 to index 9

ldr r3, [r4]
orr r3,r2,r3
str r3, [r4] // store in IDCISERN aka the intterupt set enable register

mov r4, #72 // (73/4) *4
ldr r2, =0xfffed800 // address for IDCIPTRN aka so the cpu can forward the specific interrupt
add r4, r2, r4

mov r2, #1 // 73 mod 4
add r4, r2, r4
strb r5, [r4]
pop { r4-r5, pc}

Config_Priv_Timer_Interrupt:

push {R0-R5, LR}

mov r4, #0 // (29/32) *4
ldr r2, =0xFFFED100
add r4,r2,r4

mov r2, #29 // 29 mod 32
mov r5, #1
lsl r2, r5, r2 // move 1 to index 9

ldr r3, [r4]
orr r3,r2,r3
str r3, [r4] // store in IDCISERN aka the intterupt set enable register

mov r4, #28 // (29/4) *4
ldr r2, =0xfffed800 // address for IDCIPTRN aka so the cpu can forward the specific interrupt
add r4, r2, r4

mov r2, #1 // 29 mod 4
add r4, r2, r4
strb r5, [r4]

pop { r0-r5, pc}





CONFIG_PS2:

push {r0-r7, LR}
ldr r3, =0xff200104
mov r1, #0b1
str r1, [r3]

ldr r2, =0xff200060
	ldr r3, =0xf
	str r3, [r2]

pop {r0-r7, PC}
    

/* Global variables */
CONFIG_KEYS:
	

	PUSH {R0-R1, LR}
	LDR R0, =0xFF200050 // pushbutton KEY base address
	MOV R1, #0xF // set interrupt mask bits
	STR R1, [R0, #0x8] // interrupt mask register (base + 8)
    POP {R0-R1, PC}
    
    
    




KEY_ISR:
	
    push {r0-r7, LR}
    
    ldr r0, =0xFF200050 // key address
    ldr r1, [r0, #0xc] // read edge capture register
    mov r2, #0xF
    str r2, [r0, #0xc] // clear the edge

Z_ISR:
	cmp r1, #0b1000
	BEQ TIMER_CHANGE
    ldr r4, =address

	mov r7, #1
	str r7, Direction
	
check:
	
    
    ldrb r5, [r4], #1
    //str r4, [r3]
    cmp r5, #0
    beq end_isr
    cmp r5, #1
    beq forward
    
    cmp r5, #2
    beq backward
    
    cmp r5, #3
    beq left
    
    cmp r5, #4
    beq right
    
    b end_isr

forward:
	ldr r6, Direction
	mov r7, #1
	str r7, Direction
	cmp r6, #3
	beq right_turn
	cmp r6, #4
	beq left_turn
forward_:
	ldr r2, =0xff200074 // set direction
	ldr r3, =0xffffffff
	str r3, [r2]

	ldr r2, =0xff200070 // gpio address
	mov r3, #0b0101
	str r3, [r2]
    //BL CONFIG_PRIV_TIMER
 ldr r2, =90000000
 
 sub1:
 	cmp r2, #0
    beq forward_end
    sub r2, #1
    b sub1
forward_end:
	bl GPIO_OFF
    b check

backward:
	ldr r6, Direction
	mov r7, #2
	str r7, Direction
	cmp r6, #3
	beq left_turn
	cmp r6, #4
	beq right_turn
	 
backward_:
    ldr r2, =0xff200074 // set direction
	ldr r3, =0xffffffff
	str r3, [r2]

	ldr r2, =0xff200070
	mov r3, #0b1010
	str r3, [r2]
    //BL CONFIG_PRIV_TIMER
    ldr r2, =90000000
 
 sub2:
 	cmp r2, #0
    beq backward_end
    sub r2, #1
    b sub2
backward_end:
	bl GPIO_OFF
    b check
    

left:
	ldr r6, Direction
	mov r7, #3
	str r7, Direction
	cmp r6, #1
	beq left_turn
	cmp r6, #2
	beq left_turn
	cmp r6,#3
	beq forward_
	cmp r6,#4
	beq backward_

right:
	ldr r6, Direction
	mov r7, #4
	str r7, Direction
	cmp r6, #1
	beq right_turn
	cmp r6, #2
	beq right_turn
	cmp r6,#4
	beq forward_
	cmp r6,#3
	beq backward_






left_turn:
	 ldr r2, =0xff200074 // set direction
	ldr r3, =0xffffffff
	str r3, [r2]

	ldr r2, =0xff200070
	mov r3, #0b1000 
	str r3, [r2]
    //BL CONFIG_PRIV_TIMER
    ldr r2, =220000000
	
	
 
 sub3:
 	cmp r2, #0
    beq left_end
    sub r2, #1
    b sub3
left_end:
	bl GPIO_OFF
	ldr r6, Direction
	cmp r6, #2
	beq backward_
	b forward_
   

right_turn:
	 ldr r2, =0xff200074 // set direction
	ldr r3, =0xffffffff
	str r3, [r2]

	ldr r2, =0xff200070
	mov r3,#0b0110
	str r3, [r2]
    //BL CONFIG_PRIV_TIMER
    ldr r2, =50000000
 
 sub4:
 	cmp r2, #0
    beq right_end
    sub r2, #1
    b sub4
right_end:
	bl GPIO_OFF
	ldr r6, Direction
	cmp r6, #2
	beq backward_
	b forward_
    



TIMER_CHANGE:

    ldr r1, =0xfffec60c
    mov r0, #1
    str r0, [r1]
	
	ldr r3, TIMER
	lsr r3, r3, #3
    str r3, TIMER
    bl CONFIG_PRIV_TIMER
    b end_isr
   
end_isr:
	
	
	pop {r0-r7,pc}



GPIO_OFF:

	push {r0-r8, lr}
    ldr r1, =0xfffec60c
    mov r0, #1
    str r0, [r1]
    
 	ldr r2, =0xff200070
	ldr r3, =0x00000000
	str r3, [r2]


    
    
end_gpio:
    pop {r0-r8, pc}

PS2_ISR:

push {r0-r7, LR}

ldr r1, current_address
cmp r1, #0
bne not_first
ldr r1, =address
not_first:
// ledr 


ldr r2, =0xff200000 // ledr address
ldr r3, =0xff200100




ldrb r4, [r3]
cmp r4, #0x1a
beq Z_ISR
cmp r4, #0x1d
beq forward_w
cmp r4, #0x1b
beq backward_s
cmp r4, #0x1c
beq left_a
cmp r4,#0x23
beq right_d
b end
forward_w:
mov r5, #1
strb r5, [r1],#1
str r5, [r2]
str r5, VALUE
ldr r2, =current_address
str r1, [r2]
bl path
b end

backward_s:
mov r5, #2
strb r5, [r1],#1
str r5, [r2]
str r5, VALUE
ldr r2, =current_address
str r1, [r2]
bl path
b end

left_a:
mov r5, #3
strb r5, [r1], #1
str r5, [r2]
str r5, VALUE
ldr r2, =current_address
str r1, [r2]
bl path
b end

right_d:
mov r5, #4
strb r5, [r1], #1
str r5, [r2]
str r5, VALUE
ldr r2, =current_address
str r1, [r2]
bl path
b end


end: 
	
pop {r0-r7, PC}


CONFIG_PRIV_TIMER:
	
   push {r0-r7, LR}
   ldr r0, =0xfffec600
   ldr r1, TIMER
   str r1, [r0]
   mov r1, #0b111
   str r1, [r0,#8]
   pop {r0-r7,pc}

.global PRIV_TIMER_ISR

PRIV_TIMER_ISR:

	push {r0-r8, lr}
    ldr r1, =0xfffec60c
    mov r0, #1
    str r0, [r1]
    
    ldr r2, =0xff200064 // set direction
	ldr r3, =0xffffffff
	str r3, [r2]

	ldr r2, =0xff200060 // gpio address
	ldrb r3, [r2]
	EOR R3,R3,#0XF
	STRB R3, [R2]
	
    end_isr_priv:
   pop {r0-r8, pc}


address: .space 200
current_address: .word 0x0


