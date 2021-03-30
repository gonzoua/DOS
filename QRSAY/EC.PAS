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

unit EC;

interface
uses BitStr;

const
  ECLevelAny = -1;
  ECLevelL = 1;
  ECLevelM = 0;
  ECLevelQ = 3;
  ECLevelH = 2;

  QRVersionAny = -1;

type
  ECInfo = object
    Version: Byte;
    Level: Byte;
    ECWordsPerBlock: Byte;
    BlocksInGroup1: Byte;
    Block1Len: Byte;
    BlocksInGroup2: Byte;
    Block2Len: Byte;
    function TotalBlocks: Integer;
    function TotalDataWords: Integer;
    function TotalECWords: Integer;
    function TotalWords: Integer;
    function BlockOffset(block: Byte): Integer;
    function BlockLen(block: Byte): Integer;
    function ECBlockOffset(block: Byte): Integer;
  end;

  ECInfoPtr = ^ECInfo;

const
  ECInfoTotal = 20*4;
  ECInfoTable: array[1..ECInfoTotal] of ECInfo = (
    (
      Version:1; Level:ECLevelL; EcWordsPerBlock:7;
      BlocksInGroup1: 1; Block1Len: 19;
      BlocksInGroup2: 0; Block2Len: 0
    ),    (
      Version:1; Level:ECLevelM; EcWordsPerBlock:10;
      BlocksInGroup1: 1; Block1Len: 16;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:1; Level:ECLevelQ; EcWordsPerBlock:13;
      BlocksInGroup1: 1; Block1Len: 13;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:1; Level:ECLevelH; EcWordsPerBlock:17;
      BlocksInGroup1: 1; Block1Len: 9;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:2; Level:ECLevelL; EcWordsPerBlock:10;
      BlocksInGroup1: 1; Block1Len: 34;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:2; Level:ECLevelM; EcWordsPerBlock:16;
      BlocksInGroup1: 1; Block1Len: 28;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:2; Level:ECLevelQ; EcWordsPerBlock:22;
      BlocksInGroup1: 1; Block1Len: 22;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:2; Level:ECLevelH; EcWordsPerBlock:28;
      BlocksInGroup1: 1; Block1Len: 16;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:3; Level:ECLevelL; EcWordsPerBlock:15;
      BlocksInGroup1: 1; Block1Len: 55;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:3; Level:ECLevelM; EcWordsPerBlock:26;
      BlocksInGroup1: 1; Block1Len: 44;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:3; Level:ECLevelQ; EcWordsPerBlock:18;
      BlocksInGroup1: 2; Block1Len: 17;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:3; Level:ECLevelH; EcWordsPerBlock:22;
      BlocksInGroup1: 2; Block1Len: 13;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:4; Level:ECLevelL; EcWordsPerBlock:20;
      BlocksInGroup1: 1; Block1Len: 80;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:4; Level:ECLevelM; EcWordsPerBlock:18;
      BlocksInGroup1: 2; Block1Len: 32;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:4; Level:ECLevelQ; EcWordsPerBlock:26;
      BlocksInGroup1: 2; Block1Len: 24;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:4; Level:ECLevelH; EcWordsPerBlock:16;
      BlocksInGroup1: 4; Block1Len: 9;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:5; Level:ECLevelL; EcWordsPerBlock:26;
      BlocksInGroup1: 1; Block1Len: 108;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:5; Level:ECLevelM; EcWordsPerBlock:24;
      BlocksInGroup1: 2; Block1Len: 43;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:5; Level:ECLevelQ; EcWordsPerBlock:18;
      BlocksInGroup1: 2; Block1Len: 15;
      BlocksInGroup2: 2; Block2Len: 16
    ),
    (
      Version:5; Level:ECLevelH; EcWordsPerBlock:22;
      BlocksInGroup1: 2; Block1Len: 11;
      BlocksInGroup2: 2; Block2Len: 12
    ),
    (
      Version:6; Level:ECLevelL; EcWordsPerBlock:18;
      BlocksInGroup1: 2; Block1Len: 68;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:6; Level:ECLevelM; EcWordsPerBlock:16;
      BlocksInGroup1: 4; Block1Len: 27;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:6; Level:ECLevelQ; EcWordsPerBlock:24;
      BlocksInGroup1: 4; Block1Len: 19;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:6; Level:ECLevelH; EcWordsPerBlock:28;
      BlocksInGroup1: 4; Block1Len: 15;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:7; Level:ECLevelL; EcWordsPerBlock:20;
      BlocksInGroup1: 2; Block1Len: 78;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:7; Level:ECLevelM; EcWordsPerBlock:18;
      BlocksInGroup1: 4; Block1Len: 31;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:7; Level:ECLevelQ; EcWordsPerBlock:18;
      BlocksInGroup1: 2; Block1Len: 14;
      BlocksInGroup2: 4; Block2Len: 15
    ),
    (
      Version:7; Level:ECLevelH; EcWordsPerBlock:26;
      BlocksInGroup1: 4; Block1Len: 13;
      BlocksInGroup2: 1; Block2Len: 14
    ),
    (
      Version:8; Level:ECLevelL; EcWordsPerBlock:24;
      BlocksInGroup1: 2; Block1Len: 97;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:8; Level:ECLevelM; EcWordsPerBlock:22;
      BlocksInGroup1: 2; Block1Len: 38;
      BlocksInGroup2: 2; Block2Len: 39
    ),
    (
      Version:8; Level:ECLevelQ; EcWordsPerBlock:22;
      BlocksInGroup1: 4; Block1Len: 18;
      BlocksInGroup2: 2; Block2Len: 19
    ),
    (
      Version:8; Level:ECLevelH; EcWordsPerBlock:26;
      BlocksInGroup1: 4; Block1Len: 14;
      BlocksInGroup2: 2; Block2Len: 15
    ),
    (
      Version:9; Level:ECLevelL; EcWordsPerBlock:30;
      BlocksInGroup1: 2; Block1Len: 116;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:9; Level:ECLevelM; EcWordsPerBlock:22;
      BlocksInGroup1: 3; Block1Len: 36;
      BlocksInGroup2: 2; Block2Len: 37
    ),
    (
      Version:9; Level:ECLevelQ; EcWordsPerBlock:20;
      BlocksInGroup1: 4; Block1Len: 16;
      BlocksInGroup2: 4; Block2Len: 17
    ),
    (
      Version:9; Level:ECLevelH; EcWordsPerBlock:24;
      BlocksInGroup1: 4; Block1Len: 12;
      BlocksInGroup2: 4; Block2Len: 13
    ),
    (
      Version:10; Level:ECLevelL; EcWordsPerBlock:18;
      BlocksInGroup1: 2; Block1Len: 68;
      BlocksInGroup2: 2; Block2Len: 69
    ),
    (
      Version:10; Level:ECLevelM; EcWordsPerBlock:26;
      BlocksInGroup1: 4; Block1Len: 43;
      BlocksInGroup2: 1; Block2Len: 44
    ),
    (
      Version:10; Level:ECLevelQ; EcWordsPerBlock:28;
      BlocksInGroup1: 6; Block1Len: 19;
      BlocksInGroup2: 2; Block2Len: 20
    ),
    (
      Version:10; Level:ECLevelH; EcWordsPerBlock:24;
      BlocksInGroup1: 6; Block1Len: 15;
      BlocksInGroup2: 2; Block2Len: 16
    ),
    (
      Version:11; Level:ECLevelL; EcWordsPerBlock:20;
      BlocksInGroup1: 4; Block1Len: 81;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:11; Level:ECLevelM; EcWordsPerBlock:30;
      BlocksInGroup1: 1; Block1Len: 50;
      BlocksInGroup2: 4; Block2Len: 51
    ),
    (
      Version:11; Level:ECLevelQ; EcWordsPerBlock:28;
      BlocksInGroup1: 4; Block1Len: 22;
      BlocksInGroup2: 4; Block2Len: 23
    ),
    (
      Version:11; Level:ECLevelH; EcWordsPerBlock:24;
      BlocksInGroup1: 3; Block1Len: 12;
      BlocksInGroup2: 8; Block2Len: 13
    ),
    (
      Version:12; Level:ECLevelL; EcWordsPerBlock:24;
      BlocksInGroup1: 2; Block1Len: 92;
      BlocksInGroup2: 2; Block2Len: 93
    ),
    (
      Version:12; Level:ECLevelM; EcWordsPerBlock:22;
      BlocksInGroup1: 6; Block1Len: 36;
      BlocksInGroup2: 2; Block2Len: 37
    ),
    (
      Version:12; Level:ECLevelQ; EcWordsPerBlock:26;
      BlocksInGroup1: 4; Block1Len: 20;
      BlocksInGroup2: 6; Block2Len: 21
    ),
    (
      Version:12; Level:ECLevelH; EcWordsPerBlock:28;
      BlocksInGroup1: 7; Block1Len: 14;
      BlocksInGroup2: 4; Block2Len: 15
    ),
    (
      Version:13; Level:ECLevelL; EcWordsPerBlock:26;
      BlocksInGroup1: 4; Block1Len: 107;
      BlocksInGroup2: 0; Block2Len: 0
    ),
    (
      Version:13; Level:ECLevelM; EcWordsPerBlock:22;
      BlocksInGroup1: 8; Block1Len: 37;
      BlocksInGroup2: 1; Block2Len: 38
    ),
    (
      Version:13; Level:ECLevelQ; EcWordsPerBlock:24;
      BlocksInGroup1: 8; Block1Len: 20;
      BlocksInGroup2: 4; Block2Len: 21
    ),
    (
      Version:13; Level:ECLevelH; EcWordsPerBlock:22;
      BlocksInGroup1: 12; Block1Len: 11;
      BlocksInGroup2: 4; Block2Len: 12
    ),
    (
      Version:14; Level:ECLevelL; EcWordsPerBlock:30;
      BlocksInGroup1: 3; Block1Len: 115;
      BlocksInGroup2: 1; Block2Len: 116
    ),
    (
      Version:14; Level:ECLevelM; EcWordsPerBlock:24;
      BlocksInGroup1: 4; Block1Len: 40;
      BlocksInGroup2: 5; Block2Len: 41
    ),
    (
      Version:14; Level:ECLevelQ; EcWordsPerBlock:20;
      BlocksInGroup1: 11; Block1Len: 16;
      BlocksInGroup2: 5; Block2Len: 17
    ),
    (
      Version:14; Level:ECLevelH; EcWordsPerBlock:24;
      BlocksInGroup1: 11; Block1Len: 12;
      BlocksInGroup2: 5; Block2Len: 13
    ),
    (
      Version:15; Level:ECLevelL; EcWordsPerBlock:22;
      BlocksInGroup1: 5; Block1Len: 87;
      BlocksInGroup2: 1; Block2Len: 88
    ),
    (
      Version:15; Level:ECLevelM; EcWordsPerBlock:24;
      BlocksInGroup1: 5; Block1Len: 41;
      BlocksInGroup2: 5; Block2Len: 42
    ),
    (
      Version:15; Level:ECLevelQ; EcWordsPerBlock:30;
      BlocksInGroup1: 5; Block1Len: 24;
      BlocksInGroup2: 7; Block2Len: 25
    ),
    (
      Version:15; Level:ECLevelH; EcWordsPerBlock:24;
      BlocksInGroup1: 11; Block1Len: 12;
      BlocksInGroup2: 7; Block2Len: 13
    ),
    (
      Version:16; Level:ECLevelL; EcWordsPerBlock:24;
      BlocksInGroup1: 5; Block1Len: 98;
      BlocksInGroup2: 1; Block2Len: 99
    ),
    (
      Version:16; Level:ECLevelM; EcWordsPerBlock:28;
      BlocksInGroup1: 7; Block1Len: 45;
      BlocksInGroup2: 3; Block2Len: 46
    ),
    (
      Version:16; Level:ECLevelQ; EcWordsPerBlock:24;
      BlocksInGroup1: 15; Block1Len: 19;
      BlocksInGroup2: 2; Block2Len: 20
    ),
    (
      Version:16; Level:ECLevelH; EcWordsPerBlock:30;
      BlocksInGroup1: 3; Block1Len: 15;
      BlocksInGroup2: 13; Block2Len: 16
    ),
    (
      Version:17; Level:ECLevelL; EcWordsPerBlock:28;
      BlocksInGroup1: 1; Block1Len: 107;
      BlocksInGroup2: 5; Block2Len: 108
    ),
    (
      Version:17; Level:ECLevelM; EcWordsPerBlock:28;
      BlocksInGroup1: 10; Block1Len: 46;
      BlocksInGroup2: 1; Block2Len: 47
    ),
    (
      Version:17; Level:ECLevelQ; EcWordsPerBlock:28;
      BlocksInGroup1: 1; Block1Len: 22;
      BlocksInGroup2: 15; Block2Len: 23
    ),
    (
      Version:17; Level:ECLevelH; EcWordsPerBlock:28;
      BlocksInGroup1: 2; Block1Len: 14;
      BlocksInGroup2: 17; Block2Len: 15
    ),
    (
      Version:18; Level:ECLevelL; EcWordsPerBlock:30;
      BlocksInGroup1: 5; Block1Len: 120;
      BlocksInGroup2: 1; Block2Len: 121
    ),
    (
      Version:18; Level:ECLevelM; EcWordsPerBlock:26;
      BlocksInGroup1: 9; Block1Len: 43;
      BlocksInGroup2: 4; Block2Len: 44
    ),
    (
      Version:18; Level:ECLevelQ; EcWordsPerBlock:28;
      BlocksInGroup1: 17; Block1Len: 22;
      BlocksInGroup2: 1; Block2Len: 23
    ),
    (
      Version:18; Level:ECLevelH; EcWordsPerBlock:28;
      BlocksInGroup1: 2; Block1Len: 14;
      BlocksInGroup2: 19; Block2Len: 15
    ),
    (
      Version:19; Level:ECLevelL; EcWordsPerBlock:28;
      BlocksInGroup1: 3; Block1Len: 113;
      BlocksInGroup2: 4; Block2Len: 114
    ),
    (
      Version:19; Level:ECLevelM; EcWordsPerBlock:26;
      BlocksInGroup1: 3; Block1Len: 44;
      BlocksInGroup2: 11; Block2Len: 45
    ),
    (
      Version:19; Level:ECLevelQ; EcWordsPerBlock:26;
      BlocksInGroup1: 17; Block1Len: 21;
      BlocksInGroup2: 4; Block2Len: 22
    ),
    (
      Version:19; Level:ECLevelH; EcWordsPerBlock:26;
      BlocksInGroup1: 9; Block1Len: 13;
      BlocksInGroup2: 16; Block2Len: 14
    ),
    (
      Version:20; Level:ECLevelL; EcWordsPerBlock:28;
      BlocksInGroup1: 3; Block1Len: 107;
      BlocksInGroup2: 5; Block2Len: 108
    ),
    (
      Version:20; Level:ECLevelM; EcWordsPerBlock:26;
      BlocksInGroup1: 3; Block1Len: 41;
      BlocksInGroup2: 13; Block2Len: 42
    ),
    (
      Version:20; Level:ECLevelQ; EcWordsPerBlock:30;
      BlocksInGroup1: 15; Block1Len: 24;
      BlocksInGroup2: 5; Block2Len: 25
    ),
    (
      Version:20; Level:ECLevelH; EcWordsPerBlock:28;
      BlocksInGroup1: 15; Block1Len: 15;
      BlocksInGroup2: 10; Block2Len: 16
    )
  );

