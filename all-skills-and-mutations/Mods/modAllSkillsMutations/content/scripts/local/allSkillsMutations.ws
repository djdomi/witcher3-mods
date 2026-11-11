// All Skills & Mutations - The Witcher 3 Remastered (5.0+)
// https://github.com/djdomi/witcher3-mods - License: AGPL-3.0 (SPDX: AGPL-3.0-only)
// Alle gelernten Faehigkeiten und alle erforschten Mutationen gleichzeitig aktiv.
// Schalter im Pausemenue: Mod Menu > All Skills and Mutations

// Leer (noch nie eingestellt) = AN
function ASM_Opt(v : name) : bool
{
	var s : string;
	s = theGame.GetInGameConfigWrapper().GetVarValue('ASM_Main', v);
	return s != "false" && s != "0";
}

// ================= Faehigkeiten =================
@addField(W3PlayerAbilityManager)
var asmAdded : array<ESkill>;

// Ist die Faehigkeit schon wirksam (z.B. aus dem Spielstand)?
@addMethod(W3PlayerAbilityManager)
function ASM_IsApplied(s : ESkill) : bool
{
	var ab : name;
	ab = skills[s].abilityName;
	if (theGame.GetDefinitionsManager().AbilityHasTag(ab, theGame.params.SKILL_GLOBAL_PASSIVE_TAG))
		return charStats.HasAbility(ab);
	return skillAbilities.Contains(ab);
}

// Alle gelernten, nicht eingesetzten Faehigkeiten an- oder abschalten
@addMethod(W3PlayerAbilityManager)
function ASM_SyncSkills(on : bool)
{
	var i : int;
	var s : ESkill;

	for (i = 0; i < skills.Size(); i += 1)
	{
		s = skills[i].skillType;
		if (s == S_SUndefined || skills[i].isCoreSkill || skills[i].level < 1)
			continue;
		if (GetSkillSlotID(s) >= 0)
			continue; // steckt im Slot: normales Spiel

		if (on)
		{
			if (!tempSkills.Contains(s))
				tempSkills.PushBack(s);
			if (!asmAdded.Contains(s))
				asmAdded.PushBack(s);
			if (!ASM_IsApplied(s))
				OnSkillEquip(s);
		}
		else
		{
			if (ASM_IsApplied(s))
				OnSkillUnequip(s);
			if (asmAdded.Contains(s))
			{
				tempSkills.Remove(s);
				asmAdded.Remove(s);
			}
		}
	}
}

// Faehigkeit wird in einen Slot gesetzt: vorher Mod-Wirkung entfernen (kein Doppel-Bonus)
@wrapMethod(W3PlayerAbilityManager)
function EquipSkill(skill : ESkill, slotID : int) : bool
{
	if (asmAdded.Contains(skill) && HasLearnedSkill(skill) && GetSkillSlotIndex(slotID, true) >= 0)
	{
		tempSkills.Remove(skill);
		asmAdded.Remove(skill);
		if (ASM_IsApplied(skill))
			OnSkillUnequip(skill);
	}
	return wrappedMethod(skill, slotID);
}

// Erforschte Mutationen merken
@addMethod(W3PlayerAbilityManager)
function ASM_Researched() : array<EPlayerMutationType>
{
	var ret : array<EPlayerMutationType>;
	var i : int;
	for (i = 0; i < mutations.Size(); i += 1)
		if (mutations[i].type != EPMT_MutationMaster && mutations[i].type != EPMT_None && IsMutationResearched(mutations[i].type))
			ret.PushBack(mutations[i].type);
	return ret;
}

// ================= Mutationen =================
@addField(W3PlayerWitcher)
var asmMutOn : bool;

@addField(W3PlayerWitcher)
var asmMuts : array<EPlayerMutationType>;

@addField(W3PlayerWitcher)
var asmSkillsOn : int; // 0 = unbekannt, 1 = an, 2 = aus

@wrapMethod(W3PlayerWitcher)
function IsMutationActive(mutationType : EPlayerMutationType) : bool
{
	var q : int;

	if (!asmMutOn || GetEquippedMutationType() == mutationType || !asmMuts.Contains(mutationType))
		return wrappedMethod(mutationType);

	// gleiche Regeln wie im Spiel
	switch (mutationType)
	{
		case EPMT_Mutation4 :
		case EPMT_Mutation5 :
		case EPMT_Mutation7 :
		case EPMT_Mutation8 :
		case EPMT_Mutation10 :
		case EPMT_Mutation11 :
		case EPMT_Mutation12 :
			if (IsInFistFight())
				return false;
	}
	if (mutationType == EPMT_Mutation1)
	{
		q = inv.GetItemQuality(inv.GetCurrentlyHeldSword());
		if (q < 3)
			return false;
	}
	return true;
}

// ================= Taktgeber (alle 2 Sekunden) =================
@wrapMethod(W3PlayerWitcher)
function AddStartingSchematics()
{
	wrappedMethod();
	asmSkillsOn = 0;
	AddTimer('ASM_Tick', 2.0, true);
}

