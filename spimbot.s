# syscall constants
PRINT_STRING = 4
PRINT_CHAR   = 11
PRINT_INT    = 1

# debug constants
PRINT_INT_ADDR   = 0xffff0080
PRINT_FLOAT_ADDR = 0xffff0084
PRINT_HEX_ADDR   = 0xffff0088

# spimbot constants
VELOCITY       = 0xffff0010
ANGLE          = 0xffff0014
ANGLE_CONTROL  = 0xffff0018
BOT_X          = 0xffff0020
BOT_Y          = 0xffff0024
OTHER_BOT_X    = 0xffff00a0
OTHER_BOT_Y    = 0xffff00a4
TIMER          = 0xffff001c
SCORES_REQUEST = 0xffff1018

TILE_SCAN       = 0xffff0024
SEED_TILE       = 0xffff0054
WATER_TILE      = 0xffff002c
MAX_GROWTH_TILE = 0xffff0030
HARVEST_TILE    = 0xffff0020
BURN_TILE       = 0xffff0058
GET_FIRE_LOC    = 0xffff0028
PUT_OUT_FIRE    = 0xffff0040

GET_NUM_WATER_DROPS   = 0xffff0044
GET_NUM_SEEDS         = 0xffff0048
GET_NUM_FIRE_STARTERS = 0xffff004c
SET_RESOURCE_TYPE     = 0xffff00dc
REQUEST_PUZZLE        = 0xffff00d0
SUBMIT_SOLUTION       = 0xffff00d4

# interrupt constants
BONK_MASK               = 0x1000
BONK_ACK                = 0xffff0060
TIMER_MASK              = 0x8000
TIMER_ACK               = 0xffff006c
ON_FIRE_MASK            = 0x400
ON_FIRE_ACK             = 0xffff0050
MAX_GROWTH_ACK          = 0xffff005c
MAX_GROWTH_INT_MASK     = 0x2000
REQUEST_PUZZLE_ACK      = 0xffff00d8
REQUEST_PUZZLE_INT_MASK = 0x800

.data
# data things go here
.align 2
puzzleChunk:	.space 4096
solutionChunk:	.space 328


#####================================#####
#                  Main
#####================================#####
.text
main:
    # go wild
    # the world is your oyster :)
    sw $0 , VELOCITY($0)
    li $t4, TIMER_MASK                         # timer interrupt enable
    or $t4, $t4, BONK_MASK                    # bonk interrupt enable
    or $t4, $t4, ON_FIRE_MASK                 # on fire interrupt enable
    or $t4, $t4, MAX_GROWTH_INT_MASK          # max growth interrupt
    or $t4, $t4, REQUEST_PUZZLE_INT_MASK      # request puzzle interrupt
    or $t4, $t4, 1
    mtc0 $t4, $12

	lw $t4, TIMER($0)
	add $t4, $t4, 2000000
	sw $t4, TIMER($0)



#####================================#####
#            Start Movement
#####================================#####


loadPositionStart:
    li  $t4, 0
    li  $t8, 0

moveToStart:
    li  $t2, 270
    sw  $t2, ANGLE($0)
    li  $t2, 1
    sw  $t2, ANGLE_CONTROL($0)  #ANGLE_CONTROL = ABSOLUTE
    li  $t2, 10
    sw  $t2, VELOCITY($0)       #VELOCITY = MAX
    li  $t2, 30
    lw  $t4, BOT_Y
    div $t4, $t2
    mflo $t4                #t4 = Bot Ypos in grid
    mfhi $t3
    li  $t2, 0              #check if it's in the top row
    beq $t4, $t2, moveToStartX   #Once hits top row, it should be at the starting Y
    beq  $t3, $0, getSeedStart
    j moveToStart           #TODO: Replace atStart with actual jump spot
getSeedStart:
    li  $t7, 5
    bgt $t8, $t7, moveToStart
    li  $t0, 1     	            #ELSE get seeds
    sw  $t0, SET_RESOURCE_TYPE($0)
    la  $t0, puzzleChunk
    sw  $t0, REQUEST_PUZZLE($0)
    addi $t8, $t8, 1
    j moveToStart

moveToStartX:
    li  $t4, 0
    li  $t8, 0
moveToStartX2:	
    li  $t2, 0
    sw  $t2, ANGLE($0)
    li  $t2, 1
    sw  $t2, ANGLE_CONTROL($0)  #ANGLE_CONTROL = ABSOLUTE
    li  $t2, 10
    sw  $t2, VELOCITY($0)       #VELOCITY = MAX
    li  $t2, 30
    lw  $t4, BOT_X
    div $t4, $t2
    mflo $t4                #t4 = Bot Ypos in grid
    li  $t2, 9              #checks if in right column
    beq $t4, $t2, moveAlong     #starts movement if in rightmost column
    beq $t8, $0, getWaterStart
    j moveToStartX2
