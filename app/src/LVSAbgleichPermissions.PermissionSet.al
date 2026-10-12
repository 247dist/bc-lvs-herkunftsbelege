// Berechtigungen fuer den Herkunftsbeleg-Abgleich (Seite, Kandidatentabelle, Codeunit).
// Die Tabelle "Warehouse RequestTSO" (50013) liegt in einer anderen Erweiterung. Wer sie beschreiben darf,
// regelt deren Berechtigungssatz bzw. SUPER.
permissionset 50955 "LVS Abgleich"
{
    Caption = 'LVS Herkunftsbeleg-Abgleich';
    Assignable = true;

    Permissions =
        table "LVS Abgleich Kandidat" = X,
        tabledata "LVS Abgleich Kandidat" = RIMD,
        page "LVS Abgleich Kandidaten" = X,
        page "LVS Abgleich Eingabe" = X,
        page "LVS Abgleich Artikelfilter" = X,
        codeunit "LVS Source Doc Sync TITUS" = X,
        tabledata Company = R,
        tabledata Field = R,
        tabledata Item = R,
        tabledata "Purchase Header" = R,
        tabledata "Purchase Line" = R,
        tabledata "Warehouse Receipt Header" = R,
        tabledata "Warehouse Receipt Line" = R;
}
