// ==============================================================
// microedu8_placa.v  -  Topo para a DE1-SoC COM a placa de expansao
//
// Usa o microedu8_top.v sem alteracoes e acrescenta tres sinais no
// conector GPIO_0, ligados a placa de expansao:
//   BUZZER       (GPIO_0[0]) : saida; da um bip a cada mudanca da saida
//                              (HEX3:HEX2), por exemplo ao trocar de tela
//   ENTER_EXT_N  (GPIO_0[1]) : entrada; botao ENTER externo (0 = apertado)
//   RESET_EXT_N  (GPIO_0[2]) : entrada; botao RESET externo (0 = apertado)
// Os botoes externos funcionam junto com KEY2 (ENTER) e KEY1 (reset).
// No simulador, continue usando so o microedu8_top.v.
// ==============================================================
module microedu8_placa #(
    parameter DIV    = 25_000_000,
    parameter FILTRO = 500_000,
    parameter BIP    = 4_000_000        // duracao do bip: 80 ms a 50 MHz
) (
    input  wire       CLOCK_50,
    input  wire [3:0] KEY,
    input  wire [9:0] SW,
    output wire [9:0] LEDR,
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire       BUZZER,
    input  wire       ENTER_EXT_N,
    input  wire       RESET_EXT_N
);
    // botao da placa e botao externo valem igual (os dois sao ativos em 0)
    wire [3:0] key_ef = {KEY[3], KEY[2] & ENTER_EXT_N, KEY[1] & RESET_EXT_N, KEY[0]};

    wire [6:0] h0, h1, h2, h3;

    microedu8_top #(.DIV(DIV), .FILTRO(FILTRO)) u_maquina (
        .CLOCK_50(CLOCK_50), .KEY(key_ef), .SW(SW), .LEDR(LEDR),
        .HEX0(h0), .HEX1(h1), .HEX2(h2), .HEX3(h3));

    assign HEX0 = h0;
    assign HEX1 = h1;
    assign HEX2 = h2;
    assign HEX3 = h3;

    // Bip: sempre que o que aparece em HEX3:HEX2 muda, o buzzer toca por BIP ciclos
    reg [13:0] saida_ant;
    reg [31:0] bip_cont;
    initial begin saida_ant = 14'd0; bip_cont = 32'd0; end

    always @(posedge CLOCK_50) begin
        saida_ant <= {h3, h2};
        if ({h3, h2} != saida_ant) bip_cont <= BIP;
        else if (bip_cont != 32'd0) bip_cont <= bip_cont - 32'd1;
    end

    assign BUZZER = (bip_cont != 32'd0);
endmodule
