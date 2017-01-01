        .data
stack_beg:
        .word   0 : 80
stack_end:
filename: .asciiz "C:/Users/J.Appallonia/Desktop/ball.jpg"
endgameWin: .asciiz "C:/Users/J.Appallonia/Desktop/panda.jpg"
endgamePanda: .asciiz "C:/Users/J.Appallonia/Desktop/image.bmp"
bricksLeft: .word 128
p_xLoc: .word 256
p_MoveLeft: .word 0		# count for moves left
p_MoveRight: .word 0		# count for moves right
p_Release: .word 0		# boolean for release
b_onPaddle: .word 1		# boolean for whether ball is on paddle. If p_Release == b_onPaddle then call releaseBall
b_loc_x: .word 248
b_loc_y: .word 0
b_velocity_x: .word 0
b_velocity_y: .word 0
restart_pressed: .word 0
win_text: .asciiz "You won! Enjoy you're reward :)"
lose_text: .asciiz "You lost. The Panda is sad."
level: .word 0
max_level: .word 1
        .text
        
main:
	# Enable interrupts in status register
	mfc0    $t0, $12

	# Disable all interrupt levels
	lw      $t1, EXC_INT_ALL_MASK
	not     $t1, $t1
	and     $t0, $t0, $t1
	
	# Enable console interrupt levels
	lw      $t1, EXC_INT3_MASK
	or      $t0, $t0, $t1
	#lw      $t1, EXC_INT4_MASK
	#or      $t0, $t0, $t1

	# Enable exceptions globally
	lw      $t1, EXC_ENABLE_MASK
	or      $t0, $t0, $t1

	mtc0    $t0, $12
	
	# Enable keyboard interrupts
	li      $t0, 0xffff0000     # Receiver control register
	li      $t1, 0x00000002     # Interrupt enable bit
	sw      $t1, ($t0)
	
	la $sp, stack_end
	
	sw $0, level
	
start: # initialize stuffs
        li $t0, 64
        sw $t0, bricksLeft
        sw $0, b_velocity_x
        sw $0, b_velocity_y
        
	la $a0, filename
        li $v0, 60
	syscall
        
        jal ClearDisplay
        jal drawMap
        li $t0, 256
        sw $t0, p_xLoc
        jal drawPaddle
        
updateLoop: # loop until win or lose
	jal checkInput
	jal moveBall
	# lose in $v0, 0 if none, 1 is lose (aka fell off screen)
	beq $v0, 1, lose
	
	jal checkCollisions
	lw $t0, bricksLeft
	blez $t0, win
	
	j updateLoop
lose:
	la $a0,lose_text
	jal DisplayStr
	la $a0, endgamePanda
        li $v0, 60
	syscall
	j putEndPhoto

win:
	la $a0,win_text
	jal DisplayStr
	la $a0, endgameWin
        li $v0, 60
	syscall
	
	# increment level
	lw $t0, level
	addi $t0, $t0, 1
	lw $t1, max_level
	ble $t0, $t1, putEndPhoto
	# hit max level, stay on level
	move $t0, $t1
	j putEndPhoto
	
putEndPhoto:
	li $a0, 0
	li $a1, 0
	li $v0, 61
	syscall
	li $a0, 0
	li $a1, 256
	li $a2, 0
	jal DrawDot
	sw $0, restart_pressed
	
idle:
	lw $t0, restart_pressed
	bge $t0, 1, start
	li $a0, 100
	jal Pause
	j idle
	

################################################################################################
#  Procedure: DisplayStr                                                                       #
#  Displays a message to the user                                                              #
#  Input: $a0 points to the text string that will get displayed to the user                    #
################################################################################################
DisplayStr:
li   $v0, 4           # specify Print string service
syscall               # print the prompt char
jr $ra
	
################################################################################################
#  Procedure: Pause                                                                            #
#  Pauses for a set amount of time                                                             #
#  Input: $a0 time to pause                                                                    #
################################################################################################
Pause:
move $t6,$a0
li $v0, 30
syscall
move $t5,$a0
_display_time_loop:
syscall
subu $t4,$a0,$t5
bltu $t4,$t6,_display_time_loop
jr $ra
	
################################################################################################
#  Procedure: moveBall                                                                         #
#  Returns 1 in $v0 if ball fell off screen						       #
################################################################################################
moveBall:
lw $t0, b_onPaddle
bnez $t0, moveBall_done
addi $sp, $sp, -4
sw $ra, 0($sp)

lw $a0, b_loc_x
lw $t0, b_velocity_x
add $a0, $a0, $t0
blt $a0, 496, moveBall_notHitRightWall
li $a0, 496
moveBall_notHitRightWall:
bgtz $a0, moveBall_notHitLeftWall
li $a0, 0
moveBall_notHitLeftWall:
sw $a0, b_loc_x

lw $a1, b_loc_y
lw $t1, b_velocity_y
add $a1, $a1, $t1
bgtz $a1, moveBall_notHitTopWall
li $a1, 0
moveBall_notHitTopWall:
sw $a1, b_loc_y

li $v0, 61
syscall

