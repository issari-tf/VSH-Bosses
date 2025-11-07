#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <saxtonhale>
#include <sdktools>
#include <sdkhooks>
#include <tf2attributes>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>
#include <dhooks>

#undef REQUIRE_EXTENSIONS
#tryinclude <tf2items>
#define REQUIRE_EXTENSIONS

#define PLUGIN_VERSION                "1.0.0"
#define PLUGIN_VERSION_REVISION       "manual"

#define MAX_ATTRIBUTES_SENT 			    20
#define ATTRIB_LESSHEALING				    734
#define ATTRIB_MELEE_RANGE_MULTIPLIER 264
#define ATTRIB_JUMP_HEIGHT            326

#define PARTICLE_GHOST                "ghost_appearation"

#define SOUND_ALERT                   "ui/system_message_alert.wav"
#define SOUND_BACKSTAB                "player/spy_shield_break.wav"
#define SOUND_NULL                    "vo/null.mp3"

const TFTeam TFTeam_Boss = TFTeam_Blue;
const TFTeam TFTeam_Attack = TFTeam_Red;

const TFObjectType TFObject_Invalid = view_as<TFObjectType>(-1);
const TFObjectMode TFObjectMode_Invalid = view_as<TFObjectMode>(-1);

enum
{
  WeaponSlot_Primary = 0,
  WeaponSlot_Secondary,
  WeaponSlot_Melee,
  WeaponSlot_PDABuild,
  WeaponSlot_PDADisguise = 3,
  WeaponSlot_PDADestroy,
  WeaponSlot_InvisWatch = 4,
  WeaponSlot_BuilderEngie,
  WeaponSlot_Unknown1,
  WeaponSlot_Head,
  WeaponSlot_Misc1,
  WeaponSlot_Action,
  WeaponSlot_Misc2
};

enum
{
  LifeState_Alive = 0,
  LifeState_Dead = 2
};

// TF ammo types - from tf_shareddefs.h
enum
{
  TF_AMMO_DUMMY = 0,
  TF_AMMO_PRIMARY,
  TF_AMMO_SECONDARY,
  TF_AMMO_METAL,
  TF_AMMO_GRENADES1,
  TF_AMMO_GRENADES2,
  TF_AMMO_GRENADES3,

  TF_AMMO_COUNT,
};

enum
{
  COLLISION_GROUP_NONE  = 0,
  COLLISION_GROUP_DEBRIS,             // Collides with nothing but world and static stuff
  COLLISION_GROUP_DEBRIS_TRIGGER,     // Same as debris, but hits triggers
  COLLISION_GROUP_INTERACTIVE_DEBRIS, // Collides with everything except other interactive debris or debris
  COLLISION_GROUP_INTERACTIVE,        // Collides with everything except interactive debris or debris
  COLLISION_GROUP_PLAYER,
  COLLISION_GROUP_BREAKABLE_GLASS,
  COLLISION_GROUP_VEHICLE,
  COLLISION_GROUP_PLAYER_MOVEMENT,    // For HL2, same as Collision_Group_Player, for
                                      // TF2, this filters out other players and CBaseObjects
  COLLISION_GROUP_NPC,			          // Generic NPC group
  COLLISION_GROUP_IN_VEHICLE,		      // for any entity inside a vehicle
  COLLISION_GROUP_WEAPON,			        // for any weapons that need collision detection
  COLLISION_GROUP_VEHICLE_CLIP,	      // vehicle clip brush to restrict vehicle movement
  COLLISION_GROUP_PROJECTILE,		      // Projectiles!
  COLLISION_GROUP_DOOR_BLOCKER,	      // Blocks entities not permitted to get near moving doors
  COLLISION_GROUP_PASSABLE_DOOR,	    // Doors that the player shouldn't collide with
  COLLISION_GROUP_DISSOLVING,		      // Things that are dissolving are in this group
  COLLISION_GROUP_PUSHAWAY,		        // Nonsolid on client and server, pushaway in player code

  COLLISION_GROUP_NPC_ACTOR,		      // Used so NPCs in scripts ignore the player.
  COLLISION_GROUP_NPC_SCRIPTED,	      // USed for NPCs in scripts that should not collide with each other

