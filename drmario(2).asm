################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Dr Mario.
#
# Student 1: Timothy Marcello Pasaribu, 1009714864
# Student 2: Name, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       1
# - Unit height in pixels:      1
# - Display width in pixels:    32
# - Display height in pixels:   32
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000
PAIR_TRACKER:        # This is the address itself, so we load the with "la"
    .word 0:1024      # 32 x 32 table initialized to 0 
# Reserve 4096 bytes for saving 32x32 screen (each pixel = 4 bytes)
screen_backup: .space 4096 
##############################################################################
# Mutable Data
##############################################################################

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    li $t1, 0xff0000        # $t1 = red
    li $t2, 0x00ff00        # $t2 = green
    li $t3, 0x0000ff        # $t3 = blue
    li $t4, 0xffffff        # $t4 = white
		li $t5, 0x000000        # $t5 = black

		# paint the screen black using a loop

		lw   $t0, ADDR_DSPL    # $t0 = base address of the display
    li   $t9, 0    # $t9 = counter for loop 
		li   $t8, 0    # $t8 = offset for display
		clear_screen_loop:
			beq $t9, 1024, continue_intial_game
			add $t7, $t0, $t8   # compute offset of display 
	    sw   $t5, 0($t7)     # Write black (0x000000) to the current location
	    addi $t8, $t8, 4       # Move to the next word (4 bytes)
	    addi $t9, $t9, 1      # incrase the counter
	    j clear_screen_loop  # Loop until all units are cleared


		continue_intial_game:
    jal draw_bottle         # Return address is set correctly
    jal place_viruses
    jal draw_curr_capsule   # Return address is set correctly
    j game_loop             # Go to the game loop


check_full_removal:
    lw $t9, ADDR_DSPL      # Load base display address
    lw $t9, 0($t9)

########## HORIZONTAL SCAN ##########
    li $t0, 7              # y = 0 (row)
check_rows:
    li $t1, 2              # x = 0 (column)
    li $t2, -1             # Previous color
    li $t3, 0              # Count
    li $t4, -1             # Start offset for removal

check_row_loop:
    lw $t9, ADDR_DSPL      # Load base display address

    addi $sp, $sp, -4        # Create space on stack
    sw $ra, 0($sp)           # Save $ra to stack

    # We also need to save all the $t registers' values
    addi $sp, $sp, -4        # Create space on stack
    sw $t0, 0($sp)           # Save $ra to stack

    addi $sp, $sp, -4        # Create space on stack
    sw $t1, 0($sp)           # Save $ra to stack

    addi $sp, $sp, -4        # Create space on stack
    sw $t2, 0($sp)           # Save $ra to stack

    addi $sp, $sp, -4        # Create space on stack
    sw $t3, 0($sp)           # Save $ra to stack

    addi $sp, $sp, -4        # Create space on stack
    sw $t4, 0($sp)           # Save $ra to stack

    move $a0, $t1
    move $a1, $t0
    jal get_offset

    lw $t4, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack 

    lw $t3, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack 

    lw $t2, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack 

    lw $t1, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack 

    lw $t0, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack 

    lw $ra, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack 

    add $t5, $t9, $v0      # $t5 = address at (x,y)
    lw $t6, 0($t5)         # Load color
    
    beq $t6, $t2, incr_count

    # Check if the color of the >= 4 consecutive blocks are either of these, if not we dont want to remove them and just skip
    beq $t2, 0xff0000, count_check_row_loop
    beq $t2, 0xffff00, count_check_row_loop
    beq $t2, 0x0000ff, count_check_row_loop
    j reset_check_row_loop

    count_check_row_loop:
    bge $t3, 4, remove_horizontal_range
    
    reset_check_row_loop:
    # Reset
    move $t2, $t6          # new color
    li $t3, 1              # reset count
    move $t4, $v0          # set new start offset
    j advance_column

incr_count:
    addi $t3, $t3, 1
    j advance_column

remove_horizontal_range:
    li $t7, 0              # temp offset
remove_h_loop:
    lw $t9, ADDR_DSPL      # Load base display address
    mul $t8, $t0, 32        # y*32
    add $t8, $t8, $t1       # y*32 + x
    sub $t8, $t8, $t3       
    add $t8, $t8, $t7
    sll $t8, $t8, 2         # t8 is now the offset of the current block to remove
    add $t6, $t9, $t8
    sw $zero, 0($t6)
    addi $t7, $t7, 1
    blt $t7, $t3, remove_h_loop

    li $t3, 1              # reset count
    move $t2, $t6
    j advance_column

advance_column:
    addi $t1, $t1, 1
    li $t8, 24
    blt $t1, $t8, check_row_loop

    li $t9, 31
    addi $t0, $t0, 1
    blt $t0, $t9, check_rows

########## VERTICAL SCAN ##########
    li $t1, 2              # x = 0 (column)
check_cols:
    li $t0, 7              # y = 0 (row)
    li $t2, -1             # Previous color
    li $t3, 0              # Count
    li $t4, -1             # Start offset for removal

check_col_loop:
    lw $t9, ADDR_DSPL      # Load base display address
    addi $sp, $sp, -4        # Create space on stack
    sw $ra, 0($sp)           # Save $ra to stack

    # We also need to save all the $t registers' values

    addi $sp, $sp, -4        # Create space on stack
    sw $t0, 0($sp)           # Save $ra to stack

    addi $sp, $sp, -4        # Create space on stack
    sw $t1, 0($sp)           # Save $ra to stack

    addi $sp, $sp, -4        # Create space on stack
    sw $t2, 0($sp)           # Save $ra to stack

    addi $sp, $sp, -4        # Create space on stack
    sw $t3, 0($sp)           # Save $ra to stack

    addi $sp, $sp, -4        # Create space on stack
    sw $t4, 0($sp)           # Save $ra to stack

    move $a0, $t1
    move $a1, $t0
    jal get_offset

    lw $t4, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack 

    lw $t3, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack 

    lw $t2, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack 

    lw $t1, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack 

    lw $t0, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack 

    lw $ra, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack 
    
    add $t5, $t9, $v0
    lw $t6, 0($t5)           # load the color of the current block

    beq $t6, $t2, incr_v_count  # if the color is the same as the previous color

    # Check if the color of the >= 4 consecutive blocks are either of these, if not we dont want to remove them and just skip
    beq $t2, 0xff0000, count_check_col_loop
    beq $t2, 0xffff00, count_check_col_loop
    beq $t2, 0x0000ff, count_check_col_loop
    j reset_check_col_loop

    count_check_col_loop:
    bge $t3, 4, remove_vertical_range  # if the color is not the same but the count is already >= 4

    reset_check_col_loop:
    move $t2, $t6            # store the color of the current block as the color of the previous block
    li $t3, 1
    move $t4, $v0
    j advance_row

incr_v_count:
    addi $t3, $t3, 1
    j advance_row

remove_vertical_range:
    li $t7, 0
remove_v_loop:
    mul $t8, $t0, 32         # y * 32
    add $t8, $t8, $t1        # y * 32 + x
    mul $t9, $t3, 32         
    sub $t8, $t8, $t9
    mul $t9, $t7, 32     
    add $t8, $t8, $t9        # t8 now contains the offset (in 4 bit scale) of the current block to remove
    sll $t8, $t8, 2          # t8 now contains the offset (in 1 bit scale) of the current block to remove
    lw $t9, ADDR_DSPL      # Load base display address
    add $t6, $t9, $t8       # t6 now contains the address of the current block to remove 
    sw $zero, 0($t6)
    addi $t7, $t7, 1
    blt $t7, $t3, remove_v_loop

    li $t3, 1
    move $t2, $t6
    j advance_row

advance_row:
    addi $t0, $t0, 1
    li $t8, 31
    blt $t0, $t8, check_col_loop

    li $t9, 24
    addi $t1, $t1, 1
    blt $t1, $t9, check_cols

    jr $ra

##### MAKE ALL UNSUPPORTED BLOCKS FALL
fall_unsupported:
    li $t0, 29              # Start at row 31 (bottom row)
fall_outer_loop:
    li $t1, 22              # Start at column 31 (rightmost column)