ble $a1, 240, moveBall_notOffBttm
li $v0, 1
moveBall_notOffBttm:
addi $sp, $sp, -4
sw $v0, 0($sp)

li $a0, 0
li $a1, 256
li $a2, 0
jal DrawDot

li $a0, 20
jal Pause

lw $v0, 0($sp)
addi $sp, $sp, 4
lw $ra, 0($sp)
addi $sp, $sp, 4

moveBall_done:
jr $ra

################################################################################################
#  Procedure: checkCollisions                                                                  #
#  Checks if the ball has collided with anything and changes velocity accordingly	       #
################################################################################################
checkCollisions:
addi $sp, $sp, -4
sw $ra, 0($sp)

lw $t0, b_onPaddle
bnez $t0, checkCollisions_noCollision

lw $t0, b_loc_x
bgt $t0, 4, checkCollisions_notLeftWall
# hit wall
lw $t7, b_velocity_x
sub $t6, $0, $t7		# flip x velocity
sw $t6, b_velocity_x
checkCollisions_notLeftWall:
blt  $t0, 492, checkCollisions_notRightWall
# hit wall
lw $t7, b_velocity_x
sub $t6, $0, $t7		# flip x velocity
sw $t6, b_velocity_x
checkCollisions_notRightWall:

lw $t1, b_loc_y
bgtz $t1, checkCollisions_notTopWall
# hit top wall
lw $t7, b_velocity_y
sub $t6, $0, $t7		# flip y velocity
sw $t6, b_velocity_y
checkCollisions_notTopWall:

checkCollisions_checkPaddle:
ble $t1, 225, checkCollisions_notPaddle
lw $t2, p_xLoc
addi $t2, $t2, -32				# -16 for half of paddle plus 16 for size of ball?
ble $t0, $t2, checkCollisions_notPaddle
addi $t2, $t2, 48
bgt $t0, $t2, checkCollisions_notPaddle
# hit paddle
lw $t7, b_velocity_y
sub $t6, $0, $t7		# flip y velocity
sw $t6, b_velocity_y
# check which side
addi $t2, $t2, -32
bgt $t0, $t2, checkCollisions_notLeft
# hit left
lw $t7, b_velocity_x
addi $t7, $t7, -2			# adjust x velocity
sw $t7, b_velocity_x
checkCollisions_notLeft:
addi $t2, $t2, 16
ble $t0, $t2, checkCollisions_notRight		# shuffle past hit right side code
# hit right side of paddle
lw $t7, b_velocity_x
addi $t7, $t7, 2			# adjust x velocity
sw $t7, b_velocity_x
checkCollisions_notRight:
j checkCollisions_noCollision
checkCollisions_notPaddle:

# check for collision with brick
move $a0, $t0			# x pos
lw $a1, b_loc_y

# mid left side of ball
move $a0, $a0
addi $a1, $a1, 8
addi $sp, $sp, -8
sw $a0, 0($sp)
sw $a1, 4($sp)			
jal CalcAddr
lw $a0, 0($sp)
lw $a1, 4($sp)
addi $sp, $sp, 8
li $t2, 1
lw $t7, ($v0)
beq $t7, 0x000000, checkCollisions_1NotBlock
beq $t7, 0xFFFFFF, checkCollisions_1NotBlock
# if either, not black or white, must be block
jal brickCollisions
j checkCollisions_noCollision
checkCollisions_1NotBlock:

# top mid side of ball
addi $a0, $a0, 8
addi $a1, $a1, -8
addi $sp, $sp, -8
sw $a0, 0($sp)
sw $a1, 4($sp)
jal CalcAddr
lw $a0, 0($sp)
lw $a1, 4($sp)
addi $sp, $sp, 8
li $t2, 2
lw $t7, ($v0)
beq $t7, 0x000000, checkCollisions_2NotBlock
beq $t7, 0xFFFFFF, checkCollisions_2NotBlock
# if either, not black or white, must be block
jal brickCollisions
j checkCollisions_noCollision
checkCollisions_2NotBlock:

# mid right side of ball
addi $a0, $a0, 8
addi $a1, $a1, 8
addi $sp, $sp, -8
sw $a0, 0($sp)
sw $a1, 4($sp)			
jal CalcAddr
lw $a0, 0($sp)
lw $a1, 4($sp)
addi $sp, $sp, 8
li $t2, 3
lw $t7, ($v0)
beq $t7, 0x000000, checkCollisions_3NotBlock
beq $t7, 0xFFFFFF, checkCollisions_3NotBlock
# if either, not black or white, must be block
jal brickCollisions
j checkCollisions_noCollision
checkCollisions_3NotBlock:

# bottom mid side of ball
addi $a0, $a0, -8
addi $a1, $a1, 8
addi $sp, $sp, -8
sw $a0, 0($sp)
sw $a1, 4($sp)
jal CalcAddr
lw $a0, 0($sp)
lw $a1, 4($sp)
addi $sp, $sp, 8
li $t2, 4
lw $t7, ($v0)
beq $t7, 0x000000, checkCollisions_4NotBlock
beq $t7, 0xFFFFFF, checkCollisions_4NotBlock
# if either, not black or white, must be block
jal brickCollisions
j checkCollisions_noCollision
checkCollisions_4NotBlock:

# if it fell through all of these, there's no collision
checkCollisions_noCollision:
lw $ra, 0($sp)
addi $sp, $sp, 4
jr $ra

################################################################################################
#  Procedure: brickCollisions                                                                  #
#  Deals with a brick collisions	         					       #
#  Input: $a0 has x pos of collision							       #
#  Input: $a1 has y pos of collision							       #
################################################################################################
brickCollisions:
addi $sp, $sp, -4
sw $ra, 0($sp)

addi $sp, $sp, -8
sw $a0, 0($sp)
sw $a1, 4($sp)

bne $t2, 1, brickCollisions_notLeftSideBrick
lw $t7, b_velocity_x
sub $t6, $0, $t7		# flip x velocity
addi $t6, $t6, -1
sw $t6, b_velocity_x
li $t1, 1
brickCollisions_notLeftSideBrick:
bne $t2, 3, brickCollisions_notRightSideBrick
lw $t7, b_velocity_x
sub $t6, $0, $t7		# flip x velocity
addi $t6, $t6, 1
sw $t6, b_velocity_x
li $t1, 1
brickCollisions_notRightSideBrick:
bne $t1, 1, brickCollisions_notSideBrick
lw $t7, b_velocity_y
sub $t6, $0, $t7		# flip y velocity
sw $t6, b_velocity_y
jal brickCollisions_inMiddle
brickCollisions_notSideBrick:

# check if on the edge of the brick, send to notEdgeBrick
#a0 $& $a1 is collision pos
rem $t0, $a0, 32
ble $t0, 4, brickCollisions_leftEdgeBrick
j brickCollisions_notLeftEdgeBrick
brickCollisions_leftEdgeBrick:
# left edge hit
addi $a0, $a0, -16
li $t1, 1
brickCollisions_notLeftEdgeBrick:
bge $t0, 28, brickCollisions_rightEdgeBrick
j brickCollisions_edgeBrick
brickCollisions_rightEdgeBrick:
# right edge hit
addi $a0, $a0, 16
li $t1, 1
brickCollisions_edgeBrick:
bne $t1, 1, brickCollisions_notEdgeBrick
# $a1 is still y of collision spot
addi $sp, $sp, -8
sw $a0, 0($sp)
sw $a1, 4($sp)
jal CalcAddr
lw $a0, 0($sp)
lw $a1, 4($sp)
addi $sp, $sp, 8
#$vo is addr where neighbor brick might be
lw $t7, ($v0)
beq $t7, 0x000000, brickCollisions_notEdgeBrick
# a0 & a1 still have location of other brick in them
addi $sp, $sp, -4
sw $t0, 0($sp)
jal breakBrick
lw $t0, 0($sp)
addi $sp, $sp, 4
j brickCollisions_inMiddle	# skip over modifying x
brickCollisions_notEdgeBrick:

ble $t0, 12, brickCollisions_leftOffsetBrick
j brickCollisions_testRightOffsetBrick
brickCollisions_leftOffsetBrick:
lw $t7, b_velocity_x
addi $t7, $t7, -2			# adjust x velocity
sw $t7, b_velocity_x
brickCollisions_testRightOffsetBrick:
bge $t0, 20, brickCollisions_rightOffsetBrick
j brickCollisions_inMiddle
brickCollisions_rightOffsetBrick:
lw $t7, b_velocity_x
addi $t7, $t7, 2			# adjust x velocity
sw $t7, b_velocity_x

brickCollisions_inMiddle:
# restore original collision
lw $a0, 0($sp)
lw $a1, 4($sp)
addi $sp, $sp, 8
jal breakBrick

lw $t7, b_velocity_y
sub $t6, $0, $t7		# flip y velocity
sw $t6, b_velocity_y

lw $ra, 0($sp)
addi $sp, $sp, 4
jr $ra

################################################################################################
#  Procedure: breakBrick                                                                       #
#  Break a brick at x,y location and reduces number of bricks left to break		       #
#  Input: $a0 is x location								       #	
#  Input: $a1 is y location								       #
################################################################################################
breakBrick:
addi $sp, $sp, -4
sw $ra, 0($sp)

# reduces number of bricks
lw $t0, bricksLeft
addi $t0, $t0, -1
sw $t0, bricksLeft

rem $t0, $a0, 32	# get how far on the x axis the collision is from the block's origin
bne $a0, 32, breakBrick_notRemRight
# incase hit was on the farthest right corner of brick
li $t0, 32
breakBrick_notRemRight:
rem $t1, $a1, 16	# get how far on the y axis the collision is from the block's origin
bne $a1, 16, breakBrick_notRemBttm
# incase hit was on the bottom of the brick
li $t1, 16
breakBrick_notRemBttm:
sub $a0, $a0, $t0	# subtracts distance on x axis in order to get back to origin
sub $a1, $a1, $t1	# subtracts distance on y axis in order to get back to origin
li $a2, 0 		# $a2 is color number
li $a3, 16		# $a3 height of the box'
# top of stack is width of box
addi $sp, $sp, -4
li $t7, 32
sw $t7, 0($sp)
jal DrawBox
addi $sp, $sp, 4

lw $ra, 0($sp)
addi $sp, $sp, 4
jr $ra
	
################################################################################################
#  Procedure: checkInput                                                                       #
#  Checks input variables and calls functions accordingly				       #
################################################################################################
checkInput:
addi $sp,$sp,-4
sw $ra, ($sp)
	
lw $t0, p_MoveLeft
sub $a0, $0, $t0
jal movePaddle
lw $a0, p_MoveRight
jal movePaddle
sw $0, p_MoveLeft
sw $0, p_MoveRight
	
lw $t0, p_Release
lw $t1, b_onPaddle
# if both p_Release == b_onPaddle == 1, release ball
bne $t0, 1, input_notReleased
bne $t0, $t1, input_notReleased
sw $0, b_onPaddle
li $t0, -2
sw $t0, b_velocity_y
input_notReleased:
sw $zero, p_Release

lw $ra, ($sp)
addi $sp,$sp,4
jr $ra
	
################################################################################################
#  Procedure: movePaddle                                                                       #
#  Moves paddle left (-) or right (+)  			  				       #
#  Input: $a0 is amount to move								       #
################################################################################################
movePaddle:
addi $sp,$sp,-4
sw $ra, ($sp)

beqz $a0, movePaddle_doneLooping

lw $t0, p_xLoc
add $t1, $t0, $a0
sw $t1, p_xLoc

lw $t7, b_onPaddle
beqz $t7, movePaddle_dontMoveBall
# move ball with paddle
addi $sp, $sp, -4
sw $a0, 0($sp)
addi $a0, $t1, -8
li $a1, 224
li $v0, 61
syscall
sw $a0, b_loc_x
lw $a0, 0($sp)
addi $sp, $sp, 4
movePaddle_dontMoveBall:

bltz $a0, movePaddle_notRight
addi $t1, $t0, -17		# x loc to call black lines on
addi $t0, $t0, 15		# x loc to add to paddle at
li $t2, 1
movePaddle_notRight:
bgt $a0, $0, movePaddle_notLeft
addi $t1, $t0, 17		# x loc to call black lines on
addi $t0, $t0, -15		# x loc to add to paddle at
mul $a0, $a0, -1		# used as counter for loop
li $t2, -1
movePaddle_notLeft:

movePaddle_moveLoop:
add $t0, $t0, $t2
# stops if at walls
bge $t0, 496, movePaddle_doneLooping
ble $t0, 16, movePaddle_doneLooping

add $t1, $t1, $t2
addi $sp,$sp,-16
sw $t0, 0($sp)
sw $t1, 4($sp)
sw $t2, 8($sp)
sw $a0, 12($sp)

move $a0, $t0
li $a1, 240		#  y coordinate
li $a2, 9		# color
li $a3, 8		# height
jal VertLine

lw $t1, 4($sp)
move $a0, $t1
li $a1, 240		#  y coordinate
li $a2, 0		# color
li $a3, 8		# height
jal VertLine

lw $t0, 0($sp)
lw $t1, 4($sp)
lw $t2, 8($sp)
lw $a0, 12($sp)
addi $sp,$sp,16
addi $a0, $a0, -1
bgtz $a0, movePaddle_moveLoop

movePaddle_doneLooping:
lw $ra, ($sp)
addi $sp,$sp,4
jr $ra

################################################################################################
#  Procedure: drawPaddle                                                                       #
#  Draws paddle and ball in middle as default  						       #
################################################################################################
drawPaddle:
addi $sp, $sp, -4
sw $ra, 0($sp)

li $a0, 240		#  x coordinate
li $a1, 240		#  y coordinate
li $a2, 9		# color number (white)
li $a3, 8		# height
addi $sp, $sp, -4
li $t0, 32
sw $t0, 0($sp)		# width
jal DrawBox
addi $sp, $sp, 4
li $a0, 248
li $a1, 224
sw $a0, b_loc_x
sw $a1, b_loc_y
li $v0, 61
syscall
li $a0, 0
li $a1, 256
li $a2, 0
jal DrawDot
li $t0, 1
sw $t0, b_onPaddle

lw $ra, 0($sp)
addi $sp, $sp, 4
jr $ra

################################################################################################
#  Procedure: VertLine                                                                         #
#  Draws a a vertical line                                                                     #
#  Input: $a0 x coordinate                                                                     #
#  Input: $a1 y coordinate                                                                     #
#  Input: $a2 color number (0-7)                                                               #
#  Input: $a3 length of the line                                                               #
################################################################################################
VertLine:
addi $sp,$sp,-4
sw $ra, 0($sp)		# store $ra
VertLoop:
addi $sp,$sp,-16
sw $a0, 12($sp)
sw $a1, 8($sp)		# store $a1
sw $a2, 4($sp)		# store $a2
sw $a3, 0($sp)		# store $a3
jal DrawDot
lw $a0, 12($sp)
lw $a1, 8($sp)
lw $a2, 4($sp)
lw $a3, 0($sp)
addi $sp,$sp,16
addi $a1, $a1, 1
addi $a3, $a3, -1
bne $a3, $0, VertLoop
# restore $ra
lw $ra, 0($sp)
addi $sp,$sp,4
jr $ra
	
