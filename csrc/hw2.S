.global _start
.data
array: .word 0x3f99999a, 0x3f9a0000, 0x4013d70a, 0x40140000, 0x405d70a4, 0x405d0000, 0x40b428f6
# test data1: 1.200000, 1.203125, 2.310000, 2.312500, 3.460000, 3.4531255, 5.630000

array_bf16: .word 0, 0, 0, 0, 0, 0, 0

next_line: .string "\n"
max_string: .string "maximum number is "
bf16_string: .string "\nbfloat16 number is \n"
scale_num: .string "\nscale is "
transform_to_bf16_is: .string "\ntransform to bf16 is:"
.text
_start:
        # push data    
        addi sp, sp, -4
        la t0, array
        sw t0, 0(sp)

        la s10, array_bf16      # global array_bf16 address(s10)        
        addi s11, x0, 3         # data number(s11) -> three groups data
        li t5, 0x7F800000       # exp_mask
        li t6, 0x007FFFFF       # man_mask
        li s6, 0xFFFF0000       # bf16_mask
        li s7, 0x7FFFFFFF       # abs_mask
main_for:
     
        addi a3, x0, 7          # array size(a3)
        lw a1, 0(sp)            # array_data pointer(a1)
        mv a2, s10              # array_bf16 pointer(a2)

        
fp32_to_bf16_findmax:
# array_data pointer(a1), array_bf16 pointer(a2), array size(a3)
    
# array loop
for1:
        lw a5, 0(a1)            # x(a5)
        # fp32_to_bf16
        and t0, a5, t5          # x exp(t0)
        and t1, a5, t6          # x man(t1)
        # if zero        
        bne t0, x0, else
        # exp is zero
        bne t1, x0, else
        j finish_bf16        
else: 
        # if infinity or NaN
        beq t0, t5, finish_bf16                              
        # round        
        # r = x.man shift right 8 bit
        # x+r = x.man + x.man>>8
        li t3, 0x00800000      # make up 1 to No.24bit
        or t1, t1, t3
        srli t2, t1, 8         # r(t2)
        add t1, t1, t2         # x+r
        
        # check carry
        and t4, t1, t3         # check No.24bit (t4), 0:carry, 1: nocarry
        bne t4, x0, no_carry
        add t0, t0, t3         # exp+1
        srli t1 ,t1, 1         # man alignment
no_carry:
        and t0, t0, t5         # mask exp(t0)
        and t1, t1, t6         # mask man(t1)
        or t2, t0, t1          # combine exp & man
        li t3, 0x80000000      # sign mask
        and t3, a5, t3         # x sign
        or a5, t3, t2          # bfloat16(a5) 
        and a5, a5, s6         #s6 -> bf16_mask
finish_bf16:
        sw a5, 0(a2)

        
        slti t3, a3, 7         # (a3==7) t3=0, (a3<7) t3=1
        and s8, a5, s7         # abs bf16 -> s8
        bne t3, x0, compare
        # saved first max
        j max_change
        
compare:
        blt s8, s0, max_not_change

max_change:
        mv s0, s8              # max bf16(s0) 
        mv a4, a5              # max bf16(a4)
max_not_change:               
        addi a3, a3, -1
        addi a1, a1, 4
        addi a2, a2, 4
        bne a3, x0, for1
        
        # Absolute
        and a4, a4, s7         # s7=>0x7FFFFFFF abs_mask
        
        #print


        and s0, x0, s0
        and s1, x0, s1
        
#scale_function
scale:
        addi sp, sp, -16
        sw s2, 0(sp)
        sw s3, 4(sp)
        sw s4, 8(sp)
        sw s5, 12(sp)
        li s2, 0x7F            # 127 to hex
        li s3, 1               # add to fraction head (1.fraction)
        
        and t0, a4, t6         # max_man->t0   maxbf16->a4   man_mask=0x007FFFFF->t6
        srli t0, t0, 16        # bf16_man t0=t0>>15
        srli t1, a4, 23        # max_exp
        addi t1, t1, -127      # Denominator-> power of 2 <- t1
        li t4, 7               # man has 7bits
        sub t3, t4, t1 
        srl t0, t0, t3         # mean t0 >> (7-(power of 2)) 
        
        sll s3, s3, t1         # s3=(1<<t1)
        or t0, s3, t0          # 10^(t1) + fraction
        li a6, 0 
scale_loop:
        add s4, s4, t0
        addi a6, a6, 1         # count scale
        bge s2, s4, scale_loop
        lw s2, 0(sp)
        lw s3, 4(sp)
        lw s4, 8(sp)
        lw s5, 12(sp)
        addi sp, sp, 16
        mv t5,a6

        
int_to_fp:
        addi sp, sp, -16
        sw s2, 0(sp)
        sw s3, 4(sp)
        sw s4, 8(sp)
        sw s5, 12(sp)
        li t0, 0
        mv s2, a6
loop2:
        
        srli a6, a6, 1
        
        addi t0, t0, 1 
        blt x0, a6, loop2