fall_inner_loop:

    # Compute offset from (x, y)
    # Save $ra on the stack
    addi $sp, $sp, -4        # Create space on stack
    sw $ra, 0($sp)           # Save $ra to stack

    addi $sp, $sp, -4        # Create space on stack
    sw $t0, 0($sp)           # Save $t0 to stack

    addi $sp, $sp, -4        # Create space on stack
    sw $t1, 0($sp)           # Save $t1 to stack
    
    # Pass arguments and call the function
    move $a0, $t1            # x
    move $a1, $t0            # y
    jal get_offset           # Result in $v0

    lw $t1, 0($sp)           # Restore $t1 from stack
    addi $sp, $sp, 4         # Clean up stack

    lw $t0, 0($sp)           # Restore $t0 from stack
    addi $sp, $sp, 4         # Clean up stack
    
    # Restore $ra after function returns
    lw $ra, 0($sp)           # Restore $ra from stack
    addi $sp, $sp, 4         # Clean up stack

    lw $t2, ADDR_DSPL
    add $t3, $t2, $v0       # Compute address of current block
    lw $t4, 0($t3)          # Load block value (color)

    beq $t3, $s0, next_block   # If we're checking our current block, don't fall

    # Check if it's a virus (the pair address is -2)
    la $t9, PAIR_TRACKER
    add $t9, $t9, $v0          # pair address of current block
    lw $t9, 0($t9)
    beq $t9, -2, next_block              

    # We check the other pair location. We can do this by orientation
    beq $s3, 0, check_to_skip_horizontal_pair_of_current_block
    beq $s3, 2, check_to_skip_horizontal_pair_of_current_block

    addi $t9, $s0, 4
    beq $t9, $t3, next_block

    j check_to_skip_vertical_pair_of_current_block
    check_to_skip_horizontal_pair_of_current_block:

    addi $t9, $s0, -128
    beq $t9, $t3, next_block
    
    check_to_skip_vertical_pair_of_current_block: 

    # If empty → skip
    beqz $t4, next_block

    # Check if it's colored (0xFF0000 = red, 0xFFFF00 = yellow, 0x0000FF = blue)
    li $t5, 0xFF0000
    beq $t4, $t5, check_support

    li $t5, 0xFFFF00
    beq $t4, $t5, check_support

    li $t5, 0x0000FF
    beq $t4, $t5, check_support

    # Not a valid color → skip
    j next_block

# ----------------- CHECK SUPPORT -----------------
check_support:
    # Check block below
    addi $t6, $v0, 128        # Offset for row below
    add $t7, $t2, $t6         # Address of cell below
    lw $t8, 0($t7)            # Load value of cell below
    bnez $t8, next_block       # If non-zero → supported

    # Unsupported → Check pair using PAIR_TRACKER
    la $t9, PAIR_TRACKER
    add $t6, $t9, $v0         # Access pair tracker
    lw $t8, 0($t6)            # Load pair offset
    beqz $t8, drop_single      # If no pair → drop block
    beq $t8, -1, drop_single    # pair is removed
    # No need to check for -2 because it's only for virus and we're currently checking a block

    # Has pair → Check orientation
    # andi $t5, $t8, 3           # Orientation = last 2 bits
    # srl $t8, $t8, 2            # Remove orientation bits to get pair offset
    
    add $t7, $t2, $t8          # Compute pair address
    lw $t9, 0($t7)             # Load value of pair block
    beqz $t9, drop_single      # If pair block missing → drop single  <--- unlikely case: because we make sure deleted block to have -1 pair offset

    # Pair exists → Check support for pair
    addi $t6, $t8, 128         # Offset for row below pair
    add $t7, $t2, $t6
    lw $t9, 0($t7)             # value of the block under the pair

    addi $t4, $v0, 4
    beq $t8, $t4, check_horizontal
    addi $t4, $v0, -4
    beq $t8, $t4, check_horizontal
    
    # -------- If vertical → Fall together --------
    j drop_pair

check_horizontal:
    # If either block below is occupied → Do not fall
    bnez $t9, next_block
    j drop_pair

# ----------------- DROP SINGLE -----------------
drop_single:
    # Load value of block
    lw $t4, 0($t3)

fall_single_loop:
    addi $t6, $v0, 128         # Move down one row
    add $t7, $t2, $t6          # New address
    lw $t8, 0($t7)             # Load value below
    bnez $t8, finish_fall_single

    # No need for updating the pair address since they don't have no pair 
    sw $zero, 0($t3)           # Clear old position
    sw $t4, 0($t7)             # Place block in new position
    move $t3, $t7              # Update block address
    move $v0, $t6              # Update offset
    j fall_single_loop

finish_fall_single:
    j next_block

# ----------------- DROP PAIR -----------------
drop_pair:

    la $t8, PAIR_TRACKER
    # Load pair values
    lw $t4, 0($t3)            # First half

    # compute the pair
    sub $t9, $t3, $t2         
    add $t9, $t9, $t8
    lw $t5, 0($t9)            # Second half

fall_pair_loop:
    lw $t2, ADDR_DSPL
    # Check if the block below them is empty 
    
    # First half
    addi $t7, $v0, 128        # Offset down
    add $t7, $t2, $t7
    lw $t8, 0($t7)
    bnez $t8, finish_fall_pair

    # Second half
    la $t9, PAIR_TRACKER
    add $t6, $t9, $v0         # Access pair tracker
    lw $t8, 0($t6)            # Load pair offset

    addi $t6, $t8, 128
    add $t6, $t2, $t6
    lw $t9, 0($t6)
    bnez $t9, finish_fall_pair

    # Drop both blocks if below them is empty
    sw $t4, 0($t7)            # Move down first half
    sw $t5, 0($t6)            # Move down second half
    
    addi $sp, $sp, -4        # Create space on stack
    sw $t7, 0($sp)           # Save $t1 to stack

    addi $sp, $sp, -4        # Create space on stack
    sw $t6, 0($sp)           # Save $t1 to stack

    add $t8, $t8, $t2
    sw $zero, 0($t3)          # Clear old position
    sw $zero, 0($t8)          # Clear pair position

    la $t9, PAIR_TRACKER

    sub $t3, $t3, $t2
    add $t3, $t9, $t3

    sub $t8, $t8, $t2
    add $t8, $t9, $t8

    sw $zero, 0($t3)          # Clear old pair of curent block
    sw $zero, 0($t8)          # Clear old pair of pair

    lw $t6, 0($sp)           # Restore $t1 from stack
    addi $sp, $sp, 4         # Clean up stack
    
    lw $t7, 0($sp)           # Restore $t1 from stack
    addi $sp, $sp, 4         # Clean up stack

    lw $t2, ADDR_DSPL

    sub $t4, $t7, $t2    # offset of the new block position
    sub $t5, $t6, $t2    # offset of the new block of the PAIR_TRACKER

    addi $t3, $t3, 128
    addi $t8, $t8, 128

    sw $t4, 0($t3)
    sw $t5, 0($t8)
    
    move $t3, $t7
    j fall_pair_loop

finish_fall_pair:
    j next_block

# ----------------- MOVE TO NEXT BLOCK -----------------
next_block:
    subi $t1, $t1, 1         # Decrement x
    bge $t1, 2, fall_inner_loop

    li $t1, 22               # Reset x to 31
    subi $t0, $t0, 1         # Decrement y
    bge $t0, 7, fall_outer_loop

    jr $ra                   # Return when done

#### ERASE CAPSULE ####
erase_capsule:
    lw $t9, ADDR_DSPL         # Load base address
    la $t8, PAIR_TRACKER      # Load base address of pair tracker

    sub $t1, $s0, $t9          # $a0 = Current offset
    add $t2, $t8, $t1          # address that stores the address of the pair
    # Erase the stored half
    sw $zero, 0($s0)           # Turn to black (0x000000)
    # Erase the address of the pair
    sw $zero, 0($t2)           # Turn to 0
    
    # Compute the other half based on orientation
    beq $s3, 1, erase_horizontal_right
    beq $s3, 2, erase_vertical_down
    beq $s3, 3, erase_horizontal_left
    beq $s3, 0, erase_vertical_up

erase_horizontal_right:
    addi $t6, $s0, 4           # +4 for right half
    j erase_done

erase_vertical_down:
    addi $t6, $s0, -128         # +128 for bottom half
    j erase_done

erase_horizontal_left:
    addi $t6, $s0, 4           # -4 for left half
    j erase_done

erase_vertical_up:
    addi $t6, $s0, -128         # -128 for top half

erase_done:
    # Erase the other half
    sw $zero, 0($t6)           # Turn to black (0x000000)

    sub $t1, $t6, $t9          # $a0 = Current offset
    add $t2, $t8, $t1          # address that stores the address of the pair
    sw $zero, 0($t2)           # Turn to black (0x000000)
    
    jr $ra

###### Function to compute offset from x, y coordinates ######
get_offset:
    li $t0, 32
    
    mul $t1, $a1, $t0
    add $t1, $t1, $a0
    sll $v0, $t1, 2       # multiply by 4
    
    jr $ra                # Safe return

###### Function to compute (x, y) from offset ######
get_coordinate:
    srl $t0, $a0, 2            # Divide offset by 4 → get index
    
    li $t1, 32                 # Row size = 32
    
    div $t0, $t1               # Divide index by row size
    mflo $v1                   # y-coordinate → $v1
    mfhi $v0                   # x-coordinate → $v0
    
    jr $ra                     # Safe return

### CHECK SINGLE REMOVAL
# a0 : the coordinate we want to check
check_single_removal:
    lw $t5, 0($a0)              # Load current color
    beqz $t5, done_check         # Skip if empty cell

# ----------------- HORIZONTAL CHECK -----------------
    li $t3, -24                  # (-3) * 4 = -12 (left shift)
    li $t4, 24                   # (+3) * 4 = +12 (right shift)
    li $t6, 0                    # Reset count

# Count horizontal matches
count_horizontal:
    add $t7, $a0, $t3          
    lw $t8, 0($t7)             # load the color of the block to compare to our current block's color
    bne $t8, $t5, reset_horizontal_count    # if not equal to our color, reset the count
    # if equal, we store the address and increment the count
    move $t1, $t7              # store the index
    addi $t6, $t6, 1
    addi $t3, $t3, 4
    ble $t3, $t4, count_horizontal

# If count ≥ 4 → Remove all matches (including > 4)
bge $t6, 4, remove_horizontal
j done_remove_horizontal  # If nothing to remove, go to the vertical

reset_horizontal_count:
    bge $t6, 4, remove_horizontal
    li $t6, 0                   # Reset count
    j count_horizontal

# ---------- REMOVE HORIZONTAL ----------
remove_horizontal:
    # at this point $t1 will store the first index of the sequence of >= 4
    sub $t3, $t1, $a0         # here $t3 will be the offset referring to that index
    add $t4, $t1, $t6
    sub $t4, $t4, $a0
remove_horizontal_loop:
    add $t7, $a0, $t3
    lw $t8, 0($t7)
    bne $t8, $t5, done_remove_horizontal  # Stop if different color
    sw $zero, 0($t7)             # Turn block to black (0)

    # Load pair from PAIR_TRACKER
    la $t9, PAIR_TRACKER
    
    add $t9, $t9, $t3            # $t9 now stores the location that stores the pair offset of our current block
    lw $t5, 0($t9)               # the offset of the pair of our current block

    beq $t5, -2, skip_gravity       # It's a virus
    beq $t5, -1, skip_gravity       # The pair is gone already
    beqz $t5, skip_gravity          # The pair does not exist
    
    # Check if pair still exists
    lw $t0, ADDR_DSPL
    add $t6, $t0, $t5
    lw $t0, 0($t6)               # load the value of the pair
    beqz $t0, skip_gravity       # Pair gone → skip gravity  <--- this is actually an error: our design does not allow this behaviour

    li $t1, -1              
    add $t2, $t9, $t5               
    sw $t1, 0($t9)          # Store -1 at the pair address of the block we just removed
    sw $t1, 0($t2)          # store -1 at the pair of the pair address of the block we just removed

#     ### pair is intact at this point
#     lw $t4, 0($t6)
#     sw $zero, 0($t6)              # Set old position to black
#     go_down:  
#       addi $t1, $t0, 128   # check 1 position down
#       bne $t1, $zero, fall_block_end # if it's not zero/empty, falling is done
#       # if it's zero, we go go_down (store the position we test as our current position)
#       move $t0, $t1  
      
#     fall_block_end:
#     sw $t4, 0($t0)
    
#     # # Update PAIR_TRACKER
#     # la $t9, PAIR_TRACKER
#     # add $t9, $t9, $t3             # Old pair location
#     # lw $t5, 0($t9)                # Load pair offset
#     # addi $t5, $t5, 128            # New row offset
#     # add $t9, $t9, 128
#     # sw $t5, 0($t9)                # Store updated offset

skip_gravity:

    addi $t3, $t3, 4
    ble $t3, $t4, remove_horizontal_loop

done_remove_horizontal:
    
# ----------------- VERTICAL CHECK -----------------
    li $t3, -384                 # (-3) * 128 = -384 (up shift)
    li $t4, 384                  # (+3) * 128 = +384 (down shift)
    li $t6, 0                    # Reset count

# Count vertical matches
count_vertical:
    add $t7, $a0, $t3
    lw $t8, 0($t7)
    bne $t8, $t5, reset_vertical_count
    # If equal, store the address and increment the count
    move $t1, $t7
    addi $t6, $t6, 1
    addi $t3, $t3, 128
    ble $t3, $t4, count_vertical

# If count ≥ 4 → Remove all matches (including > 4)
bge $t6, 4, remove_vertical
j done_remove_vertical  # If nothing to remove, skip removal

reset_vertical_count:
    bge $t6, 4, remove_vertical
    li $t6, 0                   # Reset count
    j count_vertical

# ---------- REMOVE VERTICAL ----------
remove_vertical:
    # $t1 = first index of the sequence of >= 4
    sub $t3, $t1, $a0         # Compute offset to first index
    add $t4, $t1, $t6
    sub $t4, $t4, $a0

remove_vertical_loop:
    add $t7, $a0, $t3
    lw $t8, 0($t7)
    bne $t8, $t5, done_remove_vertical
    sw $zero, 0($t7)             # Turn block to black (0)

    # INTEGRATED GRAVITY LOGIC    # Load pair from PAIR_TRACKER
    la $t9, PAIR_TRACKER
    add $t9, $t9, $t3            # Get pair location in tracker
    lw $t5, 0($t9)               # Load pair offset

    beq $t5, -2, skip_vertical_gravity       # It's a virus
    beq $t5, -1, skip_vertical_gravity       # Pair already gone
    beqz $t5, skip_vertical_gravity          # No pair → Skip gravity
    
    # Check if pair still exists
    lw $t0, ADDR_DSPL
    add $t6, $t0, $t5
    lw $t0, 0($t6)
    beqz $t0, skip_vertical_gravity

    li $t1, -1              
    add $t2, $t9, $t5               
    sw $t1, 0($t9)          # Store -1 at the pair address of the block we just removed
    sw $t1, 0($t2)          # store -1 at the pair of the pair address of the block we just removed

    # # ✅ FALLING LOGIC ✅
    # # If pair gone → Make it fall
    # lw $t4, 0($t6)
    # sw $zero, 0($t6)              # Remove pair block

# fall_vertical:
#     addi $t1, $t6, 128            # One row down
#     lw $t2, 0($t1)                # Load cell below
#     bnez $t2, end_fall_vertical    # If non-zero → Stop falling
    
#     move $t6, $t1                 # Update current position
#     j fall_vertical

# end_fall_vertical:
#     sw $t4, 0($t6)                # Drop block into new position
    
#     # ✅ Update PAIR_TRACKER ✅
#     la $t9, PAIR_TRACKER
#     add $t9, $t9, $t3             # Old pair location
#     lw $t5, 0($t9)                # Load pair offset
#     addi $t5, $t5, 128            # Update for new row
#     add $t9, $t9, 128
#     sw $t5, 0($t9)                # Store updated pair info

skip_vertical_gravity:
    addi $t3, $t3, 128
    ble $t3, $t4, remove_vertical_loop

done_remove_vertical:
done_check:
    jr $ra

########

# a0 : capsule offset
# a1 : capsule color 1
# a2 : capsule color 2
# a3 : orientation
assign_capsule_color:
    lw $t9, ADDR_DSPL         # Load base address into $t9
    la $t8, PAIR_TRACKER      # Load base address of the pair address arrray

    # Compute second half offset based on orientation
    beq $a3, 1, assign_horizontal_right
    beq $a3, 2, assign_vertical_down
    beq $a3, 3, assign_horizontal_left
    beq $a3, 0, assign_vertical_up

# Horizontal (right) → +4
assign_horizontal_right:

    # Store first half color
    add $t0, $t9, $a0         # Base + offset → $t0
    sw $a1, 0($t0)            # Store first half color
    add $t0, $t8, $a0
    addi $t2, $a0, 4
    sw $t2, 0($t0)
  
    addi $t1, $a0, 4          # Offset +4 (one cell right)
    add $t2, $t9, $t1         # Base + computed offset → $t2
    sw $a2, 0($t2)            # Store second half color
    add $t2, $t8, $t1
    sw $a0, 0($t2)
    j assign_second_half

