unit TextureMap;

// Based on a series of articles by Chris Hecker, translated from his C Examples to Delphi.
// https://chrishecker.com/images/4/41/Gdmtex1.pdf
// Translated by me to Delphi.

interface

Uses Types;

Type

  TSurface = Record
    Bits: pByte;
    Width, Height: Integer;
    SubRect: TRect;
    UseSubRect: Boolean;
  End;

  P3D = Record
    X, Y, Z, U, V: Double;
  End;

  P2D = Record
    X, Y: Integer;
    Z, U, V: Double;
  End;

  T2DPointArray = Array of P2D;

  TGradients = Record
    aOneOverZ, aUOverZ, aVOverZ: Array[0..2] of Double;
    dOneOverZdX, dOneOverZdY, dUOverZdX, dUOverZdY, dVOverZdX, dVOverZdY: Double;
    Procedure Gradients(const Vertices: Array of P2D);
  End;

  TEdge = Record
    X, XStep, Numerator, Denominator, ErrorTerm: Integer;
    Y, Height: Integer;
    OneOverZ, OneOverZStep, OneOverZStepExtra, UOverZ, UOverZStep, UOverZStepExtra, VOverZ, VOverZStep, VOverZStepExtra: Double;
	  Procedure edge(Gradients: TGradients; Vertices: Array of P2D; Top, Bottom: Integer);
    Function  Step: Integer; inline;
  End;
  pEdge = ^TEdge;

  Procedure TextureMapTriangle(Dest: TSurface; Vertices: T2DPointArray; Tex: TSurface);
  Procedure FloorDivMod(Numerator, Denominator: Integer; Var Floor, Modulus: Integer); inline;
  Procedure DrawScanLine(Dest: TSurface; Var Gradients: TGradients; Var pLeft, pRight: pEdge; Tex: TSurface);
  Procedure DrawScanLine_AA(Dest: TSurface; Var Gradients: TGradients; Var pLeft, pRight: pEdge; Tex: TSurface);
  Function  DrawQuad(Dest: TSurface; Vertices: Array of P3D; Tex: TSurface; Scale: Double; cx, cy: Integer): TRect;
  Procedure Rotate3D(Var Pts: Array of P3D; RotX, RotY, RotZ: Double);
  Procedure Translate3D(Var Pts: Array of P3D; TransX, TransY, TransZ: Double);
  Procedure Scale3D(Var Pts: Array of P3D; ScaleX, ScaleY, ScaleZ: Double);

Const

  FDIST = 300;

implementation

Uses Math;

Function Project2D(Dest: TSurface; Vertices: Array of P3D; Scale: Double; cx, cy: Integer): T2DPointArray;
Var
  Idx: Integer;
  f, Dist: Double;
Begin

  Dist := FDIST;

  SetLength(Result, Length(Vertices));

  For Idx := 0 To High(Vertices) Do Begin

    If Vertices[Idx].Z = dist Then
      f := 1
    Else
      f := dist / (Vertices[Idx].Z + dist);

    Result[Idx].X := Round(Vertices[Idx].X * f * Scale) + cx;
    Result[Idx].Y := Dest.Height - (Round(Vertices[Idx].Y * f * Scale) + cy);
    Result[Idx].Z := Vertices[Idx].Z;
    Result[Idx].U := Vertices[Idx].U;
    Result[Idx].V := Vertices[Idx].V;

  End;

End;

Procedure Rotate3D(Var Pts: Array of P3D; RotX, RotY, RotZ: Double);
Var
  Idx: Integer;
  xCos, yCos, zCos, xSin, ySin, zSin, y1, z1, x2: Double;