###end loop2
        addi t0, t0, -1        # count shift right num
        
        addi s3, t0, 127       # exp_num
        # Why not +127? Because the shift count is one extra.
        slli s3, s3, 23        # exp in bf16 -> s3
        
        li t1, 0xFFFFFFFF
        li t2, 32
        sub t3, t2, t0
        srl t1, t1, t3
        and s4, s2, t1         # frac_num in bf16
        li t1, 23
        sub t1, t1, t0         # t1=23-(count shift right num)
        sll s4, s4, t1         # frac in bf16
        or s5, s4, s3          # int->bf16 ok
        mv a6, s5 
        
        
        lw s2, 0(sp)
        lw s3, 4(sp)
        lw s4, 8(sp)
        lw s5, 12(sp)
        addi sp, sp, 16

Multi_bfloat:
# decoder function input is a0
# jal ra,decoder        
# load a0(two bloat number in one register) to t0
# decoder function output is s5,s6
        addi sp, sp, -16
        sw s2, 0(sp)
        sw s3, 4(sp)
        sw s4, 8(sp)
        sw s5, 12(sp)
        
        mv s5, s10
        
        addi a3, x0, 7        # array size -> 7
for2: 
        lw a4, 0(s5)
        add t0,a6,x0          # store s5(bfloat 2) to t0
        add t1,a4,x0          # store s6(bfloat 1) to t1
        li s2,0x7F800000      # mask 0x7F800000
        # get exponent to t2,t3
        and t3,t0,s2          # use mask 0x7F800000 to get t0 exponent
        and t2,t1,s2          # use mask 0x7F800000 to get t1 exponent
        add t3,t3,t2          # add two exponent to t3
        li s2,0x3F800000      # mask 0x3F800000
        sub t3,t3,s2          # sub 127 to exponent

        # get sign
        xor t2,t0,t1          # get sign and store on t2
        srli t2,t2,31         # get rid of useless data
        slli t2,t2,31         # let sign back to right position
    
        # get sign and exponent together
        or t3,t3,t2
        # set the sign and exponent to t0
        slli t0,t0,9
        srli t0,t0,9
        or t0,t3,t0

        # get fraction to t2 and t3
        li s2,0x7F            # mask 0x7F
        slli s2,s2,16         # shift mask to 0x7F0000
        and t2,t0,s2          # use mask 0x7F0000 get fraction
        and t3,t1,s2          # use mask 0x7F0000 get fraction
        slli t2,t2,9          # shift left let no leading 0
        srli t2,t2,1          # shift right let leading has one 0
        li s2,0x80000000        # mask 0x80000000
        or t2,t2,s2           # use mask 0x80000000 to add integer
        srli t2,t2,1          # shift right to add space for overflow

        slli t3,t3,8          # shift left let no leading 0
        or t3,t3,s2           # use mask 0x80000000 to add integer
        srli t3,t3,1          # shift right to add space for overflow

        add s3,x0,x0          # set a counter and 0
        addi s4,x0,8          # set a end condition
        add t1,x0,x0          # reset t1 to 0 and let this register be result
        li s2,0x80000000      # mask 0x80000000

loop:
        addi s3,s3,1          # add 1 at counter every loop
        srli s2,s2,1          # shift right at 1 every loop
    
        and t4,t2,s2          # use mask to specified number at that place
        beq t4,x0,not_add     # jump if t4 equal to 0
        add t1,t1,t3          # add t3 to t1
not_add:
        srli t3,t3,1          # shift left 1 bit to t3
        bne s3,s4,loop        # if the condition not satisfy return to loop
# end of loop 

        # check if overflow
        li s2,0x80000000
        and t4,t1,s2          # get t1 max bit
    
        # if t4 max bit equal to 0 will not overflow
        beq t4,x0,not_overflow
    
        # if overflow
        slli t1,t1,1          # shift left 1 bits to remove integer
        li s2,0x800000        # mask 0x800000
        add t0,t0,s2          # exponent add 1 if overflow
        j Mult_end            # jump to Mult_end
     
        # if not overflow
not_overflow:
        slli t1,t1,2          # shift left 2 bits to remove integer
Mult_end:
        srli t1,t1,24         # shift right to remove useless bits
        addi t1,t1,1          # add 1 little bit to check if carry
        srli t1,t1,1          # shift right to remove useless bits
        slli t1,t1,16         # shift left to let fraction be right position
    
        srli t0,t0,23         # shift right to remove useless bits
        slli t0,t0,23         # shift left to let sign and exponent be right position
        or t0,t0,t1           # combine t0 and t1 together to get bfloat

        add a4,t0,x0          # store bfloat after multiplication to  s3
### end of function
  
#Remove the decimal part of the BF16 to make it an integer.
rm_decimal_of_bf16:
        mv t0, a4
        li t3, 0x80000000
        and t3, t0, t3
        srli t3, t3, 31       # Detecting positive or negative
        and t0,t0,s7          # absolution
        srli t0, t0, 23       # exp->s2
        addi t0, t0,-127      # power of 2
        and t1, t1, t6
        srli t1, t1, 16
        li t2, 0x80           # 1000 0000
        or t1, t1, t2
        li t2, 7
        sub t2, t2, t0        # how many bits do you right shift
        srl t1, t1, t2        # ANS
        li t2, 1
        bne t3, t2, printINT8
Add_negative_sign:
        add t2, t1, t1
        sub t1, t1, t2
printINT8:

# next data
        addi s5, s5, 4
        addi a3, a3, -1
        bne a3, x0, for2
### end of function
        lw s2, 0(sp)
        lw s3, 4(sp)
        lw s4, 8(sp)
        lw s5, 12(sp)
        addi sp, sp, 16
        
exit:
        j exit