# Vertical (down) → +128
assign_vertical_down:
    # Store first half color
    add $t0, $t9, $a0         # Base + offset → $t0
    sw $a2, 0($t0)            # Store first half color
    add $t0, $t8, $a0
    addi $t2, $a0, -128
    sw $t2, 0($t0)
    
  
    addi $t1, $a0, -128        # Offset +128 (one row down)
    add $t2, $t9, $t1         # Base + computed offset → $t2
    sw $a1, 0($t2)            # Store second half color
    add $t2, $t8, $t1
    sw $a0, 0($t2)
    j assign_second_half

# Horizontal flipped (left) → -4
assign_horizontal_left:
    # Store first half color
    add $t0, $t9, $a0         # Base + offset → $t0
    sw $a2, 0($t0)            # Store first half color
    add $t0, $t8, $a0
    addi $t2, $a0, 4
    sw $t2, 0($t0)
  
    addi $t1, $a0, 4          # Offset +4 (one cell right)
    add $t2, $t9, $t1         # Base + computed offset → $t2
    sw $a1, 0($t2)            # Store second half color
    add $t2, $t8, $t1
    sw $a0, 0($t2)
    j assign_second_half

# Vertical flipped (up) → -128
assign_vertical_up:
    # Store first half color
    add $t0, $t9, $a0         # Base + offset → $t0
    sw $a1, 0($t0)            # Store first half color
    add $t0, $t8, $a0
    addi $t2, $a0, -128
    sw $t2, 0($t0)
  
    addi $t1, $a0, -128        # Offset +128 (one row down)
    add $t2, $t9, $t1         # Base + computed offset → $t2
    sw $a2, 0($t2)            # Store second half color
    add $t2, $t8, $t1
    sw $a0, 0($t2)
    j assign_second_half

# Store second half color
assign_second_half:
    jr $ra                    # Return to caller
    
###### Make the playing field for Dr.mario #######
draw_bottle:
    lw $t0, ADDR_DSPL       # $t0 = base address for display
    
    # Draw segment A
    draw_segment_A:
        sw $t4, 676($t0)
        sw $t4, 804($t0)

    # Draw segment G
    draw_segment_G:
        sw $t4, 700($t0) 
        sw $t4, 828($t0)

    # Loop for segment B
    add $t7, $t0, 772   # Set $t7 to base address + 772
    add $t5, $zero, $zero	# set $t5 to zero
    addi $t6, $zero, 8	# set $t6 to 8
    draw_segment_B:
        beq $t5, $t6, exit_segment_B
        sw $t4, 0($t7) 		# color the pixel
        addi $t5, $t5, 1    # increment the loop variable
        addi $t7, $t7, 4	# move 1 position to the right
        j draw_segment_B

    exit_segment_B:

    # Loop for segment C
    add $t7, $t0, 772   # Set $t7 to base address + 772
    add $t5, $zero, $zero	# set $t5 to zero
    addi $t6, $zero, 24	# set $t6 to 24
    draw_segment_C:
        beq $t5, $t6, exit_segment_C
        sw $t4, 0($t7) 		# color the pixel
        addi $t5, $t5, 1    # increment the loop variable
        addi $t7, $t7, 128	# move 1 position downwards 
        j draw_segment_C

    exit_segment_C:

    # Loop for segment D
    add $t7, $t0, 3844   # Set $t7 to base address + 3844
    add $t5, $zero, $zero	# set $t5 to zero
    addi $t6, $zero, 23	# set $t6 to 24
    
    draw_segment_D:
        beq $t5, $t6, exit_segment_D
        sw $t4, 0($t7) 		# color the pixel
        addi $t5, $t5, 1    # increment the loop variable
        addi $t7, $t7, 4	# move 1 position to the right 
        j draw_segment_D

    exit_segment_D:

    add $t7, $t0, 860   # Set $t7 to base address + 860
    add $t5, $zero, $zero	# set $t5 to zero
    addi $t6, $zero, 24	# set $t6 to 24
    draw_segment_E:
        beq $t5, $t6, exit_segment_E
        sw $t4, 0($t7) 		# color the pixel
        addi $t5, $t5, 1    # increment the loop variable
        addi $t7, $t7, 128	# move 1 position downwards 
        j draw_segment_E

    exit_segment_E:
      
    add $t7, $t0, 828   # Set $t7 to base address + 772
    add $t5, $zero, $zero	# set $t5 to zero
    addi $t6, $zero, 8	# set $t6 to 8
    draw_segment_F:
        beq $t5, $t6, exit_segment_F
        sw $t4, 0($t7) 		# color the pixel
        addi $t5, $t5, 1    # increment the loop variable
        addi $t7, $t7, 4	# move 1 position to the right
        j draw_segment_F
    exit_segment_F:
    
    jr $ra # the bottle is crated, back to main
        

###### Draw a two-halved capsule with random colors ######
draw_curr_capsule:
    # -------- Top Half --------
    li $v0, 42           # Syscall 42 = random integer
    li $a0, 0            # Lower bound = 0
    li $a1, 3            # Upper bound = 3 (non-inclusive)
    syscall              # Generate random number -> result in $a0

    # Map value to color for top half
    beq $a0, 0, set_red_top
    beq $a0, 1, set_yellow_top
    beq $a0, 2, set_blue_top

set_red_top:
    li $s1, 0xFF0000     # Top color = Red
    j generate_bottom

set_yellow_top:
    li $s1, 0xFFFF00     # Top color = Yellow
    j generate_bottom

set_blue_top:
    li $s1, 0x0000FF     # Top color = Blue
    
# -------- Bottom Half --------
generate_bottom:
    li $v0, 42           # Syscall 42 = random integer
    li $a0, 0            # Lower bound = 0
    li $a1, 3            # Upper bound = 3 (non-inclusive)
    syscall              # Generate random number -> result in $a0

    # Map value to color for bottom half
    beq $a0, 0, set_red_bottom
    beq $a0, 1, set_yellow_bottom
    beq $a0, 2, set_blue_bottom

set_red_bottom:
    li $s2, 0xFF0000     # Bottom color = Red
    j end_draw_capsule

set_yellow_bottom:
    li $s2, 0xFFFF00     # Bottom color = Yellow
    j end_draw_capsule

set_blue_bottom:
    li $s2, 0x0000FF     # Bottom color = Blue

##### Also add the current capsules #####
end_draw_capsule:
    addi $sp, $sp, -4       # Create stack space
    sw $ra, 0($sp)          # Save $ra before the first call
    
    lw $t0, ADDR_DSPL

    # INITIALIZE ORIENTATION
    li $s3, 0                   # Set up vertical orientation
    
    # ASSIGN LOCATION  
    li $a0, 12               # x = 12
    li $a1, 6                # y = 6
    jal get_offset           # Compute offset

    lw $t0, ADDR_DSPL
    add $s0, $t0, $v0         # Store bottom capsule address in $s0

    # ASSIGN assign_capsule_color
    move $a0, $v0            # Use $s0 as input for $a0
    move $a1, $s1            # Load color for first half
    move $a2, $s2            # Load color for second half
    move $a3, $s3            # Load orientation
    jal assign_capsule_color # Call the function

    # ASSIGN pair address
    lw $t9, ADDR_DSPL          # Load base address of display
    sub $a0, $s0, $t9          # $a0 = s0 - base address
    move $a1, $s3              # Set orientation    
    # a0 : the current offset
    # a1 : the current orientation

    # Restore $ra and clean up stack
    lw $ra, 0($sp)          # Restore $ra
    addi $sp, $sp, 4        # Clean up stack

    jr $ra                  # Return to caller

########

# ------------------------------
# Function to place 4 random viruses
# ------------------------------
place_viruses:
    # Save $ra (caller return address)
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    li $s4, 4               # Number of viruses to place
virus_loop:
    # -------- Generate Random x --------
    li $v0, 42
    li $a0, 0
    li $a1, 21
    syscall
    addi $s0, $a0, 2        # $s0 = x position

    # -------- Generate Random y --------
    li $v0, 42
    li $a0, 0
    li $a1, 12
    syscall
    addi $s1, $a0, 18       # $s1 = y position

    # -------- Generate Random Color --------
    li $v0, 42
    li $a0, 0
    li $a1, 3
    syscall
    beq $a0, 0, set_red_virus
    beq $a0, 1, set_blue_virus
    beq $a0, 2, set_yellow_virus

set_red_virus:
    li $t3, 0xFF0000
    j place_virus

set_blue_virus:
    li $t3, 0x0000FF
    j place_virus

set_yellow_virus:
    li $t3, 0xFFFF00