getWaterStart:
    li  $t7, 5
    bgt $t8, $t7, moveToStartX2
    li  $t0, 1   	            #ELSE get seeds
    sw  $t0, SET_RESOURCE_TYPE($0)
    la  $t0, puzzleChunk
    sw  $t0, REQUEST_PUZZLE($0)
    addi $t8, $t8, 1
    j moveToStartX2

moveAlong:                  #initial angle set from start position
    li  $t2, 0
    sw  $t2, ANGLE($0)
    li  $t2, 1
    sw  $t2, ANGLE_CONTROL($0)
    li  $t0, 0  	            #ELSE get seeds
    sw  $t0, SET_RESOURCE_TYPE($0)
    la  $t0, puzzleChunk
    sw  $t0, REQUEST_PUZZLE($0)
    li  $t4, 0
    li	$t8, 0		      #Don't reuse t4, t8 throughout movement code
continueMove:
    lw  $t1, BOT_Y($0)
    lw $t7, BOT_X($0)
    li  $t2, 30
    div $t1, $t2
    mflo $t1                  #bot y with respect to 10x10
    div $t7, $t2
    mflo $t7                  #bot x with respect to 10x10
    beq $t1, 0, skip270       #if bot is in block 8,9 (bottom left of our circuit) it will not turn with bonk, we need to make it turn
    bgt $t7, 8, skip270
    li $t6, 270               #this code allows it to turn without bonk
    li $t5, 1
    sw $t6, ANGLE($0)
    sw $t5, ANGLE_CONTROL($0)
    li $t3, 3
    bge $t4, $t3, skip270
    sw $0, SEED_TILE($0)
    lw  $t1, GET_NUM_SEEDS($0)
    li  $t2, 10
    bge $t1, $t2, needWater         #IF bot => 10 seeds, get water
needSeeds:
    #li  $t0, 1     	            #ELSE get seeds
    #sw  $t0, SET_RESOURCE_TYPE($0)
    #la  $t0, puzzleChunk
    #sw  $t0, REQUEST_PUZZLE($0)
    #li $t4, 1
needWater:
    li  $t0, 0
    sw  $t0, SET_RESOURCE_TYPE($0)
    la  $t0, puzzleChunk
    sw  $t0, REQUEST_PUZZLE($0)
    add  $t4, $t4, 1
skip270:
    li  $t2, 10
    sw  $t2, VELOCITY($0)
    li  $t9, 1
    beq $t8, $t9, waterTileOnce
    sw $0, SEED_TILE($0)          #plant seed
    addi $t8, $t8, 1
    lw	 $t0, BOT_Y
    li	 $t1, 30
    div  $t0, $t1
    mfhi $t1
    beq	 $t1, $0, ResetWater
    j continueMove
ResetWater:
    li   $t8, 0
    j continueMove
waterTileOnce:
    addi $t8, $t8, 1
    li	 $t9, 8
    sw	 $t9, WATER_TILE($0)
    j continueMove


#####================================#####
#        Interrupt Handler/Dispatcher    #
#####================================#####
.kdata
chunkIH:        .space 1600
non_intrpt_str: .asciiz "Non-interrupt exception\n"
unhandled_str:  .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
    move  $k1, $at
.set at
    la  $k0, chunkIH
    sw  $a0, 0($k0)
    sw  $a1, 4($k0)
    sw  $t1, 8($k0)
    sw  $t2, 12($k0)
    sw  $t3, 16($k0)
    sw  $t4, 20($k0)
    sw  $t5, 24($k0)
    sw  $t6, 28($k0)
    sw  $t7, 32($k0)
    sw  $t9, 36($k0)
    sw  $v0, 40($k0)

    mfc0 $k0, $13
    srl $a0, $k0, 2
    and $a0, $a0, 0xf
    bne $a0, 0, non_intrpt


interrupt_dispatch:
    mfc0 $k0, $13           #Get cause register
    beq $k0, $zero, done    #by storing to a global variable

    and $a0, $k0, 0x1000
    bne $a0, 0, bonk_interrupt   #hit an edge

    and $a0, $k0, 0x400
    bne $a0, 0, fire_interrupt   #this girl is on FIRE

    and $a0, $k0, 0x2000
    bne $a0, 0, max_interrupt      #little spimmy is a grower, not really a shower

    and $a0, $k0, 0x8000
    bne $a0, 0, timer_interrupt  #the final episode (interrupt based on time)

    and $a0, $k0, 0x800
    bne $a0, 0, puzzle_interrupt

    li $v0, 4                       #unhandled interrupt types
    la $a0, unhandled_str
    syscall
    j done

