{$S-,R-,I-,V-,B-}
{$M $800,0,0}

Uses Dos, Crt, QR, Render, Bitstr;

type
  WordBuf = Array[0..15] of Word;
  PointerBuf = Array[0..15] of Pointer;
  WordPtr = ^WordBuf;
  PointerPtr = ^PointerBuf;

const
  BodyIntD6h: Word = $CF90;
  CopyPrefixSeg: Word = 0;
  SavedIntD6h: Pointer = Nil;
  SavedInt09h: Pointer = Nil;
  KeyComboMask: Byte = $0A;
  MaxScreenDataLen: Integer = 256;

var
  SavedSS, SavedSP: Word;
  TSRSS, TSRSP: Word;
  KeyboardFlags: Byte absolute $0:$417;
  Screen: ScreenBuffer Absolute $B800 : $0000;
  IsBusy: Boolean;
  QRGen: QRCode;
  screenData: Array[0..255] of Byte;
  renderer: TextRenderer;

  OriginX, OriginY: Integer;
  PointerX, PointerY: Integer;

  TopLeftX, TopLeftY: Integer;
  BottomRightX, BottomRightY: Integer;

procedure CLI;
  inline($FA);

procedure STI;
  inline($FB);

procedure SaveStack;
  Inline(
    $3E/
    $8C/$16/SavedSS/
    $3E/
    $8C/$26/SavedSP/
    $3E/
    $8E/$16/TSRSS/
    $3E/
    $8E/$26/TSRSP
  );

procedure RestoreStack;
  Inline(
    $3E/
    $8E/$16/SavedSS/
    $3E/
    $8E/$26/SavedSP
  );

function Min(a, b: Integer) : Integer;
begin
  if a < b then
    Min := a
  else
    Min := b;
end;

function Max(a, b: Integer) : Integer;
begin
  if a > b then
    Max := a
  else
    Max := b;
end;

procedure XorScreenPlace(x, y: Integer);
begin
   Screen[y * ScreenWidth + x] := 
        Screen[y * ScreenWidth + x] xor $3300;
end;

procedure TSRMain;
var
  ch: Char;
  scrCh: Byte;
  qrError: Integer;
  dataLen: Integer;
  done: Boolean;
  x, y, tmp, prevX, prevY: Integer;
  dataSelected, selecting: Boolean;

  newTopLeftX, newTopLeftY: Integer;
  newBottomRightX, newBottomRightY: Integer;

