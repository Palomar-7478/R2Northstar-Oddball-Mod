global function FFA_Init

#if SERVER
global int missed_batt = 0
#endif

void function FFA_Init()
{
	ClassicMP_ForceDisableEpilogue( false )
	ScoreEvent_SetupEarnMeterValuesForMixedModes()

	#if SERVER

	if (GetCurrentPlaylistVarInt("Oddball" , 1) == 1) {
		AddCallback_OnClientConnected( InitPlayer )
		AddCallback_OnPlayerRespawned( InitPlayer )
		AddCallback_GameStateEnter( eGameState.Playing, SelectBattPlayer)
		AddCallback_GameStateEnter( eGameState.Playing,  CheckforBat)
		AddCallback_GameStateEnter( eGameState.Playing, cantfind_fallback)
		Riff_ForceTitanAvailability( eTitanAvailability.Never )
		Riff_ForceBoostAvailability( eBoostAvailability.Disabled )
	}
	if (GetCurrentPlaylistVarInt("Oddball" , 0) == 0) {AddCallback_OnPlayerKilled( OnPlayerKilled )}

	#endif
}

#if SERVER
void function SpawnBatt_func (entity player) {
	entity batt = Rodeo_CreateBatteryPack()
	Highlight_SetNeutralHighlight( batt, "hunted_friendly" )
	batt.SetOrigin(player.GetOrigin())
	print("Spawned battery at " + player.GetPlayerName())
}

void function ClearBatt_func (){
	foreach (entity players in GetPlayerArray())
		{Rodeo_RemoveAllBatteriesOffPlayer( players)}
	foreach ( entity battery in GetEntArrayByClass_Expensive( "item_titan_battery" ) )
		{battery.Destroy()}
	print("All Batteries Cleared!")
}

void function ClearMelee_func(entity player) {
	entity weapon = player.GetOffhandWeapon( OFFHAND_MELEE)
	if (weapon != null) {player.TakeWeaponNow(weapon.GetWeaponClassName())}
}

void function InitPlayer(entity player) {
	if (GetCurrentPlaylistVarInt("Carrier-Exclusive-Melee" , 1) == 1) {
		ClearMelee_func(player)
	}
}

void function SelectBattPlayer() {thread SelectBattPlayer_threaded()}
void function SelectBattPlayer_threaded() {
	wait 5.0
	try {
	int playernum = RandomInt( GetPlayerArray().len() )
	ClearBatt_func()
	SpawnBatt_func(GetPlayerArray()[playernum])
	foreach (player in GetPlayerArray()){SendHudMessage(player,GetPlayerArray()[playernum].GetPlayerName()+" has gotten the battery by chance!",-1,0.3,255,255,0,1,0,3,1)}
	}
	catch(exception) {print("No Players to select!")}
}

void function CheckforBat() {thread CheckforBat_threaded() }
void function CheckforBat_threaded() {
	while (true) {
		wait 1
		foreach (player in GetPlayerArray()) {
			if (PlayerHasBattery(player)) {
					Highlight_SetEnemyHighlight( player, "enemy_sonar" )
					if (missed_batt > 0 && GetCurrentPlaylistVarInt("Carrier-Exclusive-Melee" , 1) == 1) {ClearMelee_func(player);player.GiveOffhandWeapon( "melee_pilot_emptyhanded", OFFHAND_MELEE )}
					missed_batt = 0
					AddTeamScore( player.GetTeam(), 1 )
			}
			else {
				int score = GameRules_GetTeamScore (player.GetTeam())
				AddTeamScore (player.GetTeam() , -score)
			}
		}
	}
}

void function cantfind_fallback() {thread cantfind_fallback_threaded()}
void function cantfind_fallback_threaded() {
	while (true) {
		wait 1
		int playernum = GetPlayerArray().len()
		bool foundB = false
		foreach (player in GetPlayerArray()) {
			playernum = playernum -1
			if (PlayerHasBattery(player)) {foundB = true;}
			if (!PlayerHasBattery(player) && playernum < 1 && foundB ==false) {
				missed_batt = missed_batt + 1
				if (missed_batt > GetCurrentPlaylistVarInt("Battery-Timeout", 30)) {
					missed_batt = 0
					SelectBattPlayer()
					SendHudMessage(player,"You seem to have problems finding the battery , a random player will be given one shortly.",-1,0.3,255,255,0,1,0/*fade in time*/,3/*time*/,1/*fade out time*/)
				}
			}
		}
	}
}


void function OnPlayerKilled( entity victim, entity attacker, var damageInfo ){
	if (victim.IsPlayer() && attacker.IsPlayer() && GetGameState() == eGameState.Playing )
	{
		AddTeamScore( attacker.GetTeam(), 1 )
		attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 1 )
	}
}
#endif