function FindECInfo(version, level: Integer; length: Integer): ECInfoPtr;
procedure CalculateEC(buf: ByteBufferPtr; info: ECInfoPtr);

implementation

type
  ExpLogTableEntry = record
    Log, Exp: Word;
  end;
  ExpLogTable = Array[0..255] of ExpLogTableEntry;

var
  ExpLog: ExpLogTable;

procedure InitExpLog;
var
  i, exp: Word;
begin
  exp := 1;
  ExpLog[0].Exp := exp;
  ExpLog[1].Log := 0;

  for i := 1 to 255 do
  begin
    exp := exp * 2;
    if exp >= 256 then
        exp := exp xor 285;
    ExpLog[i].Exp := exp;
    ExpLog[exp].Log := (i mod 255);
  end;
end;

function PolyMul(x, y: Byte): Byte;
begin
  if (x <> 0) and (y <> 0) then
  begin
    PolyMul := ExpLog[(ExpLog[x].Log + ExpLog[y].Log) mod 255].Exp;
  end else
    PolyMul := 0;
end;

function ECInfo.TotalDataWords: Integer;
begin
  TotalDataWords := BlocksInGroup1 * Block1Len + BlocksInGroup2 * Block2Len;
end;

function ECInfo.TotalBlocks: Integer;
begin
  TotalBlocks := BlocksInGroup1 + BlocksInGroup2;
