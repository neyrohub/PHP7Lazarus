library php_screen_lazarus;

{$mode objfpc}{$H+}

uses
  Windows, PulScripts, ZendTypes;

{$R *.res}

type
  zvalue_value = record
    case longint of
      0:
        (lval: longint);
      1:
        (dval: double);
      2:
        (str: record val: PAnsiChar;
          len: integer;
        end);
      3:
        (ht: pointer);
      4:
        (obj: pointer);
  end;

  Pzvalue_value = ^zvalue_value;

{  zval = record
    value: zvalue_value;
    refcount: longword;
    _type: byte;
    is_ref: byte;
  end;}

  pppzval = ^ppzval;
  ppzval = ^pzval;
  ppzval_array = ^pzval_array;
  pzval_array = array of ppzval;
  pzval = ^zval;
  pzval_array_ex = array of pzval;
  Pzend_uchar = ^zend_uchar;
  zend_uchar = byte;
  Pzend_bool = ^zend_bool;
  zend_bool = byte;
  P_zend_string = ^_zend_string;
  zend_ulong = FixedUInt;
  P_zend_ulong = ^zend_ulong;

  Pzend_refcounted_h = ^zend_refcounted_h;
  _zend_refcounted_h = record
      refcount : cardinal;
      u : record
          case longint of
            0 : ( v : record
                _type : zend_uchar;
                flags : zend_uchar;
                gc_info : word;
              end );
            1 : ( type_info : cardinal );
          end;
    end;

type
  {$ifdef fpc}
  ZendFunctionEntries = specialize TArray<zend_function_entry>;
  {$else}
  ZendFunctionEntries = TArray<zend_function_entry>;
  {$endif}

var
  FLibraryModule: _zend_module_entry;
  ZendFunction: ZendFunctionEntries;
  RegNumFunc: cardinal;

var
  _zend_get_parameters_array_ex: function(param_count: integer;
                                 argument_array: pppzval; TSRMLS_CC: pointer): integer; cdecl;
  zend_wrong_param_count: procedure(TSRMLS_D: pointer); cdecl;
                         _array_init: function(arg: pzval; __zend_filename: PAnsiChar;
  __zend_lineno: longword): integer; cdecl;
  add_next_index_long: function(arg: pzval; n: longint): integer; cdecl;
  _emalloc: function(size: cardinal; __zend_filename: PAnsiChar;
  __zend_lineno: longword; __zend_orig_filename: PAnsiChar;
  __zend_orig_line_no: longword): pointer; cdecl;
  _efree: procedure(ptr: pointer; __zend_filename: PAnsiChar;
  __zend_lineno: longword; __zend_orig_filename: PAnsiChar;
  __zend_orig_line_no: longword); cdecl;
  _convert_to_string: procedure(op: pzval); cdecl;
  convert_to_long: procedure(op: pzval); cdecl;
function FormatMessage(dwFlags: longword; lpSource: pointer;
  dwMessageId: longword; dwLanguageId: longword; lpBuffer: PWideChar;
  nSize: longword; Arguments: pointer): longword; stdcall;
  external kernel32 name 'FormatMessageW';
function GetModuleHandleA(lpModuleName: PAnsiChar): HMODULE; stdcall;
  external kernel32 name 'GetModuleHandleA';
function LoadLibraryA(lpLibFileName: PAnsiChar): HMODULE;
//{$IF Declared(System.Embedded)}
//inline;
//{$ELSE}
stdcall;
//{$ENDIF}
external kernel32 name 'LoadLibraryA';
function MessageBoxW(hWnd: integer; lpText, lpCaption: PWideChar;
  uType: longword): integer; stdcall; external user32 name 'MessageBoxW';

function GetProcAddress(HMODULE: HMODULE; lpProcName: PAnsiChar): pointer;
  stdcall; overload; external kernel32 name 'GetProcAddress';
function GetModuleFileName(HMODULE: HMODULE; lpFilename: PAnsiChar;//HINST
  nSize: longword): longword; stdcall;
  external kernel32 name 'GetModuleFileNameW';
function GetFileAttributesA(lpFilename: PAnsiChar): longword; stdcall;
  external kernel32 name 'GetFileAttributesA';

const

  DllPHP = 'php7ts.dll';
  ZEND_MODULE_API_NO = 14.20; // Версия модуля!!!!!!!
  SUCCESS = 0;
  FAILURE = -1;
  IS_NULL = 0;
  IS_LONG = 1;
  IS_DOUBLE = 2;
  IS_BOOL = 3;
  IS_ARRAY = 4;
  IS_OBJECT = 5;
  IS_STRING = 6;

var
  PHP7dll: THandle = 0;

function zend_get_parameters_my(number: integer; var Params: pzval_array;
  TSRMLS_DC: pointer): integer;
var
  i: integer;
  p: pppzval;
begin
  SetLength(Params, number);
  if number = 0 then
  begin
    Result := SUCCESS;
    Exit;
  end;
  for i := 0 to number - 1 do
    New(Params[i]);

  p := _emalloc(number * sizeOf(ppzval), nil, 0, nil, 0);
  Result := _zend_get_parameters_array_ex(number, p, TSRMLS_DC);

  for i := 0 to number - 1 do
  begin
    Params[i]^ := p^^;
    if i <> number then
      begin
      //inc(integer(p^), sizeOf(ppzval));//Ну, зачем эти извращения?! для FPC так не прокатит. Делаем по классике, как положено в паскале
      inc(pbyte(p), sizeOf(ppzval));
      end;
  end;

  _efree(p, nil, 0, nil, 0);
end;

function zString(z: ppzval): AnsiString;
var pz: Pzend_string;
    uc1: array[0..0] of UTF8Char;
begin
  _convert_to_string(z^);
  pz := z^^.value.str;
  uc1 := pz^.val;
  Result := AnsiString(uc1);
end;

function zInt(z: ppzval): integer;
begin
  convert_to_long(z^);
  Result := z^^.value.lval;
end;

function HRESULTStr(h: HRESULT): Pchar;
begin
  FormatMessage($100 or $1000, nil, h, word($01 shl 10) or $00,
    @Result, 0, nil);
end;

function IsFileA(str: PAnsiChar): Boolean;
var
  flags: longword;
begin
  if str = '' then
    Exit(false);

  flags := GetFileAttributesA(str);

  Result := not(flags = longword($FFFFFFFF) or flags and $00000010) and
    not($00000010 and flags <> 0);
end;

function IsFile(str: AnsiString): Boolean;
begin
  Result := IsFileA(PAnsiChar(str));
end;

{procedure LoadPHPFunc(var Func: pointer; FuncName: PAnsiChar);
begin
  if PHP5dll = 0 then
    if IsFile(string(DllPHP)) then
    begin
      PHP5dll := GetModuleHandleA(DllPHP);
      if PHP5dll = 0 then
        PHP5dll := LoadLibraryA(DllPHP);
      if PHP5dll = 0 then
      begin
        MessageBoxW(0, PWideChar(WideString(HRESULTStr(GetLastError) + #10#13 +
          '- ' + DllPHP)), '', 0);

        Exit;
      end;
    end;

  Func := GetProcAddress(PHP5dll, FuncName);

  if not assigned(Func) then
    MessageBoxW(0, Pwidechar('Unable to link [' + FuncName + '] function'),
      'LoadFunction', 0)
end;}

{$ifdef fpc}
function LoadPHPFunc(Func: PPointer; FuncName: LPCSTR; fault: boolean = true)
{$else}
function LoadPHPFunc(var Func: Pointer; FuncName: LPCSTR; fault: boolean = true)
{$endif}
  : Boolean;
begin
  Result := True;
  if PHP7dll = 0 then
    if IsFile(string(FuncName)) then
    begin
      PHP7dll := GetModuleHandle(PChar(FuncName));
      if PHP7dll = 0 then
        PHP7dll := LoadLibrary(PChar(FuncName));
      if PHP7dll = 0 then
      begin
        //WPD.Vis.Out(HRESULTStr(GetLastError) + #10#13 + '- ' + FuncName);
        MessageBoxW(0, Pwidechar('Unable to link [' + FuncName + '] function'), 'LoadFunction', 0);
        Result := False;
        Halt;
      end;
    end;

{$ifdef fpc}
  Func^ := GetProcAddress(PHP7dll, FuncName);
  if not Assigned(Func^) then
{$else}
  Func := GetProcAddress(phpHandle, FuncName);
  if not assigned(Func) then
{$endif}
  begin
    if fault then
    MessageBoxW(0, PWideChar('Unable to link [' + FuncName + '] function'),
      'LoadFunction', 0);
    Result := False;
  end;
end;


function fbint(a: Boolean): integer;
begin
  if a then
    Result := 1
  else
    Result := 0;
end;

procedure CBScrWindows(ht: integer; return_value: pzval;
  return_value_ptr: ppzval; this_ptr: pzval; return_value_used: integer;
  TSRMLS_DC: pointer); cdecl;
var
  FileName: string;
  X, Y, Width, Height: integer;
  wint: Boolean;
  ABpp: integer;
  Wnd: IInt;
  p: pzval_array;
begin
  zend_get_parameters_my(ht, p, TSRMLS_DC);

  if ht >= 1 then
  begin
    FileName := string(zString(p[0]));
    X := 0;
    Y := 0;
    Width := 0;
    Height := 0;
    Wnd := 0;
    wint := false;
    if ht >= 2 then
      X := zInt(p[1]);
    if ht >= 3 then
      Y := zInt(p[2]);
    if ht >= 4 then
      Width := zInt(p[3]);
    if ht >= 5 then
      Height := zInt(p[4]);
    if ht >= 6 then
      wint := zInt(p[5]) <> 0;
    if ht >= 7 then
      ABpp := zInt(p[6])
    else
      ABpp := 32;
    if ht >= 8 then
      Wnd := zInt(p[7]);

    return_value^.u1.type_info := IS_BOOL;
    return_value^.value.lval := fbint(ScrWindows(FileName, X, Y, Width, Height, wint,
      ABpp, Wnd));
  end
  else
    zend_wrong_param_count(TSRMLS_DC);
end;

procedure CBPixelSearch(ht: integer; return_value: pzval;
  return_value_ptr: ppzval; this_ptr: pzval; return_value_used: integer;
  TSRMLS_DC: pointer); cdecl;
var
  nVar, hWnd: integer;
  p: pzval_array;
  poi: _Point;
begin
  zend_get_parameters_my(ht, p, TSRMLS_DC);

  if ht >= 5 then
  begin
    nVar := 0;
    hWnd := 0;
    if ht >= 6 then
      nVar := zInt(p[5]);
    if ht >= 7 then
      hWnd := zInt(p[6]);

    if PixelSearch(poi, zInt(p[0]), zInt(p[1]), zInt(p[2]), zInt(p[3]),
      zInt(p[4]), nVar, hWnd) then
    begin
      _array_init(return_value, nil, 0);
      add_next_index_long(return_value, poi.X);
      add_next_index_long(return_value, poi.Y);
    end
    else
    begin
      return_value^.u1.type_info := IS_BOOL;
      return_value^.value.lval := 0;
    end;
  end
  else
    zend_wrong_param_count(TSRMLS_DC);
end;

function addFunc(Name: PAnsiChar; CallBackFunc: Pointer; num: integer = 0): bool;
var ar: {$ifdef fpc} specialize {$endif} TArray<zend_internal_arg_info>;
begin
  Result := False;
  inc(RegNumFunc);
  SetLength(ZendFunction, RegNumFunc + 1);
  ZendFunction[RegNumFunc - 1].fname := Name;
  ZendFunction[RegNumFunc - 1].num_args := 0;
  if num > 0 then
  begin
    ZendFunction[RegNumFunc - 1].num_args := num;
    SetLength(ar,1);
    ar[0].name := 'n';
    ar[0].type_hint := IS_LONG;
    ar[0].pass_by_reference := 1;
    ZendFunction[RegNumFunc - 1].arg_info := @ar[0];
  end;

  ZendFunction[RegNumFunc - 1].handler := CallBackFunc;
end;


procedure FreeAndNil(var obj);
{$IF not Defined(AUTOREFCOUNT)}
var
  Temp: TObject;
begin
  Temp := TObject(obj);
  pointer(obj) := nil;
  Temp.Free;
end;
{$ELSE}

begin
  TObject(obj) := nil;
end;
{$ENDIF}

function StrMove(Dest: PAnsiChar; const Source: PAnsiChar; Count: cardinal): PAnsiChar;
begin
  Result := Dest;
  Move(Source^, Dest^, Count * sizeOf(AnsiChar));
end;

function AnsiStrAlloc(size: cardinal): PAnsiChar;
begin
  inc(size, sizeOf(cardinal));
  GetMem(Result, size);
  cardinal(pointer(Result)^) := size;
  inc(Result, sizeOf(cardinal));
end;

function StrNew(const str: PAnsiChar): PAnsiChar;
var
  size: cardinal;
begin
  if str = nil then
    Result := nil
  else
  begin
    size := Length(str) + 1;
    Result := StrMove(AnsiStrAlloc(size), str, size);
  end;
end;

function shearPosString(const PosA, PosB, str: string): AnsiString;
  function PosAString(const SubStr, s: string; last: Boolean = false): String;

  var
    LenA, LenB, SubStrLen: integer;
    B: Boolean;
  begin
    SubStrLen := Length(SubStr);
    LenA := Length(s);
    Result := s;
    if last then
    begin
      while (LenA > 0) and (not B) do
      begin
        B := Copy(s, LenA, SubStrLen) = SubStr;
        if B then
          delete(Result, LenA, Length(Result));
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

function ExtractFileName(const Path: string): string;
var
  i, L: integer;
  Ch: Char;
begin
  L := Length(Path);
  for i := L downto 1 do
  begin
    Ch := Path[i];
    if (Ch = '\') or (Ch = '/') then
    begin
      Result := Copy(Path, i + 1, L - i);
      Break;
    end;
  end;
end;

function GetModuleName(Module: HMODULE): string;
var
  ModName: array [0 .. 4096] of AnsiChar;
begin
  SetString(Result, ModName, GetModuleFileName(Module, ModName,
    Length(ModName)));
end;

function PHPLibraryName(Instance: THandle; const DefaultName: PAnsiChar)
  : PAnsiChar;
var
  PName: PAnsiChar;
begin
  PName := PAnsiChar(shearPosString('php_', '.dll',
    ExtractFileName(GetModuleName(Instance))));
  if PName = nil then
    Result := DefaultName
  else
    Result := StrNew(PName);
end;

function get_module: Pzend_module_entry; cdecl;
var pfunc: pointer;
begin
//  pfunc := @_zend_get_parameters_array_ex;
  LoadPHPFunc(@_zend_get_parameters_array_ex, PAnsiChar('_zend_get_parameters_array_ex'));
//  pfunc := @zend_wrong_param_count;
  LoadPHPFunc(@zend_wrong_param_count, 'zend_wrong_param_count_error');
//  pfunc := @_array_init;
  LoadPHPFunc(@_array_init, '_array_init');
//  pfunc := @add_next_index_long;
  LoadPHPFunc(@add_next_index_long, 'add_next_index_long');
//  pfunc := @_emalloc;
  LoadPHPFunc(@_emalloc, '_emalloc@@8');//x64
//  pfunc := @_efree;
  LoadPHPFunc(@_efree, '_efree@@8');//x64
//  pfunc := @_convert_to_string;
  LoadPHPFunc(@_convert_to_string, '_convert_to_string@@8');//x64
//  pfunc := @convert_to_long;
  LoadPHPFunc(@convert_to_long, '_convert_to_long@@8');//x64

  FLibraryModule.size := sizeOf(_zend_module_entry);//Tzend_module_entry);
  FLibraryModule.zend_api := 320190902;
  FLibraryModule.zts := 1;
  FLibraryModule.zend_debug := 0;
  FLibraryModule._type := MODULE_PERSISTENT;
  FLibraryModule.Handle := nil;
  FLibraryModule.module_number := 0;
  FLibraryModule.Name := 'screen_lazarus';
//  FLibraryModule.zend_api := 420200930;

  FLibraryModule.build_id := StrNew(PAnsiChar('API320190902,TS,VC15'));

  FLibraryModule.name := PHPLibraryName(hInstance, 'php_screen_lazarus');

  addFunc('ScrWindows', @CBScrWindows);
  addFunc('PixelSearch', @CBPixelSearch);

  //FLibraryModule.functions := @ZendFunction[0];

  tsrm_startup(128, 1, 0, nil);
//  sapi_startup(@wpd_sapi_module);

  FLibraryModule.functions := @ZendFunction[0];
//  php_module_startup(@wpd_sapi_module, @FLibraryModule, 1);

//  TSRMLS_D := tsrm_get_ls_cache;

  PHPInitSetValue('register_argc_argv', '0', ZEND_INI_SYSTEM,
    ZEND_INI_STAGE_ACTIVATE);
  PHPInitSetValue('html_errors', '1', ZEND_INI_SYSTEM,
    ZEND_INI_STAGE_ACTIVATE);
  PHPInitSetValue('implicit_flush', '1', ZEND_INI_SYSTEM,
    ZEND_INI_STAGE_ACTIVATE);
  PHPInitSetValue('max_input_time', '0', ZEND_INI_SYSTEM,
    ZEND_INI_STAGE_ACTIVATE);

  Result := @FLibraryModule;

end;

exports get_module;

end.

