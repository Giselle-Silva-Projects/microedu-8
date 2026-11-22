; dobro.asm - le as chaves, calcula o dobro e mostra em OUT
valor = 0x80            ; endereco da RAM onde guardamos o numero

inicio: IN              ; A = chaves
        STA valor       ; guarda na RAM
        ADD valor       ; A = chaves + chaves
        OUT             ; mostra em HEX3:HEX2
        JMP inicio      ; repete para sempre