end;

function ECInfo.TotalECWords: Integer;
begin
  TotalECWords := TotalBlocks * ECWordsPerBlock;
end;

function ECInfo.TotalWords: Integer;
begin
  TotalWords := TotalECWords + TotalDataWords;
end;

function ECInfo.BlockOffset(block: Byte): Integer;
begin
  if block < BlocksInGroup1 then
    BlockOffset := block * Block1Len
  else
    BlockOffset := BlocksInGroup1 * Block1Len +
      (block - BlocksInGroup1) * Block2Len;
end;

function ECInfo.BlockLen(block: Byte): Integer;
begin
  if block < BlocksInGroup1 then
    BlockLen := Block1Len
  else
    BlockLen := Block2Len;
end;

function ECInfo.ECBlockOffset(block: Byte): Integer;
begin
  ECBlockOffset := TotalDataWords + block * ECWordsPerBlock;
end;

procedure CalculateECBlock(buf: ByteBufferPtr;
  dataOffset, dataLen, ecOffset, ecLen: Word);
var
  i, j, alpha: Word;
  { Generative and  message polynomials }
  g, msg: Array[0..255] of Byte;
begin

  for i := 0 to SizeOf(g) - 1  do
  begin
    g[i] := 0;
    msg[i] := 0;
  end;

  { Create generative polynomial }
  g[0] := 1;
  g[1] := 1;
  for j := 1 to ecLen - 1 do
  begin
    alpha := ExpLog[j].Exp;
    for i := j+1 downto 1 do
      g[i] := PolyMul(alpha, g[i]) xor g[i-1];
    g[0] := PolyMul(g[0], alpha);
  end;

  for j := dataLen - 1 downto 0 do
      msg[j + ecLen] := buf^[dataOffset + (dataLen - 1 - j)];

  { msg mod g }
  for j := dataLen + ecLen - 1 downto ecLen  do
  begin
    alpha := msg[j];
    for i := ecLen downto 0 do
      msg[j - (ecLen - i)] := msg[j - (ecLen - i)] xor PolyMul(g[i], alpha);
  end;

  {  copy back EC data }
  for i := ecLen - 1 downto 0 do
    buf^[ecOffset + ecLen - i - 1] := msg[i];
