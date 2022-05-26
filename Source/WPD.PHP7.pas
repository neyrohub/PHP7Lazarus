unit WPD.PHP7;

{$IFDEF FPC}
{$H+}
{$ENDIF}

interface
{$INCLUDE wpdefines.inc}
uses
  Windows, SysUtils,
  {$IFDEF FPC}
  LazUTF8,
  LazUTF8Classes,
  {$ENDIF}
  WideStrUtils, Variants,
  WPD.Zend.Types7,
  WPD.Vis7;

const
  fso = {$IFDEF MSWINDOWS}'.dll'{$ELSE}'.so'{$ENDIF};
  MSCRT = 'msvcrt.dll';
var
  DllPHP: String;
  phpHandle: THandle = 0;
  ZvalSetStr: procedure(Result: pzval; sr:UTF8String);
procedure Load(LibraryName: String);
function  strdup(strSource : PUTF8Char) : PUTF8Char; cdecl; external MSCRT name '_strdup';
procedure ZVAL_TRUE(value: pzval);
procedure ZVAL_FALSE(value: pzval);
procedure ZvalVALStrNull(z: pzval); overload;
procedure ZvalVAL(z: pzval; s: {$ifdef fpc}String{$else}AnsiString{$endif}); overload;
procedure ZvalVAL(z: pzval; s: WideString); overload;
procedure ZvalVAL(z: pzval; s: UTF8String); overload;
function ZendAlterIniEntry(name, new_value: PAnsiChar;
  modify_type, stage: Integer): Integer;
{$IFDEF FPC}
function zend_get_parameters_my(number: integer; var Params: specialize TArray<pzval>): integer;
{$ELSE}
function zend_get_parameters_my(number: integer; var Params: TArray<pzval>): integer;
{$ENDIF}

{$ifdef fpc}
function zend_get_parameters_array(execute_data: pzend_execute_data; number: integer; var Params: specialize TArray<pzval>): integer;
{$else}
function zend_get_parameters_array(execute_data: pzend_execute_data; number: integer; var Params:TArray<pzval>): integer;
{$endif}

procedure ZvalHRESULTStr(z: pzval; h: HRESULT);

function ZValGet(v: pzval; GetType: Integer): Variant;

procedure ZvalVAL(z: pzval; v: Boolean)overload;
procedure ZvalVAL(z: pzval; v: Integer; const _type: Integer = IS_LONG)overload;
procedure ZvalVAL(z: pzval)overload;
procedure ZvalVAL(z: pzval; v: Double)overload;
{$ifdef fpc}
procedure ZValVAL(z: pzval; v: Single); overload;
{$else}
procedure ZvalVAL(z: pzval; v: Extended); overload;
{$ENDIF}

function ZvalGetInt(v: pzval): Integer;
function ZvalGetDouble(v: pzval): Double;
function ZvalGetBool(v: pzval): Boolean;

function ZvalGetString(z: pzval): WideString;
function ZvalGetStringA(z: pzval): AnsiString;
function ZvalGetStringU(z: pzval): UTF8String;
function ZvalGetStringRaw(z: pzval): RawByteString;

function ZvalToVariant(v: pzval): Variant;
function ZvalToPointer(v: pzval): Pointer;
function ZValArrayKeyFind(v: pzval; key: AnsiString; out pData: ppzval)
  : Boolean; overload;
function ZValArrayKeyFind(v: pzval; idx: Integer; out pData: ppzval)
  : Boolean; overload;

function GetArgPZval(Args: TVarRec; const _type: Integer = IS_LONG;
  Make: Boolean = false): pzval;
{$ifdef fpc}
function LoadPHPFunc(Func: PPointer; FuncName: LPCSTR; fault: boolean = true): Boolean;
{$else}
function LoadPHPFunc(var Func: Pointer; FuncName: LPCSTR; fault: boolean = true): Boolean;
{$endif}
procedure UnloadZEND;
function PHPLibraryName(Instance: THandle; const DefaultName: PAnsiChar = nil)
  : PAnsiChar;
function HRESULTStr(h: HRESULT): Pchar;
function GetSAPIGlobals: Psapi_globals_struct;
function GetCompilerGlobals:  P_zend_compiler_globals;
function GetExecutorGlobals: P_zend_executor_globals;
function EG: P_zend_executor_globals;
 function ZEND_CALL_VAR_NUM(call: pointer; n: IntPtr): pzval;
 function ZEND_CALL_ARG(call: pointer; n: IntPtr): pzval;
procedure zend_error_cb2(AType: Integer; const AFname: PUtf8Char;
  const ALineNo: UINT; const AFormat: PUtf8Char; Args: va_list)cdecl;

var
  sapi_globals_id: Pointer;
  core_globals_id: Pointer;
  AppIn: boolean = False;
implementation

procedure UnloadZEND;
begin
  if phpHandle <> 0 then
  begin
    FreeLibrary(phpHandle);
    phpHandle := 0;
  end;
end;
{$IFDEF FPC}
//Part of LazUtils, (c) 2006-2020 Lazarus Team
//Unit LazUTF8
//Function: IsASCII
function IsUTF8String(const s: string): boolean; inline;
var
  i: Integer;
begin
  Result := False;
  for i:=1 to length(s) do if ord(s[i])>255 then Exit(True);
end;
{$ENDIF}
{$ifdef fpc}
function LoadPHPFunc (Func: PPointer; FuncName: LPCSTR; fault: boolean = true)
{$else}
function LoadPHPFunc (var Func: Pointer; FuncName: LPCSTR; fault: boolean = true)
{$endif}
  : Boolean;
begin
  Result := True;
  if phpHandle = 0 then
    if FileExists(DllPHP + Fso) then
    begin
      phpHandle := GetModuleHandle(PChar(DllPHP + Fso));
      if phpHandle = 0 then
        phpHandle := LoadLibrary(PChar(DllPHP + Fso));
      if phpHandle = 0 then
      begin
        WPD.Vis7.Out(HRESULTStr(GetLastError) + #10#13 + '- ' + DllPHP + Fso);
        Result := False;
        Halt;
      end;
    end;

{$ifdef fpc}
  Func^ := GetProcAddress(phpHandle, FuncName);
  if not Assigned(Func^) then
{$else}
  Func := GetProcAddress(phpHandle, FuncName);
  if not assigned(Func) then
{$endif}
  begin
    if fault then
    MessageBox(0, PChar('Unable to link [' + FuncName + '] function'),
      PChar('LoadFunction from ' + DllPHP + Fso), 0);
    Result := False;
  end;
end;

procedure zend_error_cb2(AType: Integer; const AFname: PUTF8Char;
  const ALineNo: UINT; const AFormat: PUTF8Char; Args: va_list)cdecl;
var
  LText: string;
  LBuffer: array [0 .. 4096] of UTF8Char;
begin
  case AType of
    E_ERROR:
      LText := 'FATAL Error in ';
    E_WARNING:
      LText := 'Warning in ';
    E_CORE_ERROR:
      LText := 'Core Error in ';
    E_CORE_WARNING:
      LText := 'Core Warning in ';
    E_COMPILE_ERROR:
      LText := 'Compile Error in ';
    E_COMPILE_WARNING:
      LText := 'Compile Warning in ';
    E_USER_ERROR:
      LText := 'User Error in ';
    E_USER_WARNING:
      LText := 'User Warning in ';
    E_RECOVERABLE_ERROR:
      LText := 'Recoverable Error in ';
    E_PARSE:
      LText := 'Parse Error in ';
    E_NOTICE:
      LText := 'Notice in ';
    E_USER_NOTICE:
      LText := 'User Notice in ';
    E_STRICT:
      LText := 'Strict Error in ';
    E_CORE:
      LText := 'Core Error in ';
  else
    LText := 'Unknown Error(' + inttostr(AType) + '): ';
  end;

  wvsprintfA(LBuffer, AFormat, Args);
  LText := LText + AFname + '(' + inttostr(ALineNo) + '): '
    + LBuffer;
  case AType of
    E_WARNING, E_CORE_WARNING, E_COMPILE_WARNING, E_USER_WARNING:
      WPD.Vis7.Out(LText, true);
    E_NOTICE, E_USER_NOTICE:
      WPD.Vis7.Out(LText, true);
  else
    begin
      WPD.Vis7.Out(LText, true);
      _zend_bailout(AFname, ALineNo);
    end;
  end;
end;

function HRESULTStr(h: HRESULT): Pchar;
begin
  FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM,
    nil, h, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), @Result, 0, nil);
end;

function shearPosString(const PosA, PosB, str: string): AnsiString;
  function PosAString(const SubStr, s: string; last: Boolean = false): String;

  var
    LenA, LenB, SubStrLen: Integer;
    B: Boolean;
  begin
    SubStrLen := SubStr.Length;
    LenA := s.Length;
    Result := s;
    if last then
    begin
      while (LenA > 0) and (not B) do
      begin
        B := Copy(s, LenA, SubStrLen) = SubStr;
        if B then
          delete(Result, LenA, Result.Length);
        Dec(LenA);
      end;
    end
    else
    begin
      LenB := 0;
      while (LenB <> LenA) and (not B) do
      begin
        B := Copy(s, LenB, SubStrLen) = SubStr;
        if B then
        begin
          if SubStrLen <> 1 then
            LenB := LenB + SubStrLen;

          delete(Result, 1, LenB);
        end;
        inc(LenB);
      end;
    end;
  end;

begin
  Result := AnsiString(PosAString(PosB, PosAString(PosA, str), true));
end;

function PHPLibraryName(Instance: THandle; const DefaultName: PAnsiChar = nil)
  : PAnsiChar;

var
  PName: PAnsiChar;
begin
  PName := PAnsiChar(shearPosString('php_', '.dll',
    ExtractFileName(GetModuleName(Instance))));
  if PName = nil then
    Result := DefaultName
  else
    Result := strnew(PName);
end;

function zend_string_alloc(len: SIZE_T; persistent: boolean): Pzend_string;
begin

  Result := PZend_string(
  pemalloc(ZEND_MM_ALIGNED_SIZE(_ZSTR_STRUCT_SIZE(len)), persistent)
  );

  Result^.gc.refcount := 1;
  Result^.gc.u.type_info := IS_STRING;
//  if persistent then
//    Result^.gc.u.type_info. v.flags := IS_STR_PERSISTENT
//  else
//     Result^.gc.u.v.flags := 0;
//  Result^.gc.u.v.gc_info := 0;

  Result^.h := 0;
  Result^.len := len;
end;

procedure ZvalSetStrDef(Result: pzval; sr:UTF8String);
begin
  Result^.value.str := zend_string_alloc(Length(sr), true);
  if Length(sr) = 0 then
    Exit;
  CopyMemory(@Result^.value.str^.val[0], @sr[1], Result^.value.str^.len);
  Result^.u1.type_info := IS_STRING_EX;
end;

procedure ZvalSetStrHk(Result: pzval; sr:UTF8String);
begin
  ZvalSetPChar(Result, PUTF8Char(sr), Length(sr), 1);
end;

procedure ZvalCopyStr(Text: pzval; var s: UTF8String);
begin
  if Text^.u1.v.type_ <> IS_STRING then
    Exit;

  SetLength(s, Text^.value.str^.len);

  if Text^.value.str^.len = 0 then
    Exit;
  Move(Text^.value.str^.val[0], s[1], Text^.value.str^.len);
end;
function ZvalGetStringRaw(z: pzval): RawByteString;
var s: UTF8String;
begin
  Result := '';
  case z^.u1.v.type_ of
    IS_FALSE:
      Result := RawByteString('False');
    IS_TRUE:
      Result := RawByteString('True');
    IS_BOOL, IS_LONG:
      Result := RawByteString(inttostr(z^.value.lval));
    IS_DOUBLE:
      Result := RawByteString(FloatToStr(z^.value.dval));
    IS_STRING:
      begin
        ZvalCopyStr(z, s);
        Result := RawByteString(s);
        SetCodePage(Result, CP_UTF8, not IsUTF8String(Result));
      end;
    IS_ARRAY:
       Result := RawByteString('(array)');
    IS_OBJECT:
       Result := RawByteString('[object]' + z^.value.obj^.ce^.name^.val);
    IS_RESOURCE:
       Result := RawByteString('#resource#id:' + IntToStr(z^.value.res^.handle));
  end;
end;

function ZvalGetString(z: pzval): WideString;
begin
  Result := WideString(ZvalGetStringRaw(z));
end;

function ZvalGetStringU(z: pzval): UTF8String;
begin
  ZvalCopyStr(z, Result);
end;

function ZvalGetStringA(z: pzval): AnsiString;
begin
  Result := ZvalGetStringRaw(z);
end;
function estrndup(s: PUTF8Char; len: Cardinal): PUTF8Char;
begin
  if assigned(s) then
    Result := _estrndup(s, len, nil, 0, nil, 0)
     else
      Result := nil;
end;
function  DupStr(strSource : PUtf8Char) : Putf8Char; cdecl;
var
  P : PUTF8Char;
begin

  if (strSource = nil) then
     P := nil
       else
         begin
           P := StrNew(strSource);
         end;
  Result := P;
end;



function ZvalToPointer(v: pzval): Pointer;
begin
  if v = nil then
    Exit(nil);

  Result := Pointer(0);
  case v^.u1.v.type_ of
    IS_BOOL, IS_LONG:
      Result := Pointer(v^.value.lval);
    IS_DOUBLE:
      Result := Pointer(Round(v^.value.dval));
    IS_STRING:
      try
        Result := Pointer(ZvalGetString(v));
      except
        on E: EConvertError do
          Result := nil;
      end;
    IS_TRUE:
      Result := Pointer(1);
    IS_OBJECT:
      begin
        if isset_property(v, '__DClassSelf') = 1 then
          Result := Pointer(read_property22(v, '__DClassSelf', 0)^.value.lval)
      end;
  end;
