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
                ToolTip = 'Optional: eine Nummer oder ein Filter, zum Beispiel WETI1015336|WETI1015337. Gilt ohne Altersgrenze. Ist der Wareneingang schon gebucht, die Bestellnummer verwenden.';
            }
            field(OrderFilterCtrl; OrderFilter)
            {
                ApplicationArea = All;
                Caption = 'Bestellung Nr.';
                ToolTip = 'Optional: eine Bestellnummer, zum Beispiel B240000691 oder BTI1089290. Gilt ohne Altersgrenze und auch fuer bereits gebuchte Wareneingaenge. Hat Vorrang vor Datum und Wareneingang.';
            }
            field(CompanyFilterCtrl; CompanyFilter)
            {
                ApplicationArea = All;
                Caption = 'Mandant';
                ToolTip = 'Nur fuer die Bestellnummer: 247 oder Titus_GmbH. Leer = beide Mandanten.';
            }
        }
    }

    var
        DateFrom: Date;
        ReceiptFilter: Text[250];
        OrderFilter: Text[250];
        CompanyFilter: Text[30];

    trigger OnOpenPage()
    begin
        DateFrom := Today() - 14;
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if CloseAction = Action::OK then
            if (DateFrom = 0D) and (ReceiptFilter = '') and (OrderFilter = '') then
                Error('Ohne Datum muss eine Wareneingangs- oder Bestellnummer angegeben werden. Aelteres nur mit Eingabe.');
        exit(true);
    end;

    procedure GetValues(var NewDateFrom: Date; var NewReceiptFilter: Text; var NewOrderFilter: Text; var NewCompanyFilter: Text)
    begin
        NewDateFrom := DateFrom;
        NewReceiptFilter := ReceiptFilter;
        NewOrderFilter := OrderFilter;
        NewCompanyFilter := CompanyFilter;
    end;
}