################################################################################################
#  Procedure: drawMap                                                                          #
#  Draws the pattern for the blocks to break             				       #
################################################################################################
# $t0 = counter for loop
# $t1 = address of map
# $t2 = current number in mapping
# $t3 = rowSpot = num % 16
# $t4 = colSpot = num / 16
# x = (rowSpot-1) * 32
# y = colSpot*16
.data
map: .word  1,3,5,7,9,11,13,15,
18,20,22,24,26,28,30,32,
33,35,37,39,41,43,45,47,
50,52,54,56,58,60,62,64,
65,67,69,71,73,75,77,79,
82,84,86,88,90,92,94,96,
97,99,101,103,105,107,109,111,
114,116,118,120,122,124,126,128
.word  2,4,6,8,10,12,14,16
17,19,21,23,25,27,29,31,
32,34,36,38,40,42,44,46,
49,51,53,55,57,59,61,63,
64,66,68,70,72,74,76,78,
81,83,85,87,89,91,93,95,
96,98,100,102,104,106,108,110,
113,115,117,119,121,123,125,127
.text
drawMap:
addi $sp,$sp,-4
sw $ra, 0($sp)		# store $ra
la $t1, map
lw $t0, level
sll $t0, $t0, 8
add $t1, $t1, $t0

li $t0, 64
_drawMap_loop:
lw $t2, ($t1)
rem $t3, $t2, 16	# rowSpot is t3
div $t4, $t2, 16	# colSpot is t4
bne $t3, $0, drawMap_notLastColumn
li $t3, 16
addi $t4, $t4, -1
drawMap_notLastColumn:

#a0 is x for drawBox
addi $a0, $t3, -1
sll $a0, $a0, 5
#a1 is y for drawBox	
sll $a1, $t4, 4	
addi $a2, $t4, 1 		# $a2 for color (based on rowSpot)
li $a3, 16		# $a3 height of the box'
# top fo stack is width of box
addi $sp, $sp, -12
li $t7, 32
sw $t7, 0($sp)
sw $t0, 4($sp)
sw $t1, 8($sp)
jal DrawBox
# restore t0 & t1
lw $t0, 4($sp)
lw $t1, 8($sp)
addi $sp, $sp, 12	# fix stack

addi $t0, $t0, -1
addi $t1, $t1, 4
bgtz $t0, _drawMap_loop

lw $ra, 0($sp)
addi $sp, $sp, 4
jr $ra

################################################################################################
#  Procedure: ClearDisplay                                                                     #
#  Sets the display to black                                                                   #
################################################################################################
ClearDisplay:
addi $sp, $sp, -4
sw $ra, 0($sp)		# store $ra

li $a0, 0
li $a1, 0
li $a2, 0
li $a3,256		# height
addi $sp, $sp, -4
li $t0, 512
sw $t0, 0($sp)		# width
jal DrawBox
addi $sp, $sp, 4

lw $ra, 0($sp)	
addi $sp, $sp, 4
jr $ra
        
################################################################################################
#  Procedure: DrawBox                                                                          #
#  Draws a dot of color ($a2) at x ($a0) and y ($a1)                                           #
#  Input: $a0 x coordinate                                                                     #
#  Input: $a1 y coordinate                                                                     #
#  Input: $a2 color number (0-7)                                                               #
#  Input: $a3 height of the box                                                                #
#  Input: top of $sp contains width of box           					       #
################################################################################################
DrawBox:
lw $t0, 0($sp)
addi $sp,$sp,-8
sw $ra, 0($sp)		# store $ra
sw $s0, 4($sp)
move $s0, $a3
move $a3, $t0		# put width in $a3 for HorzLine
BoxLoop:
addi $sp,$sp,-16
sw $a0, 12($sp)
sw $a1, 8($sp)		# store $a1
sw $a2, 4($sp)		# store $a2
sw $a3, 0($sp)		# store $a3
jal HorzLine
lw $a0, 12($sp)
lw $a1, 8($sp)
lw $a2, 4($sp)
lw $a3, 0($sp)
addi $sp,$sp,16
addi $a1, $a1, 1	# increment y coord
addi $s0, $s0, -1	# dec counter
bne $s0, $0, BoxLoop
# restore $ra and $s0, then jr $ra
lw $ra, 0($sp)	
lw $s0, 4($sp)
addi $sp,$sp,8
jr $ra

################################################################################################
#  Procedure: HorzLine                                                                         #
#  Draws a horz line                                                                           #
#  Input: $a0 x coordinate                                                                     #
#  Input: $a1 y coordinate                                                                     #
#  Input: $a2 color number (0-7)                                                               #
#  Input: $a3 length of the line                                                               #
################################################################################################
HorzLine:
addi $sp,$sp,-4
sw $ra, 0($sp)		# store $ra
HorzLoop:
addi $sp,$sp,-16
sw $a0, 0($sp)
sw $a1, 4($sp)		# store $a1
sw $a2, 8($sp)		# store $a2
sw $a3, 12($sp)		# store $a3
jal DrawDot
lw $a0, 0($sp)
lw $a1, 4($sp)
lw $a2, 8($sp)
lw $a3, 12($sp)
addi $sp,$sp,16
addi $a0, $a0, 1
addi $a3, $a3, -1
bne $a3, $0, HorzLoop
# restore $ra
lw $ra, 0($sp)
addi $sp,$sp,4
jr $ra