non_intrpt:
    li $v0, 4
    la $a0, non_intrpt_str
    syscall                         #print out error message
    j done

#####================================#####
#                   FIN
#####================================#####

done:
    la $k0, chunkIH
    lw  $a0, 0($k0)
    lw  $a1, 4($k0)
    lw  $t1, 8($k0)
    lw  $t2, 12($k0)
    lw  $t3, 16($k0)
    lw  $t4, 20($k0)
    lw  $t5, 24($k0)
    lw  $t6, 28($k0)
    lw  $t7, 32($k0)
    lw  $t9, 36($k0)
    lw  $v0, 40($k0)

.set noat
    move $at, $k1
.set at
    eret






#####================================#####
#            On Fire Interrupt
#####================================#####

#Mostly from lab 10.2
#Simple linear movement

fire_interrupt:
  sw $a1, ON_FIRE_ACK($0)       #acknowledge fire interrupt
  lw $t3, GET_FIRE_LOC($0)         #$t3 = fire location

  j fire_move_x

fire_move_x:                    #manages x movements
  lw $a0, BOT_X
  srl $t0, $t3, 16               #getting the fire's x (with respect to 10x10)
  li $t1, 30                     #$t1 = x-size of each block
  div $a0, $t1                    #converting bot's x to 10x10 system
  mflo $t1
  beq $t0, $t1, fire_move_y       #in the right spot, move on to y
  blt $t1, $t0, fire_move_pos_x   #needs to move more in the positive x
  bgt $t1, $t0, fire_move_neg_x   #needs to move in the negative x
  j fire_move_y

fire_move_pos_x:                #moves in the positive x
  sw $0, ANGLE($0)                  #move at 0 degrees (pos x)
  li $a0, 1
  sw $a0, ANGLE_CONTROL($0)         #set to absolute ANGLE_CONTROL
  li $a0, 10
  sw $a0, VELOCITY($0)
  j fire_move_x

fire_move_neg_x:                #moves in the negative x
  li $a0, 180
  sw $a0, ANGLE($0)
  li $a0, 1
  sw $a0, ANGLE_CONTROL($0)
  li $a0, 10
  sw $a0, VELOCITY($0)
  j fire_move_x

fire_move_y:                    #manages y movements
  lw $a0, BOT_Y($0)
  and $t0, $t3, 0x0000ffff
  li $t1, 30
  div $a0, $t1
  mflo $t1
  beq $t0, $t1, fire_put_out
  blt $t1, $t0, fire_move_pos_y
  bgt $t1, $t0, fire_move_neg_y
  j put_out

fire_move_pos_y:                #moves in the positive y
  li $a0, 90
  sw $a0, ANGLE($0)
  li $a0, 1
  sw $a0, ANGLE_CONTROL($0)
  li $a0, 10
  sw $a0, VELOCITY($0)
  j fire_move_y

fire_move_neg_y:                #moves in the negative y
  li $a0, 270
  sw $a0, ANGLE($0)
  li $a0, 1
  sw $a0, ANGLE_CONTROL($0)
  li $a0, 10
  sw $a0, VELOCITY($0)
  j fire_move_y

fire_put_out:                   #puts out the fire
  sw $0, PUT_OUT_FIRE($0)
  j interrupt_dispatch


#End fire interrupt

#####================================#####
#            Harveset Interrupt
#####================================#####

#Copied movement from fire interrupt
#Also does x and y sequentially, want to figure out floating points so can get accurate arctan

max_interrupt:
  sw $a0, MAX_GROWTH_ACK($0)
  lw $t3, MAX_GROWTH_TILE($0)

  j harvest_move_x

harvest_move_x:                    #manages x movements
  lw $a0, BOT_X($0)
  srl $t0, $t3, 16               #getting the harvest's x (with respect to 10x10)
  li $t1, 30                     #$t1 = x-size of each block
  div $a0, $t1                    #converting bot's x to 10x10 system
  mflo $t1
  beq $t0, $t1, harvest_move_y       #in the right spot, move on to y
  blt $t1, $t0, harvest_move_pos_x   #needs to move more in the positive x
  bgt $t1, $t0, harvest_move_neg_x   #needs to move in the negative x
  j harvest_move_y

harvest_move_pos_x:                #moves in the positive x
  sw $0, ANGLE($0)                  #move at 0 degrees (pos x)
  li $a0, 1
  sw $a0, ANGLE_CONTROL($0)         #set to absolute ANGLE_CONTROL
  li $a0, 10
  sw $a0, VELOCITY($0)
  j harvest_move_x