place_virus:
    # Save $ra for nested calls
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    move $a0, $s0
    move $a1, $s1
    jal get_offset

    lw $t0, ADDR_DSPL
    add $t1, $t0, $v0
    la $t0, PAIR_TRACKER
    add $t4, $t0, $v0
    li $t5, -2     # pair value of virus
    sw $t3, 0($t1)
    sw $t5, 0($t4)

    # Restore $ra for nested call
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    # -------- Repeat until 4 viruses are placed --------
    subi $s4, $s4, 1
    bnez $s4, virus_loop

    # Restore $ra for the outer function
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    
    jr $ra                   # Return to caller

game_loop:
    # 1a. Check if key has been pressed

    lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t8, 0($t0)                  # Load first word from keyboard
    beq $t8, 1, keyboard_input      # If first word 1, key is pressed

    # If it's not 1, jump into cancel_move_or_skip
    j cancel_move_or_skip
    
    # 1b. Check which key has been pressed
    
    keyboard_input:
    # Load the actual key value into $t2
    lw $t2, 4($t0)                  # Read second word (ASCII value)
    # Handle movement
    beq $t2, 0x77, rotate_clockwise      # 'w'
    beq $t2, 0x61, move_left    # 'a'
    beq $t2, 0x73, move_down    # 's'
    beq $t2, 0x64, move_right   # 'd'
    beq $t2, 0x71, quit_game    # 'q'
    beq $t2, 0x70, pause_game   # 'p'

    # If not any of the above, skip
    j cancel_move_or_skip
    
#### ACTION ####
#### PAUSE GAME############
pause_game:
# loop untill p is pressed again
    lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t8, 0($t0)                  # Load first word from keyboard
    beq $t8, 0, pause_game      # If first word 0, stay in loop 
    
    # Check if p has been pressed
    # Load the actual key value into $t2
    lw $t2, 4($t0)                  # Read second word (ASCII value)
    # if p is pressed, unpause 
    beq $t2, 0x70, unpause



    # Draw the pause message 
    li   $t1, 0xffffff # t1 = colour white 

	
	li $t5, 0x000000        # $t5 = black

		# paint the screen black using a loop

		lw   $t0, ADDR_DSPL    # $t0 = base address of the display
    li   $t9, 0    # $t9 = counter for loop 
		li   $t8, 0    # $t8 = offset for display
          
    # start drawing the pause message on the first 4 lines 
    # $t1 holds the white color.
    li   $t1, 0xffffff

    # Load the base address of the display into $t0.
    lw   $t0, ADDR_DSPL

    ######################################################################
    # Helper macro (pseudo) to compute offset = ((row * 32) + col) * 4
    # We'll do it manually for each pixel in the message.
    #
    # row0 = 0, row1 = 1, row2 = 2, row3 = 3
    ######################################################################

    ######################################################################
    # Letter P at columns 1..3 (with one space before it)
    # Pattern (3 wide x 4 tall):
    # Row0: ###  (cols 1..3)
    # Row1: # #  (cols 1,3)
    # Row2: ###  (cols 1..3)
    # Row3: #    (col 1)
    ######################################################################
    # Row0
    # offset = ((0 * 32) + 1) * 4 = 4
    sw $t1, 4($t0)              # col=1, row=0
    sw $t1, 8($t0)              # col=2, row=0
    sw $t1, 12($t0)             # col=3, row=0

    # Row1
    # offset for (col=1, row=1) = ((1 * 32) + 1)*4 = (32+1)*4 = 132
    sw $t1, 132($t0)            # col=1, row=1
    sw $t1, 140($t0)            # col=3, row=1

    # Row2
    # offset row=2, col=1..3
    sw $t1, 260($t0)            # col=1, row=2 => ((2*32)+1)*4= (64+1)*4=260
    sw $t1, 264($t0)            # col=2, row=2
    sw $t1, 268($t0)            # col=3, row=2

    # Row3
    # offset row=3, col=1
    sw $t1, 388($t0)            # ((3*32)+1)*4= ((96)+1)*4= 388

    ######################################################################
    # Letter A at columns 5..7 (one column of space after P)
    # Pattern (3 wide x 4 tall):
    # Row0: ###  (cols 5..7)
    # Row1: # #  (cols 5,7)
    # Row2: ###  (cols 5..7)
    # Row3: # #  (cols 5,7)
    ######################################################################
    # Row0
    sw $t1, 20($t0)             # row=0,col=5 => offset= (0*32+5)*4=20
    sw $t1, 24($t0)             # col=6
    sw $t1, 28($t0)             # col=7

    # Row1 (row=1)
    sw $t1, 148($t0)            # col=5 => offset= ((1*32)+5)*4= (32+5)*4=148
    sw $t1, 156($t0)            # col=7 => offset= ((1*32)+7)*4=156

    # Row2 (row=2)
    sw $t1, 276($t0)            # col=5 => (2*32+5)*4= (64+5)*4=276
    sw $t1, 280($t0)            # col=6
    sw $t1, 284($t0)            # col=7

    # Row3 (row=3)
    sw $t1, 404($t0)            # col=5 => (3*32+5)*4= (96+5)*4=404
    sw $t1, 412($t0)            # col=7 => offset=412

    ######################################################################
    # Letter U at columns 9..11
    # Pattern (3 wide x 4 tall):
    # Row0: # #
    # Row1: # #
    # Row2: # #
    # Row3: ###
    ######################################################################
    # Row0 (row=0): col=9, col=11
    sw $t1, 36($t0)             # col=9 => offset= (0*32+9)*4=36
    sw $t1, 44($t0)             # col=11 => offset=44

    # Row1 (row=1): col=9, col=11
    sw $t1, 164($t0)            # (1*32+9)*4= (32+9)*4=164
    sw $t1, 172($t0)            # col=11 => offset=172

    # Row2 (row=2): col=9, col=11
    sw $t1, 292($t0)
    sw $t1, 300($t0)

    # Row3 (row=3): col=9..11 => full line
    sw $t1, 420($t0)            # col=9 => (3*32+9)*4=420
    sw $t1, 424($t0)            # col=10
    sw $t1, 428($t0)            # col=11

    ######################################################################
    # Letter S at columns 13..15
    # Pattern (3 wide x 4 tall):
    # Row0: ###
    # Row1: #
    # Row2: ###
    # Row3:   #
    ######################################################################
    # Row0 (row=0): col=13..15
    sw $t1, 52($t0)             
    sw $t1, 56($t0)
    sw $t1, 60($t0)
    # Row1 (row=1): col=13
    sw $t1, 180($t0)
    # Row2 (row=2): col=13..15
    sw $t1, 308($t0)
    sw $t1, 312($t0)
    sw $t1, 316($t0)
    # Row3 (row=3): col=15
    sw $t1, 444($t0)

    ######################################################################
    # Letter E at columns 17..19
    # Pattern (3 wide x 4 tall):
    # Row0: ###
    # Row1: #
    # Row2: ###
    # Row3: ###
    ######################################################################
    # Row0 (row=0): col=17..19
    sw $t1, 68($t0)
    sw $t1, 72($t0)
    sw $t1, 76($t0)
    # Row1 (row=1): col=17
    sw $t1, 196($t0)
    # Row2 (row=2): col=17..19
    sw $t1, 324($t0)
    sw $t1, 328($t0)
    sw $t1, 332($t0)
    # Row3 (row=3): col=17..19
    sw $t1, 452($t0)
    sw $t1, 456($t0)
    sw $t1, 460($t0)

    ######################################################################
    # Letter D at columns 21..23
    # Pattern (3 wide x 4 tall):
    # Row0: ###
    # Row1: # #
    # Row2: # #
    # Row3: ###
    ######################################################################
    # Row0 (row=0): col=21..23
    sw $t1, 84($t0)
    sw $t1, 88($t0)
    sw $t1, 92($t0)
    # Row1 (row=1): col=21, col=23
    sw $t1, 212($t0)
    sw $t1, 220($t0)
    # Row2 (row=2): col=21, col=23
    sw $t1, 340($t0)
    sw $t1, 348($t0)
    # Row3 (row=3): col=21..23
    sw $t1, 468($t0)
    sw $t1, 472($t0)
    sw $t1, 476($t0)

    # Done drawing "PAUSED" on rows 0..3
    # loop untill p 
    j pause_game
    
        unpause: 
      # clear the first 3 rows
          	li   $t1, 0xffffff # t1 = colour white 
    
    	
    	li $t5, 0x000000        # $t5 = black
    
    		# paint the screen black using a loop
    
    		lw   $t0, ADDR_DSPL    # $t0 = base address of the display
        li   $t9, 0    # $t9 = counter for loop 
    		li   $t8, 0    # $t8 = offset for display
    		
    		clear_screen_loop_used_in_pause:
    			beq $t9, 128, game_loop
    			add $t7, $t0, $t8   # compute offset of display 
    	    sw   $t5, 0($t7)     # Write black (0x000000) to the current location
    	    addi $t8, $t8, 4       # Move to the next word (4 bytes)
    	    addi $t9, $t9, 1      # incrase the counter
    	    j clear_screen_loop_used_in_pause # Loop until all units are cleared

