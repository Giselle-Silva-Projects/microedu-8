; ==============================================================
; rom.asm - ROM da MicroEdu-8: BOOTLOADER + imagem de teste
;
; Mapa de memoria:
;   00-3F  ROM de boot      (o bootloader abaixo)
;   40-7F  armazenamento    (imagem do sistema: cabecalho + codigo)
;   80-BF  RAM do sistema   (para onde a imagem e copiada e onde roda)
;   C0-FF  RAM de variaveis
;
; Formato da imagem:  [5A] [tamanho] [codigo...]
;   5A       = assinatura (sem ela, o boot recusa a imagem)
;   tamanho  = quantos bytes copiar (cabecalho incluido)
; ==============================================================
ASSINATURA = 0x5A
ARMAZ      = 0x40       ; inicio do armazenamento
RAM_SIS    = 0x80       ; onde o sistema e carregado
orig       = 0xC0       ; ponteiro de leitura  (variavel do boot)
dest       = 0xC1       ; ponteiro de escrita  (variavel do boot)
cont       = 0xC2       ; bytes que faltam copiar
valor      = 0xC8       ; variavel do programa de teste

; ---------------------- BOOTLOADER ----------------------
        .org 0x00
boot:   LDI 0xB0
        OUT                 ; mostra b0 ("boot") em HEX3:HEX2
        LDA ARMAZ           ; 1o byte do armazenamento = assinatura
        SUBI ASSINATURA
        JNZ erro            ; diferente de 5A: imagem invalida
        LDA 0x41            ; 2o byte = tamanho da imagem
        JZ erro             ; tamanho 0: imagem invalida
        STA cont
        LDI ARMAZ
        STA orig            ; orig = 40
        LDI RAM_SIS
        STA dest            ; dest = 80
copia:  LDN orig            ; A = byte da imagem
        STN dest            ; grava na RAM
        LDA orig
        ADDI 1
        STA orig            ; orig = orig + 1
        LDA dest
        ADDI 1
        STA dest            ; dest = dest + 1
        LDA cont
        SUBI 1
        STA cont            ; cont = cont - 1
        JNZ copia           ; repete ate copiar tudo
        JMP sistema         ; entrega o controle ao sistema (na RAM)
erro:   LDI 0xEE
        OUT                 ; mostra EE: boot falhou
        HLT

; ------------- IMAGEM (guardada em 40, roda em 80) -------------
        .org RAM_SIS
        .guardar_em ARMAZ
        .byte ASSINATURA, fim - RAM_SIS     ; cabecalho
sistema: IN                 ; programa de teste: dobro das chaves
        STA valor
        ADD valor
        OUT
        JMP sistema
fim:
