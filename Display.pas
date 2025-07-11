unit Display;

interface

Uses Windows, Controls, ExtCtrls, Forms, Classes, Graphics, SyncObjs, dglOpenGL;

Type

  TRenderThread = Class(TThread)
    Dead: Boolean;
    LastFrame: Integer;
    Procedure Execute; override;
  End;

Procedure InitGL(Handle: hWnd);
Procedure InitDisplay(FPS, DisplayWidth, DisplayHeight: Integer; Aspect: Boolean; Var Control: TPanel);
Function  GetTicks: Double;
Procedure ScaleBuffers(pSrc, pDst: pLongWord; SrcW, SclFact, x1, x2, y1, y2: Integer);
Procedure SetScaling(sWidth, sHeight: Integer);
Procedure FrameLoop;
Procedure SwitchFullScreen;
Procedure Refresh_Display;
Procedure ResizeDisplay;
Procedure WaitForSync;
Procedure CloseGL;

Var

  RC: HGlRC;
  DC: HDC;
  GlHandle: hWnd;
  DisplayUpdate, DoScale, FullScreen, MaintainAspect, DisplayReady: Boolean;
  intWidth, intHeight, scaleWidth, scaleHeight, winWidth, winHeight, ScaleFactor, FrameCount, LastFrames,
  DisplayWidth, DisplayHeight, lastWinX, lastWinY, lastWinWidth, lastWinHeight, MarginSize: Integer;
  StartTime, LastFrameCount, FrameTime, LastTicks, LastFrameDuration, LastFrameTime, LastFrameStart: Double;
  DisplayArray, ScaledArray: Array of LongWord;
  BaseTime, TimerFreq: Int64;
  GLX, GLY, GLW, GLH: Integer;
  bStyle: TFormBorderStyle;
  BackRed, BackGreen, BackBlue: Single;
  GLPanel: ^TPanel;
  DisplayLock: TCriticalSection;
  RenderThread: TRenderThread;

implementation

Uses MainForm, Math;

Function GetScreenRefreshRate: Integer;
var
  DeviceMode: TDeviceMode;
const
  ENUM_CURRENT_SETTINGS = DWORD(-1);
Begin
  EnumDisplaySettings(nil, ENUM_CURRENT_SETTINGS, DeviceMode);
  Result := DeviceMode.dmDisplayFrequency;
End;

Procedure TRenderThread.Execute;
Var
  LaunchTime, CurTime, VideoFPS: Double;
  CurFrame: Integer;
Begin

  Dead := False;
  VideoFPS := 1000 / GetScreenRefreshRate;
  LaunchTime := GetTicks;
  FreeOnTerminate := True;
  NameThreadForDebugging('Render Thread');

  While Not Terminated Do Begin

    CurTime := GetTicks;
    CurFrame := Trunc((CurTime - LaunchTime) / VideoFPS);

    If CurFrame <> LastFrame Then Begin
      PostMessage(Main.Handle, WM_Render, 0, 0);
      LastFrame := CurFrame;
    End;

    Sleep(1);

  End;

  Dead := True;

End;

Procedure InitTimer;
Begin

  QueryPerformanceFrequency(TimerFreq);
  QueryPerformanceCounter(BaseTime);
  TimerFreq := Round(TimerFreq / 1000);

  If Not Assigned(RenderThread) then
    RenderThread := TRenderThread.Create(False);

End;

Function GetTicks: Double;
Var
  t: Int64;
Begin

  QueryPerformanceCounter(t);
  Result := (t - BaseTime) / TimerFreq;

End;

Procedure InitGL(Handle: hWnd);
Var
  Pixelformat: GLuint;
  pfd: pixelformatdescriptor;
begin

  DisplayWidth := Screen.Width;
  DisplayHeight := Screen.Height;
  bStyle := Main.BorderStyle;

  If RC <> 0 Then Begin
    wglDeleteContext(RC);
    ReleaseDC(GLHandle, DC);
  End Else
    InitOpenGL;

  GLHandle := Handle;

  with pfd do begin
    nSize:= SizeOf( PIXELFORMATDESCRIPTOR );
    nVersion:= 1;
    dwFlags:= PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL;
    iPixelType:= PFD_TYPE_RGBA;
    cColorBits:= 32;
    cRedBits:= 0;
    cRedShift:= 0;
    cGreenBits:= 0;
    cBlueBits:= 0;
    cBlueShift:= 0;
    cAlphaBits:= 0;
    cAlphaShift:= 0;
    cAccumBits:= 0;
    cAccumRedBits:= 0;
    cAccumGreenBits:= 0;
    cAccumBlueBits:= 0;
    cAccumAlphaBits:= 0;
    cDepthBits:= 0;
    cStencilBits:= 0;
    cAuxBuffers:= 0;
    iLayerType:= PFD_MAIN_PLANE;
    bReserved:= 0;
    dwLayerMask:= 0;
    dwVisibleMask:= 0;
    dwDamageMask:= 0;
  end;

  marginSize := 4;

  DC := GetDC(GLHandle);
  PixelFormat := ChoosePixelFormat(DC, @pfd);
  SetPixelFormat(DC,PixelFormat,@pfd);
  RC := wglCreateContext(DC);
  ActivateRenderingContext(DC, RC);
  wglMakeCurrent(DC, RC);

End;

Procedure ResizeGL;
var
  ratio: Double;
  newWidth, newHeight: Integer;
Begin

  if MaintainAspect Then Begin

    ratio := Min(winWidth / intWidth, winHeight / intheight);
    newWidth := Round(ratio * intWidth) - MarginSize * 2;
    newHeight := Round(ratio * intHeight) - MarginSize * 2;
    glViewPort((winWidth - newWidth) Div 2, (winHeight - newHeight) Div 2, newWidth, newHeight);

  End Else
    glViewPort(MarginSize, MarginSize, winWidth - MarginSize, winHeight - MarginSize);

  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  glOrtho(0, winWidth, winHeight, 0, 1, -1);

  glMatrixMode(GL_MODELVIEW);
  glEnable(GL_TEXTURE_2D);

  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, ScaleWidth, ScaleHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, Nil);

  If ((winWidth/intWidth = Floor(winWidth/intWidth)) And (winHeight/intHeight = Floor(winHeight/intHeight))) or (ScaleFactor = 1) Then Begin

    glTexParameterI(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameterI(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

  End Else Begin

    glTexParameterI(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterI(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

  End;

  glEnable(GL_TEXTURE_2D);

End;

Procedure CloseGL;
Begin

  wglMakeCurrent(0, 0);
  wglDeleteContext(RC);
  ReleaseDC(GLHandle, DC);
  DeleteDC(DC);

  If Assigned(RenderThread) Then Begin
    RenderThread.Terminate;
    Repeat
      Sleep(1);
    Until RenderThread.Dead;
  End;

End;

Procedure InitDisplay(FPS, DisplayWidth, DisplayHeight: Integer; Aspect: Boolean; Var Control: TPanel);
Var
  BkColor: LongWord;
Begin

  GLPanel := @Control;
  BkColor := ColorToRGB(GLPanel^.Color);

  BackBlue := ((BkColor And $FF0000) Shr 16) / 256;
  BackGreen := ((BkColor And $FF00) Shr 8) / 256;
  BackRed := (BkColor And $FF) / 256;

  GLX := 0; GLY := 0; GLW := DisplayWidth; GLH := DisplayHeight;
  MaintainAspect := Aspect;

  SetLength(DisplayArray, DisplayWidth * DisplayHeight);
  intWidth := DisplayWidth;
  intHeight := DisplayHeight;
  InitGL(GLPanel^.Handle);
  ResizeDisplay;

  InitTimer;
  StartTime := 0;
  FrameTime := 1000/FPS;
  LastTicks := GetTicks;
  DisplayUpdate := False;

  DisplayReady := True;

End;

Procedure ResizeDisplay;
Begin

  winWidth := GLPanel^.ClientWidth;
  winHeight := GLPanel^.ClientHeight;
  SetScaling(winWidth, winHeight);
  ResizeGL;

End;

Procedure SetScaling(sWidth, sHeight: Integer);
Begin

  ScaleWidth := sWidth;
  ScaleHeight := sHeight;
  If (ScaleWidth/IntWidth = Floor(ScaleWidth/IntWidth)) And (ScaleHeight/IntHeight = Floor(ScaleHeight/IntHeight)) Then Begin
    DoScale := False;
    ScaleFactor := 1;
  End Else Begin
    DoScale := (sWidth/intWidth >= 1.5) or (sHeight/intHeight >= 1.5);
    ScaleFactor := Max(Round(sWidth/intWidth), Round(sHeight/intHeight));
    If ScaleFactor = 0 Then
      ScaleFactor := 1
    Else
      If ScaleFactor > 8 Then Begin
        DoScale := False;
        ScaleFactor := 1;
      End;
  End;

  ScaleWidth := ScaleFactor * intWidth;
  ScaleHeight := ScaleFactor * intHeight;
  SetLength(ScaledArray, ScaleWidth * ScaleHeight);
  SetLength(DisplayArray, intWidth *  intHeight);

End;

Procedure FrameLoop;
Var
  FrameStart, FrameEnd: Double;
Begin


  FrameStart := GetTicks;
  If StartTime = 0 Then
    StartTime := FrameStart;
  FrameCount := Trunc((FrameStart - StartTime) / FrameTime); // Emulated frame

  Refresh_Display;

  FrameEnd := GetTicks;
  LastFrameDuration := FrameEnd - FrameStart;
  LastFrameTime := FrameStart - LastFrameStart;
  LastFrameStart := FrameStart;

  DisplayUpdate := False;

End;

Procedure ScaleBuffers(pSrc, pDst: pLongWord; SrcW, SclFact, x1, x2, y1, y2: Integer);
var
  w,w2,x,y,i: Integer;
  ps,pd,lpd: pLongWord;
begin

  w2 := (x2 - x1) +1;              // Width of area to scale
  w := w2 * 4 * SclFAct;           // Same value scaled. Source is 8bpp, dest is 32bpp
  ps := pSrc;                      // Source - @DisplayArray[0]
  pd := pDst;                      // Dest - @ScaledArray[0]
  Inc(ps, (y1 * srcW) + x1);       // Find source topleft pixel
  Inc(pd, (y1 * SclFAct) + (x1 * SclFAct)); // And dest
  for y := y1 to y2 do begin
    lpd := pd;
    for x := x1 to x2 do begin     // Scale columns
      For i := 1 To SclFAct Do Begin
        pd^ := ps^;
        Inc(pd);
      End;
      Inc(ps);
    end;
    pd := pLongWord(NativeUint(pd) + (srcW * SclFAct * 4) - w); // Find next row
    Inc(ps, srcW - w2);                                         // in both dest and src
    For i := 1 to SclFAct -1 Do Begin                           // Copy rows
      Move(lpd^, pd^, w);
      Inc(pd, srcW * SclFAct);
    End;
  end;
end;

Procedure Refresh_Display;
Var
  x, y, w, h: Integer;
Begin

  glLoadIdentity;

  If DoScale Then Begin
    If (GLH > 0) And (GLW > 0) Then Begin
      ScaleBuffers(@DisplayArray[0], @ScaledArray[0], intWidth, ScaleFactor, GLX, GLX + GLW -1, GLY, GLY + GLH -1);
      x := GLX * ScaleFactor;
      y := GLY * ScaleFactor;
      w := GLW * ScaleFactor;
      h := GLH * ScaleFactor;
      glPixelStorei(GL_UNPACK_ROW_LENGTH, ScaleWidth);
      glTexSubImage2D(GL_TEXTURE_2D, 0, X, Y, W, H, GL_BGRA, GL_UNSIGNED_BYTE, @ScaledArray[X + ScaleWidth * Y]);
    End;
  End Else Begin
    if (GLH > 0) And (GLW > 0) Then Begin
      glPixelStorei(GL_UNPACK_ROW_LENGTH, IntWidth);
      glTexSubImage2D(GL_TEXTURE_2D, 0, GLX, GLY, GLW, GLH, GL_BGRA, GL_UNSIGNED_BYTE, @DisplayArray[GLX + IntWidth * GLY]);
    End;
  End;

  glClearColor(backRed, backGreen, backBlue, 0);
  glClear(GL_COLOR_BUFFER_BIT);

  glBegin(GL_QUADS);
  glTexCoord2D(0, 0); glVertex2D(0, 0);
  glTexCoord2D(1, 0); glVertex2D(winWidth, 0);
  glTexCoord2D(1, 1); glVertex2D(winWidth, winHeight);
  glTexCoord2D(0, 1); glVertex2D(0, winHeight);
  glEnd;

  glFlush;

End;

Procedure SwitchFullScreen;
{$J+}
const
  rect: TRect = (Left:0; Top:0; Right:0; Bottom:0);
  ws : TWindowState = wsNormal;
{$J-}
var
  r : TRect;
begin

  With Main Do Begin
    if BorderStyle <> bsNone then
    begin
      ws := WindowState;
      rect := BoundsRect;
      BorderStyle := bsNone;
      r := Screen.MonitorFromWindow(Handle).BoundsRect;
      SetBounds(r.Left, r.Top, r.Right-r.Left, r.Bottom-r.Top);
    end
    else
    begin
      BorderStyle := bsSizeable;
      if ws = wsMaximized then
        WindowState := wsMaximized
      else
        SetBounds(rect.Left, rect.Top, rect.Right-rect.Left, rect.Bottom-rect.Top);
    end;
  End;
  FullScreen := Not FullScreen;

End;

Procedure WaitForSync;
Begin

  DisplayUpdate := True;
  Repeat
    Sleep(1);
  Until Not DisplayUpdate;

End;

Initialization

  DisplayLock := TCriticalSection.Create;

Finalization

  DisplayLock.Free;

end.
