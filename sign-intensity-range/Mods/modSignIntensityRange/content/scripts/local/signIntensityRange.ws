// Sign Intensity and Range - The Witcher 3 Remastered (5.0+)
// https://github.com/djdomi/witcher3-mods - License: AGPL-3.0 (SPDX: AGPL-3.0-only)
// Einstellungen im Pausemenue: "Mod Menu" > "Sign Intensity and Range"

// ---------- Einstellungen lesen ----------
function SIR_Get(v : name, dflt : float) : float
{
	var s : string;
	s = theGame.GetInGameConfigWrapper().GetVarValue('SIR_Signs', v);
	if (s == "") return dflt;
	return StringToFloat(s, dflt);
}

function SIR_On() : bool
{
	var s : string;
	s = theGame.GetInGameConfigWrapper().GetVarValue('SIR_Signs', 'SIR_Enabled');
	return s != "false" && s != "0"; // leer = an (Standard)
}

// Faktor fuer Intensitaet (1.0 = normal)
function SIR_Power() : float { return ClampF(SIR_Get('SIR_Power', 100), 100, 1000) / 100.0; }
// Faktor fuer Reichweite (1.0 = normal)
function SIR_Range() : float { return ClampF(SIR_Get('SIR_Range', 100), 100, 500) / 100.0; }

// ---------- Intensitaet: alle 5 Zeichen ----------
@wrapMethod(W3PlayerWitcher) function GetTotalSignSpellPower(signSkill : ESkill) : SAbilityAttributeValue
{
	var sp : SAbilityAttributeValue;
	sp = wrappedMethod(signSkill);
	if (SIR_On())
		sp.valueMultiplicative *= SIR_Power();
	return sp;
}

// ---------- Reichweite: Aard und Igni ----------
@addField(W3SignEntity) var sirRangeDone : bool;

@wrapMethod(W3SignEntity) function GetSignStats()
{
	var aard : W3AardEntity;
	var igni : W3IgniEntity;
	var aAsp : SAardAspect;
	var iAsp : SIgniAspect;
	var i : int;
	var m : float;

	wrappedMethod();

	if (sirRangeDone || !SIR_On()) return;
	if (owner.GetActor() != thePlayer) return; // nur Geralt
	m = SIR_Range();
	if (m <= 1.0) return;

	aard = (W3AardEntity)this;
	if (aard)
	{
		for (i = 0; i < aard.aspects.Size(); i += 1)
		{
			aAsp = aard.aspects[i];
			aAsp.distance *= m;
			aAsp.distanceUpgrade1 *= m;
			aAsp.distanceUpgrade2 *= m;
			aAsp.distanceUpgrade3 *= m;
			aard.aspects[i] = aAsp;
		}
		sirRangeDone = true;
		return;
	}

	igni = (W3IgniEntity)this;
	if (igni)
	{
		for (i = 0; i < igni.aspects.Size(); i += 1)
		{
			iAsp = igni.aspects[i];
			iAsp.distance *= m;
			iAsp.upgradedDistance *= m;
			igni.aspects[i] = iAsp;
		}
		sirRangeDone = true;
	}
}

// ---------- Reichweite: Yrden-Kreis ----------
@addField(W3YrdenEntity) var sirYrdenScaled : bool;

@wrapMethod(W3YrdenEntity) function GetSignStats()
{
	var trigger : CComponent;
	var m : float;

	wrappedMethod();

	if (!SIR_On()) return;
	if (owner.GetActor() != thePlayer) return; // nur Geralt
	m = SIR_Range();
	if (m <= 1.0) return;

	baseModeRange *= m; // wird bei jedem Aufruf neu berechnet

	if (!sirYrdenScaled)
	{
		trigger = GetComponent("Slowdown");
		if (trigger)
			trigger.SetScale(trigger.GetLocalScale() * m);
		sirYrdenScaled = true;
	}
}

// ---------- Standardwerte (leere Regler zeigen sonst 0) ----------
function SIR_SetDefaults( wrapper : CInGameConfigWrapper )
{
	var s : string;
	if ( wrapper.GetVarValue( 'SIR_Signs', 'SIR_Enabled' ) == "" )
		wrapper.SetVarValue( 'SIR_Signs', 'SIR_Enabled', "true" );
	s = wrapper.GetVarValue( 'SIR_Signs', 'SIR_Power' );
	if ( s == "" || StringToFloat( s, 0 ) < 100 )
		wrapper.SetVarValue( 'SIR_Signs', 'SIR_Power', "100" );
	s = wrapper.GetVarValue( 'SIR_Signs', 'SIR_Range' );
	if ( s == "" || StringToFloat( s, 0 ) < 100 )
		wrapper.SetVarValue( 'SIR_Signs', 'SIR_Range', "100" );
}