begin
  CLI;
  IsBusy := True;
  SaveStack;
  STI;

  done := False;
  selecting := False;
  dataSelected := False;

  XorScreenPlace(PointerX, PointerY);

  while not done do
  begin
    ch := ReadKey;
    if ch = #27 then
      done := True;
    if ch = #0 then
      ch := ReadKey;

    if ch = #13 then
    begin
      if selecting then
      begin
        done := True;
        dataSelected := True;
      end
      else
      begin
        OriginX := PointerX;
        OriginY := PointerY;
        topLeftX := PointerX;
        topLeftY := PointerY;
        bottomRightX := PointerX;
        bottomRightY := PointerY;
        selecting := True;
      end;
    end;

    prevX := PointerX;
    prevY := PointerY;

    if ch = #72 then
      Dec(PointerY);
    if ch = #80 then
      Inc(PointerY);
    if ch = #75 then
      Dec(PointerX);
    if ch = #77 then
      Inc(PointerX);

    { Clamp values to the sceeen size }
    PointerX := Max(PointerX, 0);
    PointerY := Max(PointerY, 0);
    PointerX := Min(PointerX, ScreenWidth - 1);
    PointerY := Min(PointerY, ScreenHeight - 1);

    if not selecting then
    begin
      XorScreenPlace(prevX, prevY);
      XorScreenPlace(PointerX, PointerY);
      OriginX := PointerX;
      OriginY := PointerY;
      topLeftX := PointerX;
      topLeftY := PointerY;
      bottomRightX := PointerX;
      bottomRightY := PointerY;
    end
    else
    begin
      newTopLeftX := Min(PointerX, OriginX);
      newTopLeftY := Min(PointerY, OriginY);
      newBottomRightX := Max(PointerX, OriginX);
      newBottomRightY := Max(PointerY, OriginY);
      { repaint }

      if newTopLeftX < topLeftX then
        for tmp := topLeftY to bottomRightY do
          XorScreenPlace(newTopLeftX, tmp);
      if newTopLeftX > topLeftX then
        for tmp := topLeftY to bottomRightY do
          XorScreenPlace(topLeftX, tmp);

      if newBottomRightX < bottomRightX then
        for tmp := topLeftY to bottomRightY do
          XorScreenPlace(bottomRightX, tmp);
      if newBottomRightX > bottomRightX then
        for tmp := topLeftY to bottomRightY do
          XorScreenPlace(newBottomRightX, tmp);

      if newTopLeftY < topLeftY then
        for tmp := topLeftX to bottomRightX do
          XorScreenPlace(tmp, newTopLeftY);
      if newTopLeftY > topLeftY then
        for tmp := topLeftX to bottomRightX do
          XorScreenPlace(tmp, topLeftY);

      if newBottomRightY < bottomRightY then
        for tmp := topLeftX to bottomRightX do
          XorScreenPlace(tmp, bottomRightY);

      if newBottomRightY > bottomRightY then
        for tmp := topLeftX to bottomRightX do
          XorScreenPlace(tmp, newBottomRightY);

      topLeftX := newTopLeftX;
      topLeftY := newTopLeftY;
      bottomRightX := newBottomRightX;
      bottomRightY := newBottomRightY;
    end;
  end;

  if dataSelected then 
  begin
    { extract data from the screen }
    dataLen := 0;
    for y := topLeftY to bottomRightY do
    begin
      for x := topLeftX to bottomRightX do
      begin
        if dataLen < MaxScreenDataLen then
        begin
          scrCh := Screen[y * ScreenWidth + x] and $FF;
          screenData[dataLen] := scrCh;
          inc(dataLen);
        end;
      end;
      { track back on whitespaces }
      while (dataLen > 0) and (screenData[dataLen-1] = 32) do
        dec(dataLen);
      { replace last space with a newline or append newline }
      if screenData[dataLen-1] = 32 then
      begin
        if y <> bottomRightY then
          screenData[dataLen-1] := 10
        else
          dec(dataLen);
      end
      else
        if dataLen < MaxScreenDataLen then
        begin
          if y <> bottomRightY then
          begin
            screenData[dataLen] := 10;
            inc(dataLen);
          end
        end;
    end;
    QRGen.Init;
    qrError := QRGen.Make(@screenData, dataLen);
    if qrError = 0 then
    begin
      Renderer.Render(@QRGen, True);
    end;
  end;

  for x := topLeftX to bottomRightX do
    for y := topLeftY to bottomRightY do
      XorScreenPlace(x, y);

  CLI;
  RestoreStack;
  IsBusy := False;
  STI;
end;

procedure IntHandler09h(Falgs, CS, IP, AX, BX, CX, DX,
  SI, DI, DS, ES, BP: Word); Interrupt;
begin
  CLI;
  Inline(
    $9C/
    $3E/
    $FF/$1E/SavedInt09h
  );
  STI;
  if ((KeyboardFlags and KeyComboMask = KeyComboMask) and not IsBusy) then
    TSRMain;
end;

procedure Unload;
var
  OldPSP: Word;
  P: Pointer;
  Regs: registers;
  intVec: Pointer;
  words: WordPtr;
  pointers: PointerPtr;
begin
  GetIntVec($D6, intVec);
  words := WordPtr(intVec);
  pointers := PointerPtr(intVec);

  P := pointers^[1];
  SetIntVec($D6, P);
  P := pointers^[2];
  SetIntVec($09, P);

  OldPSP := words^[1];
  Fillchar(regs, SizeOf(regs), 0);
  with regs do
  begin
    AH := $49;
    ES := MemW[OldPSP:$2C];
    MsDos(regs);
    AH := $49;
    ES := OldPSP;
    MsDos(regs);
  end;
end;

function IsLoaded : Boolean;
var
  intVec: Pointer;
begin
  GetIntVec($D6, intVec);
  if ((intVec <> Nil) and (Word(intVec^) = BodyIntD6h)) then
    IsLoaded := True
  else
    IsLoaded := False;
end;

var
  qrError: Integer;
begin
  if IsLoaded then
  begin
    if ParamCount = 1 then
    begin
      if (ParamStr(1) = '/u') or (ParamStr(1) = '/U') then
        Unload;
    end
    else
      WriteLn('QRSDKCK is already loaded, use /U to unload');
    Halt(0);
  end;

  WriteLn('Loading QR Sidekick...');
  WriteLn('Press Alt + Left_Shift to activate selection');

  CopyPrefixSeg := PrefixSeg;
  IsBusy := False;
  TSRSS := Sseg;
  TSRSP := Sptr;
  QRGen.Init;
  Renderer.Init;
  PointerX := 0;
  PointerY := 0;

  GetIntVec($09, SavedInt09h);
  GetIntVec($D6, SavedIntD6h);
  SetIntVec($09, @IntHandler09h);
  SetIntVec($D6, @BodyIntD6h);
  Keep(0);
  WriteLn('Keep(0) failed, error: ', DosExitCode);
end.
