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

unit QR;

interface
uses Bitstr, EC;

const
  { Up to V8 }
  MaxQRSize = 17 + 4 * 8;
  MaxMask = 7;
  MaskPatternAny = -1;
  { encoding modes }
  NumericMode = 1;
  AlphanumericMode = 2;
  ByteMode = 4;
  KanjiMode = 8;

type
  Module = ( None, Light, Dark );

  QRCode = object
    QRSize: Integer;
    QRVersion: Integer;
    QRLevel: Integer;
    QRMaskPattern: Integer;
    QRMode: Integer;
    Matrix: Array[0..MaxQRSize-1, 0..MaxQRSize-1] of Module;
    PreferredVersion: Integer;
    PreferredLevel: Integer;
    PreferredMaskPattern: Integer;
    Codewords: Bitstream;
    constructor Init;
    function Make(data: ByteBufferPtr; dataLen : Integer) : Integer;
    procedure ClearMatrix;
    procedure SetPreferredLevel(level: Integer);
    procedure SetPreferredVersion(version: Integer);
    procedure SetPreferredMaskPattern(pattern: Integer);
    procedure PutModule(row, col: Integer; val: Module);
    function GetModule(row, col: Integer): Module;
    function CalculatePenalty: Word;
    procedure PlaceEverything(data: ByteBufferPtr; dataLen, mask: Integer);
    procedure PlaceTiming;
    procedure PlaceDarkModule(version: Integer);
    procedure PlacePositionElement(row, col: Integer);
    procedure PlaceAlignmentElement(centerX, centerY: Integer);
    procedure PlaceFormatString(format: Word);
    procedure PlaceVersionInfoString(info: LongInt);
    procedure PlaceModules(buf: ByteBufferPtr; dataLen: Integer; mask: Byte);
    function MaskModule(row, col: Integer; mask: Byte; val: Module): Module;

    procedure EncodeAlphanumericMode(data: ByteBufferPtr; len: Integer; version: Integer);
    procedure EncodeNumericMode(data: ByteBufferPtr; len: Integer; version: Integer);
    procedure EncodeByteMode(data: ByteBufferPtr; len: Integer; version: Integer);

    procedure Save(var f: Text);
  end;
  QRCodePtr = ^QRCode;

implementation

const
  AlignmentPosTable : Array[1..8] of Set of Byte =
  (
    [],          {  1 }
    [6, 18],
    [6, 22],
    [6, 26],
    [6, 30],
    [6, 34],
    [6, 22, 38],
    [6, 24, 42]
  );

var
  qrData: Array[0..MaxECWords] of Byte;

function AlphanumericCode(b: Byte): Byte;
begin
  case Chr(b) of
    '0'..'9': AlphanumericCode := b - Ord('0');
    'A'..'Z': AlphanumericCode := b - Ord('A') + 10;
    ' ': AlphanumericCode := 36;
    '$': AlphanumericCode := 37;
    '%': AlphanumericCode := 38;
    '*': AlphanumericCode := 39;
    '+': AlphanumericCode := 40;
    '-': AlphanumericCode := 41;
    '.': AlphanumericCode := 42;
    '/': AlphanumericCode := 43;
    ':': AlphanumericCode := 44;
    else AlphanumericCode := 255;
  end;
end;

function IsNumeric(data: ByteBufferPtr;
  len: Integer; var words: Integer): Boolean;
var
  i: Integer;
  bits: Integer;
begin
  bits := 4 + 14; { mode + len(worst case) }
  i := 0;
  for i := 0 to len - 1 do
  begin
    if (data^[i] < $30) or (data^[i] > $39) then
    begin
      IsNumeric := False;
      Exit;
    end;
  end;

  bits := bits + 10 * (len div 3);
  case (len mod 3) of
    1: bits := bits + 4;
    2: bits := bits + 7;
  end;

  words := bits div 8;
  if (bits mod 8) <> 0 then
    words := words + 1;
  IsNumeric := True;
end;

function IsAlphanumeric(data: ByteBufferPtr;
  len: Integer; var words: Integer): Boolean;
