// Gleicht Wareneingaenge mit der Tabelle "Herkunftsbelege Mandant" (50013, Name "Warehouse RequestTSO") ab.
//
// Ablauf:
//  1. Scan: liest Wareneingaenge aus 247 und Titus_GmbH ein und merkt sich je Bestellung und Lagerort, fuer die in
//     50013 kein Eintrag existiert, einen Kandidaten.
//     - Mit Wareneingangsnummer (WETI..., WE24...): gilt keine Altersgrenze, die Kandidaten sind sofort freigegeben.
//     - Nur mit Datum: Kandidaten muessen einzeln freigegeben werden.
//  2. Der Anwender gibt Kandidaten frei (Seite "Herkunftsbeleg-Abgleich").
//  3. CreateCandidates legt fuer freigegebene Kandidaten den Eintrag an. Vorhandene Eintraege bleiben unberuehrt.
//
// Als Aufgabenwarteschlange (CU 50950, laeuft im Mandanten LVS-Logistik) arbeitet die Codeunit nur freigegebene,
// noch nicht angelegte Kandidaten ab. Ohne Freigabe passiert nichts.
//
// Die Tabelle 50013 liegt nicht in KatarGo, ihre Symbole sind hier nicht eingebunden. Der Zugriff laeuft deshalb
// per RecordRef, die Felder werden zur Laufzeit ueber ihren Namen in der Systemtabelle "Field" gefunden.
codeunit 50950 "LVS Source Doc Sync TITUS"
{
    TableNo = "Job Queue Entry";
    Permissions = tabledata Field = R,
                  tabledata "LVS Abgleich Kandidat" = RIMD;

    trigger OnRun()
    var
        Candidate: Record "LVS Abgleich Kandidat";
    begin
        Candidate.SetRange(Freigegeben, true);
        Candidate.SetFilter(Status, '<>%1', Candidate.Status::Angelegt);
        CreateCandidates(Candidate);
    end;

    var
        TargetTableId: Integer;

    /// Liest Kandidaten ein. Mit ReceiptFilter wird FromDate ignoriert und der Kandidat gleich freigegeben.
    /// Ohne ReceiptFilter ist FromDate Pflicht.
    procedure Scan(FromDate: Date; ReceiptFilter: Text): Integer
    var
        Added: Integer;
        Preapproved: Boolean;
    begin
        if (FromDate = 0D) and (ReceiptFilter = '') then
            Error('Ohne Datum muss eine Wareneingangsnummer angegeben werden.');
        Preapproved := ReceiptFilter <> '';
        if Preapproved then
            FromDate := 0D;
        Added += ScanCompany('247', FromDate, ReceiptFilter, Preapproved);
        Added += ScanCompany('Titus_GmbH', FromDate, ReceiptFilter, Preapproved);
        exit(Added);
    end;

    /// Setzt Fehlermeldung und Fehleraufrufliste der Eintraege in Tabelle 50013 zurueck, damit TSO sie erneut verarbeitet.
    /// Nur Eintraege mit Fehlermeldung, nur fuer die angegebenen Bestellungen, ohne Trigger. Gibt die Anzahl zurueck.
    procedure ResetErrors(CompanyFilter: Text; OrderFilter: Text; Apply: Boolean): Integer
    var
        RecRef: RecordRef;
        MessageFieldNo: Integer;
        StackFieldNo: Integer;
        Count: Integer;
    begin
        if OrderFilter = '' then
            Error('Bestellnummer fehlt.');
        RecRef.Open(GetTableId());
        SetFilterValue(RecRef, 'SourceNo', OrderFilter);
        if CompanyFilter <> '' then
            SetFilterValue(RecRef, 'Companyname', CompanyFilter);
        SetFilterValue(RecRef, 'ErrorMessage', '<>''''');
        MessageFieldNo := FieldNoOrError(RecRef.Number, 'ErrorMessage');
        StackFieldNo := FieldNoOrError(RecRef.Number, 'ErrorCallStack');
        if RecRef.FindSet(true) then
            repeat
                Count += 1;
                if Apply then begin
                    RecRef.Field(MessageFieldNo).Value := '';
                    RecRef.Field(StackFieldNo).Value := '';
                    RecRef.Modify(false);
                end;
            until RecRef.Next() = 0;
        exit(Count);
    end;

    /// Prueft, welche Artikel der Bestellzeilen im aktuellen Mandanten (LVS-Logistik) nicht existieren oder gesperrt sind.
    /// Ohne gefundene Artikel kann TSO bei der Umlagerung die Zeile nicht anlegen
    /// ("Sie muessen einen vorhandenen Artikel auswaehlen").
    procedure CheckItems(CompanyFilter: Text; OrderFilter: Text): Text
    var
        Report: TextBuilder;
        Missing: Integer;
        Checked: Integer;
    begin
        if OrderFilter = '' then
            Error('Bestellnummer fehlt.');
        if (CompanyFilter = '') or (CompanyFilter = '247') then
            CheckItemsInCompany('247', OrderFilter, Report, Missing, Checked);
        if (CompanyFilter = '') or (CompanyFilter = 'Titus_GmbH') then
            CheckItemsInCompany('Titus_GmbH', OrderFilter, Report, Missing, Checked);
        exit(StrSubstNo('%1 Artikel geprueft, %2 fehlen oder sind gesperrt in %3.', Checked, Missing, CompanyName()) + '' + Report.ToText());
    end;

    local procedure CheckItemsInCompany(SourceCompany: Text; OrderFilter: Text; var Report: TextBuilder; var Missing: Integer; var Checked: Integer)
    var
        PurchaseLine: Record "Purchase Line";
        Item: Record Item;
        CompanyRec: Record Company;
        Seen: List of [Text];
        ItemKey: Text;
    begin
        if not CompanyRec.Get(SourceCompany) then
            exit;
        PurchaseLine.ChangeCompany(SourceCompany);
        PurchaseLine.SetRange("Document Type", PurchaseLine."Document Type"::Order);
        PurchaseLine.SetFilter("Document No.", OrderFilter);
        PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
        if not PurchaseLine.FindSet() then
            exit;
        repeat
            ItemKey := PurchaseLine."Document No." + '|' + PurchaseLine."No.";
            if not Seen.Contains(ItemKey) then begin
                Seen.Add(ItemKey);
                Checked += 1;
                if not Item.Get(PurchaseLine."No.") then begin
                    Missing += 1;
                    Report.AppendLine(StrSubstNo('%1 %2: Artikel %3 (%4) fehlt.', SourceCompany, PurchaseLine."Document No.", PurchaseLine."No.", PurchaseLine.Description));
                end else
                    if Item.Blocked then begin
                        Missing += 1;
                        Report.AppendLine(StrSubstNo('%1 %2: Artikel %3 (%4) ist gesperrt.', SourceCompany, PurchaseLine."Document No.", PurchaseLine."No.", PurchaseLine.Description));
                    end;
            end;
        until PurchaseLine.Next() = 0;
    end;

    /// Legt Kandidaten direkt aus Bestellungen an, ohne Wareneingang. Fuer bereits gebuchte Wareneingaenge.
    /// Je Lagerort der Artikelzeilen ein Kandidat, sofort freigegeben. CompanyFilter leer = beide Mandanten.
    procedure ScanOrders(CompanyFilter: Text; OrderFilter: Text): Integer
    var
        Added: Integer;
    begin
        if OrderFilter = '' then
            Error('Bestellnummer fehlt.');
        if (CompanyFilter = '') or (CompanyFilter = '247') then
            Added += ScanOrdersInCompany('247', OrderFilter);
        if (CompanyFilter = '') or (CompanyFilter = 'Titus_GmbH') then
            Added += ScanOrdersInCompany('Titus_GmbH', OrderFilter);
        exit(Added);
    end;

    local procedure ScanOrdersInCompany(SourceCompany: Text; OrderFilter: Text): Integer
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        CompanyRec: Record Company;
        Locations: List of [Text];
        LocationCode: Text;
        Added: Integer;
    begin
        if not CompanyRec.Get(SourceCompany) then
            exit(0);

        PurchaseHeader.ChangeCompany(SourceCompany);
        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
        PurchaseHeader.SetFilter("No.", OrderFilter);
        if not PurchaseHeader.FindSet() then
            exit(0);

        repeat
            Clear(Locations);
            PurchaseLine.ChangeCompany(SourceCompany);
            PurchaseLine.Reset();
            PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
            PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
            PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
            if PurchaseLine.FindSet() then
                repeat
                    if not Locations.Contains(PurchaseLine."Location Code") then
                        Locations.Add(PurchaseLine."Location Code");
                until PurchaseLine.Next() = 0;

            foreach LocationCode in Locations do
                if not RequestExists(SourceCompany, PurchaseHeader."No.", LocationCode) then
                    if InsertCandidate(SourceCompany, '', PurchaseHeader."Order Date", PurchaseHeader."No.", LocationCode, true) then
                        Added += 1;
        until PurchaseHeader.Next() = 0;
        exit(Added);
    end;

    local procedure ScanCompany(SourceCompany: Text; FromDate: Date; ReceiptFilter: Text; Preapproved: Boolean): Integer
    var
        WhseReceiptHeader: Record "Warehouse Receipt Header";
        WhseReceiptLine: Record "Warehouse Receipt Line";
        CompanyRec: Record Company;
        Orders: Dictionary of [Text, Text];
        OrderKey: Text;
        OrderNo: Text;
        LocationCode: Text;
        Added: Integer;
    begin
        if not CompanyRec.Get(SourceCompany) then
            exit(0);

        WhseReceiptHeader.ChangeCompany(SourceCompany);
        if ReceiptFilter <> '' then
            WhseReceiptHeader.SetFilter("No.", ReceiptFilter);
        if FromDate <> 0D then
            WhseReceiptHeader.SetFilter("Posting Date", '%1..', FromDate);
        if not WhseReceiptHeader.FindSet() then
            exit(0);

        repeat
            Clear(Orders);
            WhseReceiptLine.ChangeCompany(SourceCompany);
            WhseReceiptLine.Reset();
            WhseReceiptLine.SetRange("No.", WhseReceiptHeader."No.");
            WhseReceiptLine.SetRange("Source Type", Database::"Purchase Line");
            WhseReceiptLine.SetFilter("Source Subtype", '1');
            if WhseReceiptLine.FindSet() then
                repeat
                    OrderKey := WhseReceiptLine."Source No." + '|' + WhseReceiptLine."Location Code";
                    if not Orders.ContainsKey(OrderKey) then
                        Orders.Add(OrderKey, WhseReceiptLine."Source No.");
                until WhseReceiptLine.Next() = 0;

            foreach OrderKey in Orders.Keys() do begin
                OrderNo := Orders.Get(OrderKey);
                LocationCode := OrderKey.Substring(StrLen(OrderNo) + 2);
                if not RequestExists(SourceCompany, OrderNo, LocationCode) then
                    if InsertCandidate(SourceCompany, WhseReceiptHeader."No.", WhseReceiptHeader."Posting Date", OrderNo, LocationCode, Preapproved) then
                        Added += 1;
            end;
        until WhseReceiptHeader.Next() = 0;
        exit(Added);
    end;

    local procedure InsertCandidate(SourceCompany: Text; ReceiptNo: Code[20]; PostingDate: Date; OrderNo: Text; LocationCode: Text; Preapproved: Boolean): Boolean
    var
        Candidate: Record "LVS Abgleich Kandidat";
        PurchaseHeader: Record "Purchase Header";
    begin
        Candidate.SetRange(Mandant, SourceCompany);
        Candidate.SetRange("Bestellung Nr.", CopyStr(OrderNo, 1, MaxStrLen(Candidate."Bestellung Nr.")));
        Candidate.SetRange(Lagerort, CopyStr(LocationCode, 1, MaxStrLen(Candidate.Lagerort)));
        Candidate.SetFilter(Status, '<>%1', Candidate.Status::Angelegt);
        if Candidate.FindFirst() then begin
            // Wurde das WETI gezielt eingegeben, wird ein vorhandener Kandidat freigegeben.
            if Preapproved and not Candidate.Freigegeben then begin
                Candidate.Freigegeben := true;
                Candidate.Modify();
            end;
            exit(false);
        end;

        Candidate.Reset();
        Candidate.Init();
        Candidate.Mandant := CopyStr(SourceCompany, 1, MaxStrLen(Candidate.Mandant));
        Candidate."Wareneingang Nr." := ReceiptNo;
        Candidate."Bestellung Nr." := CopyStr(OrderNo, 1, MaxStrLen(Candidate."Bestellung Nr."));
        Candidate.Lagerort := CopyStr(LocationCode, 1, MaxStrLen(Candidate.Lagerort));
        Candidate.Buchungsdatum := PostingDate;
        Candidate.Freigegeben := Preapproved;
        PurchaseHeader.ChangeCompany(SourceCompany);
        if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, OrderNo) then
            Candidate."Kreditor Nr." := PurchaseHeader."Buy-from Vendor No.";
        Candidate.Insert();
        exit(true);
    end;

    /// Legt fuer alle Kandidaten im uebergebenen Filter den Eintrag an. Fehler stehen je Zeile.
    procedure CreateCandidates(var Candidate: Record "LVS Abgleich Kandidat")
    var
        Done: Integer;
        Failed: Integer;
    begin
        if Candidate.FindSet(true) then
            repeat
                ClearLastError();
                if RequestExists(Candidate.Mandant, Candidate."Bestellung Nr.", Candidate.Lagerort) then begin
                    Candidate.Status := Candidate.Status::Angelegt;
                    Candidate.Fehlermeldung := 'Eintrag war bereits vorhanden.';
                    Done += 1;
                end else
                    if TryInsertRequest(Candidate.Mandant, Candidate."Bestellung Nr.", Candidate.Lagerort) then begin
                        Candidate.Status := Candidate.Status::Angelegt;
                        Candidate.Fehlermeldung := '';
                        Done += 1;
                    end else begin
                        Candidate.Status := Candidate.Status::Fehler;
                        Candidate.Fehlermeldung := CopyStr(GetLastErrorText(), 1, MaxStrLen(Candidate.Fehlermeldung));
                        Failed += 1;
                    end;
                Candidate.Modify();
                Commit();
            until Candidate.Next() = 0;

        if GuiAllowed() then
            Message('%1 angelegt, %2 Fehler.', Done, Failed);
    end;

    [TryFunction]
    local procedure TryInsertRequest(SourceCompany: Text; OrderNo: Text; LocationCode: Text)
    var
        PurchaseHeader: Record "Purchase Header";
        RecRef: RecordRef;
    begin
        PurchaseHeader.ChangeCompany(SourceCompany);
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, OrderNo);

        // Werte wie beim manuell angelegten Eintrag (Beispiel B240000691 aus 247).
        RecRef.Open(GetTableId());
        RecRef.Init();
        SetValue(RecRef, 'Companyname', SourceCompany);
        SetValue(RecRef, 'Type', 0); // Eingehend
        SetValue(RecRef, 'LocationCode', LocationCode);
        SetValue(RecRef, 'SourceType', Database::"Purchase Line");
        SetValue(RecRef, 'SourceSubtype', 1);
        SetValue(RecRef, 'SourceNo', OrderNo);
        SetValue(RecRef, 'SourceDocument', 2); // Einkaufsbestellung
        SetValue(RecRef, 'DocumentStatus', 0); // Offen
        SetValue(RecRef, 'ShippingAdvice', 0); // Teillieferung
        SetValue(RecRef, 'DestinationType', 2); // Kreditor
        SetValue(RecRef, 'DestinationNo', PurchaseHeader."Buy-from Vendor No.");
        RecRef.Insert(true);
    end;

    local procedure RequestExists(SourceCompany: Text; OrderNo: Text; LocationCode: Text): Boolean
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(GetTableId());
        SetFilterValue(RecRef, 'Companyname', SourceCompany);
        SetFilterValue(RecRef, 'Type', '0');
        SetFilterValue(RecRef, 'LocationCode', LocationCode);
        SetFilterValue(RecRef, 'SourceType', Format(Database::"Purchase Line"));
        SetFilterValue(RecRef, 'SourceSubtype', '1');
        SetFilterValue(RecRef, 'SourceNo', OrderNo);
        exit(not RecRef.IsEmpty());
    end;

    local procedure GetTableId(): Integer
    begin
        if TargetTableId = 0 then
            TargetTableId := 50013;
        exit(TargetTableId);
    end;

    local procedure SetValue(var RecRef: RecordRef; FieldName: Text; Value: Variant)
    var
        FieldRef: FieldRef;
    begin
        FieldRef := RecRef.Field(FieldNoOrError(RecRef.Number, FieldName));
        FieldRef.Value := Value;
    end;

    local procedure SetFilterValue(var RecRef: RecordRef; FieldName: Text; FilterText: Text)
    var
        FieldRef: FieldRef;
    begin
        FieldRef := RecRef.Field(FieldNoOrError(RecRef.Number, FieldName));
        FieldRef.SetFilter(FilterText);
    end;

    local procedure FieldNoOrError(TableId: Integer; FieldName: Text): Integer
    var
        FieldNo: Integer;
    begin
        FieldNo := FindFieldNo(TableId, FieldName);
        if FieldNo = 0 then
            Error('Feld %1 in Tabelle %2 nicht gefunden.', FieldName, TableId);
        exit(FieldNo);
    end;

    // Sucht ein Feld nach Feldname oder Feldbezeichnung (Leerzeichen und Satzzeichen ignoriert, Gross-/Kleinschreibung egal).
    local procedure FindFieldNo(TableId: Integer; FieldName: Text): Integer
    var
        Field: Record Field;
        Wanted: Text;
    begin
        Wanted := Normalize(FieldName);
        Field.SetRange(TableNo, TableId);
        if Field.FindSet() then
            repeat
                if (Normalize(Field.FieldName) = Wanted) or (Normalize(Field."Field Caption") = Wanted) then
                    exit(Field."No.");
            until Field.Next() = 0;
        exit(0);
    end;

    local procedure Normalize(Value: Text): Text
    begin
        exit(DelChr(Value, '=', ' .-/()_').ToLower());
    end;
}
