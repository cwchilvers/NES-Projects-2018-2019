; iNES Header ==================================================================
    .inesprg 1    ; 16KB PRG code (x1)
    .ineschr 1    ; 8KB CHR data (x1)
    .inesmap 0    ; Mapper 0 = NROM (16KB PRG ROM and 8KB CHR ROM; No Swapping)
    .inesmir 2    ; Single Screen (No Scrolling)

; ______________________________________________________________________________
; ==============================================================================
; -------------------------------- VARIABLES -----------------------------------
; ==============================================================================

    .rsset $0000	; Start defining variables at RAM location 0

PPU_STATUS	    = $2002
OAM_ADDR 	    = $2003
PPU_SCROLL   	= $2005
PPU_ADDR	    = $2006
PPU_DATA    	= $2007
OAM_DMA		    = $4014

; ==============================================================================
; ----- Dragon Sprites ---------------------------------------------------------

; X-Positions
DRAGON_X_T1     = $0203
DRAGON_x_T2     = $0207
DRAGON_x_T3     = $020B
DRAGON_x_TM1    = $020F
DRAGON_x_TM2    = $0213
DRAGON_x_TM3    = $0217
DRAGON_x_BM1    = $021B
DRAGON_x_BM2    = $021F
DRAGON_x_BM3    = $0223
DRAGON_x_B1     = $0227
DRAGON_x_B2     = $022B
DRAGON_x_B3     = $022F

; tiles
DRAGON_tile_T1      = $0201
DRAGON_tile_T2      = $0205
DRAGON_tile_T3      = $0209
DRAGON_tile_TM1     = $020D
DRAGON_tile_TM2     = $0211
DRAGON_tile_TM3     = $0215
DRAGON_tile_BM1     = $0219
DRAGON_tile_BM2     = $021D
DRAGON_tile_BM3     = $0221
DRAGON_tile_B1      = $0225
DRAGON_tile_B2      = $0229
DRAGON_tile_B3      = $022D

MOVE_HalfSpeed .rs 1

ANIMATION_FrameCounter .rs 1

; ----- MARIO ------------------------------------------------------------------

; X-Positions
MARIO_x_B1     = $0233
MARIO_x_B2     = $0237
MARIO_x_M1     = $023B
MARIO_x_M2     = $023F
MARIO_x_T1     = $0243
MARIO_x_T2     = $0247

MARIO_Tile_B1  = $0231
MARIO_Tile_B2  = $0235
MARIO_Tile_M1  = $0239
MARIO_Tile_M2  = $023D
MARIO_Tile_T1  = $0241
MARIO_Tile_T2  = $0245

MARIO_Frame .rs 1

; ----- Controller -------------------------------------------------------------
controller_1    = $4016
controller_button .rs 1

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
    LDA #$00	    ; Load accumulator with memory $00 (0)
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
LOAD_Palettes:
    LDA PPU_STATUS	; Read PPU status (in $2002) to reset the high/low latch
    LDA #$3F	    ; Load $3F00 (where palets are stored) in PPU
    STA PPU_ADDR    ; Set high byte of $3500 address in $2006
    LDA #$00	    ; Load $0000 (where pattern tables are stored) in PPU
    STA PPU_ADDR  	; Set low byte of $3500 address in $2006
    LDX #$00	    ; Set X to 0

LOAD_Palettes_LOOP:
    LDA Palettes, x	        ; Load from address (bg_palette) + X (0)
    STA PPU_DATA		    ; Write to $2007
    INX					    ; X = X + 1
    CPX #$20			    ; Compare X to hex $10 (16)
    BNE LOAD_Palettes_LOOP  ; Branch back if x =/= hex 10 (dec 16)
    LDX #$00			    ; Reset X to 0

; ----- Load Sprites ----------------------------------------------------------
LOAD_Sprites_LOOP:
    LDA Sprites, x
    STA $0200, x
    INX
    CPX #$48        ; How many bytes for sprite data (in hex) - 4 per sprite
    BNE LOAD_Sprites_LOOP

