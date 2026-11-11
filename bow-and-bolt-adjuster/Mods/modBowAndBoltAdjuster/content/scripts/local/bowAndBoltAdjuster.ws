// Bow-and-Bolt Adjuster - Witcher 3 Next-Gen (4.0+)
// https://github.com/djdomi/witcher3-mods - License: AGPL-3.0 (SPDX: AGPL-3.0-only)
// Armbrust- und Bolzen-Einstellungen im Menue: Optionen > Mods > Cheats

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
	return s == "true" || s == "1";
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
function BBA_BoltSpeed() : float  { return ClampF(BBA_Get('BBA_Bolt', 'BBA_BoltSpeed', 1), 1, 1000); }

function BBA_BoltDamage() : float
{
	var i : int;
	i = (int)BBA_Get('BBA_Bolt', 'BBA_BoltDamage', 0);
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
		BBA_SpeedUp(BBA_FireRate());
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
	if (!BBA_On())
	{
		shotCountLimit = 1;
		return wrappedMethod();
	}
	n = BBA_Shots();
	if (n < 0)
		return false; // Automatik: sofort nachgeladen, ohne Animation
	shotCountLimit = n;
	return wrappedMethod();
}

// ---------- Bolzen-Geschwindigkeit ----------
@addField(W3BoltProjectile)
var bbaSpeedDone : bool;

@wrapMethod(W3BoltProjectile)
function ThrowProjectile(targetPosIn : Vector)
{
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