Begin
  xCos := Cos(RotX);
  yCos := Cos(RotY);
  zCos := Cos(RotZ);
  xSin := Sin(RotX);
  ySin := Sin(RotY);
  zSin := Sin(RotZ);
  For Idx := 0 To High(Pts) Do Begin
    y1 := Pts[Idx].Y * xCos + Pts[Idx].Z * xSin;
    z1 := Pts[Idx].Z * xCos - Pts[Idx].Y * xSin;
    x2 := Pts[Idx].X * yCos - z1 * ySin;
    Pts[Idx].Z := Pts[Idx].X * ySin + z1 * yCos;
    Pts[Idx].X := x2 * zCos - y1 * zSin;
    Pts[Idx].Y := x2 * zSin + y1 * zCos;
  End;
End;

Procedure Translate3D(Var Pts: Array of P3D; TransX, TransY, TransZ: Double);
Var
  Idx: Integer;
Begin
  For Idx := 0 To High(Pts) Do Begin
    Pts[Idx].X := Pts[Idx].X + TransX;
    Pts[Idx].Y := Pts[Idx].Y + TransY;
    Pts[Idx].Z := Pts[Idx].Z + TransZ;
  End;
End;

Procedure Scale3D(Var Pts: Array of P3D; ScaleX, ScaleY, ScaleZ: Double);
Var
  Idx: Integer;
Begin
  For Idx := 0 To High(Pts) Do Begin
    Pts[Idx].X := Pts[Idx].X * ScaleX;
    Pts[Idx].Y := Pts[Idx].Y * ScaleY;
    Pts[Idx].Z := Pts[Idx].Z * ScaleZ;
  End;
End;

Function  DrawQuad(Dest: TSurface; Vertices: Array of P3D; Tex: TSurface; Scale: Double; cx, cy: Integer): TRect;
Var
  Pts: T2DPointArray;
Begin

  Pts := Project2D(Dest, Vertices, Scale, cx, cy);

  TextureMapTriangle(Dest, [Pts[0], Pts[1], Pts[2]], Tex);
  TextureMapTriangle(Dest, [Pts[0], Pts[2], Pts[3]], Tex);

  Result.Left := Min(Min(Min(Pts[0].X, Pts[1].X), Pts[2].X), Pts[3].X);
  Result.Right := Max(Max(Max(Pts[0].X, Pts[1].X), Pts[2].X), Pts[3].X);
  Result.Top := Min(Min(Min(Pts[0].Y, Pts[1].Y), Pts[2].Y), Pts[3].Y);
  Result.Bottom := Max(Max(Max(Pts[0].Y, Pts[1].Y), Pts[2].Y), Pts[3].Y);

End;

Procedure FloorDivMod(Numerator, Denominator: Integer; Var Floor, Modulus: Integer);
Begin
	if Numerator >= 0 Then Begin
		Floor := Numerator Div Denominator;
		Modulus := Numerator Mod Denominator;
  End Else Begin
		Floor := -((-Numerator) Div Denominator);
		Modulus := (-Numerator) Mod Denominator;
		if Modulus > 0 Then Begin
			Dec(Floor);
      Modulus := Denominator - Modulus;
    End;
  End;
End;

Procedure TGradients.Gradients(const Vertices: Array of P2D);
Var
  Counter: Integer;
  OneOverDX, OneOverDY, OneOverZ: Double;
Begin

	OneOverdX := 1.0 / (((Vertices[1].X - Vertices[2].X) * (Vertices[0].Y - Vertices[2].Y)) -	((Vertices[0].X - Vertices[2].X) * (Vertices[1].Y - Vertices[2].Y)));
	OneOverdY := -OneOverdX;

	For Counter := 0 To 2 Do Begin
  	OneOverZ := 1.0 / (Vertices[Counter].Z + FDIST);
		aOneOverZ[Counter] := OneOverZ;
		aUOverZ[Counter] := Vertices[Counter].U * OneOverZ;
		aVOverZ[Counter] := Vertices[Counter].V * OneOverZ;
  End;

	dOneOverZdX := OneOverdX * (((aOneOverZ[1] - aOneOverZ[2]) * (Vertices[0].Y - Vertices[2].Y)) - ((aOneOverZ[0] - aOneOverZ[2]) * (Vertices[1].Y - Vertices[2].Y)));
	dOneOverZdY := OneOverdY * (((aOneOverZ[1] - aOneOverZ[2]) * (Vertices[0].X - Vertices[2].X)) -	((aOneOverZ[0] - aOneOverZ[2]) * (Vertices[1].X - Vertices[2].X)));

	dUOverZdX := OneOverdX * (((aUOverZ[1] - aUOverZ[2]) * (Vertices[0].Y - Vertices[2].Y)) - ((aUOverZ[0] - aUOverZ[2]) * (Vertices[1].Y - Vertices[2].Y)));
	dUOverZdY := OneOverdY * (((aUOverZ[1] - aUOverZ[2]) * (Vertices[0].X - Vertices[2].X)) - ((aUOverZ[0] - aUOverZ[2]) * (Vertices[1].X - Vertices[2].X)));

	dVOverZdX := OneOverdX * (((aVOverZ[1] - aVOverZ[2]) * (Vertices[0].Y - Vertices[2].Y)) - ((aVOverZ[0] - aVOverZ[2]) * (Vertices[1].Y - Vertices[2].Y)));
	dVOverZdY := OneOverdY * (((aVOverZ[1] - aVOverZ[2]) * (Vertices[0].X - Vertices[2].X)) - ((aVOverZ[0] - aVOverZ[2]) * (Vertices[1].X - Vertices[2].X)));

End;

Procedure TEdge.edge(Gradients: TGradients; Vertices: Array of P2D; Top, Bottom: Integer);
Var
  width: Integer;
Begin

	Y := Vertices[Top].Y;
	Height := Vertices[Bottom].Y - Y;
	Width := Vertices[Bottom].X - Vertices[Top].X;

	If Height > 0 Then Begin
		FloorDivMod(Width * (Y - Vertices[Top].Y) - 1, Height, X, ErrorTerm);
		Inc(X, Vertices[Top].X + 1);

		FloorDivMod(Width, Height, XStep, Numerator);
		Denominator := Height;

		OneOverZ := Gradients.aOneOverZ[Top];
		OneOverZStep := XStep * Gradients.dOneOverZdX + Gradients.dOneOverZdY;
		OneOverZStepExtra := Gradients.dOneOverZdX;

		UOverZ := Gradients.aUOverZ[Top];
		UOverZStep := XStep * Gradients.dUOverZdX + Gradients.dUOverZdY;
		UOverZStepExtra := Gradients.dUOverZdX;

		VOverZ := Gradients.aVOverZ[Top];
		VOverZStep := XStep * Gradients.dVOverZdX + Gradients.dVOverZdY;
		VOverZStepExtra := Gradients.dVOverZdX;
  End;

End;

Function TEdge.Step: Integer;
Begin

	Inc(X, XStep);
  Inc(Y);
  Dec(Height);
	UOverZ := UOverZ + UOverZStep;
  VOverZ := VOverZ + VOverZStep;
  OneOverZ := OneOverZ + OneOverZStep;

	Inc(ErrorTerm, Numerator);
	if ErrorTerm >= Denominator Then Begin
    Inc(X);
		Dec(ErrorTerm, Denominator);
		OneOverZ := OneOverZ + OneOverZStepExtra;
		UOverZ   := UOverZ   + UOverZStepExtra;
    VOverZ   := VOverZ   + VOverZStepExtra;
  End;

	Result := Height;

End;

Procedure TextureMapTriangle(Dest: TSurface; Vertices: T2DPointArray; Tex: TSurface);
Var
  Top, Middle, Bottom, MiddleForCompare, BottomForCompare, Y0, Y1, Y2, MiddleIsLeft, Height: Integer;
  Gradients: TGradients;
  TopToBottom, TopToMiddle, MiddleToBottom: TEdge;
  pLeft, pRight: pEdge;
