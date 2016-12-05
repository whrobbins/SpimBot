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
align 2

chunkIH:        .space 1600
puzzleChunk:    .space 4096
solutionChunk:  .space 328

#####================================#####
#                  Main
#####================================#####
.text
main:
    # go wild
    # the world is your oyster :)
    sw $0 , VELOCITY
    li $t4, 0x8000               # timer interrupt enable
    or $t4, $t4, 0x1000          # bonk interrupt enable
    or $t4, $t4, 0x400           # on fire interrupt enable
    or $t4, $t4, 0x2000          # max growth interrupt
    or $t4, $t4, 0x800           # request puzzle interrupt
    or $t4, $t4, 1
    mtc0 $t4, $12
    j    main

infinite:
    j infinite


#####================================#####
#           Interrupt Handler/Dispatcher
#####================================#####
.kdata
chunkIH:        .space 44
non_intrpt_str: .asciiz "Non-interrupt exception\n"
unhandled_str:  .asciiz "Unhandled interrut type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
        move    $k1, $at
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
    lw $t9, GET_FIRE_LOC


interrupt_dispatch:
    sw $0, VELOCITY         #Stop movement as interrupt may switch direction
    mfc0 $k0, $13           #Get cause register
    beq $k0, $zero, done    #by storing to a global variable
    
    and $a0, $0, 0x1000
    bne $a0, 0, bonk_interrupt   #hit an edge
    
    and $a0, $0, 0x400
    bne $a0, 0, fire_interrupt   #this girl is on FIRE
    
    and $a0, $0, 0x2000
    bne $a0, 0, max_interrupt
    
    and $a0, $0, 0x8000
    bne $a0, 0, timer_interrupt  #the final episode (interrupt based on time)
    
    and $a0, $0, 0x800
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
#            Start Movement
#####================================#####


loadPositionStart  
    lw      $t0, BOT_X          #t0 = Bot Xpos - StartXpos in units
    lw      $t1, BOT_Y          #t2 = Bot Ypos - StartYpos in units
    sub     $t0, $t0, 45
    sub     $t1, $t1, 45
    
sb_arctan:
    li    $v0, 0        # angle = 0;

    abs    $t0, $t0    # get absolute values
    abs    $t1, $t1
    ble    $t1, $t0, no_TURN_90      

    ## if (abs(y) > abs(x)) { rotate 90 degrees }
    move    $t0, $t1    # int temp = y;
    neg    $t1, $t0    # y = -x;      
    move    $t0, $t0    # x = temp;    
    li    $t3, 90        # angle = 90;  

no_TURN_90:
    bgez    $t0, pos_x     # skip if (x >= 0)

    ## if (x < 0) 
    add    $t3, $t3, 180    # angle += 180;

pos_x:
    mtc1    $t0, $f0
    mtc1    $t1, $f1
    cvt.s.w $f0, $f0    # convert from ints to floats
    cvt.s.w $f1, $f1
    
    div.s    $f0, $f1, $f0    # float v = (float) y / (float) x;

    mul.s    $f1, $f0, $f0    # v^^2
    mul.s    $f2, $f1, $f0    # v^^3
    l.s    $f3, three    # load 5.0
    div.s     $f3, $f2, $f3    # v^^3/3
    sub.s    $f6, $f0, $f3    # v - v^^3/3

    mul.s    $f4, $f1, $f2    # v^^5
    l.s    $f5, five    # load 3.0
    div.s     $f5, $f4, $f5    # v^^5/5
    add.s    $f6, $f6, $f5    # value = v - v^^3/3 + v^^5/5

    l.s    $f8, PI        # load PI
    div.s    $f6, $f6, $f8    # value / PI
    l.s    $f7, F180    # load 180.0
    mul.s    $f6, $f6, $f7    # 180.0 * value / PI

    cvt.w.s $f6, $f6    # convert "delta" back to integer
    mfc1    $t0, $f6
    add    $t3, $t3, $t0    # angle += delta

    li  $t2, 1
    sw  $t2, ANGLE_CONTROL  #ANGLE_CONTROL = ABSOLUTE
    sw  $t3, ANGLE          #Set ANGLE to arctan of y/x
    
moveToStart:
    li  $t2, 1
    sw  $t2, ANGLE_CONTROL  #ANGLE_CONTROL = ABSOLUTE
    li  $t2, 10
    sw  $t2, VELOCITY       #VELOCITY = MAX
    li  $t2, 30
    lw  $t4, BOT_Y
    div $t4, $t4, $t2
    mflo $t4                #t4 = Bot Ypos in grid
    li  $t2, 2
    beq $t2, 2, moveAlong   #Once hits 2nd row, it should be at the starting block
    j moveToStart           #TODO: Replace atStart with actual jump spot
    
    
moveAlong:                  #initial angle set from start position
    li  $t2, 1
    sw  $t2, ANGLE_CONTROL
    li  $t2, 0
    sw  $t2, ANGLE
continueMove:
    li  $t2, 10
    sw  $t2, VELOCITY
    lw  $t1, BOT_X
    li  $t2, 30
    div $t2, $t1, $t2
    mflo $t1                        #t2 = Bot Xpos in grid
    li  $t2, 9
    li  $t3, 2
    bgt $t1, $t2, turnAround        #Turn around when it passes square 9
    blt $t1, $t3, turnAround        #Turn around when it passes square 2
    j continueMove:
turnAround:
    #TODO: Add puzzle solving when it hits an edge
    li  $t2, 0
    sw  $t2, ANGLE_CONTROL
    li  $t2, 180
    sw  $t2, ANGLE
    lw  $t1, GET_NUM_SEEDS
    li  $t2, 10
    bge $t1, $t2, needWater         #IF bot => 10 seeds, get water
needSeeds:
    li  $t0, 1                      #ELSE get seeds
    sw  $t0, SET_RESOURCE_TYPE
    la  $t0, puzzleChunk
    sw  $t0, REQUEST_PUZZLE
    j continueMove
needWater:
    li  $t0, 0
    sw  $t0, SET_RESOURCE_TYPE
    la  $t0, puzzleChunk
    sw  $t0, REQUEST_PUZZLE
    j continueMove
    
#####================================#####
#             Puzzle Solver
#####================================#####    

# NOTE:  Remember to specify which before calling
# 0 for water, 1 for seeds, 2 for fire starters:

# li $t0, 0
# sw $t0, SET_RESOURCE_TYPE
# la $t0, puzzleChunk
# sw $t0, REQUEST_PUZZLE

# NOTE:  The Submission is automatically submitted at the end of the puzzles solver.



.globl convert_highest_bit_to_int
convert_highest_bit_to_int:
    move  $v0, $0             # result = 0
chbti_loop:
    beq   $a0, $0, chbti_end
    add   $v0, $v0, 1         # result ++
    sra   $a0, $a0, 1         # domain >>= 1
    j     chbti_loop
chbti_end:
    jr      $ra

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
    sub    $a0, $0, $s2                    # -domain
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
    jr       $ra
    
.globl is_single_value_domain
is_single_value_domain:
    beq    $a0, $0, isvd_zero     # return 0 if domain == 0
    sub    $t0, $a0, 1              # (domain - 1)
    and    $t0, $t0, $a0          # (domain & (domain - 1))
    bne    $t0, $0, isvd_zero     # return 0 if (domain & (domain - 1)) != 0
    li     $v0, 1
    jr       $ra
isvd_zero:       
    li       $v0, 0
    jr       $ra

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
  move    $v0, $0
  seq   $v0, $t0, $t1
  j     $ra
  
  
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
                        
# ZERO OUT SOLUTION STRUCT:

  la $t0, solutionChunk
  sw $0, 0($t0)          # zero out solution->size
  still_has_assignments:
    addi $t0, 4          # increment the assignment struct
    bge $t0, 324, done_zeroing
    sw $0, 0($t0)
    j still_has_assignments
  done_zeroing:


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
  # ADDING CODE TO SUBMIT SOLUTION:
  la $t0, solutionChunk
  la $t1, SUBMIT_SOLUTION
  sw $t0, 0($t1)
 
  jr    $ra

    
# END OF PUZZLE SOLVER


    
#####================================#####
#            On Fire Interrupt
#####================================#####

#Mostly from lab 10.2

fire_interrupt:
  sw $a1, 0xffff0050($0)        #acknowledge fire interrupt
  lw $t3, GET_FIRE_LOC          #$t3 = fire location

  j fire_move_x

fire_move_x:                    #manages x movements
  lw $a0, BOT_X
  srl $t0, $t3, 16               #getting the fire's x (with respect to 10x10)
  li $t1, 30                     #$t1 = x-size of each block
  div $a0, $t1                    #converting bot's x to 10x10 system
  mflo $t1
  beq $t0, $t1, fire_move_y       #in the right spot, move on to y
  blt $t1, $t0, fire_move_pos_x   #needs to move more in the positive x
  bgt $t1, $t0, fire_move_neg_x
  j fire_move_y

fire_move_pos_x:                #moves in the positive x
  sw $0, ANGLE
  li $a0, 1
  sw $a0, ANGLE_CONTROL
  li $a0, 10
  sw $a0, VELOCITY
  j move_x

fire_move_neg_x:                #moves in the negative x
  li $a0, 180
  sw $a0, ANGLE
  li $a0, 1
  sw $a0, ANGLE_CONTROL
  li $a0, 10
  sw $a0, VELOCITY
  j fire_move_x

fire_move_y:                    #manages y movements
  lw $a0, BOT_Y
  and $t0, $t3, 0x0000ffff
  li $t1, 30
  div $a0, $t1
  mflo $t1
  beq $t0, $t1, put_out
  blt $t1, $t0, move_pos_y
  bgt $t1, $t0, move_neg_y
  j put_out

fire_move_pos_y:                #moves in the positive y
  li $a0, 90
  sw $a0, ANGLE
  li $a0, 1
  sw $a0, ANGLE_CONTROL
  li $a0, 10
  sw $a0, VELOCITY
  j fire_move_y

fire_move_neg_y:                #moves in the negative y
  li $a0, 270
  sw $a0, ANGLE
  li $a0, 1
  sw $a0, ANGLE_CONTROL
  li $a0, 10
  sw $a0, VELOCITY
  j fire_move_y

fire_put_out:                   #puts out the fire
  sw $0, PUT_OUT_FIRE
  j interrupt_dispatch




#####================================#####
#            Harveset Interrupt
#####================================#####



