; ----- Load Background --------------------------------------------------------
LOAD_Background:    ; A.K.A."Nametable"
    LDA PPU_STATUS
    LDA #$20
    STA PPU_ADDR
    LDA #$00
    STA PPU_ADDR
    LDX #$00

LOAD_Background_T8_LOOP:
    LDA Background_Top8, x
    STA PPU_DATA
    INX
    CPX #$00
    BNE LOAD_Background_T8_LOOP
LOAD_Background_TM8_LOOP:
    LDA Background_TopMiddle8, x
    STA PPU_DATA
    INX
    CPX #$00
    BNE LOAD_Background_TM8_LOOP
LOAD_Background_BM8_LOOP:
    LDA Background_BottomMiddle8, x
    STA PPU_DATA
    INX
    CPX #$00
    BNE LOAD_Background_BM8_LOOP
LOAD_Background_B8_LOOP:
    LDA Background_Bottom8, x
    STA PPU_DATA
    INX
    CPX #$00
    BNE LOAD_Background_B8_LOOP

; ----- Load Attributes --------------------------------------------------------
LOAD_Attributes:
    LDA PPU_STATUS
    LDA #$23
    STA PPU_ADDR
    LDA #$C0
    STA PPU_ADDR
    LDX #$00
LOAD_Attributes_LOOP:
    LDA Attributes, x
    STA PPU_DATA
    INX
    CPX #$40
    BNE LOAD_Attributes_LOOP

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; -------------------------- Enable Sprite Drawing -----------------------------
Enable_Sprite_Drawing:
    LDA #%10010000
    STA $2000	        ; Store bytes in $2000
    LDA #%00011110      ; 000 - Enable Sprites (1) - 0000
    STA $2001		    ; Store bytes in $2001

; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; ------------------------- Activate NMI Every Frame ---------------------------
NMI_LOOP:
    JMP NMI_LOOP

NMI:
    LDA #$00	   	    ; Load data from RAM address $0000
    STA OAM_ADDR	    ; Set low byte of RAM address to $2003
    LDA #$02		    ; Load from $0200 (RAM)
    STA OAM_DMA	        ; Set high byte of RAM address to $4014 - Start Transfer
























; ______________________________________________________________________________
; [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]
; ==============================================================================
; -------------------------------- GAME CODE -----------------------------------
; ==============================================================================



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
    BEQ MOVE_Right
    ; ----- No Button -------- ;
    JMP RESET_MarioFrame

; ==============================================================================

MOVE_Right:
    LDX MARIO_x_B1
    INX
    STX MARIO_x_B1
    STX MARIO_x_M1
    STX MARIO_x_T1
    LDX MARIO_x_B2
    INX
    STX MARIO_x_B2
    STX MARIO_x_M2
    STX MARIO_x_T2

    LDX MARIO_Frame
    INX
    STX MARIO_Frame
    LDX MARIO_Frame
    CPX #$00
    BEQ MARIO_Frame1
    CPX #$05
    BEQ MARIO_Frame2
    CPX #$09
    BEQ RESET_MarioFrame
    JMP DRAGON


RESET_MarioFrame:
    LDX #$00
    STX MARIO_Frame
    JMP DRAGON

MARIO_Frame1:
    LDX #$2A
    STX MARIO_Tile_B1
    LDX #$2B
    STX MARIO_Tile_B2
    LDX #$28
    STX MARIO_Tile_M1
    LDX #$29
    STX MARIO_Tile_M2
    LDX #$26
    STX MARIO_Tile_T1
    LDX #$27
    STX MARIO_Tile_T2
    JMP DRAGON


MARIO_Frame2:
    LDX #$24
    STX MARIO_Tile_B1
    LDX #$25
    STX MARIO_Tile_B2
    LDX #$22
    STX MARIO_Tile_M1
    LDX #$23
    STX MARIO_Tile_M2
    LDX #$20
    STX MARIO_Tile_T1
    LDX #$21
    STX MARIO_Tile_T2
    JMP DRAGON

; ===== DRAGON =================================================================
DRAGON:

CheckSpeed:
    LDX MOVE_HalfSpeed
    CPX #$00
    BEQ DRAGON_MoveLeft
    JMP RESET_HalfSpeedCounter
DRAGON_MoveLeft:
    LDX ANIMATION_FrameCounter
    INX
    STX ANIMATION_FrameCounter

    LDA DRAGON_X_T1
    SEC
    SBC #$01
    STA DRAGON_X_T1
    STA DRAGON_x_TM1
    STA DRAGON_x_BM1
    STA DRAGON_x_B1

    LDA DRAGON_x_T2
    SEC
    SBC #$01
    STA DRAGON_x_T2
    STA DRAGON_x_TM2
    STA DRAGON_x_BM2
    STA DRAGON_x_B2

    LDA DRAGON_x_T3
    SEC
    SBC #$01
    STA DRAGON_x_T3
    STA DRAGON_x_TM3
    STA DRAGON_x_BM3
    STA DRAGON_x_B3

    LDX #$01
    STX MOVE_HalfSpeed
    JMP Animation

RESET_HalfSpeedCounter:
    LDX #$00
    STX MOVE_HalfSpeed
    JMP Animation

Animation:
    LDX ANIMATION_FrameCounter
    CPX #$00
    BEQ Frame1
    CPX #$05
    BEQ Frame2
    JMP ResetCounter
Frame1:
    LDX #$00
    STX DRAGON_tile_T1
    LDX #$01
    STX DRAGON_tile_T2
    LDX #$02
    STX DRAGON_tile_T3
    LDX #$03
    STX DRAGON_tile_TM1
    LDX #$04
    STX DRAGON_tile_TM2
    LDX #$05
    STX DRAGON_tile_TM3
    LDX #$06
    STX DRAGON_tile_BM1
    LDX #$07
    STX DRAGON_tile_BM2
    LDX #$08
    STX DRAGON_tile_BM3
    LDX #$09
    STX DRAGON_tile_B1
    LDX #$0A
    STX DRAGON_tile_B2
    LDX #$0B
    STX DRAGON_tile_B3
    JMP ResetCounter
Frame2:
    LDX #$10
    STX DRAGON_tile_T1
    LDX #$11
    STX DRAGON_tile_T2
    LDX #$12
    STX DRAGON_tile_T3
    LDX #$13
    STX DRAGON_tile_TM1
    LDX #$14
    STX DRAGON_tile_TM2
    LDX #$15
    STX DRAGON_tile_TM3
    LDX #$16
    STX DRAGON_tile_BM1
    LDX #$17
    STX DRAGON_tile_BM2
    LDX #$18
    STX DRAGON_tile_BM3
    LDX #$19
    STX DRAGON_tile_B1
    LDX #$1A
    STX DRAGON_tile_B2
    LDX #$1B
    STX DRAGON_tile_B3
    JMP ResetCounter
ResetCounter:
    LDX ANIMATION_FrameCounter
    CPX #$0A
    BNE DONE
    LDX #$00
    STX ANIMATION_FrameCounter
    JMP DONE

; ------------------------------------------------------------------------------

DONE:
    LDX #$00
    STX controller_button   ; Clear controller input

; ______________________________________________________________________________
; ==============================================================================
; -------------------------------- PPU Cleanup ---------------------------------
; ==============================================================================

PPU_Cleanup:
    LDA #%10010000    ; Enable NMI, Sprites from Pattern 0, BG from Pattern 1
    STA $2000			    ; Store bytes in $2000
    LDA #%00011110		; Enable Sprites and Enable Background
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

Palettes:
    ; ----- BG PALETTES ------------------------- ;
    .db $21,$0A,$1A,$37		; Green
    .db $21,$06,$27,$17		; Yellow
    .db $21,$1C,$3C,$20		; Blue
    .db $21,$0C,$14,$36		; Purple
    ; ----- SPRITE PALETTES --------------------- ;
    .db $21,$0D,$1C,$36     ; Blue
    .db $21,$0D,$16,$36     ; Red