harvest_move_neg_x:                #moves in the negative x
  li $a0, 180
  sw $a0, ANGLE($0)
  li $a0, 1
  sw $a0, ANGLE_CONTROL($0)
  li $a0, 10
  sw $a0, VELOCITY($0)	
  j harvest_move_x

harvest_move_y:                    #manages y movements
  lw $a0, BOT_Y($0)
  and $t0, $t3, 0x0000ffff
  li $t1, 30
  div $a0, $t1
  mflo $t1
  beq $t0, $t1, harvest_tile
  blt $t1, $t0, harvest_move_pos_y
  bgt $t1, $t0, harvest_move_neg_y
  j harvest_tile

harvest_move_pos_y:                #moves in the positive y
  li $a0, 90
  sw $a0, ANGLE($0)
  li $a0, 1
  sw $a0, ANGLE_CONTROL($0)
  li $a0, 10
  sw $a0, VELOCITY($0)
  sw $0, HARVEST_TILE($0)
  j harvest_move_y

harvest_move_neg_y:                #moves in the negative y
  li $a0, 270
  sw $a0, ANGLE($0)
  li $a0, 1
  sw $a0, ANGLE_CONTROL($0)
  li $a0, 10
  sw $a0, VELOCITY($0)
  sw $0, HARVEST_TILE($0)
  j harvest_move_y

harvest_tile:                   #puts out the fire
  sw $0, HARVEST_TILE($0)
  lw $t9, GET_NUM_WATER_DROPS
  sw $t9, PRINT_INT_ADDR
  li  $t0, 0  	            #ELSE get seeds
  sw  $t0, SET_RESOURCE_TYPE($0)
  la  $t0, puzzleChunk
  sw  $t0, REQUEST_PUZZLE($0)
  j interrupt_dispatch

#Finish harvest interrupt



#####================================#####
#            Bonk Interrupt
#####================================#####

bonk_interrupt:
  sw $a0, BONK_ACK($0)                  #turns the bot 90degrees to its right
  li $t0, 90
  sw $t0, ANGLE($0)
  sw $0, ANGLE_CONTROL($0)
  li  $t0, 1    	            #ELSE get seeds
  sw  $t0, SET_RESOURCE_TYPE($0)
  la  $t0, puzzleChunk
  sw  $t0, REQUEST_PUZZLE($0)

  j interrupt_dispatch

#Finish Bonk Interrupt


#####================================#####
#            Timer Interrupt
#####================================#####

timer_interrupt:
  sw $a0, TIMER_ACK($0)
  sw $0, SET_RESOURCE_TYPE($0)
  la $t0, puzzleChunk
  sw $t0, REQUEST_PUZZLE($0)
  lw $t0, TIMER($0)
  add $t0, $t0, 500000
  sw $t0, TIMER($0)
  j interrupt_dispatch



#####================================#####
#            Puzzle Interrupt
#####================================#####

puzzle_interrupt:
  la  $a1, puzzleChunk
  la  $a0, solutionChunk
  jal start_puzzle
  #jal recursive_backtracking
  sw $a0, REQUEST_PUZZLE_ACK($0)
  la $t0, solutionChunk
  sw $t0, SUBMIT_SOLUTION($zero)
  j interrupt_dispatch






#####================================#####
#             Puzzle Solver
#####================================#####

# NOTE:  Remember to specify which before calling
# 0 for water, 1 for seeds, 2 for fire starters:

# li $t0, 0
# sw $t0, SET_RESOURCE_TYPE
# la $t0, puzzleChunk
# sw $t0, REQUEST_PUZZLE
# jal recursive_backtracking
# make sure to not overwrite existing t0 values

# NOTE: The Solution is automatically submitted at the end of the puzzles solver.



.globl convert_highest_bit_to_int
.globl convert_highest_bit_to_int
convert_highest_bit_to_int:
    move  $v0, $0   	      # result = 0

chbti_loop:
    beq   $a0, $0, chbti_end
    add   $v0, $v0, 1         # result ++
    sra   $a0, $a0, 1         # domain >>= 1
    j     chbti_loop

chbti_end:
    jr	  $ra


.globl get_domain_for_addition
get_domain_for_addition:
    sub    $sp, $sp, 20
    sw     $ra, 0($sp)
    sw     $s0, 4($sp)
    sw     $s1, 8($sp)
    sw     $s2, 12($sp)
    sw     $s3, 16($sp)
    move   $s0, $a0                     # s0 = target
    move   $s1, $a1                     # s1 = num_cell
    move   $s2, $a2                     # s2 = domain

    move   $a0, $a2
    jal    convert_highest_bit_to_int
    move   $s3, $v0                     # s3 = upper_bound

    sub    $a0, $0, $s2	                # -domain
    and    $a0, $a0, $s2                # domain & (-domain)
    jal    convert_highest_bit_to_int   # v0 = lower_bound
	   
    sub    $t0, $s1, 1                  # num_cell - 1
    mul    $t0, $t0, $v0                # (num_cell - 1) * lower_bound
    sub    $t0, $s0, $t0                # t0 = high_bits
    bge    $t0, 0, gdfa_skip0

    li     $t0, 0

