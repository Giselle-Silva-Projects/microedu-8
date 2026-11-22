// ==============================================================
// MicroEdu-8: CPU de 8 bits (SAP-1 estendido) com microcodigo
// Para a placa DE1-SoC (Cyclone V 5CSEMA5F31C6) e para o simulador.
//   KEY[0] : da um passo (um clock da CPU) a cada aperto
//   KEY[1] : reset
//   SW[7:0]: entrada (instrucao IN le estas chaves)
//   SW[9]  : 1 = executa sozinho (automatico), 0 = so por botao
//   SW[8]  : 1 = automatico rapido (25x)
//   HEX1:HEX0 : acumulador A em hexadecimal
//   HEX3:HEX2 : registrador de saida (instrucao OUT)
//   LEDR[7:0] : acumulador A em binario
//   LEDR[8]   : 1 quando a CPU executou HLT
//   LEDR[9]   : muda a cada passo
// Instrucoes (2 bytes: opcode, operando):
//   0 HLT        1 n  LDI n    2 n  ADDI n    3 n  SUBI n
//   4 a  LDA a  (A <- M[a])    5 a  STA a  (M[a] <- A)
//   6 a  ADD a  (A <- A + M[a]) 7 a  SUB a  (A <- A - M[a])
//   8 a  JMP a  (PC <- a)      9 a  JZ a   (se A = 0, PC <- a)
//   A a  JNZ a  (se A != 0, PC <- a)
//   B 0  IN     (A <- chaves SW[7:0])
//   C 0  OUT    (saida <- A, aparece em HEX3:HEX2)
// Memoria: 00-7F = ROM (programa)   80-FF = RAM (variaveis)
// ==============================================================