// ---------- Optionen der XML-Gruppe fuer das Menue ----------
function SIR_BuildMenuOptions( storage : CScriptedFlashValueStorage ) : CScriptedFlashArray
{
	var wrapper : CInGameConfigWrapper;
	var groupId : int;
	var i : int;
	var root : CScriptedFlashObject;
	var options : CScriptedFlashArray;

	options = storage.CreateTempFlashArray();
	wrapper = (CInGameConfigWrapper)theGame.GetInGameConfigWrapper();
	if ( !wrapper )
		return options;

	groupId = -1;
	for ( i = 0; i < wrapper.GetGroupsNum(); i += 1 )
	{
		if ( wrapper.GetGroupName( i ) == 'SIR_Signs' )
			groupId = i;
	}
	if ( groupId < 0 )
		return options;

	SIR_SetDefaults( wrapper );

	root = storage.CreateTempFlashObject();
	root.SetMemberFlashArray( "subElements", options );
	IngameMenu_FillSubMenuOptionsList( storage, groupId, 'SIR_Signs', root );
	return root.GetMemberFlashArray( "subElements" );
}

// ---------- Gemeinsames "Mod Menu" (id "djdomi_modmenu") ----------
// Jede unserer Mods haengt sich dort als eigenes Untermenue ein.
// Gibt es das "Mod Menu" schon (von einer anderen unserer Mods), wird es benutzt.
@wrapMethod(IngameMenuStructureCreator)
function PopulateMenuData() : CScriptedFlashArray
{
	var src : CScriptedFlashArray;
	var dst : CScriptedFlashArray;
	var menuItem : CScriptedFlashObject;
	var holder : CScriptedFlashObject;
	var modItem : CScriptedFlashObject;
	var subs : CScriptedFlashArray;
	var i : int;
	var after : string;
	var placed : bool;

	src = wrappedMethod();
	if ( !parentMenu || parentMenu.isMainMenu )
		return src;

	modItem = CreateMenuItem( "sir_menu", "Sign Intensity and Range", NameToFlashUInt( 'SIRMenu' ), IGMActionType_MenuLastHolder, false, "Sign Intensity and Range" );
	modItem.SetMemberFlashString( "label", "Sign Intensity and Range" );
	modItem.SetMemberFlashString( "listTitle", "Sign Intensity and Range" );
	modItem.SetMemberFlashArray( "subElements", SIR_BuildMenuOptions( m_flashValueStorage ) );

	// vorhandenes "Mod Menu" suchen
	for ( i = 0; i < src.GetLength(); i += 1 )
	{
		menuItem = src.GetElementFlashObject( i );
		if ( menuItem && menuItem.GetMemberFlashString( "id" ) == "djdomi_modmenu" )
		{
			subs = menuItem.GetMemberFlashArray( "subElements" );
			subs.PushBackFlashObject( modItem );
			menuItem.SetMemberFlashArray( "subElements", subs );
			return src;
		}
	}

	// sonst neu anlegen
	holder = CreateMenuItem( "djdomi_modmenu", "Mod Menu", NameToFlashUInt( 'DjdomiModMenu' ), IGMActionType_MenuHolder, false, "Mod Menu" );
	holder.SetMemberFlashString( "label", "Mod Menu" );
	holder.SetMemberFlashString( "listTitle", "Mod Menu" );
	subs = m_flashValueStorage.CreateTempFlashArray();
	subs.PushBackFlashObject( modItem );
	holder.SetMemberFlashArray( "subElements", subs );

	// nach "Cheats" einfuegen, sonst nach "Einstellungen"
	after = "mainmenu_options";
	for ( i = 0; i < src.GetLength(); i += 1 )
	{
		menuItem = src.GetElementFlashObject( i );
		if ( menuItem && menuItem.GetMemberFlashString( "id" ) == "wqol_cheats" )
			after = "wqol_cheats";
	}

	dst = m_flashValueStorage.CreateTempFlashArray();
	placed = false;
	for ( i = 0; i < src.GetLength(); i += 1 )
	{
		menuItem = src.GetElementFlashObject( i );
		dst.PushBackFlashObject( menuItem );
		if ( !placed && menuItem && menuItem.GetMemberFlashString( "id" ) == after )
		{
			dst.PushBackFlashObject( holder );
			placed = true;
		}
	}
	if ( !placed )
		dst.PushBackFlashObject( holder );

	return dst;
}