gdfa_skip0:
    bge    $t0, $s3, gdfa_skip1

    li     $t1, 1          
    sll    $t0, $t1, $t0                # 1 << high_bits
    sub    $t0, $t0, 1                  # (1 << high_bits) - 1
    and    $s2, $s2, $t0                # domain & ((1 << high_bits) - 1)

gdfa_skip1:	   
    sub    $t0, $s1, 1                  # num_cell - 1
    mul    $t0, $t0, $s3                # (num_cell - 1) * upper_bound
    sub    $t0, $s0, $t0                # t0 = low_bits
    ble    $t0, $0, gdfa_skip2

   sub    $t0, $t0, 1                  # low_bits - 1
    sra    $s2, $s2, $t0                # domain >> (low_bits - 1)
    sll    $s2, $s2, $t0                # domain >> (low_bits - 1) << (low_bits - 1)

gdfa_skip2:	   
    move   $v0, $s2                     # return domain
    lw     $ra, 0($sp)
    lw     $s0, 4($sp)
    lw     $s1, 8($sp)
    lw     $s2, 12($sp)
    lw     $s3, 16($sp)
    add    $sp, $sp, 20
    jr     $ra


.globl get_domain_for_subtraction
get_domain_for_subtraction:
    li     $t0, 1              
    li     $t1, 2
    mul    $t1, $t1, $a0            # target * 2
    sll    $t1, $t0, $t1            # 1 << (target * 2)
    or     $t0, $t0, $t1            # t0 = base_mask
    li     $t1, 0                   # t1 = mask

gdfs_loop:
    beq    $a2, $0, gdfs_loop_end	
    and    $t2, $a2, 1              # other_domain & 1
    beq    $t2, $0, gdfs_if_end
	   
    sra    $t2, $t0, $a0            # base_mask >> target
    or     $t1, $t1, $t2            # mask |= (base_mask >> target)

gdfs_if_end:
    sll    $t0, $t0, 1              # base_mask <<= 1
    sra    $a2, $a2, 1              # other_domain >>= 1
    j      gdfs_loop

gdfs_loop_end:
    and    $v0, $a1, $t1            # domain & mask
    jr	   $ra

	
.globl is_single_value_domain
is_single_value_domain:
    beq    $a0, $0, isvd_zero     # return 0 if domain == 0
    sub    $t0, $a0, 1	          # (domain - 1)
    and    $t0, $t0, $a0          # (domain & (domain - 1))
    bne    $t0, $0, isvd_zero     # return 0 if (domain & (domain - 1)) != 0
    li     $v0, 1
    jr	   $ra

isvd_zero:	   
    li	   $v0, 0
    jr	   $ra

.globl forward_checking
forward_checking:
  sub   $sp, $sp, 24
  sw    $ra, 0($sp)
  sw    $a0, 4($sp)
  sw    $a1, 8($sp)
  sw    $s0, 12($sp)
  sw    $s1, 16($sp)
  sw    $s2, 20($sp)
  lw    $t0, 0($a1)     # size
  li    $t1, 0          # col = 0
fc_for_col:
  bge   $t1, $t0, fc_end_for_col  # col < size
  div   $a0, $t0
  mfhi  $t2             # position % size
  mflo  $t3             # position / size
  beq   $t1, $t2, fc_for_col_continue    # if (col != position % size)
  mul   $t4, $t3, $t0
  add   $t4, $t4, $t1   # position / size * size + col
  mul   $t4, $t4, 8
  lw    $t5, 4($a1) # puzzle->grid
  add   $t4, $t4, $t5   # &puzzle->grid[position / size * size + col].domain
  mul   $t2, $a0, 8   # position * 8
  add   $t2, $t5, $t2 # puzzle->grid[position]
  lw    $t2, 0($t2) # puzzle -> grid[position].domain
  not   $t2, $t2        # ~puzzle->grid[position].domain
  lw    $t3, 0($t4) #
  and   $t3, $t3, $t2
  sw    $t3, 0($t4)
  beq   $t3, $0, fc_return_zero # if (!puzzle->grid[position / size * size + col].domain)
fc_for_col_continue:
  add   $t1, $t1, 1     # col++
  j     fc_for_col
fc_end_for_col:
  li    $t1, 0          # row = 0
