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

Unit BitStr;

interface

const
  MaxBufferSize = 8196;

type
  ByteBuffer = array[0..MaxBufferSize - 1] of Byte;
  ByteBufferPtr = ^ByteBuffer;
  BitStream = object
    Buffer: ByteBufferPtr;
    BitPtr: Integer;
    BufferLength: Integer;
    constructor Init;
    destructor Done; virtual;
    procedure AddBits(data: Word; bits: Byte);
    procedure ReallocateBuffer;
    procedure PadToByte;
    procedure Dump;
    function BitLength: Integer;
    function ByteLength: Integer;
    function GetByte(idx: Integer): Byte;
  end;

implementation

constructor BitStream.Init;
var
  i: Integer;
begin
  BufferLength := 256; { reasonable default }
  GetMem(Buffer, BufferLength);
  for i := 0 to BufferLength - 1 do
    Buffer^[i] := 0;
  BitPtr := 0;
end;

destructor BitStream.Done;
begin
  FreeMem(Buffer, BufferLength);
end;

procedure BitStream.ReallocateBuffer;
var
  i: Integer;
  newBuffer: ByteBufferPtr;
begin
  GetMem(newBuffer, BufferLength*2);
  for i := 0 to BufferLength - 1 do
    newBuffer^[i] := Buffer^[i];
  for i:= BufferLength to 2*BufferLength - 1 do
    newBuffer^[i] := 0;
  FreeMem(Buffer, BufferLength);
  Buffer := newBuffer;
  BufferLength := BufferLength * 2;
end;

procedure BitStream.AddBits(data: Word; bits: Byte);
var
  i, newByteLength: Integer;
  bit, shift: Integer;
begin
  newByteLength := (BitPtr + bits) div 8;
  if (bitPtr + bits) mod 8 <> 0 then
    newByteLength := newByteLength + 1;
  if newByteLength > BufferLength then
    ReallocateBuffer;

  for i := bits - 1 downto 0 do
  begin
    bit := (data shr i) and 1;
    bit := bit shl (7 - (bitPtr mod 8));
    Buffer^[bitPtr div 8] :=  Buffer^[bitPtr div 8] or bit;
    bitPtr := bitPtr + 1;
  end;
end;

procedure BitStream.PadToByte;
begin
  if BitPtr mod 8 <> 0 then
    BitPtr := BitPtr - (BitPtr mod 8) + 8;
end;

function BitStream.BitLength: Integer;
begin
  BitLength := BitPtr;
end;

function BitStream.ByteLength: Integer;
var
  l: Integer;
begin
  l := BitPtr div 8;
  if BitPtr mod 8 <> 0 then
    l := l + 1;
    ByteLength := l;
end;

function BitStream.GetByte(idx: Integer): Byte;
begin
  GetByte := Buffer^[idx];
end;

procedure BitStream.Dump;
var
  i, bytes: Integer;
begin
  bytes := BitPtr div 8;
  if BitPtr mod 8 <> 0 then
    bytes := bytes + 1;
  Write('Bitstream is ');
  Write(BitPtr, ' bit(s):');
  for i := 0 to bytes - 1 do
    Write(Buffer^[i], ' ');
  WriteLn;
end;

begin
end.