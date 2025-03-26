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
    li $t3, -12                  # (-3) * 4 = -12 (left shift)
    li $t4, 12                   # (+3) * 4 = +12 (right shift)
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

    # INTEGRATED GRAVITY LOGIC
    # Load pair from PAIR_TRACKER
    la $t9, PAIR_TRACKER
    
    add $t9, $t9, $t3            # Get pair location in tracker
    lw $t5, 0($t9)               # Load pair offset

    beq $t5, -2, skip_gravity       # It's a virus
    beq $t5, -1, skip_gravity       # The pair is gone already
    beqz $t5, skip_gravity          # The pair does not exist
    
    # Check if pair still exists
    lw $t0, ADDR_DSPL
    add $t6, $t0, $t5
    lw $t0, 0($t6)               # load the value of the pair
    beqz $t0, skip_gravity       # Pair gone → skip gravity

    ### pair is intact at this point
    lw $t4, 0($t6)
    sw $zero, 0($t6)              # Set old position to black
    go_down:  
      addi $t1, $t0, 128   # check 1 position down
      bne $t1, $zero, fall_block_end # if it's not zero/empty, falling is done
      # if it's zero, we go go_down (store the position we test as our current position)
      move $t0, $t1  
      
    fall_block_end:
    sw $t4, 0($t0)
    
    # # Update PAIR_TRACKER
    # la $t9, PAIR_TRACKER
    # add $t9, $t9, $t3             # Old pair location
    # lw $t5, 0($t9)                # Load pair offset
    # addi $t5, $t5, 128            # New row offset
    # add $t9, $t9, 128
    # sw $t5, 0($t9)                # Store updated offset

skip_gravity:
    li $t1, -1              
    sw $t1, 0($t6)          # Store -1 at the pair address of the block we just removed
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

    # INTEGRATED GRAVITY LOGIC
    # Load pair from PAIR_TRACKER
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

    # FALLING LOGIC
    # If pair gone → Make it fall
    lw $t4, 0($t6)
    sw $zero, 0($t6)              # Remove pair block

fall_vertical:
    addi $t1, $t6, 128            # One row down
    lw $t2, 0($t1)                # Load cell below
    bnez $t2, end_fall_vertical    # If non-zero → Stop falling
    
    move $t6, $t1                 # Update current position
    j fall_vertical

end_fall_vertical:
    sw $t4, 0($t6)                # Drop block into new position
    
    # ✅ Update PAIR_TRACKER ✅
    la $t9, PAIR_TRACKER
    add $t9, $t9, $t3             # Old pair location
    lw $t5, 0($t9)                # Load pair offset
    addi $t5, $t5, 128            # Update for new row
    add $t9, $t9, 128
    sw $t5, 0($t9)                # Store updated pair info

skip_vertical_gravity:
    li $t1, -1
    sw $t1, 0($t9)                # Mark pair as gone
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
    sw $t3, 0($t1)

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

    # If not any of the above, skip
    j cancel_move_or_skip
    
#### ACTION ####

### ROTATE CLOCKWISE ###
rotate_clockwise: 
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

generate_new_capsule:
    jal draw_curr_capsule  # This will draw new capsule at (12,6) and (12, 5)

    j sleep    

### MOVE LEFT ###
move_left:
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
	    j clear_screen_loop  # Loop until all units are cleared

		continue_drawing_game_over:
	sw $t1, 512($t0)
	j after_drawing_game_over_pixel

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
    
    li $v0, 32              # Sleep syscall
    li $a0, 16              # 16 milliseconds delay
    syscall

    # 5. Go back to Step 1
    j game_loop

    quit_game:
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
	    j quit_game
			
	    keyboard_input_game_over_screen:
	    # Load the actual key value into $t2
	    lw $t2, 4($t0)                  # Read second word (ASCII value)
	    # Handle movement
	    beq $t2, 0x72, restart_game   # 'r'
	    beq $t2, 0x71, exit_game    # 'q'
	
	    

			restart_game:
				j main
			exit_game:
	      li $v0, 10
	      syscall