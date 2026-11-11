// Sign Intensity and Range - The Witcher 3 Remastered (5.0+)
// https://github.com/djdomi/witcher3-mods - License: AGPL-3.0 (SPDX: AGPL-3.0-only)
// Zeichen-Einstellungen im Pausemenue: "Signs"

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