Sprites:
    ; --------- DRAGON SPRITES -------------------- ;
    ;  y-pos Tile Attr      x-pos
    .db $A0, $00, %00000000, $D0	; Top 1
    .db $A0, $01, %00000000, $D8	; Top 2
    .db $A0, $02, %00000000, $E0	; Top 3
    .db $A8, $03, %00000000, $D0	; Middle-Top 1
    .db $A8, $04, %00000000, $D8	; Middle-Top 2
    .db $A8, $05, %00000000, $E0	; Middle-Top 3
    .db $B0, $06, %00000000, $D0	; Middle-Bottom 1
    .db $B0, $07, %00000000, $D8	; Middle-Bottom 2
    .db $B0, $08, %00000000, $E0	; Middle-Bottom 3
    .db $B8, $09, %00000000, $D0	; Bottom 1
    .db $B8, $0A, %00000000, $D8	; Bottom 2
    .db $B8, $0B, %00000000, $E0	; Bottom 3
    ; --------- MARIO SPRITES --------------------
    ;  y-pos Tile Attr      x-pos
    .db $B7, $24, %00000001, $10    ; Bottom 1
    .db $B7, $25, %00000001, $18    ; Bottom 2
    .db $AF, $22, %00000001, $10    ; Middle 1
    .db $AF, $23, %00000001, $18    ; Middle 2
    .db $A7, $20, %00000001, $10    ; Middle 1
    .db $A7, $21, %00000001, $18    ; Middle 2


Background_Top8:   ; A.K.A."Nametable"
    ; ROW 1 - 32 Tiles across --------------------------------------------------
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; ROW 2
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; ROW 3
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; ROW 4
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; ROW 5
    .db $00,$00,$00,$06,$07,$07,$07,$08,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    .db $00,$00,$00,$09,$0A,$0A,$0A,$0B,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06,$07,$07,$07,$07

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$09,$0A,$0A,$0A,$0A

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

Background_TopMiddle8:
    ; ROW 1 - 32 Tiles across --------------------------------------------------
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; ROW 2 - 32 Tiles across --------------------------------------------------
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

Background_BottomMiddle8:
    ; ROW 1 - 32 Tiles across --------------------------------------------------
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; ROW 2
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; ROW 3
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    ; ROW 4
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

Background_Bottom8:
    .db $01,$02,$01,$02,$01,$02,$01,$02,$01,$02,$01,$02,$01,$02,$01,$02
    .db $01,$02,$01,$02,$01,$02,$01,$02,$01,$02,$01,$02,$01,$02,$01,$02

    .db $03,$04,$03,$04,$03,$04,$03,$04,$03,$04,$03,$04,$03,$04,$03,$04
    .db $03,$04,$03,$04,$03,$04,$03,$04,$03,$04,$03,$04,$03,$04,$03,$04

    .db $04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05
    .db $04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05

    .db $03,$04,$03,$04,$03,$04,$03,$04,$03,$04,$03,$04,$03,$04,$03,$04
    .db $03,$04,$03,$04,$03,$04,$03,$04,$03,$04,$03,$04,$03,$04,$03,$04

    .db $04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05
    .db $04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05,$04,$05

    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
    .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

Attributes:
    .db %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
    .db %00001000,%00001010,%00000000,%00000000,%00000000,%00000000,%10001010,%10101010
    .db %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
    .db %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
    .db %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
    .db %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
    .db %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
    .db %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000

; ______________________________________________________________________________
; ==============================================================================
; --------------------------------- VECTORS ------------------------------------
; ==============================================================================

Vectors:
    .org $FFFA	; Go to $FFFA
    .dw NMI		  ; Define word NMI - When NMI happens, jump to label NMI
    .dw RESET	  ; Define word RESET - When processor turns on, jump to RESET
    .dw 0		    ; External interrupt IRQ not used

; ______________________________________________________________________________
; ==============================================================================
; ------------------------------ EXTERNAL FILES --------------------------------
; ==============================================================================

    .bank 2
    .org $0000
    .incbin "sprite-animation.chr"

