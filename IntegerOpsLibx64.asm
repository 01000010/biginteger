; Large Integer Operations 

;.386
;.model flat,C
;.stack 4096

EXTERN GetProcessHeap: PROC
EXTERN HeapAlloc: PROC
EXTERN HeapFree: PROC

.data


;********************************************************************************
;  Large Integer Format:
;
;	  qword  : Reserved for reference count
;     qword  : Number of qwords reserved for numeric data (not included number header with sign)
;	  qword  : Actual number of qwords used for number (can be less than reserved value)
;	  qword  : sign of number (0 = positive, 1 = negetive)
;	  qwords : sequence of qwords storing positive numberic data 
;
;	  Note: Qwords past the end of the number should be zeroed
;
;********************************************************************************

;********************************************************************************
;  BCD (Bindary coded DIGITS!!) Integer Format:
;
;     qword  : Reserved for reference count
;     qword  : Number of qwords reserved for numeric data (not included number header with sign)
;	  qword  : Number of bytes used for number (can be less than reserved value)
;	  qword  : Sign of number (0 = positive, 1 = negetive)
;     qword  : Base of number. Legal values: 10 and 16.  (Note: we can support 8 later if needed)
;	  bytes  : sequence of bytes storing positive BCD numberic data 
;
;********************************************************************************

pHeap  dq  0

.code

;********************************************************************************
;
;	  Purpose:  Allocate memory
;
;	  qword  : Number of bytes to Allocate
;     
;     return : Pointer to allocated memory
;
;********************************************************************************

LIOAlloc proc public

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Save requested memory size
	mov  [rbp+24], rdx

	mov rax, pHeap						; Get heap pointer 
	test rax, rax
	jnz alloc_mem

	sub  rsp,32							; Make home frame
	call GetProcessHeap
	add  rsp,32							; Destory home frame

	mov  pHeap, rax

alloc_mem:

	mov  rcx, rax						; Param1: heap 
	mov  rdx, [rbp+24]					; Param2: allocaton flags
	mov  r8,  [rbp+16]					; Param3; requested memory (passed in as param1)

	sub  rsp,32							; Make home frame
	call HeapAlloc
	add  rsp,32							; Destory home frame

	; Procedure Epilog

	pop  rbp							; Restore the old base pointer
	ret


LIOAlloc endp

;********************************************************************************
;
;	  Purpose:  Make an integer 
;
;	  qword  :  Size reseved for data in qwords
;     
;     return :  Large Integer (initalized to zero)
;
;********************************************************************************

LIOMakeInt proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Save param1 in home frame

	push rbx
	sub  sp, 8

	; End Prolog

	cmp rcx, 1							; max(rcx,1) : if rcx is zero cmp will set the carry flag.
	adc rcx, 0							;     Then we add the carry back into rcx

	mov  rbx, rcx						; save our requested memory size

	add  rcx, 4							; add space for (memory size, number size and sign bit)
	shl  rcx, 3							; convert from quad-words to bytes
	mov  rdx, 08h						; Allocated zeroed memory
	
	sub  rsp,32							; Make home frame
	call LIOAlloc
	add  rsp,32							; Destory home frame

	test rax,rax
	jz   no_mem

	mov  qword ptr [rax],    0			; Clear reference word
	mov  qword ptr [rax+8],  rbx		; Save the length of memory allocated (in quad-words)
	mov  qword ptr [rax+16], 0			; Set then length of the number to zero
	mov  qword ptr [rax+24], 0			; Set sign to positive

no_mem:

	; Procedure Epilog

	add  sp, 8
	pop  rbx

	pop  rbp							; Restore the old base pointer
	ret

LIOMakeInt endp

;********************************************************************************
;
;	  Purpose:  Make an BCD integer 
;
;	  ptr    :  Size reseved for data in qwords
;     
;     return :  BCD Integer (initalized to zero)
;
;********************************************************************************

LIOMakeBCD proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Save param1 in home frame

	push rbx
	sub  sp, 8

	; End Prolog

	cmp rcx, 1							; max(rcx,1) : if rcx is zero cmp will set the carry flag.
	adc rcx, 7							;     Then we add the carry flag +7 back into rcx and
	and rcx, 0FFFFFFFFFFFFFFF8h			;	  round down the the nearest multiple of 8

	mov  rbx, rcx						; save our requested memory size

	add  rcx, 40						; add space for (reference memory size, number size,  sign bit and base)
	mov  rdx, 08h						; Allocated zeroed memory
	
	sub  rsp,32							; Make home frame
	call LIOAlloc
	add  rsp,32							; Destory home frame

	test rax,rax
	jz   no_mem

	mov  qword ptr [rax],    0			; Clear reference qword
	mov  qword ptr [rax+8],  rbx	    ; Save the length of memory allocated (in bytes)
	mov  qword ptr [rax+16], 0			; Set then length of the number to zero
	mov  qword ptr [rax+24], 0			; Set sign to positive
	mov  qword ptr [rax+32], 0			; No base yet
	   

no_mem:

	; Procedure Epilog
	
	add  sp, 8
	pop  rbx

	pop  rbp							; Restore the old base pointer
	ret

LIOMakeBCD endp


;********************************************************************************
;
;	  Purpose:  Sets an exsisting integer to zero
;
;	  ptr    :  Large integer to set to zero
;     
;     return :  input large integer
;
;********************************************************************************

LIOSetIntZero proc public

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Save param1 in home frame

	xor  r8,r8
	xor  rax,rax

zero_loop:

	cmp  r8, [rcx+8]
	jge  zero_done
	mov  [rcx+r8*8+32], rax

	jmp zero_loop

zero_done:

	mov [rcx+16], rax
	mov rax, rcx

	; Procedure Epilog

	pop  rbp							; Restore the old base pointer
	ret

LIOSetIntZero endp

;********************************************************************************
;
;	  Purpose:  Destroy a large integer
;
;	  ptr    :  Large integer to destroy
;     
;     return :  Non-zero for success, zero for failure
;
;********************************************************************************

LIODestroyInt proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Save param1 in home frame

    mov rax, pHeap						; Get heap pointer 
	test rax, rax						; Redimentary error check for heap
	jz no_heap							;

	mov r8, rcx							; Param3; requested memory (passed in as param1)
	xor rdx, rdx						; Param2: allocaton flags
	mov rcx, rax						; Param1: heap 

    sub  rsp,32							; Make home frame
	call HeapFree						; Destroy memory of number
	add  rsp,32							; Destroy home frame

no_heap:

	; Procedure Epilog

	pop  rbp							; Restore the old base pointer
	ret

LIODestroyInt endp

;********************************************************************************
;
;	  Purpose:  Copies a large integer
;
;	  ptr    :  Large integer to copy
;     
;     return :  Copy of integer
;
;********************************************************************************