  LAST_SHARED_COLLISION_GROUP
};

// entity effects
enum
{
  EF_BONEMERGE          = (1<<0),	// Performs bone merge on client side
  EF_BRIGHTLIGHT        = (1<<1),	// DLIGHT centered at entity origin
  EF_DIMLIGHT           = (1<<2),	// player flashlight
  EF_NOINTERP           = (1<<3),	// don't interpolate the next frame
  EF_NOSHADOW           = (1<<4),	// Don't cast no shadow
  EF_NODRAW             = (1<<5),	// don't draw entity
  EF_NORECEIVESHADOW		= (1<<6),	// Don't receive no shadow
  EF_BONEMERGE_FASTCULL	= (1<<7),	// For use with EF_BONEMERGE. If this is set, then it places this ent's origin at its
                                  // parent and uses the parent's bbox + the max extents of the aiment.
                                  // Otherwise, it sets up the parent's bones every frame to figure out where to place
                                  // the aiment, which is inefficient because it'll setup the parent's bones even if
                                  // the parent is not in the PVS.
  EF_ITEM_BLINK         = (1<<8), // blink an item so that the user notices it.
  EF_PARENT_ANIMATES		= (1<<9),	// always assume that the parent entity is animating
};

// Settings for m_takedamage - from shareddefs.h
enum
{
  DAMAGE_NO = 0,
  DAMAGE_EVENTS_ONLY, // Call damage functions, but don't modify health
  DAMAGE_YES,
  DAMAGE_AIM,
};

enum
{
  DONT_BLEED = -1,
  
  BLOOD_COLOR_RED = 0,
  BLOOD_COLOR_YELLOW,
  BLOOD_COLOR_GREEN,
  BLOOD_COLOR_MECH,
};


// TF2 Class names, ordered from TFClassType
char g_strClassName[TFClassType][] = {
  "Unknown",
  "Scout",
  "Sniper",
  "Soldier",
  "Demoman",
  "Medic",
  "Heavy",
  "Pyro",
  "Spy",
  "Engineer",
};


// TF2 Building names
char g_strBuildingName[TFObjectType][TFObjectMode][] = {
  {"Dispenser", ""},
  {"Teleporter Entrance", "Teleporter Exit"},
  {"Sentry Gun", ""},
  {"Sapper", ""},
};

//bool g_bTF2Items;

int g_iSpritesLaserbeam;
int g_iSpritesGlow;

#include "vshboss/abilities/ability_body_eat.sp"
#include "vshboss/abilities/ability_brave_jump.sp"
#include "vshboss/abilities/ability_dash_jump.sp"
#include "vshboss/abilities/ability_groundpound.sp"
#include "vshboss/abilities/ability_lunge.sp"
#include "vshboss/abilities/ability_pounce.sp"
#include "vshboss/abilities/ability_rage_attributes.sp"
#include "vshboss/abilities/ability_rage_bomb.sp"
#include "vshboss/abilities/ability_rage_bomb_projectile.sp"
#include "vshboss/abilities/ability_rage_conditions.sp"
#include "vshboss/abilities/ability_rage_freeze.sp"
#include "vshboss/abilities/ability_rage_ghost.sp"
#include "vshboss/abilities/ability_rage_light.sp"
#include "vshboss/abilities/ability_rage_meteor.sp"
#include "vshboss/abilities/ability_rage_scare.sp"
#include "vshboss/abilities/ability_teleport_swap.sp"
#include "vshboss/abilities/ability_teleport_view.sp"
#include "vshboss/abilities/ability_wallclimb.sp"
#include "vshboss/abilities/ability_weapon_ball.sp"
#include "vshboss/abilities/ability_weapon_charge.sp"
#include "vshboss/abilities/ability_weapon_fists.sp"
#include "vshboss/abilities/ability_weapon_sentry.sp"
#include "vshboss/abilities/ability_weapon_spells.sp"