end;

function ZvalToVariant(v: pzval): Variant;
begin
  if v = nil then
    Exit(0);
  Result := 0;
  case v^.u1.v.type_ of
    IS_BOOL, IS_LONG:
      Result := v^.value.lval;
    IS_DOUBLE:
      Result := Round(v^.value.dval);
    IS_STRING:
      try
        Result := ZvalGetStringA(v)
      except
        on E: EConvertError do
          Result := '';
      end;
    IS_FALSE:
      Result := 0;
    IS_TRUE:
      Result := 1;
    IS_OBJECT:
      begin
        if isset_property(v, '__DClassSelf') = 1 then
          Result := read_property22(v, '__DClassSelf', 0)^.value.lval
        else
          Result := 0;
      end;
  end;
end;

function ZvalGetInt(v: pzval): Integer;
begin
  if v = nil then
    Exit(0);

  Result := 0;
  case v^.u1.v.type_ of
    IS_BOOL, IS_LONG:
      Result := v^.value.lval;
    IS_DOUBLE:
      Result := Round(v^.value.dval);
    IS_STRING:
      try
        Result := StrToInt(ZvalGetString(v))
      except
        on E: EConvertError do
          Result := 0;
      end;
    IS_FALSE:
      Result := 0;
    IS_TRUE:
      Result := 1;
    IS_OBJECT:
      begin
        if isset_property(v, '__DClassSelf') = 1 then
          Result := read_property22(v, '__DClassSelf', 0)^.value.lval
        else
          Result := 0;
      end;
  end;
end;

function ZvalGetDouble(v: pzval): Double;
begin
  Result := 0;
  case v^.u1.v.type_ of
    IS_BOOL, IS_LONG:
      Result := v^.value.lval;
    IS_DOUBLE:
      Result := v^.value.dval;
    IS_STRING:
      try
        Result := strtofloat(ZvalGetString(v));
      except
        on E: EConvertError do
          Result := 0;
      end;
    IS_TRUE:
      Result := 1;

  end;
end;

function ZvalGetBool(v: pzval): Boolean;
begin
  Result := false;
  case v^.u1.v.type_ of
    IS_BOOL, IS_LONG:
      Result := Boolean(v^.value.lval);
    IS_DOUBLE:
      Result := Boolean(Round(v^.value.dval));
    IS_STRING:
      try
        Result := StrToBool(ZvalGetString(v));
      except
        on E: EConvertError do
          Result := false;
      end;
    IS_TRUE:
      Result := true;
  end;
end;

function ZValGet(v: pzval; GetType: Integer): Variant;
begin
  Result := Null;
  case GetType of
    IS_LONG:
      Result := ZvalGetInt(v);
    IS_DOUBLE:
      Result := ZvalGetDouble(v);
    IS_BOOL:
      Result := ZvalGetBool(v);
    IS_STRING:
      Result := ZvalGetStringA(v);
    IS_FALSE:
      Result := 0;
    IS_TRUE:
      Result := 1;
  end;
end;

// _zval_get_string_func
function ZendAlterIniEntry(name, new_value: PAnsiChar;
  modify_type, stage: Integer): Integer;
var
  charset: p_zend_string;
begin
  // name = zend_string_init("iconv.input_encoding", sizeof("iconv.input_encoding") - 1, 0
  // Result := zend_alter_ini_entry(name, Length(name) + 1, new_value, Length(new_value), modify_type, stage);
end;

procedure ZvalVAL(z: pzval; v: Boolean);
Begin
  z^.u1.type_info := IS_BOOL;
  z^.value.lval := Integer(v);
  z^.u1.v.type_ := z^.u1.type_info;
End;

procedure ZvalVAL(z: pzval; v: Integer; const _type: Integer = IS_LONG);
Begin
//Это точно правильно?! Возможно, для PHP7 все должно быть наоборот?!
  z^.u1.type_info := _type;
  z^.u1.v.type_ := z^.u1.type_info;
  z^.value.lval := v;
End;

procedure ZvalVAL(z: pzval);
Begin
  z^.u1.type_info := IS_NULL;
  z^.u1.v.type_ := z^.u1.type_info;
End;

procedure ZvalVAL(z: pzval; v: Double);
Begin
  z^.u1.type_info := IS_DOUBLE;
  z^.value.dval := v;
  z^.u1.v.type_ := z^.u1.type_info;
End;

{$IFDEF fpc}
procedure ZvalVAL(z: pzval; v: Single);
{$ELSE}
procedure ZvalVAL(z: pzval; v: Extended);
{$ENDIF}
var D: Double;
Begin
  D := v;
  z^.u1.type_info := IS_DOUBLE;
  z^.value.dval := D;
  z^.u1.v.type_ := z^.u1.type_info;
End;

procedure ZVAL_TRUE(value: pzval);
begin
  value^.u1.type_info := IS_BOOL;
  value^.value.lval := 1;
  value^.u1.v.type_ := value^.u1.type_info;
end;

procedure ZVAL_FALSE(value: pzval);
begin
  value^.u1.type_info := IS_BOOL;
  value^.value.lval := 0;
  value^.u1.v.type_ := value^.u1.type_info;
end;

procedure ZvalVALStrNull(z: pzval);
begin
  ZvalSetStr(z, '');
end;

procedure ZvalVAL(z: pzval; s: {$ifdef fpc}String{$else}AnsiString{$endif});overload;
begin
  ZvalSetStr(z, UTF8String(s));
end;

procedure ZvalVAL(z: pzval; s: WideString);overload;
begin
 ZvalSetStr(z, UTF8String(s));
end;

procedure ZvalVAL(z: pzval; s: UTF8String);overload;
begin
  ZvalSetStr(z, s);
end;

procedure ZvalHRESULTStr(z: pzval; h: HRESULT);
begin
//TODO:
end;


{$ifdef fpc}
function zend_get_parameters_my(number: integer; var Params: specialize TArray<pzval>): integer;
{$else}
function zend_get_parameters_my(number: integer; var Params:TArray<pzval>): integer;
{$endif}
var
  i  : integer;
  p: ppzval;
begin
  if number = 0 then
    begin
    Result := SUCCESS;
    Exit;
    end;
  SetLength(Params, number);
  for i := 0 to number - 1 do
    begin
    New(Params[i]);
    end;

    // выделяем в ядре ZEND память под N-количество параметров, размером zval каждый
  p := emalloc(number * sizeOf(pzval));
    //передаем указатель на начало выделенной области, а внутри процедуры _zend_get_parameters_array_ex (zend_API.c) просто идет
    //итерация p := p + 1 и КОПИРОВАНИЕ реального значения переменной в переданный нами участок памяти
    //при помощи макроса ZVAL_COPY_VALUE(argument_array, param_ptr);
    //который не просто создает вам копию указателя, но еще и увеличивает число ссылок на оригинальное значение zend_refcounted *_gc = Z_COUNTED_P(_z2);
  Result := _zend_get_parameters_array_ex(number, p^); {пример вызова \ext\com_dotnet\com_handlers.c}

  for i := 0 to number - 1 do
    begin
    Params[i] := p^;
    if i <> number then
      p := ppzval( integer(p) + sizeof(pzval) );
    end;
  efree(p);// Очистка памяти, в которой находятся полученные переменные вызывает сомнение.
end;

{$ifdef fpc}
function zend_get_parameters_array(execute_data: pzend_execute_data; number: integer; var Params: specialize TArray<pzval>): integer;
{$else}
function zend_get_parameters_array(execute_data: pzend_execute_data; number: integer; var Params:TArray<pzval>): integer;
{$endif}
var
  i  : integer;
  p: pzval;
begin
//получение параметров происходит при помощи нескольких вложенных макросов ZEND_CALL_ARG() -> ZEND_CALL_VAR_NUM(),
//определенных в php-src-PHP-7.4.21\Zend\zend_compile.h
//полностью раскрытая строка кода на выходе препроцессора выглядит так:
//(((zval(p_execute_data)) + (((int)((ZEND_MM_ALIGNED_SIZE(sizeof(zend_execute_data)) + ZEND_MM_ALIGNED_SIZE(sizeof(zval)) - 1) / ZEND_MM_ALIGNED_SIZE(sizeof(zval)))) + ((int)(n))))

{ пример вызова \ext\com_dotnet\com_handlers.c
nargs = ZEND_NUM_ARGS();
if (nargs)
        args = (zval *)safe_emalloc(sizeof(zval), nargs, 0);
        zend_get_parameters_array_ex(nargs, args);

}
Result := FAILURE;
  if number = 0 then
    begin
    Result := SUCCESS;
    Exit;
    end;

  // выделяем в ядре ZEND память под N-количество параметров, размером zval каждый
//  p := emalloc(number * sizeOf(zval));
  //передаем указатель на начало выделенной области, а внутри процедуры _zend_get_parameters_array_ex (zend_API.c) просто идет
  //итерация p := p + 1 и КОПИРОВАНИЕ реального значения переменной в переданный нами участок памяти
  //при помощи макроса ZVAL_COPY_VALUE(argument_array, param_ptr);
  //который не просто создает вам копию указателя, но еще и увеличивает число ссылок на оригинальное значение zend_refcounted *_gc = Z_COUNTED_P(_z2);
//  Result := _zend_get_parameters_array_ex(number, p);
  SetLength(Params, number);
  if (length(Params) = number) then
    begin
    //SetLength(Params, number);
    //Result := _zend_get_parameters_array_ex(number, @Params);
    //на данный момент p[0]^ = parametr1
    //на данный момент p[1]^ = parametr2
    //че за хуйня идет дальше?!

    for i := 0 to number - 1 do
      begin
      //Params[i] := pzval(Pbyte(execute_data) + sizeOf(_zend_execute_data) + sizeOf(_zval_struct) * i + 8);//исправить константу 8 на вызов функции расчета смещения адреса в памяти
      Params[i] := pzval(Pbyte(execute_data) + ZEND_CALL_FRAME_SLOT + sizeOf(_zval_struct) * i);
      //т.е. это присвоение является копированием?
      //New(Params[i]);
      {Params[i] := p^;
      if i <> number then
        begin
        //p := pzval( integer(p) + sizeof(zval) ); ну зачем так?!
        p := p + 1;
        end;}
      end;
  //почему тут очищают выделенную память?
  //efree(p);
  Result := SUCCESS;
  end;
end;


function GetArgPZval(Args: TVarRec; const _type: Integer = IS_LONG;
  Make: Boolean = false): pzval;
begin
  New(Result);
  {$ifdef fpc}
  if Args.VPointer = nil then
  {$else}
  if Args._Reserved1 = 0 then // nil
  {$endif}
  begin
    Result^.u1.type_info := IS_NULL;
    Result^.u1.v.type_ := IS_NULL;
  end
  else if Args.VType = vtPointer then
    Result := Args.VPointer
  else
  begin
    case Args.VType of
      vtInteger:
        ZvalVAL(Result, Args.VInteger, _type);
      vtInt64:
        ZvalVAL(Result, NativeInt(Args.VInt64^), _type);
      vtBoolean:
        ZvalVAL(Result, Args.VBoolean);
      vtExtended:
        ZvalVAL(Result, Args.VExtended^);
      {$ifdef fpc}
      vtClass:
        ZvalVal(Result, IntPtr(@Args.VClass));
      vtObject:
        ZvalVal(Result, IntPtr(@Args.VObject));
      {$else}
      vtClass, vtObject:
        ZvalVAL(Result, Args._Reserved1);
      {$endif}
      vtString:
        ZvalVAL(Result, AnsiString(Args.VString^));
      vtAnsiString:
        ZvalVAL(Result, AnsiString(PAnsiChar(Args.VAnsiString)));
      {$ifdef fpc}
      vtUnicodeString:
        ZvalVal(Result, UnicodeString(Args.VUnicodeString));
      {$else}
      vtUnicodeString:
        ZvalVAL(Result, UnicodeString(Args._Reserved1));
      {$endif}
      vtWideChar:
        ZvalVAL(Result, WideString(Args.VWideChar));
      vtChar:
        ZvalVAL(Result, String(Args.VChar));
      vtPWideChar:
        ZvalVAL(Result, WideString(Args.VPWideChar));
      vtPChar:
        ZvalVAL(Result, String(Char(Args.VPChar)));
      vtWideString:
        ZvalVAL(Result, PWideChar(Args.VWideString));
    end;
  end;
end;

function __fgsapi(sapi_globals_value:WPD.Zend.Types7.IntPtr; tsrmls_dc:pointer): WPD.Zend.Types7.IntPtr;
type P = ^IntPtr;
begin
  Result := P( P(tsrmls_dc)^ + sapi_globals_value*Sizeof(Pointer) - Sizeof(Pointer))^;
end;

function GetSAPIGlobals: Psapi_globals_struct;
begin
  Result := nil;
  if assigned(sapi_globals_id) then
  begin
    Result := Psapi_globals_struct(__fgsapi(IntPtr(sapi_globals_id^), ts_resource_ex(0, nil)));
  end;
end;

function GetGlobalResource(resource_name: AnsiString): Pointer;
var
  global_id: Pointer;
begin
  Result := nil;
  try
    global_id := GetProcAddress(phpHandle, PAnsiChar(resource_name));
    if assigned(global_id) then
    begin
      Result := Pointer(__fgsapi(IntPtr(global_id^), ts_resource_ex(0, nil)));
    end;
  except
    Result := nil;
  end;
end;

function GetCompilerGlobals: P_zend_compiler_globals;
begin
  Result := GetGlobalResource('compiler_globals_id');
end;

function GetExecutorGlobals: p_zend_executor_globals;
begin
  Result := GetGlobalResource('executor_globals_id');
