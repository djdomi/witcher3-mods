# Mod Menu Template

English · [Deutsch](#deutsch)

Template mod for **The Witcher 3 Remastered (version 5.0 or newer)**.
It adds the shared **Mod Menu** to the pause menu. Every mod from this repo hangs itself in there as its own sub menu.

Repository: https://github.com/djdomi/witcher3-mods
License: AGPL-3.0

## What you see in game

```
Pause menu
  Mod Menu
    Template Mod
      Mod enabled
      Show message after loading
      Example slider (1 to 10)
      Example list
    (other mods from this repo)
```

After loading a save, the template shows a short message at the top of the screen. You can switch that off in the menu.

The menu only shows in the **pause menu during the game**, not on the start screen.
"Mod Menu" is not the same as the game's own "Mods" entry (the mod browser of version 5.0).

## Install

Install the ZIP with **Vortex**. Nothing else is needed.

## Files

```
Mods\modMenuTemplate\content\scripts\local\modMenuTemplate.ws   the script
bin\config\r4game\user_config_matrix\pc\modMenuTemplate.xml     the menu entries
bin\config\base\modmenutemplate.ini                             the default values
```

## Make your own mod from the template

1. Copy the whole folder `mod-menu-template` and give it a new name, for example `my-mod`.
2. Rename the three files above, for example `modMyMod.ws`, `modMyMod.xml`, `mymod.ini`. Also rename the folder `Mods\modMenuTemplate` to `Mods\modMyMod`.
3. Pick a short prefix that no other mod uses, for example `MM_`.
4. In all three files replace:

```
TPL_            ->  MM_
'TPLMenu'       ->  'MMMenu'
"tpl_menu"      ->  "mm_menu"
Template Mod    ->  My Mod
```

5. **Never** change these three. All mods share them:

```
"djdomi_modmenu"
"Mod Menu"
'DjdomiModMenu'
```

### Add a new switch (example)

Add one line to the XML, inside `<VisibleVars>`:

```xml
<Var id="MM_GodMode" displayName="God mode" displayType="TOGGLE" tags="nonLocalizedName"/>
```

Add one line to the INI:

```ini
MM_GodMode=false
```

Add one line to the function `MM_SetDefaults` in the .ws file:

```
	if ( wrapper.GetVarValue( 'MM_Main', 'MM_GodMode' ) == "" ) wrapper.SetVarValue( 'MM_Main', 'MM_GodMode', "false" );
```

Use it in your code:

```
	if ( MM_On( 'MM_GodMode' ) )
	{
		// your feature here
	}
```

### Other menu types

```xml
<Var id="MM_Speed" displayName="Speed (1 to 10)" displayType="SLIDER;1;10;9" tags="nonLocalizedName"/>

<Var id="MM_Mode" displayName="Mode" displayType="OPTIONS" tags="nonLocalizedName;nonLocalized;customNames">
	<OptionsArray>
		<Option id="0" displayName="Off"/>
		<Option id="1" displayName="On"/>
	</OptionsArray>
</Var>

<Var id="MM_Sep1" displayName="" displayType="SUBTLE_SEPARATOR"/>
```

SLIDER means: lowest value; highest value; number of steps.

## Known problems with version 5.0

| Problem | What to do |
|---|---|
| Two mods use the same global function name | Error at game start. Always put your prefix in front of every function name. |
| Wrong number of parameters in a `@wrapMethod` | Error at game start. Copy the first line of the original function exactly from the game files. |
| `wrappedMethod` called twice in one wrapper | The original code runs twice. Call it **exactly once**. |
| Many mods wrap the same function | This is fine. Each wrapper calls `wrappedMethod` once and they stack. |
| Event wrapper returns too early | Write `return false;` not `return;`. |
| `def` as a variable name | Reserved word. Use another name. |
| Menu entries are empty | Use `tags="nonLocalizedName"`. For lists also `nonLocalized;customNames`. |
| Slider shows 0 | The value was never set. Add it to the INI and to `SetDefaults`. |
| Menu is broken for all mods | A copy of an XML file (for example `.bak`) is in the menu folder. The game reads every file there. Delete the copy. |
| Umlauts look wrong | Save all files as **UTF-8**. |
| Old install guides | Do **not** edit `dx11filelist.txt` or `dx12filelist.txt`. Version 5.0 finds the XML by itself. No `install.bat` needed. |
| Script is not loaded | The folder must be exactly `Mods\<modname>\content\scripts\local\`. |

Where to find the original game scripts:

```
<game folder>\content\content0\scripts\
```

## Finding errors

1. Start the game. If a script is wrong, the game shows a **red error list right at the start**. It names the file and the line. Take a photo or screenshot of it.
2. The lines that start with `Warning [content0]` come from the game itself. You can ignore them.
3. A log file is optional. Add `-debugscripts` to the game start options. The game then may write the file:

```
C:\Users\<your name>\Documents\The Witcher 3\scriptslog.txt
```

This file was not yet checked with version 5.0.

## Status

The menu code is the same as in the other mods of this repo. The template itself is **not yet tested in game**.

---

## Deutsch

Vorlage (Template) für **The Witcher 3 Remastered (Version 5.0 oder neuer)**.
Sie fügt das gemeinsame **Mod Menu** ins Pausemenü ein. Jede Mod aus diesem Repo hängt sich dort als eigenes Untermenü ein.

Repository: https://github.com/djdomi/witcher3-mods
Lizenz: AGPL-3.0

## Was du im Spiel siehst

```
Pausemenü
  Mod Menu
    Template Mod
      Mod enabled
      Show message after loading
      Example slider (1 to 10)
      Example list
    (andere Mods aus diesem Repo)
```

Nach dem Laden eines Spielstands zeigt die Vorlage oben eine kurze Nachricht. Das kannst du im Menü ausschalten.

Das Menü gibt es nur im **Pausemenü im Spiel**, nicht im Startbildschirm.
"Mod Menu" ist nicht der Eintrag "Mods" vom Spiel selbst (der Mod Browser von Version 5.0).

## Installation

ZIP mit **Vortex** installieren. Sonst ist nichts nötig.

## Dateien

```
Mods\modMenuTemplate\content\scripts\local\modMenuTemplate.ws   das Skript
bin\config\r4game\user_config_matrix\pc\modMenuTemplate.xml     die Menüeinträge
bin\config\base\modmenutemplate.ini                             die Standardwerte
```

## Eigene Mod aus der Vorlage bauen

1. Kopiere den ganzen Ordner `mod-menu-template` und gib ihm einen neuen Namen, zum Beispiel `my-mod`.
2. Benenne die drei Dateien oben um, zum Beispiel `modMyMod.ws`, `modMyMod.xml`, `mymod.ini`. Benenne auch den Ordner `Mods\modMenuTemplate` in `Mods\modMyMod` um.
3. Such dir ein kurzes Kürzel aus, das keine andere Mod nutzt, zum Beispiel `MM_`.
4. Ersetze in allen drei Dateien:

```
TPL_            ->  MM_
'TPLMenu'       ->  'MMMenu'
"tpl_menu"      ->  "mm_menu"
Template Mod    ->  My Mod
```

5. Diese drei **niemals** ändern. Alle Mods teilen sie:

```
"djdomi_modmenu"
"Mod Menu"
'DjdomiModMenu'
```

### Neuen Schalter einbauen (Beispiel)

Eine Zeile in die XML, innerhalb von `<VisibleVars>`:

```xml
<Var id="MM_GodMode" displayName="God mode" displayType="TOGGLE" tags="nonLocalizedName"/>
```

Eine Zeile in die INI:

```ini
MM_GodMode=false
```

Eine Zeile in die Funktion `MM_SetDefaults` in der .ws Datei:

```
	if ( wrapper.GetVarValue( 'MM_Main', 'MM_GodMode' ) == "" ) wrapper.SetVarValue( 'MM_Main', 'MM_GodMode', "false" );
```

So nutzt du den Schalter im Code:

```
	if ( MM_On( 'MM_GodMode' ) )
	{
		// deine Funktion hier
	}
```

### Andere Menütypen

```xml
<Var id="MM_Speed" displayName="Speed (1 to 10)" displayType="SLIDER;1;10;9" tags="nonLocalizedName"/>

<Var id="MM_Mode" displayName="Mode" displayType="OPTIONS" tags="nonLocalizedName;nonLocalized;customNames">
	<OptionsArray>
		<Option id="0" displayName="Off"/>
		<Option id="1" displayName="On"/>
	</OptionsArray>
</Var>

<Var id="MM_Sep1" displayName="" displayType="SUBTLE_SEPARATOR"/>
```

SLIDER heißt: kleinster Wert; größter Wert; Anzahl Schritte.

## Bekannte Probleme mit Version 5.0

| Problem | Was tun |
|---|---|
| Zwei Mods haben denselben globalen Funktionsnamen | Fehler beim Spielstart. Setze dein Kürzel vor jeden Funktionsnamen. |
| Falsche Anzahl Parameter bei `@wrapMethod` | Fehler beim Spielstart. Kopiere die erste Zeile der Originalfunktion genau aus den Spieldateien. |
| `wrappedMethod` zweimal im selben Wrapper | Der Originalcode läuft doppelt. Rufe es **genau einmal** auf. |
| Viele Mods wrappen dieselbe Funktion | Das ist in Ordnung. Jeder Wrapper ruft `wrappedMethod` einmal auf, dann stapeln sie sich. |
| Event Wrapper steigt zu früh aus | Schreibe `return false;` und nicht `return;`. |
| `def` als Variablenname | Reserviertes Wort. Nimm einen anderen Namen. |
| Menüeinträge sind leer | Nutze `tags="nonLocalizedName"`. Bei Listen zusätzlich `nonLocalized;customNames`. |
| Schieberegler zeigt 0 | Der Wert wurde nie gesetzt. Trage ihn in die INI und in `SetDefaults` ein. |
| Menü ist bei allen Mods kaputt | Eine Kopie einer XML (zum Beispiel `.bak`) liegt im Menüordner. Das Spiel liest jede Datei dort. Kopie löschen. |
| Umlaute sehen falsch aus | Alle Dateien als **UTF-8** speichern. |
| Alte Anleitungen | `dx11filelist.txt` oder `dx12filelist.txt` **nicht** ändern. Version 5.0 findet die XML selbst. Keine `install.bat` nötig. |
| Skript wird nicht geladen | Der Ordner muss genau `Mods\<modname>\content\scripts\local\` heißen. |

Hier liegen die Original Skripte vom Spiel:

```
<Spielordner>\content\content0\scripts\
```

## Fehler finden

1. Starte das Spiel. Ist ein Skript falsch, zeigt das Spiel **gleich am Anfang eine rote Fehlerliste**. Dort stehen Datei und Zeile. Mach ein Foto oder einen Screenshot davon.
2. Zeilen mit `Warning [content0]` kommen vom Spiel selbst. Die kannst du ignorieren.
3. Eine Logdatei ist optional. Füge `-debugscripts` zu den Startoptionen vom Spiel hinzu. Das Spiel schreibt dann eventuell die Datei:

```
C:\Users\<dein Name>\Documents\The Witcher 3\scriptslog.txt
```

Diese Datei wurde mit Version 5.0 noch nicht geprüft.

## Status

Der Menücode ist derselbe wie in den anderen Mods aus diesem Repo. Die Vorlage selbst ist **noch nicht im Spiel getestet**.
