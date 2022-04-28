; iNES Header ==================================================================
    .inesprg 1   ; 16KB PRG code (x1)
    .ineschr 1   ; 8KB CHR data (x1)
    .inesmap 0   ; Mapper 0 = NROM (16KB PRG ROM and 8KB CHR ROM; No Swapping)
    .inesmir 2   ; Single Screen (No Scrolling)

; ______________________________________________________________________________
; ==============================================================================
; -------------------------------- VARIABLES -----------------------------------
; ==============================================================================
  	.rsset $0000	; Start defining variables at RAM location 0

PPU_STATUS	  = $2002
OAM_ADDR 	    = $2003
PPU_SCROLL   	= $2005
PPU_ADDR	    = $2006
PPU_DATA    	= $2007
OAM_DMA		    = $4014

; ----- Controller -------------------------------------------------------------
controller_1	 = $4016
controller_button .rs 1

; ----- Frog Sprites -----------------------------------------------------------
frog_tile_TL	= $0201
frog_tile_TR  = $0205
frog_tile_BL	= $0209
frog_tile_BR  = $020D

frog_y_TL     = $0200
frog_y_TR     = $0204
frog_y_BL     = $0208
frog_y_BR     = $020C

frog_x_TL     = $0203
frog_x_TR     = $0207
frog_x_BL     = $020B
frog_x_BR     = $020F

; ----- Counters ---------------------------------------------------------------
frog_stop_go      .rs 1
frog_direction    .rs 1
frog_distance     .rs 1

; ______________________________________________________________________________
; ==============================================================================
; ------------------------------- INIT CODE ------------------------------------
; ==============================================================================
    .bank 0
    .org $C000