end;

  //#ifdef ZTS
  //# define EG(v) ZEND_TSRMG(executor_globals_id, zend_executor_globals *, v)
  //#else
  //# define EG(v) (executor_globals.v)
  //function EGZts(v): pointer;
  //begin

  //end;
  function EG: P_zend_executor_globals;
  begin
    Result := GetGlobalResource('executor_globals_id');
  end;
  function ZEND_CALL_VAR_NUM(call: pointer; n: IntPtr): pzval;
  begin
    Result := pzval((IntPtr(pzval(call))) + (ZEND_CALL_FRAME_SLOT + IntPtr(n)));
  end;
  function ZEND_CALL_ARG(call: pointer; n: IntPtr): pzval;
  begin
    Result := ZEND_CALL_VAR_NUM(call, n - 1);
  end;
function GetAllocGlobals: Pointer;
begin
  Result := GetGlobalResource('alloc_globals_id');
end;

function ZValArrayKeyFind(v: pzval; key: AnsiString; out pData: ppzval)
  : Boolean; overload;
var
  keyStr: PAnsiChar;
  KeyLength: UINT;
begin
  keyStr := PAnsiChar(key);
  KeyLength := Length(key) + 1;
  WPD.Vis7.Out(keyStr);

  // Result := zend_hash_quick_find(v.value.ht, keyStr, KeyLength,
  // zend_hash_func(keyStr, KeyLength), pData) = SUCCESS;
end;

// array_set_zval_key
function ZValArrayKeyFind(v: pzval; idx: Integer; out pData: ppzval)
  : Boolean; overload;
begin

  WPD.Vis7.Out('ZValArrayKeyFind' + idx.ToString());
  // Result := zend_hash_str_find
  // Result := zend_hash_quick_find(v.value.ht, nil, 0, idx, pData) = SUCCESS;
end;

procedure Load(LibraryName: String);
begin
DllPHP := LibraryName;
LoadPHPFunc(@tsrm_set_new_thread_begin_handler,
  'tsrm_set_new_thread_begin_handler');
LoadPHPFunc(@tsrm_set_new_thread_end_handler,
  'tsrm_set_new_thread_end_handler');
LoadPHPFunc(@tsrm_new_interpreter_context, 'tsrm_new_interpreter_context');
LoadPHPFunc(@tsrm_set_interpreter_context, 'tsrm_set_interpreter_context');
LoadPHPFunc(@tsrm_free_interpreter_context, 'tsrm_free_interpreter_context');
LoadPHPFunc(@tsrm_get_ls_cache, 'tsrm_get_ls_cache');
LoadPHPFunc(@tsrm_error_set, 'tsrm_error_set');
LoadPHPFunc(@tsrm_thread_id, 'tsrm_thread_id');
LoadPHPFunc(@tsrm_mutex_alloc, 'tsrm_mutex_alloc');
LoadPHPFunc(@tsrm_mutex_free, 'tsrm_mutex_free');
LoadPHPFunc(@tsrm_mutex_lock, 'tsrm_mutex_lock');
LoadPHPFunc(@tsrm_mutex_unlock, 'tsrm_mutex_unlock');
LoadPHPFunc(@tsrm_startup, 'tsrm_startup');
LoadPHPFunc(@tsrm_shutdown, 'tsrm_shutdown');
LoadPHPFunc(@ts_allocate_id, 'ts_allocate_id');
LoadPHPFunc(@ts_resource_ex, 'ts_resource_ex');
LoadPHPFunc(@ts_free_thread, 'ts_free_thread');
LoadPHPFunc(@ts_free_id, 'ts_free_id');
LoadPHPFunc(@php_request_startup, 'php_request_startup');
LoadPHPFunc(@php_request_shutdown, 'php_request_shutdown');
LoadPHPFunc(@php_request_shutdown_for_exec, 'php_request_shutdown_for_exec');
LoadPHPFunc(@php_module_startup, 'php_module_startup');
LoadPHPFunc(@php_module_shutdown, 'php_module_shutdown');
LoadPHPFunc(@php_module_shutdown_for_exec, 'php_module_shutdown_for_exec');
LoadPHPFunc(@php_module_shutdown_wrapper, 'php_module_shutdown_wrapper');
LoadPHPFunc(@php_request_startup_for_hook, 'php_request_startup_for_hook');
LoadPHPFunc(@php_request_shutdown_for_hook, 'php_request_shutdown_for_hook');
LoadPHPFunc(@php_register_extensions, 'php_register_extensions');
LoadPHPFunc(@php_execute_script, 'php_execute_script');
LoadPHPFunc(@php_execute_simple_script, 'php_execute_simple_script');
LoadPHPFunc(@php_lint_script, 'php_lint_script');
LoadPHPFunc(@php_handle_aborted_connection, 'php_handle_aborted_connection');
LoadPHPFunc(@php_handle_auth_data, 'php_handle_auth_data');
LoadPHPFunc(@php_html_puts, 'php_html_puts');
LoadPHPFunc(@php_stream_open_for_zend_ex, 'php_stream_open_for_zend_ex');
{$IFDEF CPUX64}
LoadPHPFunc(@zend_strndup, 'zend_strndup@@16');
LoadPHPFunc(@_emalloc, '_emalloc@@8');
LoadPHPFunc(@_safe_emalloc, '_safe_emalloc@@24');
LoadPHPFunc(@_safe_malloc, '_safe_malloc@@24');
LoadPHPFunc(@_efree, '_efree@@8');
LoadPHPFunc(@_ecalloc, '_ecalloc@@16');
LoadPHPFunc(@_erealloc, '_erealloc@@16');
LoadPHPFunc(@_erealloc2, '_erealloc2@@24');
LoadPHPFunc(@_safe_erealloc, '_safe_erealloc@@32');
LoadPHPFunc(@_safe_realloc, '_safe_realloc@@32');
LoadPHPFunc(@_estrdup, '_estrdup@@8');
LoadPHPFunc(@_estrndup, '_estrndup@@16');
LoadPHPFunc(@_zend_mem_block_size, '_zend_mem_block_size@@8');
{$ELSE}
LoadPHPFunc(@zend_strndup, 'zend_strndup@@8');
LoadPHPFunc(@_emalloc, '_emalloc@@4');
LoadPHPFunc(@_safe_emalloc, '_safe_emalloc@@12');
LoadPHPFunc(@_safe_malloc, '_safe_malloc@@12');
LoadPHPFunc(@_efree, '_efree@@4');
LoadPHPFunc(@_ecalloc, '_ecalloc@@8');
LoadPHPFunc(@_erealloc, '_erealloc@@8');
LoadPHPFunc(@_erealloc2, '_erealloc2@@12');
LoadPHPFunc(@_safe_erealloc, '_safe_erealloc@@16');
LoadPHPFunc(@_safe_realloc, '_safe_realloc@@16');
LoadPHPFunc(@_estrdup, '_estrdup@@4');
LoadPHPFunc(@_estrndup, '_estrndup@@8');
LoadPHPFunc(@_zend_mem_block_size, '_zend_mem_block_size@@4');
{$ENDIF}
LoadPHPFunc(@__zend_malloc, '__zend_malloc');
LoadPHPFunc(@__zend_calloc, '__zend_calloc');
LoadPHPFunc(@__zend_realloc, '__zend_realloc');
LoadPHPFunc(@zend_set_memory_limit, 'zend_set_memory_limit');
LoadPHPFunc(@start_memory_manager, 'start_memory_manager');
LoadPHPFunc(@shutdown_memory_manager, 'shutdown_memory_manager');
LoadPHPFunc(@is_zend_mm, 'is_zend_mm');
LoadPHPFunc(@zend_memory_usage, 'zend_memory_usage');
LoadPHPFunc(@zend_memory_peak_usage, 'zend_memory_peak_usage');
LoadPHPFunc(@zend_mm_startup, 'zend_mm_startup');
LoadPHPFunc(@zend_mm_shutdown, 'zend_mm_shutdown');
{$IFDEF CPUX64}
LoadPHPFunc(@_zend_mm_alloc, '_zend_mm_alloc@@16');
LoadPHPFunc(@_zend_mm_free, '_zend_mm_free@@16');
LoadPHPFunc(@_zend_mm_realloc, '_zend_mm_realloc@@24');
LoadPHPFunc(@_zend_mm_realloc2, '_zend_mm_realloc2@@32');
LoadPHPFunc(@_zend_mm_block_size, '_zend_mm_block_size@@16');
{$ELSE}
LoadPHPFunc(@_zend_mm_alloc, '_zend_mm_alloc@@8');
LoadPHPFunc(@_zend_mm_free, '_zend_mm_free@@8');
LoadPHPFunc(@_zend_mm_realloc, '_zend_mm_realloc@@12');
LoadPHPFunc(@_zend_mm_realloc2, '_zend_mm_realloc2@@16');
LoadPHPFunc(@_zend_mm_block_size, '_zend_mm_block_size@@8');
{$ENDIF}
LoadPHPFunc(@zend_mm_set_heap, 'zend_mm_set_heap');
LoadPHPFunc(@zend_mm_get_heap, 'zend_mm_get_heap');
LoadPHPFunc(@zend_mm_gc, 'zend_mm_gc');
LoadPHPFunc(@zend_mm_is_custom_heap, 'zend_mm_is_custom_heap');
LoadPHPFunc(@zend_mm_get_storage, 'zend_mm_get_storage');
LoadPHPFunc(@zend_mm_startup_ex, 'zend_mm_startup_ex');
LoadPHPFunc(@zend_stack_init, 'zend_stack_init');
LoadPHPFunc(@zend_stack_push, 'zend_stack_push');
LoadPHPFunc(@zend_stack_top, 'zend_stack_top');
LoadPHPFunc(@zend_stack_del_top, 'zend_stack_del_top');
LoadPHPFunc(@zend_stack_int_top, 'zend_stack_int_top');
LoadPHPFunc(@zend_stack_is_empty, 'zend_stack_is_empty');
LoadPHPFunc(@zend_stack_destroy, 'zend_stack_destroy');
LoadPHPFunc(@zend_stack_base, 'zend_stack_base');
LoadPHPFunc(@zend_stack_count, 'zend_stack_count');
LoadPHPFunc(@zend_stack_apply, 'zend_stack_apply');
LoadPHPFunc(@zend_stack_apply_with_argument, 'zend_stack_apply_with_argument');
LoadPHPFunc(@zend_stack_clean, 'zend_stack_clean');
LoadPHPFunc(@zend_std_get_static_method, 'zend_std_get_static_method');
LoadPHPFunc(@zend_std_get_static_property, 'zend_std_get_static_property');
LoadPHPFunc(@zend_std_unset_static_property, 'zend_std_unset_static_property');
LoadPHPFunc(@zend_std_get_constructor, 'zend_std_get_constructor');
LoadPHPFunc(@zend_get_property_info, 'zend_get_property_info');
LoadPHPFunc(@zend_std_get_properties, 'zend_std_get_properties');
LoadPHPFunc(@zend_std_get_debug_info, 'zend_std_get_debug_info');
LoadPHPFunc(@zend_std_cast_object_tostring, 'zend_std_cast_object_tostring');
LoadPHPFunc(@zend_std_write_property, 'zend_std_write_property');
LoadPHPFunc(@rebuild_object_properties, 'rebuild_object_properties');
LoadPHPFunc(@zend_check_private, 'zend_check_private');
LoadPHPFunc(@zend_check_protected, 'zend_check_protected');
LoadPHPFunc(@zend_check_property_access, 'zend_check_property_access');
LoadPHPFunc(@zend_get_call_trampoline_func, 'zend_get_call_trampoline_func');
LoadPHPFunc(@zend_ast_create_znode, 'zend_ast_create_znode');
LoadPHPFunc(@lex_scan, 'lex_scan');
LoadPHPFunc(@zend_set_compiled_filename, 'zend_set_compiled_filename');
LoadPHPFunc(@zend_restore_compiled_filename, 'zend_restore_compiled_filename');
LoadPHPFunc(@zend_get_compiled_filename, 'zend_get_compiled_filename');
LoadPHPFunc(@zend_get_compiled_lineno, 'zend_get_compiled_lineno');
LoadPHPFunc(@zend_get_scanned_file_offset, 'zend_get_scanned_file_offset');
LoadPHPFunc(@zend_get_compiled_variable_name,
  'zend_get_compiled_variable_name');
LoadPHPFunc(@get_unary_op, 'get_unary_op');
LoadPHPFunc(@get_binary_op, 'get_binary_op');
LoadPHPFunc(@do_bind_function, 'do_bind_function');
LoadPHPFunc(@do_bind_class, 'do_bind_class');
LoadPHPFunc(@do_bind_inherited_class, 'do_bind_inherited_class');
LoadPHPFunc(@zend_do_delayed_early_binding, 'zend_do_delayed_early_binding');
LoadPHPFunc(@function_add_ref, 'function_add_ref');
LoadPHPFunc(@compile_file, 'compile_file');
LoadPHPFunc(@compile_string, 'compile_string');
LoadPHPFunc(@compile_filename, 'compile_filename');
LoadPHPFunc(@zend_try_exception_handler, 'zend_try_exception_handler');
LoadPHPFunc(@zend_execute_scripts, 'zend_execute_scripts');
LoadPHPFunc(@open_file_for_scanning, 'open_file_for_scanning');
LoadPHPFunc(@init_op_array, 'init_op_array');
LoadPHPFunc(@destroy_op_array, 'destroy_op_array');
LoadPHPFunc(@zend_destroy_file_handle, 'zend_destroy_file_handle');
LoadPHPFunc(@zend_cleanup_user_class_data, 'zend_cleanup_user_class_data');
LoadPHPFunc(@zend_cleanup_internal_class_data,
  'zend_cleanup_internal_class_data');
LoadPHPFunc(@zend_cleanup_internal_classes, 'zend_cleanup_internal_classes');
LoadPHPFunc(@zend_cleanup_op_array_data, 'zend_cleanup_op_array_data');
LoadPHPFunc(@clean_non_persistent_function_full,
  'clean_non_persistent_function_full');