Begin

	Y0 := Vertices[0].Y;
  Y1 := Vertices[1].Y;
  Y2 := Vertices[2].Y;

	if Y0 < Y1 Then Begin
		if Y2 < Y0 Then Begin
      Top := 2;
      Middle := 0;
      Bottom := 1;
			MiddleForCompare := 0;
      BottomForCompare := 1;
    End else Begin
			Top := 0;
			if Y1 < Y2 Then Begin
				Middle := 1;
        Bottom := 2;
				MiddleForCompare := 1;
        BottomForCompare := 2;
			End else Begin
				Middle := 2;
        Bottom := 1;
				MiddleForCompare := 2;
        BottomForCompare := 1;
      End;
    End;
	End else Begin
		if Y2 < Y1 Then Begin
			Top := 2;
      Middle := 1;
      Bottom := 0;
			MiddleForCompare := 1;
      BottomForCompare := 0;
		End else Begin
			Top := 1;
			if Y0 < Y2 Then Begin
				Middle := 0;
        Bottom := 2;
				MiddleForCompare := 3;
        BottomForCompare := 2;
			End else Begin
				Middle := 2;
        Bottom := 0;
				MiddleForCompare := 2;
        BottomForCompare := 3;
      End;
    End;
  End;

	Gradients.Gradients(Vertices);
	TopToBottom.Edge(Gradients, Vertices, Top, Bottom);
	TopToMiddle.Edge(Gradients, Vertices, Top, Middle);
	MiddleToBottom.Edge(Gradients, Vertices, Middle, Bottom);

	if BottomForCompare > MiddleForCompare Then Begin
		MiddleIsLeft := 0;
		pLeft := @TopToBottom;
    pRight := @TopToMiddle;
	End else Begin
		MiddleIsLeft := 1;
		pLeft := @TopToMiddle;
    pRight := @TopToBottom;
  End;

	Height := TopToMiddle.Height;

	while Height > 0 Do Begin
    If (pLeft.Y >= 0) And (pLeft.Y < Dest.Height) Then
  		DrawScanLine_AA(Dest, Gradients, pLeft, pRight, Tex);
		TopToMiddle.Step;
    TopToBottom.Step;
    Dec(height);
  End;

	Height := MiddleToBottom.Height;

	If MiddleIsLeft <> 0 Then Begin
		pLeft := @MiddleToBottom;
    pRight := @TopToBottom;
	End else Begin
		pLeft := @TopToBottom;
    pRight := @MiddleToBottom;
  End;

	While Height > 0 Do Begin
    If (pLeft.Y >= 0) And (pLeft.Y < Dest.Height) Then
		  DrawScanLine_AA(Dest, Gradients, pLeft, pRight, Tex);
		MiddleToBottom.Step;
    TopToBottom.Step;
    Dec(Height);
  End;

End;

Procedure DrawScanLine(Dest: TSurface; Var Gradients: TGradients; Var pLeft, pRight: pEdge; Tex: TSurface);
Var
  XStart, Width, U, V: Integer;
  OneOverZ, UOverZ, VOverZ, Z: Double;
  DstPtr, TexPtr: pLongWord;
Begin

	XStart := pLeft^.X;
	Width := pRight^.X - XStart;

  DstPtr := pLongWord(Dest.Bits);
  TexPtr := pLongWord(Tex.Bits);

	Inc(DstPtr, pLeft^.Y * Dest.Width + XStart);

	OneOverZ := pLeft^.OneOverZ;
	UOverZ := pLeft^.UOverZ;
	VOverZ := pLeft^.VOverZ;

	While Width > 0 Do Begin

		Z := 1 / OneOverZ;
		U := Trunc(UOverZ * Z);
		V := Trunc(VOverZ * Z);

    If (XStart >= 0) And (XStart < Dest.Width) then
      DstPtr^ := pLongWord(NativeUInt(TexPtr) + (U + (V * Tex.Width)) * SizeOf(LongWord))^;

    Inc(XStart);
		OneOverZ := OneOverZ + Gradients.dOneOverZdX;
		UOverZ := UOverZ + Gradients.dUOverZdX;
		VOverZ := VOverZ + Gradients.dVOverZdX;
    Dec(Width);
    Inc(DstPtr);

  End;