LIOCopyInt proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.
	
	mov  [rbp+16], rcx					; Save param1 in home frame

	push rsi							; Save monvolitile registers
	push rdi

	; End Prolog

	mov  rsi, rcx

	mov  rcx, [rsi+8]					; Calculate required memory
	add  rcx, 4							; 
	shl  rcx, 3							;

	xor  rdx, rdx						; Don't need zeroed memory  
	
	sub  rsp,32							
	call LIOAlloc						; Allocate memory for copy
	add  rsp,32							

	cld
	mov  rdi, rax						; Set destination for move
	mov  rcx, [rsi+8]					; Get data size in qwords
	add  rcx, 4							; Add 4 for header size

	rep movsq							; Copy data

	; Procedure Epilog

	pop  rdi
	pop  rsi

	pop  rbp							; Restore the old base pointer
	ret

LIOCopyInt endp

;********************************************************************************
;
;	  Purpose:  Copies a BCD integer
;
;	  ptr    :  BCD integer to copy
;     
;     return :  Copy of BCD integer
;
;********************************************************************************

LIOCopyBCD proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.
	
	mov  [rbp+16], rcx					; Save param1 in home frame

	push rsi							; Save monvolitile registers
	push rdi

	; End Prolog

	mov  rsi, rcx

	mov  rcx, [rsi+8]					; Calculate required memory
	add  rcx, 32						; 

	xor  rdx, rdx						; Don't need zeroed memory  
	
	sub  rsp,32							
	call LIOAlloc						; Allocate memory for copy
	add  rsp,32							

	mov  rdi, rax						; Set destination for move
	mov  rcx, [rsi+8]					; Get data size in bytes
	shr  rcx, 3							; Convert data size to qwords (note: we can do this becuse data size is always a multiple of 8)
	add  rcx, 5							; Add 5 for header size

	rep movsq							; Copy data

	; Procedure Epilog

	pop  rdi
	pop  rsi

	pop  rbp							; Restore the old base pointer
	ret

LIOCopyBCD endp

;********************************************************************************
;
;	  Purpose:  Destroy a BCD integer
;
;	  ptr    :  BCD integer to destroy
;     
;     return :  Non-zero for success, zero for failure
;
;********************************************************************************

LIODestroyBCD proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Save param1 in home frame

    mov rax, pHeap						; Get heap pointer 
	test rax, rax						; Redimentary error check for heap
	jz no_heap							;

	mov r8, rcx							; Param3; requested memory (passed in as param1)
	xor rdx, rdx						; Param2: allocaton flags
	mov rcx, rax						; Param1: heap 

    sub  rsp,32							; Make home frame
	call HeapFree						; Destroy memory of number
	add  rsp,32							; Destroy home frame

no_heap:

	; Procedure Epilog

	pop  rbp							; Restore the old base pointer
	ret

LIODestroyBCD endp


;********************************************************************************
;  Compare two large numbers
;
;     Parameters:
;
;     ptr  : First large integer to compare
;     ptr  : Second large interger to compare
;
;     return:  Return 0 if Param1 and Param2 are equal
;              Return index of the highest order qword which is different 
;                  between Param1 and Param2 (Note: lowest order qword starts at index 1 )
;			   Return the negetive index of the highest order qword which is different 
;                  between Param1 and Param2 (Note: lowest order qword starts at index 1 )
;********************************************************************************

LIOCompareRaw proc Public

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Save address of first number
	mov  [rbp+24], rdx					; Save address of second number

	; End Prolog
	
	mov  rax, [rcx+16]					; get size of first number
	sub  rax, [rdx+16]					; compare with size of second number

	jg   set_gt_result					; first is greater since the length is greater
	jl   set_lt_result					; Second greater since the length is greater

	mov  rax, [rcx+16]					; Get the size of the numbers
    
comp_loop:								; loop until we find a difference in the numbers. 
										;    On exit rax hold the qword count of the highest order qwords with a differnce
	mov  r10, [rcx+rax*8+24]			; Get qword of first number
	sub  r10, [rdx+rax*8+24]			; Compare to qword of second number

	jg   comp_end						; first number is greater so exit
	jl   negate_result					; second number is greater so negate and exit

	dec rax
	jnz comp_loop						; we found a number chunk that is not equal so set neq result and exit

	jmp comp_end						; rax must be zero here (meaning equality) so just exit

set_gt_result:

	mov  rax, [rcx+16]					; return the lenght of the first number
	jmp  comp_end
	
set_lt_result:

	mov  rax, [rdx+16]					; return the length of the second number

negate_result:

	neg  rax							; negate the result to flag that the second number is zero

comp_end:

	; Procedure Epilog

	pop  rbp							; Restore the old base pointer
	ret

LIOCompareRaw endp

;********************************************************************************
;
;	  Purpose:  Add two large integers ingoring the sign
;
;	  ptr    :  Augend large integer
;     ptr    :  Addend large integer
;     
;     return :  New large integer holding the sum
;
;********************************************************************************

LIOAddRaw proc Public

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Save address of first number
	mov  [rbp+24], rdx					; Save address of second number

	push rdi							; Save monvolitile registers
	push r13							;
	push r14							;
	push r15							;

	; End Prolog
	
	mov  rax, [rcx+16]					; get size of first number
	cmp  rax, [rdx+16]					; compare with size of second number

	jge   arw_first_bigger_or_eq

	mov  r14, rcx						; Second parameter bigger 
	mov  r15, rdx						; 

	jmp  arw_make_int

arw_first_bigger_or_eq:

	mov  r14, rdx  						; First parameter bigger or equal to
	mov  r15, rcx						; 

arw_make_int:

	mov  rcx, [r15+16]					; Get length of longest number
	inc  rcx							; Increment lenth in case of carry 

	sub  rsp,32							
	call LIOMakeInt						; Make destination integer
	add  rsp,32							

	mov  rdi,rax						; Set starting destination of new number

	; Do the math!!!

	clc									; clear the cary flag
	lahf								; Save in AH
	xor  r13,r13						; Zero our counter

arw_loop_1:

	cmp  r13, [r14+16]					; Check to see if we reach the end of the sort number
	jge  arw_loop_2

	mov  r9, [r15+r13*8+32]				; Get qword from larger number
	sahf								; Restore carry flag
	adc  r9, [r14+r13*8+32]				; Add to qworld from shorter number
	lahf								; Save carry flag
	mov  [rdi+r13*8+32], r9				; Save in destination 
	inc  r13							; Next qword

	jmp arw_loop_1

arw_loop_2:

	cmp r13,[r15+16]					; Check to see of we reached the end
	jge arw_check_carry

	mov  r9, [r15+r13*8+32]				; Get qword from larger number
	sahf								; Restore carry flag
	adc  r9, 0							; Add to zero to propagate carry
	lahf								; Save carry flag (will be cleared)
	mov  [rdi+r13*8+32], r9				; Save in destination 
	inc  r13							; Next qword

	jmp arw_loop_2

arw_check_carry:

	sahf								
	jnc arw_set_header					; Check to see if we have a final carry

	mov  r9, 1
	mov  [rdi+r13*8+32], r9				; Set final carry
	inc  r13

arw_set_header:
	
	mov  [rdi+16], r13
	mov  rax,rdi

	; Procedure Epilog

	pop  r15
	pop  r14
	pop  r13							; Restore non-volatile registers
	pop  rdi							;

	pop  rbp							; Restore the old base pointer
	ret

