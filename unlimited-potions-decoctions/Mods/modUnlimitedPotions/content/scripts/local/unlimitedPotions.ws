// Unlimited Potions & Decoctions - The Witcher 3 Remastered (5.0+)
// https://github.com/djdomi/witcher3-mods - License: AGPL-3.0
// 1) Traenke ohne Vergiftungs-Limit  2) Alle Absude per Schalter aktiv
// Schalter: Pausemenue > Unlimited Potions

// Gift-Modus: 0 = kein Gift (Standard), 1 = 1 Punkt pro Trank, 2 = normal wie im Spiel
function UP_ToxMode() : int
{
	var s : string;
	s = theGame.GetInGameConfigWrapper().GetVarValue('UP_Main', 'UP_Toxicity');
	if (s == "1") return 1;
	if (s == "2") return 2;
	return 0;
}

// Leer (noch nie eingestellt) = AN
function UP_DecoctionsOn() : bool
{
	var s : string;
	s = theGame.GetInGameConfigWrapper().GetVarValue('UP_Main', 'UP_Decoctions');
	return s != "false" && s != "0";
}

// ================= Traenke =================
// Darf ich trinken? Bei Modus 0/1 immer ja.
@wrapMethod(W3PlayerWitcher)
function ToxicityLowEnoughToDrinkPotion(slotid : EEquipmentSlots, optional itemId : SItemUniqueId) : bool
{
	if (UP_ToxMode() != 2)
		return true;
	return wrappedMethod(slotid, itemId);
}

// Gift pro Trank: 0 oder 1, und immer trinkbar
@wrapMethod(W3PlayerWitcher)
// 5.0: zusaetzliche Parameter toxicityOffset und adrenaline
function HasFreeToxicityToDrinkPotion(item : SItemUniqueId, effectType : EEffectType, out finalPotionToxicity : float, out toxicityOffset : float, out adrenaline : float) : bool
{
	var ret : bool;
	var m : int;

	ret = wrappedMethod(item, effectType, finalPotionToxicity, toxicityOffset, adrenaline);
	m = UP_ToxMode();
	if (m == 2)
		return ret;
	if (m == 1 && finalPotionToxicity > 0)
		finalPotionToxicity = 1;
	else
		finalPotionToxicity = 0;
	toxicityOffset = 0; // Absude sperren kein Gift
	return true;
}

// Absude sperren kein Gift mehr (Toxizitaets-Sperre aus)
@wrapMethod(W3PlayerAbilityManager)
function AddToxicityOffset(val : float)
{
	if (UP_ToxMode() != 2)
		return;
	wrappedMethod(val);
}

@wrapMethod(W3PlayerAbilityManager)
function SetToxicityOffset(val : float)
{
	if (UP_ToxMode() != 2)
		val = 0;
	wrappedMethod(val);
}

// ================= Absude =================
@addMethod(W3PlayerWitcher)
function UP_SyncDecoctions(on : bool)
{
	var i : int;
	var b : CBaseGameplayEffect;
	var p : SCustomEffectParams;
	var mp : W3MutagenBuffCustomParams;

	for (i = EET_Mutagen01; i <= EET_Mutagen28; i += 1)
	{
		b = GetBuff(i, "UP_Decoction");
		if (!on)
		{
			if (b)
				RemoveBuff(i, true, "UP_Decoction");
			continue;
		}
		if (b)
		{
			// Laeuft trotzdem ab (z.B. nach Skill-Wechsel)? Wieder auffuellen.
			if (b.GetDurationLeft() >= 0 && b.GetDurationLeft() < 600)
				b.SetTimeLeft(3600);
			continue;
		}
		if (HasBuff(i))
			continue; // selbst getrunken: nicht doppelt

		mp = new W3MutagenBuffCustomParams in theGame;
		mp.toxicityOffset = 0;
		mp.potionItemName = DecoctionEffectTypeToItemName(i);
		p.effectType = i;
		p.creator = this;
		p.sourceName = "UP_Decoction";
		p.duration = -1; // ohne Ende
		p.buffSpecificParams = mp;
		AddEffectCustom(p);
		delete mp;
	}
}

// ================= Taktgeber (alle 2 Sekunden) =================
@addField(W3PlayerWitcher)
var upDecOn : int; // 0 = unbekannt, 1 = an, 2 = aus