var
  i: Integer;
  bits: Integer;
begin
  bits := 4 + 13; { mode + len(worst case) }
  i := 0;
  for i := 0 to len - 1 do
  begin
    if AlphanumericCode(data^[i]) = 255 then
    begin
      IsAlphanumeric := False;
      Exit;
    end;
  end;

  bits := bits + 11 * (len div 2);
  if (len mod 2) <> 0 then
    bits := bits + 6;
  words := bits div 8;
  if (bits mod 8) <> 0 then
    words := words + 1;
  IsAlphanumeric := True;
end;

function IsByte(data: ByteBufferPtr;
  len: Integer; var words: Integer): Boolean;
var
  i: Integer;
  bits: Integer;

begin
  bits := 4 + 16; { mode + len (worst case) }
  bits := bits + 8 * len;
  words := bits div 8;
  if (bits mod 8) <> 0 then
    words := words + 1;
  IsByte := True;
end;

function BitstringLen(w: LongInt): Byte;
var
  i: ShortInt;
begin
  i := 31;
  while (i >= 0) and ((w shr i) and 1 = 0) do
    i := i - 1;
  BitstringLen := i + 1;
end;


function MakeFormatString(level: Byte; mask: Byte): Word;
const
  { Generatorial polynomial }
  GP = $537;
var
  ecc: Word;
  formatString: Word;
  bitLen: Byte;
begin
  ecc := (level shl 3) or mask;
  { append  order of generational polynomial zeroes to the right }
  ecc := ecc shl 10;
  bitLen := BitstringLen(ecc);

  while bitLen > 10 do
  begin
    ecc := ecc xor (GP shl (bitLen - 11));
    ecc := ecc and ((1 shl (bitLen + 1)) - 1);
    bitLen := BitstringLen(ecc);
  end;
  ecc := ecc or (level shl 13) or (mask shl 10);
  ecc := (ecc xor $5412) and $7FFF;
  MakeFormatString := ecc;
end;

procedure WriteHex(x: LongInt);
const
 hexs : String = '0123456789ABCDEF';
var
 i: Integer;
 pos: Integer;
begin
 for i := 7 downto 0 do
 begin
   pos := ((x shr (i*4)) and $F);
   Write(hexs[pos + 1]);
 end;
end;

function MakeVersionInfoString(version: Byte): LongInt;
const
  { Generatorial polynomial }
  GP : LongInt = $1F25;
var
  ecc: LongInt;
  bitLen: Byte;
begin
  ecc := version;
  { append  order of generational polynomial zeroes to the right }
  ecc := ecc shl 12;
  bitLen := BitstringLen(ecc);

  while bitLen > 12 do
  begin
    ecc := ecc xor (GP shl (bitLen - 13));
    bitLen := BitstringLen(ecc);
  end;
  MakeVersionInfoString := ecc or (LongInt(version) shl 12);
end;

constructor QRCode.Init;
begin
  Codewords.Init;
  QRVersion := QRVersionAny;
  QRLevel := ECLevelAny;
  QRMaskPattern := MaskPatternAny;
  PreferredVersion := QRVersionAny;
  PreferredLevel := ECLevelAny;
  PreferredMaskPattern := MaskPatternAny;
  ClearMatrix;
end;

procedure QRCode.ClearMatrix;
var
  i, j: Word;
begin
  for i := 0 to MaxQRSize-1 do
    for j := 0 to MaxQRSize-1 do
      Matrix[i, j] := None;
end;

procedure QRCode.SetPreferredLevel(level: Integer);
begin
  PreferredLevel := level;
end;

procedure QRCode.SetPreferredVersion(version: Integer);
begin
  PreferredVersion := version;
end;

procedure QRCode.SetPreferredMaskPattern(pattern: Integer);
begin
  PreferredMaskPattern := pattern;
end;

function QRCode.Make(data: ByteBufferPtr; dataLen: Integer) : Integer;
var
  encodedCodewords: Integer;
  info: ECInfoPtr;
  terminatorLen, paddingLen: Integer;
  currentMask: Byte;
  penalty, minPenalty: Word;
  i: Word;
  row, col: Integer;
  mode: Integer;
