; ==============================================================
; rom.asm - BOOTLOADER + sistema com MENU (soma e subtracao)
;
; Mapa de memoria:
;   00-37  ROM de boot      (o bootloader)
;   38-97  armazenamento    (imagem do sistema: cabecalho + codigo)
;   98-F7  RAM do sistema   (para onde a imagem e copiada e onde roda)
;   F8-FF  RAM de variaveis
; Formato da imagem:  [5A] [tamanho] [codigo...]
; ==============================================================
ASSINATURA = 0x5A
ARMAZ      = 0x38       ; inicio do armazenamento
RAM_SIS    = 0x98       ; onde o sistema e carregado
orig       = 0xF8       ; variaveis do boot
dest       = 0xF9
cont       = 0xFA
numero     = 0xFB       ; ultimo numero lido (resultado de le_numero)
x          = 0xFC       ; primeiro numero da conta
op         = 0xFD       ; opcao escolhida no menu (1 = soma, 2 = subtracao)
RETORNO    = 0xFE       ; endereco de retorno das sub-rotinas (CALL/RET)

; ---------------------- BOOTLOADER ----------------------
        .org 0x00
boot:   LDI 0xB0
        OUT                 ; mostra b0 ("boot")
        LDA ARMAZ           ; 1o byte do armazenamento = assinatura
        SUBI ASSINATURA
        JNZ erro            ; diferente de 5A: imagem invalida
        LDA ARMAZ+1         ; 2o byte = tamanho da imagem
        JZ erro             ; tamanho 0: imagem invalida
        STA cont
        LDI ARMAZ
        STA orig
        LDI RAM_SIS
        STA dest
copia:  LDN orig
        STN dest
        LDA orig
        ADDI 1
        STA orig
        LDA dest
        ADDI 1
        STA dest
        LDA cont
        SUBI 1
        STA cont
        JNZ copia
        JMP sistema         ; entrega o controle ao sistema (na RAM)
erro:   LDI 0xEE
        OUT                 ; mostra EE: boot falhou
        HLT

; ------------- IMAGEM (guardada em 38, roda em 98) -------------
        .org RAM_SIS
        .guardar_em ARMAZ
        .byte ASSINATURA, fim - RAM_SIS     ; cabecalho

; ---- MENU: F0 na tela. Chaves = opcao, depois ENTER ----
sistema: LDI 0xF0
        OUT                 ; F0 = menu
        CALL le_numero      ; espera ENTER e le as chaves
        LDA numero
        STA op              ; guarda a opcao
        SUBI 1
        JZ conta            ; opcao 1: soma
        LDA op
        SUBI 2
        JZ conta            ; opcao 2: subtracao
        JMP sistema         ; opcao invalida: volta ao menu

; ---- CONTA: pede dois numeros e soma (op=1) ou subtrai (op=2) ----
conta:  LDI 0xA1
        OUT                 ; A1 = "digite o 1o numero"
        CALL le_numero
        LDA numero
        STA x               ; guarda o 1o numero
        LDI 0xA2
        OUT                 ; A2 = "digite o 2o numero"
        CALL le_numero
        LDA op
        SUBI 2
        JZ subtrai
        LDA x
        ADD numero          ; x + 2o numero
        JMP mostra
subtrai: LDA x
        SUB numero          ; x - 2o numero
mostra: OUT                 ; mostra o resultado
        CALL le_numero      ; espera ENTER
        JMP sistema         ; volta ao menu

; sub-rotina: espera o ENTER, le as chaves e guarda em "numero"
le_numero: INK
        JZ le_numero        ; sem ENTER: continua esperando
        IN
        STA numero
        RET
fim:
