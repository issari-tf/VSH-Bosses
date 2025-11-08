#define PARTICLE_TELEPORT	"merasmus_tp"
#define TELEPORT_RADIUS 600.0
#define SOLID_BBOX 2

enum TeleportViewMode
{
  TeleportViewMode_None,
  TeleportViewMode_Teleporting,
  TeleportViewMode_Teleported
}

static TeleportViewMode g_nTeleportViewMode[MAXPLAYERS];
static float g_vecTeleportViewPos[MAXPLAYERS][3];
static float g_flTeleportViewStartCharge[MAXPLAYERS];
static float g_flTeleportViewCooldownWait[MAXPLAYERS];

static bool g_bIsBomb[MAXPLAYERS];
static Handle g_hBombTimer[MAXPLAYERS];

// on teleport we spawn bombs on players heads. 
// hook players on touch to see if touches boss.
// if timer runs out kill player.

public void TeleportView_Create(SaxtonHaleBase boss)
{
  //Default values, these can be changed if needed
  boss.SetPropFloat("TeleportView", "Charge", 2.0);
  boss.SetPropFloat("TeleportView", "Cooldown", 30.0);
  
  g_flTeleportViewStartCharge[boss.iClient] = 0.0;
  g_flTeleportViewCooldownWait[boss.iClient] = GetGameTime() + boss.GetPropFloat("TeleportView", "Cooldown");
  boss.CallFunction("UpdateHudInfo", 0.0, 0.0);	//Update once instead of every second

  // Reset all bomb states and timers
  for (int i = 1; i <= MaxClients; i++)
  {
    CleanupBomb(i);
  }
}

// Helper function to clean up bomb state
void CleanupBomb(int client)
{
  if (!IsValidClient(client))
    return;

  g_bIsBomb[client] = false;

  if (g_hBombTimer[client] != null)
  {
    CloseHandle(g_hBombTimer[client]);
    g_hBombTimer[client] = null;
  }

  SDKUnhook(client, SDKHook_Touch, Bomb_TouchHook);
  
  // Reset collision properties if modified
  if (IsPlayerAlive(client))
  {
    SetEntProp(client, Prop_Send, "m_nSolidType", SOLID_BBOX);
    SetEntProp(client, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER);
  }
}

public void TeleportView_OnPlayerDeath(int client)
{
  CleanupBomb(client);
}

public void TeleportView_OnPlayerDisconnect(int client)
{
  CleanupBomb(client);
}

public Action Bomb_TouchHook(int client, int other)
{
  // Validate the client holding the bomb
  if (!IsValidClient(client) || !IsPlayerAlive(client) || !g_bIsBomb[client])
    return Plugin_Continue;

  // Validate the entity being touched
  if (!IsValidClient(other) || !IsPlayerAlive(other) || g_bIsBomb[other])
    return Plugin_Continue;

  // if touching a boss
  if (SaxtonHale_IsValidBoss(other))
  {
    PrintToChatAll("%N touched the boss!", client);

    // Clear bomb from current holder
    if (g_hBombTimer[client] != null)
    {
      CloseHandle(g_hBombTimer[client]);
      g_hBombTimer[client] = null;
    }

    TF2_RemoveCondition(client, TFCond_HalloweenBombHead);
    TF2_AddCondition(client, TFCond_Ubercharged, 10.0);
    TF2_AddCondition(client, TFCond_SpeedBuffAlly, 10.0);

    // Unhook and clear
    CleanupBomb(client);

    return Plugin_Continue;
  }

  PrintToChatAll("%N transferred the bomb to %N!", client, other);

  // Clear bomb from current holder
  if (g_hBombTimer[client] != null)
  {
    CloseHandle(g_hBombTimer[client]);
    g_hBombTimer[client] = null;
  }

  TF2_RemoveCondition(client, TFCond_HalloweenBombHead);
  TF2_AddCondition(client, TFCond_SpeedBuffAlly, 10.0);
  
  CleanupBomb(client);

  // Apply bomb to touched player
  g_bIsBomb[other] = true;

  // Set proper collision for bomb carrier
  SetEntProp(other, Prop_Send, "m_nSolidType", SOLID_BBOX);
  SetEntProp(other, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER);

  // Hook touch on new bomb carrier
  SDKHook(other, SDKHook_Touch, Bomb_TouchHook);

  // Set a new timer on the new bomb carrier
  g_hBombTimer[other] = CreateTimer(10.0, Bomb_ExpireTimer, GetClientUserId(other));
  
  return Plugin_Continue;
}

public Action Bomb_ExpireTimer(Handle timer, any userid)
{
  int client = GetClientOfUserId(userid);
  g_hBombTimer[client] = null;

  if (!IsClientInGame(client) || !IsPlayerAlive(client))
      return Plugin_Stop;

  if (g_bIsBomb[client])
  {
    PrintToChatAll("%N exploded because they didn't reach the boss!", client);
    TF2_RemoveCondition(client, TFCond_HalloweenBombHead);
    ForcePlayerSuicide(client);
    CleanupBomb(client);
  }

  return Plugin_Stop;
}

public void TeleportView_OnThink(SaxtonHaleBase boss)
{
  if (GameRules_GetRoundState() == RoundState_Preround)
    return;
  
  float flCharge = GetGameTime() - g_flTeleportViewStartCharge[boss.iClient];
  
  if (g_nTeleportViewMode[boss.iClient] == TeleportViewMode_Teleporting)
  {
    float vecOrigin[3];
    GetClientAbsOrigin(boss.iClient, vecOrigin);
    
    if (flCharge > boss.GetPropFloat("TeleportView", "Charge") + 1.5)
    {
      //Do the actual teleport
      
      g_nTeleportViewMode[boss.iClient] = TeleportViewMode_Teleported;
      boss.CallFunction("UpdateHudInfo", 0.0, 0.0);	//Update once
      
      //Create particle
      CreateTimer(3.0, Timer_EntityCleanup, TF2_SpawnParticle(PARTICLE_TELEPORT, vecOrigin));
      CreateTimer(3.0, Timer_EntityCleanup, TF2_SpawnParticle(PARTICLE_TELEPORT, g_vecTeleportViewPos[boss.iClient]));
      
      //Teleport
      TeleportEntity(boss.iClient, g_vecTeleportViewPos[boss.iClient], NULL_VECTOR, NULL_VECTOR);
      
      SDKCall_PlaySpecificSequence(boss.iClient, "teleport_in");
      return;
    }
    
    //Progress in teleporting
    TeleportView_ShowPos(boss.iClient, g_vecTeleportViewPos[boss.iClient]);
    return;
  }
  else if (g_nTeleportViewMode[boss.iClient] == TeleportViewMode_Teleported)
  {
    if (flCharge > boss.GetPropFloat("TeleportView", "Charge") + 3.0)
    {
      //Fully done
      
      g_nTeleportViewMode[boss.iClient] = TeleportViewMode_None;
      g_flTeleportViewCooldownWait[boss.iClient] = GetGameTime() + boss.GetPropFloat("TeleportView", "Cooldown");
      boss.CallFunction("UpdateHudInfo", 0.0, 0.0);	//Update once instead of continuously
      
      g_flTeleportViewStartCharge[boss.iClient] = 0.0;
      
      SetEntityMoveType(boss.iClient, MOVETYPE_WALK);

      float vecOrigin[3];
      GetClientAbsOrigin(boss.iClient, vecOrigin);

      float otherPos[3];
      for (int i = 1; i <= MaxClients; i++)
      {
        if (!SaxtonHale_IsValidAttack(i) || !IsPlayerAlive(i) || i == boss.iClient)
          continue;

        GetClientAbsOrigin(i, otherPos);
        if (GetVectorDistance(vecOrigin, otherPos) <= TELEPORT_RADIUS)
        {
          PrintToChatAll("%N was set as bomb!", i);
          
          g_bIsBomb[i] = true;

          // Set proper collision for bomb carrier
          SetEntProp(i, Prop_Send, "m_nSolidType", SOLID_BBOX);
          SetEntProp(i, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_PLAYER);

          SDKHook(i, SDKHook_Touch, Bomb_TouchHook);
          TF2_AddCondition(i, TFCond_HalloweenBombHead, 30.0);
          TF2_AddCondition(i, TFCond_SpeedBuffAlly, 30.0);

          // Kill previous timer if it exists
          if (g_hBombTimer[i] != null)
          {
            CloseHandle(g_hBombTimer[i]);
            g_hBombTimer[i] = null;
          }

          g_hBombTimer[i] = CreateTimer(15.0, Bomb_ExpireTimer, GetClientUserId(i));
        }
      }
    }
    
    //Progress into finishing
    return;
  }
  else if (g_flTeleportViewCooldownWait[boss.iClient] != 0.0 && g_flTeleportViewCooldownWait[boss.iClient] > GetGameTime())
  {
    //Teleport in cooldown
    return;
  }
  else if (g_flTeleportViewStartCharge[boss.iClient] == 0.0)
  {
    //Can use teleport, but not charging
    return;
  }
  
  float vecEyePos[3], vecAng[3];
  GetClientEyePosition(boss.iClient, vecEyePos);
  GetClientEyeAngles(boss.iClient, vecAng);
  
  TR_TraceRayFilter(vecEyePos, vecAng, MASK_PLAYERSOLID, RayType_Infinite, TraceRay_DontHitEntity, boss.iClient);
  if (!TR_DidHit())
    return;
  
  float vecEndPos[3];
  TR_GetEndPosition(vecEndPos);
  
  float vecOrigin[3], vecMins[3], vecMaxs[3];
  GetClientAbsOrigin(boss.iClient, vecOrigin);
  GetClientMins(boss.iClient, vecMins);
  GetClientMaxs(boss.iClient, vecMaxs);
  
  if (vecEndPos[2] < vecOrigin[2])	//If trace heading downward, prevent that because mins/maxs hitbox
    vecEndPos[2] = vecOrigin[2];
  
  //Find spot from player's eye
  TR_TraceHullFilter(vecOrigin, vecEndPos, vecMins, vecMaxs, MASK_PLAYERSOLID, TraceRay_DontHitEntity, boss.iClient);
  TR_GetEndPosition(vecEndPos);
  
  //Find the floor
  TR_TraceRayFilter(vecEndPos, view_as<float>({ 90.0, 0.0, 0.0 }), MASK_PLAYERSOLID, RayType_Infinite, TraceRay_DontHitEntity, boss.iClient);
  if (!TR_DidHit())
    return;
  
  float vecFloorPos[3];
  TR_GetEndPosition(vecFloorPos);
  TR_TraceHullFilter(vecEndPos, vecFloorPos, vecMins, vecMaxs, MASK_PLAYERSOLID, TraceRay_DontHitEntity, boss.iClient);
  TR_GetEndPosition(vecEndPos);
  
  if (flCharge >= boss.GetPropFloat("TeleportView", "Charge"))
  {
    // Start teleport anim
    
    g_nTeleportViewMode[boss.iClient] = TeleportViewMode_Teleporting;
    
    g_vecTeleportViewPos[boss.iClient] = vecEndPos;
    
    SetEntityMoveType(boss.iClient, MOVETYPE_NONE);
    SDKCall_PlaySpecificSequence(boss.iClient, "teleport_out");
    
    // FIXED: Only apply conditions to the BOSS, not to nearby players
    TF2_AddCondition(boss.iClient, TFCond_FreezeInput, 3.0);
    TF2_AddCondition(boss.iClient, TFCond_UberchargedCanteen, 3.0);
  }
  
  //Show where to teleport
  TeleportView_ShowPos(boss.iClient, vecEndPos);
  boss.CallFunction("UpdateHudInfo", 0.0, 0.0);	//Update once
}