LIOAddRaw endp

;********************************************************************************
;
;	  Purpose:  Subtract two large integers ingoring the sign
;
;	  ptr    :  Minuend Large integer
;     ptr    :  Subtrahend large integer
;     
;     return :  New large integer holding the difference
;
;********************************************************************************

LIOSubRaw proc Public

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Save first number
	mov  [rbp+24], rdx					; Save second number

    push rdi							; Save mon-volitile registers
	push r14							;
	push r15							;
	sub  sp,8							;

	; End prolog

	; Rudimentary error checking		

	xor  rax, rax						; set ax to zero to flag error status
	
	mov  r8, [rcx+16]					; Check to make sure length of first number
	cmp  r8, [rdx+16]					;     is greater than or equal to second
	jl   sub_done					
	
	; Do subtraction						

	mov  r14, rdx						; Save the small number
	mov  r15, rcx						; Save the large number

    mov  rcx, r8				

	sub  rsp,32							; Make home frame
	call LIOMakeInt
	add  rsp,32							; Destory home frame

	mov  rdi, rax						; Set starting destination of new number

	; Do the math!!!

	clc									; clear the cary flag
	lahf								; save in AH
	xor r10,r10							; clear qword counter;
	xor r11,r11							; Clear maximum non-zero resultant qword tracker

sub_loop_1:

	cmp r10,[r14+16]					; Check for end of short number
	jge sub_loop_2						;

	mov  r9, [r15+r10*8+32]
	sahf								; restore borrow flag 
	sbb  r9, [r14+r10*8+32]
	lahf								; save borrow flag
	mov  [rdi+r10*8+32], r9
	inc  r10

	test r9,r9							; Check to see if the result was zero
	jz   sub_loop_1

	mov  r11,r10						; Result not zero so set new high order qword

	jmp  sub_loop_1

sub_loop_2:

	cmp r10,[r15+16]
	jge check_borrow_error

	mov  r9, [r15+r10*8+32]
	sahf
	sbb  r9,0
	lahf
	mov  [rdi+r10*8+32], r9
	inc  r10

	test r9,r9							; Check to see if the result was zero
	jz   sub_loop_2

	mov  r11,r10						; Result not zero so set new high order qword

	jmp sub_loop_2

check_borrow_error:

	sahf
	jnc sub_set_header

	mov rcx, rdi						; We have a borrow wich means the parameters were wrong

	sub  rsp,32							; Destory our number 
	call LIODestroyInt
	add  rsp,32	

	xor  rax, rax						; return 0 to signal error
	jmp  sub_done

sub_raw_zero:

	xor  rcx, rcx

	sub  rsp,32							
	call LIOMakeInt						; Make zero int
	add  rsp,32							

	jmp  sub_done

sub_set_header:
	
	mov  [rdi+16], r11
	mov  rax,rdi

sub_done:

	; Procedure Epilog

	add  sp,8
	pop  r15							; Restore non-volatile registers
	pop  r14							;
	pop  rdi							;

	pop  rbp							; Restore the old base pointer
	ret

LIOSubRaw endp


;********************************************************************************
;
;	  Purpose:  Multipy a single qword multiplier to the multiplicand and
;				add the result to the product starting at the products 
;				qword specified by the index (note index 0 is the lower
;				order qword). This procedure is used in multiplicaton.
;
;	  ptr    :  Multiplicand Large integer
;     ptr    :  Multiplier large integer
;     ptr    :  Product large integer
;     qword  :  product offest
;     
;     return :  New large integer holding the product
;
;********************************************************************************

LIOMulAndAdd  proc Public

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number
	mov  [rbp+24], rdx					; Qword 
	mov  [rbp+32], r8					; Destination number (to add to)
	mov  [rbp+40], r9					; Offset

    push rsi							; Save mon-volitile registers	
	push rdi   							;

	; End Epilog


	mov rax, [rcx+16]
	test rax, rax
	jz maa_done
	test rdx, rdx						; Check for zero qword
	jz maa_done

	mov  r10, r9						; Check minimum destination size
	add  r10, [rcx+16]					;						;
	cmp  r10, [r8+16]					;
	jge  maa_big_enough					;

	mov  r10, [r8+16]					;

maa_big_enough:

	inc	 r10							;
	cmp  r10, [r8+8]					;
	jg   maa_overflow					;

	xor  r12, r12						; Zero source counter
	mov  rsi, rdx						; Save source qword

maa_mull_loop:

	cmp r12, [rcx+16]					; Check for end of number
	jge maa_set_length

	mov  rax, rsi						; Put qword into rax for multiply
	mul  QWORD PTR [rcx+r12*8+32]		; muliply qword with qword of source number
	
	add  rax, [r8+r9*8+32]				; Add first qword of result to destination 
	adc  rdx, [r8+r9*8+40]				; Add second qword of result to destination
    mov  [rdi+r9*8+32], rax				; Save first qword of result back to destination
	mov  [rdi+r9*8+40], rdx				; Save second qword of result back to destination

	inc r9								; increment offset to destination
	inc r12								; increment source qword counter

	mov r11, r9							; Init carry flag propagation
	
carry_loop:

	jnc maa_mull_loop					; Check for a carry

	inc r11								; Next destination qword
	mov rax, 0							; clear rax
	adc rax, [r8+r11*8+32]				; Add in carry flag to destination qword
	mov [r8+r11*8+32], rax				; Save result in destination

	jmp carry_loop

maa_overflow:

	xor  rax, rax
	jmp  maa_done

maa_set_length:

	cmp  qword ptr [r8+r11*8+32],  1
	sbb  r11,0
	inc  r11
	mov  [r8+16], r11

	mov  rax, rdi

maa_done:

	; Procedure Epilog

	pop  rdi							; Restore mon-volitile registers							;
	pop  rsi							;

	pop  rbp				; Restore the old base pointer
	ret

LIOMulAndAdd endp

;********************************************************************************
;
;	  Purpose:  Estimate a large multiple of the quotient that can be 
;               subtracted from the dividend, and subtract it. Also
;               add our quotient muliplier to the quotient (if provided). 
;				This procedure is used in division. Sign is ignored
;				The quotient should be large enough to hold it's result
;
;	  ptr    :  Dividend/decumulator large integer 
;     ptr    :  Divisor large integer
;     ptr    :  Quotient large integer (or null)
;     
;     return :  return 0 if the resultant dividend/decumulator is less than  
;				or equal to the divisor (in this case the dividend/decumulator 
;               will hold the remainder)
;
;********************************************************************************

