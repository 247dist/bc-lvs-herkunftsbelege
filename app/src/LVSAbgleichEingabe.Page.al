// Eingabe fuer das Einlesen: Datum ab (Standard 14 Tage) und/oder Wareneingangsnummer(n).
page 50953 "LVS Abgleich Eingabe"
{
    Caption = 'Einlesen: Eingabe';
    PageType = StandardDialog;

    layout
    {
        area(Content)
        {
            field(DateFromCtrl; DateFrom)
            {
                ApplicationArea = All;
                Caption = 'Buchungsdatum ab';
                ToolTip = 'Nur Wareneingaenge mit Buchungsdatum ab diesem Datum. Leer = ohne Datumsgrenze (dann ist eine Wareneingangsnummer Pflicht).';
            }
            field(ReceiptFilterCtrl; ReceiptFilter)
            {
                ApplicationArea = All;
                Caption = 'Wareneingang Nr.';
                ToolTip = 'Optional: eine Nummer oder ein Filter, zum Beispiel WETI1015336|WETI1015337. Ohne Eingabe gilt nur die Datumsgrenze.';
            }
        }
    }

    var
        DateFrom: Date;
        ReceiptFilter: Text[250];

    trigger OnOpenPage()
    begin
        DateFrom := Today() - 14;
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if CloseAction = Action::OK then
            if (DateFrom = 0D) and (ReceiptFilter = '') then
                Error('Ohne Datum muss eine Wareneingangsnummer angegeben werden. Aelteres nur mit Eingabe.');
        exit(true);
    end;

    procedure GetValues(var NewDateFrom: Date; var NewReceiptFilter: Text)
    begin
        NewDateFrom := DateFrom;
        NewReceiptFilter := ReceiptFilter;
    end;
}