@wrapMethod(W3PlayerWitcher)
function AddStartingSchematics()
{
	wrappedMethod();
	upDecOn = 0;
	AddTimer('UP_Tick', 2.0, true);
}

@addMethod(W3PlayerWitcher)
timer function UP_Tick(dt : float, id : int)
{
	var on : bool;
	var tox : float;

	if (!abilityManager || !abilityManager.IsInitialized() || !IsAlive())
		return;

	// Gift
	if (UP_ToxMode() != 2)
	{
		((W3PlayerAbilityManager)abilityManager).SetToxicityOffset(0);
		if (UP_ToxMode() == 0)
		{
			tox = GetStat(BCS_Toxicity, true);
			if (tox > 0)
				DrainToxicity(tox);
		}
	}

	// Absude
	on = UP_DecoctionsOn();
	if (on || upDecOn != 2)
		UP_SyncDecoctions(on);
	if (on) upDecOn = 1; else upDecOn = 2;
}

// ================= Pausemenue-Eintrag "Unlimited Potions" (5.0) =================
function UP_SetDefaults(wrapper : CInGameConfigWrapper)
{
	if (wrapper.GetVarValue('UP_Main', 'UP_Toxicity') == "")
		wrapper.SetVarValue('UP_Main', 'UP_Toxicity', "0");
	if (wrapper.GetVarValue('UP_Main', 'UP_Decoctions') == "")
		wrapper.SetVarValue('UP_Main', 'UP_Decoctions', "true");
}

function UP_BuildMenuOptions(storage : CScriptedFlashValueStorage) : CScriptedFlashArray
{
	var wrapper : CInGameConfigWrapper;
	var groupId : int;
	var i : int;
	var root : CScriptedFlashObject;
	var options : CScriptedFlashArray;

	options = storage.CreateTempFlashArray();
	wrapper = (CInGameConfigWrapper)theGame.GetInGameConfigWrapper();
	if (!wrapper)
		return options;

	groupId = -1;
	for (i = 0; i < wrapper.GetGroupsNum(); i += 1)
	{
		if (wrapper.GetGroupName(i) == 'UP_Main')
			groupId = i;
	}
	if (groupId < 0)
		return options;

	UP_SetDefaults(wrapper);

	root = storage.CreateTempFlashObject();
	root.SetMemberFlashArray("subElements", options);
	IngameMenu_FillSubMenuOptionsList(storage, groupId, 'UP_Main', root);
	return root.GetMemberFlashArray("subElements");
}

@wrapMethod(IngameMenuStructureCreator)
function PopulateMenuData() : CScriptedFlashArray
{
	var src : CScriptedFlashArray;
	var dst : CScriptedFlashArray;
	var menuItem : CScriptedFlashObject;
	var upItem : CScriptedFlashObject;
	var i : int;
	var after : string;
	var id : string;
	var placed : bool;

	src = wrappedMethod();
	if (!parentMenu || parentMenu.isMainMenu)
		return src;

	upItem = CreateMenuItem("up_menu", "Unlimited Potions", NameToFlashUInt('UPMenu'), IGMActionType_MenuLastHolder, false, "Unlimited Potions");
	upItem.SetMemberFlashString("label", "Unlimited Potions");
	upItem.SetMemberFlashString("listTitle", "Unlimited Potions");
	upItem.SetMemberFlashArray("subElements", UP_BuildMenuOptions(m_flashValueStorage));

	// hinter anderen Mod-Menues einfuegen, sonst hinter "Einstellungen"
	after = "mainmenu_options";
	for (i = 0; i < src.GetLength(); i += 1)
	{
		menuItem = src.GetElementFlashObject(i);
		if (!menuItem)
			continue;
		id = menuItem.GetMemberFlashString("id");
		if (id == "wqol_cheats" || id == "bba_menu")
			after = id;
	}

	dst = m_flashValueStorage.CreateTempFlashArray();
	placed = false;
	for (i = 0; i < src.GetLength(); i += 1)
	{
		menuItem = src.GetElementFlashObject(i);
		dst.PushBackFlashObject(menuItem);
		if (!placed && menuItem && menuItem.GetMemberFlashString("id") == after)
		{
			dst.PushBackFlashObject(upItem);
			placed = true;
		}
	}
	if (!placed)
		dst.PushBackFlashObject(upItem);

	return dst;
}
