; iNES Header =================================================================================

	.inesprg 1	; 1x 16KB PRG code
	.ineschr 1	; 1x 8KB CHR data
	.inesmap 0	; mapper 0 = NROM, no bank swapping
	.inesmir 1	; horizontal mirroring (SMB)

; Variables ===================================================================================

	.rsset $0000	; Start variables at RAM location 0

PPU_STATUS	= $2002
OAM_ADDR 	= $2003
PPU_SCROLL	= $2005
PPU_ADDR	= $2006
PPU_DATA	= $2007
OAM_DMA		= $4014

controller_1 = $4016

; PLAYER ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Player Sprites X-Position
player1_x	= $0203
player2_x	= $0207
player3_x	= $020B
player4_x	= $020F

; Player Sprites Y-Position
player1_y	= $0200
player2_y	= $0204
player3_y	= $0208
player4_y	= $020C

; Player Sprites Tile Number
player1_t	= $2001
player2_t	= $2008

; FOLLOW ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Follow X-Position
follow_x 	= $0213
; Follow Y-Position
follow_y	= $0210

; ALLOW MOVE ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Allow Move Y-Position
moving = $0214

; Distance between Player and Follow ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
distance .rs 1


; Player Animation Frame ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

player_animation	.rs 1

; [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[
; Bank 0 (In PRG-ROM Lower Bank) ==============================================================
; ]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]

	.bank 0
	.org $C000	; Go to $C000 (PRG-ROM Lower Bank)

RESET:
	SEI			; Ignore IRQs
	CLD			; Disable decimal mode
	LDX #$40
	STX $4017	; disable APU frame IRQ
	LDX #$FF
	TXS			; Set up stack
	INX			; Now X = 0
	STX $2000	; Disable NMI
	STX $2001	; Disable rendering
	STX $4010	; Disable DMC IRQs

vblankwait1:			; First wait for vblank to make sure PPU is ready
	BIT PPU_STATUS		; Test bits with accumulator in $2002 ($2002 is in PPU I/O Ports)
	BPL vblankwait1		; Branch if plus to vblankwait1

clrmem:
	LDA #$00		; Load accumulator with memory $00 (0)
	STA $0000, x	; Store accumulator (x = $00) in $0000 (Zero Page)
	STA $0100, x 	; Store accumulator (x = $00) in $0100 (Stack)
					; Skip $0200 (Sprites Data) to avoid glitch sprite at 0,0
	STA $0300, x 	; Store accumulator (x = $00) in $0300 (RAM)
	STA $0400, x 	; Store accumulator (x = $00) in $0400 (RAM)
	STA $0500, x 	; Etc...
	STA $0600, x
	STA $0700, x
	INX 			; Increase X by 1 -> Now X = 1
	BNE clrmem

vblankwait2:	; Second wait for vblank - PPU is ready after this
	BIT PPU_STATUS
	BPL vblankwait2

; [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[
; Load Stuff Into RAM =========================================================================
; ]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]

LoadPalettes:
	LDA PPU_STATUS	; Read PPU status (in $2002) to reset the high/low latch
	LDA #$3F		; Load $3F00 (where palets are stored) in PPU
	STA PPU_ADDR	; Set high byte of $3500 address in $2006
	LDA #$00		; Load $0000 (where pattern tables are stored) in PPU
	STA PPU_ADDR	; Set low byte of $3500 address in $2006
	LDX #$00		; Set X to 0

LoadBgPaletteLoop:
	LDA bg_palette, x		; Load from address (bg_palette) + X (0)
	STA PPU_DATA				; Write to $2007
	INX						; X = X + 1
	CPX #$10				; Compare X to hex $10 (16)
	BNE LoadBgPaletteLoop	; Branch to LoadBGPalettesLoop (repeat) if X =/= hex $10 (16)

	LDX #$00				; Reset X to 0

LoadSpritePaletteLoop:
	LDA sprite_palette, x
	STA PPU_DATA
	INX
	CPX #$10
	BNE LoadSpritePaletteLoop

	LDX #$00