fc_for_row:
  bge   $t1, $t0, fc_end_for_row  # row < size
  div   $a0, $t0
  mflo  $t2             # position / size
  mfhi  $t3             # position % size
  beq   $t1, $t2, fc_for_row_continue
  lw    $t2, 4($a1)     # puzzle->grid
  mul   $t4, $t1, $t0
  add   $t4, $t4, $t3
  mul   $t4, $t4, 8
  add   $t4, $t2, $t4   # &puzzle->grid[row * size + position % size]
  lw    $t6, 0($t4)
  mul   $t5, $a0, 8
  add   $t5, $t2, $t5
  lw    $t5, 0($t5)     # puzzle->grid[position].domain
  not   $t5, $t5
  and   $t5, $t6, $t5
  sw    $t5, 0($t4)
  beq   $t5, $0, fc_return_zero
fc_for_row_continue:
  add   $t1, $t1, 1     # row++
  j     fc_for_row
fc_end_for_row:

  li    $s0, 0          # i = 0
fc_for_i:
  lw    $t2, 4($a1)
  mul   $t3, $a0, 8
  add   $t2, $t2, $t3
  lw    $t2, 4($t2)     # &puzzle->grid[position].cage
  lw    $t3, 8($t2)     # puzzle->grid[position].cage->num_cell
  bge   $s0, $t3, fc_return_one
  lw    $t3, 12($t2)    # puzzle->grid[position].cage->positions
  mul   $s1, $s0, 4
  add   $t3, $t3, $s1
  lw    $t3, 0($t3)     # pos
  lw    $s1, 4($a1)
  mul   $s2, $t3, 8
  add   $s2, $s1, $s2   # &puzzle->grid[pos].domain
  lw    $s1, 0($s2)
  move  $a0, $t3
  jal get_domain_for_cell
  lw    $a0, 4($sp)
  lw    $a1, 8($sp)
  and   $s1, $s1, $v0
  sw    $s1, 0($s2)     # puzzle->grid[pos].domain &= get_domain_for_cell(pos, puzzle)
  beq   $s1, $0, fc_return_zero
fc_for_i_continue:
  add   $s0, $s0, 1     # i++
  j     fc_for_i
fc_return_one:
  li    $v0, 1
  j     fc_return
fc_return_zero:
  li    $v0, 0
fc_return:
  lw    $ra, 0($sp)
  lw    $a0, 4($sp)
  lw    $a1, 8($sp)
  lw    $s0, 12($sp)
  lw    $s1, 16($sp)
  lw    $s2, 20($sp)
  add   $sp, $sp, 24
  jr    $ra


.globl get_unassigned_position
get_unassigned_position:
  li    $v0, 0            # unassigned_pos = 0
  lw    $t0, 0($a1)       # puzzle->size
  mul  $t0, $t0, $t0     # puzzle->size * puzzle->size
  add   $t1, $a0, 4       # &solution->assignment[0]
get_unassigned_position_for_begin:
  bge   $v0, $t0, get_unassigned_position_return  # if (unassigned_pos < puzzle->size * puzzle->size)
  mul  $t2, $v0, 4
  add   $t2, $t1, $t2     # &solution->assignment[unassigned_pos]
  lw    $t2, 0($t2)       # solution->assignment[unassigned_pos]
  beq   $t2, 0, get_unassigned_position_return  # if (solution->assignment[unassigned_pos] == 0)
  add   $v0, $v0, 1       # unassigned_pos++
  j   get_unassigned_position_for_begin
get_unassigned_position_return:
  jr    $ra


.globl is_complete
is_complete:
  lw    $t0, 0($a0)       # solution->size
  lw    $t1, 0($a1)       # puzzle->size
  mul   $t1, $t1, $t1     # puzzle->size * puzzle->size
  move	$v0, $0
  seq   $v0, $t0, $t1
  j     $ra
	
 .globl start_puzzle
 start_puzzle:

  la $a0, solutionChunk                              # ZERO OUT SOLUTION STRUCT:
  la $a1, puzzleChunk
  sw $0, 0($a0)          # zero out solution->size
  li $t9, 0
  still_has_assignments:
    addi $a0, 4          # increment the assignment struct
    addi $t9, 4
    bge $t9, 324, done_zeroing
    sw $0, 0($a0)
    j still_has_assignments
  done_zeroing:                                      # DONE ZEROING OUT SOLN
    la $a0, solutionChunk
