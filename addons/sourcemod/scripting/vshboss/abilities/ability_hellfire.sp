#pragma semicolon 1
#pragma newdecls required

#define HELLFIRE_BEAM_MODEL "materials/sprites/laser.vmt"
#define HELLFIRE_SOUND "misc/halloween/spell_lightning_ball_impact.wav"
#define HELLFIRE_LOOP_SOUND "misc/halloween/merasmus_spell.wav"

static float g_flHellfireNext[MAXPLAYERS];
static float g_flHellfireCooldown[MAXPLAYERS];
static bool g_bHellfireActive[MAXPLAYERS];
static float g_flHellfireEnd[MAXPLAYERS];
static float g_flLastBeamFire[MAXPLAYERS];
static bool g_bHellfireHit[MAXPLAYERS][MAXPLAYERS]; // [boss][victim]

public void Hellfire_Create(SaxtonHaleBase boss)
{
	g_flHellfireNext[boss.iClient] = 0.0;
	g_flHellfireCooldown[boss.iClient] = 0.0;
	g_bHellfireActive[boss.iClient] = false;
	g_flHellfireEnd[boss.iClient] = 0.0;
	g_flLastBeamFire[boss.iClient] = 0.0;
	
	// Reset hit tracking
	for (int i = 1; i <= MaxClients; i++)
		g_bHellfireHit[boss.iClient][i] = false;
	
	// Configuration
	boss.SetPropFloat("Hellfire", "Cooldown", 8.0);
	boss.SetPropFloat("Hellfire", "Duration", 3.0);
	boss.SetPropFloat("Hellfire", "Range", 1000.0);
	boss.SetPropFloat("Hellfire", "LaunchForce", 800.0);
	boss.SetPropFloat("Hellfire", "BurnDuration", 10.0);
	boss.SetPropFloat("Hellfire", "TickRate", 0.1);
	
	PrecacheModel(HELLFIRE_BEAM_MODEL);
	PrecacheSound(HELLFIRE_SOUND);
	PrecacheSound(HELLFIRE_LOOP_SOUND);
	PrecacheSound("player/recharged.wav");
}

public void Hellfire_Precache()
{
	PrecacheModel(HELLFIRE_BEAM_MODEL);
	PrecacheSound(HELLFIRE_SOUND);
	PrecacheSound(HELLFIRE_LOOP_SOUND);
	PrecacheSound("player/recharged.wav");
}

public void Hellfire_GetHudInfo(SaxtonHaleBase boss, char[] sMessage, int iLength, int iColor[4])
{
	float flPercentage = 1.0 - ((g_flHellfireCooldown[boss.iClient] - GetGameTime()) / boss.GetPropFloat("Hellfire", "Cooldown"));
	if (flPercentage > 1.0)
		flPercentage = 1.0;

	if (flPercentage == 1.0)
		Format(sMessage, iLength, "%s\nHellfire: %.0f%%%% - Press M3 to use!", sMessage, flPercentage * 100.0);
	else
		Format(sMessage, iLength, "%s\nHellfire: %.0f%%%%", sMessage, flPercentage * 100.0);
}

public void Hellfire_OnButtonPress(SaxtonHaleBase boss, int iButton)
{
	if (iButton == IN_ATTACK3 && GameRules_GetRoundState() != RoundState_Preround)
	{
		float flGameTime = GetGameTime();
		
		// Check cooldown
		if (g_flHellfireCooldown[boss.iClient] > flGameTime)
			return;
		
		// Reset hit tracking for new activation
		for (int i = 1; i <= MaxClients; i++)
			g_bHellfireHit[boss.iClient][i] = false;
		
		// Activate Hellfire
		g_bHellfireActive[boss.iClient] = true;
		g_flHellfireEnd[boss.iClient] = flGameTime + boss.GetPropFloat("Hellfire", "Duration");
		g_flHellfireCooldown[boss.iClient] = flGameTime + boss.GetPropFloat("Hellfire", "Cooldown");
		g_flLastBeamFire[boss.iClient] = 0.0;
		
		boss.CallFunction("UpdateHudInfo", 0.0, boss.GetPropFloat("Hellfire", "Cooldown") * 2);
		
		// Play ability sound
		char sSound[PLATFORM_MAX_PATH];
		boss.CallFunction("GetSoundAbility", sSound, sizeof(sSound), "Hellfire");
		if (!StrEmpty(sSound))
			EmitSoundToAll(sSound, boss.iClient, SNDCHAN_VOICE, SNDLEVEL_SCREAMING);
		
		EmitSoundToAll(HELLFIRE_LOOP_SOUND, boss.iClient, SNDCHAN_AUTO, SNDLEVEL_RAIDSIREN);
		
		// Play ready sound after cooldown
		CreateTimer(boss.GetPropFloat("Hellfire", "Cooldown"), Timer_HellfireReady, GetClientUserId(boss.iClient));
	}
}

public void Hellfire_OnThink(SaxtonHaleBase boss)
{
	if (!g_bHellfireActive[boss.iClient])
		return;
	
	float flGameTime = GetGameTime();
	
	// Check if duration ended
	if (flGameTime >= g_flHellfireEnd[boss.iClient])
	{
		g_bHellfireActive[boss.iClient] = false;
		StopSound(boss.iClient, SNDCHAN_AUTO, HELLFIRE_LOOP_SOUND);
		return;
	}
	
	// Fire beam at intervals
	if (g_flLastBeamFire[boss.iClient] > flGameTime)
		return;
	
	g_flLastBeamFire[boss.iClient] = flGameTime + boss.GetPropFloat("Hellfire", "TickRate");
	
	// Get boss eye position for beam origin
	float vecBossEyes[3];
	GetClientEyePosition(boss.iClient, vecBossEyes);
	
	// Find and attack target player
	int iTarget = Hellfire_FindTarget(boss);
	if (iTarget > 0)
	{
		Hellfire_AttackPlayer(boss, iTarget, vecBossEyes);
	}
	
	// Destroy nearby sentry guns
	float vecBossOrigin[3];
	GetClientAbsOrigin(boss.iClient, vecBossOrigin);
	Hellfire_DestroySentries(boss, vecBossOrigin, vecBossEyes);
}

