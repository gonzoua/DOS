uses Crt, Dos;

type
   ScreenBuffer = array [1..4000] of byte;
   CodePage = array [$21..$FF,1..16] of byte;
   Characters = array [1..256] of byte;

var
   Ch: char;
   Screen: ScreenBuffer Absolute $B800 : $0000;
   OrigCodePage : CodePage;
   ClearText, EncryptedText : Characters;

procedure GetCodePage;
var
    regs : Registers;
    i, j, offset : integer;
begin
     with regs do
     begin
          AH := $11;
          AL := $30;
          BH := $6; { 8x16 font }
          Intr($10, regs);
          offset := $21 * 16;
          for i := $21 to $FF do
              for j := 1 to 16 do
              begin
                   OrigCodePage[i][j] := Mem[ES:BP + offset];
                   Inc(offset);
              end;
     end;
end;

procedure HideCursor;
var
    regs : Registers;
begin
     with regs do
     begin
          AX := $0100;
          CH := $20;
          CL := $20;
          Intr($10, regs);
     end;
end;

procedure MarkUnencrypted(b : byte);
var
   i : Integer;
begin
     i := 1;
     while i <= 4000 do
     begin
          if Screen[i] = b then Screen[i + 1] := $09;
          Inc(i, 2);
     end;
end;

procedure SetCodePage(clear, code : Characters; total : Integer);
var
   regs : Registers;
   page : CodePage;
   i, pos_from, pos_to : Integer;
begin
     for i := 1 to total do
     begin
         pos_from := code[i];
         pos_to := clear[i];
         {
         Write('From ');
         Write(pos_from);
         Write(' to ');
         WriteLn(pos_to);
         }
         page[pos_to] := OrigCodePage[pos_from];
     end;

     with regs do
     begin
          AH := $11;
          AL := $0;
          BH := 16; { font height }
          BL := 0;   { code page }
          CX := $FF - $21 + 1; { total symbols }
          DX := $21; { start symbol }
          ES := Seg(page);
          BP := Ofs(page);
          Intr($10, regs);
     end;
end;

procedure RestoreCodePage;
var
   regs : Registers;
begin
     with regs do
     begin
          AH := $11;
          AL := $4;
          BL := 0;
          Intr($10, regs);
     end;
end;

procedure Shuffle(var a : Characters; start, stop : integer);
var
    i,r : Integer;
    v : Byte;
begin
    Randomize;

    for i := stop downto start do
    begin
        r := Random(stop - start) + start;
        v := a[i];
        a[i] := a[r];
        a[r] := v;
    end;
end;

procedure CreateMenu;
var
    i : Integer;
    menuY : Integer;
begin
     WriteLn('HEX CONTROL NODE: 5SYS-1719');
     GoToXY(70, 1);
     Write('arc17/s12');

     GoToXY(8, 8);
     for i := 1 to 64 do Write('=');

     menuY := 10;
     GoToXY(10, menuY);
     WriteLn('[1] Transfer Collected Data to Secure Storage');
     GoToXY(10, menuY + 1);
     WriteLn('[2] Update Processing Unit Firmware');
     GoToXY(10, menuY + 2);
     WriteLn('[3] Self Test Laser Components');
     GoToXY(10, menuY + 3);
     WriteLn('[4] Run Scan on All Locked Targets');
     GoToXY(10, menuY + 4);
     WriteLn('[5] Commence Procedure 205b');
     GoToXY(10, menuY + 5);
     WriteLn('[6] Hibernate Until Further Notice');

     GoToXY(8, menuY + 8);
     for i := 1 to 64 do Write('=');
end;

var
    i, j, total : Integer;
    stillEncrypted : Integer;
    b, v : Byte;

begin
     ClrScr;
     HideCursor;
     GetCodePage;

     total := 1;
     for i := $21 to $FF do
     begin
         ClearText[total] := i;
         EncryptedText[total] := i;
         Inc(total);
     end;
     Dec(total);
     stillEncrypted := total;

     Shuffle(ClearText, 1, total);
     Shuffle(EncryptedText, 1, total);
     SetCodePage(ClearText, EncryptedText, total);

     CreateMenu;

     for i := $21 to $FF do
     begin
          Shuffle(EncryptedText, 1, stillEncrypted);
          SetCodePage(ClearText, EncryptedText, total);
          b := clearText[stillEncrypted];
          for j := 1 to stillEncrypted do
          begin
               if EncryptedText[j] = b then
               begin
                    EncryptedText[j] := EncryptedText[stillEncrypted];
                    EncryptedText[stillEncrypted] := b;
               end
          end;
          MarkUnencrypted(b);
          Dec(stillEncrypted);
          Delay(50);
     end;
     ch := ReadKey;
     RestoreCodePage;
end.