### ROTATE CLOCKWISE ###
rotate_clockwise: 

    # play a sound effect for rotation
    li $v0, 31 
    li $a0, 60
    li $a1, 300
    li $a2, 1
    li $a3, 100

    syscall
    
    jal erase_capsule

    # Load base address
    lw $t9, ADDR_DSPL         # Load base address into $t9
    
    # Extract x, y of current capsule (pivot)
    sub $t0, $s0, $t9         # Subtract base address to get offset
    srl $t0, $t0, 2           # Divide by 4 to get index
    div $t0, $t0, 32          # Divide by row size
    mflo $t1                  # y_pivot
    mfhi $t2                  # x_pivot

    # Update orientation (cycle between 0 → 1 → 2 → 3 → 0)
    addi $s3, $s3, 1          # Increment orientation
    andi $s3, $s3, 3          # Wrap value between 0 and 3

    # Compute new position for the other half based on new orientation
    beq $s3, 1, compute_horizontal_right
    beq $s3, 2, compute_vertical_down
    beq $s3, 3, compute_horizontal_left
    beq $s3, 0, compute_vertical_up

compute_horizontal_right:
    addi $t3, $t2, 1          # x_other = x_pivot + 1
    move $t4, $t1             # y_other = y_pivot
    j compute_done

compute_vertical_down:
    move $t3, $t2             # x_other = x_pivot
    subi $t4, $t1, 1          # y_other = y_pivot + 1
    j compute_done

compute_horizontal_left:
    addi $t3, $t2, 1          # x_other = x_pivot - 1
    move $t4, $t1             # y_other = y_pivot
    j compute_done

compute_vertical_up:
    move $t3, $t2             # x_other = x_pivot
    subi $t4, $t1, 1          # y_other = y_pivot
    j compute_done

compute_done:
    # Get new offset for computed half
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    move $a0, $t3              # New x_other → $a0
    move $a1, $t4              # New y_other → $a1
    jal get_offset

    lw $t9, ADDR_DSPL 
    # Compute new address
    add $t6, $t9, $v0          # Base + offset → new address
    
    # Check collision for new position
    lw $t0, 0($t6)
    bnez $t0, cancel_rotation   # If occupied → cancel rotation

    # Rotation is valid → Commit state
    # move $s0, $t6              # The rotated part becomes the new stored half

    lw $ra, 0($sp)             # Restore return address
    addi $sp, $sp, 4
    j done_rotation

cancel_rotation:
    # Subtract 1 from orientation
    addi $s3, $s3, -1           # Decrement orientation
    bgez $s3, end_wrap_check     # If $s3 >= 0, skip wrap
    li $s3, 3                   # If $s3 < 0, wrap to 3

    end_wrap_check:
  
    lw $ra, 0($sp)             # Restore return address
    addi $sp, $sp, 4
    j done_rotation

done_rotation:
    j cancel_move_or_skip

### MOVE RIGHT ###

move_right:
    # play a sound effect for rotation
    li $v0, 31 
    li $a0, 67
    li $a1, 300
    li $a2, 1
    li $a3, 100

    syscall
    jal erase_capsule          # Erase current capsule
    
    addi $t6, $s0, 4           # Right shift for stored half
    
    beq $s3, 1, move_right_horizontal
    beq $s3, 2, move_right_vertical
    beq $s3, 3, move_right_horizontal_flipped
    beq $s3, 0, move_right_vertical_flipped

move_right_horizontal:
    addi $t7, $t6, 4           # Right shift for computed half
    j check_collision

move_right_vertical:
    addi $t7, $t6, -128         # Down shift for computed half
    j check_collision

move_right_horizontal_flipped:
    addi $t7, $t6, 4           # Left shift for computed half
    j check_collision

move_right_vertical_flipped:
    addi $t7, $t6, -128          # Up shift for computed half
    j check_collision


### MOVE DOWN ###
move_down:
    # play a sound effect for rotation
    li $v0, 31 
    li $a0, 64
    li $a1, 300
    li $a2, 1
    li $a3, 100

    syscall
    jal erase_capsule          # Erase current capsule
  
    addi $t6, $s0, 128         # Down shift for top half
    
    beq $s3, 1, move_down_horizontal
    beq $s3, 2, move_down_vertical
    beq $s3, 3, move_down_horizontal_flipped
    beq $s3, 0, move_down_vertical_flipped

move_down_horizontal:
    addi $t7, $t6, 4          # Right shift for computed half
    j check_vertical_collision

move_down_vertical:
    addi $t7, $t6, -128        # Down shift for computed half
    j check_vertical_collision

move_down_horizontal_flipped:
    addi $t7, $t6, 4          # Left shift for computed half
    j check_vertical_collision

move_down_vertical_flipped:
    addi $t7, $t6, -128         # Up shift for computed half
    j check_vertical_collision

# CHECK VERTICAL COLLISSION
# Might implement check vertical collision
# If that's the case, we fix our current capsule and generate a new one which we will be controlling from now on
check_vertical_collision:
    lw $t0, 0($t6)
    bnez $t0, next_capsule

    lw $t1, 0($t7)
    bnez $t1, next_capsule
    
    # 2b. Update locations (capsules)
    # No collision → Commit state
    move $s0, $t6
    j cancel_move_or_skip

# We go to the next capsule
next_capsule:
    # If the code gets here then the entrance is not blocked

    # draw the current capsule in the current fixed place
    # ASSIGN assign_capsule_color
    lw $t1, ADDR_DSPL        # Load address into $t1
    sub $t0, $s0, $t1        # Now you can subtract the address
    
    move $a0, $t0            # Use $s0 as input for $a0
    move $a1, $s1            # Load color for first half
    move $a2, $s2            # Load color for second half
    move $a3, $s3            # Load orientation
    jal assign_capsule_color # Call the function
  
    # We check whether the entrance is blocked. If it is, we quit the game.
check_blocking_entrance:
    lw $t0, ADDR_DSPL        # Load base address of display

    # Start x = 10, y = 5 → Compute Offset
    li $a0, 10               # x = 10
    li $a1, 5                # y = 5
    jal get_offset           # Get offset for (10, 5)

    lw $t0, ADDR_DSPL        # Load base address of display
    add $t4, $t0, $v0        # Starting address of (10,5)

    # ---------- Check row 5 ----------
    li $t1, 5                # Row 5
    li $t2, 14               # x = 14 (end coordinate)

check_row_5:
    lw $t5, 0($t4)           # Load value at computed address
    
    bnez $t5, quit_game      # If non-zero → game over
    
    addi $t4, $t4, 4         # Move right (next column)
    
    addi $a0, $a0, 1         # Increment x-coordinate
    ble $a0, $t2, check_row_5

    # ---------- Check row 6 ----------
    li $a0, 10               # Reset x-coordinate
    li $a1, 6                # y = 6
    jal get_offset           # Get offset for (10, 6)

    lw $t0, ADDR_DSPL        # Load base address of display
    add $t4, $t0, $v0        # Starting address of (10,6)

check_row_6:
    lw $t5, 0($t4)           # Load value at computed address
    
    bnez $t5, quit_game      # If non-zero → game over
    
    addi $t4, $t4, 4         # Move right (next column)
    
    addi $a0, $a0, 1         # Increment x-coordinate
    ble $a0, $t2, check_row_6

#### REMOVE ANY 4 or more consecutive blocks with the same color
# at this point, s0 and s3 still refer to location and orientation of current capsule (not the new one)
# check_for_removal:
#     # ---------- First Half ----------
#     move $a0, $s0                # Store first half offset

#     jal check_single_removal

#     move $t1, $s3
#     # ---------- Compute Second Half ----------
#     beq $t1, 1, compute_horizontal_right_remove
#     beq $t1, 2, compute_vertical_down_remove
#     beq $t1, 3, compute_horizontal_left_remove
#     beq $t1, 0, compute_vertical_up_remove

# compute_horizontal_right_remove:
#     addi $a0, $s0, 4             # Offset +4 (right shift)
#     j check_second_half

# compute_vertical_down_remove:
#     addi $a0, $s0, -128           # Offset +128 (down shift)
#     j check_second_half

