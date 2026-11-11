// Door Unlock All - The Witcher 3 Remastered (5.0+)
// https://github.com/djdomi/witcher3-mods - License: AGPL-3.0 (SPDX: AGPL-3.0-only)
// Schliesst alle verschlossenen Tueren auf. Schluessel bleiben im Inventar.
// Unlocks all locked doors. Keys stay in the inventory.

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

	if (!lockedByKey || !DUA_IsDoor()) return;

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