RESET:
    SEI          ; Ignore IRQs (Interrupt Requests)
    CLD          ; Disable decimal mode (NES processor doesn't use decimals)
    ldx #$40
    stx $4017    ; Disable APU timer IRQs (If mapper generates IRQs)
    ldx #$ff
    txs          ; Set up stack
    inx
    stx $2000    ; Disable NMI
    stx $2001    ; Disable rendering
    stx $4010    ; Disable DMC IRQs

vblank_1:
    BIT PPU_STATUS
    BPL vblank_1

clear_memory:
    LDA #$00		  ; Load accumulator with memory $00 (0)
    STA $0000, x	; Store accumulator (x = $00) in $0000 (Zero Page)
    STA $0100, x 	; Store accumulator (x = $00) in $0100 (Stack)
                  ; Skip $0200 (Sprites Data) to avoid glitch sprite at 0,0
    STA $0300, x 	; Store accumulator (x = $00) in $0300 (RAM)
    STA $0400, x 	; Store accumulator (x = $00) in $0400 (RAM)
    STA $0500, x 	; Etc...
    STA $0600, x
    STA $0700, x
    INX 		    	; Increase X by 1 -> Now X = 1
    BNE clear_memory

vblank_2:
    BIT PPU_STATUS
    BPL vblank_2

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; -------------------------- Load Stuff Into RAM -------------------------------
; ----- Load Palettes ----------------------------------------------------------
load_palettes:
    LDA PPU_STATUS	; Read PPU status (in $2002) to reset the high/low latch
    LDA #$3F		    ; Load $3F00 (where palets are stored) in PPU
    STA PPU_ADDR	  ; Set high byte of $3500 address in $2006
    LDA #$00		    ; Load $0000 (where pattern tables are stored) in PPU
    STA PPU_ADDR  	; Set low byte of $3500 address in $2006
    LDX #$00		    ; Set X to 0

load_palettes_LOOP:
    LDA palettes, x	       ; Load from address (bg_palette) + X (0)
    STA PPU_DATA				       ; Write to $2007
    INX						             ; X = X + 1
    CPX #$20				           ; Compare X to hex $10 (16)
    BNE load_palettes_LOOP	 ; Branch back if x =/= hex 10 (dec 16)
    LDX #$00				           ; Reset X to 0

; ----- Load Sprites ----------------------------------------------------------
load_sprites_LOOP:
    LDA sprites, x
    STA $0200, x
    INX
    CPX #$10        ; How many bytes for sprite data (in hex) - 4 per sprite
    BNE load_sprites_LOOP

; ----- Load Background --------------------------------------------------------
load_background:
  	LDA PPU_STATUS
  	LDA #$20
  	STA PPU_ADDR
  	LDA #$00
  	STA PPU_ADDR
  	LDX #$00

load_background_LOOP:
    LDA background_1, x
    STA PPU_DATA
    INX
    CPX #$80				; How many bytes (currently 128 bytes)
    BNE load_background_LOOP

; ----- Load Attributes --------------------------------------------------------
load_attribute:
    LDA $2002
    LDA #$23
    STA $2006
    LDA #$C0
    STA $2006
    LDX #$00

load_attributes_LOOP:
    LDA attributes, x
  	STA PPU_DATA
  	INX
  	CPX #08         ; Decimal 8 bytes
  	BNE load_attributes_LOOP


; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; -------------------------- Enable Sprite Drawing -----------------------------
enable_sprite_drawing:
    LDA #%10010000	; Enable NMI (1) - 000 - Sprites from pattern table 0 (0) - 000
    STA $2000			  ; Store bytes in $2000
    LDA #%00011110	; 000 - Enable Sprites (1) - 0000
    STA $2001			  ; Store bytes in $2001

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; ------------------------- Activate NMI Every Frame ---------------------------
NMI_loop:
    JMP NMI_loop

NMI:
    LDA #$00	   	; Load data from RAM address $0000
    STA OAM_ADDR	; Set low byte of RAM address to $2003
    LDA #$02		  ; Load from $0200 (RAM)
    STA OAM_DMA		; Set high byte of RAM address to $4014 - Start Transfer
























; ______________________________________________________________________________
; [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]
; ==============================================================================
; -------------------------------- GAME CODE -----------------------------------
; ==============================================================================

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; ------------------------- STOPPED OR MOVING? ---------------------------------
stopped_or_moving:
    LDX frog_stop_go
    CPX #$00
    BEQ read_controller
    JMP MOVING
; ______________________________________________________________________________
; ==============================================================================
; -------------------------- Read Controller Input -----------------------------
; ==============================================================================

read_controller:

LatchController:
	 LDA #$01
	 STA controller_1
	 LDA #$00
	 STX controller_1  	 ; Tell both controllers to latch buttons

ReadA:
	 LDA controller_1	   ; Player 1 memory port address
	 AND #%00000001      ; Look at bit 0 and erase all other bits
	 BEQ ReadADone	     ; Branch to ReadADone if A button NOT pressed (0)
   ; If A button is pressed
   LDX #$01
   STX controller_button
ReadADone:

ReadB:
	  LDA controller_1
	  AND #%00000001
	  BEQ ReadBDone
    LDX #$02
    STX controller_button
ReadBDone:

ReadSelect:
	  LDA controller_1
	  AND #%00000001
	  BEQ ReadSelectDone
    LDX #$03
    STX controller_button
ReadSelectDone:

ReadStart:
	  LDA controller_1
	  AND #%00000001
	  BEQ ReadStartDone
    LDX #$04
    STX controller_button
ReadStartDone:

ReadUp:
	  LDA controller_1
    AND #%00000001
    BEQ ReadUpDone
    LDX #$05
    STX controller_button
ReadUpDone:

ReadDown:
	  LDA controller_1
    AND #%00000001
    BEQ ReadDownDone
    LDX #$06
    STX controller_button
ReadDownDone:

ReadLeft:
	  LDA controller_1
    AND #%00000001
    BEQ ReadLeftDone
    LDX #$07
    STX controller_button
ReadLeftDone:

ReadRight:
	  LDA controller_1
    AND #%00000001
    BEQ ReadRightDone
    LDX #$08
    STX controller_button
ReadRightDone:

Which_Button:
    LDX controller_button
    ; ----- Right ------------ ;
    CPX #$08
    BEQ setup_right
    ; ----- No Button -------- ;
    JMP DONE

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; ------------------------------- SETUP MOVEMENT -------------------------------
setup_right:
    LDX #$01
    STX frog_direction    ; Set Direction to 1 = Right
    STX frog_stop_go      ; Set Stop/Go to 1 = Moving
    LDX #$00
    JMP MOVING

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; ------------------------------- MOVING ---------------------------------------
MOVING:
    LDX frog_direction
    CPX #$01              ; 1 = Moving right
    BEQ moving_right
    JMP FROG_ANIMATION

moving_right:
    LDX frog_distance
    CPX #$10            ; Is frog_distance = hex 10? (dec 16)
    BEQ done_moving
    ; ----- Add 1 to Distance ----
    LDX frog_distance   ; Load value X from frog_distance
    INX                 ; Frog_distance + 1
    STX frog_distance   ; Store value X at frog distance
    ; ----- Move Right -----------
    LDX frog_x_TL
    INX
    STX frog_x_TL
    STX frog_x_BL
    LDX frog_x_TR
    INX
    STX frog_x_TR
    STX frog_x_BR
    JMP FROG_ANIMATION

done_moving:
    LDX #$00
    STX frog_stop_go
    STX frog_distance
    JMP FROG_ANIMATION

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; ---------------------------- ANIMATION FRAME ---------------------------------
FROG_ANIMATION:
    LDX frog_direction
    CPX #$01              ; 1 = Moving right
    BEQ frog_which_animation_right
    JMP DONE

frog_which_animation_right:
    LDX frog_distance
    CPX #$00              ; 0 = Stopped
    BEQ frog_animation_right_stopped
    CPX #$01              ; 1 = Frame 1
    BEQ frog_animation_right_jump1
    CPX #$06              ; 6 = Frame 2
    BEQ frog_animation_right_jump2
    CPX #$0A              ; 11 = Frame 3
    BEQ frog_animation_right_jump3
    CPX #$0C               ; 14 = Stopped
    BEQ frog_animation_right_stopped
    JMP DONE

frog_animation_right_stopped:
    LDX #$00
    STX frog_tile_TL
    INX
    STX frog_tile_TR
    INX
    STX frog_tile_BL
    INX
    STX frog_tile_BR
    JMP DONE

frog_animation_right_jump1:
    LDX #$04
    STX frog_tile_TL
    INX
    STX frog_tile_TR
    INX
    STX frog_tile_BL
    INX
    STX frog_tile_BR
    JMP DONE

frog_animation_right_jump2:
    LDX #$08
    STX frog_tile_TL
    INX
    STX frog_tile_TR
    INX
    STX frog_tile_BL
    INX
    STX frog_tile_BR
    JMP DONE

frog_animation_right_jump3:
    LDX #$0C
    STX frog_tile_TL
    INX
    STX frog_tile_TR
    INX
    STX frog_tile_BL
    INX
    STX frog_tile_BR
    JMP DONE




; ------------------------------------------------------------------------------

DONE:
    LDX #$00
    STX controller_button   ; Clear controller input



; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~































; ______________________________________________________________________________
; ==============================================================================
; -------------------------------- PPU Cleanup ---------------------------------
; ==============================================================================
PPU_cleanup:
    LDA #%10010000		; Enable NMI (1) - 000 - Sprites from pattern table 0 (0) - 000
    STA $2000			    ; Store bytes in $2000
    LDA #%00011110		; 000 - Enable Sprites (1) - 0000
    STA $2001			    ; Store bytes in $2001
    LDA #$00        	; Tell the PPU there is no background scrolling
    STA PPU_SCROLL
    STA PPU_SCROLL
    RTI

; ______________________________________________________________________________
; ==============================================================================
; ------------------------------ Interrupt Bank --------------------------------
; ==============================================================================
    .bank 1
    .org $E000

palettes:
    ; ----- BG PALETTES ------------------------- ;
    .db $20,$18,$27,$36		; Yellow
    .db $20,$0C,$15,$36		; Red
    .db $20,$0C,$1C,$36		; Blue
    .db $20,$0C,$14,$36		; Purple
    ; ----- SPRITE PALETTES --------------------- ;
    .db $20,$0B,$19,$36   ; Frog

sprites:
    ; --------- FROG SPRITES -------------------- ;
    ;  X-pos Tile Attr      Y-pos
    .db $3F, $00, %00000000, $40	; Top Left
    .db $3F, $01, %00000000, $48	; Top Right
    .db $47, $02, %00000000, $40	; Bottom Left
    .db $47, $03, %00000000, $48	; Bottom Right

background_1:



attributes:



; ______________________________________________________________________________
; ==============================================================================
; --------------------------------- VECTORS ------------------------------------
; ==============================================================================
vectors:
    .org $FFFA	; Go to $FFFA
    .dw NMI		  ; Define word NMI - When NMI happens, jump to label NMI
    .dw RESET	  ; Define word RESET - When processor turns on, jump to label RESET
    .dw 0		    ; External interrupt IRQ not used

; ______________________________________________________________________________
; ==============================================================================
; ------------------------------ EXTERNAL FILES --------------------------------
; ==============================================================================
    .bank 2
    .org $0000
    .incbin "Flipbit.chr"
