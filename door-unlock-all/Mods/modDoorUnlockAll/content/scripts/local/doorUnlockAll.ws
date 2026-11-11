// Door Unlock All - The Witcher 3 Remastered (5.0+)
// https://github.com/djdomi/witcher3-mods - License: AGPL-3.0 (SPDX: AGPL-3.0-only)
// Schliesst alle verschlossenen Tueren auf. Schluessel bleiben im Inventar.
// Unlocks all locked doors. Keys stay in the inventory.
// Pause menu > Mod Menu > Door Unlock All > Unlock all doors (on/off)

// Schalter im Mod Menu (leer = an)
function DUA_On() : bool
{
	return theGame.GetInGameConfigWrapper().GetVarValue('DUA_Main', 'DUA_Enabled') != "false";
}

// Ist dieses Objekt eine Tuer? (nur Tueren, keine Truhen, keine Tore)
@addMethod(W3LockableEntity)
function DUA_IsDoor() : bool
{
	return (W3Door)this || (W3NewDoor)this;
}

// Tuer aufschliessen, ohne Schluessel zu entfernen
@addMethod(W3LockableEntity)
function DUA_Unlock()
{
	var nd : W3NewDoor;

	if (!lockedByKey || !DUA_IsDoor() || !DUA_On()) return;

	lockedByKey = false;
	UpdateComponents("Main");

	nd = (W3NewDoor)this;
	if (nd) nd.DUA_FreeArea();
}

// Unsichtbare Sperre vor verschlossenen Tueren abschalten
@addMethod(W3NewDoor)
function DUA_FreeArea()
{
	if (lockedDA) lockedDA.SetEnabled(false);
}

// Jedes Abschliessen (beim Laden und durch Quests) sofort wieder aufheben
@wrapMethod(W3LockableEntity)
function Lock(keyName : name, optional removeKey : bool, optional smoooth : bool)
{
	wrappedMethod(keyName, removeKey, smoooth);
	DUA_Unlock();
}

// Zur Sicherheit: wenn Geralt in die Naehe kommt
@wrapMethod(W3LockableEntity)
function ShowInteractionComponent()
{
	DUA_Unlock();
	wrappedMethod();
}

// ---------- Mod Menu (Pausemenue > Mod Menu > Door Unlock All) ----------
function DUA_BuildMenuOptions( storage : CScriptedFlashValueStorage ) : CScriptedFlashArray
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
		if ( wrapper.GetGroupName( i ) == 'DUA_Main' )
			groupId = i;
	}
	if ( groupId < 0 )
		return options;

	if ( wrapper.GetVarValue( 'DUA_Main', 'DUA_Enabled' ) == "" ) wrapper.SetVarValue( 'DUA_Main', 'DUA_Enabled', "true" );

	root = storage.CreateTempFlashObject();
	root.SetMemberFlashArray( "subElements", options );
	IngameMenu_FillSubMenuOptionsList( storage, groupId, 'DUA_Main', root );
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

	myItem = CreateMenuItem( "dua_menu", "Door Unlock All", NameToFlashUInt( 'DUAMenu' ), IGMActionType_MenuLastHolder, false, "Door Unlock All" );
	myItem.SetMemberFlashString( "label", "Door Unlock All" );
	myItem.SetMemberFlashString( "listTitle", "Door Unlock All" );
	myItem.SetMemberFlashArray( "subElements", DUA_BuildMenuOptions( m_flashValueStorage ) );

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