public void TeleportView_GetHudInfo(SaxtonHaleBase boss, char[] sMessage, int iLength, int iColor[4])
{
  if (g_nTeleportViewMode[boss.iClient] == TeleportViewMode_Teleporting)
  {
    //Progress in teleporting
    StrCat(sMessage, iLength, "\nTeleport-view: TELEPORTING.");
  }
  else if (g_nTeleportViewMode[boss.iClient] == TeleportViewMode_Teleported)
  {
    //Progress into finishing
    StrCat(sMessage, iLength, "\nTeleport-view: TELEPORTED.");
  }
  else if (g_flTeleportViewCooldownWait[boss.iClient] != 0.0 && g_flTeleportViewCooldownWait[boss.iClient] > GetGameTime())
  {
    //Teleport in cooldown
    int iSec = RoundToCeil(g_flTeleportViewCooldownWait[boss.iClient] - GetGameTime());
    Format(sMessage, iLength, "%s\nTeleport-view cooldown %i second%s remaining!", sMessage, iSec, (iSec > 1) ? "s" : "");
  }
  else if (g_flTeleportViewStartCharge[boss.iClient] == 0.0)
  {
    //Can use teleport, but not charging
    StrCat(sMessage, iLength, "\nHold reload to use your teleport-view!");
  }
  else
  {
    //Charging to teleport
    float flPercentage = (GetGameTime() - g_flTeleportViewStartCharge[boss.iClient]) / boss.GetPropFloat("TeleportView", "Charge");
    Format(sMessage, iLength, "%s\nTeleport-view: %0.2f%%.", sMessage, flPercentage * 100.0);
  }
}