.globl recursive_backtracking
recursive_backtracking:
  sub   $sp, $sp, 680
  sw    $ra, 0($sp)
  sw    $a0, 4($sp)     # solution
  sw    $a1, 8($sp)     # puzzle
  sw    $s0, 12($sp)    # position
  sw    $s1, 16($sp)    # val
  sw    $s2, 20($sp)    # 0x1 << (val - 1)
                        # sizeof(Puzzle) = 8
                        # sizeof(Cell [81]) = 648

  jal   is_complete
  bne   $v0, $0, recursive_backtracking_return_one
  lw    $a0, 4($sp)     # solution
  lw    $a1, 8($sp)     # puzzle
  jal   get_unassigned_position
  move  $s0, $v0        # position
  li    $s1, 1          # val = 1
recursive_backtracking_for_loop:
  lw    $a0, 4($sp)     # solution
  lw    $a1, 8($sp)     # puzzle
  lw    $t0, 0($a1)     # puzzle->size
  add   $t1, $t0, 1     # puzzle->size + 1
  bge   $s1, $t1, recursive_backtracking_return_zero  # val < puzzle->size + 1
  lw    $t1, 4($a1)     # puzzle->grid
  mul   $t4, $s0, 8     # sizeof(Cell) = 8
  add   $t1, $t1, $t4   # &puzzle->grid[position]
  lw    $t1, 0($t1)     # puzzle->grid[position].domain
  sub   $t4, $s1, 1     # val - 1
  li    $t5, 1
  sll   $s2, $t5, $t4   # 0x1 << (val - 1)
  and   $t1, $t1, $s2   # puzzle->grid[position].domain & (0x1 << (val - 1))
  beq   $t1, $0, recursive_backtracking_for_loop_continue # if (domain & (0x1 << (val - 1)))
  mul   $t0, $s0, 4     # position * 4
  add   $t0, $t0, $a0
  add   $t0, $t0, 4     # &solution->assignment[position]
  sw    $s1, 0($t0)     # solution->assignment[position] = val
  lw    $t0, 0($a0)     # solution->size
  add   $t0, $t0, 1
  sw    $t0, 0($a0)     # solution->size++
  add   $t0, $sp, 32    # &grid_copy
  sw    $t0, 28($sp)    # puzzle_copy.grid = grid_copy !!!
  move  $a0, $a1        # &puzzle
  add   $a1, $sp, 24    # &puzzle_copy
  jal   clone           # clone(puzzle, &puzzle_copy)
  mul   $t0, $s0, 8     # !!! grid size 8
  lw    $t1, 28($sp)
  
  add   $t1, $t1, $t0   # &puzzle_copy.grid[position]
  sw    $s2, 0($t1)     # puzzle_copy.grid[position].domain = 0x1 << (val - 1);
  move  $a0, $s0
  add   $a1, $sp, 24
  jal   forward_checking  # forward_checking(position, &puzzle_copy)
  beq   $v0, $0, recursive_backtracking_skip

  lw    $a0, 4($sp)     # solution
  add   $a1, $sp, 24    # &puzzle_copy
  jal   recursive_backtracking
  beq   $v0, $0, recursive_backtracking_skip
  j     recursive_backtracking_return_one # if (recursive_backtracking(solution, &puzzle_copy))
recursive_backtracking_skip:
  lw    $a0, 4($sp)     # solution
  mul   $t0, $s0, 4
  add   $t1, $a0, 4
  add   $t1, $t1, $t0
  sw    $0, 0($t1)      # solution->assignment[position] = 0
  lw    $t0, 0($a0)
  sub   $t0, $t0, 1
  sw    $t0, 0($a0)     # solution->size -= 1
recursive_backtracking_for_loop_continue:
  add   $s1, $s1, 1     # val++
  j     recursive_backtracking_for_loop
recursive_backtracking_return_zero:
  li    $v0, 0
  j     recursive_backtracking_return
recursive_backtracking_return_one:
  li    $v0, 1
recursive_backtracking_return:
  lw    $ra, 0($sp)
  lw    $a0, 4($sp)
  lw    $a1, 8($sp)
  lw    $s0, 12($sp)
  lw    $s1, 16($sp)
  lw    $s2, 20($sp)
  add   $sp, $sp, 680
 
  jr    $ra


# END OF PUZZLE SOLVER

.globl clone
clone:

    lw  $t0, 0($a0)
    sw  $t0, 0($a1)

    mul $t0, $t0, $t0
    mul $t0, $t0, 2 # two words in one grid

    lw  $t1, 4($a0) # &puzzle(ori).grid
    lw  $t2, 4($a1) # &puzzle(clone).grid

    li  $t3, 0 # i = 0;
clone_for_loop:
    bge  $t3, $t0, clone_for_loop_end
    sll $t4, $t3, 2 # i * 4
    add $t5, $t1, $t4 # puzzle(ori).grid ith word
    lw   $t6, 0($t5)

    add $t5, $t2, $t4 # puzzle(clone).grid ith word
    sw   $t6, 0($t5)

    addi $t3, $t3, 1 # i++

    j    clone_for_loop