LIOEstimateAndSubtract proc 


	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Dividend/Decumulator
	mov  [rbp+24], rdx					; Divisor 
	mov  [rbp+32], r8					; quotient

	push rbx
	push rsi
	push rdi
	push r12
	push r13
	push r14
	push r15
	sub  rsp, 8

	; End Prolog

	xor rbx, rbx						; Initialize continue flag 

	mov  r13, [rcx+16]					; Get length of D/D
	test r13, r13						; Check for D/D zero
	jz est_done							;

	bsr  r15, qword ptr [rcx+r13*8+24]	; Find index of first bit in D/D
	dec  r13							;
	shl  r13, 6							;
	add  r13, r15						;

	mov  r11, [rdx+16]					; Get length of divisor
	test r11, r11						; Test for zero (Note: zero is illegal here)
	jz	 est_done						;

	bsr  r15, qword ptr [rdx+r11*8+24]	;Find index of first bit in D/D
	dec  r11							;
	shl  r11, 6							;
	add  r11, r15						;

	mov  rdi, rcx						; Save D/D in rdi since we rcx is volatile		
	mov  rsi, rdx					    ; Save Divisor in rsi since rdx is volatile
	
	sub  r13, r11						; Calculate difference in magnitude between D/D and Divisor

	jl   est_done					    ; If D/D magnitude is less than divisor magnitude we are done. 
	jg   est_sub_mag_one_less			; D/D and Divisor magnitues are the same so do a full comparison

	sub  rsp,32						
	call LIOCompareRaw					; Do a raw complare of our numbers
	add  rsp,32

	mov  r8,  [rbp+32]					; Restore quotient since r8 is volatile

	test rax, rax
	js est_done							; Divisor is less than D/D so we are done 
	jz est_sub_mag_equal				; Divisor is equal to D/D so well will have no remainder.
										;    Do subtraction but don't set the continue flag
	mov  rbx, 1							; D/D is still greater than the quotient so set the continue flag 
	
est_sub_mag_equal:

	xor  r12,r12						; Divisor and D/D are of the same magnitude so we don't
	xor  r13,r13						;    do any shifting and we subtract from the beginning of D/D
	jmp  est_sub_quotient_power
	
est_sub_mag_one_less:

	dec  r13							; Divisor magnitude is at least one less than D/D magnitude
	mov  r12, r13						;   so calculate divisor shift in bits (r12) and starting
	shr  r13, 6							;	qword (r13)
	and  r12, 000000000000003Fh			;

	mov  rbx, 1							; Set continue flag

est_sub_quotient_power:

	xor r10,r10							; init divisor qword index
	xor rdx,rdx							; Clear leftover bits register
	mov r11,r13							; Init D/D qword counter
	mov r9, 63							; Calculate requred right shift value - 1 needed to align carry over bits
	sub r9, r12							;    Note: we need to shift from 1 to 64 so we must do it in two steps 
										;		   since shrx will only shift 63 maximum
	clc									; clear the carry flag
	lahf
	
est_decumulator_loop:

	mov  r14, [rsi+r10*8+32]			; get qword of quotient

	mov  rcx, r12
	shl  r14, cl						; Shift it left to align with D/D qword
	or   r14, rdx						; Include needed bits from previous quotient qword

	mov  rdx, [rsi+r10*8+32]			; Get a qword again to calculate bits to pass on to next subtract
	shr  rdx, 1							; We need to shift right from 1 to 64 so we must do it in two steps
	mov  rcx, r9						;    in two steps
	shr  rdx, cl 						;

	mov  r15, [rdi+r11*8+32]			; Get the D/D qword to subtract from
	sahf								; Set borrow status from last subtract
	sbb  r15, r14						; Do subtraction 
	lahf								; Save borrow status for next subtract
	mov  [rdi+r11*8+32],r15				; Save result back into D/D
	
	inc  r10							; Increment quotient qword counter
	inc  r11							; increment D/D qword counter
	cmp  r10, [rsi+16]					; check for last quotient qword
	jl   est_decumulator_loop			; if not last quotient qword then loop 		

	test rdx, rdx						; Check for remaining qword bits
	jz   est_check_for_borrow			; If non bits check for carry

	mov  r15, [rdi+r11*8+32]            ; Get the D/D qword to subtract from
	sahf								; Set borrow status from last subtract
	sbb  r15, rdx						; Do subtraction 
	lahf								; Save borrow status for for subtract from qero
	mov  [rdi+r11*8+32],r15				; Save result back into D/D

	inc  r11

est_check_for_borrow:

	sahf
	jnc  est_resize_dd					; Check for borrow

	mov  r15, [rdi+r11*8+32]			; Get the D/D qword to borrow from
	sbb  r15, 0							; Do borrow
	mov  [rdi+r11*8+32],r15				; Save result back into D/D

est_resize_dd:

	std									; Set direction flag to scan backwards
	xor rax,rax							; Scan for first zero
	mov r15, rdi						; We need rdi for scan use r15 to address D/D
	mov rcx, [r15+16]					; Scan back the old length of the D/D
	lea rdi, [r15+rcx*8+24]				; Set the address old high order qword to start scan
	inc rcx								; Increase scan length by 1 of there are no high order bits we end up
										;     left of the number and the new length is calculated to zero
	repe scasq							; scan for first non-zero high order qword of D/D

	sub rdi, r15						; calculate qword offset from beginning of D/D
	shr rdi, 3							; Convert to number of qwords
	sub rdi, 2							; Subtract 2 to compensate for stuff
	mov [r15+16],rdi					; Set new D/D length
	cld

	test r8, r8							;Check to see if we are generating a quotient.
	jz   est_done						;    If not we are done.

	lea  r15, [r13+1]					; Calculate new quotient size 
	cmp  r15, [r8+16]					; Check to see if we need to expand the quotient
	jle  est_quotient_ok				;
	mov  [r8+16], r15					; Set new quotient size

est_quotient_ok:

	mov  r15, 1							; Generate power of 2 quotient we used above
	mov  rcx, r12						;	 for the subtraction
	shl  r15, cl 
	add  r15, [r8+r13*8+32]				; Add to quoient
	lahf								; Save the carry flag 		
	mov  [r8+r13*8+32],r15				; Save the result 
	jnc  est_done						; Check for carry
	
est_carry_loop:
								
	inc  r13							; Go to next qword of quotient
	cmp  r13, [r8+16]					; Check to see if we need to expand the quotient
	jl   ext_add_carry_to_quotient		;

	lea  r15, [r13+1]					; Calculate new quotient size 
	mov  [r8+16], r15					; Set new quotient size
	; xor  r15, r15						; Make sure are new high bits
	; mov  [r8+r13*8+32],r15			;	 are zeroed

ext_add_carry_to_quotient:

	mov  r15, [r8+r13*8+32]				; Get qword of quotient to add carry to
	sahf								; Restore carry flag
	adc  r15, 0							; Add carry
	lahf								; Save the carry flag
	mov  [r8+r13*8+32],r15				; Save the result back in the quotient

	jc   est_carry_loop

est_done:

	mov rax,rbx							; Set return value (continue flag)

	; Procedure Epilog

	add  rsp, 8
	pop  r15
	pop  r14
	pop  r13
	pop  r12
	pop  rdi
	pop  rsi
	pop  rbx

	pop  rbp				; Restore the old base pointer
	ret

LIOEstimateAndSubtract endp


;********************************************************************************
;
;	  Purpose:  Multiply multiplicand in place by 10. 
;
;	  ptr    :  multiplicand large integer 
;     
;     return :  return 0 
;
;********************************************************************************

LIOMultiplyInPlaceBy10 proc

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number 1

	; End Prolog

	xor r11,r11
	xor r9, r9
	clc									; clear the carry flag
	lahf

