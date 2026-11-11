// Godlike Aerondight - The Witcher 3 Remastered (5.0+)
// https://github.com/djdomi/witcher3-mods - License: AGPL-3.0 (SPDX: AGPL-3.0-only)
// Aerondight wird goettlich. Pausemenue > Mod Menu > Godlike Aerondight

// ---------- Einstellungen lesen ----------
function GA_Var(v : name) : string
{
	return theGame.GetInGameConfigWrapper().GetVarValue('GA_Main', v);
}

// Schalter: leer = Standard
function GA_Is(v : name, dflt : bool) : bool
{
	var s : string;
	s = GA_Var(v);
	if (s == "") return dflt;
	return s != "false" && s != "0";
}

function GA_Num(v : name, dflt : float) : float
{
	var s : string;
	s = GA_Var(v);
	if (s == "" || s == "false") return dflt;
	return StringToFloat(s, dflt);
}

function GA_On() : bool { return GA_Is('GA_Enabled', true); }
function GA_Mult() : float { return ClampF(GA_Num('GA_DamageMult', 1), 1, 100); }
function GA_MaxDmg() : float { return ClampF(GA_Num('GA_MaxDmg', 0), 0, 20000); }

// Mindestschaden ist nie hoeher als Hoechstschaden
function GA_MinDmg() : float
{
	var lo, hi : float;
	lo = ClampF(GA_Num('GA_MinDmg', 0), 0, 10000);
	hi = GA_MaxDmg();
	if (hi > 0 && lo > hi) lo = hi;
	return lo;
}

function GA_LifeSteal() : float
{
	switch ((int)GA_Num('GA_LifeSteal', 0))
	{
		case 1: return 0.1;
		case 2: return 0.25;
		case 3: return 0.5;
		case 4: return 1.0;
	}
	return 0;
}

function GA_KillChance() : float
{
	switch ((int)GA_Num('GA_KillChance', 0))
	{
		case 1: return 0.05;
		case 2: return 0.1;
		case 3: return 0.25;
		case 4: return 0.5;
		case 5: return 1.0;
	}
	return 0;
}

function GA_MonsterMult() : float { return ClampF(GA_Num('GA_MonsterMult', 1), 1, 100); }

// Flaechenschaden: Anteil vom Treffer-Schaden fuer Gegner in der Naehe
function GA_AreaShare() : float
{
	switch ((int)GA_Num('GA_Area', 0))
	{
		case 1: return 0.25;
		case 2: return 0.5;
		case 3: return 1.0;
	}
	return 0;
}

// Schaden an alle feindlichen Gegner im Umkreis von 4 m (kein Nahkampf -> keine Kettenreaktion)
function GA_AreaDamage(victim : CGameplayEntity, dmg : float)
{
	var ents : array<CGameplayEntity>;
	var a : CActor;
	var dm : W3DamageAction;
	var i : int;

	if (!victim || dmg <= 0) return;
	FindGameplayEntitiesInSphere(ents, victim.GetWorldPosition(), 4, 20, , FLAG_OnlyAliveActors);
	for (i = 0; i < ents.Size(); i += 1)
	{
		a = (CActor)ents[i];
		if (!a || a == thePlayer || a == victim || !a.IsAlive()) continue;
		if (!IsRequiredAttitudeBetween(thePlayer, a, true)) continue;
		dm = new W3DamageAction in theGame.damageMgr;
		dm.Initialize(thePlayer, a, NULL, "GodlikeAerondight", EHRT_Light, CPS_Undefined, false, false, false, true);
		dm.AddDamage(theGame.params.DAMAGE_NAME_DIRECT, dmg);
		theGame.damageMgr.ProcessAction(dm);
		delete dm;
	}
}

// Haelt Geralt gerade Aerondight in der Hand?
function GA_HoldsAerondight() : bool
{
	var inv : CInventoryComponent;
	inv = thePlayer.GetInventory();
	return inv && inv.ItemHasTag(inv.GetCurrentlyHeldSword(), 'Aerondight');
}

// Ist das ein Nahkampf-Treffer von Geralt mit Aerondight?
function GA_IsHit(act : W3DamageAction) : bool
{
	return act && act.attacker == thePlayer && act.IsActionMelee() && !act.IsDoTDamage() && GA_On() && GA_HoldsAerondight();
}

