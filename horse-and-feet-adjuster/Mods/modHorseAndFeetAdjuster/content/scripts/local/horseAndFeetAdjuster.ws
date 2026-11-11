// Horse and Feet Adjuster - https://github.com/djdomi/witcher3-mods - License: AGPL-3.0
// The Witcher 3 Remastered 5.0 only.
// Pause menu > "Mod Menu" > "Horse and Feet Adjuster" > settings.
// Running speed on foot, horse speed, and a boost while the ALT key (walk key) is held.
// Prefix: HFA_

// ---------- 1. Read settings ----------

function HFA_Get( v : name ) : string
{
	return theGame.GetInGameConfigWrapper().GetVarValue( 'HFA_Main', v );
}

function HFA_On( v : name ) : bool
{
	return HFA_Get( 'HFA_Enabled' ) == "true" && HFA_Get( v ) == "true";
}

function HFA_Factor( v : name, maxV : float ) : float
{
	return ClampF( StringToFloat( HFA_Get( v ), 1 ), 1, maxV );
}

// ---------- 2. Defaults (empty value = never set) ----------

function HFA_Def( wrapper : CInGameConfigWrapper, v : name, val : string )
{
	if ( wrapper.GetVarValue( 'HFA_Main', v ) == "" )
		wrapper.SetVarValue( 'HFA_Main', v, val );
}

function HFA_SetDefaults( wrapper : CInGameConfigWrapper )
{
	HFA_Def( wrapper, 'HFA_Enabled', "true" );
	HFA_Def( wrapper, 'HFA_FeetOn', "true" );
	HFA_Def( wrapper, 'HFA_FeetFactor', "1" );
	HFA_Def( wrapper, 'HFA_HorseOn', "true" );
	HFA_Def( wrapper, 'HFA_HorseFactor', "1" );
	HFA_Def( wrapper, 'HFA_AltOn', "true" );
	HFA_Def( wrapper, 'HFA_AltFactor', "2" );
}

// ---------- 3. ALT key (game action "WalkToggle") ----------

@addField(CR4Player)
var hfaAltHeld : bool;

@addField(CR4Player)
var hfaFeetActive : bool;

@addField(CR4Player)
var hfaFeetId : int;

@addField(CR4Player)
var hfaHorse : CNewNPC;

@addField(CR4Player)
var hfaHorseId : int;

// With "ALT boost" on, holding ALT boosts the speed instead of the normal walk toggle.
@wrapMethod(CPlayerInput)
function OnCommWalkToggle( action : SInputAction )
{
	var r : CR4Player;

	r = (CR4Player)thePlayer;
	if ( r && HFA_On( 'HFA_AltOn' ) )
	{
		r.hfaAltHeld = IsPressed( action );
		return false;
	}
	if ( r )
		r.hfaAltHeld = false;
	return wrappedMethod( action );
}

// ---------- 4. Speed logic (runs 10 times per second) ----------

@addMethod(CR4Player)
function HFA_Boost() : float
{
	if ( hfaAltHeld && HFA_On( 'HFA_AltOn' ) )
		return HFA_Factor( 'HFA_AltFactor', 5 );
	return 1;
}

@addMethod(CR4Player)
function HFA_StopFeet()
{
	if ( hfaFeetActive )
		ResetAnimationSpeedMultiplier( hfaFeetId );
	hfaFeetActive = false;
}

@addMethod(CR4Player)
function HFA_StopHorse()
{
	if ( hfaHorse )
		hfaHorse.ResetAnimationSpeedMultiplier( hfaHorseId );
	hfaHorse = NULL;
}

