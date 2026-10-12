// Zeigt den Filter der fehlenden Artikelnummern zum Kopieren (zum Beispiel fuer ein Konfigurationspaket).
page 50954 "LVS Abgleich Artikelfilter"
{
    Caption = 'Fehlende Artikel (Filter)';
    PageType = StandardDialog;

    layout
    {
        area(Content)
        {
            field(InfoCtrl; InfoText)
            {
                ApplicationArea = All;
                Caption = 'Hinweis';
                Editable = false;
                ShowCaption = false;
            }
            field(FilterCtrl; FilterText)
            {
                ApplicationArea = All;
                Caption = 'Artikelfilter';
                MultiLine = true;
                ToolTip = 'Markieren mit Strg+A, kopieren mit Strg+C und als Filter fuer Nr. einsetzen.';
            }
        }
    }

    var
        InfoText: Text;
        FilterText: Text;

    procedure SetValues(NewInfoText: Text; NewFilterText: Text)
    begin
        InfoText := NewInfoText;
        FilterText := NewFilterText;
    end;
}