int Hellfire_FindTarget(SaxtonHaleBase boss)
{
	float vecBossOrigin[3];
	GetClientAbsOrigin(boss.iClient, vecBossOrigin);
	
	float flMaxRange = boss.GetPropFloat("Hellfire", "Range");
	int iClosestTarget = -1;
	float flClosestDist = flMaxRange;
	
	int iTeam = GetClientTeam(boss.iClient);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		
		if (GetClientTeam(i) == iTeam)
			continue;
		
		float vecTargetOrigin[3];
		GetClientAbsOrigin(i, vecTargetOrigin);
		
		float flDistance = GetVectorDistance(vecBossOrigin, vecTargetOrigin);
		if (flDistance < flClosestDist)
		{
			// Check line of sight
			Handle hTrace = TR_TraceRayFilterEx(vecBossOrigin, vecTargetOrigin, MASK_SOLID, RayType_EndPoint, Hellfire_TraceFilter, boss.iClient);
			bool bHit = TR_DidHit(hTrace);
			int iEntity = TR_GetEntityIndex(hTrace);
			delete hTrace;
			
			if (!bHit || iEntity == i)
			{
				flClosestDist = flDistance;
				iClosestTarget = i;
			}
		}
	}
	
	return iClosestTarget;
}

void Hellfire_AttackPlayer(SaxtonHaleBase boss, int iTarget, float vecStart[3])
{
	// Check if already hit this target during this activation
	if (g_bHellfireHit[boss.iClient][iTarget])
		return;
	
	// Mark as hit
	g_bHellfireHit[boss.iClient][iTarget] = true;
	
	float vecEnd[3];
	GetClientAbsOrigin(iTarget, vecEnd);
	vecEnd[2] += 50.0; // Aim at chest
	
	// Create green lightning beam effect
	Hellfire_CreateBeam(vecStart, vecEnd);
	
	// Launch player into air
	float vecVelocity[3];
	vecVelocity[0] = GetRandomFloat(-100.0, 100.0);
	vecVelocity[1] = GetRandomFloat(-100.0, 100.0);
	vecVelocity[2] = boss.GetPropFloat("Hellfire", "LaunchForce");
	
	TeleportEntity(iTarget, NULL_VECTOR, NULL_VECTOR, vecVelocity);
	
	// Set on fire
	TF2_IgnitePlayer(iTarget, boss.iClient, boss.GetPropFloat("Hellfire", "BurnDuration"));
	
	// Play impact sound
	EmitSoundToAll(HELLFIRE_SOUND, iTarget, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
	
	// Screen shake for target
	Hellfire_ScreenShake(iTarget);
}

void Hellfire_DestroySentries(SaxtonHaleBase boss, float vecOrigin[3], float vecStart[3])
{
	int iSentry = -1;
	int iTeam = GetClientTeam(boss.iClient);
	float flRange = boss.GetPropFloat("Hellfire", "Range");
	
	while ((iSentry = FindEntityByClassname(iSentry, "obj_sentrygun")) != -1)
	{
		if (GetEntProp(iSentry, Prop_Send, "m_iTeamNum") == iTeam)
			continue;
		
		float vecSentryOrigin[3];
		GetEntPropVector(iSentry, Prop_Send, "m_vecOrigin", vecSentryOrigin);
		
		if (GetVectorDistance(vecOrigin, vecSentryOrigin) <= flRange)
		{
			// Check line of sight
			Handle hTrace = TR_TraceRayFilterEx(vecOrigin, vecSentryOrigin, MASK_SOLID, RayType_EndPoint, Hellfire_TraceFilter, boss.iClient);
			bool bHit = TR_DidHit(hTrace);
			int iEntity = TR_GetEntityIndex(hTrace);
			delete hTrace;
			
			if (!bHit || iEntity == iSentry)
			{
				// Create beam to sentry
				Hellfire_CreateBeam(vecStart, vecSentryOrigin);
				
				// Destroy sentry instantly
				SetVariantInt(99999);
				AcceptEntityInput(iSentry, "RemoveHealth");
				
				EmitSoundToAll(HELLFIRE_SOUND, iSentry, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
			}
		}
	}
}

void Hellfire_CreateBeam(float vecStart[3], float vecEnd[3])
{
	TE_SetupBeamPoints(vecStart, vecEnd, PrecacheModel(HELLFIRE_BEAM_MODEL), 0, 0, 0, 0.2, 8.0, 8.0, 10, 10.0, {50, 255, 50, 255}, 10);
	TE_SendToAll();
}

void Hellfire_ScreenShake(int iClient)
{
	Handle hMessage = StartMessageOne("Shake", iClient);
	if (hMessage != null)
	{
		BfWriteByte(hMessage, 0);
		BfWriteFloat(hMessage, 10.0); // Amplitude
		BfWriteFloat(hMessage, 5.0); // Frequency
		BfWriteFloat(hMessage, 1.0); // Duration
		EndMessage();
	}
}

public bool Hellfire_TraceFilter(int iEntity, int iContentsMask, int iClient)
{
	return iEntity != iClient;
}

static Action Timer_HellfireReady(Handle timer, int iUserId)
{
	int client = GetClientOfUserId(iUserId);
	if (client && IsClientInGame(client))
	{
		EmitSoundToClient(client, "player/recharged.wav");
	}
	return Plugin_Stop;
}