End;

Procedure DrawScanLine_AA(Dest: TSurface; Var Gradients: TGradients; Var pLeft, pRight: pEdge; Tex: TSurface);
Var
  XStart, Width: Integer;
  U, V, UFrac, VFrac, OneOverZ, UOverZ, VOverZ, Z: Double;
  DstPtr: pLongWord;
  TexPtr: pLongWord;
  TexX, TexY, TexX1, TexY1: Integer;
  TexWidth, TexHeight: Integer;
  C00, C01, C10, C11: LongWord;
  R, G, B: Double;
Begin
  XStart := pLeft^.X;
  Width := pRight^.X - XStart;

  DstPtr := pLongWord(Dest.Bits);
  TexPtr := pLongWord(Tex.Bits);

  Inc(DstPtr, pLeft^.Y * Dest.Width + XStart);

  OneOverZ := pLeft^.OneOverZ;
  UOverZ := pLeft^.UOverZ;
  VOverZ := pLeft^.VOverZ;

  TexWidth := Tex.Width;
  TexHeight := Tex.Height;

  While Width > 0 Do Begin
    Z := 1 / OneOverZ;
    U := (UOverZ * Z);
    V := (VOverZ * Z);

    TexX := Trunc(U);
    TexY := Trunc(V);
    UFrac := U - TexX;
    VFrac := V - TexY;

    TexX1 := Min(TexWidth -1, TexX + 1);
    TexY1 := Min(TexHeight -1, TexY +1);

    C00 := pLongWord(NativeUInt(TexPtr) + (TexX + TexY * TexWidth) * SizeOf(LongWord))^;
    C01 := pLongWord(NativeUInt(TexPtr) + (TexX1 + TexY * TexWidth) * SizeOf(LongWord))^;
    C10 := pLongWord(NativeUInt(TexPtr) + (TexX + TexY1 * TexWidth) * SizeOf(LongWord))^;
    C11 := pLongWord(NativeUInt(TexPtr) + (TexX1 + TexY1 * TexWidth) * SizeOf(LongWord))^;

    R := ((1 - UFrac) * (1 - VFrac) * ((C00 shr 16) and $FF) + UFrac * (1 - VFrac) * ((C01 shr 16) and $FF) + (1 - UFrac) * VFrac * ((C10 shr 16) and $FF) + UFrac * VFrac * ((C11 shr 16) and $FF));
    G := ((1 - UFrac) * (1 - VFrac) * ((C00 shr 8) and $FF) + UFrac * (1 - VFrac) * ((C01 shr 8) and $FF) + (1 - UFrac) * VFrac * ((C10 shr 8) and $FF) + UFrac * VFrac * ((C11 shr 8) and $FF));
    B := ((1 - UFrac) * (1 - VFrac) * (C00 and $FF) + UFrac * (1 - VFrac) * (C01 and $FF) + (1 - UFrac) * VFrac * (C10 and $FF) + UFrac * VFrac * (C11 and $FF));

    If (XStart >= 0) And (XStart < Dest.Width) Then
      DstPtr^ := (Trunc(R) shl 16) or (Trunc(G) shl 8) or Trunc(B);

    Inc(XStart);
    OneOverZ := OneOverZ + Gradients.dOneOverZdX;
    UOverZ := UOverZ + Gradients.dUOverZdX;
    VOverZ := VOverZ + Gradients.dVOverZdX;
    Dec(Width);
    Inc(DstPtr);
  End;
End;

end.
