#define PISSCAKEHOLE_MODEL "models/freak_fortress_2/piss_cakehole/realpisscakehole.mdl"
#define PISSCAKEHOLE_BGM "freak_fortress_2/piss_cakehole/pissbgm.mp3"

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

public void PissCakehole_Create(SaxtonHaleBase boss)
{
  boss.CreateClass("Slither");

  boss.CreateClass("RageAddCond");
  boss.SetPropFloat("RageAddCond", "RageCondDuration", 10.0);
  RageAddCond_AddCond(boss, TFCond_UberchargedCanteen);
  
  boss.iHealthPerPlayer = 500;
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
  StrCat(sInfo, length, "");
}

public void PissCakehole_GetModel(SaxtonHaleBase boss, char[] sModel, int length)
{
  strcopy(sModel, length, PISSCAKEHOLE_MODEL);
}

public void PissCakehole_OnSpawn(SaxtonHaleBase boss)
{
  char attribs[128];
  Format(attribs, sizeof(attribs), "2 ; 3.0 ; 252 ; 0.5 ; 68 ; 2.0");
  int iWeapon = boss.CallFunction("CreateWeapon", 8, "tf_weapon_bonesaw", 100, TFQual_Strange, attribs);
  if (iWeapon > MaxClients)
    SetEntPropEnt(boss.iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
  
  SetVariantString(PISSCAKEHOLE_MODEL);
  AcceptEntityInput(boss.iClient, "SetCustomModel");
  SetEntProp(boss.iClient, Prop_Send, "m_bUseClassAnimations", 1);
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
}

public void PissCakehole_GetMusicInfo(SaxtonHaleBase boss, char[] sSound, int length, float &time)
{
  strcopy(sSound, length, PISSCAKEHOLE_BGM);
  time = 136.0;
}

public void PissCakehole_Precache(SaxtonHaleBase boss)
{
  PrepareModel(PISSCAKEHOLE_MODEL);
  
  PrepareMusic(PISSCAKEHOLE_BGM);
  
  for (int i = 0; i < sizeof(g_strPissCakeholeRoundStart); i++) PrecacheSound(g_strPissCakeholeRoundStart[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeWin); i++) PrecacheSound(g_strPissCakeholeWin[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeLose); i++) PrecacheSound(g_strPissCakeholeLose[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeRage); i++) PrecacheSound(g_strPissCakeholeRage[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeJump); i++) PrecacheSound(g_strPissCakeholeJump[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeKillSpree); i++) PrecacheSound(g_strPissCakeholeKillSpree[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeCatchPhrase); i++) PrecacheSound(g_strPissCakeholeCatchPhrase[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeLastMan); i++) PrecacheSound(g_strPissCakeholeLastMan[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeHit); i++) PrecacheSound(g_strPissCakeholeHit[i]);
  for (int i = 0; i < sizeof(g_strPissCakeholeSlither); i++) PrepareSound(g_strPissCakeholeSlither[i]);

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
  
  AddFileToDownloadsTable("models/freak_fortress_2/piss_cakehole/realpisscakehole.dx80.vtx");
  AddFileToDownloadsTable("models/freak_fortress_2/piss_cakehole/realpisscakehole.dx90.vtx");
  AddFileToDownloadsTable("models/freak_fortress_2/piss_cakehole/realpisscakehole.mdl");
  AddFileToDownloadsTable("models/freak_fortress_2/piss_cakehole/realpisscakehole.phy");
  AddFileToDownloadsTable("models/freak_fortress_2/piss_cakehole/realpisscakehole.vvd");
  AddFileToDownloadsTable("models/freak_fortress_2/piss_cakehole/realpisscakehole.sw.vtx");
  
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/iampisscakehole.wav");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_intro.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_laugh.wav");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_win.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_die1.wav");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_die2.wav");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/pissbgm.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_jump1.wav");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_rage.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_hitv2.mp3");
  AddFileToDownloadsTable("sound/freak_fortress_2/piss_cakehole/piss_slither.mp3");
}