clone_for_loop_end:

    jr  $ra

.globl get_domain_for_cell
get_domain_for_cell:
    # save registers
    sub $sp, $sp, 36
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp)
    sw $s5, 24($sp)
    sw $s6, 28($sp)
    sw $s7, 32($sp)

    li $t0, 0 # valid_domain
    lw $t1, 4($a1) # puzzle->grid (t1 free)
    sll $t2, $a0, 3 # position*8 (actual offset) (t2 free)
    add $t3, $t1, $t2 # &puzzle->grid[position]
    lw  $t4, 4($t3) # &puzzle->grid[position].cage
    lw  $t5, 0($t4) # puzzle->grid[posiition].cage->operation

    lw $t2, 4($t4) # puzzle->grid[position].cage->target

    move $s0, $t2   # remain_target = $s0  *!*!
    lw $s1, 8($t4) # remain_cell = $s1 = puzzle->grid[position].cage->num_cell
    lw $s2, 0($t3) # domain_union = $s2 = puzzle->grid[position].domain
    move $s3, $t4 # puzzle->grid[position].cage
    li $s4, 0   # i = 0
    move $s5, $t1 # $s5 = puzzle->grid
    move $s6, $a0 # $s6 = position
    # move $s7, $s2 # $s7 = puzzle->grid[position].domain

    bne $t5, 0, gdfc_check_else_if

    li $t1, 1
    sub $t2, $t2, $t1 # (puzzle->grid[position].cage->target-1)
    sll $v0, $t1, $t2 # valid_domain = 0x1 << (prev line comment)
    j gdfc_end # somewhere!!!!!!!!

gdfc_check_else_if:
    bne $t5, '+', gdfc_check_else

gdfc_else_if_loop:
    lw $t5, 8($s3) # puzzle->grid[position].cage->num_cell
    bge $s4, $t5, gdfc_for_end # branch if i >= puzzle->grid[position].cage->num_cell
    sll $t1, $s4, 2 # i*4
    lw $t6, 12($s3) # puzzle->grid[position].cage->positions
    add $t1, $t6, $t1 # &puzzle->grid[position].cage->positions[i]
    lw $t1, 0($t1) # pos = puzzle->grid[position].cage->positions[i]
    add $s4, $s4, 1 # i++

    sll $t2, $t1, 3 # pos * 8
    add $s7, $s5, $t2 # &puzzle->grid[pos]
    lw  $s7, 0($s7) # puzzle->grid[pos].domain

    beq $t1, $s6 gdfc_else_if_else # branch if pos == position



    move $a0, $s7 # $a0 = puzzle->grid[pos].domain
    jal is_single_value_domain
    bne $v0, 1 gdfc_else_if_else # branch if !is_single_value_domain()
    move $a0, $s7
    jal convert_highest_bit_to_int
    sub $s0, $s0, $v0 # remain_target -= convert_highest_bit_to_int
    addi $s1, $s1, -1 # remain_cell -= 1
    j gdfc_else_if_loop
gdfc_else_if_else:
    or $s2, $s2, $s7 # domain_union |= puzzle->grid[pos].domain
    j gdfc_else_if_loop

gdfc_for_end:
    move $a0, $s0
    move $a1, $s1
    move $a2, $s2
    jal get_domain_for_addition # $v0 = valid_domain = get_domain_for_addition()
    j gdfc_end

gdfc_check_else:
    lw $t3, 12($s3) # puzzle->grid[position].cage->positions
    lw $t0, 0($t3) # puzzle->grid[position].cage->positions[0]
    lw $t1, 4($t3) # puzzle->grid[position].cage->positions[1]
    xor $t0, $t0, $t1
    xor $t0, $t0, $s6 # other_pos = $t0 = $t0 ^ position
    lw $a0, 4($s3) # puzzle->grid[position].cage->target

    sll $t2, $s6, 3 # position * 8
    add $a1, $s5, $t2 # &puzzle->grid[position]
    lw  $a1, 0($a1) # puzzle->grid[position].domain
    # move $a1, $s7

    sll $t1, $t0, 3 # other_pos*8 (actual offset)
    add $t3, $s5, $t1 # &puzzle->grid[other_pos]
    lw $a2, 0($t3)  # puzzle->grid[other_pos].domian

    jal get_domain_for_subtraction # $v0 = valid_domain = get_domain_for_subtraction()
    # j gdfc_end
gdfc_end:
# restore registers

    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    lw $s5, 24($sp)
    lw $s6, 28($sp)
    lw $s7, 32($sp)
    add $sp, $sp, 36
    jr $ra