#include "vshboss/bosses/boss_announcer.sp"
#include "vshboss/bosses/boss_blutarch.sp"
#include "vshboss/bosses/boss_brutalsniper.sp"
#include "vshboss/bosses/boss_bunny.sp"
#include "vshboss/bosses/boss_demopan.sp"
#include "vshboss/bosses/boss_demorobot.sp"
#include "vshboss/bosses/boss_gentlespy.sp"
#include "vshboss/bosses/boss_graymann.sp"
#include "vshboss/bosses/boss_hale.sp"
#include "vshboss/bosses/boss_horsemann.sp"
#include "vshboss/bosses/boss_painiscupcakes.sp"
#include "vshboss/bosses/boss_redmond.sp"
#include "vshboss/bosses/boss_seeldier.sp"
#include "vshboss/bosses/boss_seeman.sp"
#include "vshboss/bosses/boss_vagineer.sp"
#include "vshboss/bosses/boss_yeti.sp"
#include "vshboss/bosses/boss_merasmus.sp"
#include "vshboss/bosses/boss_zombie.sp"

#include "vshboss/bossesmulti/bossmulti_mannbrothers.sp"
#include "vshboss/bossesmulti/bossmulti_seemanseeldier.sp"

#include "vshboss/stocks.sp"
#include "vshboss/sdk.sp"

public Plugin myinfo =
{
  name               = "VSH Bosses",
  author             = "Aidan Sanders",
  description        = "",
  version            = PLUGIN_VERSION ... "." ... PLUGIN_VERSION_REVISION,
  url                = "",
};

public void OnPluginStart()
{
  // OnLibraryAdded dont always call TF2Items on plugin start
  //g_bTF2Items = LibraryExists("TF2Items");

  SDK_Init();
}

public void OnMapStart()
{
  PrecacheSound(SOUND_ALERT);
  PrecacheSound(SOUND_BACKSTAB);
  PrecacheSound(SOUND_NULL);

  g_iSpritesLaserbeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
  g_iSpritesGlow = PrecacheModel("materials/sprites/glow01.vmt", true);
}

public void OnLibraryAdded(const char[] name)
{
  if (StrEqual(name, "saxtonhale"))
  {
    // Register normal bosses
    SaxtonHale_RegisterClass("SaxtonHale",            VSHClassType_Boss);

    SaxtonHale_RegisterClass("Announcer",             VSHClassType_Boss);
    SaxtonHale_RegisterClass("Blutarch",              VSHClassType_Boss);
    SaxtonHale_RegisterClass("Bunny",                 VSHClassType_Boss);
    SaxtonHale_RegisterClass("BrutalSniper",          VSHClassType_Boss);
    SaxtonHale_RegisterClass("DemoPan",               VSHClassType_Boss);
    SaxtonHale_RegisterClass("DemoRobot",             VSHClassType_Boss);
    //SaxtonHale_RegisterClass("GentleSpy",             VSHClassType_Boss);
    //SaxtonHale_RegisterClass("GrayMann",              VSHClassType_Boss);
    SaxtonHale_RegisterClass("Horsemann",             VSHClassType_Boss);
    SaxtonHale_RegisterClass("Merasmus",              VSHClassType_Boss);
    SaxtonHale_RegisterClass("PainisCupcake",         VSHClassType_Boss);
    SaxtonHale_RegisterClass("Redmond",               VSHClassType_Boss);
    SaxtonHale_RegisterClass("Seeldier",              VSHClassType_Boss);
    SaxtonHale_RegisterClass("SeeMan",                VSHClassType_Boss);
    SaxtonHale_RegisterClass("Vagineer",              VSHClassType_Boss);
    SaxtonHale_RegisterClass("Yeti",                  VSHClassType_Boss);
    
    // Register multi bosses
    SaxtonHale_RegisterClass("MannBrothers",          VSHClassType_BossMulti);
    SaxtonHale_RegisterClass("SeeManSeeldier",        VSHClassType_BossMulti);

    // Register minions
    SaxtonHale_RegisterClass("SeeldierMinion",        VSHClassType_Boss);
    SaxtonHale_RegisterClass("AnnouncerMinion",       VSHClassType_Boss);
    //SaxtonHale_RegisterClass("MinionRanger",          VSHClassType_Boss);
    // Graymann seems to break server.
    //SaxtonHale_RegisterClass("GrayMannSoldierMinion", VSHClassType_Boss);
    //SaxtonHale_RegisterClass("GrayMannDemomanMinion", VSHClassType_Boss);
    //SaxtonHale_RegisterClass("GrayMannPyroMinion",    VSHClassType_Boss);
    SaxtonHale_RegisterClass("Zombie",                VSHClassType_Boss);

    // Register ability
    SaxtonHale_RegisterClass("BodyEat",               VSHClassType_Ability);
    SaxtonHale_RegisterClass("Bomb",                  VSHClassType_Ability);
    SaxtonHale_RegisterClass("BombProjectile",        VSHClassType_Ability);
    SaxtonHale_RegisterClass("BraveJump",             VSHClassType_Ability);
    SaxtonHale_RegisterClass("DashJump",              VSHClassType_Ability);
    SaxtonHale_RegisterClass("Pounce",                VSHClassType_Ability);
    SaxtonHale_RegisterClass("GroundPound",           VSHClassType_Ability);
    SaxtonHale_RegisterClass("Lunge",                 VSHClassType_Ability);
    SaxtonHale_RegisterClass("RageAttributes",        VSHClassType_Ability);
    SaxtonHale_RegisterClass("RageAddCond",           VSHClassType_Ability);
    SaxtonHale_RegisterClass("RageFreeze",            VSHClassType_Ability);
    SaxtonHale_RegisterClass("RageGhost",             VSHClassType_Ability);
    SaxtonHale_RegisterClass("LightRage",             VSHClassType_Ability);
    SaxtonHale_RegisterClass("RageMeteor",            VSHClassType_Ability);
    SaxtonHale_RegisterClass("ScareRage",             VSHClassType_Ability);
    SaxtonHale_RegisterClass("TeleportSwap",          VSHClassType_Ability);
    SaxtonHale_RegisterClass("TeleportView",          VSHClassType_Ability);
    SaxtonHale_RegisterClass("WallClimb",             VSHClassType_Ability);
    SaxtonHale_RegisterClass("WeaponBall",            VSHClassType_Ability);
    SaxtonHale_RegisterClass("WeaponCharge",          VSHClassType_Ability);
    SaxtonHale_RegisterClass("WeaponFists",           VSHClassType_Ability);
    SaxtonHale_RegisterClass("WeaponSentry",          VSHClassType_Ability);
    SaxtonHale_RegisterClass("WeaponSpells",          VSHClassType_Ability);
  }
}


