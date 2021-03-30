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

uses Crt, Bitstr, QR, EC, Render;

procedure Usage;
begin
  WriteLn('SYNTAX: QRSAY [options] /F file | MESSAGE');
  WriteLn('OPTIONS:');
  WriteLn('  /I        Invert image, use light on dark theme');
  WriteLn('  /L x      Request specific EC level, values: L, M, Q, H');
  WriteLn('  /M x      Request specific mask pattern, values: 0-7');
  WriteLn('  /N        Do not render QR code, only print its info');
  WriteLn('  /O file   Save QR code as text to the specified file');
  WriteLn('  /V xxx    Request specific version, values: 1-20');
  Halt(1);
end;

var
  data: ByteBufferPtr;
  dataFile: file;
  i, j, dataLen: Integer;
  err: Integer;
  pQR: QRCodePtr;
  pRenderer: RendererPtr;
  Factory: RendererFactory;
  qrError: Integer;
  fileName, saveFileName, msg, s, tmpStr: String;
  preferredVersion, preferredLevel, preferredMaskPattern : Integer;
  invert, printInfo: Boolean;
  ioErr: Integer;
  out: Text;
begin

  fileName := '';
  saveFileName := '';
  msg := '';
  preferredVersion := QRVersionAny;
  preferredLevel := ECLevelAny;
  preferredMaskPattern := MaskPatternAny;
  invert := False;
  printInfo := False;
  i := 1;
  while i <= ParamCount do
  begin
    s := ParamStr(i);
    i := i + 1;
    if (Length(s) > 0) and (s[1] = '/') then
    begin
      if Length(s) > 2 then
        Usage;
      case UpCase(s[2]) of
        'I': invert := True;
        { input filename }
        'F': begin
               fileName := ParamStr(i);
               i := i + 1;
             end;
        { preferred EC level }
        'L': begin
               tmpStr := ParamStr(i);
               i := i + 1;
               if tmpStr = 'L' then
                 preferredLevel := ECLevelL
               else if tmpStr = 'M' then
                 preferredLevel := ECLevelM
               else if tmpStr = 'Q' then
                 preferredLevel := ECLevelQ
               else if tmpStr = 'H' then
                 preferredLevel := ECLevelH
               else
               begin
                 WriteLn('Invalid level value: ', tmpStr);
                 Usage;
               end;
             end;
        'M': begin
               tmpStr := ParamStr(i);
               i := i + 1;
               Val(tmpStr, preferredMaskPattern, err);
               if (err <> 0) or (preferredMaskPattern < 0) or
                   (preferredMaskPattern > 7) then
               begin
                 WriteLn('Invalid mask pattern: ', tmpStr);
                 Usage;
               end;
             end;
        'N': printInfo := True;
        { output filename }
        'O': begin
               saveFileName := ParamStr(i);
               i := i + 1;
             end;
        { Preferred version }
        'V': begin
               tmpStr := ParamStr(i);
               i := i + 1;
               Val(tmpStr, preferredVersion, err);
               if (err <> 0) or (preferredVersion < 1) or
                   (preferredVersion > 20) then
               begin
                 WriteLn('Invalid version value: ', tmpStr);
                 Usage;
               end;
             end;
        { optional /T for text starting with "/" }
        'T': begin
               msg := ParamStr(i);
               i := i + 1;
             end;
        else
        begin
          WriteLn('Unknown option: ', s);
          Usage;
        end;
      end;
    end
    else
    begin
      if msg <> '' then
        msg := msg + ' ' + s
      else
        msg := s;
    end;
  end;

  if (fileName <> '') and (msg <> '') then
    Usage;

  if fileName <> '' then
  begin
{$I-}
    Assign(dataFile, fileName);
    Reset(dataFile, 1);
    ioErr := IOResult;
    if ioErr <> 0 then
    begin
      WriteLn('Failed to open file ', fileName, ', error ', ioErr);
      Halt(1);
    end;
    dataLen := FileSize(dataFile);
    if dataLen > MaxBufferSize then
    begin
      WriteLn('File ', fileName, ' is too large');
      Halt(1);
    end;
    if dataLen = 0 then
      dataLen := 1;
    GetMem(data, dataLen);
    BlockRead(dataFile, data^, dataLen);
    Close(dataFile);
{$I+}
  end
  else if msg <> '' then
  begin
    dataLen := Length(msg);
    GetMem(data, dataLen);
    for j := 1 to Length(msg) do
      data^[j - 1] := ord(msg[j]);
  end
  else
    Usage;

  pQR := New(QRCodePtr, Init);

  pQR^.SetPreferredLevel(preferredLevel);
  PQR^.SetPreferredVersion(preferredVersion);
  pQR^.SetPreferredMaskPattern(preferredMaskPattern);
  qrError := pQR^.Make(data, dataLen);

  if qrError <> 0 then
  begin
    WriteLn('Failed to find version/level combination');
    Halt(1);
  end;

  if printInfo then
  begin
    WriteLn('Version       : ', pQR^.QRVersion);
    WriteLn('Size          : ', pQR^.QRSize, 'x', pQR^.QRSize);
    Write  ('EC Level      : ');
    case pQR^.QRLevel of
      ECLevelL: WriteLn('L');
      ECLevelM: WriteLn('M');
      EClevelQ: WriteLn('Q');
      ECLevelH: WriteLn('H');
      else WriteLn('<unknown>');
    end;
    Write  ('Mode          : ');
    case pQR^.QRMode of
      NumericMode: WriteLn('Numeric');
      AlphanumericMode: WriteLn('Alphanumeric');
      ByteMode: WriteLn('Byte');
      KanjiMode: WriteLn('Kanji');
      else WriteLn('<unknown>');
    end;
    WriteLn('Mask pattern  : ', pQR^.QRMaskPattern);
  end
  else if saveFileName <> '' then
  begin
{$I-}
    Assign(out, saveFileName);
    Rewrite(out);
    ioErr := IOResult;
    if ioErr <> 0 then
    begin
      WriteLn('Failed to create file ', saveFileName, ', error ', ioErr);
      Halt(1);
    end;
    pQR^.Save(out);
    Close(out);
{$I+}
  end
  else begin
    pRenderer := Factory.Create;
    pRenderer^.Render(pQR, invert);
    Dispose(pRenderer);
  end;

  Dispose(pQr);
end.