# compute_horizontal_left_remove:
#     addi $a0, $s0, 4             # Offset -4 (left shift)
#     j check_second_half

# compute_vertical_up_remove:
#     addi $a0, $s0, -128           # Offset -128 (up shift)

# check_second_half:
#     # a0 : the address of the block whose neighbour we want to check
#     jal check_single_removal

#### We then generate new capsules
    jal check_full_removal

generate_new_capsule:
    jal draw_curr_capsule  # This will draw new capsule at (12,6) and (12, 5)

    j sleep    

### MOVE LEFT ###

move_left:
    # play a sound effect for move
    li $v0, 31 
    li $a0, 62
    li $a1, 300
    li $a2, 1
    li $a3, 100

    syscall
    jal erase_capsule          # Erase current capsule
    
    subi $t6, $s0, 4          # Try shifting stored half to the left
    
    beq $s3, 1, move_left_horizontal
    beq $s3, 2, move_left_vertical
    beq $s3, 3, move_left_horizontal_flipped
    beq $s3, 0, move_left_vertical_flipped

move_left_horizontal:
    addi $t7, $t6, 4          # Left shift for computed half
    j check_collision

move_left_vertical:
    addi $t7, $t6, -128        # Down shift for computed half
    j check_collision

move_left_horizontal_flipped:
    addi $t7, $t6, 4          # Right shift for computed half
    j check_collision

move_left_vertical_flipped:
    addi $t7, $t6, -128         # Up shift for computed half
    j check_collision

check_collision:
    lw $t0, 0($t6)
    bnez $t0, cancel_move_or_skip

    lw $t1, 0($t7)
    bnez $t1, cancel_move_or_skip
    
    # 2b. Update locations (capsules)
    # No collision → Commit state
    move $s0, $t6

    # If we cancel the shift movements due to collision or done doing rotation (or canceled rotation)



cancel_move_or_skip:
    # Maybe we can implement the falling here (check if the positions directly below them are filled with colored blocks, if no:shift the capsule down by one
    # if yes: the current capsule stops moving and check for coloring and potential breaking, then we go to next capsule)
    
	# 3. Draw the screen
    # ASSIGN assign_capsule_color
    lw $t1, ADDR_DSPL        # Load address into $t1
    sub $t0, $s0, $t1        # Now you can subtract the address
    
    move $a0, $t0            # Use $s0 as input for $a0
    move $a1, $s1            # Load color for first half
    move $a2, $s2            # Load color for second half
    move $a3, $s3            # Load orientation
    jal assign_capsule_color # Call the function
    
	# 4. Sleep
    # Refresh at 60 FPS
    sleep:
    # ------- Before we sleep, we check for unsupported ---------


# check_for_removal:
#     li $t0, 0                  # Row index = 0

# loop_rows:
#     li $t1, 0                  # Column index = 0

# loop_columns:
#     # ---------- Compute Offset ----------
#     mul $t2, $t0, 32           # Row offset → t2 = y * 32
#     add $t2, $t2, $t1          # Add column offset → t2 = y * 32 + x
#     sll $t2, $t2, 2            # Multiply by 4 → offset in bytes

#     # ---------- Add base address ----------
#     lw $t3, ADDR_DSPL          # Load base address into $t3
#     add $a0, $t3, $t2          # a0 = address of pixel at (x, y)

#     # ---------- Call Removal Check ----------
#     jal check_single_removal

#     # ---------- Next Column ----------
#     addi $t1, $t1, 1
#     bne $t1, 32, loop_columns

#     # ---------- Next Row ----------
#     addi $t0, $t0, 1
#     bne $t0, 32, loop_rows

# end_check:
#     jr $ra
    
    # Make all unsupported blocks fall
    jal fall_unsupported
    # ------------------------------
    
    li $v0, 32              # Sleep syscall
    li $a0, 16              # 16 milliseconds delay
    syscall

    # 5. Go back to Step 1
    j game_loop

    quit_game:
            # play a sound effect for pressing q
        li $v0, 31 
        li $a0, 60
        li $a1, 300
        li $a2, 22
        li $a3, 100
    
        syscall
		  # Eric: Edited this function to implment easy feature 4
		  # Display a game over menu, give the option to restart if needed, press q to quit the prgram, and press r to restart the game

			# Draw the gameover text
		j draw_game_over_message_in_pixel

		after_drawing_game_over_pixel:
			
	    lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
	    lw $t8, 0($t0)                  # Load first word from keyboard
	    beq $t8, 1, keyboard_input_game_over_screen      # If first word 1, key is pressed
	    
	    # 1b. Check which key has been pressed
	    # If not any of the above, repeat to wait for input
	    j after_drawing_game_over_pixel
			
	    keyboard_input_game_over_screen:
	    # Load the actual key value into $t2
	    lw $t2, 4($t0)                  # Read second word (ASCII value)
	    # Handle movement
	    beq $t2, 0x72, restart_game   # 'r'
	    beq $t2, 0x71, exit_game    # 'q'
	
	    

			restart_game:
                  # play a sound effect for pressing r
                  li $v0, 31 
                  li $a0, 60
                  li $a1, 300
                  li $a2, 23
                  li $a3, 100
              
                  syscall
				j main
			exit_game:
                  # play a sound effect for pressing q
        li $v0, 31 
        li $a0, 60
        li $a1, 300
        li $a2, 22
        li $a3, 100
    
        syscall
	      li $v0, 10
	      syscall





