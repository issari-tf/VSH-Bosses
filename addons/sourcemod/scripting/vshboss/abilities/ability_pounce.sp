#pragma semicolon 1
#pragma newdecls required

// Warrior's Spirit Pounce - Boss Ability Version
// Converted from standalone plugin to SaxtonHale boss ability

#define WARRIORS_SPIRIT 310
#define POUNCE_FORCE 900.0
#define POUNCE_DAMAGE 10.0
#define IMPACT_SOUND "player/taunt_yeti_land.wav"
#define IMPACT_PARTICLE "hammer_impact_button"

static float g_flPounceCooldownWait[MAXPLAYERS];
static bool g_bPounceActive[MAXPLAYERS];
static bool g_bAlreadyHit[MAXPLAYERS];
static Handle g_hCollisionTimer[MAXPLAYERS];
static float g_flPounceStartTime[MAXPLAYERS];
static int g_EntityTrail[MAXPLAYERS];
static float g_vecPounceInitialAngles[MAXPLAYERS][3];

static char g_TrailFile[][] = {
    "materials/sprites/laserbeam"
};

public void Pounce_Create(SaxtonHaleBase boss)
{
    g_flPounceCooldownWait[boss.iClient] = 0.0;
    g_bPounceActive[boss.iClient] = false;
    g_EntityTrail[boss.iClient] = -1;
    
    boss.SetPropFloat("Pounce", "Cooldown", 6.0);
    boss.SetPropFloat("Pounce", "MaxDamage", POUNCE_DAMAGE);
    boss.SetPropFloat("Pounce", "MaxForce", POUNCE_FORCE);
}

public void Pounce_Precache()
{
    PrecacheSound("player/recharged.wav", true);
    PrecacheSound("weapons/cleaver_throw.wav", true);
    PrecacheSound("weapons/demo_charge_hit_flesh3.wav", true);
    PrecacheSound(IMPACT_SOUND, true);
    PrecacheSound("player/taunt_yeti_roar_second.wav", true);
    PrecacheParticleSystem(IMPACT_PARTICLE);
}

public void Pounce_GetHudInfo(SaxtonHaleBase boss, char[] sMessage, int iLength, int iColor[4])
{
    float flPercentage = 1.0 - ((g_flPounceCooldownWait[boss.iClient] - GetGameTime()) / boss.GetPropFloat("Pounce", "Cooldown"));
    if (flPercentage > 1.0)
        flPercentage = 1.0;

    if (flPercentage == 1.0 && CanPounce(boss))
        Format(sMessage, iLength, "%s\nPounce: %.0f%%%% - Press reload to use!", sMessage, flPercentage * 100.0);
    else
        Format(sMessage, iLength, "%s\nPounce: %.0f%%%%", sMessage, flPercentage * 100.0);
}

static bool CanPounce(SaxtonHaleBase boss)
{
    return !TF2_IsPlayerInCondition(boss.iClient, TFCond_Dazed) &&
        !TF2_IsPlayerInCondition(boss.iClient, TFCond_Taunting) &&
        GetEntProp(boss.iClient, Prop_Send, "m_nWaterLevel") < 2;
}

public void Pounce_OnPlayerKilled(SaxtonHaleBase boss, Event event, int iVictim)
{
    if (g_bPounceActive[boss.iClient])
    {
        event.SetString("weapon_logclassname", "pounce");
        event.SetString("weapon", "warrior_spirit");
    }
}