begin
  mode := 0;
  if IsNumeric(data, dataLen, encodedCodewords) then
    mode := NumericMode
  else if IsAlphanumeric(data, dataLen, encodedCodewords) then
    mode := AlphaNumericMode
  else if IsByte(data, dataLen, encodedCodewords) then
    mode := ByteMode;


  info := FindECInfo(PreferredVersion, PreferredLevel, encodedCodewords);
  if info = Nil then
  begin
    Make := -1;
    Exit;
  end;
  QRMode := mode;
  case mode of
    NumericMode: EncodeNumericMode(data, dataLen, info^.Version);
    AlphaNumericMode: EncodeAlphaNumericMode(data, dataLen, info^.Version);
    ByteMode: EncodeByteMode(data, dataLen, info^.Version);
  end;

  QRSize := info^.Version*4 + 17;
  QRVersion := info^.Version;
  QRLevel := info^.Level;

  terminatorLen := info^.TotalDataWords * 8 - codewords.BitLength;
  if terminatorLen > 4 then
    terminatorLen := 4;
  codeWords.AddBits(0, terminatorLen);
  codeWords.PadToByte;

  for i := 0 to codewords.ByteLength - 1 do
    qrData[i] := codewords.GetByte(i);

  paddingLen := info^.TotalDataWords - codeWords.ByteLength;

  i := 0;
  while i < paddingLen do
  begin
    if i mod 2 = 0 then
      qrData[codeWords.ByteLength + i] := $EC
    else
      qrData[codeWords.ByteLength + i] := $11;
    i := i + 1;
  end;
  CalculateEc(@qrData, info);
  minPenalty := $FFFF;
  if PreferredMaskPattern = MaskPatternAny then
    for currentMask := 0 to MaxMask do
    begin
      ClearMatrix;
      PlaceEverything(@qrData, info^.TotalWords, currentMask);
      penalty := CalculatePenalty;
      { Writeln('Mask #', currentMask, ', penalty=', penalty); }
      if penalty < minPenalty then
      begin
        QRMaskPattern := currentMask;
        minPenalty := penalty;
      end;
    end
  else
    QRMaskPattern := PreferredMaskPattern;

  ClearMatrix;
  PlaceEverything(@qrData, info^.TotalWords, QRMaskPattern);
  Make := 0;
end;

function QRCode.CalculatePenalty : Word;
var
  penalty: Word;
  streakLen, patternLen: Integer;
  streak: Module;
  i, j: Integer;
  pattern: Word;
  low, high, darkModules: Integer;
