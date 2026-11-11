// Bow-and-Bolt Adjuster - The Witcher 3 Remastered (5.0+)
// https://github.com/djdomi/witcher3-mods - License: AGPL-3.0 (SPDX: AGPL-3.0-only)
// Armbrust- und Bolzen-Einstellungen im Pausemenue: "Bow and Bolt"

// ---------- Einstellungen lesen ----------
function BBA_Get(grp : name, v : name, dflt : float) : float
{
	var s : string;
	s = theGame.GetInGameConfigWrapper().GetVarValue(grp, v);
	if (s == "" || s == "false") return dflt;
	if (s == "true") return 1.0;
	return StringToFloat(s, dflt);
}

function BBA_On() : bool
{
	var s : string;
	s = theGame.GetInGameConfigWrapper().GetVarValue('BBA_Bow', 'BBA_Enabled');
	return s != "false" && s != "0"; // leer = an (Standard)
}

// Schuesse vor dem Nachladen. -1 = Automatik (nie nachladen)
function BBA_Shots() : int
{
	var i : int;
	i = (int)BBA_Get('BBA_Bow', 'BBA_Shots', 0);
	switch (i)
	{
		case 1: return 2;
		case 2: return 3;
		case 3: return 5;
		case 4: return 10;
		case 5: return 25;
		case 6: return -1;
	}
	return 1;
}

function BBA_FireRate() : float   { return ClampF(BBA_Get('BBA_Bow', 'BBA_FireRate', 1), 1, 10); }
function BBA_ReloadRate() : float { return ClampF(BBA_Get('BBA_Bow', 'BBA_ReloadRate', 1), 1, 10); }
function BBA_BoltSpeed() : float  { return ClampF(BBA_Get('BBA_Bow', 'BBA_BoltSpeed', 1), 1, 1000); }

function BBA_BoltDamage() : float
{
	var i : int;
	i = (int)BBA_Get('BBA_Bow', 'BBA_BoltDamage', 0);
	switch (i)
	{
		case 1: return 2;
		case 2: return 5;
		case 3: return 10;
		case 4: return 25;
		case 5: return 50;
		case 6: return 100;
		case 7: return 500;
		case 8: return 1000;
		case 9: return 5000;
		case 10: return 10000;
		case 11: return 50000;
		case 12: return 100000;
	}
	return 1;
}

// ---------- Animations-Tempo (Schussrate / Nachladen) ----------
@addField(RangedWeapon)
var bbaSpeedId : int;

@addField(RangedWeapon)
var bbaSpeedOn : bool;

@addMethod(RangedWeapon)
function BBA_SpeedUp(mult : float)
{
	BBA_SpeedReset();
	if (!ownerPlayer || mult <= 1.01) return;
	bbaSpeedId = ownerPlayer.SetAnimationSpeedMultiplier(mult);
	bbaSpeedOn = true;
	AddTimer('BBA_SpeedTimer', 3.0 / mult, false);
}

@addMethod(RangedWeapon)
function BBA_SpeedReset()
{
	RemoveTimer('BBA_SpeedTimer');
	if (bbaSpeedOn && ownerPlayer)
		ownerPlayer.ResetAnimationSpeedMultiplier(bbaSpeedId);
	bbaSpeedOn = false;
}

@addMethod(RangedWeapon)
timer function BBA_SpeedTimer(dt : float, id : int)
{
	BBA_SpeedReset();
}

// Zielen/Schiessen schneller
@wrapMethod(RangedWeapon)
function SetBehaviorGraphVariables(varName : name, flag : bool, optional num : int)
{
	wrappedMethod(varName, flag, num);
	if (isPlayer && flag && BBA_On() && (varName == 'isAimingWeapon' || varName == 'isShootingWeapon'))
	{
		BBA_ApplyUnlimited();
		BBA_SpeedUp(BBA_FireRate());
	}
}

// Nachladen schneller
@wrapMethod(RangedWeapon)
function ReloadWeaponWithOrWithoutAnimIfNeeded() : bool
{
	var r : bool;
	r = wrappedMethod();
	if (r && isPlayer && BBA_On())
	{
		SetBehaviorVariable('animSpeedMult', BBA_ReloadRate());
		BBA_SpeedUp(BBA_ReloadRate());
	}
	return r;
}

// Beim Wegstecken alles zuruecksetzen
@wrapMethod(RangedWeapon)
function ResetAllSettings()
{
	BBA_SpeedReset();
	wrappedMethod();
}

// ---------- Schuesse vor dem Nachladen ----------
@wrapMethod(Crossbow)
function PlayOwnerReloadAnim() : bool
{
	var n : int;
	var r : bool;
	n = 1;
	if (BBA_On())
		n = BBA_Shots();
	if (n < 0)
		n = 1000000; // Automatik: praktisch nie nachladen
	shotCountLimit = n;
	r = wrappedMethod();
	return r;
}

