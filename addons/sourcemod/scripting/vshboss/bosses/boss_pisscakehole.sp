#define PISSCAKEHOLE_MODEL "models/freak_fortress_2/piss_cakehole_issari/realpisscakehole.mdl"
#define PISSCAKEHOLE_BGM "freak_fortress_2/piss_cakehole/pissbgm.mp3"
#define PISSCAKEHOLE_RAGE_BGM "freak_fortress_2/piss_cakehole/pissragebgm.mp3"

static char g_strPissCakeholeRoundStart[][] = {
  "freak_fortress_2/piss_cakehole/piss_intro.mp3"
};

static char g_strPissCakeholeWin[][] = {
  "freak_fortress_2/piss_cakehole/piss_win.mp3"
};

static char g_strPissCakeholeLose[][] = {
  "freak_fortress_2/piss_cakehole/piss_die1.wav",
  "freak_fortress_2/piss_cakehole/piss_die2.wav"
};

static char g_strPissCakeholeRage[][] = {
  "freak_fortress_2/piss_cakehole/piss_rage.mp3"
};

static char g_strPissCakeholeJump[][] = {
  "freak_fortress_2/piss_cakehole/piss_jump1.wav"
};

static char g_strPissCakeholeSlither[][] = {
  "freak_fortress_2/piss_cakehole/piss_slither.mp3"
};

static char g_strPissCakeholeKillSpree[][] = {
  "freak_fortress_2/piss_cakehole/piss_laugh.wav"
};

static char g_strPissCakeholeCatchPhrase[][] = {
  "freak_fortress_2/piss_cakehole/iampisscakehole.wav"
};

static char g_strPissCakeholeLastMan[][] = {
  "freak_fortress_2/piss_cakehole/piss_laugh.wav"
};

static char g_strPissCakeholeHit[][] = {
  "freak_fortress_2/piss_cakehole/piss_hitv2.mp3"
};

static char g_strPissCakeholeExplosion[][] = {
  "freak_fortress_2/piss_cakehole/pexplosion.mp3"
};

