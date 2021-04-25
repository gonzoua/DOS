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

  Renderer = object
    constructor Init;
    procedure Render(qrPtr: QRCodePtr; invert: Boolean); virtual;
  end;
  RendererPtr = ^Renderer;

  TextRenderer = object(Renderer)
    OrigScreen: ScreenBuffer;
    constructor Init;
    procedure Render(qrPtr: QRCodePtr; invert: Boolean); virtual;
    procedure DisplayNormal(qrPtr: QRCodePtr; invert: Boolean);
    procedure SaveScreenState;
    procedure RestoreScreenState;
  end;
  TextRendererPtr = ^TextRenderer;

implementation

const
  NormalAttr = $7;
  InverseAttr = $7 shl 4;

var
  Screen: ScreenBuffer Absolute $B800 : $0000;

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

procedure TextRenderer.SaveScreenState;
begin
  Move(Screen, OrigScreen, SizeOf(Screen));
end;

procedure TextRenderer.RestoreScreenState;
begin
  Move(OrigScreen, Screen, SizeOf(Screen));
end;

procedure TextRenderer.Render(qrPtr: QRCodePtr; invert: Boolean);
begin
  SaveScreenState;
  DisplayNormal(qrPtr, invert);
  RestoreScreenState;
end;

begin
end.