################################################################################################
#  Procedure: CalcAddr                                                                         #
#  Converts X, Y coordinate to address                                                         #
#  Input: $a0 x coordinate                                                                     #
#  Input: $a1 y coordinate                                                                     #
#  Returns $v0 = memory address                                                                #
################################################################################################
CalcAddr:
# $v0 = base+$a0*4+$a1*512*4
sll $a0,$a0,2
sll $a1,$a1,11
addi $v0, $a0, 0x10040000
add $v0, $v0, $a1
jr $ra

################################################################################################
#  Procedure: GetColor                                                                         #
#  Converts X, Y coordinate to address                                                         #
#  Input: $a2 color number (0-9)                                                               #
#  Returns $v1 = actual number to write to the display                                         #
################################################################################################
.data
ColorTable:
        .align  2               # forces the data segment to a word boundary
	.word 0x000000	# black
	.word 0xff0000	# red
	.word 0xff8800	# orange
	.word 0xffff00	# yellow
	.word 0x66ff00	# lime green
	.word 0x00ff66	# green blue
	.word 0x0066ff	# blue
	.word 0x8800ff	# purple
	.word 0xff0099	# pink
	.word 0xffffff	# white
.text
GetColor:
la $t0, ColorTable	# load base
sll $a2,$a2,2		# index x4 is offset
add $a2, $t0, $a2	# addr is base+ offset
lw $v1, 0($a2)		# get actual color from mem
jr $ra

################################################################################################
#  Procedure: DrawDot                                                                          #
#  Draws a dot of color ($a2) at x ($a0) and y ($a1)                                           #
#  Input: $a0 x coordinate                                                                     #
#  Input: $a1 y coordinate                                                                     #
#  Input: $a2 color number (0-9)                                                               #
################################################################################################
DrawDot:
addi $sp,$sp,-8	# adjust stack ptr, 2 words
sw $ra, 4($sp)		# store $ra
sw $a2, 0($sp)		# store $a2
jal CalcAddr		# v0 has address for pixel
lw $a2, 0($sp)		# restore $a2

sw $v0, 0($sp)		# store $v0 in spot freed by $a2
jal GetColor		#v1 has color
lw $v0, 0($sp)		# restore $v0

sw $v1, 0($v0)		# make dot
lw $ra, 4($sp)		# load original $ra
addi $sp, $sp, 8	# adjust $sp
jr $ra


#########################################################################
# Exception handling
#########################################################################
.data
# Status register bits
.align 2
EXC_ENABLE_MASK:        .word   0x00000001

# Cause register bits
EXC_CODE_MASK:          .word   0x0000003c  # Exception code bits

EXC_CODE_INTERRUPT:     .word   0   # External interrupt
EXC_CODE_ADDR_LOAD:     .word   4   # Address error on load
EXC_CODE_ADDR_STORE:    .word   5   # Address error on store
EXC_CODE_IBUS:          .word   6   # Bus error instruction fetch
EXC_CODE_DBUS:          .word   7   # Bus error on load or store
EXC_CODE_SYSCALL:       .word   8   # System call
EXC_CODE_BREAKPOINT:    .word   9   # Break point
EXC_CODE_RESERVED:      .word   10  # Reserved instruction code
EXC_CODE_OVERFLOW:      .word   12  # Arithmetic overflow

# Status and cause register bits
EXC_INT_ALL_MASK:       .word   0x0000ff00  # Interrupt level enable bits

EXC_INT0_MASK:          .word   0x00000100  # Software
EXC_INT1_MASK:          .word   0x00000200  # Software
EXC_INT2_MASK:          .word   0x00000400  # Display
EXC_INT3_MASK:          .word   0x00000800  # Keyboard
EXC_INT4_MASK:          .word   0x00001000
EXC_INT5_MASK:          .word   0x00002000  # Timer
EXC_INT6_MASK:          .word   0x00004000
EXC_INT7_MASK:          .word   0x00008000

	########################################################################
	#   Description:
	#       Example SPIM exception handler
	#       Derived from the default exception handler in the SPIM S20
	#       distribution.
	#
	#   History:
	#       Dec 2009    J Bacon
	
	########################################################################
	# Exception handling code.  This must go first!
	
			.kdata
	__start_msg_:   .asciiz "  Exception "
	__end_msg_:     .asciiz " occurred and ignored\n"
	
	# Messages for each of the 5-bit exception codes
	__exc0_msg:     .asciiz "  [Interrupt] "
	__exc1_msg:     .asciiz "  [TLB]"
	__exc2_msg:     .asciiz "  [TLB]"
	__exc3_msg:     .asciiz "  [TLB]"
	__exc4_msg:     .asciiz "  [Address error in inst/data fetch] "
	__exc5_msg:     .asciiz "  [Address error in store] "
	__exc6_msg:     .asciiz "  [Bad instruction address] "
	__exc7_msg:     .asciiz "  [Bad data address] "
	__exc8_msg:     .asciiz "  [Error in syscall] "
	__exc9_msg:     .asciiz "  [Breakpoint] "
	__exc10_msg:    .asciiz "  [Reserved instruction] "
	__exc11_msg:    .asciiz ""
	__exc12_msg:    .asciiz "  [Arithmetic overflow] "
	__exc13_msg:    .asciiz "  [Trap] "
	__exc14_msg:    .asciiz ""
	__exc15_msg:    .asciiz "  [Floating point] "
	__exc16_msg:    .asciiz ""
	__exc17_msg:    .asciiz ""
	__exc18_msg:    .asciiz "  [Coproc 2]"
	__exc19_msg:    .asciiz ""
	__exc20_msg:    .asciiz ""
	__exc21_msg:    .asciiz ""
	__exc22_msg:    .asciiz "  [MDMX]"
	__exc23_msg:    .asciiz "  [Watch]"
	__exc24_msg:    .asciiz "  [Machine check]"
	__exc25_msg:    .asciiz ""
	__exc26_msg:    .asciiz ""
	__exc27_msg:    .asciiz ""
	__exc28_msg:    .asciiz ""
	__exc29_msg:    .asciiz ""
	__exc30_msg:    .asciiz "  [Cache]"
	__exc31_msg:    .asciiz ""
	
	__level_msg:    .asciiz "Interrupt mask: "
	
	
	#########################################################################
	# Lookup table of exception messages
	__exc_msg_table:
		.align 2
		.word   __exc0_msg, __exc1_msg, __exc2_msg, __exc3_msg, __exc4_msg
		.word   __exc5_msg, __exc6_msg, __exc7_msg, __exc8_msg, __exc9_msg
		.word   __exc10_msg, __exc11_msg, __exc12_msg, __exc13_msg, __exc14_msg
		.word   __exc15_msg, __exc16_msg, __exc17_msg, __exc18_msg, __exc19_msg
		.word   __exc20_msg, __exc21_msg, __exc22_msg, __exc23_msg, __exc24_msg
		.word   __exc25_msg, __exc26_msg, __exc27_msg, __exc28_msg, __exc29_msg
		.word   __exc30_msg, __exc31_msg
	
	# Variables for save/restore of registers used in the handler
	save_v0:    .word   0
	save_a0:    .word   0
	save_a1:    .word   0
	save_a2:    .word   0
	save_at:    .word   0
	save_ra:    .word   0
	save_t0:    .word   0
	save_t1:    .word   0
	save_t2:    .word   0
	
	
	#########################################################################
	# This is the exception handler code that the processor runs when
	# an exception occurs. It only prints some information about the
	# exception, but can serve as a model of how to write a handler.
	#
	# Because this code is part of the kernel, it can use $k0 and $k1 without
	# saving and restoring their values.  By convention, they are treated
	# as temporary registers for kernel use.
	#
	# On the MIPS-1 (R2000), the exception handler must be at 0x80000080
	# This address is loaded into the program counter whenever an exception
	# occurs.  For the MIPS32, the address is 0x80000180.
	# Select the appropriate one for the mode in which SPIM is compiled.
	
		.ktext  0x80000180
		
		# $at is the temporary register reserved for the assembler.
		# It may be modified by pseudo-instructions in this handler.
		# Since an interrupt could have occurred during a pseudo
		# instruction in user code, $at must be restored to ensure
		# that that pseudo instruction completes correctly.
		.set    noat
		sw      $at, save_at
		.set    at
	
		# Save ALL registers modified in this handler, except $k0 and $k1
		# This includes $t* since the user code does not explicitly
		# call this handler.  $sp cannot be trusted, so saving them to
		# the stack is not an option.  This routine is not reentrant (can't
		# be called again while it is running), so we can save registers
		# to static variables.
		sw      $v0, save_v0
		sw      $a0, save_a0
		sw      $a1, save_a1
		sw      $a2, save_a2
		sw      $t0, save_t0
		sw      $t1, save_t1
		sw      $t2, save_t2
		sw      $ra, save_ra
		
	# Enable interrupts in status register
#	mfc0    $t0, $12

	# Disable all interrupt levels
#	lw      $t1, EXC_INT_ALL_MASK
#	not     $t1, $t1
#	and     $t0, $t0, $t1

#	mtc0    $t0, $12
	
	# Enable keyboard interrupts
