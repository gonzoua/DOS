{***************************************************************************}
{ Copyright 2021 Google LLC                                                 }
{                                                                           }
{ Licensed under the Apache License, Version 2.0 (the "License");           }
{ you may not use this file except in compliance with the License.          }
{ You may obtain a copy of the License at                                   }
{                                                                           }
{     https://www.apache.org/licenses/LICENSE-2.0                           }
{                                                                           }
{ Unless required by applicable law or agreed to in writing, software       }
{ distributed under the License is distributed on an "AS IS" BASIS,         }
{ WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  }
{ See the License for the specific language governing permissions and       }
{ limitations under the License.                                            }
{***************************************************************************}

unit Render;

interface

uses QR, Crt, Dos;
const
  ScreenWidth = 80;
  ScreenHeight = 25;
  ScreenBufferSize = ScreenWidth*ScreenHeight*2;
type
  ScreenBuffer = array [0..ScreenBufferSize-1] of Word;
  CodePage = array [$0..$FF,0..15] of byte;

  Renderer = object
    constructor Init;
    procedure Render(qrPtr: QRCodePtr; invert: Boolean); virtual;
  end;
  RendererPtr = ^Renderer;

  TextRenderer = object(Renderer)
    OrigScreen: ScreenBuffer;
    QRCodePage, OrigCodePage : CodePage;
    constructor Init;
    procedure Render(qrPtr: QRCodePtr; invert: Boolean); virtual;
    procedure DisplayNormal(qrPtr: QRCodePtr; invert: Boolean);
    procedure DisplayHighRes(qrPtr: QRCodePtr; invert: Boolean);
    procedure GenerateQRCodePage;
    procedure SaveScreenState;
    procedure RestoreScreenState;
  end;
  TextRendererPtr = ^TextRenderer;

  RendererFactory = object
    function Create: RendererPtr;
  end;
implementation

const
  NormalAttr = $7;
  InverseAttr = $7 shl 4;

var
  Screen: ScreenBuffer Absolute $B800 : $0000;

procedure SaveOrigCodePage(var page: Codepage);
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
    offset := $0 * 16;
    for i := $0 to $FF do
      for j := 0 to 15 do
      begin
        page[i][j] := Mem[ES:BP + offset];
        Inc(offset);
      end;
   end;
end;

procedure SetCodePage(var page : Codepage);
var
   regs : Registers;
   i, pos_from, pos_to : Integer;
begin
     with regs do
     begin
          AH := $11;
          AL := $0;
          BH := 16;   { font height }
          BL := 0;    { code page }
          CX := $100; { total symbols }
          DX := $0;   { start symbol }
          ES := Seg(page);
          BP := Ofs(page);
          Intr($10, regs);
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

procedure ShowCursor;
var
  regs : Registers;
begin
  with regs do
  begin
    AX := $0100;
    CH := $06;
    CL := $07;
    Intr($10, regs);
  end;
end;

constructor Renderer.Init;
begin
end;

procedure Renderer.Render(qrPtr: QRCodePtr; invert: Boolean);
begin
  WriteLn('Implement me: Renderer.Render');
end;

constructor TextRenderer.Init;
begin
  Renderer.Init;
  GenerateQRCodepage;
end;

procedure TextRenderer.DisplayNormal(qrPtr: QRCodePtr; invert: Boolean);
var
  row, col: Integer;
  val: Module;
  bits: Byte;
  originX, originY: Integer;
  k: Char;
  fill: Word;
  attr: Word;
begin
  HideCursor;
  if invert then
    attr := InverseAttr
  else
    attr := NormalAttr;

  originX := (ScreenWidth - qrPtr^.QRSize) div 2;
  originY := (ScreenHeight - qrPtr^.QRSize div 2) div 2;

  { Clean area with borders for QR }
  for row := originY - 1 to originY + qrPtr^.QRSize div 2 + 1  do
    for col := originX - 2 to originX + qrPtr^.QRSize + 1 do
      if ((row >= 0) and (row < ScreenHeight)) and
          ((col >= 0) and (col < ScreenWidth)) then
        Screen[row*ScreenWidth + col] := (attr shl 8) or 219;

  row := 0;
  while row <= qrPtr^.QRSize - 1 do
  begin
    for col := 0 to qrPtr^.QRSize - 1 do
    begin
      if qrPtr^.GetModule(row, col) = Light then
        bits := 2
      else
        bits := 0;
      if qrPtr^.GetModule(row + 1, col) = Light then
          bits := bits or 1;
      case bits of
        0: fill := $20;
        1: fill := 220;
        2: fill := 223;
        3: fill := 219;
      end;
      Screen[(originY + row div 2) * ScreenWidth + (originX + col)] :=
        fill or (attr shl 8);
    end;
    row := row + 2;
  end;
  k := ReadKey;
  ShowCursor;
end;

procedure TextRenderer.DisplayHighRes(qrPtr: QRCodePtr; invert: Boolean);
var
  row, col: Byte;
  val: Module;
  bits: Byte;
  originX, originY: Integer;
  x, y: Integer;
  k: Char;
  attr: Word;
begin
  HideCursor;
  SaveOrigCodePage(OrigCodePage);
  SetCodepage(QRCodePage);
  if invert then
    attr := InverseAttr
  else
    attr := NormalAttr;
  for row := 0 to ScreenHeight - 1 do
    for col := 0 to ScreenWidth - 1 do
      Screen[row*ScreenWidth + col] := (attr shl 8) or $FF;
  originX := (ScreenWidth - qrPtr^.QRSize div 2) div 2;
  originY := (ScreenHeight - qrPtr^.QRSize div 4) div 2;
  row := 0;
  while row <= qrPtr^.QRSize - 1 do
  begin
    col := 0;
    while col <= qrPtr^.QRSize - 1 do
    begin

      bits := 0;
      for y := 0 to 3 do
        for x := 0 to 1 do
        begin
          bits := bits shl 1;
          bits := bits or Byte(qrPtr^.GetModule(row + y, col + x) = Light);
        end;

      Screen[(originY + row div 4) * ScreenWidth + (originX + col div 2)] :=
        bits or (attr shl 8);
      col := col + 2;
    end;
    row := row + 4;
  end;
  k := ReadKey;
  SetCodePage(OrigCodePage);
  ShowCursor;
end;

procedure TextRenderer.SaveScreenState;
begin
  Move(Screen, OrigScreen, SizeOf(Screen));
end;

procedure TextRenderer.RestoreScreenState;
begin
  Move(OrigScreen, Screen, SizeOf(Screen));
end;

procedure TextRenderer.GenerateQRCodepage;
var
  c, col, row, bit, bits: Byte;
begin
  { Generate QR codegenerator data }
  FillChar(QRCodePage, SizeOf(QRCodePage), 0);
  for c := 0 to $FF do
  begin
    for col := 0 to 1 do
      for row := 0 to 3 do
      begin
        if ((c shr (7 - (row * 2 + col))) and 1) = 1 then
          bits := $F shl ((1 - col) * 4)
        else
          bits := 0;

        QRCodePage[c][row*4]     := QRCodePage[c][row*4] or bits;
        QRCodePage[c][row*4 + 1] := QRCodePage[c][row*4 + 1] or bits;
        QRCodePage[c][row*4 + 2] := QRCodePage[c][row*4 + 2] or bits;
        QRCodePage[c][row*4 + 3] := QRCodePage[c][row*4 + 3] or bits;
      end;
  end;
end;

procedure TextRenderer.Render(qrPtr: QRCodePtr; invert: Boolean);
begin
  SaveScreenState;
  if qrPtr^.QRSize < 48 then
    DisplayNormal(qrPtr, invert)
  else
    DisplayHighRes(qrPtr, invert);
  RestoreScreenState;
end;

function RendererFactory.Create: RendererPtr;
begin
  { TODO: Add printer and graphics renderers }
  Create := New(TextRendererPtr, Init);
end;

begin
end.