// ---------- Boni vor dem Treffer: Ruestung ignorieren, Effekte ----------
@wrapMethod(W3DamageManagerProcessor)
function ProcessAction(act : W3DamageAction)
{
	if (GA_IsHit(act) && act.victim != thePlayer)
	{
		if (GA_Is('GA_IgnoreArmor', true))
		{
			act.SetIgnoreArmor(true);
			act.SetPointResistIgnored(true);
		}
		if (GA_Is('GA_Bleeding', true))  act.AddEffectInfo(EET_Bleeding);
		if (GA_Is('GA_Burning', true))   act.AddEffectInfo(EET_Burning);
		if (GA_Is('GA_Poison', true))    act.AddEffectInfo(EET_Poison);
		if (GA_Is('GA_Freeze', false))   act.AddEffectInfo(EET_Frozen);
		if (GA_Is('GA_Knockdown', false)) act.AddEffectInfo(EET_Knockdown);
		if (GA_Is('GA_Stagger', false))   act.AddEffectInfo(EET_Stagger);
		if (GA_Is('GA_Confusion', false)) act.AddEffectInfo(EET_Confusion);
		if (GA_Is('GA_Blind', false))     act.AddEffectInfo(EET_Blindness);
		if (GA_Is('GA_Slow', false))      act.AddEffectInfo(EET_Slowdown);
		if (GA_Is('GA_Paralyze', false))  act.AddEffectInfo(EET_Paralyzed);
	}
	wrappedMethod(act);
}

// ---------- Immer kritischer Treffer ----------
@wrapMethod(W3DamageManagerProcessor)
function ProcessCriticalHitCheck()
{
	wrappedMethod();
	if (GA_IsHit(action) && GA_Is('GA_AlwaysCrit', true) && !action.IsCriticalHit())
		action.SetCriticalHit();
}

// ---------- Schaden: Min/Max, Faktor, Lebensraub ----------
@wrapMethod(W3DamageManagerProcessor)
function ProcessActionDamage_DealDamage()
{
	var d, lo, hi, n, steal : float;

	d = 0;
	if (GA_IsHit(action))
		d = MaxF(action.processedDmg.vitalityDamage, action.processedDmg.essenceDamage);
	if (d > 0)
	{
		lo = GA_MinDmg();
		hi = GA_MaxDmg();
		if (lo > 0 || hi > 0)
		{
			if (lo <= 0) lo = MinF(d, hi);
			if (hi <= 0) hi = MaxF(d, lo);
			n = RandRangeF(hi, lo);
			if (action.processedDmg.vitalityDamage > 0) action.processedDmg.vitalityDamage = n;
			if (action.processedDmg.essenceDamage > 0)  action.processedDmg.essenceDamage = n;
		}
		action.MultiplyAllDamageBy(GA_Mult());
		if (victimMonsterCategory != MC_Human)
			action.MultiplyAllDamageBy(GA_MonsterMult());
		if (actorVictim && actorVictim != thePlayer && RandF() < GA_KillChance())
		{
			if (action.processedDmg.vitalityDamage > 0) action.processedDmg.vitalityDamage = actorVictim.GetStatMax(BCS_Vitality) * 10;
			if (action.processedDmg.essenceDamage > 0)  action.processedDmg.essenceDamage = actorVictim.GetStatMax(BCS_Essence) * 10;
		}
		d = MaxF(action.processedDmg.vitalityDamage, action.processedDmg.essenceDamage);
		steal = GA_LifeSteal();
		if (steal > 0)
			thePlayer.GainStat(BCS_Vitality, d * steal);
		if (GA_Is('GA_Adrenaline', false))
			thePlayer.GainStat(BCS_Focus, 1);
		if (GA_Is('GA_Stamina', false))
			thePlayer.GainStat(BCS_Stamina, thePlayer.GetStatMax(BCS_Stamina));
	}
	wrappedMethod();
	if (d > 0 && GA_AreaShare() > 0)
		GA_AreaDamage(action.victim, d * GA_AreaShare());
}

// ---------- Immer voll aufgeladen ----------
@wrapMethod(W3Effect_Aerondight)
function OnUpdate(deltaTime : float)
{
	if (GA_On() && GA_Is('GA_FullCharge', true))
	{
		if (m_maxCount > 0 && m_currCount < m_maxCount && GA_HoldsAerondight())
		{
			m_currCount = m_maxCount;
			UpdateAerondightFX();
		}
		ResetAerondightTime();
	}
	return wrappedMethod(deltaTime);
}

