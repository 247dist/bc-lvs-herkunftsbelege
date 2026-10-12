// Liste der Kandidaten. Einlesen nach Eingabe, Freigeben, Anlegen nur fuer Freigegebene.
page 50952 "LVS Abgleich Kandidaten"
{
    Caption = 'Herkunftsbeleg-Abgleich';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Tasks;
    SourceTable = "LVS Abgleich Kandidat";
    InsertAllowed = false;
    DeleteAllowed = true;
    ModifyAllowed = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Freigegeben; Rec.Freigegeben)
                {
                    ApplicationArea = All;
                    Editable = true;
                }
                field(Mandant; Rec.Mandant)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Wareneingang Nr."; Rec."Wareneingang Nr.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Bestellung Nr."; Rec."Bestellung Nr.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Lagerort; Rec.Lagerort)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Kreditor Nr."; Rec."Kreditor Nr.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Buchungsdatum; Rec.Buchungsdatum)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field(Fehlermeldung; Rec.Fehlermeldung)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Einlesen)
            {
                ApplicationArea = All;
                Caption = 'Einlesen';
                Image = Refresh;
                ToolTip = 'Liest Wareneingaenge ohne Eintrag in Herkunftsbelege Mandant ein. Fragt nach Datum und Wareneingangsnummer.';

                trigger OnAction()
                var
                    Input: Page "LVS Abgleich Eingabe";
                    Sync: Codeunit "LVS Source Doc Sync TITUS";
                    DateFrom: Date;
                    ReceiptFilter: Text;
                    OrderFilter: Text;
                    CompanyFilter: Text;
                    Added: Integer;
                begin
                    if Input.RunModal() <> Action::OK then
                        exit;
                    Input.GetValues(DateFrom, ReceiptFilter, OrderFilter, CompanyFilter);
                    if OrderFilter <> '' then
                        Added := Sync.ScanOrders(CompanyFilter, OrderFilter)
                    else
                        Added := Sync.Scan(DateFrom, ReceiptFilter);
                    Message('%1 neue Kandidaten eingelesen.', Added);
                    CurrPage.Update(false);
                end;
            }
            action(ArtikelPruefen)
            {
                ApplicationArea = All;
                Caption = 'Artikel im LVS pruefen';
                Image = ItemLines;
                ToolTip = 'Zeigt, welche Artikel der Bestellzeilen in diesem Mandanten fehlen oder gesperrt sind. Eingabe: Bestellung Nr. und optional Mandant.';

                trigger OnAction()
                var
                    Input: Page "LVS Abgleich Eingabe";
                    Sync: Codeunit "LVS Source Doc Sync TITUS";
                    DateFrom: Date;
                    ReceiptFilter: Text;
                    OrderFilter: Text;
                    CompanyFilter: Text;
                begin
                    if Input.RunModal() <> Action::OK then
                        exit;
                    Input.GetValues(DateFrom, ReceiptFilter, OrderFilter, CompanyFilter);
                    if OrderFilter = '' then
                        Error('Bitte eine Bestellung Nr. angeben, zum Beispiel BTI1089290|BTI1089304|BTI1089393.');
                    Message(Sync.CheckItems(CompanyFilter, OrderFilter));
                end;
            }
            action(FehlerZuruecksetzen)
            {
                ApplicationArea = All;
                Caption = 'Fehler zuruecksetzen';
                Image = ClearLog;
                ToolTip = 'Leert Fehlermeldung und Fehleraufrufliste der Eintraege in Herkunftsbelege Mandant zu den angegebenen Bestellungen, damit TSO sie erneut verarbeitet. Eingabe: Bestellung Nr. und optional Mandant.';

                trigger OnAction()
                var
                    Input: Page "LVS Abgleich Eingabe";
                    Sync: Codeunit "LVS Source Doc Sync TITUS";
                    DateFrom: Date;
                    ReceiptFilter: Text;
                    OrderFilter: Text;
                    CompanyFilter: Text;
                    Count: Integer;
                begin
                    if Input.RunModal() <> Action::OK then
                        exit;
                    Input.GetValues(DateFrom, ReceiptFilter, OrderFilter, CompanyFilter);
                    if OrderFilter = '' then
                        Error('Bitte eine Bestellung Nr. angeben, zum Beispiel BTI1089290|BTI1089304|BTI1089393.');
                    Count := Sync.ResetErrors(CompanyFilter, OrderFilter, false);
                    if Count = 0 then
                        Error('Keine Eintraege mit Fehlermeldung zu diesen Bestellungen gefunden.');
                    if not Confirm('Fehler bei %1 Eintraegen zuruecksetzen?', false, Count) then
                        exit;
                    Sync.ResetErrors(CompanyFilter, OrderFilter, true);
                    Message('%1 Eintraege zurueckgesetzt.', Count);
                end;
            }
            action(Freigeben)
            {
                ApplicationArea = All;
                Caption = 'Markierte freigeben';
                Image = Approve;
                ToolTip = 'Setzt das Haekchen Freigegeben fuer die markierten Zeilen.';

                trigger OnAction()
                var
                    Candidate: Record "LVS Abgleich Kandidat";
                begin
                    CurrPage.SetSelectionFilter(Candidate);
                    Candidate.SetFilter(Status, '<>%1', Candidate.Status::Angelegt);
                    Candidate.ModifyAll(Freigegeben, true);
                    CurrPage.Update(false);
                end;
            }
            action(FreigabeEntfernen)
            {
                ApplicationArea = All;
                Caption = 'Freigabe entfernen';
                Image = Cancel;
                ToolTip = 'Nimmt das Haekchen Freigegeben fuer die markierten Zeilen wieder weg.';

                trigger OnAction()
                var
                    Candidate: Record "LVS Abgleich Kandidat";
                begin
                    CurrPage.SetSelectionFilter(Candidate);
                    Candidate.ModifyAll(Freigegeben, false);
                    CurrPage.Update(false);
                end;
            }
            action(Anlegen)
            {
                ApplicationArea = All;
                Caption = 'Freigegebene anlegen';
                Image = Post;
                ToolTip = 'Legt fuer alle freigegebenen Zeilen den fehlenden Eintrag in Herkunftsbelege Mandant an.';

                trigger OnAction()
                var
                    Candidate: Record "LVS Abgleich Kandidat";
                    Sync: Codeunit "LVS Source Doc Sync TITUS";
                    Count: Integer;
                begin
                    Candidate.SetRange(Freigegeben, true);
                    Candidate.SetFilter(Status, '<>%1', Candidate.Status::Angelegt);
                    Count := Candidate.Count();
                    if Count = 0 then
                        Error('Keine freigegebenen Zeilen.');
                    if not Confirm('%1 Eintraege in Herkunftsbelege Mandant anlegen?', false, Count) then
                        exit;
                    Sync.CreateCandidates(Candidate);
                    CurrPage.Update(false);
                end;
            }
            action(ErledigteLoeschen)
            {
                ApplicationArea = All;
                Caption = 'Erledigte loeschen';
                Image = Delete;
                ToolTip = 'Entfernt Zeilen mit Status Angelegt aus der Liste.';

                trigger OnAction()
                var
                    Candidate: Record "LVS Abgleich Kandidat";
                begin
                    Candidate.SetRange(Status, Candidate.Status::Angelegt);
                    Candidate.DeleteAll();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            actionref(Einlesen_Promoted; Einlesen) { }
            actionref(ArtikelPruefen_Promoted; ArtikelPruefen) { }
            actionref(Freigeben_Promoted; Freigeben) { }
            actionref(Anlegen_Promoted; Anlegen) { }
        }
    }
}