public void Pounce_OnButtonPress(SaxtonHaleBase boss, int iButton)
{
    if (iButton == IN_RELOAD && GameRules_GetRoundState() != RoundState_Preround && CanPounce(boss))
    {
        if (g_flPounceCooldownWait[boss.iClient] > GetGameTime())
            return;
        
        g_flPounceCooldownWait[boss.iClient] = GetGameTime() + boss.GetPropFloat("Pounce", "Cooldown");
        boss.CallFunction("UpdateHudInfo", 0.0, boss.GetPropFloat("Pounce", "Cooldown") * 2);
        
        // Play ability sound
        char sSound[PLATFORM_MAX_PATH];
        boss.CallFunction("GetSoundAbility", sSound, sizeof(sSound), "Pounce");
        if (!StrEmpty(sSound))
            EmitSoundToAll(sSound, boss.iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
        
        // Play yeti roar
        EmitSoundToClient(boss.iClient, "player/taunt_yeti_roar_second.wav");
        
        EmitSoundToClient(boss.iClient, "weapons/cleaver_throw.wav");
        
        // Set up collision detection
        int iTeam = GetClientTeam(boss.iClient);
        for (int iVictim = 1; iVictim <= MaxClients; iVictim++)
        {
            g_bAlreadyHit[iVictim] = false;

            if (iVictim != boss.iClient)
            {
                if (!IsClientInGame(iVictim) || !IsPlayerAlive(iVictim) || GetClientTeam(iVictim) == iTeam)
                    continue;
            }

            SetEntityCollisionGroup(iVictim, COLLISION_GROUP_DEBRIS_TRIGGER);
            
            if (g_hCollisionTimer[iVictim] == null)
                g_hCollisionTimer[iVictim] = CreateTimer(0.1, RevertCollisionGroup, GetClientUserId(iVictim), TIMER_REPEAT);
        }
        
        g_bPounceActive[boss.iClient] = true;
        g_flPounceStartTime[boss.iClient] = GetGameTime();
        
        GetClientEyeAngles(boss.iClient, g_vecPounceInitialAngles[boss.iClient]);
        
        float vecVelocity[3];
        GetAngleVectors(g_vecPounceInitialAngles[boss.iClient], vecVelocity, NULL_VECTOR, NULL_VECTOR);
        ScaleVector(vecVelocity, boss.GetPropFloat("Pounce", "MaxForce"));

        if ((GetEntityFlags(boss.iClient) & FL_ONGROUND) == 0)
            vecVelocity[2] += 50.0;
        else if (vecVelocity[2] < 310.0)
            vecVelocity[2] = 310.0;
        
        TeleportEntity(boss.iClient, NULL_VECTOR, NULL_VECTOR, vecVelocity);
        
        // Attach trail
        AttachTrailToClient(boss.iClient);
    }
}

public void Pounce_OnThink(SaxtonHaleBase boss)
{
    if (g_bPounceActive[boss.iClient])
    {
        // Grace period before checking conditions
        if ((GetGameTime() - g_flPounceStartTime[boss.iClient]) > 0.1)
        {
            // End after 0.5 seconds or touching ground/water
            if ((GetGameTime() - g_flPounceStartTime[boss.iClient]) > 0.5 || 
                (GetEntityFlags(boss.iClient) & FL_ONGROUND) != 0 || 
                GetEntProp(boss.iClient, Prop_Send, "m_nWaterLevel") > 1)
            {
                g_bPounceActive[boss.iClient] = false;
                
                // Play recharged sound when ready again
                CreateTimer(boss.GetPropFloat("Pounce", "Cooldown"), Timer_PounceReady, GetClientUserId(boss.iClient));
                return;
            }
        }

        float vecBoss[3], vecVictim[3];
        GetClientAbsOrigin(boss.iClient, vecBoss);
        
        float flDamage = boss.GetPropFloat("Pounce", "MaxDamage");
        
        int iTeam = GetClientTeam(boss.iClient);
        for (int iVictim = 1; iVictim <= MaxClients; iVictim++)
        {
            if (g_bAlreadyHit[iVictim] || !IsClientInGame(iVictim) || !IsPlayerAlive(iVictim) || GetClientTeam(iVictim) == iTeam)
                continue;

            GetClientAbsOrigin(iVictim, vecVictim);
            
            // Simple distance check
            if (GetVectorDistance(vecBoss, vecVictim) <= 100.0)
            {
                g_bAlreadyHit[iVictim] = true;
                
                // Deal damage
                SDKHooks_TakeDamage(iVictim, boss.iClient, boss.iClient, flDamage, DMG_CLUB);
                
                // Play impact sound
                EmitSoundToAll("weapons/demo_charge_hit_flesh3.wav", boss.iClient, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN, SND_NOFLAGS, 1.0, 80);
                
                // Create particle effect
                float vecAngles[3];
                CreateTimer(1.0, Timer_EntityCleanup, TF2_SpawnParticle(IMPACT_PARTICLE, vecVictim, vecAngles));
            }
        }
    }
}

static Action Timer_PounceReady(Handle timer, int iUserId)
{
    int client = GetClientOfUserId(iUserId);
    if (client && IsClientInGame(client))
    {
        EmitSoundToClient(client, "player/recharged.wav");
    }
    return Plugin_Stop;
}

static Action RevertCollisionGroup(Handle hTimer, int iUserId)
{
    int iClient = GetClientOfUserId(iUserId);
    if (iClient)
    {
        if (g_bPounceActive[iClient])
            return Plugin_Continue;
        
        float vecOrigin[3], vecMins[3], vecMaxs[3];
        GetClientAbsOrigin(iClient, vecOrigin);
        vecMins[0] = vecOrigin[0] - 50.0;
        vecMins[1] = vecOrigin[1] - 50.0;
        vecMins[2] = vecOrigin[2] - 85.0;
        vecMaxs[0] = vecOrigin[0] + 50.0;
        vecMaxs[1] = vecOrigin[1] + 50.0;
        vecMaxs[2] = vecOrigin[2] + 85.0;
        
        int iTeam = GetClientTeam(iClient);
        for (int iVictim = 1; iVictim <= MaxClients; iVictim++)
        {
            if (iVictim == iClient || !IsClientInGame(iVictim) || !IsPlayerAlive(iVictim) || GetClientTeam(iVictim) == iTeam)
                continue;
            
            if (g_bPounceActive[iVictim])
                return Plugin_Continue;
            
            GetClientAbsOrigin(iVictim, vecOrigin);
            if (vecOrigin[0] >= vecMins[0] && vecOrigin[0] <= vecMaxs[0] &&
                vecOrigin[1] >= vecMins[1] && vecOrigin[1] <= vecMaxs[1] &&
                vecOrigin[2] >= vecMins[2] && vecOrigin[2] <= vecMaxs[2])
            {
                return Plugin_Continue;
            }
        }
        
        SetEntityCollisionGroup(iClient, COLLISION_GROUP_PLAYER);
    }

    for (int i = 0; i < sizeof(g_hCollisionTimer); i++)
    {
        if (g_hCollisionTimer[i] == hTimer)
        {
            g_hCollisionTimer[i] = null;
            break;
        }
    }

    return Plugin_Stop;
}

void AttachTrailToClient(int client)
{
    int trail = CreateEntityByName("env_spritetrail");
    if (!IsValidEntity(trail))
        return;

    g_EntityTrail[client] = trail;

    char strTargetName[64];
    Format(strTargetName, sizeof(strTargetName), "trail_target_%d", client);
    DispatchKeyValue(client, "targetname", strTargetName);
    DispatchKeyValue(trail, "parentname", strTargetName);
    DispatchKeyValueFloat(trail, "lifetime", 0.6);
    DispatchKeyValueFloat(trail, "startwidth", 6.0);
    DispatchKeyValueFloat(trail, "endwidth", 15.0);

    char trailMaterial[PLATFORM_MAX_PATH];
    Format(trailMaterial, sizeof(trailMaterial), "%s.vmt", g_TrailFile[0]);
    DispatchKeyValue(trail, "spritename", trailMaterial);

    DispatchKeyValue(trail, "renderamt", "255");
    DispatchKeyValue(trail, "rendermode", "4");

    DispatchSpawn(trail);

    float pos[3];
    GetClientAbsOrigin(client, pos);
    pos[2] += 10.0;

    TeleportEntity(trail, pos, NULL_VECTOR, NULL_VECTOR);
    SetVariantString(strTargetName);
    AcceptEntityInput(trail, "SetParent");
    SetEntPropFloat(trail, Prop_Send, "m_flTextureRes", 0.05);

    CreateTimer(0.7, RemoveTrail, GetClientUserId(client));
}

static Action RemoveTrail(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client))
    {
        int trail = g_EntityTrail[client];
        if (trail != -1 && IsValidEntity(trail))
        {
            AcceptEntityInput(trail, "Kill");
            g_EntityTrail[client] = -1;
        }
    }
    return Plugin_Stop;
}

static Action Timer_EntityCleanup(Handle timer, int entity)
{
    if (IsValidEntity(entity))
        RemoveEntity(entity);
    
    return Plugin_Stop;
}