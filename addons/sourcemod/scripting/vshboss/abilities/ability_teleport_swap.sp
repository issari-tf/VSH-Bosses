static float g_flTeleportSwapCooldownWait[MAXPLAYERS];
static bool g_bTeleportSwapHoldingChargeButton[MAXPLAYERS];

static float gl_flVortexPos[3];
static int gl_iVortexIndex[2];

public void TeleportSwap_Create(SaxtonHaleBase boss)
{
  //Default values, these can be changed if needed
  boss.SetPropInt("TeleportSwap", "Charge", 0);
  boss.SetPropInt("TeleportSwap", "MaxCharge", 200);
  boss.SetPropInt("TeleportSwap", "ChargeBuild", 4);
  boss.SetPropFloat("TeleportSwap", "Cooldown", 30.0);
  boss.SetPropFloat("TeleportSwap", "StunDuration", 1.0);
  boss.SetPropFloat("TeleportSwap", "EyeAngleRequirement", -60.0);	//How far up should the boss look for the ability to trigger? Minimum value is -89.0 (all the way up)
  
  g_flTeleportSwapCooldownWait[boss.iClient] = GetGameTime() + boss.GetPropFloat("TeleportSwap", "Cooldown");
  boss.CallFunction("UpdateHudInfo", 1.0, boss.GetPropFloat("TeleportSwap", "Cooldown"));	//Update every second for cooldown duration

  gl_flVortexPos[0] = 0.0;
  gl_flVortexPos[1] = 0.0;
  gl_flVortexPos[2] = 0.0;

  gl_iVortexIndex[0] = -1;
  gl_iVortexIndex[1] = -1;
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

Action vortex_touch(int entity, int other)
{
    if (!IsValidEntity(other))
        return Plugin_Continue;

    // Only respond to real, in-game players
    if (!IsValidClient(other))
        return Plugin_Continue;

    if (!SaxtonHale_IsValidBoss(other))
    {
        TF2_AddCondition(other, TFCond_SpeedBuffAlly, 5.0);
    }

    return Plugin_Continue;
}


// Spawn Entrance later
public Action Timer_VortexEntrance(Handle hTimer)
{
  float duration = 30.0;
  gl_iVortexIndex[0] = CreateEntityByName("hightower_teleport_vortex");
  DispatchKeyValueFloat(gl_iVortexIndex[0], "duration", duration);
  DispatchKeyValueFloat(gl_iVortexIndex[0], "lifetime", GetGameTime() + duration);
  DispatchKeyValue(gl_iVortexIndex[0], "target_base_name", "vortex_exit");
  DispatchSpawn(gl_iVortexIndex[0]);
  TeleportEntity(gl_iVortexIndex[0], gl_flVortexPos, NULL_VECTOR, NULL_VECTOR);
  
  // when player touches
  SDKHook(gl_iVortexIndex[0], SDKHook_Touch, vortex_touch);
  
  // on think
  //HookEntityThink(gl_iVortexIndex[0], vortex_think);

  CreateTimer(28.0, RemoveEnt, EntIndexToEntRef(gl_iVortexIndex[0]), TIMER_FLAG_NO_MAPCHANGE);
  CreateTimer(28.0, RemoveEnt, EntIndexToEntRef(AttachParticle(gl_iVortexIndex[0], "eyeboss_tp_vortex", 50.0, false, 28.0)));
/*
  float duration = 30.0;
  // Spawn Portal Entrance at Client
  //float flPos[3]; GetClientAbsOrigin(iClient, flPos); // this spawns entrace at placer...
  gl_iVortexIndex[0] = CreateEntityByName("teleport_vortex"); // hightower_teleport_vortex
  DispatchKeyValueFloat(gl_iVortexIndex[0], "duration", duration);
  DispatchKeyValueFloat(gl_iVortexIndex[0], "lifetime", GetGameTime() + duration);
  DispatchSpawn(gl_iVortexIndex[0]);
  TeleportEntity(gl_iVortexIndex[0], gl_flVortexPos, NULL_VECTOR, NULL_VECTOR);
  CreateTimer(28.0, RemoveEnt, EntIndexToEntRef(gl_iVortexIndex[0]), TIMER_FLAG_NO_MAPCHANGE);
  CreateTimer(28.0, RemoveEnt, EntIndexToEntRef(AttachParticle(gl_iVortexIndex[0], "eyeboss_tp_vortex", 50.0, false, 28.0)));
*/
  return Plugin_Handled;
}









public void TeleportSwap_OnThink(SaxtonHaleBase boss)
{
  if (g_flTeleportSwapCooldownWait[boss.iClient] <= GetGameTime())
  {
    g_flTeleportSwapCooldownWait[boss.iClient] = 0.0;
    
    int iCharge = boss.GetPropInt("TeleportSwap", "Charge");
    int iChargeBuild = boss.GetPropInt("TeleportSwap", "ChargeBuild");
    int iMaxCharge = boss.GetPropInt("TeleportSwap", "MaxCharge");
    int iNewCharge;
    
    if (g_bTeleportSwapHoldingChargeButton[boss.iClient])
      iNewCharge = iCharge + iChargeBuild;
    else
      iNewCharge = iCharge - iChargeBuild * 2;
    
    if (iNewCharge > iMaxCharge)
      iNewCharge = iMaxCharge;
    else if (iNewCharge < 0)
      iNewCharge = 0;
    
    if (iCharge != iNewCharge)
    {
      boss.SetPropInt("TeleportSwap", "Charge", iNewCharge);
      boss.CallFunction("UpdateHudInfo", 0.0, 0.0);	//Update once
    }
  }
}

public void TeleportSwap_GetHudInfo(SaxtonHaleBase boss, char[] sMessage, int iLength, int iColor[4])
{
  if (g_flTeleportSwapCooldownWait[boss.iClient] != 0.0 && g_flTeleportSwapCooldownWait[boss.iClient] > GetGameTime())
  {
    int iSec = RoundToCeil(g_flTeleportSwapCooldownWait[boss.iClient]-GetGameTime());
    Format(sMessage, iLength, "%s\nTeleport-swap is on cooldown for %d second%s!", sMessage, iSec, (iSec > 1) ? "s" : "");
  }
  else if (boss.GetPropInt("TeleportSwap", "Charge") > 0)
  {
    Format(sMessage, iLength, "%s\nTeleport-swap: %.0f％. Look up and release right click to teleport.", sMessage, (float(boss.GetPropInt("TeleportSwap", "Charge"))/float(boss.GetPropInt("TeleportSwap", "MaxCharge")))*100.0);
  }
  else
  {
    Format(sMessage, iLength, "%s\nHold right click to use your teleport-swap!", sMessage);
  }
}

public void TeleportSwap_OnButton(SaxtonHaleBase boss, int &buttons)
{
  if (buttons & IN_ATTACK2)
    g_bTeleportSwapHoldingChargeButton[boss.iClient] = true;
}

public void TeleportSwap_OnButtonRelease(SaxtonHaleBase boss, int button)
{
  if (button == IN_ATTACK2)
  {
    g_bTeleportSwapHoldingChargeButton[boss.iClient] = false;
    
    if (g_flTeleportSwapCooldownWait[boss.iClient] > GetGameTime()) return;
    
    float vecAng[3];
    GetClientEyeAngles(boss.iClient, vecAng);
    
    if ((vecAng[0] <= boss.GetPropFloat("TeleportSwap", "EyeAngleRequirement")) && (boss.GetPropInt("TeleportSwap", "Charge") >= boss.GetPropInt("TeleportSwap", "MaxCharge")))
    {
      // Deny teleporting when stunned
      if (TF2_IsPlayerInCondition(boss.iClient, TFCond_Dazed))
      {
        PrintHintText(boss.iClient, "Can't teleport-swap when stunned.");
        return;
      }
      
      // Deny teleporting when airborne
      if (!(GetEntityFlags(boss.iClient) & FL_ONGROUND))
      {
        PrintHintText(boss.iClient, "Can't teleport-swap when airborne.");
        return;
      }
      
      // Get a list of valid attackers
      ArrayList aClients = new ArrayList();
      for (int i = 1; i <= MaxClients; i++)
        if (SaxtonHale_IsValidAttack(i) && IsPlayerAlive(i))
          aClients.Push(i);
      
      if (aClients.Length == 0)
      {
        //Nobody in list? okay...
        delete aClients;
        return;
      }
      
      aClients.Sort(Sort_Random, Sort_Integer);
      
      // Avoid teleporting to potential targets who are out of the dome
      int iClient[2];
      iClient[0] = boss.iClient;
      
      for (int i = 0; i < aClients.Length; i++)
      {
        int iTarget = aClients.Get(i);
        iClient[1] = iTarget;
        break;
      }
      
      delete aClients;
      
      // Deny teleporting if every target found is out of the dome
      if (!iClient[1])
      {
        PrintHintText(boss.iClient, "Can't teleport-swap, all possible targets are outside of the dome.");
        return;
      }

      // Create Delayed Vortex Entrance.
      GetClientAbsOrigin(iClient[0], gl_flVortexPos);
      CreateTimer(2.0, Timer_VortexEntrance, _, TIMER_FLAG_NO_MAPCHANGE);

      // Spawn Clients
      TF2_TeleportSwap(iClient);
      
      TF2_StunPlayer(iClient[0], boss.GetPropFloat("TeleportSwap", "StunDuration"), 0.0, TF_STUNFLAGS_GHOSTSCARE|TF_STUNFLAG_NOSOUNDOREFFECT, iClient[1]);
      TF2_AddCondition(iClient[0], TFCond_DefenseBuffMmmph, boss.GetPropFloat("TeleportSwap", "StunDuration"));
      
      g_flTeleportSwapCooldownWait[boss.iClient] = GetGameTime()+boss.GetPropFloat("TeleportSwap", "Cooldown");
      boss.CallFunction("UpdateHudInfo", 1.0, boss.GetPropFloat("TeleportSwap", "Cooldown"));	//Update every second for cooldown duration
      boss.SetPropInt("TeleportSwap", "Charge", 0);
      
      char sSound[PLATFORM_MAX_PATH];
      boss.CallFunction("GetSoundAbility", sSound, sizeof(sSound), "TeleportSwap");
      if (!StrEmpty(sSound))
        EmitSoundToAll(sSound, boss.iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
    
      // Spawn Portal Exit at Boss
      float flPos[3]; GetClientAbsOrigin(iClient[0], flPos);
      gl_iVortexIndex[1] = CreateEntityByName("info_target");
      DispatchKeyValue(gl_iVortexIndex[1], "targetname", "vortex_exit_loser");
      DispatchSpawn(gl_iVortexIndex[1]);
      TeleportEntity(gl_iVortexIndex[1], flPos, NULL_VECTOR, NULL_VECTOR);
      CreateTimer(30.0, RemoveEnt, EntIndexToEntRef(gl_iVortexIndex[1]), TIMER_FLAG_NO_MAPCHANGE);
      CreateTimer(30.0, RemoveEnt, EntIndexToEntRef(AttachParticle(iClient[0], "eb_death_vortex01", 50.0, false, 30.0)));
    }
  }
}