#	li      $t0, 0xffff0000     # Receiver control register
#	li      $t1, 0x00000002     # Interrupt enable bit
#	sw      $t1, ($t0)
	
		# Determine cause of the exception
		mfc0    $k0, $13        # Get cause register from coprocessor 0
		srl     $a0, $k0, 2     # Extract exception code field (bits 2-6)
		andi    $a0, $a0, 0x1f
		
		# Check for program counter issues (exception 6)
		bne     $a0, 6, ok_pc
		nop
	
		mfc0    $a0, $14        # EPC holds PC at moment exception occurred
		andi    $a0, $a0, 0x3   # Is EPC word-aligned (multiple of 4)?
		beqz    $a0, ok_pc
		nop
	
		# Bail out if PC is unaligned
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4
		la      $a0, __exc3_msg
		syscall
		li      $v0, 10
		syscall
	
	ok_pc:
		mfc0    $k0, $13
		srl     $a0, $k0, 2     # Extract exception code from $k0 again
		andi    $a0, $a0, 0x1f
		bnez    $a0, non_interrupt  # Code 0 means exception was an interrupt
		nop
	
		# External interrupt handler
		# Don't skip instruction at EPC since it has not executed.
		# Interrupts occur BEFORE the instruction at PC executes.
		# Other exceptions occur during the execution of the instruction,
		# hence for those increment the return address to avoid
		# re-executing the instruction that caused the exception.
	
	     	# check if we are in here because of a character on the keyboard simulator
	     	jal IsCharThere
		 # go to nochar if some other interrupt happened
		 bne $v0, 1, nochar
		 jal GetCharEx		# get the character from memory
		 bne $v0, 97, inter_not_moveLeft
		 li $t0, 32
		 sw $t0, p_MoveLeft
		 inter_not_moveLeft:
		 bne $v0, 100, inter_not_moveRight
		 li $t0, 32
		 sw $t0, p_MoveRight
		 inter_not_moveRight:
		 bne $v0, 119, interrupts_not_release
		 li $t0, 1
		 sw $t0, p_Release
		 interrupts_not_release:
		 bne $v0, 114, interrupts_not_restart
		 li $t0, 1
		 sw $t0, restart_pressed
		 interrupts_not_restart:
		j	return
	
nochar:
		# not a character
		# Print interrupt level
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4          # print_str
		la      $a0, __level_msg
		syscall
		
		li      $v0, 1          # print_int
		mfc0    $k0, $13        # Cause register
		srl     $a0, $k0, 11    # Right-justify interrupt level bits
		syscall
		
		li      $v0, 11         # print_char
		li      $a0, 10         # Line feed
		syscall
		
		j       return
	
	non_interrupt:
		# Print information about exception.
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4          # print_str
		la      $a0, __start_msg_
		syscall
	
		li      $v0, 1          # print_int
		mfc0    $k0, $13        # Extract exception code again
		srl     $a0, $k0, 2
		andi    $a0, $a0, 0x1f
		syscall
	
		# Print message corresponding to exception code
		# Exception code is already shifted 2 bits from the far right
		# of the cause register, so it conveniently extracts out as
		# a multiple of 4, which is perfect for an array of 4-byte
		# string addresses.
		# Normally you don't want to do syscalls in an exception handler,
		# but this is MARS and not a real computer
		li      $v0, 4          # print_str
		mfc0    $k0, $13        # Extract exception code without shifting
		andi    $a0, $k0, 0x7c
		lw      $a0, __exc_msg_table($a0)
		nop
		syscall
	
		li      $v0, 4          # print_str
		la      $a0, __end_msg_
		syscall
	
		# Return from (non-interrupt) exception. Skip offending instruction
		# at EPC to avoid infinite loop.
		mfc0    $k0, $14
		addiu   $k0, $k0, 4
		mtc0    $k0, $14
	
	return:
	
		# Restore registers and reset processor state
		lw      $v0, save_v0    # Restore other registers
		lw      $a0, save_a0
		lw      $a1, save_a1
		lw      $a2, save_a2
		lw      $t0, save_t0
		lw      $t1, save_t1
		lw      $t2, save_t2
		lw      $ra, save_ra
	
		.set    noat            # Prevent assembler from modifying $at
		lw      $at, save_at
		.set    at
	
		mtc0    $zero, $13      # Clear Cause register
	
		# Re-enable interrupts, which were automatically disabled
		# when the exception occurred, using read-modify-write cycle.
		mfc0    $k0, $12        # Read status register
		andi    $k0, 0xfffd     # Clear exception level bit
		ori     $k0, 0x0001     # Set interrupt enable bit
		mtc0    $k0, $12        # Write back
	
		# Return from exception on MIPS32:
		eret
		
	# Functions
	################################################################################################
	#  Procedure: IsCharThere                                                                      #
	################################################################################################
	IsCharThere:
		lui $t0,0xffff
		lw  $t1,0($t0)
		and $v0,$t1,1
		jr $ra
		
	################################################################################################
	#  Procedure: GetChar                                                                          #
	# return char in v0                                                                            #
	################################################################################################
	GetCharEx:
		li $t2, 0
		lui $t0, 0xffff		# char in 0xffff0004
		lw $v0, 4($t0)
		jr $ra
	
	#########################################################################
	# Standard startup code.  Invoke the routine "main" with arguments:
	# main(argc, argv, envp)
	
		.text
		.globl __start
	__start:
		lw      $a0, 0($sp)     # argc = *$sp
		addiu   $a1, $sp, 4     # argv = $sp + 4
		addiu   $a2, $sp, 8     # envp = $sp + 8
		sll     $v0, $a0, 2     # envp += size of argv array
		addu    $a2, $a2, $v0
		jal     main
		nop
	
		li      $v0, 10         # exit
		syscall
	
		.globl __eoth
	__eoth:


end:
