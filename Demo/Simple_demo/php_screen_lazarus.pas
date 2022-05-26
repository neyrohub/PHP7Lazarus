library php_screen_lazarus;

{$mode objfpc}{$H+}

uses
  Windows, SysUtils, Classes, {PulScripts,} WPD.Zend.Types7, WPD.Php7;

type
  {$ifdef fpc}
  ZendFunctionEntries = specialize TArray<zend_function_entry>;
  {$else}
  ZendFunctionEntries = TArray<zend_function_entry>;
  {$endif}

var
  FLibraryModule: _zend_module_entry;
  ArrZendFunctionEnt: ZendFunctionEntries;
  RegNumFunc: cardinal;

var
  //вот же заморочки... Оказывается расширение это не самостоятельный объект!
  //ему еще необходимо импортировать некоторые функции из основной
  php_info_print_table_start: procedure; cdecl;
  php_info_print_table_row : procedure (n2 : integer; c1, c2 : pAnsiChar); cdecl;
  php_info_print_table_end: procedure (); cdecl;
//  CallZvalGetArgs: function(Count: Integer; Args: ppzval): Integer;cdecl varargs;
  {$ifdef fpc}
  arr_arg_info: specialize TArray<zend_internal_arg_info>;
  {$else}
  arr_arg_info: TArray<zend_internal_arg_info>;
  {$endif}

const

{$ifdef fpc}
  PHPDllNAME = 'php7ts.dll';
{$else}
  PHPDllNAME = 'php7ts.so';
{$endif}
  ZEND_MODULE_API_NO = 14.20; // Версия модуля!!!!!!!

var
  PHP7dllHandle: THandle = 0;

{
procedure LoadPHPFunc(var Func: pointer; FuncName: PAnsiChar);
begin
  if PHP7dll = 0 then
    if IsFile(string(PhpDllName)) then
    begin
      PHP7dll := GetModuleHandleA(PhpDllName);
      if PHP7dll = 0 then
        PHP7dll := LoadLibraryA(PhpDllName);
      if PHP7dll = 0 then
      begin
        MessageBoxW(0, PWideChar(WideString(HRESULTStr(GetLastError) + #10#13 +
          '- ' + PhpDllName)), '', 0);

        Exit;
      end;
    end;

  Func := GetProcAddress(PHP7dll, FuncName);

  if not assigned(Func) then
    MessageBoxW(0, Pwidechar('Unable to link [' + FuncName + '] function'),
      'LoadFunction', 0)
end;
}
{$ifdef fpc}
function LoadPHPFuncLocal(Func: PPointer; FuncName: LPCSTR; fault: boolean = true): Boolean;
{$else}
function LoadPHPFuncLocal(var Func: Pointer; FuncName: LPCSTR; fault: boolean = true): Boolean;
{$endif}

begin
  Result := True;
  if PHP7dllHandle = 0 then