m10_loop:

	cmp  r11, [rcx+16] 
	jge  m10_check_left_and_carry

	mov  r8, [rcx+r11*8+32]
	mov  r10, r8
	shl  r8,3
	or   r8,r9
	shl  r10,1
	shr  r9,2
	or   r10,r9
	sahf
	adc  r8,r10
	lahf

	mov  r9, [rcx+r11*8+32]
	shr  r9, 61

	mov  [rcx+r11*8+32], r8

	inc  r11

	jmp m10_loop

m10_check_left_and_carry:

	sahf
	jc m10_expand
	test r9, r9
	jz m10_OK

m10_expand:

	lea  r8,[r11+1]
	cmp  r8,[rcx+8]
	jg   m10_overflow
	mov  [rcx+16], r8 
	 
	mov  r8, r9
	shr  r8, 2

	sahf
	adc  r8,r9

	mov  [rcx+r11*8+32], r8

	jmp m10_OK

m10_overflow:

	xor  ax,ax
	jmp  m10_done

m10_OK:

	mov  ax,1

m10_done:

	xor  rax, rax

	; Procedure Epilog

    mov  rsp, rbp
	pop  rbp							; Restore the old base pointer
	ret


LIOMultiplyInPlaceBy10 endp

;********************************************************************************
;
;	  Purpose:  Add the addend qword to the augend large integer
;
;	  ptr    :  Multiplicand large integer 
;     qword  :  Addend
;     
;     return :  return 0 
;
;********************************************************************************

LIOAddInPlaceQWord proc

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number 1
	mov  [rbp+24], rdx

	; Procedure Epilog

	test dx, dx							; test for adding zero
	jz aip_OK							; if we are adding zero we are done

	xor  r9, r9							; clear qword counter
	clc									; Clear carry flag
	lahf								; Save carry flag			

aip_loop:

	cmp  r9, [rcx+16]					; Check to make sure our number is big enough
	jl aip_big_enough					

	lea  r10, [r9+1]					; Calculate new number size
	cmp  r10, [rcx+8]					; Check for overflow
	jg   aip_overflow					; 
	mov  [rcx+16], r10					; Set new number size
	xor r10,r10							; 					
	mov  [rcx+r9*8+32], r10				; Set new high bits to zero
	
aip_big_enough:

	sahf
	adc rdx, [rcx+r9*8+32]				; add in our number on first pass or carry on subsequent passes
	mov [rcx+r9*8+32],rdx				; Save result back in number
	mov rdx,0
	lahf
		
	jc  aip_loop						; Check for carry

aip_OK:

	mov  ax, 1
	jmp  aip_done

aip_overflow:

	xor ax, ax

aip_done:
	
	; Procedure Epilog

    mov  rsp, rbp
	pop  rbp							; Restore the old base pointer
	ret

LIOAddInPlaceQWord endp


;********************************************************************************
;
;	  Purpose:  Add two large integers
;
;	  ptr    :  Augend large integer
;     ptr    :  Addend large integer
;     
;     return :  New large integer holding the sum
;
;********************************************************************************

LIOAdd proc export


	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number 1
	mov  [rbp+24], rdx					; Source number 2

	push r12
	sub  rsp, 8

	; End Prolog

	mov  rax, [rcx+24]
	xor  rax, [rdx+24]

	jnz add_do_sub

	mov r12, [rcx+24]					; save sign

	sub  rsp,32	
	call LIOAddRaw						
	add  rsp,32

	jmp add_set_sign

add_do_sub:

	sub  rsp,32	
	call LIOCompareRaw					; Compare size of integers ignoring sign
	add  rsp,32	

	mov  r8, rax

	test r8, r8
	jz add_zero
	js add_swap
	
	mov  rcx, [rbp+16]			
	mov  rdx, [rbp+24]
	mov  r12, [rcx+24]					; save sign
		
	jmp  add_raw_sub	
	
add_swap:

	neg  r8
	mov  rcx, [rbp+24]			
	mov  rdx, [rbp+16]
	mov  r12, [rcx+24]					; save sign

	jmp  add_raw_sub

add_zero:

	xor r12, r12						; set sign to zero

add_raw_sub:
	
	sub  rsp,32	
	call LIOSubRaw						
	add  rsp,32	

add_set_sign:

	mov [rax+24], r12					; Set sign

	; Procedure Epilog

	add  rsp, 8
	pop  r12

	pop  rbp				; Restore the old base pointer
	ret

LIOAdd endp

;********************************************************************************
;
;	  Purpose:  Subtract two large integers
;
;	  ptr    :  Minuend Large integer
;     ptr    :  Subtrahend large integer
;     
;     return :  New large integer holding the difference
;
;********************************************************************************

LIOSub proc export


	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number 1
	mov  [rbp+24], rdx					; Source number 2

	push r12
	sub  rsp, 8

	; End Prolog

	mov  rax, [rcx+24]					; Calculate sign flag (0 = signs same, 1 = signs different)
	xor  rax, [rdx+24]					;

	jz sub_do_sub

	mov r12, [rcx+24]					; save sign

	sub  rsp,32	
	call LIOAddRaw						; Add signless mumbers	
	add  rsp,32

	jmp sub_set_sign

sub_do_sub:

	sub  rsp,32	
	call LIOCompareRaw					; Compare size of integers ignoring sign
	add  rsp,32	

	mov  r8, rax

	test r8, r8
	jz sub_zero
	js sub_swap

	mov  rcx, [rbp+16]					; First number is greater so simply restore 
	mov  rdx, [rbp+24]					;    rcx and rdx in their original order

	mov  r12, [rcx+24]					; Save sign for result
		
	jmp  sub_raw_sub	
	
sub_swap:

	mov  rcx, [rbp+24]					; First number is greater so  restore
	mov  rdx, [rbp+16]					;    rcx and rdx swapped

	mov  r12, [rcx+24]					; Save -sign for result
	xor  r12, 1							;

	jmp  sub_raw_sub

sub_zero:

	xor  rcx, rcx						; Set length parameter to zero for zero integer

	sub  rsp,32	
	call LIOMakeInt						; Make zero integer
	add  rsp,32	

	jmp  sub_done						

sub_raw_sub:
	
	sub  rsp,32	
	call LIOSubRaw						; Subtract signless numbers
	add  rsp,32	

sub_set_sign:

	mov [rax+24], r12					; Set sign

sub_done:

	; Procedure Epilog

	add  rsp, 8
	pop  r12

    mov  rsp, rbp
	pop  rbp				; Restore the old base pointer
	ret

LIOSub endp


;********************************************************************************
;
;	  Purpose:  Muultiply two large integers
;
;	  ptr    :  Multiplicand Large integer
;     ptr    :  Multiplier large integer
;     
;     return :  New large integer holding the product
;
;********************************************************************************