// ---------- Bolzen-Geschwindigkeit ----------
@addField(W3BoltProjectile)
var bbaSpeedDone : bool;

@wrapMethod(W3BoltProjectile)
function ThrowProjectile(targetPosIn : Vector)
{
	if (GetOwner() == thePlayer)
	{
		BBA_ApplyUnlimited();
		BBA_TopUpEquippedBolt();
	}
	if (!bbaSpeedDone && GetOwner() == thePlayer && BBA_On())
	{
		projSpeed = projSpeed * BBA_BoltSpeed();
		bbaSpeedDone = true;
	}
	wrappedMethod(targetPosIn);
}

// ---------- Bolzen-Schaden ----------
@wrapMethod(W3DamageManagerProcessor)
function ProcessActionDamage_DealDamage()
{
	if (action && (W3BoltProjectile)action.causer && action.attacker == thePlayer && BBA_On())
		action.MultiplyAllDamageBy(BBA_BoltDamage());
	wrappedMethod();
}

// Standardwerte setzen, wenn noch leer oder 0 (Spiel-Standard = 1x)
function BBA_Default1( wrapper : CInGameConfigWrapper, v : name, val : string )
{
	var s : string;
	s = wrapper.GetVarValue( 'BBA_Bow', v );
	if ( s == "" || StringToFloat( s, 0 ) < 1 )
		wrapper.SetVarValue( 'BBA_Bow', v, val );
}

function BBA_SetDefaults( wrapper : CInGameConfigWrapper )
{
	if ( wrapper.GetVarValue( 'BBA_Bow', 'BBA_Enabled' ) == "" )
		wrapper.SetVarValue( 'BBA_Bow', 'BBA_Enabled', "true" );
	BBA_Default1( wrapper, 'BBA_FireRate', "1" );
	BBA_Default1( wrapper, 'BBA_ReloadRate', "1" );
	BBA_Default1( wrapper, 'BBA_BoltSpeed', "1" );
	if ( wrapper.GetVarValue( 'BBA_Bow', 'BBA_Shots' ) == "" )
		wrapper.SetVarValue( 'BBA_Bow', 'BBA_Shots', "0" );
	if ( wrapper.GetVarValue( 'BBA_Bow', 'BBA_Unlimited' ) == "" )
		wrapper.SetVarValue( 'BBA_Bow', 'BBA_Unlimited', "false" );
	if ( wrapper.GetVarValue( 'BBA_Bow', 'BBA_DefaultBolt' ) == "" )
		wrapper.SetVarValue( 'BBA_Bow', 'BBA_DefaultBolt', "0" );
	if ( wrapper.GetVarValue( 'BBA_Bow', 'BBA_BoltDamage' ) == "" )
		wrapper.SetVarValue( 'BBA_Bow', 'BBA_BoltDamage', "0" );
}

// ---- Pausemenue-Eintrag "Bow and Bolt" (wie Witcher3Cheats: eigener Punkt mit festem Namen) ----
function BBA_BuildMenuOptions( storage : CScriptedFlashValueStorage ) : CScriptedFlashArray
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
		if ( wrapper.GetGroupName( i ) == 'BBA_Bow' )
			groupId = i;
	}
	if ( groupId < 0 )
		return options;

	BBA_SetDefaults( wrapper );

	root = storage.CreateTempFlashObject();
	root.SetMemberFlashArray( "subElements", options );
	IngameMenu_FillSubMenuOptionsList( storage, groupId, 'BBA_Bow', root );
	return root.GetMemberFlashArray( "subElements" );
}

@wrapMethod(IngameMenuStructureCreator)
function PopulateMenuData() : CScriptedFlashArray
{
	var src : CScriptedFlashArray;
	var dst : CScriptedFlashArray;
	var menuItem : CScriptedFlashObject;
	var bbaItem : CScriptedFlashObject;
	var i : int;
	var after : string;
	var placed : bool;

	src = wrappedMethod();
	if ( !parentMenu || parentMenu.isMainMenu )
		return src;

	bbaItem = CreateMenuItem( "bba_menu", "Bow and Bolt", NameToFlashUInt( 'BBAMenu' ), IGMActionType_MenuLastHolder, false, "Bow and Bolt" );
	bbaItem.SetMemberFlashString( "label", "Bow and Bolt" );
	bbaItem.SetMemberFlashString( "listTitle", "Bow and Bolt" );
	bbaItem.SetMemberFlashArray( "subElements", BBA_BuildMenuOptions( m_flashValueStorage ) );

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
			dst.PushBackFlashObject( bbaItem );
			placed = true;
		}
	}
	if ( !placed )
		dst.PushBackFlashObject( bbaItem );

	return dst;
}

// ---------- Unbegrenzte Bolzen + Standard-Bolzen ----------
function BBA_Unlimited() : bool
{
	return BBA_On() && theGame.GetInGameConfigWrapper().GetVarValue('BBA_Bow', 'BBA_Unlimited') == "true";
}