// ---------- CPU ----------
module microedu8_cpu (
    input  wire       clk,
    input  wire       ce,        // 1 = executa um passo neste clock
    input  wire       rst,       // reset geral (nivel 1)
    input  wire [7:0] sw_in,     // chaves de entrada
    output wire [7:0] saida_out, // registrador de saida (OUT)
    output wire [7:0] a_out,
    output wire [7:0] pc_out,
    output wire [7:0] ir_out,
    output wire [7:0] mar_out,
    output wire [3:0] t_out,
    output wire       halted
);
    reg [7:0] a, b, pc, mar, ir, saida;
    reg [3:0] t;
    wire [7:0]  w, m, soma;
    wire [15:0] palavra;
    wire ep, lm, er, li, cp, la, lb, eu, su, hlt, rst_t, ea, wm, lp, ei, lo;
    wire z;

    initial begin
        a = 0; b = 0; pc = 0; mar = 0; ir = 0; t = 0; saida = 0;
    end

    // RAM: enderecos 80-FF (128 bytes)
    reg [7:0] ram [0:127];
    integer i;
    initial begin
        for (i = 0; i < 128; i = i + 1) ram[i] = 8'h00;
    end

    // ROM de programa (enderecos 00-7F). Demonstracao de entrada e saida:
    //   le as chaves, guarda na RAM, soma consigo mesmo (dobro) e mostra em OUT.
    function [7:0] programa;
        input [7:0] endereco;
        begin
            case (endereco)
                8'h00: programa = 8'h0B;  8'h01: programa = 8'h00;   // inicio: IN
                8'h02: programa = 8'h05;  8'h03: programa = 8'h80;   // STA 80
                8'h04: programa = 8'h06;  8'h05: programa = 8'h80;   // ADD 80  (A = 2 x chaves)
                8'h06: programa = 8'h0C;  8'h07: programa = 8'h00;   // OUT
                8'h08: programa = 8'h08;  8'h09: programa = 8'h00;   // JMP inicio
                default: programa = 8'h00;
            endcase
        end
    endfunction

    // Microcodigo: palavra de controle = f(T, opcode, z). Igual ao controle.txt,
    // com bits novos: Ea (A -> barramento), Wm (escreve na RAM), Lp (PC <- barramento)
    function [15:0] microcodigo;
        input [3:0] passo;
        input [3:0] op;
        input       zero;                                          // 1 quando A = 0
        begin
            case (passo)
                4'd0: microcodigo = 16'h003;                       // Ep, Lm
                4'd1: microcodigo = 16'h01c;                       // Er, Li, Cp
                4'd2: case (op)
                          4'd1, 4'd2, 4'd3, 4'd4, 4'd5, 4'd6, 4'd7, 4'd8, 4'd9, 4'd10, 4'd11, 4'd12:
                                   microcodigo = 16'h003;          // Ep, Lm
                          default: microcodigo = 16'h200;          // HLT (e opcodes sem uso): Hlt
                      endcase
                4'd3: case (op)
                          4'd1:    microcodigo = 16'h434;          // LDI: Er, La, Cp, Rst
                          4'd2, 4'd3: microcodigo = 16'h054;       // ADDI/SUBI: Er, Lb, Cp
                          4'd4, 4'd5, 4'd6, 4'd7:
                                   microcodigo = 16'h016;          // Er, Lm, Cp (MAR <- endereco)
                          4'd8:    microcodigo = 16'h2404;         // JMP: Er, Lp, Rst
                          4'd9:    microcodigo = zero ? 16'h2404   // JZ: pula se A = 0
                                                      : 16'h410;   //     senao: Cp, Rst (pula o operando)
                          4'd10:   microcodigo = zero ? 16'h410    // JNZ: pula se A != 0
                                                      : 16'h2404;
                          4'd11:   microcodigo = 16'h4430;         // IN: Ei, La, Cp, Rst
                          4'd12:   microcodigo = 16'h8c10;         // OUT: Ea, Lo, Cp, Rst
                          default: microcodigo = 16'h000;
                      endcase
                4'd4: case (op)
                          4'd2:    microcodigo = 16'h4a0;          // ADDI: Eu, La, Rst
                          4'd3:    microcodigo = 16'h5a0;          // SUBI: Su, Eu, La, Rst
                          4'd4:    microcodigo = 16'h424;          // LDA: Er, La, Rst
                          4'd5:    microcodigo = 16'h1c00;         // STA: Ea, Wm, Rst
                          4'd6, 4'd7:
                                   microcodigo = 16'h044;          // ADD/SUB: Er, Lb
                          default: microcodigo = 16'h000;
                      endcase
                4'd5: case (op)
                          4'd6:    microcodigo = 16'h4a0;          // ADD: Eu, La, Rst
                          4'd7:    microcodigo = 16'h5a0;          // SUB: Su, Eu, La, Rst
                          default: microcodigo = 16'h000;
                      endcase
                default: microcodigo = 16'h000;
            endcase
        end
    endfunction

    // Controlador (combinacional: depende de T e IR)
    assign z = (a == 8'h00);                  // A = 0 ?
    assign palavra = microcodigo(t, ir[3:0], z);
    assign ep    = palavra[0];
    assign lm    = palavra[1];
    assign er    = palavra[2];
    assign li    = palavra[3];
    assign cp    = palavra[4];
    assign la    = palavra[5];
    assign lb    = palavra[6];
    assign eu    = palavra[7];
    assign su    = palavra[8];
    assign hlt   = palavra[9];
    assign rst_t = palavra[10];
    assign ea    = palavra[11];
    assign wm    = palavra[12];
    assign lp    = palavra[13];
    assign ei    = palavra[14];
    assign lo    = palavra[15];

    // Memoria: leitura assincrona em M[MAR] (80-FF = RAM, abaixo = ROM)
    assign m = mar[7] ? ram[mar[6:0]] : programa(mar);

    // ULA: A + B  ou  A - B
    assign soma = su ? (a - b) : (a + b);

    // Barramento W: so uma fonte por vez (Ep, Er, Eu, Ea ou Ei)
    assign w = ep ? pc : er ? m : eu ? soma : ea ? a : ei ? sw_in : 8'h00;

    // Registradores (subida do clock; so andam quando ce = 1)
    always @(posedge clk) begin
        if (rst) begin
            a <= 0; b <= 0; pc <= 0; mar <= 0; ir <= 0; t <= 0; saida <= 0;
        end else if (ce) begin
            if (lm) mar <= w;
            if (li) ir  <= w;
            if (la) a   <= w;
            if (lb) b   <= w;
            if (lo) saida <= w;
            if (lp)      pc <= w;                   // pulo: PC <- endereco
            else if (cp) pc <= pc + 8'd1;
            if (wm && mar[7]) ram[mar[6:0]] <= w;   // escreve na RAM
            if (!hlt) begin                    // Hlt congela o contador T
                if (rst_t) t <= 0;             // Rst volta ao passo 0
                else       t <= t + 4'd1;
            end
        end
    end

    assign a_out   = a;
    assign saida_out = saida;
    assign pc_out  = pc;
    assign ir_out  = ir;
    assign mar_out = mar;
    assign t_out   = t;
    assign halted  = hlt;
endmodule

// ---------- Botao -> um pulso por aperto (com filtro anti-repique) ----------
module botao_pulso #(parameter FILTRO = 500000) (   // 500000 ciclos = 10 ms a 50 MHz
    input  wire clk,
    input  wire btn_n,              // KEY da placa: 0 quando apertado
    output reg  pulso
);
    reg s0, s1, estavel;
    reg [31:0] cont;
    initial begin s0 = 1; s1 = 1; estavel = 1; cont = 0; pulso = 0; end
    always @(posedge clk) begin
        s0 <= btn_n;
        s1 <= s0;
        pulso <= 1'b0;
        if (s1 != estavel) begin
            if (cont >= FILTRO) begin
                estavel <= s1;
                cont <= 0;
                if (s1 == 1'b0) pulso <= 1'b1;    // acabou de ser apertado
            end else cont <= cont + 1;
        end else cont <= 0;
    end
endmodule

// ---------- Digito hexadecimal -> display de 7 segmentos ----------
// Os displays da DE1-SoC acendem com 0 (ativo em nivel baixo).
// Se aparecer "invertido" no simulador, troque ATIVO_BAIXO para 0.
module hex7seg #(parameter ATIVO_BAIXO = 1) (
    input  wire [3:0] v,
    output wire [6:0] seg           // seg[0] = a ... seg[6] = g
);
    reg [6:0] s;
    always @* begin
        case (v)
            4'h0: s = 7'b0111111;  4'h1: s = 7'b0000110;
            4'h2: s = 7'b1011011;  4'h3: s = 7'b1001111;
            4'h4: s = 7'b1100110;  4'h5: s = 7'b1101101;
            4'h6: s = 7'b1111101;  4'h7: s = 7'b0000111;
            4'h8: s = 7'b1111111;  4'h9: s = 7'b1101111;
            4'hA: s = 7'b1110111;  4'hB: s = 7'b1111100;
            4'hC: s = 7'b0111001;  4'hD: s = 7'b1011110;
            4'hE: s = 7'b1111001;  default: s = 7'b1110001;
        endcase
    end
    assign seg = ATIVO_BAIXO ? ~s : s;