LIOMul proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number 1
	mov  [rbp+24], rdx					; Source number 2

	push r14
	push r15
	push rdi
	push r13

	;End Prolog

	mov  r9, [rcx+16]					; Check for first number zero
	test r9, r9							;
	jz   mul_zero						;

	mov  r9, [rdx+16]					; Check for second number zero
	test r9, r9							;
	jz   mul_zero						;

	mov  rax, [rcx+16]
	cmp  rax, [rdx+16]					; make sure first number is greater than second (this is an optimization)
	jl   mul_first_greater				; Do we need to swap?

	mov  r15, rcx
	mov  r14, rdx
	jmp  mul_make_dest

mul_first_greater:

	mov  r14, rcx
	mov  r15, rdx

mul_make_dest:

	mov  rcx, [r14+16]
	add  rcx, [r15+16]					; Calculate maximum length of destination number

	sub  rsp,32							;
	call LIOMakeInt						; Make destination integer
	add  rsp,32							;
	
	mov  rdi, rax						; Save destination number

	mov  rax, [r14+24]					; Calculate and store sign of product
	xor  rax, [r15+24]					;
	mov  [rdi+24], rax					;

	xor  r13,r13

mul_loop:

    cmp r13, [r15+16]
	jge mul_loop_done

	mov rcx, r14
	mov rdx, [r15+r13*8+32]
	mov r8,  rdi
	mov r9,  r13

	sub  rsp,32							;
	call LIOMulAndAdd					;
	add  rsp,32	

	inc  r13
	jmp  mul_loop

mul_zero:

	xor  rcx, rcx

	sub  rsp,32					; Make home frame
	call LIOMakeInt
	add  rsp,32	

	jmp  mul_done

mul_loop_done:

	mov  rax, rdi

mul_done:

	; Procedure Epilog

	pop  r13
	pop  rdi
	pop  r11
	pop  r10

	mov  rsp, rbp
	pop  rbp				; Restore the old base pointer
	ret

LIOMul endp

;********************************************************************************
;
;	  Purpose:  Divide two large integers
;
;	  ptr    :  Dividend Large integer
;     ptr    :  Divisor large integer
;     
;     return :  New large integer holding the quotient
;
;*******************************************************************************

LIODiv proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	;mov  [rbp+16], rcx					; Source number 1
	;mov  [rbp+24], rdx					; Source number 2

	push rsi
	push rdi
	push r14
	push r15

	;End Prolog

	cmp qword ptr [rdx+16], 0			; Check to see if divisor is zero
	je div_done

	mov  r14, rcx				
	mov  r15, rdx

	sub  rsp,32	
	call LIOCompareRaw					; Compare size of integers ignoring sign
	add  rsp,32	

	test ax,ax
	js div_zero
	jz div_one

	mov  rcx, r14

	sub  rsp,32							;
	call LIOCopyInt						; Temporary buffer for calculation
	add  rsp,32							;

	mov rsi, rax
	
	add  rcx, [r14+16]					; Calculate maximum length of destination number
	sub  rcx, [r15+16]
	inc  rcx

	sub  rsp,32							;
	call LIOMakeInt						; Make destination integer
	add  rsp,32							;

	mov  rdi, rax						; Save destination

div_next:

	mov  rcx, rsi				
	mov  rdx, r15
	mov  r8,  rdi

	sub  rsp,32	
	call LIOEstimateAndSubtract			; Estimate a power of two * the divisor we can
	add  rsp,32							;    subtract from the quotient and subtract it

    test rax, rax
	jnz div_next
	 
	mov  rcx, rsi						
	call LIODestroyInt					; Destroy D/D

	mov  rax, rdi						; Set return value

	jmp  div_done

div_zero:

	mov  rcx, 0

	sub  rsp,32						
	call LIOMakeInt						; Create number zero
	add  rsp,32	

	jmp  div_done

div_one:

	mov  rcx, 1

	sub  rsp,32					
	call LIOMakeInt						; Create number zero
	add  rsp,32	

	mov  r8, 1
	mov  [rax+16], r8					; Set qword count to 1
	mov  [rax+32], r8					; Set data value to 1

div_done:

	; Procedure Epilog

	pop  r15
	pop  r14
	pop  rdi
	pop  rsi

	pop  rbp				; Restore the old base pointer
	ret

LIODiv endp

;********************************************************************************
;
;	  Purpose:  Take the modulous of two large integers
;
;	  ptr    :  Multiplicand Large integer
;     ptr    :  Multiplier large integer
;     
;     return :  New large integer holding the remainder
;
;*******************************************************************************

LIOMod proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	;mov  [rbp+16], rcx					; Source number 1
	;mov  [rbp+24], rdx					; Source number 2

	push rsi
	push rdi
	push r14
	push r15

	;End Prolog
		
	cmp qword ptr [rdx+16], 0			; Check to see if divisor is zero
	je mod_done

	mov  r14, rcx				
	mov  r15, rdx

	sub  rsp,32	
	call LIOCompareRaw					; Compare size of integers ignoring sign
	add  rsp,32	

	test ax,ax
	js mod_remainder
	jz mod_zero

	mov  rcx, r14

	sub  rsp,32							;
	call LIOCopyInt						; Make int for remainder
	add  rsp,32							;

	mov rsi, rax

mod_next:

	mov  rcx, rsi				
	mov  rdx, r15
	xor  r8,  r8

	sub  rsp,32	
	call LIOEstimateAndSubtract
	add  rsp,32	

    test rax, rax
	jnz mod_next
	
	mov  rax, rsi

	jmp  mod_done

mod_remainder:

	mov  rax, rcx

	jmp  mod_done

mod_zero:

	mov  rcx, 0

	sub  rsp,32					
	call LIOMakeInt
	add  rsp,32	

	mov  r8, 1
	mov  [rax+16],  r8					; Set qword count to 1
	mov  [rax+32], r8					; Set data value to 1

mod_done:

	; Procedure Epilog

	pop  r15
	pop  r14
	pop  rdi
	pop  rsi

	pop  rbp				; Restore the old base pointer
	ret

LIOMod endp

;********************************************************************************
;
;	  Purpose:  Convert a decimal BCD integer to a large integer
;
;	  ptr    :  Decimal BCD integer to convert
;     
;     return :  New large integer holding the result
;
;*******************************************************************************

LIOConvertDecToInt proc export


	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number 1

	push rsi
	push rdi
	push r13
	sub  sp,8

	;End Prolog

	xor rax, rax						; Clear return value

	cmp  qword ptr [rcx+32], 10			; Check to make sure we have base 10
	jne cdeci_done						;

	mov  rax, [rcx+16]					; Caclulate rough estimate for maximum number of bits
	mov  r8, rax						;    base on number of decimal digits  
	mov  r9, rax						;	 Digits * 3.5 + 1
	shl  r8,1							;
	shr  r9,1							;
	add  rax,r8							;
	add  rax,r9							;
	inc  rax							;

	add  rax, 63						; Convert bits to qwords 
	shr  rax, 6							;

	mov  rcx, rax
	
	sub  rsp,32		
	call LIOMakeInt
	add  rsp,32	

	mov  rdi, rax
	mov  rsi, [rbp+16]
	mov  r13, [rsi+16]