static int g_iRageWeapon[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

public void PissCakehole_Create(SaxtonHaleBase boss)
{
  boss.CreateClass("Slither");
  boss.CreateClass("PissLunge");
  boss.CreateClass("Shockwave"); // Shockwave ability during rage
  
  boss.CreateClass("RageAddCond");
  boss.SetPropFloat("RageAddCond", "RageCondDuration", 15.0);
  RageAddCond_AddCond(boss, TFCond_UberchargedCanteen);
  
  boss.CreateClass("RageAttributes");
  boss.SetPropFloat("RageAttributes", "RageAttribDuration", 999999.0); // Permanent
  RageAttributes_AddAttrib(boss, 107, 1.3, 1.3, false); // 1.3x move speed
  
  boss.iHealthPerPlayer = 600;
  boss.flHealthExponential = 1.05;
  boss.nClass = TFClass_Sniper;
  boss.iMaxRageDamage = 2500;
}

public void PissCakehole_GetBossName(SaxtonHaleBase boss, char[] sName, int length)
{
  strcopy(sName, length, "Piss Cakehole");
}

public void PissCakehole_GetBossInfo(SaxtonHaleBase boss, char[] sInfo, int length)
{
  StrCat(sInfo, length, "\nHealth: Medium");
  StrCat(sInfo, length, "\n ");
  StrCat(sInfo, length, "\nAbilities");
  StrCat(sInfo, length, "\n- Slither: Fast movement that can climb walls");
  StrCat(sInfo, length, "\n  Interrupted if taking 25+ damage in one hit");
  StrCat(sInfo, length, "\n ");
  StrCat(sInfo, length, "\nRage");
  StrCat(sInfo, length, "\n- Damage requirement: 2500");
  StrCat(sInfo, length, "\n- Übercharge, 1.3x speed, and Half-Zatoichi for 10 seconds");
  StrCat(sInfo, length, "\n- Slither replaced with Piss Lunge (instant kill aerial attack)");
  StrCat(sInfo, length, "\n- Shockwave: knockback + 10 damage (3 uses, 8s cooldown)");
  StrCat(sInfo, length, "\n- 200%% Rage: extends duration to 30 seconds");
}

public void PissCakehole_GetModel(SaxtonHaleBase boss, char[] sModel, int length)
{
  strcopy(sModel, length, PISSCAKEHOLE_MODEL);
}

public void PissCakehole_OnSpawn(SaxtonHaleBase boss)
{
  char attribs[128];
  // 100 damage, 0.5 knockback resistance, 2x capture rate, 5 seconds bleed on hit
  Format(attribs, sizeof(attribs), "2 ; 1.54 ; 252 ; 0.5 ; 68 ; 2.0 ; 149 ; 5.0");
  int iWeapon = boss.CallFunction("CreateWeapon", 8, "tf_weapon_bonesaw", 100, TFQual_Strange, attribs);
  if (iWeapon > MaxClients)
    SetEntPropEnt(boss.iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
  
  SetVariantString(PISSCAKEHOLE_MODEL);
  AcceptEntityInput(boss.iClient, "SetCustomModel");
  SetEntProp(boss.iClient, Prop_Send, "m_bUseClassAnimations", 1);
  
  g_iRageWeapon[boss.iClient] = INVALID_ENT_REFERENCE;
}

public void PissCakehole_OnRage(SaxtonHaleBase boss)
{
  // Play rage animation
  SDKCall_PlaySpecificSequence(boss.iClient, "rage");
  
  // Freeze during animation (4 seconds)
  SetEntityMoveType(boss.iClient, MOVETYPE_NONE);
  TF2_AddCondition(boss.iClient, TFCond_FreezeInput, 4.0);
  
  // Force third person during animation
  SetVariantInt(1);
  AcceptEntityInput(boss.iClient, "SetForcedTauntCam");
  
  // After animation, give weapon and swap abilities
  CreateTimer(4.0, Timer_RageAnimationEnd, GetClientUserId(boss.iClient));
  
  // Schedule rage end to restore abilities
  float flDuration = boss.GetPropFloat("RageAddCond", "RageCondDuration");
  if (boss.bSuperRage)
    flDuration *= boss.GetPropFloat("RageAddCond", "RageCondSuperRageMultiplier");
  
  CreateTimer(flDuration, Timer_RageEnd, GetClientUserId(boss.iClient));
}

public Action Timer_RageAnimationEnd(Handle hTimer, int iUserId)
{
  int iClient = GetClientOfUserId(iUserId);
  if (iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
    return Plugin_Stop;
  
  SaxtonHaleBase boss = SaxtonHaleBase(iClient);
  
  // Unfreeze
  SetEntityMoveType(iClient, MOVETYPE_WALK);
  TF2_RemoveCondition(iClient, TFCond_FreezeInput);
  
  // Return to first person
  SetVariantInt(0);
  AcceptEntityInput(iClient, "SetForcedTauntCam");
  
  // Swap abilities
  if (boss.HasClass("Slither"))
    Slither_Disable(boss);
  
  if (boss.HasClass("PissLunge"))
    PissLunge_Enable(boss);
  
  // Remove old weapon
  int iOldWeapon = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
  if (iOldWeapon > MaxClients && IsValidEntity(iOldWeapon))
  {
    RemovePlayerItem(iClient, iOldWeapon);
    RemoveEntity(iOldWeapon);
  }
  
  // Create Half-Zatoichi: 200 damage (3.08x), 2x attack speed (0.5)
  char attribs[256];
  Format(attribs, sizeof(attribs), "2 ; 3.08 ; 6 ; 0.5");
  
  int iWeapon = boss.CallFunction("CreateWeapon", 357, "tf_weapon_katana", 100, TFQual_Strange, attribs);
  if (iWeapon > MaxClients)
  {
    SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
    g_iRageWeapon[iClient] = EntIndexToEntRef(iWeapon);
    FakeClientCommand(iClient, "slot3");
  }
  
  // Apply green glow
  SetEntityRenderMode(iClient, RENDER_TRANSCOLOR);
  SetEntityRenderColor(iClient, 0, 255, 0, 255);
  
  // Activate Shockwave ability
  if (boss.HasClass("Shockwave"))
    Shockwave_Activate(boss);
  
  return Plugin_Stop;
}

public Action Timer_RageEnd(Handle hTimer, int iUserId)
{
  int iClient = GetClientOfUserId(iUserId);
  if (iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
    return Plugin_Stop;
  
  SaxtonHaleBase boss = SaxtonHaleBase(iClient);
  
  // Restore abilities
  if (boss.HasClass("PissLunge"))
    PissLunge_Disable(boss);
  
  if (boss.HasClass("Slither"))
    Slither_Enable(boss);
  
  // Deactivate Shockwave
  if (boss.HasClass("Shockwave"))
    Shockwave_Deactivate(boss);
  
  // Remove rage weapon and restore bonesaw
  int iOldWeapon = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
  if (iOldWeapon > MaxClients && IsValidEntity(iOldWeapon))
  {
    RemovePlayerItem(iClient, iOldWeapon);
    RemoveEntity(iOldWeapon);
  }
  
  // Recreate bonesaw
  char attribs[128];
  Format(attribs, sizeof(attribs), "2 ; 1.54 ; 252 ; 0.5 ; 68 ; 2.0 ; 149 ; 5.0");
  int iWeapon = boss.CallFunction("CreateWeapon", 8, "tf_weapon_bonesaw", 100, TFQual_Strange, attribs);
  if (iWeapon > MaxClients)
  {
    SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
    FakeClientCommand(iClient, "slot3");
  }
  
  // Remove green glow
  SetEntityRenderMode(iClient, RENDER_NORMAL);
  SetEntityRenderColor(iClient, 255, 255, 255, 255);
  
  return Plugin_Stop;
}

public void PissCakehole_GetSound(SaxtonHaleBase boss, char[] sSound, int length, SaxtonHaleSound iSoundType)
{
  switch (iSoundType)
  {
    case VSHSound_RoundStart: strcopy(sSound, length, g_strPissCakeholeRoundStart[GetRandomInt(0,sizeof(g_strPissCakeholeRoundStart)-1)]);
    case VSHSound_Win: strcopy(sSound, length, g_strPissCakeholeWin[GetRandomInt(0,sizeof(g_strPissCakeholeWin)-1)]);
    case VSHSound_Lose: strcopy(sSound, length, g_strPissCakeholeLose[GetRandomInt(0,sizeof(g_strPissCakeholeLose)-1)]);
    case VSHSound_Rage: strcopy(sSound, length, g_strPissCakeholeRage[GetRandomInt(0,sizeof(g_strPissCakeholeRage)-1)]);
    case VSHSound_Lastman: strcopy(sSound, length, g_strPissCakeholeLastMan[GetRandomInt(0,sizeof(g_strPissCakeholeLastMan)-1)]);
  }
}

public void PissCakehole_GetSoundAbility(SaxtonHaleBase boss, char[] sSound, int length, const char[] sType)
{
  if (strcmp(sType, "BraveJump") == 0)
    strcopy(sSound, length, g_strPissCakeholeJump[GetRandomInt(0,sizeof(g_strPissCakeholeJump)-1)]);

  if (strcmp(sType, "Slither") == 0)
    strcopy(sSound, length, g_strPissCakeholeSlither[GetRandomInt(0,sizeof(g_strPissCakeholeSlither)-1)]);
  
  if (strcmp(sType, "SlitherLoop") == 0)
    strcopy(sSound, length, "freak_fortress_2/piss_cakehole/piss_slither_loop.mp3");
  
  if (strcmp(sType, "PissLungeStart") == 0)
    strcopy(sSound, length, g_strPissCakeholeJump[GetRandomInt(0,sizeof(g_strPissCakeholeJump)-1)]);
  
  if (strcmp(sType, "PissLungeMiss") == 0)
    strcopy(sSound, length, g_strPissCakeholeKillSpree[GetRandomInt(0,sizeof(g_strPissCakeholeKillSpree)-1)]);
  
  if (strcmp(sType, "PissLungeCarve") == 0)
    strcopy(sSound, length, g_strPissCakeholeHit[GetRandomInt(0,sizeof(g_strPissCakeholeHit)-1)]);
  
  if (strcmp(sType, "Shockwave") == 0)
    strcopy(sSound, length, g_strPissCakeholeExplosion[GetRandomInt(0,sizeof(g_strPissCakeholeExplosion)-1)]);
}

public void PissCakehole_GetMusicInfo(SaxtonHaleBase boss, char[] sSound, int length, float &time)
{
  strcopy(sSound, length, PISSCAKEHOLE_BGM);
  time = 136.0;
}

public void PissCakehole_GetRageMusicInfo(SaxtonHaleBase boss, char[] sSound, int length, float &time)
{
  strcopy(sSound, length, PISSCAKEHOLE_RAGE_BGM);
  
  // Match rage duration
  float flDuration = boss.GetPropFloat("RageAddCond", "RageCondDuration");
  if (boss.bSuperRage)
    flDuration *= boss.GetPropFloat("RageAddCond", "RageCondSuperRageMultiplier");
  
  time = flDuration;
}

public void PissCakehole_Precache(SaxtonHaleBase boss)
{
  PrepareModel(PISSCAKEHOLE_MODEL);
  
  PrepareSound(PISSCAKEHOLE_RAGE_BGM);
  
  for (int i = 0; i < sizeof(g_strPissCakeholeRoundStart); i++) PrecacheSound(g_strPissCakeholeRoundStart[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeWin); i++) PrecacheSound(g_strPissCakeholeWin[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeLose); i++) PrecacheSound(g_strPissCakeholeLose[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeRage); i++) PrecacheSound(g_strPissCakeholeRage[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeJump); i++) PrecacheSound(g_strPissCakeholeJump[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeKillSpree); i++) PrecacheSound(g_strPissCakeholeKillSpree[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeCatchPhrase); i++) PrecacheSound(g_strPissCakeholeCatchPhrase[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeLastMan); i++) PrecacheSound(g_strPissCakeholeLastMan[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeHit); i++) PrecacheSound(g_strPissCakeholeHit[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeExplosion); i++) PrecacheSound(g_strPissCakeholeExplosion[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeSlither); i++) PrepareSound(g_strPissCakeholeSlither[i]);
  PrecacheSound("freak_fortress_2/piss_cakehole/piss_slither_loop.mp3");
  
  PrecacheDecal("Blood");
  
  AddFileToDownloadsTable("materials/models/piscke2/sniper/sniper_blue_invun.vmt");
  AddFileToDownloadsTable("materials/models/piscke2/sniper/sniper_blue_invun.vtf");
  AddFileToDownloadsTable("materials/models/piscke2/sniper/sniper_head_blue.vmt");
  AddFileToDownloadsTable("materials/models/piscke2/sniper/sniper_head_blue.vtf");
  AddFileToDownloadsTable("materials/models/piscke2/sniper/sniper_head_blue_invun.vmt");
  AddFileToDownloadsTable("materials/models/piscke2/sniper/sniper_head_blue_invun.vtf");
  AddFileToDownloadsTable("materials/models/piscke2/sniper/sniper_head_red.vmt");
  AddFileToDownloadsTable("materials/models/piscke2/sniper/sniper_head_red.vtf");
  AddFileToDownloadsTable("materials/models/piscke2/sniper/sniper_red.vmt");
  AddFileToDownloadsTable("materials/models/piscke2/sniper/sniper_red.vtf");
  AddFileToDownloadsTable("materials/models/piscke2/sniper/invulnerability_blue.vmt");
  AddFileToDownloadsTable("materials/models/piscke2/sniper/invulnerability_blue.vtf");
  
  AddFileToDownloadsTable("models/freak_fortress_2/piss_cakehole_issari/realpisscakehole.dx80.vtx");
  AddFileToDownloadsTable("models/freak_fortress_2/piss_cakehole_issari/realpisscakehole.dx90.vtx");
  AddFileToDownloadsTable("models/freak_fortress_2/piss_cakehole_issari/realpisscakehole.mdl");
  AddFileToDownloadsTable("models/freak_fortress_2/piss_cakehole_issari/realpisscakehole.phy");
  AddFileToDownloadsTable("models/freak_fortress_2/piss_cakehole_issari/realpisscakehole.vvd");
  AddFileToDownloadsTable("models/freak_fortress_2/piss_cakehole_issari/realpisscakehole.sw.vtx");
  
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/iampisscakehole.wav");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_intro.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_laugh.wav");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_win.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_die1.wav");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_die2.wav");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/pissbgm.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/pissragebgm.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/pexplosion.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_jump1.wav");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_rage.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_hitv2.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_slither.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_slither_loop.mp3");
}