endmodule

// ---------- Topo (liga a CPU na placa) ----------
module microedu8_top #(
    parameter DIV    = 25_000_000,  // modo automatico: 1 passo a cada DIV ciclos (2 por segundo)
    parameter FILTRO = 500_000
) (
    input  wire       CLOCK_50,
    input  wire [3:0] KEY,
    input  wire [9:0] SW,
    output wire [9:0] LEDR,
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3
);
    wire passo;
    wire [7:0] a, saida;
    wire halted;
    reg  r0, r1, rst, pisca;
    reg  [31:0] cdiv;
    wire [31:0] limite = SW[8] ? (DIV / 25) : DIV;     // SW8 = rapido
    wire auto_pulso = (cdiv >= limite - 1);
    wire ce = passo | (SW[9] & auto_pulso);

    initial begin r0 = 1; r1 = 1; rst = 1; pisca = 0; cdiv = 0; end

    botao_pulso #(.FILTRO(FILTRO)) u_passo (
        .clk(CLOCK_50), .btn_n(KEY[0]), .pulso(passo));

    always @(posedge CLOCK_50) begin
        r0  <= ~KEY[1];              // KEY[1] apertado (0) -> reset
        r1  <= r0;
        rst <= r1;
        cdiv <= auto_pulso ? 32'd0 : cdiv + 32'd1;
        if (ce) pisca <= ~pisca;
    end

    microedu8_cpu u_cpu (
        .clk(CLOCK_50), .ce(ce), .rst(rst),
        .sw_in(SW[7:0]), .saida_out(saida),
        .a_out(a), .pc_out(), .ir_out(), .mar_out(), .t_out(), .halted(halted));

    hex7seg u_h0 (.v(a[3:0]), .seg(HEX0));
    hex7seg u_h1 (.v(a[7:4]), .seg(HEX1));
    hex7seg u_h2 (.v(saida[3:0]), .seg(HEX2));
    hex7seg u_h3 (.v(saida[7:4]), .seg(HEX3));

    assign LEDR[7:0] = a;
    assign LEDR[8]   = halted;
    assign LEDR[9]   = pisca;
endmodule
