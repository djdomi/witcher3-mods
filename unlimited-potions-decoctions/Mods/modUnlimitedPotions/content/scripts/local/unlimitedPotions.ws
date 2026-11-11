// Unlimited Potions & Decoctions - Witcher 3 Next-Gen (4.0+)
// https://github.com/djdomi/witcher3-mods - License: AGPL-3.0
// 1) Traenke ohne Vergiftungs-Limit  2) Alle Absude per Schalter aktiv
// Schalter: Optionen > Unlimited Potions

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
function HasFreeToxicityToDrinkPotion(item : SItemUniqueId, effectType : EEffectType, out finalPotionToxicity : float) : bool
{
	var ret : bool;
	var m : int;

	ret = wrappedMethod(item, effectType, finalPotionToxicity);
	m = UP_ToxMode();
	if (m == 2)
		return ret;
	if (m == 1 && finalPotionToxicity > 0)
		finalPotionToxicity = 1;
	else
		finalPotionToxicity = 0;
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
