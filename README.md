# LVS Herkunftsbelege Abgleich

Business-Central-Erweiterung (AL) fuer den Mandanten **LVS-Logistik**. Legt fehlende Eintraege in
**Herkunftsbelege Mandant** (Tabelle 50013, Name "Warehouse RequestTSO") fuer Wareneingaenge aus **247** und
**Titus_GmbH** an, damit sie ueber die Aufgabenwarteschlange "TITUS GmbH <> LVS" (CU 50064) ins LVS gelangen.

Stand: Version 1.6.0.0, seit 13.10.2026 in Production.

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

## Neue Erkenntnis (12.10.2026)

Die Fehleraufrufliste der drei Eintraege (WETI1015336/7/53) zeigt: TSO scheitert nicht beim Anlegen des Eintrags,
sondern spaeter in der Uebertragung. CU 50064 `WhseCreateWhseDocumentsTSO` ruft CU 50015
`WhseQueueTransferOrderTSO` und CU 50063 `WhseCreateTransferOrderTSO` auf, die aus der Bestellung einen
**Umlagerungsauftrag** erzeugen. Beim Setzen der Artikelnr. an der Umlagerungszeile (`Transfer Line.GetItemNo`)
wird der Artikel nicht gefunden: "Sie muessen einen vorhandenen Artikel auswaehlen." Ursache war die
Artikelsynchronisation TITUS -> LVS, die seit dem 07.10.2026 im Fehler stand (Sync lief am 12.10. noch).
Nach dem Sync muss die Fehlermeldung am Eintrag in Tabelle 50013 zurueckgesetzt werden, damit TSO erneut verarbeitet.

### Stand der Ursachensuche (12.10.2026, Production)

- Fehlende Artikel im LVS-Mandanten: 75 von 128 Artikeln der drei Bestellungen. Vorhanden ist ein Artikel vom
  06.10.2026, fehlend sind Artikel vom 08.10.2026 (Kollektion Homeboy Q3-2026). Die Artikelsynchronisation
  TITUS -> LVS stand seit dem 07.10. im Fehler, lief nach dem Neustart fehlerfrei, hat aber nicht alle uebertragen.
- Der Farbsync (`bc-data-sync`, Repo `247dist/bc-data-sync`) ist **nicht** die Ursache: `bc-sync diff` am 12.10.
  zeigt fuer 247 und LVS-Logistik 0 fehlende Farben und 0 Feldabweichungen. `bc-data-sync` synchronisiert Farben
  und den Kreditor-Abgleich, keine Artikel.
- Der Artikelsync laeuft vermutlich im LS-Central-Scheduler (Jobs ITEMREPL, WEBREPL, ARTREF). Offen: welcher Job es ist
  und warum er die Artikel nach dem 07.10. nicht nachholt. Vermutung (ungeprueft): der Sync uebertraegt nur
  geaenderte Artikel ab seinem Stand-Zeiger. Alle 75 Artikel wurden in TITUS geaendert und zurueckgeaendert, das
  Ergebnis der Pruefung steht noch aus.
- Aufruf der Nummernsuche: Aktion "Artikel im LVS pruefen" in der Seite "Herkunftsbeleg-Abgleich".

### Fall WE24100645/46/47 (13.10.2026)

Zu den Wareneingaengen in 247 (Bestellungen B240000720, B240000762, B240000745) gab es keinen Eintrag in Tabelle 50013.
Die Erweiterung (bis 1.5.0.0) legte sie an, TSO verarbeitete sie aber nicht: In der Spalte "Herkunftsbeleg" stand
"2" bzw. leer statt "Einkaufsbestellung". Ursache: Der Wert der Optionsfelder wurde als Zahl geschrieben, abgeleitet aus der
Optionsliste des Konfigurationspakets. Diese Nummern sind nicht die internen Werte des Feldes. **Ab 1.6.0.0** kopiert
das Anlegen alle Werte von einem fertigen Eintrag (mit gesetztem "Befindet sich im LVS"), die Aktion "Herkunftsbeleg
korrigieren" repariert vorhandene Eintraege. Mit dieser Aktion (1.6.0.0, Production) wurden die drei Eintraege
korrigiert, danach waren die Umlagerungsauftraege WE24100645/46/47 im LVS (VIRTUELL -> ZENTRAL, Freigegeben).
Das Anlegen aus der Vorlage (neue Eintraege ab 1.6.0.0) ist damit noch nicht an einem echten Fall geprueft, die
Korrektur aber schon (sie nutzt dieselbe Vorlage).

Lehre: Optionswerte an fremden Tabellen nie aus Listenindex oder Konfigurationspaket ableiten, sondern von einem
vorhandenen Datensatz uebernehmen und gegen die Anzeige pruefen.

## Was die Erweiterung tut

Seite **Herkunftsbeleg-Abgleich** (Suche in BC):

- **Einlesen** fragt nach Buchungsdatum ab (Standard 14 Tage) und/oder Wareneingangsnummer. Mit Wareneingangsnummer
  gilt keine Altersgrenze, die Kandidaten sind sofort freigegeben. Nur mit Datum werden Kandidaten einzeln freigegeben.
  Ohne Datum ist eine Wareneingangsnummer Pflicht (Aelteres nur mit Eingabe).
- **Bestellung Nr. (und optional Mandant)** legt Kandidaten direkt aus der Bestellung an, je Lagerort der Artikelzeilen,
  sofort freigegeben und ohne Altersgrenze. Das ist der Weg fuer bereits **gebuchte** Wareneingaenge, deren WETI es
  nicht mehr gibt. Die Bestellung hat Vorrang vor Datum und Wareneingang.
- **Artikel im LVS pruefen** (nur lesend): zeigt zu einer oder mehreren Bestellungen, welche Artikel im aktuellen
  Mandanten (LVS-Logistik) fehlen oder gesperrt sind. Hintergrund unten ("Neue Erkenntnis").
- Kandidat = Bestellung und Lagerort eines Wareneingangs, fuer die in Tabelle 50013 kein Eintrag existiert.
  Ein WETI kann mehrere Bestellungen enthalten, je Bestellung ein Kandidat.
- **Fehlende Artikel (Filter)** (nur lesend): gibt die Nummern der fehlenden Artikel als Filter `A|B|C` zum Kopieren
  aus (fuer ein Konfigurationspaket). Aktuell etwa 75 Artikel der drei Bestellungen.
- **Herkunftsbeleg korrigieren**: setzt das Feld Herkunftsbeleg bei vorhandenen Eintraegen zu angegebenen Bestellungen auf
  den Wert eines fertigen Eintrags (Einkaufsbestellung).
- **Fehler zuruecksetzen**: leert Fehlermeldung und Fehleraufrufliste der Eintraege in Tabelle 50013 zu angegebenen
  Bestellungen (nach Rueckfrage mit Anzahl, ohne Trigger). TSO verarbeitet sie danach erneut (am 12.10. bestaetigt:
  derselbe Fehler kam zurueck, solange die Artikel fehlten).
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
- Test des Anlegens (Version 1.5.0.0) in Sandbox und danach Production ist noch nicht erfolgt.
- Ursache der fehlenden Eintraege und der Artikelfehler (WETI1015336/7/53) klaeren.
- Aufgabenwarteschlange im LVS-Mandanten einrichten, erst nachdem der manuelle Weg ueber die Seite sauber laeuft.