//    if IsFile(AnsiString(PhpDllName)) then
//    if FileExists(PhpDllName) then
//    begin
      PHP7dllHandle := GetModuleHandle(PChar('C:\xampp\php\' + PhpDllName));
      if PHP7dllHandle = 0 then
        begin
        PHP7dllHandle := LoadLibrary(PChar('C:\xampp\php\' + PhpDllName));
        MessageBox(0, PChar('LoadLibrary [' + 'C:\xampp\php\' + PhpDllName + ']'), 'LoadPHPFunc', 0);
        end;
      if PHP7dllHandle = 0 then
        begin
        //WPD.Vis.Out(HRESULTStr(GetLastError) + #10#13 + '- ' + FuncName);
        MessageBox(0, PChar('Unable to LoadLibrary [' + 'C:\xampp\php\' + PhpDllName + '] function'), 'LoadPHPFunc', 0);
        Result := False;
        Halt;
        end;

    {$ifdef fpc}
      Func^ := GetProcAddress(PHP7dllHandle, FuncName);
      if not Assigned(Func^) then
    {$else}
      Func := GetProcAddress(PHP7dllHandle, FuncName);
      if not assigned(Func) then
    {$endif}
        begin
        //if fault then
        MessageBox(0, PChar('Unable to GetProcAddress [' + FuncName + '] function'), 'LoadFunction', 0);
        Result := False;
        end
      else
        begin
        //MessageBox(0, PChar('Loaded: GetProcAddress [' + FuncName + '] function'), 'LoadFunction', 0);
        end
//    end
//  else
//    begin
//    MessageBoxW(0, Pwidechar('Error! [' + PhpDllName + '] is not a file name!'), 'LoadPHPFunc', 0);
//    Result := False;
//    end;
end;

procedure CBTest(execute_data: pzend_execute_data; return_value: pzval); cdecl;
var
  {$ifdef fpc}
  FuncArgs: specialize TArray<pzval>;
//  FuncArgs: specialize TArray<ppzval>;
//  p: array of pzval;
  p: specialize TArray<pzval>;
  parsArray: specialize TArray<pzval>;
//  parsArray: Array of zval;
  {$else}
  p: TArray<pzval>;
  {$endif}
  err, i: integer;
  X, Y: longint;
//  X, Y: Pzend_long;
//  X, Y: pzval;
  input_arguments_count : longint;
  //FuncArgs: ppzval;
  par1, par2 : pzval;
//  par1, par2 : ppzval;
//  zpar1, zpar2 : zval;
  zv, param_ptr: pzval;
  Args: ppzval;
  pVar_type: PAnsiChar;
begin
//блять! типы данных с PHP7 не совпадают!
  MessageBox(0, PChar('CBTest'), PChar('CBTest'), 0);
//  MessageBox(0, PChar('CBTest'), PChar('CBTest'), 0);
  input_arguments_count := execute_data^.This.u2.num_args;
//  X := TSRMLS_DC.u2.num_args;
//  input_arguments_count := this_ptr^.u2.num_args;
//  input_arguments_count := 2;//p1^.u2.num_args;
//  zend_get_parameters_my( ht, p);
//  MessageBoxW(0, Pwidechar('zend_get_parameters_my'), Pwidechar('zend_get_parameters_my'), 0);

  if input_arguments_count = 2 then
    begin
    //получение параметров происходит при помощи нескольких вложенных макросов ZEND_CALL_ARG() -> ZEND_CALL_VAR_NUM(),
    //определенных в php-src-PHP-7.4.21\Zend\zend_compile.h
    //полностью раскрытая строка кода на выходе препроцессора выглядит так:
    //(((zval(p_execute_data)) + (((int)((ZEND_MM_ALIGNED_SIZE(sizeof(zend_execute_data)) + ZEND_MM_ALIGNED_SIZE(sizeof(zval)) - 1) / ZEND_MM_ALIGNED_SIZE(sizeof(zval)))) + ((int)(n))))

    //вычисляем коррекцию смещения аргументов функции в памяти вручную
    //par1 := pzval(Pbyte(execute_data) + sizeOf(_zend_execute_data) + sizeOf(_zval_struct) * 0 + 8);//0- номер параметра. Так работает!
    //par2 := pzval(Pbyte(execute_data) + sizeOf(_zend_execute_data) + sizeOf(_zval_struct) * 1 + 8);//1- номер параметра. Так работает!
    //для сокращения кода использует константу смещения ZEND_CALL_FRAME_SLOT
    //проверяем, что константа ZEND_CALL_FRAME_SLOT правильно вычисляется
    //par1 := pzval(Pbyte(execute_data) + ZEND_CALL_FRAME_SLOT);

    SetLength(parsArray, input_arguments_count);
    err := zend_get_parameters_array(execute_data, input_arguments_count, parsArray);
    x := parsArray[0]^.value.lval;
    y := parsArray[1]^.value.lval;

    //return_value := ZvalEmalloc;
    //NewPzval(return_value);
    //формирем переменную для возврата результата работы функции
    ZvalVAL(return_value, 0);
    return_value^.u1.type_info := IS_LONG;
    return_value^.u1.v.type_ := return_value^.u1.type_info;
    return_value^.value.lval := X + Y;
    //efree(FuncArgs);
    end
  else
    begin
    //формируем сообщение об ошибке: Неправильное количество параметров
    zend_wrong_paramers_count_error(input_arguments_count, 2, 2 );
    //MessageBoxW(0, Pwidechar('ZVAL_FALSE(return_value)'), Pwidechar('ZVAL_FALSE(return_value)'), 0);
    ZVAL_FALSE(return_value);
    //zend_wrong_paramers_count(TSRMLS_DC);
    end;
end;

function addFunc(Name: PAnsiChar; CallBackFunc: Pointer; num: integer = 0): bool;
var
  { сделаем глобальной
  {$ifdef fpc}
  arr_arg_info: specialize TArray<zend_internal_arg_info>;
  {$else}
  arr_arg_info: TArray<zend_internal_arg_info>;
  {$endif}
  }
  i: integer;
  Parr_arg_info: P_zend_internal_arg_info;
  pB: pByte;
begin
//  num := 0;
  Result := False;
  inc(RegNumFunc);
  //увеличиваем размер массива Пользовательских функций
  SetLength(ArrZendFunctionEnt, RegNumFunc);
  ArrZendFunctionEnt[RegNumFunc - 1].fname := Name;
  ArrZendFunctionEnt[RegNumFunc - 1].num_args := num;//0;
  ArrZendFunctionEnt[RegNumFunc - 1].handler := Pzend_function_entry_handler(CallBackFunc);
  if num > 0 then
    begin
    //если у функции есть аргументы, то нужно описать каждый из них
    //увеличиваем массив аргументов, до нужного размера

    //помним, что мы находимся в чужом адресном пространстве! (Нашу DLL всосало ядро ZEND!)
    //а философия ZEND придерживается таких же принципов, как и модель Microsoft COM. А именно:
    //чтобы работа внутреннего менеджера памяти ZEND была надежной, то любой внешний модуль должен хранить свои данные
    //в куче, созданной в ядре ZEND. Т.е. если нам нужно выделить память под какую-то структуру данных, которая должна сохраниться после
    //завершения нашей самописной функции, эти данные нужно хранить в памяти (куче) ЯДРА ZEND!
    //ЕЩЕ раз: если вы внутри своего модуля (DLL) делаете вызов GetMem, то память выделяет менеджер памяти DLL
    //ядро ZEND о занятии этого куска памяти ничего не знает. Если при завершении вашей функции, вы оставляете выделенным какой-то кусок памяти (или структуру данных)
    //и передаете указатель на нее ZEND-ядру, то оно потом должно вызывать менеджер памяти вашей DLL, чтобы освободить/переместить вашу память.
    //Это ведет к значительным усложнениям ZEND-ядра и бардаку (а в дальнейшем к утечкам памяти и краху всего модуля PHP).
    //Поэтому, создатели ZEND отказались от работы с менеджерами памяти каждого DLL модуля.
    //Внутри своих процедур и функций создавайте, разрушайте какие угодно объекты/структуры данных при поможи местного менеджера памяти GetMem/FreeMem.
    //Это допускается. Не забываейте, только, что все что вы выделили, вы же потом и должны освободить этими же функциями GetMem/FreeMem!
    //Zend о ваших манипуляциях GetMem/FreeMem ничего не знает!
    //А теперь САМОЕ ВАЖНОЕ: помните, если вы хотите, что-то передать (или оставить на выходе вашей процедуры) для ZEND-ядра, то пользуйтесь его менеджером памяти!
    //т.е. пользуемся функциями _emalloc/_efree (которые мы импортировали из PHPts7.dll или PHPts7.so)
    //ПОВТОРЯЮ, если нужно взаимодействовать с ядром ZEND используем ЕГО менеджер памяти (_emalloc/_efree и прочие функции из zend_alloc.h)!

    SetLength(arr_arg_info, num);
    ArrZendFunctionEnt[RegNumFunc - 1].num_args := num;

    for i := 0 to num - 1 do
      begin
      arr_arg_info[i].name := PAnsiChar('par' + inttostr(i));
      arr_arg_info[i].type_ := IS_LONG;
      arr_arg_info[i].pass_by_reference := ZEND_SEND_BY_REF;//=1
      arr_arg_info[i].is_variadic := 0;
      end;
    ArrZendFunctionEnt[RegNumFunc - 1].arg_info := @arr_arg_info;

    //можно сделать код на основе указателей
    {
    //Структура arr_arg_info будет оставлена в памяти после завершения кода моей функции, поэтому я выделяю под нее память в куче, которой управляет ZEND
    //Parr_arg_info := _emalloc(SizeOf(_zend_internal_arg_info) * num, nil, 0, nil, 0);
    Parr_arg_info := emalloc(SizeOf(_zend_internal_arg_info) * num);
    //Parr_arg_info := @arr_arg_info;
    pB := pointer(Parr_arg_info);
    //и тут у здорового программиста возникает вопрос: нужно ли убирать за собой _efree(), после того, как навалил кучу?
    //чисто теоретически при выгрузке нашего модуля будет вызвана функция ShutDown и в ней мы должны очистить все, что мы выделяли
    //в том числе и в куче, которой управляет ядро ZEND. Однако, при завершении самого ZEND его ядро пробегается по всей кучи и очищает все известные
    //ему фрагменты памяти. Т.е. если ваш модуль загружается и работает постоянно, то можно навалить кучу и не спускать - это сделает ZEND...)))) Но это не точно))))
    //Лично я ярый противник JAVA концепции по наваливанию куч и блокировке сливных бачков! Навалил - сам нажал на слив - это подход правильного языка программирования!
    ArrZendFunctionEnt[RegNumFunc - 1].arg_info := @Parr_arg_info;
    for i := 0 to num - 1 do
      begin

      //проверено так работает, но проблема со вторым аргументом у функции!
      Parr_arg_info^.name := PAnsiChar('par' + inttostr(i));
      Parr_arg_info^.type_ := IS_LONG;//ZEND_TYPE_ENCODE(IS_LONG, 0);//IS_UNDEF;//IS_LONG;
      Parr_arg_info^.pass_by_reference := ZEND_SEND_BY_REF;
      Parr_arg_info^.is_variadic := 0;
      //ArrZendFunctionEnt[RegNumFunc - 1].arg_info := nil;//если сделать так, то вызов функции из PHP ведет к падению библиотеки. Т.е. массив аргументов работает
      Parr_arg_info := Parr_arg_info + 1;//прибавляется не 1 байт, а размер типизированного указателя

      { или
      //проверено так работает, но проблема со вторым аргументом у функции!
      P_zend_internal_arg_info(pB)^.name := PAnsiChar('par' + inttostr(i));
      P_zend_internal_arg_info(pB)^.type_ := IS_LONG;//ZEND_TYPE_ENCODE(IS_LONG, 0);//IS_UNDEF;//IS_LONG;
      P_zend_internal_arg_info(pB)^.pass_by_reference := ZEND_SEND_BY_REF;//ZEND_SEND_BY_VAL
      P_zend_internal_arg_info(pB)^.is_variadic := 0;//1 = переменное число параметров?
      //ArrZendFunctionEnt[RegNumFunc - 1].arg_info := nil;//если сделать так, то вызов функции из PHP ведет к падению библиотеки. Т.е. массив аргументов работает
      //ArrZendFunctionEnt[RegNumFunc - 1].arg_info := @pB;
      pB := pB + SizeOf(_zend_internal_arg_info);
      }
      end;
    }
    Result := true;
    end
  else
    begin
    //если у функции нет аргументов, то и таблица описания аргументов не нужна
    ArrZendFunctionEnt[RegNumFunc - 1].num_args := 0;
    ArrZendFunctionEnt[RegNumFunc - 1].arg_info := nil;
    end;

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

function StrMove(Dest: PAnsiChar; const Source: PAnsiChar; Count: cardinal)
  : PAnsiChar;
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
  PName := PAnsiChar(shearPosString('php_', '.dll', ExtractFileName(GetModuleName(Instance))));
  if PName = nil then
    Result := DefaultName
  else
    Result := StrNew(PName);
end;

//function module_startup_func(_type: longint; module_number:longint):longint;cdecl;
function module_startup_func(_type: integer; module_number: integer): integer; cdecl;
begin
  //вызывается при старте PHP загрузки модуля во время запуска Апачи
//  MessageBoxW(0, Pwidechar('module_startup_func'), Pwidechar('module_startup_func'), 0);
  result := SUCCESS;
end;

function module_shutdown_func(_type: longint; module_number: longint): longint; cdecl;
begin
//  MessageBoxW(0, Pwidechar('module_shutdown_func'), Pwidechar('module_shutdown_func'), 0);
  result := SUCCESS;
end;

function request_startup_func(_type:longint; module_number:longint):longint;cdecl;//PHP7
//function request_startup_func(_type: longint; module_number: longint; TSRMLS_DC: Pointer): longint; cdecl;//PHP5
begin
  //вызывается не при старте загрузки модуля во время запуска Апачи, а уже при вызове функции загрузки из скрипта PHP!
//  MessageBoxW(0, Pwidechar('request_startup_func'), Pwidechar('request_startup_func'), 0);
  result := SUCCESS;
end;

function request_shutdown_func(_type: longint; module_number: longint): longint; cdecl;
begin
  //вызывается при завершении сценария PHP!
//  MessageBoxW(0, Pwidechar('request_shutdown_func'), Pwidechar('request_shutdown_func'), 0);
  result := SUCCESS;
end;

procedure Init(global: pointer); cdecl;
//var strlist: TStringList;
begin
//  strlist := TStringList.Create();
//  strlist.add('OK');
//  strlist.SaveToFile('C:\Distrib\1.txt');
//  strlist.free;
//  result := 0;
MessageBoxW(0, Pwidechar('Init'), Pwidechar('Module Init()'), 0);
//FLibraryModule.module_started := 1;
end;

procedure ShutDown(global: pointer); cdecl;
begin
//  MessageBoxW(0, Pwidechar('ShutDown'), Pwidechar('zend_get_module'), 0);
//  result := 0;
end;

procedure info_func(pzend_module: p_zend_module_entry); cdecl;
begin
//  MessageBoxW(0, Pwidechar('info_func'), Pwidechar('zend_get_module'), 0);
  php_info_print_table_start();
  php_info_print_table_row(2, PChar('Php_screen module version'), PChar('WPD PHP7_for_Lazarus 1.0 24 Okt 2021'));
  php_info_print_table_row(2, PChar('Home page'), PChar('http://noname'));
  php_info_print_table_end();
end;

function get_module: Pzend_module_entry; cdecl;
var pfunc: pointer;
var strlist: TStringList;
begin
//  strlist := TStringList.Create();
//  strlist.add('OK');
//  strlist.SaveToFile('C:\Distrib\1.txt');
//  strlist.free;
  MessageBoxW(0, Pwidechar('zend_get_module'), Pwidechar('zend_get_module'), 0);

//  Load('C:\xampp\php\php7ts');
  RegNumFunc := 0;
//Из всего множества функций, которые есть в PHPts7.dll нам нужны лишь несколько
//например, функция вывода строк в табличку запроса информации о модуле расширения
  LoadPHPFuncLocal(@php_info_print_table_start, PAnsiChar('php_info_print_table_start'));
  LoadPHPFuncLocal(@php_info_print_table_row, PAnsiChar('php_info_print_table_row'));
  LoadPHPFuncLocal(@php_info_print_table_end, PAnsiChar('php_info_print_table_end'));
//  LoadPHPFuncLocal(@ZvalGetArgs, PAnsiChar('ZvalGetArgs'));

  LoadPHPFuncLocal(@_zend_get_parameters_array_ex, PAnsiChar('_zend_get_parameters_array_ex'));
  LoadPHPFuncLocal(@zend_wrong_paramers_count_error, 'zend_wrong_parameters_count_error@@16');
//  LoadPHPFunc(@_array_init, '_array_init');
  LoadPHPFuncLocal(@add_next_index_long, 'add_next_index_long');
  LoadPHPFuncLocal(@_emalloc, '_emalloc@@8');//x64
  LoadPHPFuncLocal(@_efree, '_efree@@8');//x64
  LoadPHPFuncLocal(@_convert_to_string, '_convert_to_string@@8');//x64
//  LoadPHPFunc(@convert_to_long, '_convert_to_long@@8');//x64

  FLibraryModule.size := sizeOf(_zend_module_entry);//Tzend_module_entry);
  //FLibraryModule.globals_size := ;

  //This is plugin working with
  //PHP Extension    20190902
  //Zend Extension  320190902

  FLibraryModule.zend_api := 20190902;//ZEND_EXTENSION_API_NO;
  //  FLibraryModule.zend_api := 420200930;
  FLibraryModule.zend_debug := 0;
  FLibraryModule.zts := 1;
  FLibraryModule.ini_entry := nil;
  FLibraryModule.deps := nil;
  FLibraryModule.Name := StrNew(PAnsiChar('php_screen_lazarus'));
  //FLibraryModule.name := PHPLibraryName(hInstance, 'php_screen_lazarus');
  FLibraryModule.module_startup_func := @module_startup_func;
  FLibraryModule.module_shutdown_func := @module_shutdown_func;
  FLibraryModule.request_startup_func := @request_startup_func;//nil
  FLibraryModule.request_shutdown_func := @request_shutdown_func;
  FLibraryModule.info_func := @info_func;
  FLibraryModule.globals_ctor := @init;
  FLibraryModule.globals_dtor := @shutdown;
  FLibraryModule.globals_ptr := nil;
  FLibraryModule.post_deactivate_func := nil;;
  FLibraryModule.version := StrNew(PAnsiChar('0.11'));
//  FLibraryModule._type := MODULE_TEMPORARY;
  FLibraryModule.type_ := MODULE_PERSISTENT;
  FLibraryModule.Handle := nil;
  FLibraryModule.module_number := 0;
  FLibraryModule.module_started := 0;


  FLibraryModule.build_id := StrNew(PAnsiChar('API20190902,TS,VC15'));//API320190902,TS,VC15

//без добавления Функции модуль загружается, но стоит добавить ф-ция и все падает
//addFunc('CBTest', @CBTest, 1);//функция будет принимать 2 параметра на вход
  addFunc('CBTest', @CBTest, 2);//функция будет принимать 2 параметра на вход



//  addFunc('ScrWindows', @CBScrWindows);
//  addFunc('PixelSearch', @CBPixelSearch);
//MessageBoxW(0, Pwidechar('addFunc ScrWindows'), Pwidechar('zend_get_module'), 0);

//  FLibraryModule.functions := @ZendFunction[0];
//  MessageBoxW(0, Pwidechar('FLibraryModule.functions := @ZendFunction[0]'), Pwidechar('zend_get_module'), 0);


//  tsrm_startup(128, 1, 0, nil);
//  sapi_startup(@wpd_sapi_module);

  FLibraryModule.functions := @ArrZendFunctionEnt[0];
//  php_module_startup(@wpd_sapi_module, @FLibraryModule, 1);
//  module_shutdown_func(@wpd_sapi_module, @FLibraryModule, 1);//module_shutdown_func 	PHP_MSHUTDOWN(mymodule)

//  TSRMLS_D := tsrm_get_ls_cache;

//  PHPInitSetValue('register_argc_argv', '0', ZEND_INI_SYSTEM, ZEND_INI_STAGE_ACTIVATE);
//  PHPInitSetValue('html_errors', '1', ZEND_INI_SYSTEM, ZEND_INI_STAGE_ACTIVATE);
//  PHPInitSetValue('implicit_flush', '1', ZEND_INI_SYSTEM, ZEND_INI_STAGE_ACTIVATE);
//  PHPInitSetValue('max_input_time', '0', ZEND_INI_SYSTEM, ZEND_INI_STAGE_ACTIVATE);

  Result := @FLibraryModule;
//  MessageBoxW(0, Pwidechar('Result := @FLibraryModule'), Pwidechar('zend_get_module'), 0);

end;

exports get_module name 'get_module';
//exports get_module name 'zend_get_module';

end.

