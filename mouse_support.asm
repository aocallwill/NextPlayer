; =============================================================================
; mouse_support.asm  –  podpora Kempston myši pro NextPlayer
; Autor: Shrek/MB Maniax  v0.9
;
; ZMĚNY v0.9:
;  - MOUSE_PLAY_TICK přesunut ZA keysetup (byl před ním → keysetup přepisoval
;    klavesa kterou MOUSE_PLAY_TICK nastavil)
;  - Zpřesnění X hranic seznamu souborů (bylo 1..159, nyní 32..135)
;    Zabrání kliknutí mimo levý panel (pravá část obrazovky, border)
;  - MOUSE_PLAY_TICK vynuluje MOUSE_TLAC jen jednou, ne dvakrát
; =============================================================================

MOUSE_PORT_BTN  equ $FADF

; CSpect border offsets:
; Nahoře:  32px → COORD+1 = ZX_pixel_Y + 32
; Vlevo:   24px → COORD+0 = ZX_pixel_X + 24
MOUSE_BORDER_Y  equ 32
MOUSE_BORDER_X  equ 32

; Oblast levého panelu (seznam souborů):
; ZX pixel X: 32..111 (chars 4..13, šířka 10 chars = jméno souboru)
; ZX pixel Y: 16..159 (chars 2..19, výška 18 řádků)
; + border offsets:
MOUSE_LIST_Y0   equ 16 + MOUSE_BORDER_Y     ; = 48
MOUSE_LIST_Y1   equ 159 + MOUSE_BORDER_Y    ; = 191
MOUSE_LIST_X0   equ 24 ; + MOUSE_BORDER_X       ; = 40  (zacý okraj panelu)
MOUSE_LIST_X1   equ 68 ;+ MOUSE_BORDER_X    ; = 143 (pravy okraj leveho panelu)

; Proměnné
MOUSE_TLAC      defb 0
MOUSE_WOLD      defb 0
MOUSE_DCNT      defb 0
MOUSE_DROW      defb $FF
MOUSE_OLD_ROW   defb 0
MOUSE_NEW_ROW   defb 0

; =============================================================================
; MOUSE_INIT
; =============================================================================
MOUSE_INIT:
        ld hl, 0*256 + 0
        call KOREKCE

        call MOUSE_RdWheel
        ld (MOUSE_WOLD), a

        xor a
        ld (MOUSE_TLAC), a
        ld (MOUSE_DCNT), a
        ld a, $FF
        ld (MOUSE_DROW), a

        nextreg $15, %01000001

        nextreg $34, 0
        ld hl, mouse_sipka_data
        ld b, 0
        ld c, $5B
MINIT_loop:
        ld a, (hl)
        out (c), a
        inc hl
        djnz MINIT_loop

        call MOUSE_UpdateSpr
        ret

; =============================================================================
; MOUSE_UpdateSpr – refresh sprite + latch tlačítek (uchovává všechny registry)
; =============================================================================
MOUSE_UpdateSpr:
        push af
        push bc
        push de
        push hl

        call MOUSE                  ; A = CONTRB, HL = COORD (L=X, H=Y)
        ld b, a                     ; B = aktuální stav tlačítek

        ; Latch: MOUSE_TLAC = MOUSE_TLAC OR aktuální tlačítka
        ; (tlačítko zůstane aktivní dokud ho nespotřebuje obsluha)
           ; Latch: OR aktualni tlacitka do MOUSE_TLAC
        ld a, b
        or a
        jr z, .noBtn
        ld a, (MOUSE_TLAC)
        or b
        ld (MOUSE_TLAC), a
.noBtn:
        nextreg $34, 0

        ld a, l
        ld d, a
        ld e, 2
        mul d, e
        ld a, e
        ld (MUSPR_X+3), a

        ld a, (MUSPR_XH+3)
        res 0, a
        or d
        set 7, a
        ld (MUSPR_XH+3), a

        ld a, h
        ld (MUSPR_Y+3), a

MUSPR_X:  nextreg $35, 0
MUSPR_Y:  nextreg $36, 0
MUSPR_XH: nextreg $37, %00001000
          nextreg $38, %10000000

        pop hl
        pop de
        pop bc
        pop af
        ret

; =============================================================================
; MOUSE_RdWheel
; =============================================================================
MOUSE_RdWheel:
        ld bc, MOUSE_PORT_BTN
        in a, (c)
        and $F0
        rrca
        rrca
        rrca
        rrca
        ret

; =============================================================================
; MOUSE_PLAY_TICK – myš při přehrávání
;
; Volat ZA keysetup, PŘED music_play (v každé přehrávací smyčce):
;   call keysetup
;   call MOUSE_PLAY_TICK    ← sem
;   call stc.music_play
;
; Pravé tlačítko (bit0) → klavesa = 1  = break/stop
; Levé tlačítko  (bit1) → klavesa = 32 = space/next
; =============================================================================
MOUSE_PLAY_TICK:
        push af
        push bc
        push hl

        call MOUSE_UpdateSpr

        ld a, (MOUSE_TLAC)
        or a
        jr z, .done

        ; Pravé tlačítko = break
        bit 0, a
        jr z, .checkLeft
        xor a
        ld (MOUSE_TLAC), a
        ld a, 1
        ld (klavesa), a
        jr .done