// ---------- Mod Menu (gemeinsamer Standard) ----------
function GA_BuildMenuOptions( storage : CScriptedFlashValueStorage ) : CScriptedFlashArray
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
		if ( wrapper.GetGroupName( i ) == 'GA_Main' )
			groupId = i;
	}
	if ( groupId < 0 )
		return options;

	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Enabled' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Enabled', "true" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_DamageMult' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_DamageMult', "1" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_MinDmg' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_MinDmg', "0" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_MaxDmg' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_MaxDmg', "0" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_FullCharge' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_FullCharge', "true" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_AlwaysCrit' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_AlwaysCrit', "true" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_IgnoreArmor' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_IgnoreArmor', "true" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_LifeSteal' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_LifeSteal', "0" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Bleeding' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Bleeding', "true" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Burning' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Burning', "true" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Poison' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Poison', "true" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Freeze' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Freeze', "false" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Knockdown' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Knockdown', "false" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Stagger' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Stagger', "false" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Confusion' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Confusion', "false" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Blind' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Blind', "false" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Slow' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Slow', "false" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Paralyze' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Paralyze', "false" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_KillChance' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_KillChance', "0" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Area' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Area', "0" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_MonsterMult' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_MonsterMult', "1" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Adrenaline' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Adrenaline', "false" );
	if ( wrapper.GetVarValue( 'GA_Main', 'GA_Stamina' ) == "" ) wrapper.SetVarValue( 'GA_Main', 'GA_Stamina', "false" );
	// Mindestschaden nie hoeher als Hoechstschaden
	if ( GA_MaxDmg() > 0 && GA_Num( 'GA_MinDmg', 0 ) > GA_MaxDmg() ) wrapper.SetVarValue( 'GA_Main', 'GA_MinDmg', FloatToString( GA_MaxDmg() ) );

	root = storage.CreateTempFlashObject();
	root.SetMemberFlashArray( "subElements", options );
	IngameMenu_FillSubMenuOptionsList( storage, groupId, 'GA_Main', root );
	return root.GetMemberFlashArray( "subElements" );
}

@wrapMethod(IngameMenuStructureCreator)
function PopulateMenuData() : CScriptedFlashArray
{
	var src : CScriptedFlashArray;
	var dst : CScriptedFlashArray;
	var menuItem : CScriptedFlashObject;
	var modMenu : CScriptedFlashObject;
	var modList : CScriptedFlashArray;
	var myItem : CScriptedFlashObject;
	var i : int;
	var after : string;
	var placed : bool;

	src = wrappedMethod();
	if ( !parentMenu || parentMenu.isMainMenu )
		return src;

	myItem = CreateMenuItem( "ga_menu", "Godlike Aerondight", NameToFlashUInt( 'GAMenu' ), IGMActionType_MenuLastHolder, false, "Godlike Aerondight" );
	myItem.SetMemberFlashString( "label", "Godlike Aerondight" );
	myItem.SetMemberFlashString( "listTitle", "Godlike Aerondight" );
	myItem.SetMemberFlashArray( "subElements", GA_BuildMenuOptions( m_flashValueStorage ) );

	for ( i = 0; i < src.GetLength(); i += 1 )
	{
		menuItem = src.GetElementFlashObject( i );
		if ( menuItem && menuItem.GetMemberFlashString( "id" ) == "djdomi_modmenu" )
		{
			modList = menuItem.GetMemberFlashArray( "subElements" );
			modList.PushBackFlashObject( myItem );
			menuItem.SetMemberFlashArray( "subElements", modList );
			return src;
		}
	}

	modMenu = CreateMenuItem( "djdomi_modmenu", "Mod Menu", NameToFlashUInt( 'DjdomiModMenu' ), IGMActionType_MenuHolder, false, "Mod Menu" );
	modMenu.SetMemberFlashString( "label", "Mod Menu" );
	modMenu.SetMemberFlashString( "listTitle", "Mod Menu" );
	modList = m_flashValueStorage.CreateTempFlashArray();
	modList.PushBackFlashObject( myItem );
	modMenu.SetMemberFlashArray( "subElements", modList );

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
			dst.PushBackFlashObject( modMenu );
			placed = true;
		}
	}
	if ( !placed )
		dst.PushBackFlashObject( modMenu );
	return dst;
}