begin
  penalty := 0;

  { Horizontal condition #1 }
  for i := 0 to QRSize - 1 do
  begin
    streak := None;
    streakLen := 0;
    for j := 0 to QRSize - 1 do
    begin
      if Matrix[i, j] = streak then
        streakLen := streakLen + 1
      else
      begin
        if streakLen >= 5 then
          penalty := penalty + 3  + (streakLen - 5);
        streak := Matrix[i, j];
        streakLen := 1;
      end;
    end;
    if streakLen >= 5 then
      penalty := penalty + 3 + (streakLen - 5);
  end;

  { Vertical condition #1 }
  for i := 0 to QRSize - 1 do
  begin
    streak := None;
    streakLen := 0;
    for j := 0 to QRSize - 1 do
    begin
      if Matrix[j, i] = streak then
        streakLen := streakLen + 1
      else
      begin
        if streakLen >= 5 then
          penalty := penalty + 3 + (streakLen - 5);
        streak := Matrix[j, i];
        streakLen := 1;
      end;
    end;
    if streakLen >= 5 then
      penalty := penalty + 3 + (streakLen - 5);
  end;

  { Condition #2 }
  for i := 0 to QRSize - 1 - 1 do
    for j := 0 to QRSize - 1 - 1 do
    begin
        if (Matrix[i, j] = Matrix[i, j + 1])
          and (Matrix[i, j] = Matrix[i + 1, j + 1])
          and (Matrix[i, j] = Matrix[i + 1, j]) then
            penalty := penalty + 3
    end;

  { Horizontal codition #3 }
  for i := 0 to QRSize - 1 do
  begin
    pattern := 0;
    streakLen := 0;
    for j := 0 to QRSize - 1 do
    begin
      if Matrix[i, j] = Light then
        pattern := pattern shl 1
      else
        pattern := (pattern shl 1) or 1;
      pattern := pattern and $7FF;
      if patternLen < 11 then
        patternLen := patternLen + 1
      else
        if (pattern = $5D) or (pattern = $5D0) then
          penalty := penalty + 40;
    end
  end;

  { Vertical codition #3 }
  for i := 0 to QRSize - 1 do
  begin
    pattern := 0;
    streakLen := 0;
    for j := 0 to QRSize - 1 do
    begin
      if Matrix[j, i] = Light then
        pattern := pattern shl 1
      else
        pattern := (pattern shl 1) or 1;
      pattern := pattern and $7FF;
      if patternLen < 11 then
        patternLen := patternLen + 1
      else
        if (pattern = $5D) or (pattern = $5D0) then
          penalty := penalty + 40;
    end
  end;

  { Condition #4 }
  darkModules := 0;
  for i := 0 to QRSize - 1 do
    for j := 0 to QRSize - 1 do
      if Matrix[i, j] = Dark then
        darkModules := darkModules + 1;

  low := (darkModules * 100) div (QRSize*QRSize);
  low := low - (low mod 5);
  high := low + 5;
  low := abs(low - 50) div 5;
  high := abs(high - 50) div 5;
  if low < high then
    penalty := penalty + low * 10
  else
    penalty := penalty + high * 10;

  CalculatePenalty := penalty;
end;

procedure QRCode.PlaceEverything(data: ByteBufferPtr; dataLen, mask: Integer);
var
  row, col: Word;
begin
  PlacePositionElement(0, 0);
  PlacePositionElement(QRSize - 7, 0);
  PlacePositionElement(0, QRSize - 7);

  for row := 0 to QRSize - 1 do
  begin
    if row in AlignmentPosTable[QRVersion] then
    begin
        for col := 0 to QRSize do
          if col in AlignmentPosTable[QRVersion] then
            PlaceAlignmentElement(row, col);
    end;
  end;

  PlaceTiming;
  PlaceDarkModule(QRVersion);
  PlaceFormatString(MakeFormatString(QRLevel, mask));
  if QRVersion >= 7 then
    PlaceVersionInfoString(MakeVersionInfoString(QRVersion));
  PlaceModules(data, dataLen, mask);

end;

procedure QRCode.EncodeNumericMode(data: ByteBufferPtr; len: Integer; version: Integer);
var
  i: Integer;
  val: Integer;
begin
  Codewords.AddBits(NumericMode, 4);
  if (version < 10) then
    CodeWords.AddBits(len, 10)
  else if (version < 27) then
    CodeWords.AddBits(len, 12)
  else
    CodeWords.AddBits(len, 14);

  val := 0;
  for i := 0 to len - 1 do
  begin
    val := val * 10 + (ord(data^[i]) - $30);
    if i mod 3 = 2 then
    begin
      Codewords.AddBits(val, 10);
      val := 0;
    end;
  end;
  case len mod 3 of
    1: Codewords.AddBits(val, 4);
    2: CodeWords.AddBits(val, 7);
  end;
end;

procedure QRCode.EncodeAlphanumericMode(data: ByteBufferPtr; len: Integer; version: Integer);
var
  i: Integer;
  val: Integer;
begin
  Codewords.AddBits(AlphanumericMode, 4);

  if (version < 10) then
    CodeWords.AddBits(len, 9)
  else if (version < 27) then
    CodeWords.AddBits(len, 11)
  else
    CodeWords.AddBits(len, 13);

  i := 0;
  while i < len - 1 do
  begin
    val := AlphanumericCode(data^[i]) * 45 + AlphanumericCode(data^[i+1]);
    Codewords.AddBits(val, 11);
    i := i + 2;
  end;

  if i = len - 1 then
  begin
    val := AlphanumericCode(data^[i]);
    Codewords.AddBits(val, 6);
  end;
end;


procedure QRCode.EncodeByteMode(data: ByteBufferPtr; len: Integer; version: Integer);
var
  i: Integer;
begin
  Codewords.AddBits(ByteMode, 4);

  if (version < 10) then
    CodeWords.AddBits(len, 8)
  else
    CodeWords.AddBits(len, 16);

  for i := 0 to len - 1 do
    Codewords.AddBits(data^[i], 8);
end;

procedure QRCode.PutModule(row, col: Integer; val: Module);
begin
  if (row < 0) or (row >= QRSize) then exit;
  if (col < 0) or (col >= QRSize) then exit;
  Matrix[row, col] := val;
end;

function QRCode.GetModule(row, col: Integer): Module;
var
  val: Module;
begin
  val := Light;
  if (row >= 0) and (row < QRSize) and (col >= 0) and (col < QRSize) then
    val := Matrix[row, col];
  GetModule := val;
end;

procedure QRCode.PlaceTiming;
var
  i: Integer;
begin
    for i:= 8 to QRSize - 7 do
    begin
      if i mod 2 = 0 then
      begin
        PutModule(6, i, Dark);
        PutModule(i, 6, Dark);
      end
      else
      begin
        PutModule(6, i, Light);
        PutModule(i, 6, Light);
      end;
    end;
end;

procedure QRCode.PlaceDarkModule(version: Integer);
begin
   PutModule(4 * version + 9, 8, Dark);
end;

procedure QRCode.PlacePositionElement(row, col: Integer);
var
  i, j: Integer;
begin
  { external dark square }
  for i := 0 to 6 do
  begin
    PutModule(row + 0, col + i, Dark);
    PutModule(row + 6, col + i, Dark);
    PutModule(row + i, col + 0, Dark);
    PutModule(row + i, col + 6, Dark);
  end;

  { internal light square }
  for i := 1 to 5 do
  begin
    PutModule(row + 1, col + i, Light);
    PutModule(row + 5, col + i, Light);
    PutModule(row + i, col + 1, Light);
    PutModule(row + i, col + 5, Light);
  end;

  { internal dark square }
  for i := 2 to 4 do
    for j := 2 to 4 do
      PutModule(row + i, col + j, Dark);

  { separators, out-of-area coordinates are handled by PutModule }
  for i := -1 to 7 do
  begin
    PutModule(row - 1, col + i, Light);
    PutModule(row + 7, col + i, Light);
    PutModule(row + i, col - 1, Light);
    PutModule(row + i, col + 7, Light);
  end;
end;

procedure QRCode.PlaceAlignmentElement(centerX, centerY: Integer);
var
  i: Integer;
begin
  { overlaps with the top-left finder ? }
  if (centerX - 2 <= 7) and (centerY - 2 <= 7) then
    Exit;
  { overlaps with the top-right finder ? }
  if (centerX + 2 >= QRSize - 1 - 7) and (centerY - 2 <= 7) then
    Exit;
  { overlaps with the bottom-left finder ? }
  if (centerX - 2 <= 7) and (centerY + 2 >= QRSize - 1 - 7) then
    Exit;

  PutModule(centerX, centerY, Dark);
  for i := -1 to 1 do
  begin
    PutModule(centerX - 1, centerY + i, Light);
    PutModule(centerX + 1, centerY + i, Light);
    PutModule(centerX + i, centerY + 1, Light);
    PutModule(centerX + i, centerY - 1, Light);
  end;
  for i := -2 to 2 do
  begin
    PutModule(centerX - 2, centerY + i, Dark);
    PutModule(centerX + 2, centerY + i, Dark);
    PutModule(centerX + i, centerY + 2, Dark);
    PutModule(centerX + i, centerY - 2, Dark);
  end;
end;

procedure QRCode.PlaceFormatString(format: Word);
var
  i: Integer;
  v: Module;
begin
  { vertical }
  for i := 0 to 14 do
  begin
    if ((format shr (14 - i)) and 1) = 1 then
      v := Dark
    else
      v := Light;
    if i < 7 then
      PutModule(QRSize - 1 - i, 8, v)
    else if i < 9 then
      PutModule(15 - i, 8, v)
    else
      PutModule(14 - i, 8, v);
  end;

  { horizontal }
  for i := 0 to 14 do
  begin
    if (format shr (14 - i) and 1) = 0 then
      v := Light
    else
      v := Dark;
    if i < 6 then
      PutModule(8, i,  v)
    else if i < 7 then
      PutModule(8, i + 1, v)
    else
      PutModule(8, QRSize - 15 + i, v);
  end;
end;

procedure QRCode.PlaceVersionInfoString(info: LongInt);
var
  i: Integer;
  v: Module;
begin
  for i := 0 to 17 do
  begin
    if ((info shr i) and 1) = 0 then
      v :=  Light
    else
      v := Dark;
    { horizontal }
    PutModule(QRSize - 11 + (i mod 3), i div 3, v);
    { vertical }
    PutModule(i div 3, QRSize - 11 + (i mod 3), v);
  end;
end;

procedure QRCode.PlaceModules(buf: ByteBufferPtr; dataLen: Integer; mask: Byte);
var
  col, row: Integer;
  useLeft, goUp, done: Boolean;
  bitPtr, idx, bit: Integer;
  val: Module;
begin
  col := QRSize - 1;
  row := QRSize - 1;
  useLeft := False;
  goUp := True;
  done := False;
  bitPtr := 0;

  repeat
    if Matrix[row, col] = None then
    begin
      idx := bitPtr div 8 + 1;
      if (idx >= dataLen) or ((buf^[idx-1] and (1 shl (7 - (bitPtr mod 8)))) = 0) then
        val := Light
      else
        val := Dark;

      val := MaskModule(row, col, mask, val);
      PutModule(row, col, val);

      bitPtr := bitPtr + 1;
    end;

    if useLeft then
    begin
      useLeft := False;
      col := col + 1;
      if goUp then
        row := row - 1
      else
        row := row + 1;
    end
    else
    begin
      useLeft := True;
      col := col - 1;
    end;

    { Are we at the top of the map? }
    if row = -1 then
    begin
      goUp := False;
      col := col - 2;
      row := 0;
    end;

    { Are we at the bottom of the map? }
    if row = QRSize then
    begin
      goUp := True;
      col := col - 2;
      row := QRSize - 1;
    end;

    { Skip vertical timing column }
    if col = 6 then
      col := col - 1;

  until col = -1;
end;

function QRCode.MaskModule(row, col: Integer; mask: Byte; val: Module): Module;
var
  invert: Boolean;
begin
  invert := False;
  case mask of
    0: invert := ((row + col) mod 2) = 0;
    1: invert := (row mod 2) = 0;
    2: invert := (col mod 3) = 0;
    3: invert := (row + col) mod 3 = 0;
    4: invert := (((row div 2) + (col div 3)) mod 2) = 0;
    5: invert := ((row * col) mod 2) + ((row * col) mod 3) = 0;
    6: invert := (((row * col) mod 2) + ((row * col) mod 3)) mod 2 = 0;
    7: invert := (((row + col) mod 2) + ((row * col) mod 3)) mod 2 = 0;
  end;
  if invert then
  begin
    if val = Light then
      MaskModule := Dark
    else
      MaskModule := Light;
  end
  else
    MaskModule := val;
end;

procedure QRCode.Save(var f: Text);
var
  row, col, ch: Byte;
  val: Module;
begin
  row := 0;
  while row < QRSize do
  begin
    Write(f, '  ');
    for col := 0 to QRSize - 1 do
    begin
      ch := 0;
      val := Matrix[row, col];
      if val = Light then
        ch := 2;
      if row < QRSize - 1 then
      begin
        if Matrix[row + 1, col] = Light then
          ch := ch or 1;
      end
      else
        ch := ch or 1;
      case ch of
        3: Write(f, ' ');
        2: Write(f, chr(220));
        1: Write(f, chr(223));
        0: Write(f, chr(219));
      end;
    end;
    WriteLn(f);
    row := row + 2;
  end;
end;


begin
end.