.checkLeft:
        ; Levé tlačítko = next song
        bit 1, a
        jr z, .done
        xor a
        ld (MOUSE_TLAC), a
        ld a, 32
        ld (klavesa), a

.done:
        pop hl
        pop bc
        pop af
        ret

; =============================================================================
; MOUSE_TICK – hlavní smyčka (hl0, před KEYSCAN)
; =============================================================================
MOUSE_TICK:
        push af
        push bc
        push de
        push hl

        call MOUSE_UpdateSpr

        ld hl, MOUSE_DCNT
        ld a, (hl)
        or a
        jr z, .dcOk
        dec (hl)
.dcOk:
        call MOUSE_Wheel

        ld a, (MOUSE_TLAC)
        bit 1, a
        jr z, .done
        xor a
        ld (MOUSE_TLAC), a
        call MOUSE_LeftClick

.done:
        pop hl
        pop de
        pop bc
        pop af
        ret

; =============================================================================
; MOUSE_Wheel – kolečko: k sobě=LEFT(8)=prev, od sebe=RIGHT(9)=next
; =============================================================================
MOUSE_Wheel:
        ld a, (MOUSE_WOLD)
        cp 15
        jr z, .atFifteen
        or a
        jr z, .atZero

        ld e, a
        call MOUSE_RdWheel
        ld (MOUSE_WOLD), a
        cp e
        ret z
        jr c, .scrollLeft
        jr .scrollRight

.atFifteen:
        ld e, a
        call MOUSE_RdWheel
        ld (MOUSE_WOLD), a
        cp 0
        jr z, .scrollLeft
        cp 14
        jr z, .scrollRight
        ret

.atZero:
        ld e, a
        call MOUSE_RdWheel
        ld (MOUSE_WOLD), a
        cp 15
        jr z, .scrollRight
        cp 1
        jr z, .scrollLeft
        ret

.scrollLeft:
        ld a, 8
        ld (KEY), a
        call CH_FILE
        ret

.scrollRight:
        ld a, 9
        ld (KEY), a
        call CH_FILE
        ret

; =============================================================================
; MOUSE_WaitRelease – čeká na uvolnění levého tlačítka
; =============================================================================
MOUSE_WaitRelease:
        call MOUSE_UpdateSpr
        ld bc, MOUSE_PORT_BTN
        in a, (c)
        cpl
        and %00000010
        jr nz, MOUSE_WaitRelease
        ; Tlacitko uvolneno: vynuluj latch aby dalsi frame nevidel klik
        xor a
        ld (MOUSE_TLAC), a
        ret

; =============================================================================
; MOUSE_LeftClick – kliknutí v hlavní smyčce
; =============================================================================
MOUSE_LeftClick:

        ld a, (COORD+1)
        cp MOUSE_LIST_Y0
        jp c, .outside
        cp MOUSE_LIST_Y1 + 1
        jp nc, .outside

        ld a, (COORD+0)
        cp MOUSE_LIST_X0
        jp c, .outside
        cp MOUSE_LIST_X1 + 1
        jp nc, .outside

        ; Y → řádek: (Y - MOUSE_LIST_Y0) / 8
        ld a, (COORD+1)
        sub MOUSE_LIST_Y0
        srl a
        srl a
        srl a
        ld (MOUSE_NEW_ROW), a

        ld a, (POS_F+1)
        ld (MOUSE_OLD_ROW), a

        ld hl, (apos_all)
        ld b, 0
        ld c, a
        or a
        sbc hl, bc
        jr nc, .baseOk
        ld hl, 0
.baseOk:
        ld a, (MOUSE_NEW_ROW)
        ld b, 0
        ld c, a
        add hl, bc

        push hl
        ld de, (ALLFILES)
        or a
        sbc hl, de
        pop hl
        jp nc, .outside

        ; Uložit PŘED KURZOR (KURZOR přepíše HL, DE, BC!)
        ld (apos_all), hl
        ld a, (MOUSE_NEW_ROW)
        ld (POS_F+1), a

        ld a, (MOUSE_OLD_ROW)
        ld c, %00001111
        call KURZOR

        ld a, (MOUSE_NEW_ROW)
        ld c, %00010111
        call KURZOR

        call LFNPRINT
        ld hl, LFNNAME + maxline
        ld (hl), 0
        ld hl, LFNNAME
        ld de, 20672+2
        call print

        ; Double-click
        ld a, (MOUSE_NEW_ROW)
        ld b, a
        ld a, (MOUSE_DROW)
        cp b
        jr z, .sameRow

        ld a, (MOUSE_NEW_ROW)
        ld (MOUSE_DROW), a
        ld a, 25
        ld (MOUSE_DCNT), a
        call MOUSE_WaitRelease
        ret

.sameRow:
        ld a, (MOUSE_DCNT)
        or a
        jr z, .newSingle

        xor a
        ld (MOUSE_DCNT), a
        ld a, $FF
        ld (MOUSE_DROW), a
        call MOUSE_WaitRelease
        call FIRE
        ret

.newSingle:
        ld a, (MOUSE_NEW_ROW)
        ld (MOUSE_DROW), a
        ld a, 25
        ld (MOUSE_DCNT), a
        call MOUSE_WaitRelease
        ret

.outside:
        ld a, $FF
        ld (MOUSE_DROW), a
        xor a
        ld (MOUSE_DCNT), a
        call MOUSE_WaitRelease
        ret