LoadPHPFunc(@clean_non_persistent_class_full,
  'clean_non_persistent_class_full');
LoadPHPFunc(@destroy_zend_function, 'destroy_zend_function');
LoadPHPFunc(@zend_function_dtor, 'zend_function_dtor');
LoadPHPFunc(@destroy_zend_class, 'destroy_zend_class');
LoadPHPFunc(@zend_mangle_property_name, 'zend_mangle_property_name');
LoadPHPFunc(@zend_unmangle_property_name_ex, 'zend_unmangle_property_name_ex');
LoadPHPFunc(@pass_two, 'pass_two');
LoadPHPFunc(@zend_is_compiling, 'zend_is_compiling');
LoadPHPFunc(@zend_make_compiled_string_description,
  'zend_make_compiled_string_description');
LoadPHPFunc(@zend_initialize_class_data, 'zend_initialize_class_data');
LoadPHPFunc(@zend_get_call_op, 'zend_get_call_op');
LoadPHPFunc(@zend_register_auto_global, 'zend_register_auto_global');
LoadPHPFunc(@zend_activate_auto_globals, 'zend_activate_auto_globals');
LoadPHPFunc(@zend_is_auto_global, 'zend_is_auto_global');
LoadPHPFunc(@zend_is_auto_global_str, 'zend_is_auto_global_str');
LoadPHPFunc(@zend_dirname, 'zend_dirname');
LoadPHPFunc(@zend_set_function_arg_flags, 'zend_set_function_arg_flags');
LoadPHPFunc(@zend_assert_valid_class_name, 'zend_assert_valid_class_name');
LoadPHPFunc(@zend_ast_create_zval_ex, 'zend_ast_create_zval_ex');
LoadPHPFunc(@zend_ast_create_ex, 'zend_ast_create_ex');
LoadPHPFunc(@zend_ast_create, 'zend_ast_create');
LoadPHPFunc(@zend_ast_create_decl, 'zend_ast_create_decl');
LoadPHPFunc(@zend_ast_create_list, 'zend_ast_create_list');
LoadPHPFunc(@zend_ast_list_add, 'zend_ast_list_add');
LoadPHPFunc(@zend_ast_evaluate, 'zend_ast_evaluate');
LoadPHPFunc(@zend_ast_export, 'zend_ast_export');
LoadPHPFunc(@zend_ast_copy, 'zend_ast_copy');
LoadPHPFunc(@zend_ast_destroy, 'zend_ast_destroy');
LoadPHPFunc(@zend_ast_destroy_and_free, 'zend_ast_destroy_and_free');
LoadPHPFunc(@zend_ast_apply, 'zend_ast_apply');
LoadPHPFunc(@zend_stream_open, 'zend_stream_open');
LoadPHPFunc(@zend_stream_fixup, 'zend_stream_fixup');
LoadPHPFunc(@zend_file_handle_dtor, 'zend_file_handle_dtor');
LoadPHPFunc(@zend_compare_file_handles, 'zend_compare_file_handles');
LoadPHPFunc(@_zend_bailout, '_zend_bailout');
LoadPHPFunc(@get_zend_version, 'get_zend_version');
LoadPHPFunc(@zend_make_printable_zval, 'zend_make_printable_zval');
LoadPHPFunc(@zend_print_zval, 'zend_print_zval');
// LoadPHPFunc(@zend_print_zval_ex, 'zend_print_zval_ex');
LoadPHPFunc(@zend_print_zval_r, 'zend_print_zval_r');
LoadPHPFunc(@zend_print_flat_zval_r, 'zend_print_flat_zval_r');
// LoadPHPFunc(@zend_print_zval_r_ex, 'zend_print_zval_r_ex');
LoadPHPFunc(@zend_output_debug_string, 'zend_output_debug_string');
LoadPHPFunc(@zend_activate, 'zend_activate');
LoadPHPFunc(@zend_deactivate, 'zend_deactivate');
LoadPHPFunc(@zend_call_destructors, 'zend_call_destructors');
LoadPHPFunc(@zend_activate_modules, 'zend_activate_modules');
LoadPHPFunc(@zend_deactivate_modules, 'zend_deactivate_modules');
LoadPHPFunc(@zend_post_deactivate_modules, 'zend_post_deactivate_modules');
LoadPHPFunc(@free_estring, 'free_estring');
LoadPHPFunc(@zend_error, 'zend_error');
LoadPHPFunc(@zend_throw_error, 'zend_throw_error');
LoadPHPFunc(@zend_type_error, 'zend_type_error');
LoadPHPFunc(@zend_internal_type_error, 'zend_internal_type_error');
LoadPHPFunc(@zend_message_dispatcher, 'zend_message_dispatcher');
LoadPHPFunc(@zend_get_configuration_directive,
  'zend_get_configuration_directive');
LoadPHPFunc(@zend_next_free_module, 'zend_next_free_module');
//LoadPHPFunc(@zend_get_parameters, 'zend_get_parameters');
//LoadPHPFunc(@zend_get_parameters_ex, 'zend_get_parameters_ex');
//LoadPHPFunc(@ZvalGetArgs, 'zend_get_parameters_ex');//PHP5
LoadPHPFunc(@_zend_get_parameters_array_ex, '_zend_get_parameters_array_ex');
LoadPHPFunc(@zend_copy_parameters_array, 'zend_copy_parameters_array');
LoadPHPFunc(@zend_parse_parameters, 'zend_parse_parameters');
LoadPHPFunc(@zend_parse_parameters_ex, 'zend_parse_parameters_ex');
LoadPHPFunc(@zend_parse_parameters_throw, 'zend_parse_parameters_throw');
LoadPHPFunc(@zend_zval_type_name, 'zend_zval_type_name');
LoadPHPFunc(@zend_parse_method_parameters, 'zend_parse_method_parameters');
LoadPHPFunc(@zend_parse_method_parameters_ex,
  'zend_parse_method_parameters_ex');
LoadPHPFunc(@zend_parse_parameter, 'zend_parse_parameter');
LoadPHPFunc(@zend_register_functions, 'zend_register_functions');
LoadPHPFunc(@zend_unregister_functions, 'zend_unregister_functions');
LoadPHPFunc(@zend_startup_module, 'zend_startup_module');
LoadPHPFunc(@zend_register_internal_module, 'zend_register_internal_module');
LoadPHPFunc(@zend_register_module_ex, 'zend_register_module_ex');
LoadPHPFunc(@zend_startup_module_ex, 'zend_startup_module_ex');
LoadPHPFunc(@zend_startup_modules, 'zend_startup_modules');
LoadPHPFunc(@zend_check_magic_method_implementation,
  'zend_check_magic_method_implementation');
LoadPHPFunc(@zend_register_internal_class, 'zend_register_internal_class');
LoadPHPFunc(@zend_register_internal_class_ex,
  'zend_register_internal_class_ex');
LoadPHPFunc(@zend_register_internal_interface,
  'zend_register_internal_interface');
LoadPHPFunc(@zend_class_implements, 'zend_class_implements');
LoadPHPFunc(@zend_register_class_alias_ex, 'zend_register_class_alias_ex');
LoadPHPFunc(@zend_disable_function, 'zend_disable_function');
LoadPHPFunc(@zend_disable_class, 'zend_disable_class');
LoadPHPFunc(@zend_is_callable_ex, 'zend_is_callable_ex');
LoadPHPFunc(@zend_is_callable, 'zend_is_callable');
LoadPHPFunc(@zend_make_callable, 'zend_make_callable');
LoadPHPFunc(@zend_get_module_version, 'zend_get_module_version');
LoadPHPFunc(@zend_get_module_started, 'zend_get_module_started');
LoadPHPFunc(@zend_declare_property_ex, 'zend_declare_property_ex');
LoadPHPFunc(@zend_declare_property, 'zend_declare_property');
LoadPHPFunc(@zend_declare_property_null, 'zend_declare_property_null');
LoadPHPFunc(@zend_declare_property_bool, 'zend_declare_property_bool');
LoadPHPFunc(@zend_declare_property_long, 'zend_declare_property_long');
LoadPHPFunc(@zend_declare_property_double, 'zend_declare_property_double');
LoadPHPFunc(@zend_declare_property_string, 'zend_declare_property_string');
LoadPHPFunc(@zend_declare_property_stringl, 'zend_declare_property_stringl');
LoadPHPFunc(@zend_declare_class_constant, 'zend_declare_class_constant');
LoadPHPFunc(@zend_declare_class_constant_null,
  'zend_declare_class_constant_null');
LoadPHPFunc(@zend_declare_class_constant_long,
  'zend_declare_class_constant_long');
LoadPHPFunc(@zend_declare_class_constant_bool,
  'zend_declare_class_constant_bool');
LoadPHPFunc(@zend_declare_class_constant_double,
  'zend_declare_class_constant_double');
LoadPHPFunc(@zend_declare_class_constant_stringl,
  'zend_declare_class_constant_stringl');
LoadPHPFunc(@zend_declare_class_constant_string,
  'zend_declare_class_constant_string');
LoadPHPFunc(@zend_update_class_constants, 'zend_update_class_constants');
LoadPHPFunc(@zend_update_property_ex, 'zend_update_property_ex');
LoadPHPFunc(@zend_update_property, 'zend_update_property');
LoadPHPFunc(@zend_update_property_null, 'zend_update_property_null');
LoadPHPFunc(@zend_update_property_bool, 'zend_update_property_bool');
LoadPHPFunc(@zend_update_property_long, 'zend_update_property_long');
LoadPHPFunc(@zend_update_property_double, 'zend_update_property_double');
LoadPHPFunc(@zend_update_property_str, 'zend_update_property_str');
LoadPHPFunc(@zend_update_property_string, 'zend_update_property_string');
LoadPHPFunc(@zend_update_property_stringl, 'zend_update_property_stringl');
LoadPHPFunc(@zend_update_static_property, 'zend_update_static_property');
LoadPHPFunc(@zend_update_static_property_null,
  'zend_update_static_property_null');
LoadPHPFunc(@zend_update_static_property_bool,
  'zend_update_static_property_bool');
LoadPHPFunc(@zend_update_static_property_long,
  'zend_update_static_property_long');
LoadPHPFunc(@zend_update_static_property_double,
  'zend_update_static_property_double');
LoadPHPFunc(@zend_update_static_property_string,
  'zend_update_static_property_string');
LoadPHPFunc(@zend_update_static_property_stringl,
  'zend_update_static_property_stringl');
LoadPHPFunc(@zend_read_property, 'zend_read_property');
LoadPHPFunc(@zend_read_static_property, 'zend_read_static_property');
LoadPHPFunc(@zend_get_type_by_const, 'zend_get_type_by_const');
LoadPHPFunc(@_array_init, '_array_init');
LoadPHPFunc(@_object_init, '_object_init');
LoadPHPFunc(@_object_init_ex, '_object_init_ex');
LoadPHPFunc(@_object_and_properties_init, '_object_and_properties_init');
LoadPHPFunc(@object_properties_init, 'object_properties_init');
LoadPHPFunc(@object_properties_init_ex, 'object_properties_init_ex');
LoadPHPFunc(@object_properties_load, 'object_properties_load');
LoadPHPFunc(@zend_merge_properties, 'zend_merge_properties');
LoadPHPFunc(@add_assoc_long_ex, 'add_assoc_long_ex');
LoadPHPFunc(@add_assoc_null_ex, 'add_assoc_null_ex');
LoadPHPFunc(@add_assoc_bool_ex, 'add_assoc_bool_ex');
LoadPHPFunc(@add_assoc_resource_ex, 'add_assoc_resource_ex');
LoadPHPFunc(@add_assoc_double_ex, 'add_assoc_double_ex');
LoadPHPFunc(@add_assoc_str_ex, 'add_assoc_str_ex');
LoadPHPFunc(@add_assoc_string_ex, 'add_assoc_string_ex');
LoadPHPFunc(@add_assoc_stringl_ex, 'add_assoc_stringl_ex');
LoadPHPFunc(@add_assoc_zval_ex, 'add_assoc_zval_ex');
LoadPHPFunc(@add_index_long, 'add_index_long');
LoadPHPFunc(@add_index_null, 'add_index_null');
LoadPHPFunc(@add_index_bool, 'add_index_bool');
LoadPHPFunc(@add_index_resource, 'add_index_resource');
LoadPHPFunc(@add_index_double, 'add_index_double');
LoadPHPFunc(@add_index_str, 'add_index_str');
LoadPHPFunc(@add_index_string, 'add_index_string');
LoadPHPFunc(@add_index_stringl, 'add_index_stringl');
LoadPHPFunc(@add_index_zval, 'add_index_zval');
LoadPHPFunc(@add_next_index_long, 'add_next_index_long');
LoadPHPFunc(@add_next_index_null, 'add_next_index_null');
LoadPHPFunc(@add_next_index_bool, 'add_next_index_bool');
LoadPHPFunc(@add_next_index_resource, 'add_next_index_resource');
LoadPHPFunc(@add_next_index_double, 'add_next_index_double');
LoadPHPFunc(@add_next_index_str, 'add_next_index_str');
LoadPHPFunc(@add_next_index_string, 'add_next_index_string');
LoadPHPFunc(@add_next_index_stringl, 'add_next_index_stringl');
LoadPHPFunc(@add_next_index_zval, 'add_next_index_zval');
LoadPHPFunc(@add_get_assoc_string_ex, 'add_get_assoc_string_ex');
LoadPHPFunc(@add_get_assoc_stringl_ex, 'add_get_assoc_stringl_ex');
LoadPHPFunc(@add_get_index_long, 'add_get_index_long');
LoadPHPFunc(@add_get_index_double, 'add_get_index_double');
LoadPHPFunc(@add_get_index_str, 'add_get_index_str');
LoadPHPFunc(@add_get_index_string, 'add_get_index_string');
LoadPHPFunc(@add_get_index_stringl, 'add_get_index_stringl');
LoadPHPFunc(@array_set_zval_key, 'array_set_zval_key');
LoadPHPFunc(@add_property_long_ex, 'add_property_long_ex');
LoadPHPFunc(@add_property_null_ex, 'add_property_null_ex');
LoadPHPFunc(@add_property_bool_ex, 'add_property_bool_ex');
LoadPHPFunc(@add_property_resource_ex, 'add_property_resource_ex');
LoadPHPFunc(@add_property_double_ex, 'add_property_double_ex');
LoadPHPFunc(@add_property_str_ex, 'add_property_str_ex');
LoadPHPFunc(@add_property_string_ex, 'add_property_string_ex');
LoadPHPFunc(@add_property_stringl_ex, 'add_property_stringl_ex');
LoadPHPFunc(@add_property_zval_ex, 'add_property_zval_ex');
// LoadPHPFunc(@call_user_function, 'call_user_function');
// LoadPHPFunc(@call_user_function_ex, 'call_user_function_ex');
LoadPHPFunc(@zend_fcall_info_init, 'zend_fcall_info_init');
LoadPHPFunc(@zend_fcall_info_args_clear, 'zend_fcall_info_args_clear');
LoadPHPFunc(@zend_fcall_info_args_save, 'zend_fcall_info_args_save');
LoadPHPFunc(@zend_fcall_info_args_restore, 'zend_fcall_info_args_restore');
LoadPHPFunc(@zend_fcall_info_args, 'zend_fcall_info_args');
LoadPHPFunc(@zend_fcall_info_args_ex, 'zend_fcall_info_args_ex');
LoadPHPFunc(@zend_fcall_info_argp, 'zend_fcall_info_argp');
LoadPHPFunc(@zend_fcall_info_argv, 'zend_fcall_info_argv');
LoadPHPFunc(@zend_fcall_info_argn, 'zend_fcall_info_argn');
LoadPHPFunc(@zend_fcall_info_call, 'zend_fcall_info_call');
LoadPHPFunc(@zend_call_function, 'zend_call_function');
LoadPHPFunc(@zend_set_hash_symbol, 'zend_set_hash_symbol');
LoadPHPFunc(@zend_delete_global_variable, 'zend_delete_global_variable');
LoadPHPFunc(@zend_rebuild_symbol_table, 'zend_rebuild_symbol_table');
LoadPHPFunc(@zend_attach_symbol_table, 'zend_attach_symbol_table');
LoadPHPFunc(@zend_detach_symbol_table, 'zend_detach_symbol_table');
LoadPHPFunc(@zend_set_local_var, 'zend_set_local_var');
LoadPHPFunc(@zend_set_local_var_str, 'zend_set_local_var_str');
LoadPHPFunc(@zend_find_alias_name, 'zend_find_alias_name');
LoadPHPFunc(@zend_resolve_method_name, 'zend_resolve_method_name');
LoadPHPFunc(@zend_get_object_type, 'zend_get_object_type');
LoadPHPFunc(@zend_wrong_param_count, 'zend_wrong_param_count');
{LoadPHPFunc(@zend_wrong_paramers_count_error, 'zend_wrong_paramers_count_error@@16');
  LoadPHPFunc(@zend_wrong_paramer_type_error,
  'zend_wrong_paramer_type_error@@12');
  LoadPHPFunc(@zend_wrong_paramer_class_error,
  'zend_wrong_paramer_class_error@@12'); }
{$IFDEF CPUX64}
LoadPHPFunc(@zend_wrong_callback_error, 'zend_wrong_callback_error@@24');
LoadPHPFunc(@zend_parse_arg_class, 'zend_parse_arg_class@@32');
LoadPHPFunc(@zend_parse_arg_bool_slow, 'zend_parse_arg_bool_slow@@16');
LoadPHPFunc(@zend_parse_arg_bool_weak, 'zend_parse_arg_bool_weak@@16');
LoadPHPFunc(@zend_parse_arg_long_slow, 'zend_parse_arg_long_slow@@16');
LoadPHPFunc(@zend_parse_arg_long_weak, 'zend_parse_arg_long_weak@@16');
LoadPHPFunc(@zend_parse_arg_long_cap_slow, 'zend_parse_arg_long_cap_slow@@16');
LoadPHPFunc(@zend_parse_arg_long_cap_weak, 'zend_parse_arg_long_cap_weak@@16');
LoadPHPFunc(@zend_parse_arg_double_slow, 'zend_parse_arg_double_slow@@16');
LoadPHPFunc(@zend_parse_arg_double_weak, 'zend_parse_arg_double_weak@@16');
LoadPHPFunc(@zend_parse_arg_str_slow, 'zend_parse_arg_str_slow@@16');
LoadPHPFunc(@zend_parse_arg_str_weak, 'zend_parse_arg_str_weak@@16');
{$ELSE}
LoadPHPFunc(@zend_wrong_callback_error, 'zend_wrong_callback_error@@12');
LoadPHPFunc(@zend_parse_arg_class, 'zend_parse_arg_class@@16');
LoadPHPFunc(@zend_parse_arg_bool_slow, 'zend_parse_arg_bool_slow@@8');
LoadPHPFunc(@zend_parse_arg_bool_weak, 'zend_parse_arg_bool_weak@@8');
LoadPHPFunc(@zend_parse_arg_long_slow, 'zend_parse_arg_long_slow@@8');
LoadPHPFunc(@zend_parse_arg_long_weak, 'zend_parse_arg_long_weak@@8');
LoadPHPFunc(@zend_parse_arg_long_cap_slow, 'zend_parse_arg_long_cap_slow@@8');
LoadPHPFunc(@zend_parse_arg_long_cap_weak, 'zend_parse_arg_long_cap_weak@@8');
LoadPHPFunc(@zend_parse_arg_double_slow, 'zend_parse_arg_double_slow@@8');
LoadPHPFunc(@zend_parse_arg_double_weak, 'zend_parse_arg_double_weak@@8');
LoadPHPFunc(@zend_parse_arg_str_slow, 'zend_parse_arg_str_slow@@8');
LoadPHPFunc(@zend_parse_arg_str_weak, 'zend_parse_arg_str_weak@@8');
{$ENDIF}
LoadPHPFunc(@sapi_startup, 'sapi_startup');
LoadPHPFunc(@sapi_shutdown, 'sapi_shutdown');
LoadPHPFunc(@sapi_activate, 'sapi_activate');
LoadPHPFunc(@sapi_deactivate, 'sapi_deactivate');
LoadPHPFunc(@sapi_initialize_empty_request, 'sapi_initialize_empty_request');
LoadPHPFunc(@sapi_header_op, 'sapi_header_op');
LoadPHPFunc(@sapi_add_header_ex, 'sapi_add_header_ex');
LoadPHPFunc(@sapi_send_headers, 'sapi_send_headers');
LoadPHPFunc(@sapi_free_header, 'sapi_free_header');
LoadPHPFunc(@sapi_handle_post, 'sapi_handle_post');
LoadPHPFunc(@sapi_read_post_block, 'sapi_read_post_block');
LoadPHPFunc(@sapi_register_post_entries, 'sapi_register_post_entries');
LoadPHPFunc(@sapi_register_post_entry, 'sapi_register_post_entry');
LoadPHPFunc(@sapi_unregister_post_entry, 'sapi_unregister_post_entry');
// LoadPHPFunc(@sapi_register_default_post_reader, 'sapi_register_default_post_reader');
LoadPHPFunc(@sapi_register_treat_data, 'sapi_register_treat_data');
LoadPHPFunc(@sapi_register_input_filter, 'sapi_register_input_filter');
LoadPHPFunc(@sapi_flush, 'sapi_flush');
LoadPHPFunc(@sapi_get_stat, 'sapi_get_stat');
LoadPHPFunc(@sapi_getenv, 'sapi_getenv');
LoadPHPFunc(@sapi_get_default_content_type, 'sapi_get_default_content_type');
LoadPHPFunc(@sapi_get_default_content_type_header,
  'sapi_get_default_content_type_header');
LoadPHPFunc(@sapi_apply_default_charset, 'sapi_apply_default_charset');
LoadPHPFunc(@sapi_activate_headers_only, 'sapi_activate_headers_only');
LoadPHPFunc(@sapi_get_fd, 'sapi_get_fd');
LoadPHPFunc(@sapi_force_http_10, 'sapi_force_http_10');
LoadPHPFunc(@sapi_get_target_uid, 'sapi_get_target_uid');
LoadPHPFunc(@sapi_get_target_gid, 'sapi_get_target_gid');
LoadPHPFunc(@sapi_get_request_time, 'sapi_get_request_time');
LoadPHPFunc(@sapi_terminate_process, 'sapi_terminate_process');
LoadPHPFunc(@_php_stream_alloc, '_php_stream_alloc');
LoadPHPFunc(@_php_stream_tell, '_php_stream_tell');
LoadPHPFunc(@_php_stream_read, '_php_stream_read');
LoadPHPFunc(@_php_stream_write, '_php_stream_write');
LoadPHPFunc(@_php_stream_fill_read_buffer, '_php_stream_fill_read_buffer');
LoadPHPFunc(@_php_stream_printf, '_php_stream_printf');
LoadPHPFunc(@_php_stream_eof, '_php_stream_eof');
LoadPHPFunc(@_php_stream_seek, '_php_stream_seek');
LoadPHPFunc(@_php_stream_free, '_php_stream_free');
LoadPHPFunc(@php_stream_encloses, 'php_stream_encloses');
LoadPHPFunc(@_php_stream_free_enclosed, '_php_stream_free_enclosed');
LoadPHPFunc(@php_stream_from_persistent_id, 'php_stream_from_persistent_id');
LoadPHPFunc(@php_file_le_stream, 'php_file_le_stream');
LoadPHPFunc(@php_file_le_pstream, 'php_file_le_pstream');
LoadPHPFunc(@php_file_le_stream_filter, 'php_file_le_stream_filter');
LoadPHPFunc(@_php_stream_getc, '_php_stream_getc');
LoadPHPFunc(@_php_stream_putc, '_php_stream_putc');
LoadPHPFunc(@_php_stream_flush, '_php_stream_flush');
LoadPHPFunc(@_php_stream_get_line, '_php_stream_get_line');
LoadPHPFunc(@_php_stream_get_url_stream_wrappers_hash,
  '_php_stream_get_url_stream_wrappers_hash');
LoadPHPFunc(@php_stream_get_url_stream_wrappers_hash_global,
  'php_stream_get_url_stream_wrappers_hash_global');
LoadPHPFunc(@_php_get_stream_filters_hash, '_php_get_stream_filters_hash');
LoadPHPFunc(@php_get_stream_filters_hash_global,
  'php_get_stream_filters_hash_global');
LoadPHPFunc(@_php_stream_truncate_set_size, '_php_stream_truncate_set_size');
LoadPHPFunc(@_php_stream_make_seekable, '_php_stream_make_seekable');
LoadPHPFunc(@_php_stream_copy_to_stream, '_php_stream_copy_to_stream');
LoadPHPFunc(@_php_stream_copy_to_mem, '_php_stream_copy_to_mem');
LoadPHPFunc(@_php_stream_copy_to_stream_ex, '_php_stream_copy_to_stream_ex');
LoadPHPFunc(@_php_stream_passthru, '_php_stream_passthru');
LoadPHPFunc(@_php_stream_cast, '_php_stream_cast');
LoadPHPFunc(@php_register_url_stream_wrapper,
  'php_register_url_stream_wrapper');
LoadPHPFunc(@php_unregister_url_stream_wrapper,
  'php_unregister_url_stream_wrapper');
LoadPHPFunc(@php_register_url_stream_wrapper_volatile,
  'php_register_url_stream_wrapper_volatile');
LoadPHPFunc(@php_unregister_url_stream_wrapper_volatile,
  'php_unregister_url_stream_wrapper_volatile');
LoadPHPFunc(@_php_stream_open_wrapper_ex, '_php_stream_open_wrapper_ex');
LoadPHPFunc(@php_stream_locate_url_wrapper, 'php_stream_locate_url_wrapper');
LoadPHPFunc(@php_stream_locate_eol, 'php_stream_locate_eol');
LoadPHPFunc(@php_stream_get_record, 'php_stream_get_record');
LoadPHPFunc(@php_stream_wrapper_log_error, 'php_stream_wrapper_log_error');
LoadPHPFunc(@_php_stream_puts, '_php_stream_puts');
LoadPHPFunc(@_php_stream_stat, '_php_stream_stat');
LoadPHPFunc(@_php_stream_stat_path, '_php_stream_stat_path');
LoadPHPFunc(@_php_stream_mkdir, '_php_stream_mkdir');
LoadPHPFunc(@_php_stream_rmdir, '_php_stream_rmdir');
LoadPHPFunc(@_php_stream_opendir, '_php_stream_opendir');
LoadPHPFunc(@_php_stream_readdir, '_php_stream_readdir');
LoadPHPFunc(@php_stream_dirent_alphasort, 'php_stream_dirent_alphasort');
LoadPHPFunc(@php_stream_dirent_alphasortr, 'php_stream_dirent_alphasortr');
LoadPHPFunc(@_php_stream_scandir, '_php_stream_scandir');
LoadPHPFunc(@_php_stream_set_option, '_php_stream_set_option');
LoadPHPFunc(@php_stream_context_free, 'php_stream_context_free');
LoadPHPFunc(@php_stream_context_alloc, 'php_stream_context_alloc');
LoadPHPFunc(@php_stream_context_get_option, 'php_stream_context_get_option');
LoadPHPFunc(@php_stream_context_set_option, 'php_stream_context_set_option');
LoadPHPFunc(@php_stream_notification_alloc, 'php_stream_notification_alloc');
LoadPHPFunc(@php_stream_notification_free, 'php_stream_notification_free');
LoadPHPFunc(@php_stream_notification_notify, 'php_stream_notification_notify');
LoadPHPFunc(@php_stream_context_set, 'php_stream_context_set');
LoadPHPFunc(@zend_llist_init, 'zend_llist_init');
LoadPHPFunc(@zend_llist_add_element, 'zend_llist_add_element');
LoadPHPFunc(@zend_llist_prepend_element, 'zend_llist_prepend_element');
LoadPHPFunc(@zend_llist_del_element, 'zend_llist_del_element');
LoadPHPFunc(@zend_llist_destroy, 'zend_llist_destroy');
LoadPHPFunc(@zend_llist_clean, 'zend_llist_clean');
LoadPHPFunc(@zend_llist_remove_tail, 'zend_llist_remove_tail');
LoadPHPFunc(@zend_llist_copy, 'zend_llist_copy');
LoadPHPFunc(@zend_llist_apply, 'zend_llist_apply');
LoadPHPFunc(@zend_llist_apply_with_del, 'zend_llist_apply_with_del');
LoadPHPFunc(@zend_llist_apply_with_argument, 'zend_llist_apply_with_argument');
LoadPHPFunc(@zend_llist_apply_with_arguments,
  'zend_llist_apply_with_arguments');
LoadPHPFunc(@zend_llist_count, 'zend_llist_count');
LoadPHPFunc(@zend_llist_sort, 'zend_llist_sort');
LoadPHPFunc(@zend_llist_get_first_ex, 'zend_llist_get_first_ex');
LoadPHPFunc(@zend_llist_get_last_ex, 'zend_llist_get_last_ex');
LoadPHPFunc(@zend_llist_get_next_ex, 'zend_llist_get_next_ex');
LoadPHPFunc(@zend_llist_get_prev_ex, 'zend_llist_get_prev_ex');
LoadPHPFunc(@php_stream_filter_register_factory,
  'php_stream_filter_register_factory');
LoadPHPFunc(@php_stream_filter_unregister_factory,
  'php_stream_filter_unregister_factory');
LoadPHPFunc(@php_stream_filter_register_factory_volatile,
  'php_stream_filter_register_factory_volatile');
LoadPHPFunc(@php_stream_filter_create, 'php_stream_filter_create');
LoadPHPFunc(@_php_stream_filter_prepend, '_php_stream_filter_prepend');
LoadPHPFunc(@php_stream_filter_prepend_ex, 'php_stream_filter_prepend_ex');
LoadPHPFunc(@_php_stream_filter_append, '_php_stream_filter_append');
LoadPHPFunc(@php_stream_filter_append_ex, 'php_stream_filter_append_ex');
LoadPHPFunc(@_php_stream_filter_flush, '_php_stream_filter_flush');
LoadPHPFunc(@php_stream_filter_remove, 'php_stream_filter_remove');
LoadPHPFunc(@php_stream_filter_free, 'php_stream_filter_free');
LoadPHPFunc(@_php_stream_filter_alloc, '_php_stream_filter_alloc');
LoadPHPFunc(@php_stream_bucket_new, 'php_stream_bucket_new');
LoadPHPFunc(@php_stream_bucket_split, 'php_stream_bucket_split');
LoadPHPFunc(@php_stream_bucket_delref, 'php_stream_bucket_delref');
LoadPHPFunc(@php_stream_bucket_prepend, 'php_stream_bucket_prepend');
LoadPHPFunc(@php_stream_bucket_append, 'php_stream_bucket_append');
LoadPHPFunc(@php_stream_bucket_unlink, 'php_stream_bucket_unlink');
LoadPHPFunc(@php_stream_bucket_make_writeable,
  'php_stream_bucket_make_writeable');
LoadPHPFunc(@zend_init_execute_data, 'zend_init_execute_data');
// LoadPHPFunc(@zend_create_generator_execute_data,
// 'zend_create_generator_execute_data');
LoadPHPFunc(@zend_execute, 'zend_execute');
LoadPHPFunc(@execute_ex, 'execute_ex');
LoadPHPFunc(@execute_internal, 'execute_internal');
LoadPHPFunc(@zend_lookup_class, 'zend_lookup_class');
LoadPHPFunc(@zend_lookup_class_ex, 'zend_lookup_class_ex');
LoadPHPFunc(@zend_get_called_scope, 'zend_get_called_scope');
LoadPHPFunc(@zend_get_this_object, 'zend_get_this_object');
LoadPHPFunc(@zend_eval_string, 'zend_eval_string');
LoadPHPFunc(@zend_eval_stringl, 'zend_eval_stringl');
LoadPHPFunc(@zend_eval_string_ex, 'zend_eval_string_ex');
LoadPHPFunc(@zend_eval_stringl_ex, 'zend_eval_stringl_ex');
LoadPHPFunc(@zval_update_constant, 'zval_update_constant');
LoadPHPFunc(@zval_update_constant_ex, 'zval_update_constant_ex');
LoadPHPFunc(@zend_vm_stack_init, 'zend_vm_stack_init');
LoadPHPFunc(@zend_vm_stack_destroy, 'zend_vm_stack_destroy');
LoadPHPFunc(@zend_vm_stack_extend, 'zend_vm_stack_extend');
LoadPHPFunc(@get_active_class_name, 'get_active_class_name');
LoadPHPFunc(@get_active_function_name, 'get_active_function_name');
LoadPHPFunc(@zend_get_executed_filename, 'zend_get_executed_filename');
LoadPHPFunc(@zend_get_executed_filename_ex, 'zend_get_executed_filename_ex');
LoadPHPFunc(@zend_get_executed_lineno, 'zend_get_executed_lineno');
LoadPHPFunc(@zend_is_executing, 'zend_is_executing');
{$IFDEF CPUX64}
LoadPHPFunc(@zend_check_internal_arg_type, 'zend_check_internal_arg_type@@24');
{$ELSE}
LoadPHPFunc(@zend_check_internal_arg_type, 'zend_check_internal_arg_type@@12');
{$ENDIF}

LoadPHPFunc(@zend_set_timeout, 'zend_set_timeout');
LoadPHPFunc(@zend_unset_timeout, 'zend_unset_timeout');
LoadPHPFunc(@zend_timeout, 'zend_timeout');
LoadPHPFunc(@zend_fetch_class, 'zend_fetch_class');
LoadPHPFunc(@zend_fetch_class_by_name, 'zend_fetch_class_by_name');
LoadPHPFunc(@zend_fetch_dimension_by_zval, 'zend_fetch_dimension_by_zval');
LoadPHPFunc(@zend_fetch_dimension_by_zval_is,
  'zend_fetch_dimension_by_zval_is');
LoadPHPFunc(@EX_VAR, 'zend_get_compiled_variable_value');
LoadPHPFunc(@zend_set_user_opcode_handler, 'zend_set_user_opcode_handler');
LoadPHPFunc(@zend_get_user_opcode_handler, 'zend_get_user_opcode_handler');
LoadPHPFunc(@zend_get_zval_ptr, 'zend_get_zval_ptr');
LoadPHPFunc(@zend_clean_and_cache_symbol_table,
  'zend_clean_and_cache_symbol_table');
LoadPHPFunc(@zend_objects_store_init, 'zend_objects_store_init');
LoadPHPFunc(@zend_objects_store_call_destructors,
  'zend_objects_store_call_destructors');
LoadPHPFunc(@zend_objects_store_mark_destructed,
  'zend_objects_store_mark_destructed');
LoadPHPFunc(@zend_objects_store_destroy, 'zend_objects_store_destroy');
LoadPHPFunc(@zend_objects_store_put, 'zend_objects_store_put');
LoadPHPFunc(@zend_objects_store_del, 'zend_objects_store_del');
LoadPHPFunc(@zend_objects_store_free, 'zend_objects_store_free');
LoadPHPFunc(@zend_object_store_set_object, 'zend_object_store_set_object');
LoadPHPFunc(@zend_object_store_ctor_failed, 'zend_object_store_ctor_failed');
LoadPHPFunc(@zend_objects_store_free_object_storage,
  'zend_objects_store_free_object_storage');
LoadPHPFunc(@zend_get_std_object_handlers, 'zend_get_std_object_handlers');
LoadPHPFunc(@zend_ptr_stack_init, 'zend_ptr_stack_init');
LoadPHPFunc(@zend_ptr_stack_init_ex, 'zend_ptr_stack_init_ex');
LoadPHPFunc(@zend_ptr_stack_n_push, 'zend_ptr_stack_n_push');
LoadPHPFunc(@zend_ptr_stack_n_pop, 'zend_ptr_stack_n_pop');
LoadPHPFunc(@zend_ptr_stack_destroy, 'zend_ptr_stack_destroy');
LoadPHPFunc(@zend_ptr_stack_apply, 'zend_ptr_stack_apply');
LoadPHPFunc(@zend_ptr_stack_clean, 'zend_ptr_stack_clean');
LoadPHPFunc(@zend_ptr_stack_num_elements, 'zend_ptr_stack_num_elements');
LoadPHPFunc(@zend_ini_startup, 'zend_ini_startup');
LoadPHPFunc(@zend_ini_shutdown, 'zend_ini_shutdown');
LoadPHPFunc(@zend_ini_global_shutdown, 'zend_ini_global_shutdown');
LoadPHPFunc(@zend_ini_deactivate, 'zend_ini_deactivate');
LoadPHPFunc(@zend_ini_dtor, 'zend_ini_dtor');
LoadPHPFunc(@zend_copy_ini_directives, 'zend_copy_ini_directives');
LoadPHPFunc(@zend_ini_sort_entries, 'zend_ini_sort_entries');
LoadPHPFunc(@zend_register_ini_entries, 'zend_register_ini_entries');
LoadPHPFunc(@zend_unregister_ini_entries, 'zend_unregister_ini_entries');
LoadPHPFunc(@zend_ini_refresh_caches, 'zend_ini_refresh_caches');
LoadPHPFunc(@zend_alter_ini_entry, 'zend_alter_ini_entry');
LoadPHPFunc(@zend_alter_ini_entry_ex, 'zend_alter_ini_entry_ex');
LoadPHPFunc(@zend_alter_ini_entry_chars, 'zend_alter_ini_entry_chars');
LoadPHPFunc(@zend_alter_ini_entry_chars_ex, 'zend_alter_ini_entry_chars_ex');
LoadPHPFunc(@zend_restore_ini_entry, 'zend_restore_ini_entry');
LoadPHPFunc(@display_ini_entries, 'display_ini_entries');
LoadPHPFunc(@zend_ini_long, 'zend_ini_long');
LoadPHPFunc(@zend_ini_double, 'zend_ini_double');
LoadPHPFunc(@zend_ini_string, 'zend_ini_string');
LoadPHPFunc(@zend_ini_string_ex, 'zend_ini_string_ex');
LoadPHPFunc(@zend_ini_register_displayer, 'zend_ini_register_displayer');
LoadPHPFunc(@zend_parse_ini_file, 'zend_parse_ini_file');
LoadPHPFunc(@zend_parse_ini_string, 'zend_parse_ini_string');
{$IFDEF CPUX64}
LoadPHPFunc(@_zend_hash_init, '_zend_hash_init@@32');
LoadPHPFunc(@_zend_hash_init_ex, '_zend_hash_init_ex@@40');
LoadPHPFunc(@zend_hash_destroy, 'zend_hash_destroy@@8');
LoadPHPFunc(@zend_hash_clean, 'zend_hash_clean@@8');
LoadPHPFunc(@zend_hash_real_init, 'zend_hash_real_init@@16');
LoadPHPFunc(@zend_hash_packed_to_hash, 'zend_hash_packed_to_hash@@8');
LoadPHPFunc(@zend_hash_to_packed, 'zend_hash_to_packed@@8');
LoadPHPFunc(@zend_hash_extend, 'zend_hash_extend@@24');
LoadPHPFunc(@_zend_hash_add_or_update, '_zend_hash_add_or_update@@32');
LoadPHPFunc(@_zend_hash_update, '_zend_hash_update@@24');
LoadPHPFunc(@_zend_hash_update_ind, '_zend_hash_update_ind@@24');
LoadPHPFunc(@_zend_hash_add, '_zend_hash_add@@24');
LoadPHPFunc(@_zend_hash_add_new, '_zend_hash_add_new@@24');
LoadPHPFunc(@_zend_hash_str_add_or_update, '_zend_hash_str_add_or_update@@40');
LoadPHPFunc(@_zend_hash_str_update, '_zend_hash_str_update@@32');
LoadPHPFunc(@_zend_hash_str_update_ind, '_zend_hash_str_update_ind@@32');
LoadPHPFunc(@_zend_hash_str_add, '_zend_hash_str_add@@32');
LoadPHPFunc(@_zend_hash_str_add_new, '_zend_hash_str_add_new@@32');
LoadPHPFunc(@_zend_hash_index_add_or_update,
  '_zend_hash_index_add_or_update@@32');
LoadPHPFunc(@_zend_hash_index_add, '_zend_hash_index_add@@24');
LoadPHPFunc(@_zend_hash_index_add_new, '_zend_hash_index_add_new@@24');
LoadPHPFunc(@_zend_hash_index_update, '_zend_hash_index_update@@24');
LoadPHPFunc(@_zend_hash_next_index_insert, '_zend_hash_next_index_insert@@16');
LoadPHPFunc(@_zend_hash_next_index_insert_new,
  '_zend_hash_next_index_insert_new@@16');
LoadPHPFunc(@zend_hash_index_add_empty_element,
  'zend_hash_index_add_empty_element@@16');
LoadPHPFunc(@zend_hash_add_empty_element, 'zend_hash_add_empty_element@@16');
LoadPHPFunc(@zend_hash_str_add_empty_element,
  'zend_hash_str_add_empty_element@@24');