@addMethod(CR4Player)
timer function HFA_Tick( dt : float, id : int )
{
	var horse : CNewNPC;
	var mul : float;
	var moving : bool;

	// ----- Horse -----
	horse = GetHorseCurrentlyMounted();
	mul = 1;
	if ( horse && HFA_On( 'HFA_HorseOn' ) && !IsInNonGameplayCutscene()
		&& horse.GetMovingAgentComponent().GetRelativeMoveSpeed() > 0.1 )
		mul = MinF( HFA_Factor( 'HFA_HorseFactor', 5 ) * HFA_Boost(), 10 );

	if ( hfaHorse && hfaHorse != horse )
		HFA_StopHorse();
	if ( mul > 1.01 )
	{
		if ( hfaHorse )
			hfaHorseId = horse.SetAnimationSpeedMultiplier( mul, hfaHorseId );
		else
			hfaHorseId = horse.SetAnimationSpeedMultiplier( mul, -1 );
		hfaHorse = horse;
	}
	else if ( hfaHorse )
		HFA_StopHorse();

	// ----- On foot (only outside combat, only while running or sprinting) -----
	mul = 1;
	moving = ( GetIsRunning() || GetIsSprinting() ) && GetMovingAgentComponent().GetRelativeMoveSpeed() > 0.1;
	if ( !horse && HFA_On( 'HFA_FeetOn' ) && moving && GetCurrentStateName() == 'Exploration' && !IsInNonGameplayCutscene() )
		mul = MinF( HFA_Factor( 'HFA_FeetFactor', 5 ) * HFA_Boost(), 10 );

	if ( mul > 1.01 )
	{
		if ( hfaFeetActive )
			hfaFeetId = SetAnimationSpeedMultiplier( mul, hfaFeetId );
		else
			hfaFeetId = SetAnimationSpeedMultiplier( mul, -1 );
		hfaFeetActive = true;
	}
	else
		HFA_StopFeet();
}

@wrapMethod(CR4Player)
function OnSpawned( spawnData : SEntitySpawnData )
{
	var res : bool;

	res = wrappedMethod( spawnData );
	HFA_SetDefaults( (CInGameConfigWrapper)theGame.GetInGameConfigWrapper() );
	hfaAltHeld = false;
	hfaFeetActive = false;
	hfaHorse = NULL;
	AddTimer( 'HFA_Tick', 0.1, true );
	return res;
}

// ---------- 5. Mod Menu: build the settings list ----------

function HFA_BuildMenuOptions( storage : CScriptedFlashValueStorage ) : CScriptedFlashArray
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
		if ( wrapper.GetGroupName( i ) == 'HFA_Main' )
			groupId = i;
	}
	if ( groupId < 0 )
		return options;

	HFA_SetDefaults( wrapper );

	root = storage.CreateTempFlashObject();
	root.SetMemberFlashArray( "subElements", options );
	IngameMenu_FillSubMenuOptionsList( storage, groupId, 'HFA_Main', root );
	return root.GetMemberFlashArray( "subElements" );
}

// ---------- 6. Mod Menu: hook into the pause menu ----------
// Shared Mod Menu block from mod-menu-template.

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

	// Your mod = one sub menu inside "Mod Menu".
	myItem = CreateMenuItem( "hfa_menu", "Horse and Feet Adjuster", NameToFlashUInt( 'HFAMenu' ), IGMActionType_MenuLastHolder, false, "Horse and Feet Adjuster" );
	myItem.SetMemberFlashString( "label", "Horse and Feet Adjuster" );
	myItem.SetMemberFlashString( "listTitle", "Horse and Feet Adjuster" );
	myItem.SetMemberFlashArray( "subElements", HFA_BuildMenuOptions( m_flashValueStorage ) );

	// Another mod already made "Mod Menu": add yourself to it.
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

	// First mod: create "Mod Menu".
	modMenu = CreateMenuItem( "djdomi_modmenu", "Mod Menu", NameToFlashUInt( 'DjdomiModMenu' ), IGMActionType_MenuHolder, false, "Mod Menu" );
	modMenu.SetMemberFlashString( "label", "Mod Menu" );
	modMenu.SetMemberFlashString( "listTitle", "Mod Menu" );
	modList = m_flashValueStorage.CreateTempFlashArray();
	modList.PushBackFlashObject( myItem );
	modMenu.SetMemberFlashArray( "subElements", modList );

	// Place it after "Options" (or after the CHEATS entry, if there is one).
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