end;

procedure CalculateEC(buf: ByteBufferPtr; info: ECInfoPtr);
var
  i, col,ptr: Integer;
  tmpbuf: ByteBufferPtr;
begin
  { create a scratchpad copy to work with }
  GetMem(tmpbuf, info^.TotalWords);
  for i := 0 to info^.TotalDataWords - 1 do
    tmpbuf^[i] := buf^[i];

  for i := 0 to info^.TotalBlocks - 1 do
    CalculateECBlock(tmpbuf, info^.BlockOffset(i), info^.BlockLen(i),
      info^.ECBlockOffset(i), info^.ECWordsPerBlock);

  { interleave data }
  ptr := 0;
  col := 0;
  while ptr < info^.TotalDataWords do
  begin
    for i := 0 to info^.TotalBlocks - 1 do
    begin
      if col < info^.BlockLen(i) then
      begin
        buf^[ptr] := tmpbuf^[info^.BlockOffset(i) + col];
        ptr := ptr + 1;
      end;
    end;
    col := col + 1;
  end;

  { interleave EC }
  ptr := info^.TotalDataWords;
  col := 0;
  while ptr < info^.TotalWords do
  begin
    for i := 0 to info^.TotalBlocks - 1 do
    begin
      buf^[ptr] := tmpbuf^[info^.ECBlockOffset(i) + col];
      ptr := ptr + 1;
    end;
    col := col + 1;
  end;

  FreeMem(tmpbuf, info^.TotalWords);
end;

function FindECInfo(version, level, length: Integer): ECInfoPtr;
var
  i: Integer;
  minTotal: Integer;
  info: ECInfoPtr;
  match: Boolean;
begin
  info := Nil;
  minTotal := $7000; { some ridiculously high value }
  for i := 1 to ECInfoTotal do
  begin
    match := (version = QRVersionAny) or (ECInfoTable[i].version = version);
    match := match and ((level = ECLevelAny) or (ECInfoTable[i].level = level));

    if match and (ECInfoTable[i].TotalDataWords >= length) and
      (ECInfoTable[i].TotalDataWords < minTotal) then
    begin
      minTotal := ECInfoTable[i].TotalDataWords;
      info := @ECInfoTable[i];
    end;
  end;
  FindECInfo := info;
end;

begin
  InitExpLog;
end.