public void TeleportView_OnButton(SaxtonHaleBase boss, int &buttons)
{
  if (GameRules_GetRoundState() == RoundState_Preround)
    return;
  
  if (buttons & IN_RELOAD && g_flTeleportViewStartCharge[boss.iClient] == 0.0 && g_flTeleportViewCooldownWait[boss.iClient] != 0.0 && g_flTeleportViewCooldownWait[boss.iClient] < GetGameTime())
    g_flTeleportViewStartCharge[boss.iClient] = GetGameTime();
}

public void TeleportView_OnButtonRelease(SaxtonHaleBase boss, int button)
{
  if (button == IN_RELOAD && g_nTeleportViewMode[boss.iClient] == TeleportViewMode_None)
  {
    g_flTeleportViewStartCharge[boss.iClient] = 0.0;
    boss.CallFunction("UpdateHudInfo", 0.0, 0.0);	//Update once
  }
}

public void TeleportView_Precache(SaxtonHaleBase boss)
{
  PrecacheParticleSystem(PARTICLE_TELEPORT);
}

void TeleportView_ShowPos(int iClient, const float vecPos[3])
{
  //Show where boss will be teleported
  float vecStart[3], vecEnd[3], vecMins[3], vecMaxs[3];
  GetClientAbsOrigin(iClient, vecStart);
  GetClientMins(iClient, vecMins);
  GetClientMaxs(iClient, vecMaxs);
  vecEnd = vecPos;
  
  vecStart[2] += 8.0;
  vecEnd[2] += 8.0;
  float flDiameter = vecMaxs[0] - vecMins[0];
  
  //Line effect
  TE_SetupBeamPoints(vecStart, vecEnd, g_iSpritesLaserbeam, g_iSpritesGlow, 0, 10, 0.1, 3.0, 3.0, 10, 0.0, {0, 255, 0, 255}, 10);
  TE_SendToClient(iClient);
  
  //Ring effect
  TE_SetupBeamRingPoint(vecEnd, flDiameter, flDiameter + 1.0, g_iSpritesLaserbeam, g_iSpritesGlow, 0, 10, 0.1, 3.0, 0.0, {0, 255, 0, 255}, 10, 0);
  TE_SendToClient(iClient);
}