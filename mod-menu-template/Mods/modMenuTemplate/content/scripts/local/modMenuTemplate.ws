// Mod Menu Template - https://github.com/djdomi/witcher3-mods - License: AGPL-3.0
// The Witcher 3 Remastered 5.0 only.
// Pause menu > "Mod Menu" (id "djdomi_modmenu") > "Template Mod" > settings.
//
// HOW TO USE (short, details in README.md):
// 1. Copy this whole mod folder and rename it.
// 2. Replace the prefix TPL_ everywhere with your own prefix (e.g. ABC_).
//    Also replace 'TPL_Main', "tpl_menu", 'TPLMenu' and "Template Mod".
// 3. Never change "djdomi_modmenu", "Mod Menu" or 'DjdomiModMenu'.
//    All mods share them. If one mod changes them, you get two menus.

// ---------- 1. Read settings ----------

function TPL_Get( v : name ) : string
{
	return theGame.GetInGameConfigWrapper().GetVarValue( 'TPL_Main', v );
}

function TPL_On( v : name ) : bool
{
	return TPL_Get( 'TPL_Enabled' ) == "true" && TPL_Get( v ) == "true";
}

function TPL_Number() : int
{
	return StringToInt( TPL_Get( 'TPL_Number' ) );
}

// ---------- 2. Defaults (empty value = never set) ----------

function TPL_SetDefaults( wrapper : CInGameConfigWrapper )
{
	if ( wrapper.GetVarValue( 'TPL_Main', 'TPL_Enabled' ) == "" ) wrapper.SetVarValue( 'TPL_Main', 'TPL_Enabled', "true" );
	if ( wrapper.GetVarValue( 'TPL_Main', 'TPL_Message' ) == "" ) wrapper.SetVarValue( 'TPL_Main', 'TPL_Message', "true" );
	if ( wrapper.GetVarValue( 'TPL_Main', 'TPL_Number' ) == "" ) wrapper.SetVarValue( 'TPL_Main', 'TPL_Number', "5" );
	if ( wrapper.GetVarValue( 'TPL_Main', 'TPL_Choice' ) == "" ) wrapper.SetVarValue( 'TPL_Main', 'TPL_Choice', "1" );
}

// ---------- 3. Example feature: message after loading a save ----------

@wrapMethod(CR4Player)
function OnSpawned( spawnData : SEntitySpawnData )
{
	wrappedMethod( spawnData );
	TPL_SetDefaults( (CInGameConfigWrapper)theGame.GetInGameConfigWrapper() );
	if ( TPL_On( 'TPL_Message' ) )
		DisplayHudMessage( "Template Mod is active. Slider value: " + IntToString( TPL_Number() ) );
}

// ---------- 4. Mod Menu: build the settings list ----------

function TPL_BuildMenuOptions( storage : CScriptedFlashValueStorage ) : CScriptedFlashArray
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
		if ( wrapper.GetGroupName( i ) == 'TPL_Main' )
			groupId = i;
	}
	if ( groupId < 0 )
		return options;

	TPL_SetDefaults( wrapper );

	root = storage.CreateTempFlashObject();
	root.SetMemberFlashArray( "subElements", options );
	IngameMenu_FillSubMenuOptionsList( storage, groupId, 'TPL_Main', root );
	return root.GetMemberFlashArray( "subElements" );
}

// ---------- 5. Mod Menu: hook into the pause menu ----------
// Do not change this block except the 4 TPL / Template Mod values in CreateMenuItem.

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
	myItem = CreateMenuItem( "tpl_menu", "Template Mod", NameToFlashUInt( 'TPLMenu' ), IGMActionType_MenuLastHolder, false, "Template Mod" );
	myItem.SetMemberFlashString( "label", "Template Mod" );
	myItem.SetMemberFlashString( "listTitle", "Template Mod" );
	myItem.SetMemberFlashArray( "subElements", TPL_BuildMenuOptions( m_flashValueStorage ) );

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