@addMethod(W3PlayerWitcher)
timer function ASM_Tick(dt : float, id : int)
{
	var am : W3PlayerAbilityManager;
	var i : int;
	var bank : string;
	var on : bool;

	am = (W3PlayerAbilityManager)abilityManager;
	if (!am || !am.IsInitialized())
		return;

	// Faehigkeiten
	on = ASM_Opt('ASM_Skills');
	if (on || asmSkillsOn != 2)
		am.ASM_SyncSkills(on);
	if (on) asmSkillsOn = 1; else asmSkillsOn = 2;

	// Mutationen
	asmMutOn = ASM_Opt('ASM_Mutations');
	if (asmMutOn)
	{
		asmMuts = am.ASM_Researched();
		for (i = 0; i < asmMuts.Size(); i += 1)
		{
			bank = am.GetMutationSoundBank(asmMuts[i]);
			if (bank != "" && !theSound.SoundIsBankLoaded(bank))
				theSound.SoundLoadBank(bank, true);
		}
	}
}

// ================= Pausemenue: Mod Menu > All Skills and Mutations =================
function ASM_SetDefaults( wrapper : CInGameConfigWrapper )
{
	if ( wrapper.GetVarValue( 'ASM_Main', 'ASM_Skills' ) == "" )
		wrapper.SetVarValue( 'ASM_Main', 'ASM_Skills', "true" );
	if ( wrapper.GetVarValue( 'ASM_Main', 'ASM_Mutations' ) == "" )
		wrapper.SetVarValue( 'ASM_Main', 'ASM_Mutations', "true" );
}

function ASM_BuildMenuOptions( storage : CScriptedFlashValueStorage ) : CScriptedFlashArray
{
	var wrapper : CInGameConfigWrapper;
	var groupId, i : int;
	var root : CScriptedFlashObject;
	var options : CScriptedFlashArray;

	options = storage.CreateTempFlashArray();
	wrapper = (CInGameConfigWrapper)theGame.GetInGameConfigWrapper();
	if ( !wrapper )
		return options;

	groupId = -1;
	for ( i = 0; i < wrapper.GetGroupsNum(); i += 1 )
	{
		if ( wrapper.GetGroupName( i ) == 'ASM_Main' )
			groupId = i;
	}
	if ( groupId < 0 )
		return options;

	ASM_SetDefaults( wrapper );

	root = storage.CreateTempFlashObject();
	root.SetMemberFlashArray( "subElements", options );
	IngameMenu_FillSubMenuOptionsList( storage, groupId, 'ASM_Main', root );
	return root.GetMemberFlashArray( "subElements" );
}

// Gemeinsames "Mod Menu" (gleiche id "djdomi_modmenu" in allen Mods von djdomi/witcher3-mods):
// Die erste Mod legt den Punkt an, jede weitere haengt nur ihr Untermenue an.
@wrapMethod(IngameMenuStructureCreator)
function PopulateMenuData() : CScriptedFlashArray
{
	var src, dst, subs : CScriptedFlashArray;
	var menuItem, modMenu, asmItem : CScriptedFlashObject;
	var i : int;
	var after : string;
	var placed : bool;

	src = wrappedMethod();
	if ( !parentMenu || parentMenu.isMainMenu )
		return src;

	asmItem = CreateMenuItem( "asm_menu", "All Skills and Mutations", NameToFlashUInt( 'ASMMenu' ), IGMActionType_MenuLastHolder, false, "All Skills and Mutations" );
	asmItem.SetMemberFlashString( "label", "All Skills and Mutations" );
	asmItem.SetMemberFlashString( "listTitle", "All Skills and Mutations" );
	asmItem.SetMemberFlashArray( "subElements", ASM_BuildMenuOptions( m_flashValueStorage ) );

	// Gibt es "Mod Menu" schon (von einer anderen Mod)?
	for ( i = 0; i < src.GetLength(); i += 1 )
	{
		menuItem = src.GetElementFlashObject( i );
		if ( menuItem && menuItem.GetMemberFlashString( "id" ) == "djdomi_modmenu" )
		{
			subs = menuItem.GetMemberFlashArray( "subElements" );
			subs.PushBackFlashObject( asmItem );
			menuItem.SetMemberFlashArray( "subElements", subs );
			return src;
		}
	}

	// Nein: "Mod Menu" neu anlegen
	modMenu = CreateMenuItem( "djdomi_modmenu", "Mod Menu", NameToFlashUInt( 'DjdomiModMenu' ), IGMActionType_MenuHolder, false, "Mod Menu" );
	modMenu.SetMemberFlashString( "label", "Mod Menu" );
	modMenu.SetMemberFlashString( "listTitle", "Mod Menu" );
	subs = m_flashValueStorage.CreateTempFlashArray();
	subs.PushBackFlashObject( asmItem );
	modMenu.SetMemberFlashArray( "subElements", subs );

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
			dst.PushBackFlashObject( modMenu );
			placed = true;
		}
	}
	if ( !placed )
		dst.PushBackFlashObject( modMenu );

	return dst;
}
