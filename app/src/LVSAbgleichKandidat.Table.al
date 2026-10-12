// Kandidaten fuer fehlende Eintraege in "Herkunftsbelege Mandant" (Tabelle 50013).
// Wird beim Einlesen gefuellt, angelegt wird nur, was freigegeben ist.
table 50951 "LVS Abgleich Kandidat"
{
    Caption = 'Abgleich Kandidat';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Lfd. Nr.';
            AutoIncrement = true;
        }
        field(2; Mandant; Text[30])
        {
            Caption = 'Mandant';
        }
        field(3; "Wareneingang Nr."; Code[20])
        {
            Caption = 'Wareneingang Nr.';
        }
        field(4; "Bestellung Nr."; Code[20])
        {
            Caption = 'Bestellung Nr.';
        }
        field(5; Lagerort; Code[10])
        {
            Caption = 'Lagerort';
        }
        field(6; "Kreditor Nr."; Code[20])
        {
            Caption = 'Kreditor Nr.';
        }
        field(7; Buchungsdatum; Date)
        {
            Caption = 'Buchungsdatum';
        }
        field(8; Freigegeben; Boolean)
        {
            Caption = 'Freigegeben';
        }
        field(9; Status; Option)
        {
            Caption = 'Status';
            OptionMembers = Neu,Angelegt,Fehler;
            OptionCaption = 'Neu,Angelegt,Fehler';
        }
        field(10; Fehlermeldung; Text[2048])
        {
            Caption = 'Fehlermeldung';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Order; Mandant, "Bestellung Nr.", Lagerort)
        {
        }
    }
}