LoadPlayerSpritesLoop:
	LDA player_sprites, x
	STA $0200, x
	INX
	CPX #$10
	BNE LoadPlayerSpritesLoop

	LDX #$00

LoadFollowSpriteLoop:
	LDA follow_sprite, x
	STA $0210, x
	INX
	CPX #$04
	BNE LoadFollowSpriteLoop

	LDX #$00

LoadMovingSpriteLoop:
	LDA moving_sprite, x
	STA $0214, x
	INX
	CPX #$04
	BNE LoadMovingSpriteLoop

	LDX #$00

LoadBackground1:
	LDA PPU_STATUS
	LDA #$20
	STA PPU_ADDR
	LDA #$00
	STA PPU_ADDR
	LDX #$00
LoadBackground1Loop:
	LDA background1, x
	STA PPU_DATA
	INX
	CPX #$00				; Set how many BG tiles can be used (Dec 256)
	BNE LoadBackground1Loop
LoadBackground2Loop:
	LDA background2, x
	STA PPU_DATA
	INX
	CPX #$00
	BNE LoadBackground2Loop

	LDX #$00

LoadAttribute:
	LDA PPU_STATUS
	LDA #$23
	STA PPU_ADDR
	LDA #$C0
	STA PPU_ADDR
	LDX #$00
LoadAttributeLoop:
	LDA attribute, x
	STA PPU_DATA
	INX
	CPX #$40
	BNE LoadAttributeLoop

; Enable Sprite Drawing =======================================================================

	LDA #%10000000		; Enable NMI (1) - 000 - Sprites from pattern table 0 (0) - 000
	STA $2000			; Store bytes in $2000

	LDA #%00011110		; 000 - Enable Sprites (1) - 0000
	STA $2001			; Store bytes in $2001

; Activate NMI Every Frame ====================================================================

ForeverLoop:
	JMP ForeverLoop		; Infinite loop to activate NMI every frame (~60FPS)

; [[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[
; Game Code ===================================================================================
; ]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]

NMI:

	LDA #$00		; Load data from RAM address $0000
	STA OAM_ADDR	; Set low byte of RAM address to $2003
	LDA #$02		; Load from $0200 (RAM)
	STA OAM_DMA		; Set high byte of RAM address to $4014 - Start Transfer

; Refresh Counter NMI -------------------------------------------------------------------------

; Controller ----------------------------------------------------------------------------------

; ALREADY MOVING ~~~~~~~~~~~~~~~~~~
AlreadyMovingRight:
	; Already Moving Right?
	LDA moving
	CPX #$10
	BNE AlreadyMovingRightDone
	JMP MoveRight
AlreadyMovingRightDone:

AlreadyMovingLeft:
	; Already Moving left?
	LDA moving
	CPX #$20
	BNE AlreadyMovingLeftDone
	JMP MoveLeft
AlreadyMovingLeftDone:

AlreadyMovingDown:
	; Already Moving Down?
	LDA moving
	CPX #$30
	BNE AlreadyMovingDownDone
	JMP MoveDown
AlreadyMovingDownDone:

AlreadyMovingUp:
	; Already Moving Down?
	LDA moving
	CPX #$40
	BNE AlreadyMovingUpDone
	JMP MoveUp
AlreadyMovingUpDone:
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

LatchController:
	LDA #$01
	STA controller_1
	LDA #$00
	STX controller_1	; Tell both controller to latch buttons

ReadA:
	LDA controller_1	; Player 1 memory pot address
	AND #%00000001
	BEQ ReadADone		; Branch to ReadADone if A button NOT pressed
ReadADone:

ReadB:
	LDA controller_1
	AND #%00000001
	BEQ ReadBDone
ReadBDone:

ReadSelect:
	LDA controller_1
	AND #%00000001
	BEQ ReadSelectDone
ReadSelectDone:

ReadStart:
	LDA controller_1
	AND #%00000001
	BEQ ReadStartDone
ReadStartDone:

; Move Up -------------------------------------------------------------------------------------
ReadUp:
	; Push Button?
	LDA controller_1
	AND #%00000001
	BEQ ReadUpDone
	; Setup?
	LDA moving
	CPX #$30
	BEQ ReadUpDone
	JMP SetupUp
SetupUp:
; Move Follow above Player
	LDA player1_y
	SEC
	SBC #$10
	STA follow_y
	; Set moving to $40 (MOVING UP)
	LDA moving
	LDX #$40
	STX moving
	JMP EndRead
MoveUp:
	; Check Distance
	LDA player1_y
	SEC
	SBC follow_y
	BEQ ResetUp
	; Move Left
	LDA player1_y
	SEC
	SBC #$01
	STA player1_y
	LDA player2_y
	SEC
	SBC #$01
	STA player2_y
	LDA player3_y
	SEC
	SBC #$01
	STA player3_y
	LDA player4_y
	SEC
	SBC #$01
	STA player4_y
	JMP EndRead
ResetUp:
	LDA moving
	CLC
	LDX #$00
	STX moving
	LDA distance
	CLC
	LDX #$00
ReadUpDone:

; MoveDown -------------------------------------------------------------------------------------------------------------------
ReadDown:
	; Push Button?
	LDA controller_1
	AND #%00000001
	BEQ ReadDownDone
	; Setup?
	LDA moving
	CPX #$30
	BEQ ReadDownDone
	JMP SetupDown
SetupDown:
; Move Follow below Player
	LDA player1_y
	CLC
	ADC #$10
	STA follow_y
	; Set moving to $30 (MOVING DOWN)
	LDA moving
	LDX #$30
	STX moving
	JMP EndRead
MoveDown:
	; Check Distance
	LDA follow_y
	SEC
	SBC player1_y
	BEQ ResetDown
	; Move Right
	LDA player1_y
	CLC
	ADC #$01
	STA player1_y
	LDA player2_y
	CLC
	ADC #$01
	STA player2_y
	LDA player3_y
	CLC
	ADC #$01
	STA player3_y
	LDA player4_y
	CLC
	ADC #$01
	STA player4_y
	JMP EndRead
ResetDown:
	LDA moving
	CLC
	LDX #$00
	STX moving
	LDA distance
	CLC
	LDX #$00
ReadDownDone:

; Move Left ------------------------------------------------------------------------------------------------------------------
ReadLeft:
	; Push Button?
	LDA controller_1
	AND #%00000001
	BEQ ReadLeftDone
	; Setup?
	LDA moving
	CPX #$20
	BEQ ReadLeftDone
	JMP SetupLeft
SetupLeft:
	; Move Follow left of Player
	LDA player1_x
	SEC
	SBC #$10
	STA follow_x
	; Set moving to $20 (MOVING LEFT)
	LDA moving
	LDX #$20
	STX moving
	JMP EndRead
MoveLeft:
	; Check Distance
	LDA player1_x
	SEC
	SBC follow_x
	BEQ ResetLeft
	; Move Left
	LDA player1_x
	SEC
	SBC #$01
	STA player1_x
	LDA player2_x
	SEC
	SBC #$01
	STA player2_x
	LDA player3_x
	SEC
	SBC #$01
	STA player3_x
	LDA player4_x
	SEC
	SBC #$01
	STA player4_x
	JMP EndRead
ResetLeft:
	LDA moving
	CLC
	LDX #$00
	STX moving
ReadLeftDone:


; Move Right -----------------------------------------------------------------------------------------------------------------
ReadRight:
	; Push Button?
	LDA controller_1	; Load accumulator controller 1
	AND #%00000001		; Erase everything except bit 0
	BEQ BranchReadRightDone
	; Setup?
	LDA moving
	CPX #$10
	BEQ BranchReadRightDone
	JMP SetupRight
SetupRight:
	; Move Follow right of Player
	LDA player1_x
	CLC
	ADC #$10
	STA follow_x
	; Set moving to $10 (MOVING RIGHT)
	LDA moving
	LDX #$10
	STX moving
	JMP EndRead
	; Start animation
	LDA player_animation
	CLC
	LDX #$04
	STX player_animation
BranchReadRightDone:
	JMP ReadRightDone
MoveRight:
	; Check Distance
	LDA follow_x
	SEC
	SBC player1_x
	BEQ ResetRight
	; Move Right
	LDA player1_x
	CLC
	ADC #$01
	STA player1_x
	LDA player2_x
	CLC
	ADC #$01
	STA player2_x
	LDA player3_x
	CLC
	ADC #$01
	STA player3_x
	LDA player4_x
	CLC
	ADC #$01
	STA player4_x
	; Animation
	LDA player_animation
	CPX #$04
	BEQ Right2
	CPX #$09
	BEQ Right1
	JMP EndRead
Right2:
	LDA player1_t
	CLC
	LDX #$26
	STX player1_t
	LDA player2_t
	CLC
	LDX #$27
	STX player2_t
	LDA player_animation
	CLC
	ADC #$01
	STA player_animation
	JMP EndRead
Right1:
	LDA player1_t
	CLC
	LDX #$1E
	STX player1_t
	LDA player2_t
	CLC
	LDX #$1F
	STX player2_t
	LDA player_animation
	CLC
	ADC #$01
	STA player_animation
	JMP EndRead
ResetRight:
	LDA moving
	CLC
	LDX #$00
	STX moving
	LDA player_animation
	CLC
	LDX #$00
	STX player_animation
ReadRightDone:

EndRead:

; PPU Cleanup ================================================================================================================

	LDA #%10000000		; Enable NMI (1) - 000 - Sprites from pattern table 0 (0) - 000
	STA $2000			; Store bytes in $2000

	LDA #%00011110		; 000 - Enable Sprites (1) - 0000
	STA $2001			; Store bytes in $2001

	LDA #$00        	; Tell the PPU there is no background scrolling
	STA PPU_SCROLL
	STA PPU_SCROLL

; NMI Counter ----------------------------------------------------------------------------------------------------------------

	RTI

; Interrupt Bank - 32 Bytes (In upper bank of PRG-ROM) =======================================================================

	.bank 1
	.org $E000

bg_palette:		; 16 Bytes
	.db $0F,$18,$27,$36		; Yellow
	.db $0F,$0C,$15,$36		; Red
	.db $0F,$0C,$1C,$36		; Blue
	.db $0F,$0C,$14,$36		; Purple

sprite_palette:	; 16 Bytes
	.db $0F,$18,$27,$36		; Yellow
	.db $0F,$0C,$15,$36		; Red
	.db $0F,$0C,$1C,$36		; Blue
	.db $0F,$0C,$14,$36		; Purple

player_sprites:
	.db $3F, $1E, %00000000, $40	; P-1
	.db $3F, $1F, %00000000, $48	; P-2
	.db $47, $20, %00000000, $40	; P-3
	.db $47, $21, %00000000, $48	; P-4

follow_sprite:
	.db $3F, $00, $00000000, $40	; Follow-1

moving_sprite:
	.db $00, $00, $00000001, $00	; Moving-1

background1:
	; Row 1
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	; Row 2
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	; Row 3 - LEVEL 1
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$12,$13,$14,$13
	.db $12,$00,$00,$15,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	; Row 4
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	; Row 5
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	; Row 6
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	; Row 7
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	; Row 8
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

background2:
	; Row 9
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	; Row 10
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	; Row 11
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	; Row 12
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	; Row 13
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

attribute: 		; 4 x 4 of sprite tiles
	; Rows 1 + 2
	.db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
	.db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000

; In last 16KB of ROM - Upper Bank PRG-ROM) ---------------------------------------------------

	.org $FFFA	; Go to $FFFA
	.dw NMI		; Define word NMI - When NMI happens, jump to label NMI
	.dw RESET	; Define word RESET - When processor turns on, jump to label RESET
	.dw 0		; External interrupt IRQ not used

; External Files ==============================================================================

	.bank 2
	.org $0000
	.incbin "grid-movement.chr"