// Spiel verbraucht keinen Bolzen, wenn dieser (Spiel-eigene) Fakt existiert
function BBA_ApplyUnlimited()
{
	// Den Fakt nur entfernen, wenn WIR ihn gesetzt haben (andere Mods nicht stoeren)
	if (BBA_Unlimited())
	{
		if (!FactsDoesExist("debug_fact_inf_bolts"))
		{
			FactsAdd("debug_fact_inf_bolts");
			FactsAdd("bba_inf_bolts_added");
		}
	}
	else if (FactsDoesExist("bba_inf_bolts_added"))
	{
		FactsRemove("debug_fact_inf_bolts");
		FactsRemove("bba_inf_bolts_added");
	}
}

// Mit 'unlimited': ausgeruesteten Spezial-Bolzen auf mindestens 10 Stueck auffuellen
function BBA_TopUpEquippedBolt()
{
	var p : W3PlayerWitcher;
	var cur : SItemUniqueId;
	var n : name;
	var have : int;

	p = GetWitcherPlayer();
	if (!p || !BBA_Unlimited() || !p.GetItemEquippedOnSlot(EES_Bolt, cur))
		return;
	n = p.inv.GetItemName(cur);
	if (n == 'Bodkin Bolt' || n == 'Harpoon Bolt')
		return;
	have = p.inv.GetItemQuantityByName(n);
	if (have < 10)
		p.inv.AddAnItem(n, 10 - have, true, true);
}

function BBA_DefaultBoltName() : name
{
	var i : int;
	if (!BBA_On()) return '';
	i = (int)BBA_Get('BBA_Bow', 'BBA_DefaultBolt', 0);
	switch (i)
	{
		case 1: return 'Blunt Bolt';
		case 2: return 'Broadhead Bolt';
		case 3: return 'Target Point Bolt';
		case 4: return 'Split Bolt';
		case 5: return 'Explosive Bolt';
	}
	return '';
}

@addField(W3PlayerWitcher)
var bbaBoltBusy : bool;

// Gewaehlten Standard-Bolzen anlegen (nur mit Armbrust, nicht unter Wasser)
function BBA_EquipDefaultBolt()
{
	var p : W3PlayerWitcher;
	var boltName : name;
	var ids : array<SItemUniqueId>;
	var cur : SItemUniqueId;
	var weapon : SItemUniqueId;
	var curName : name;

	p = GetWitcherPlayer();
	if (!p || p.bbaBoltBusy)
		return;
	boltName = BBA_DefaultBoltName();
	if (boltName == '')
		return;
	if (!p.GetItemEquippedOnSlot(EES_RangedWeapon, weapon) || !p.inv.IsItemCrossbow(weapon))
		return;
	if (p.ShouldUseInfiniteWaterBolts())
		return;
	if (p.GetItemEquippedOnSlot(EES_Bolt, cur))
	{
		curName = p.inv.GetItemName(cur);
		if (curName != 'Bodkin Bolt' && curName != 'Harpoon Bolt')
			return; // Spieler hat bewusst einen Bolzen gewaehlt
	}

	// mit 'unlimited' immer mindestens 10 Stueck im Inventar, damit das Spiel nachladen kann
	if (BBA_Unlimited() && p.inv.GetItemQuantityByName(boltName) < 10)
		p.inv.AddAnItem(boltName, 10 - p.inv.GetItemQuantityByName(boltName), true, true);
	ids = p.inv.GetItemsByName(boltName);
	if (ids.Size() == 0)
		return;

	p.bbaBoltBusy = true;
	p.EquipItem(ids[0], EES_Bolt);
	p.bbaBoltBusy = false;
}

// Spiel wechselt auf Standardbolzen, wenn Bolzen leer sind -> gewaehlten wieder anlegen
@wrapMethod(W3PlayerWitcher)
function UnequipItemFromSlot(slot : EEquipmentSlots, optional reequipped : bool) : bool
{
	var r : bool;
	r = wrappedMethod(slot, reequipped);
	if (slot == EES_Bolt && !reequipped)
		BBA_EquipDefaultBolt();
	return r;
}

// Nach Dialogen/Zwischensequenzen wechselt das Spiel auf Standardbolzen
@wrapMethod(CR4Game)
function SetIsDialogOrCutscenePlaying(b : bool)
{
	wrappedMethod(b);
	if (!b)
		BBA_EquipDefaultBolt();
}

// Aenderung im Menue sofort anwenden
@wrapMethod(CR4Game)
function OnConfigValueChanged(varName : name, value : string)
{
	wrappedMethod(varName, value);
	if (varName == 'BBA_Unlimited' || varName == 'BBA_Enabled')
		BBA_ApplyUnlimited();
	if (varName == 'BBA_DefaultBolt' || varName == 'BBA_Enabled')
		BBA_EquipDefaultBolt();
}