cdeci_add_loop:

	test r13, r13
	jz  cdeci_set_header 

	dec  r13

	mov  rcx, rdi

	sub  rsp,32
	call LIOMultiplyInPlaceBy10
	add  rsp,32

	; We can check for overflow here if we want but it shouldn't happen

	mov  rcx, rdi
	xor  rdx, rdx
	mov  dl, [rsi+r13*1+40]

	sub  rsp,32
	call LIOAddInPlaceQWord
	add  rsp,32

	jmp cdeci_add_loop

cdeci_set_header:

	mov  rax, [rsi+24]					; Copy sign
	mov  [rdi+24], rax					;
	mov  rax, rdi						; Set return value
	
cdeci_done:

	; Subroutine Epilogue 

	add  sp,8
	pop  r13
	pop  rdi
	pop  rsi

	pop  rbp			; Restore the caller's base pointer value
	ret
			
LIOConvertDecToInt endp


;********************************************************************************
;
;	  Purpose:  Convert a large integer to a decimal BCD integer
;
;	  ptr    :  Large integer to convert
;     
;     return :  New decimal BCD integer holding the result
;
;*******************************************************************************

LIOConvertIntToDec proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number 1

	push rbx
	push rsi
	push rdi
	push r12
	push r13
	push r14

	; End Prolog

	mov rsi, rcx						; Save source int

	mov  r12, [rsi+16]					; Get int qwords 
	test r12, r12						; check for zero 
	jnz cidec_not_zero					
	
	xor  rcx, rcx						; Set zero length for zero BCD 

	sub  rsp,32					
	call LIOMakeBCD						; Make zero BCD 
	add  rsp,32
	 
	mov  rdi, rax						; Make destination zero

    jmp cidec_set_header				

cidec_not_zero:						

	mov  r14, QWORD PTR [rsi+r12*8+24]	; Get last qword of source int
	bsr  r13, r14						; Find first non-zero bit
	mov  rcx, 63						; Calculate number of bits to shift left so that the
	sub  rcx, r13						;    first set bit is all the way to the left
	shl  r14, cl						; Shift set bits to left end of qword 
	inc  r13							; Change from bit index to bit count

	dec  r12							; highest order qword bits are already in r14 so 
										;    decrement qword count to reflect this
	mov  rax, r12						; Calculate number number of bits in
	shl  rax, 6							;	 remaining qwords
	add  rax, r13						; Add in the high order bit count
	xor  rdx, rdx						; Clear rdx for divide
	mov  r8, 3							; Set divisor to 3
	div  r8								; Divide by 3 and add 1 for a very rough maximum 
	inc  rax							;	 base 10 digits. 

	mov  rcx, rax						; Set data size for destination BCD number

	sub  rsp,32							
	call LIOMakeBCD						; Make destination BCD
	add  rsp,32	
	
	mov  rdi, rax						; Save destination BCD

cidec_bit_loop:

	xor  r8, r8							; Reset BCD digit counter
	shl  r14, 1							; Shift left most bit from current binary qword into carry flag
	lahf								; Save carry flag

cidec_shift_loop:

	cmp  r8, [rdi+16]					; Check to make see if our BCD digit index is 
	jge cidec_check_expand				;	 beyond the length of the number

	mov  bl, [rdi+r8*1+40]				; Get our BCD diget
	cmp  bl, 5							; is it greater or equal to 5 so we need to add three?
	jl   cidec_no_add

	add bl,3							; Add 3

cidec_no_add:

	sahf								; restore carry bit 
	rcl  bl,1							; rotate it into our current byte
	shl  bl,4							; shift it 4 
	lahf								; save our new carry
	shr  bl,4							; shift it back
	mov  [rdi+r8*1+40], bl

	inc r8								; increment for next bcd digit
	jmp cidec_shift_loop				; 

cidec_check_expand:

	sahf								; Restore carry bit
	jnc cidec_next_bit					; check for expand bcd

	;xor rbx, rbx						
	;sahf
	;rcl bl,1

	mov bl, 1							; Create new digit starting with 1
	mov  [rdi+r8*1+40], bl				; Save digit 
	inc r8								; Increment BCD length
	mov [rdi+16], r8					; Set BCD lenght
	
cidec_next_bit:

	dec r13								; Decrement bit counter
	jnz cidec_bit_loop					; Check to see if we have finished with this qword

	test r12,r12						; Check to see if we have any more qwords
	jz   cidec_set_header				;

	dec  r12							; Decrement binary qword counter
	mov  r14, [rsi+r12*8+32]			; Load new binary qword for processing
	mov  r13, 64						; Reset bit counter for current qword

	jmp cidec_bit_loop
		
cidec_set_header:

	mov  rax, [rsi+24]					; Copy sign
	mov  [rdi+24], rax					; 
    mov  qword ptr [rdi+32], 10			; Set to base 10
	mov  rax, rdi						; Set return value
	
	; Subroutine Epilogue 

	pop  r14
	pop  r13
	pop  r12
	pop  rdi
	pop  rsi
	pop  rbx

	pop  rbp			; Restore the caller's base pointer value
	ret

LIOConvertIntToDec endp

;********************************************************************************
;
;	  Purpose:  Convert a hexadecimal BCD integer to a large integer
;
;	  ptr    :  Hexadecimal BCD integer to convert
;     
;     return :  New large integer holding the result
;
;*******************************************************************************

LIOConvertHexToInt proc export


	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number 1

	push rbx							
	push rsi
	push rdi
	sub  sp,8

	;End Prolog

	xor rax, rax						; Clear return value

	cmp  qword ptr [rcx+32], 16			; Check to make sure we have base 16
	jne chexi_done						;
	
	mov rsi, rcx						; Save source BCD

	mov rbx, [rsi+16]					; Calculate number of qwords in int
	add rbx, 15							;
	shr rbx, 4							;

	mov rcx, rbx						; Set size parameter

	sub  rsp,32		
	call LIOMakeInt						; Make destination int
	add  rsp,32	

	mov  rdi, rax						; Save destination int

	xor  r8, r8							; Clear BCD counter
	xor  r9, r9							; Clear int counter								;

chexi_loop:

	cmp  r8, [rsi+16]					; Check for end of BCD
	jge chexi_set_header

	xor  rdx, rdx						; Clear all bits in preparation for shift
	mov  dl, [rsi+r8*1+40]				; Read in BCD byte
	mov  rcx, r8						; Calculate shift needed for integer
	and  cl, 0Fh						;     by mod of BCD counter * 4
	shl  cl, 2							;
	shl  rdx, cl						; Shift to correct position in int
	or   [rdi+r9*8+32], rdx				; Or into int

	add  cl, 196						; If cl is 60 (meaning we are on our last nibble of this qword)
	adc  r9, 0							;    the carry flag will be set by adding 196 so add 1 to r9. Otherwise add 0

	inc r8								; Next Hex digit

	jmp chexi_loop

chexi_set_header:

	mov [rdi+16], rbx					; Set number size
	mov rax, [rsi+24]					; Set sign 
	mov [rdi+24], rax					;
	mov  rax, rdi	

chexi_done:

	; Subroutine Epilogue 

	add  sp,8
	pop  rdi
	pop  rsi
	pop  rbx

	pop  rbp			; Restore the caller's base pointer value
	ret
			
LIOConvertHexToInt endp


;********************************************************************************
;
;	  Purpose:  Convert a large integer to a hexadecimal BCD integer
;
;	  ptr    :  Large integer to convert
;     
;     return :  New hexadecimal BCD integer holding the result
;
;*******************************************************************************

LIOConvertIntToHex proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number 1

	push rbx
	push rsi
	push rdi
	sub  sp, 8 

	; End Prolog

	mov rsi, rcx						; Save source int

	mov  rbx, [rsi+16]					; Get qwords in number
	test rbx, rbx
	jz   cihex_make_int

	dec  rbx
	bsr  rax, [rsi+rbx*8+32]
	shl  rbx, 6
	lea  rbx, [rbx+rax+4]
	shr  rbx, 2

cihex_make_int:

	mov  rcx, rbx

	sub  rsp,32							
	call LIOMakeBCD						; Make destination BCD
	add  rsp,32	

	mov  rdi, rax
	
	xor  r8, r8							; Clear BCD counter
	xor  r9, r9							; Clear int counter	
	mov  r10, 	[rsi+r9*8+32]			; Grab first qword of int

cihex_loop:

	cmp  r8, rbx						; Check for end of BCD
	jge cihex_set_header

	mov  r10, r8
	and  r10, 000000000000000Fh
	jnz  cihex_have_bits

	mov  rdx, [rsi+r9*8+32]
	inc  r9

cihex_have_bits:

	mov  al, dl
	and  al, 0Fh
	shr  rdx, 4

	mov  [rdi+r8*1+40], al

	inc  r8

	jmp cihex_loop

cihex_set_header:

	mov  [rdi+16], rbx
	mov  rax, [rsi+24]					; Copy sign
	mov  [rdi+24], rax					; 
    mov  qword ptr [rdi+32], 16			; Set to base 16
	mov  rax, rdi						; Set return value
	
	; Subroutine Epilogue 

	add  sp, 8
	pop  rdi
	pop  rsi
	pop  rbx

	pop  rbp			; Restore the caller's base pointer value
	ret

LIOConvertIntToHex endp

;********************************************************************************
;
;	  Purpose:  Convert any BCD integer to a large integer
;
;	  ptr    :  BCD integer to convert
;     
;     return :  New large integer holding the result
;
;*******************************************************************************

LIOConvertBCDToInt proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number 1

	;End Prolog

	xor  rax, rax
	
	mov  r8, [rcx+32]

	cmp  r8, 10
	jne  cbcdi_check_hex

	sub  rsp,32	
	call LIOConvertDecToInt
	add  rsp,32	

	jmp cbcdi_done

cbcdi_check_hex:
	
	cmp  r8, 16
	jne  cbcdi_done

	sub  rsp,32	
	call LIOConvertHexToInt
	add  rsp,32	

cbcdi_done:

	; Subroutine Epilogue 

	pop  rbp			; Restore the caller's base pointer value
	ret
			
LIOConvertBCDToInt endp

;********************************************************************************
;
;	  Purpose:  Convert a large integer to a BCD integer of type 
;               specified by the base parameter
;
;	  ptr    :  Large integer to convert
;     qword  :  base (10 = decamal, 16 = hexadecimal)
;     
;     return :  New hexadecimal BCD integer holding the result
;
;*******************************************************************************

LIOConvertIntToBCD proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number 1
	mov  [rbp+24], rdx					; Base to convert to

	;End Prolog

	xor  rax, rax

	cmp  rdx, 10
	jne  cibcd_check_hex

	sub  rsp,32	
	call LIOConvertIntToDec
	add  rsp,32

	jmp cibcd_done

cibcd_check_hex:
	
	cmp  rdx, 16
	jne  cibcd_done

	sub  rsp,32	
	call LIOConvertIntToHex
	add  rsp,32

cibcd_done:

	; Subroutine Epilogue 

	pop  rbp			; Restore the caller's base pointer value
	ret
			
LIOConvertIntToBCD endp

;********************************************************************************
;
;	  Purpose:  Make a large integer from an unsigned integer qword 
;
;	  qword  :  unsigned integer 
;     
;     return :  New large integer holding the result
;
;*******************************************************************************

LIOMakeUnsignedInt proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number

	;End Prolog

	test rcx, rcx
	jz   muint_zero						; check for zero

	mov  rcx, 1							; Set length to 1

	sub  rsp,32					
	call LIOMakeInt						; Create number 
	add  rsp,32	

	mov  qword ptr [rax+16], 1			; Set qword length to 1
	mov  r9, [rbp+16]					; Put value in first qword
	mov  [rax+32], r9					;

	jmp   muint_done

muint_zero:

	xor  rcx, rcx						; Set length to zero

	sub  rsp,32					
	call LIOMakeInt						; Create number zero
	add  rsp,32	

muint_done:

	; Subroutine Epilogue 

	pop  rbp							; Restore the caller's base pointer value
	ret
			
LIOMakeUnsignedInt endp


;********************************************************************************
;
;	  Purpose:  Make a large integer from a signed integer qword 
;
;	  qword  :  signed integer
;     
;     return :  New large integer holding the result
;
;*******************************************************************************

LIOMakeSignedInt proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number

	;End Prolog

	test rcx, rcx
	jz   msint_zero
	js   msint_neg

	mov  rcx, 1

	sub  rsp,32					
	call LIOMakeInt						; Create number 
	add  rsp,32	

	mov  qword ptr [rax+16], 1			; Set qword length to 1
	mov  r9, [rbp+16]					; Put value in first qword
	mov  [rax+32], r9					;

	jmp   msint_done

msint_zero:

	xor  rcx, rcx

	sub  rsp,32					
	call LIOMakeInt						; Create number zero
	add  rsp,32	

	jmp   msint_done

msint_neg:

	mov  rcx, 1

	sub  rsp,32					
	call LIOMakeInt						; Create number 
	add  rsp,32	

	mov  qword ptr [rax+16], 1			; Set qword length to 1
	mov  qword ptr [rax+24], 1			; Set sign to negetive
	mov  r9, [rbp+16]					; Set -value in first qword
	neg  r9								;
	mov  [rax+32], r9					;

msint_done:

	; Subroutine Epilogue 

	pop  rbp			; Restore the caller's base pointer value
	ret
			
LIOMakeSignedInt endp


;********************************************************************************
;
;	  Purpose:  Negate a large integer
;
;	  ptr    :  large integer to negate
;     
;     return :  New large integer holding the quotient
;
;*******************************************************************************

LIONeg proc export

	; Procedure Prolog

	push rbp							; Save the old base pointer value
	mov  rbp, rsp						; Set the new base pointer value.

	mov  [rbp+16], rcx					; Source number

	;End Prolog

	sub  rsp,32					
	call LIOCopyInt						; Create number 
	add  rsp,32	

	xor  qword ptr [rax+24], 1

msint_done:

	; Subroutine Epilogue 

	pop  rbp			; Restore the caller's base pointer value
	ret
			
LIONeg endp

;********************************************************************************

end 