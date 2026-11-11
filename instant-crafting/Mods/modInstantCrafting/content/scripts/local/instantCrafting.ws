// Instant Crafting - The Witcher 3 Remastered (5.0+)
// https://github.com/djdomi/witcher3-mods - License: AGPL-3.0 (SPDX: AGPL-3.0-only)
// Alchemie und Schmied: ein Klick stellt sofort her, keine Voraussetzungen.
// Alchemy and crafting: one click crafts instantly, no requirements.

// ---------- Hilfsfunktionen / helpers ----------

// Alle Rezept-Namen aus den Spieldaten (alchemy_recipes / crafting_schematics)
function IC_AllRecipeNames(defName : name) : array<name>
{
	var dm : CDefinitionsManagerAccessor;
	var main : SCustomNode;
	var tmpName : name;
	var i : int;
	var ret : array<name>;

	dm = theGame.GetDefinitionsManager();
	main = dm.GetCustomDefinition(defName);
	for (i = 0; i < main.subNodes.Size(); i += 1)
	{
		if (dm.GetCustomNodeAttributeValueName(main.subNodes[i], 'name_name', tmpName) && IsNameValid(tmpName))
		{
			if (!ret.Contains(tmpName))
				ret.PushBack(tmpName);
		}
	}
	return ret;
}

// ---------- Alchemie / alchemy ----------

// Fehlende Zutaten nicht pruefen
@wrapMethod(W3AlchemyManager)
function CanCookRecipe(recipeName : name, optional ignorePlayerState : bool) : EAlchemyExceptions
{
	var res : EAlchemyExceptions;
	res = wrappedMethod(recipeName, ignorePlayerState);
	if (res == EAE_NotEnoughIngredients)
		return EAE_NoException;
	return res;
}

// Fehlende Zutaten kurz vor dem Brauen ergaenzen
@addMethod(W3AlchemyManager)
function IC_AddMissingIngredients(recipeName : name)
{
	var recipe : SAlchemyRecipe;
	var dm : CDefinitionsManagerAccessor;
	var i, cnt, need : int;
	var itemName : name;

	if (!GetRecipe(recipeName, recipe)) return;
	dm = theGame.GetDefinitionsManager();

	for (i = 0; i < recipe.requiredIngredients.Size(); i += 1)
	{
		itemName = recipe.requiredIngredients[i].itemName;
		need = recipe.requiredIngredients[i].quantity;
		if (!IsNameValid(itemName) || need <= 0) continue;

		if (dm.ItemHasTag(itemName, 'MutagenIngredient'))
			cnt = thePlayer.inv.GetUnusedMutagensCount(itemName);
		else
			cnt = thePlayer.inv.GetItemQuantityByName(itemName);

		if (cnt < need)
			thePlayer.inv.AddAnItem(itemName, need - cnt);
	}
}

@wrapMethod(W3AlchemyManager)
function CookItem(recipeName : name)
{
	IC_AddMissingIngredients(recipeName);
	wrappedMethod(recipeName);
}

// Alle Alchemie-Rezepte im Menue zeigen
@addField(CR4AlchemyMenu)
var IC_pressTag : name;
@addField(CR4AlchemyMenu)
var IC_pressTime : float;
@addField(CR4AlchemyMenu)
var IC_inPress : bool;

@wrapMethod(CR4AlchemyMenu)
function OnConfigUI()
{
	wrappedMethod();
	m_alchemyManager = new W3AlchemyManager in this;
	m_alchemyManager.Init(IC_AllRecipeNames('alchemy_recipes'));
	m_recipeList = m_alchemyManager.GetRecipes(false);
	PopulateData();
}

// Ein Klick = sofort herstellen
@wrapMethod(CR4AlchemyMenu)
function OnEntryPress(tag : name)
{
	wrappedMethod(tag);
	IC_inPress = true;
	OnCraftItem(tag);
	IC_inPress = false;
	IC_pressTag = tag;
	IC_pressTime = theGame.GetEngineTimeAsSeconds();
}

// Nicht doppelt herstellen, wenn das Spiel danach noch "Halten fertig" meldet
@wrapMethod(CR4AlchemyMenu)
function OnCraftItem(tag : name)
{
	if (!IC_inPress && tag == IC_pressTag && theGame.GetEngineTimeAsSeconds() - IC_pressTime < 3.0)
		return;
	wrappedMethod(tag);
}

// ---------- Schmied / Ruestungsschmied - crafting ----------

// Keine Pruefung von Zutaten, Handwerker-Art, Handwerker-Stufe, Geld
@wrapMethod(W3CraftingManager)
function CanCraftSchematic(schematicName : name, checkMerchant : bool) : ECraftingException
{
	var res : ECraftingException;
	res = wrappedMethod(schematicName, checkMerchant);
	if (res == ECE_TooFewIngredients || res == ECE_WrongCraftsmanType || res == ECE_TooLowCraftsmanLevel || res == ECE_NotEnoughMoney)
		return ECE_NoException;
	return res;
}

@addMethod(W3CraftingManager)
function IC_InitAll(masterComp : W3CraftsmanComponent)
{
	craftMasterComp = masterComp;
	LoadSchematicsXMLData(IC_AllRecipeNames('crafting_schematics'));
}

// Fehlende Zutaten und fehlendes Geld kurz vor dem Herstellen ergaenzen
@addMethod(W3CraftingManager)
function IC_AddMissing(schemName : name)
{
	var schem : SCraftingSchematic;
	var i, cnt, need, cost : int;
	var itemName : name;

	if (!GetSchematic(schemName, schem)) return;

	for (i = 0; i < schem.ingredients.Size(); i += 1)
	{
		itemName = schem.ingredients[i].itemName;
		need = schem.ingredients[i].quantity;
		if (!IsNameValid(itemName) || need <= 0) continue;
		cnt = thePlayer.inv.GetItemQuantityByName(itemName);
		if (cnt < need)
			thePlayer.inv.AddAnItem(itemName, need - cnt);
	}

	if (craftMasterComp)
	{
		cost = GetCraftingCost(schemName);
		if (cost > 0 && thePlayer.GetMoney() < cost)
			thePlayer.AddMoney(cost - thePlayer.GetMoney());
	}
}

@wrapMethod(W3CraftingManager)
function Craft(schemName : name, out item : SItemUniqueId) : ECraftingException
{
	IC_AddMissing(schemName);
	return wrappedMethod(schemName, item);
}

// Alle Schmiede-Rezepte im Menue zeigen
@addField(CR4CraftingMenu)
var IC_pressTag : name;
@addField(CR4CraftingMenu)
var IC_pressTime : float;
@addField(CR4CraftingMenu)
var IC_inPress : bool;

@wrapMethod(CR4CraftingMenu)
function OnConfigUI()
{
	wrappedMethod();
	m_craftingManager = new W3CraftingManager in this;
	m_craftingManager.IC_InitAll(_craftsmanComponent);
	m_schematicList = IC_AllRecipeNames('crafting_schematics');
	PopulateData();
}

// Ein Klick = sofort herstellen
@wrapMethod(CR4CraftingMenu)
function OnEntryPress(tag : name)
{
	wrappedMethod(tag);
	IC_inPress = true;
	OnCraftItem(tag);
	IC_inPress = false;
	IC_pressTag = tag;
	IC_pressTime = theGame.GetEngineTimeAsSeconds();
}

@wrapMethod(CR4CraftingMenu)
function OnCraftItem(tag : name)
{
	if (!IC_inPress && tag == IC_pressTag && theGame.GetEngineTimeAsSeconds() - IC_pressTime < 3.0)
		return;
	wrappedMethod(tag);
}