draw_game_over_message_in_pixel:
	li   $t1, 0xffffff # t1 = colour white 

	
	li $t5, 0x000000        # $t5 = black

		# paint the screen black using a loop

		lw   $t0, ADDR_DSPL    # $t0 = base address of the display
    li   $t9, 0    # $t9 = counter for loop 
		li   $t8, 0    # $t8 = offset for display
		
		clear_screen_loop_used_in_drawing_game_over:
			beq $t9, 1024, continue_drawing_game_over
			add $t7, $t0, $t8   # compute offset of display 
	    sw   $t5, 0($t7)     # Write black (0x000000) to the current location
	    addi $t8, $t8, 4       # Move to the next word (4 bytes)
	    addi $t9, $t9, 1      # incrase the counter
	    j clear_screen_loop_used_in_drawing_game_over  # Loop until all units are cleared

		continue_drawing_game_over:
    # -------------------------
    # Draw letter "G" (origin: row 14, col 0)
    # Pattern for G (4×5):
    #   Row0: 1 1 1 0
    #   Row1: 1 0 0 0
    #   Row2: 1 0 1 1
    #   Row3: 1 0 0 1
    #   Row4: 1 1 1 1
    # -------------------------
    # Row0: row = 14 → pixels at cols 0,1,2.
    li   $t2, 1792            # (14*32+0)*4 = (448+0)*4 = 448*4 = 1792.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1796            # (14*32+1)*4 = 449*4 = 1796.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1800            # (14*32+2)*4 = 450*4 = 1800.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row1: row = 15 → pixel at col 0.
    li   $t2, 1920            # (15*32+0)*4 = (480+0)*4 = 480*4 = 1920.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row2: row = 16 → pixels at cols 0,2,3.
    li   $t2, 2048            # (16*32+0)*4 = (512+0)*4 = 512*4 = 2048.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2056            # (16*32+2)*4 = (512+2)*4 = 514*4 = 2056.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2060            # (16*32+3)*4 = 515*4 = 2060.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row3: row = 17 → pixels at cols 0 and 3.
    li   $t2, 2176            # (17*32+0)*4 = (544+0)*4 = 544*4 = 2176.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2188            # (17*32+3)*4 = (544+3)*4 = 547*4 = 2188.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row4: row = 18 → pixels at cols 0,1,2,3.
    li   $t2, 2304            # (18*32+0)*4 = (576+0)*4 = 576*4 = 2304.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2308            # (18*32+1)*4 = 577*4 = 2308.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2312            # (18*32+2)*4 = 578*4 = 2312.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2316            # (18*32+3)*4 = 579*4 = 2316.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    
    # -------------------------
    # Draw letter "A" (origin: row 14, col 4)
    # Pattern for A (4×5):
    #   Row0: 0 1 1 0
    #   Row1: 1 0 0 1
    #   Row2: 1 1 1 1
    #   Row3: 1 0 0 1
    #   Row4: 1 0 0 1
    # -------------------------
    # For letter A, add 4 to each column.
    # Row0: row 14 → white at relative cols 1,2 → absolute cols: 5,6.
    li   $t2, 1812            # (14*32+5)*4 = 1812.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1816            # (14*32+6)*4 = 1816.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row1: row 15 → white at relative cols 0,3 → absolute cols: 4,7.
    li   $t2, 1936            # (15*32+4)*4 = 1936.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1948            # (15*32+7)*4 = 1948.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row2: row 16 → white at relative cols 0,1,2,3 → absolute: 4,5,6,7.
    li   $t2, 2064            # (16*32+4)*4 = 2064.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2068            # (16*32+5)*4 = 2068.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2072            # (16*32+6)*4 = 2072.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2076            # (16*32+7)*4 = 2076.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row3: row 17 → white at relative cols 0,3 → absolute: 4,7.
    li   $t2, 2192            # (17*32+4)*4 = 2192.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2204            # (17*32+7)*4 = 2204.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row4: row 18 → white at relative cols 0,3 → absolute: 4,7.
    li   $t2, 2320            # (18*32+4)*4 = 2320.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2332            # (18*32+7)*4 = 2332.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    
    # -------------------------
    # Draw letter "M" (origin: row 14, col 8)
    # Pattern for M (4×5):
    #   Row0: 1 0 0 1
    #   Row1: 1 1 1 1
    #   Row2: 1 0 0 1
    #   Row3: 1 0 0 1
    #   Row4: 1 0 0 1
    # -------------------------
    # For letter M, col base = 8.
    # Row0: row 14 → white at relative cols 0 and 3 → absolute: 8, 11.
    li   $t2, 1824            # (14*32+8)*4 = 1824.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1836            # (14*32+11)*4 = 1836.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row1: row 15 → white at relative cols 0,1,2,3 → absolute: 8,9,10,11.
    li   $t2, 1952            # (15*32+8)*4 = 1952.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1956            # (15*32+9)*4 = 1956.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1960            # (15*32+10)*4 = 1960.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1964            # (15*32+11)*4 = 1964.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row2: row 16 → white at relative cols 0 and 3 → absolute: 8,11.
    li   $t2, 2080            # (16*32+8)*4 = 2080.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2092            # (16*32+11)*4 = 2092.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row3: row 17 → white at relative cols 0 and 3 → absolute: 8,11.
    li   $t2, 2208            # (17*32+8)*4 = 2208.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2220            # (17*32+11)*4 = 2220.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row4: row 18 → white at relative cols 0 and 3 → absolute: 8,11.
    li   $t2, 2336            # (18*32+8)*4 = 2336.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2348            # (18*32+11)*4 = 2348.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    
    # -------------------------
    # Draw letter "E" (origin: row 14, col 12)
    # Pattern for E (4×5):
    #   Row0: 1 1 1 1
    #   Row1: 1 0 0 0
    #   Row2: 1 1 1 0
    #   Row3: 1 0 0 0
    #   Row4: 1 1 1 1
    # -------------------------
    # For letter E, col base = 12.
    # Row0: row 14 → white at relative cols 0,1,2,3 → absolute: 12,13,14,15.
    li   $t2, 1840            # (14*32+12)*4 = 1840.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1844            # 1844.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1848            # 1848.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1852            # 1852.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row1: row 15 → white at relative col0 → absolute: 12.
    li   $t2, 1968            # (15*32+12)*4 = 1968.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row2: row 16 → white at relative cols 0,1,2 → absolute: 12,13,14.
    li   $t2, 2096            # (16*32+12)*4 = 2096.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2100            # 2100.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2104            # 2104.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row3: row 17 → white at relative col0 → absolute: 12.
    li   $t2, 2224            # (17*32+12)*4 = 2224.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row4: row 18 → white at relative cols 0,1,2,3 → absolute: 12,13,14,15.
    li   $t2, 2352            # (18*32+12)*4 = 2352.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2356
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2360
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2364
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    
    # -------------------------
    # Draw letter "O" (origin: row 14, col 16)
    # Pattern for O (4×5):
    #   Row0: 0 1 1 0
    #   Row1: 1 0 0 1
    #   Row2: 1 0 0 1
    #   Row3: 1 0 0 1
    #   Row0: 0 1 1 0
    # -------------------------
    # For letter O, col base = 16.
    # Row0: row 14 → white at relative cols 1,2 → absolute: 17,18.
    li   $t2, 1860            # (14*32+17)*4 = 1860.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1864            # (14*32+18)*4 = 1864.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row1: row 15 → white at relative cols 0,3 → absolute: 16,19.
    li   $t2, 1984            # (15*32+16)*4 = 1984.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1996            # (15*32+19)*4 = 1996.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row2: row 16 → white at relative cols 0,3 → absolute: 16,19.
    li   $t2, 2112            # (16*32+16)*4 = 2112.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2124            # (16*32+19)*4 = 2124.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row3: row 17 → white at relative cols 0,3 → absolute: 16,19.
    li   $t2, 2240            # (17*32+16)*4 = 2240.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2252            # (17*32+19)*4 = 2252.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row4: row 18 → white at relative cols 1,2 → absolute: 17,18.
    li   $t2, 2372            # (18*32+17)*4 = 2372.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2376            # (18*32+18)*4 = 2376.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    
    # -------------------------
    # Draw letter "V" (origin: row 14, col 20)
    # Pattern for V (4×5):
    #   Row0: 1 0 0 1
    #   Row1: 1 0 0 1
    #   Row2: 1 0 0 1
    #   Row3: 0 1 1 0
    #   Row4: 0 0 0 0
    # -------------------------
    # For letter V, col base = 20.
    # Row0: row 14 → white at relative cols 0,3 → absolute: 20,23.
    li   $t2, 1872            # (14*32+20)*4 = 1872.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1884            # (14*32+23)*4 = 1884.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row1: row 15 → white at relative cols 0,3 → absolute: 20,23.
    li   $t2, 2000            # (15*32+20)*4 = 2000.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2012            # (15*32+23)*4 = 2012.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row2: row 16 → white at relative cols 0,3 → absolute: 20,23.
    li   $t2, 2128            # (16*32+20)*4 = 2128.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2140            # (16*32+23)*4 = 2140.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row3: row 17 → white at relative cols 1,2 → absolute: 21,22.
    li   $t2, 2260            # (17*32+21)*4 = 2260.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2264            # (17*32+22)*4 = 2264.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    
    # -------------------------
    # Draw letter "E" (origin: row 14, col 24)
    # Pattern for E: same as previous E.
    # For letter E, col base = 24.
    # Row0: row 14 → white at absolute: 24,25,26,27.
    li   $t2, 1888            # (14*32+24)*4 = 1888.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1892            # 1892.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1896            # 1896.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1900            # 1900.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row1: row 15 → white at absolute: 24.
    li   $t2, 2016            # (15*32+24)*4 = 2016.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row2: row 16 → white at absolute: 24,25,26.
    li   $t2, 2144            # (16*32+24)*4 = 2144.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2148            # 2148.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2152            # 2152.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row3: row 17 → white at absolute: 24.
    li   $t2, 2272            # (17*32+24)*4 = 2272.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row4: row 18 → white at absolute: 24,25,26,27.
    li   $t2, 2400            # (18*32+24)*4 = 2400.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2404            # 2404.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2408            # 2408.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2412            # 2412.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    
    # -------------------------
    # Draw letter "R" (origin: row 14, col 28)
    # Pattern for R (4×5):
    #   Row0: 1 1 1 0
    #   Row1: 1 0 0 1
    #   Row2: 1 1 1 0
    #   Row3: 1 0 1 0
    #   Row4: 1 0 0 1
    # For letter R, col base = 28.
    # Row0: row 14 → white at relative cols 0,1,2 → absolute: 28,29,30.
    li   $t2, 1904            # (14*32+28)*4 = 1904.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1908            # 1908.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 1912            # 1912.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row1: row 15 → white at relative cols 0,3 → absolute: 28,31.
    li   $t2, 2032            # (15*32+28)*4 = 2032.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2044            # (15*32+31)*4 = 2044.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row2: row 16 → white at relative cols 0,1,2 → absolute: 28,29,30.
    li   $t2, 2160            # (16*32+28)*4 = 2160.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2164            # 2164.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2168            # 2168.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row3: row 17 → white at relative cols 0,2 → absolute: 28,30.
    li   $t2, 2288            # (17*32+28)*4 = 2288.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2296            # (17*32+30)*4 = 2296.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    # Row4: row 18 → white at relative cols 0,3 → absolute: 28,31.
    li   $t2, 2416            # (18*32+28)*4 = 2416.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)
    li   $t2, 2428            # (18*32+31)*4 = 2428.
    add  $t3, $t0, $t2
    sw   $t1, 0($t3)



    
	j after_drawing_game_over_pixel
    #j draw_game_over_message_in_pixel