public void ApplyBossModel(int iClient)
{
  SaxtonHaleBase boss = SaxtonHaleBase(iClient);
  if (!boss.bValid) return;
  
  char sModel[255];
  boss.CallFunction("GetModel", sModel, sizeof(sModel));
  SetVariantString(sModel);
  AcceptEntityInput(iClient, "SetCustomModel");
  SetEntProp(iClient, Prop_Send, "m_bUseClassAnimations", true);
  //SetEntPropFloat(iClient, Prop_Send, "m_flModelScale", 1.25);
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int itemDefIndex, Handle &item)
{
  return GiveNamedItem(client, classname, itemDefIndex);
}

Action GiveNamedItem(int iClient, const char[] sClassname, int iIndex)
{
  //if (!g_bEnabled) return Plugin_Continue;
  
  SaxtonHaleBase boss = SaxtonHaleBase(iClient);
  if (boss.bValid)
    return boss.CallFunction("OnGiveNamedItem", sClassname, iIndex);
  //else if (g_ConfigIndex.IsRestricted(iIndex))
  //	return Plugin_Handled;
  
  return Plugin_Continue;
}


public Action Timer_EntityCleanup(Handle hTimer, int iRef)
{
  int iEntity = EntRefToEntIndex(iRef);
  if(iEntity > MaxClients)
    AcceptEntityInput(iEntity, "Kill");
  return Plugin_Handled;
}


public Action Timer_DestroyLight(Handle hTimer, int iRef)
{
  int iLight = EntRefToEntIndex(iRef);
  if (iLight > MaxClients)
  {
    AcceptEntityInput(iLight, "TurnOff");
    RequestFrame(Frame_KillLight, iRef);
  }
  
  return Plugin_Continue;
}

void Frame_KillLight(int iRef)
{
  int iLight = EntRefToEntIndex(iRef);
  if (iLight > MaxClients)
    AcceptEntityInput(iLight, "Kill");
}
