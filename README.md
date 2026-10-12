# LVS Herkunftsbelege Abgleich

Business-Central-Erweiterung (AL) fuer den Mandanten **LVS-Logistik**. Legt fehlende Eintraege in
**Herkunftsbelege Mandant** (Tabelle 50013, Name "Warehouse RequestTSO") fuer Wareneingaenge aus **247** und
**Titus_GmbH** an, damit sie ueber die Aufgabenwarteschlange "TITUS GmbH <> LVS" (CU 50064) ins LVS gelangen.

Stand: Version 1.1.0.0, gebaut. In der Sandbox lief bisher nur der Vorgaengerstand (Testlauf), **noch nicht in Production**.

## Hintergrund

Wareneingaenge (WETI... in TITUS, WE24... in 247) werden nicht ins LVS uebertragen, wenn zur Bestellung kein Eintrag
in Tabelle 50013 existiert. Bisher wurde er per Konfigurationspaket (Paket HBMUe) von Hand nachgetragen.

Gefunden am 09.10.2026:
- Bei WETI1015336, WETI1015337 und WETI1015353 (Bestellungen BTI1089290, BTI1089304, BTI1089393) existieren die
  Eintraege, scheitern aber mit **"Sie muessen einen vorhandenen Artikel auswaehlen."** (Fehlermeldung in
  Tabelle 50013). Das behebt dieser Abgleich nicht, die Artikelursache ist offen.
- Fehlende Eintraege sind belegt bei B240000691 (247, Teillieferungen, Bestellung vom 02.03.2026). Die Ursache ist
  nicht geklaert (Vermutung: nachtraegliche Teillieferung zu bereits freigegebener Bestellung).
- Tabelle 50013 und CU 50064 liegen nicht in KatarGo (TSO-DATA), sondern in einer weiteren Erweiterung.

## Was die Erweiterung tut

Seite **Herkunftsbeleg-Abgleich** (Suche in BC):

- **Einlesen** fragt nach Buchungsdatum ab (Standard 14 Tage) und/oder Wareneingangsnummer. Mit Wareneingangsnummer
  gilt keine Altersgrenze, die Kandidaten sind sofort freigegeben. Nur mit Datum werden Kandidaten einzeln freigegeben.
  Ohne Datum ist eine Wareneingangsnummer Pflicht (Aelteres nur mit Eingabe).
- Kandidat = Bestellung und Lagerort eines Wareneingangs, fuer die in Tabelle 50013 kein Eintrag existiert.
  Ein WETI kann mehrere Bestellungen enthalten, je Bestellung ein Kandidat.
- **Freigegebene anlegen** legt den Eintrag an. Fehler stehen je Zeile. Vorhandene Eintraege bleiben unberuehrt.
- **Aufgabenwarteschlange:** Codeunit 50950 arbeitet nur freigegebene, noch nicht angelegte Kandidaten ab.

Werte des neuen Eintrags (Vorbild: manueller Eintrag B240000691 aus 247): Art Eingehend, Herkunftsart 39,
Untertyp 1, Herkunftsbeleg Einkaufsbestellung, Belegstatus Offen, Versandanweisung Teillieferung,
Fuer Art Kreditor, Fuer Nr. = Kreditor der Bestellung.

## Technik

- Objekte: Tabelle 50951, Seiten 50952/50953, Codeunit 50950 (ID-Bereich 50950-50979).
- Tabelle 50013 wird per RecordRef angesprochen, die Felder zur Laufzeit ueber den Feldnamen (Systemtabelle "Field")
  gefunden (Companyname, Type, LocationCode, SourceType, SourceSubtype, SourceNo, SourceDocument, DocumentStatus,
  ShippingAdvice, DestinationType, DestinationNo). Die Symbole der Tabelle sind nicht eingebunden.
- `RecRef.Insert(true)` loest die Trigger der Tabelle aus.

## Bauen und installieren

- Ordner `app` in VS Code oeffnen (AL-Erweiterung, Ordner als vertrauenswuerdig markieren).
- `AL: Download Symbols` gegen **SandboxTITUS** (Tenant 818efc40-1991-4545-9006-0f68581d03ac). `launch.json` liegt
  nicht im Git, Vorlage: Umgebung Sandbox, Name SandboxTITUS, `breakOnError: None`.
- Installieren mit `AL: Publish without debugging` (nicht F5, der Debugger haelt die Sandbox an).
- Eine als Dev installierte Erweiterung nicht zusaetzlich ueber "Erweiterung hochladen" einspielen, das schlaegt mit
  AVS0109 fehl.
- Auf der Kommandozeile baut `alc.exe` aus der AL-Erweiterung, wenn `DOTNET_ROOT` auf die von VS Code geladene
  .NET-Laufzeit zeigt (`%APPDATA%\Code\User\globalStorage\ms-dotnettools.vscode-dotnet-runtime\.dotnet\...`).

## Offen

- In der Sandbox sind alle Wareneingaenge aelter als 14 Tage, ein Test mit frischen Daten steht aus.
- Test des Anlegens (Version 1.1.0.0) in Sandbox und danach Production ist noch nicht erfolgt.
- Ursache der fehlenden Eintraege und der Artikelfehler (WETI1015336/7/53) klaeren.
- Aufgabenwarteschlange im LVS-Mandanten einrichten, erst nachdem der manuelle Weg ueber die Seite sauber laeuft.
