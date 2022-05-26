unit WPD.Vis7;
{$Include wpdefines.inc}
interface

uses
  {$IF Defined(FPC)}
  Types,
  Classes,
  {$ELSE}
  System.Types,
  System.Classes,
  {$ENDIF}
  WPD.Classes7
  {$IF Defined(LCL)}
  , Forms
  , Dialogs
  {$ELSEIF Defined(FMX)}
//  , FMX.Forms
//  , System.Messaging
//  , FMX.Consts
//  , FMX.Types
//  , FMX.dialogs
  {$ELSEIF Defined(VCL)}
  , VCL.Forms,
  VCL.Dialogs
  {$ELSE}
  {$ENDIF}
  {$IF not Defined(FPC) and (Defined(VCL) or Defined(FMX))}
  , System.UITypes
  {$ENDIF}
  ;
procedure Out(What: String; E: Boolean = False);

{$IF not Defined(FPC) and Defined(FMX)}
type TForm = class (FMX.Forms.TCustomForm)
  constructor Create(AOwner: TComponent); override;
end;
{$ENDIF}

implementation
procedure Out(What: String; E: Boolean = False);
{$IF not Defined(FPC) and Defined(FMX)}
Begin
  if E then
       MessageDlg( What, TMsgDlgType.mtWarning, [TMsgDlgBtn.mbOK], 0 )
  ELse
    ShowMessage(What);
End;
{$ELSEIF Defined(LCL) or Defined(VCL)}
Begin
  if E then
       MessageDlg( What, mtWarning, [mbOK], 0 )
  ELse
    ShowMessage(What);
End;
{$ELSE}
Begin
  if E then
  begin
    WriteLn(Output, 'Error:');
    WriteLn(What);
  end
  else
    WriteLn(Output, What);
  ReadLn(Input);
End;
{$ENDIF}

{$IF not Defined(FPC) and Defined(FMX)}
constructor TForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(Application);
  if Application.MainForm = Nil then
  begin
    Application.MainForm := Self;
    TMessageManager.DefaultManager.SendMessage(Self, TMainCaptionChangedMessage.Create(Self));
  end;
end;
{$ENDIF}
{$IF Defined(LCL)}
initialization
   RequireDerivedFormResource := False;
   RegisterClass( Forms.TForm );
{$ELSEIF Defined(FMX) or Defined(VCL)}
initialization
    {$IF Defined(FMX)}
//    RegisterClass(WPD.Vis.TForm);
//    RegisterClassAlias('FMX.Forms.TForm', 'WPD.Vis.TForm');
    {$ELSEIF Defined(VCL)}
    RegisterClass(VCL.Forms.TForm);
    {$ENDIF}
{$ENDIF}
end.