LoadPHPFunc(@zend_hash_graceful_destroy, 'zend_hash_graceful_destroy@@8');
LoadPHPFunc(@zend_hash_graceful_reverse_destroy,
  'zend_hash_graceful_reverse_destroy@@8');
LoadPHPFunc(@zend_hash_apply, 'zend_hash_apply@@16');
LoadPHPFunc(@zend_hash_apply_with_argument,
  'zend_hash_apply_with_argument@@24');
{$ELSE}
LoadPHPFunc(@_zend_hash_init, '_zend_hash_init@@16');
LoadPHPFunc(@_zend_hash_init_ex, '_zend_hash_init_ex@@20');
LoadPHPFunc(@zend_hash_destroy, 'zend_hash_destroy@@4');
LoadPHPFunc(@zend_hash_clean, 'zend_hash_clean@@4');
LoadPHPFunc(@zend_hash_real_init, 'zend_hash_real_init@@8');
LoadPHPFunc(@zend_hash_packed_to_hash, 'zend_hash_packed_to_hash@@4');
LoadPHPFunc(@zend_hash_to_packed, 'zend_hash_to_packed@@4');
LoadPHPFunc(@zend_hash_extend, 'zend_hash_extend@@12');
LoadPHPFunc(@_zend_hash_add_or_update, '_zend_hash_add_or_update@@16');
LoadPHPFunc(@_zend_hash_update, '_zend_hash_update@@12');
LoadPHPFunc(@_zend_hash_update_ind, '_zend_hash_update_ind@@12');
LoadPHPFunc(@_zend_hash_add, '_zend_hash_add@@12');
LoadPHPFunc(@_zend_hash_add_new, '_zend_hash_add_new@@12');
LoadPHPFunc(@_zend_hash_str_add_or_update, '_zend_hash_str_add_or_update@@20');
LoadPHPFunc(@_zend_hash_str_update, '_zend_hash_str_update@@16');
LoadPHPFunc(@_zend_hash_str_update_ind, '_zend_hash_str_update_ind@@16');
LoadPHPFunc(@_zend_hash_str_add, '_zend_hash_str_add@@16');
LoadPHPFunc(@_zend_hash_str_add_new, '_zend_hash_str_add_new@@16');
LoadPHPFunc(@_zend_hash_index_add_or_update,
  '_zend_hash_index_add_or_update@@16');
LoadPHPFunc(@_zend_hash_index_add, '_zend_hash_index_add@@12');
LoadPHPFunc(@_zend_hash_index_add_new, '_zend_hash_index_add_new@@12');
LoadPHPFunc(@_zend_hash_index_update, '_zend_hash_index_update@@12');
LoadPHPFunc(@_zend_hash_next_index_insert, '_zend_hash_next_index_insert@@8');
LoadPHPFunc(@_zend_hash_next_index_insert_new,
  '_zend_hash_next_index_insert_new@@8');
LoadPHPFunc(@zend_hash_index_add_empty_element,
  'zend_hash_index_add_empty_element@@8');
LoadPHPFunc(@zend_hash_add_empty_element, 'zend_hash_add_empty_element@@8');
LoadPHPFunc(@zend_hash_str_add_empty_element,
  'zend_hash_str_add_empty_element@@12');
LoadPHPFunc(@zend_hash_graceful_destroy, 'zend_hash_graceful_destroy@@4');
LoadPHPFunc(@zend_hash_graceful_reverse_destroy,
  'zend_hash_graceful_reverse_destroy@@4');
LoadPHPFunc(@zend_hash_apply, 'zend_hash_apply@@8');
LoadPHPFunc(@zend_hash_apply_with_argument,
  'zend_hash_apply_with_argument@@12');
{$ENDIF}
LoadPHPFunc(@zend_hash_apply_with_arguments, 'zend_hash_apply_with_arguments');
{$IFDEF CPUX64}
LoadPHPFunc(@zend_hash_reverse_apply, 'zend_hash_reverse_apply@@16');
LoadPHPFunc(@zend_hash_del, 'zend_hash_del@@16');
LoadPHPFunc(@zend_hash_del_ind, 'zend_hash_del_ind@@16');
LoadPHPFunc(@zend_hash_str_del, 'zend_hash_str_del@@24');
LoadPHPFunc(@zend_hash_str_del_ind, 'zend_hash_str_del_ind@@24');
LoadPHPFunc(@zend_hash_index_del, 'zend_hash_index_del@@16');
LoadPHPFunc(@zend_hash_del_bucket, 'zend_hash_del_bucket@@16');
LoadPHPFunc(@zend_hash_find, 'zend_hash_find@@16');
LoadPHPFunc(@zend_hash_str_find, 'zend_hash_str_find@@24');
LoadPHPFunc(@zend_hash_index_find, 'zend_hash_index_find@@16');
LoadPHPFunc(@zend_hash_exists, 'zend_hash_exists@@16');
LoadPHPFunc(@zend_hash_str_exists, 'zend_hash_str_exists@@24');
LoadPHPFunc(@zend_hash_index_exists, 'zend_hash_index_exists@@16');
LoadPHPFunc(@zend_hash_move_forward_ex, 'zend_hash_move_forward_ex@@16');
LoadPHPFunc(@zend_hash_move_backwards_ex, 'zend_hash_move_backwards_ex@@16');
LoadPHPFunc(@zend_hash_get_current_key_ex, 'zend_hash_get_current_key_ex@@32');
LoadPHPFunc(@zend_hash_get_current_key_zval_ex,
  'zend_hash_get_current_key_zval_ex@@24');
LoadPHPFunc(@zend_hash_get_current_key_type_ex,
  'zend_hash_get_current_key_type_ex@@16');
LoadPHPFunc(@zend_hash_get_current_data_ex, 'zend_hash_get_current_data_ex@@16');
LoadPHPFunc(@zend_hash_internal_pointer_reset_ex,
  'zend_hash_internal_pointer_reset_ex@@16');
LoadPHPFunc(@zend_hash_internal_pointer_end_ex,
  'zend_hash_internal_pointer_end_ex@@16');
LoadPHPFunc(@zend_hash_copy, 'zend_hash_copy@@24');
LoadPHPFunc(@_zend_hash_merge, '_zend_hash_merge@@32');
LoadPHPFunc(@zend_hash_merge_ex, 'zend_hash_merge_ex@@40');
{$ELSE}
LoadPHPFunc(@zend_hash_reverse_apply, 'zend_hash_reverse_apply@@8');
LoadPHPFunc(@zend_hash_del, 'zend_hash_del@@8');
LoadPHPFunc(@zend_hash_del_ind, 'zend_hash_del_ind@@8');
LoadPHPFunc(@zend_hash_str_del, 'zend_hash_str_del@@12');
LoadPHPFunc(@zend_hash_str_del_ind, 'zend_hash_str_del_ind@@12');
LoadPHPFunc(@zend_hash_index_del, 'zend_hash_index_del@@8');
LoadPHPFunc(@zend_hash_del_bucket, 'zend_hash_del_bucket@@8');
LoadPHPFunc(@zend_hash_find, 'zend_hash_find@@8');
LoadPHPFunc(@zend_hash_str_find, 'zend_hash_str_find@@12');
LoadPHPFunc(@zend_hash_index_find, 'zend_hash_index_find@@8');
LoadPHPFunc(@zend_hash_exists, 'zend_hash_exists@@8');
LoadPHPFunc(@zend_hash_str_exists, 'zend_hash_str_exists@@12');
LoadPHPFunc(@zend_hash_index_exists, 'zend_hash_index_exists@@8');
LoadPHPFunc(@zend_hash_move_forward_ex, 'zend_hash_move_forward_ex@@8');
LoadPHPFunc(@zend_hash_move_backwards_ex, 'zend_hash_move_backwards_ex@@8');
LoadPHPFunc(@zend_hash_get_current_key_ex, 'zend_hash_get_current_key_ex@@16');
LoadPHPFunc(@zend_hash_get_current_key_zval_ex,
  'zend_hash_get_current_key_zval_ex@@12');
LoadPHPFunc(@zend_hash_get_current_key_type_ex,
  'zend_hash_get_current_key_type_ex@@8');
LoadPHPFunc(@zend_hash_get_current_data_ex, 'zend_hash_get_current_data_ex@@8');
LoadPHPFunc(@zend_hash_internal_pointer_reset_ex,
  'zend_hash_internal_pointer_reset_ex@@8');
LoadPHPFunc(@zend_hash_internal_pointer_end_ex,
  'zend_hash_internal_pointer_end_ex@@8');
LoadPHPFunc(@zend_hash_copy, 'zend_hash_copy@@12');
LoadPHPFunc(@_zend_hash_merge, '_zend_hash_merge@@16');
LoadPHPFunc(@zend_hash_merge_ex, 'zend_hash_merge_ex@@20');
{$ENDIF}
LoadPHPFunc(@zend_hash_bucket_swap, 'zend_hash_bucket_swap');
LoadPHPFunc(@zend_hash_bucket_renum_swap, 'zend_hash_bucket_renum_swap');
LoadPHPFunc(@zend_hash_bucket_packed_swap, 'zend_hash_bucket_packed_swap');
LoadPHPFunc(@zend_hash_compare, 'zend_hash_compare');
{$IFDEF CPUX64}
LoadPHPFunc(@zend_hash_sort_ex, 'zend_hash_sort_ex@@32');
LoadPHPFunc(@zend_hash_minmax, 'zend_hash_minmax@@24');
LoadPHPFunc(@zend_hash_rehash, 'zend_hash_rehash@@8');
{$ELSE}
LoadPHPFunc(@zend_hash_sort_ex, 'zend_hash_sort_ex@@16');
LoadPHPFunc(@zend_hash_minmax, 'zend_hash_minmax@@12');
LoadPHPFunc(@zend_hash_rehash, 'zend_hash_rehash@@4');
{$ENDIF}
LoadPHPFunc(@zend_array_count, 'zend_array_count');
{$IFDEF CPUX64}
LoadPHPFunc(@zend_array_dup, 'zend_array_dup@@8');
LoadPHPFunc(@zend_array_destroy, 'zend_array_destroy@@8');
LoadPHPFunc(@zend_symtable_clean, 'zend_symtable_clean@@8');
LoadPHPFunc(@_zend_handle_numeric_str_ex, '_zend_handle_numeric_str_ex@@24');
LoadPHPFunc(@zend_hash_iterator_add, 'zend_hash_iterator_add@@16');
LoadPHPFunc(@zend_hash_iterator_pos, 'zend_hash_iterator_pos@@16');
LoadPHPFunc(@zend_hash_iterator_pos_ex, 'zend_hash_iterator_pos_ex@@16');
LoadPHPFunc(@zend_hash_iterator_del, 'zend_hash_iterator_del@@8');
LoadPHPFunc(@zend_hash_iterators_lower_pos, 'zend_hash_iterators_lower_pos@@16');
LoadPHPFunc(@_zend_hash_iterators_update, '_zend_hash_iterators_update@@24');

LoadPHPFunc(@smart_str_erealloc, 'smart_str_erealloc@@16');
LoadPHPFunc(@smart_str_realloc, 'smart_str_realloc@@16');

LoadPHPFunc(@add_function, 'add_function@@24');
LoadPHPFunc(@sub_function, 'sub_function@@24');
LoadPHPFunc(@mul_function, 'mul_function@@24');
LoadPHPFunc(@pow_function, 'pow_function@@24');
LoadPHPFunc(@div_function, 'div_function@@24');
LoadPHPFunc(@mod_function, 'mod_function@@24');
LoadPHPFunc(@boolean_xor_function, 'boolean_xor_function@@24');
LoadPHPFunc(@boolean_not_function, 'boolean_not_function@@16');
LoadPHPFunc(@bitwise_not_function, 'bitwise_not_function@@16');
LoadPHPFunc(@bitwise_or_function, 'bitwise_or_function@@24');
LoadPHPFunc(@bitwise_and_function, 'bitwise_and_function@@24');
LoadPHPFunc(@bitwise_xor_function, 'bitwise_xor_function@@24');
LoadPHPFunc(@shift_left_function, 'shift_left_function@@24');
LoadPHPFunc(@shift_right_function, 'shift_right_function@@24');
LoadPHPFunc(@concat_function, 'concat_function@@24');
LoadPHPFunc(@zend_is_identical, 'zend_is_identical@@16');
LoadPHPFunc(@is_equal_function, 'is_equal_function@@24');
LoadPHPFunc(@is_identical_function, 'is_identical_function@@24');
LoadPHPFunc(@is_not_identical_function, 'is_not_identical_function@@24');
LoadPHPFunc(@is_not_equal_function, 'is_not_equal_function@@24');
LoadPHPFunc(@is_smaller_function, 'is_smaller_function@@24');
LoadPHPFunc(@is_smaller_or_equal_function, 'is_smaller_or_equal_function@@24');
LoadPHPFunc(@instanceof_function_ex, 'instanceof_function_ex@@24');
LoadPHPFunc(@instanceof_function, 'instanceof_function@@16');
LoadPHPFunc(@_is_numeric_string_ex, '_is_numeric_string_ex@@48');
LoadPHPFunc(@zend_memnstr_ex, 'zend_memnstr_ex@@32');
LoadPHPFunc(@zend_memnrstr_ex, 'zend_memnrstr_ex@@32');
LoadPHPFunc(@zend_dval_to_lval_slow, 'zend_dval_to_lval_slow@@8');
LoadPHPFunc(@is_numeric_str_function, 'is_numeric_str_function@@24');
LoadPHPFunc(@increment_function, 'increment_function@@8');
LoadPHPFunc(@decrement_function, 'decrement_function@@8');
LoadPHPFunc(@convert_scalar_to_number, 'convert_scalar_to_number@@8');
LoadPHPFunc(@_convert_to_cstring, '_convert_to_cstring@@8');
LoadPHPFunc(@_convert_to_string, '_convert_to_string@@8');
LoadPHPFunc(@convert_to_long, 'convert_to_long@@8');
LoadPHPFunc(@convert_to_double, 'convert_to_double@@8');
LoadPHPFunc(@convert_to_long_base, 'convert_to_long_base@@16');
LoadPHPFunc(@convert_to_null, 'convert_to_null@@8');
LoadPHPFunc(@convert_to_boolean, 'convert_to_boolean@@8');
LoadPHPFunc(@convert_to_array, 'convert_to_array@@8');
LoadPHPFunc(@convert_to_object, 'convert_to_object@@8');
{$ELSE}
LoadPHPFunc(@zend_array_dup, 'zend_array_dup@@4');
LoadPHPFunc(@zend_array_destroy, 'zend_array_destroy@@4');
LoadPHPFunc(@zend_symtable_clean, 'zend_symtable_clean@@4');
LoadPHPFunc(@_zend_handle_numeric_str_ex, '_zend_handle_numeric_str_ex@@12');
LoadPHPFunc(@zend_hash_iterator_add, 'zend_hash_iterator_add@@8');
LoadPHPFunc(@zend_hash_iterator_pos, 'zend_hash_iterator_pos@@8');
LoadPHPFunc(@zend_hash_iterator_pos_ex, 'zend_hash_iterator_pos_ex@@8');
LoadPHPFunc(@zend_hash_iterator_del, 'zend_hash_iterator_del@@4');
LoadPHPFunc(@zend_hash_iterators_lower_pos, 'zend_hash_iterators_lower_pos@@8');
LoadPHPFunc(@_zend_hash_iterators_update, '_zend_hash_iterators_update@@12');

LoadPHPFunc(@smart_str_erealloc, 'smart_str_erealloc@@8');
LoadPHPFunc(@smart_str_realloc, 'smart_str_realloc@@8');

LoadPHPFunc(@add_function, 'add_function@@12');
LoadPHPFunc(@sub_function, 'sub_function@@12');
LoadPHPFunc(@mul_function, 'mul_function@@12');
LoadPHPFunc(@pow_function, 'pow_function@@12');
LoadPHPFunc(@div_function, 'div_function@@12');
LoadPHPFunc(@mod_function, 'mod_function@@12');
LoadPHPFunc(@boolean_xor_function, 'boolean_xor_function@@12');
LoadPHPFunc(@boolean_not_function, 'boolean_not_function@@8');
LoadPHPFunc(@bitwise_not_function, 'bitwise_not_function@@8');
LoadPHPFunc(@bitwise_or_function, 'bitwise_or_function@@12');
LoadPHPFunc(@bitwise_and_function, 'bitwise_and_function@@12');
LoadPHPFunc(@bitwise_xor_function, 'bitwise_xor_function@@12');
LoadPHPFunc(@shift_left_function, 'shift_left_function@@12');
LoadPHPFunc(@shift_right_function, 'shift_right_function@@12');
LoadPHPFunc(@concat_function, 'concat_function@@12');
LoadPHPFunc(@zend_is_identical, 'zend_is_identical@@8');
LoadPHPFunc(@is_equal_function, 'is_equal_function@@12');
LoadPHPFunc(@is_identical_function, 'is_identical_function@@12');
LoadPHPFunc(@is_not_identical_function, 'is_not_identical_function@@12');
LoadPHPFunc(@is_not_equal_function, 'is_not_equal_function@@12');
LoadPHPFunc(@is_smaller_function, 'is_smaller_function@@12');
LoadPHPFunc(@is_smaller_or_equal_function, 'is_smaller_or_equal_function@@12');
LoadPHPFunc(@instanceof_function_ex, 'instanceof_function_ex@@12');
LoadPHPFunc(@instanceof_function, 'instanceof_function@@8');
LoadPHPFunc(@_is_numeric_string_ex, '_is_numeric_string_ex@@24');
LoadPHPFunc(@zend_memnstr_ex, 'zend_memnstr_ex@@16');
LoadPHPFunc(@zend_memnrstr_ex, 'zend_memnrstr_ex@@16');
LoadPHPFunc(@zend_dval_to_lval_slow, 'zend_dval_to_lval_slow@@8');
LoadPHPFunc(@is_numeric_str_function, 'is_numeric_str_function@@12');
LoadPHPFunc(@increment_function, 'increment_function@@4');
LoadPHPFunc(@decrement_function, 'decrement_function@@4');
LoadPHPFunc(@convert_scalar_to_number, 'convert_scalar_to_number@@4');
LoadPHPFunc(@_convert_to_cstring, '_convert_to_cstring@@4');
LoadPHPFunc(@_convert_to_string, '_convert_to_string@@4');
LoadPHPFunc(@convert_to_long, 'convert_to_long@@4');
LoadPHPFunc(@convert_to_double, 'convert_to_double@@4');
LoadPHPFunc(@convert_to_long_base, 'convert_to_long_base@@8');
LoadPHPFunc(@convert_to_null, 'convert_to_null@@4');
LoadPHPFunc(@convert_to_boolean, 'convert_to_boolean@@4');
LoadPHPFunc(@convert_to_array, 'convert_to_array@@4');
LoadPHPFunc(@convert_to_object, 'convert_to_object@@4');
{$ENDIF}
LoadPHPFunc(@multi_convert_to_long_ex, 'multi_convert_to_long_ex');
LoadPHPFunc(@multi_convert_to_double_ex, 'multi_convert_to_double_ex');
LoadPHPFunc(@multi_convert_to_string_ex, 'multi_convert_to_string_ex');
{$IFDEF CPUX64}
LoadPHPFunc(@_zval_get_long_func, '_zval_get_long_func@@8');
LoadPHPFunc(@_zval_get_double_func, '_zval_get_double_func@@8');
LoadPHPFunc(@_zval_get_string_func, '_zval_get_string_func@@8');
LoadPHPFunc(@zend_is_true, 'zend_is_true@@8');
LoadPHPFunc(@zend_object_is_true, 'zend_object_is_true@@8');
LoadPHPFunc(@compare_function, 'compare_function@@24');
LoadPHPFunc(@numeric_compare_function, 'numeric_compare_function@@16');
LoadPHPFunc(@string_compare_function_ex, 'string_compare_function_ex@@24');
LoadPHPFunc(@string_compare_function, 'string_compare_function@@16');
LoadPHPFunc(@string_case_compare_function, 'string_case_compare_function@@16');
LoadPHPFunc(@string_locale_compare_function,
  'string_locale_compare_function@@16');
LoadPHPFunc(@zend_str_tolower, 'zend_str_tolower@@16');
LoadPHPFunc(@zend_str_tolower_copy, 'zend_str_tolower_copy@@24');
LoadPHPFunc(@zend_str_tolower_dup, 'zend_str_tolower_dup@@16');
LoadPHPFunc(@zend_str_tolower_dup_ex, 'zend_str_tolower_dup_ex@@16');
LoadPHPFunc(@zend_string_tolower, 'zend_string_tolower@@8');
LoadPHPFunc(@zend_binary_zval_strcmp, 'zend_binary_zval_strcmp@@16');
LoadPHPFunc(@zend_binary_zval_strncmp, 'zend_binary_zval_strncmp@@24');
LoadPHPFunc(@zend_binary_zval_strcasecmp, 'zend_binary_zval_strcasecmp@@16');
LoadPHPFunc(@zend_binary_zval_strncasecmp, 'zend_binary_zval_strncasecmp@@24');
LoadPHPFunc(@zend_binary_strcmp, 'zend_binary_strcmp@@32');
LoadPHPFunc(@zend_binary_strncmp, 'zend_binary_strncmp@@40');
LoadPHPFunc(@zend_binary_strcasecmp, 'zend_binary_strcasecmp@@32');
LoadPHPFunc(@zend_binary_strncasecmp, 'zend_binary_strncasecmp@@40');
LoadPHPFunc(@zend_binary_strcasecmp_l, 'zend_binary_strcasecmp_l@@32');
LoadPHPFunc(@zend_binary_strncasecmp_l, 'zend_binary_strncasecmp_l@@40');
LoadPHPFunc(@zendi_smart_strcmp, 'zendi_smart_strcmp@@16');
LoadPHPFunc(@zend_compare_symbol_tables, 'zend_compare_symbol_tables@@16');
LoadPHPFunc(@zend_compare_arrays, 'zend_compare_arrays@@16');
LoadPHPFunc(@zend_compare_objects, 'zend_compare_objects@@16');
LoadPHPFunc(@zend_atoi, 'zend_atoi@@16');
LoadPHPFunc(@zend_atol, 'zend_atol@@16');
LoadPHPFunc(@zend_locale_sprintf_double, 'zend_locale_sprintf_double@@8');
LoadPHPFunc(@zend_long_to_str, 'zend_long_to_str@@8');
{$ELSE}
LoadPHPFunc(@_zval_get_long_func, '_zval_get_long_func@@4');
LoadPHPFunc(@_zval_get_double_func, '_zval_get_double_func@@4');
LoadPHPFunc(@_zval_get_string_func, '_zval_get_string_func@@4');
LoadPHPFunc(@zend_is_true, 'zend_is_true@@4');
LoadPHPFunc(@zend_object_is_true, 'zend_object_is_true@@4');
LoadPHPFunc(@compare_function, 'compare_function@@12');
LoadPHPFunc(@numeric_compare_function, 'numeric_compare_function@@8');
LoadPHPFunc(@string_compare_function_ex, 'string_compare_function_ex@@12');
LoadPHPFunc(@string_compare_function, 'string_compare_function@@8');
LoadPHPFunc(@string_case_compare_function, 'string_case_compare_function@@8');
LoadPHPFunc(@string_locale_compare_function,
  'string_locale_compare_function@@8');
LoadPHPFunc(@zend_str_tolower, 'zend_str_tolower@@8');
LoadPHPFunc(@zend_str_tolower_copy, 'zend_str_tolower_copy@@12');
LoadPHPFunc(@zend_str_tolower_dup, 'zend_str_tolower_dup@@8');
LoadPHPFunc(@zend_str_tolower_dup_ex, 'zend_str_tolower_dup_ex@@8');
LoadPHPFunc(@zend_string_tolower, 'zend_string_tolower@@4');
LoadPHPFunc(@zend_binary_zval_strcmp, 'zend_binary_zval_strcmp@@8');
LoadPHPFunc(@zend_binary_zval_strncmp, 'zend_binary_zval_strncmp@@12');
LoadPHPFunc(@zend_binary_zval_strcasecmp, 'zend_binary_zval_strcasecmp@@8');
LoadPHPFunc(@zend_binary_zval_strncasecmp, 'zend_binary_zval_strncasecmp@@12');
LoadPHPFunc(@zend_binary_strcmp, 'zend_binary_strcmp@@16');
LoadPHPFunc(@zend_binary_strncmp, 'zend_binary_strncmp@@20');
LoadPHPFunc(@zend_binary_strcasecmp, 'zend_binary_strcasecmp@@16');
LoadPHPFunc(@zend_binary_strncasecmp, 'zend_binary_strncasecmp@@20');
LoadPHPFunc(@zend_binary_strcasecmp_l, 'zend_binary_strcasecmp_l@@16');
LoadPHPFunc(@zend_binary_strncasecmp_l, 'zend_binary_strncasecmp_l@@20');
LoadPHPFunc(@zendi_smart_strcmp, 'zendi_smart_strcmp@@8');
LoadPHPFunc(@zend_compare_symbol_tables, 'zend_compare_symbol_tables@@8');
LoadPHPFunc(@zend_compare_arrays, 'zend_compare_arrays@@8');
LoadPHPFunc(@zend_compare_objects, 'zend_compare_objects@@8');
LoadPHPFunc(@zend_atoi, 'zend_atoi@@8');
LoadPHPFunc(@zend_atol, 'zend_atol@@8');
LoadPHPFunc(@zend_locale_sprintf_double, 'zend_locale_sprintf_double@@4');
LoadPHPFunc(@zend_long_to_str, 'zend_long_to_str@@4');
{$ENDIF}
LoadPHPFunc(_TestCreate, '_TestCreate');

LoadPHPFunc(@zend_hash_index_find2, 'zend_hash_index_find2');
LoadPHPFunc(@zend_hash_index_findZval, 'zend_hash_index_findZval');
LoadPHPFunc(@zend_symtable_findTest, 'zend_symtable_findTest');
LoadPHPFunc(@zend_hash_index_existsZval, 'zend_hash_index_existsZval');

if LoadPHPFunc(@ZvalSetPChar, 'ZvalSetPChar', false) then
  ZvalSetStr := @ZvalSetStrHk
Else
  ZvalSetStr := @ZvalSetStrDef;

LoadPHPFunc(@read_property22, 'read_property22');

LoadPHPFunc(@lookup_class_ce, 'lookup_class_ce');
LoadPHPFunc(@isset_property, 'isset_property');
LoadPHPFunc(@class_exists, 'class_exists');
LoadPHPFunc(@class_exists2, 'class_exists2');
LoadPHPFunc(@update_property_zval, 'update_property_zval');
LoadPHPFunc(@__create_php_object, '__create_php_object');
LoadPHPFunc(@__call_function, '__call_function');
LoadPHPFunc(@safe_emalloc2, 'safe_emalloc2');
LoadPHPFunc(@ZvalEmalloc, 'ZvalEmalloc');

LoadPHPFunc(@pZVAL_NEW_REF, 'pZVAL_NEW_REF');
LoadPHPFunc(@NewPzval, 'NewPzval');
LoadPHPFunc(@CreateCll, 'CreateCll');

LoadPHPFunc(@PHPInitSetValue, 'PHPInitSetValue');
End;

// call_user_function := GetProcAddress(phpHandle, 'call_user_function');
end.
