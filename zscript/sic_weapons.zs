// The night guard's TNT Cannon (replaces the rocket launcher), its TNT shots, TNT blocks that explode
// like in Minecraft (they replace the barrels), and pizza slices that heal.

class SICTNTLauncher : RocketLauncher replaces RocketLauncher
{
	Default
	{
		Weapon.SlotNumber 5;
		Weapon.AmmoGive 10;
		Tag "TNT Cannon";
		Inventory.PickupMessage "You got the TNT Cannon! Blow those animatronics back into blocks.";
		-WEAPON.NOAUTOFIRE
	}
	States
	{
	Ready:
		TNTG A 1 A_WeaponReady;
		Loop;
	Deselect:
		TNTG A 1 A_Lower;
		Loop;
	Select:
		TNTG A 1 A_Raise;
		Loop;
	Fire:
		TNTG B 3 Bright
		{
			A_GunFlash();
			A_FireProjectile("SICTNTShot", 0, true, 0, 4);
			A_StartSound("tnt/fire", CHAN_WEAPON);
			A_QuakeEx(1, 1, 1, 6, 0, 64, "", QF_SCALEDOWN | QF_RELATIVE);
			SICNight.UsePower(5);
		}
		TNTG B 5 Bright;
		TNTG A 12;
		TNTG A 0 A_ReFire;
		Goto Ready;
	Flash:
		TNT1 A 4 A_Light2;
		TNT1 A 4 A_Light1;
		Goto LightDone;
	Spawn:
		TNTB A -1;
		Stop;
	}
}

// A flying TNT block: tumbles, smokes, and goes off like a rocket.
class SICTNTShot : Actor
{
	Default
	{
		Projectile;
		Radius 10;
		Height 12;
		Speed 24;
		Damage 20;
		+RANDOMIZE
		+DEHEXPLOSION
		DeathSound "tnt/boom";
		Obituary "%o caught %k's TNT.";
	}
	States
	{
	Spawn:
		TNTP A 3 Bright A_SpawnItemEx("SICSmoke", -8, 0, 4, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
		TNTP B 3 Bright A_SpawnItemEx("SICSmoke", -8, 0, 4, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
		Loop;
	Death:
		TNT1 A 0
		{
			A_Explode(128, 128);
			A_SpawnItemEx("SICBoom", 0, 0, 0, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
		}
		TNT1 A 10;
		Stop;
	}
}

// A TNT block. Shoot it, it flashes white and hisses... then BOOM.
class SICTNTBlock : Actor replaces ExplosiveBarrel
{
	Default
	{
		Health 20;
		Radius 14;
		Height 32;
		Mass 300;
		+SOLID
		+SHOOTABLE
		+NOBLOOD
		+DONTGIB
		+ACTIVATEMCROSS
		+OLDRADIUSDMG
		+NOICEDEATH
		DeathSound "tnt/boom";
		Obituary "%o stood too close to the TNT.";
		Tag "TNT";
	}
	States
	{
	Spawn:
		TNTB A -1;
		Stop;
	Death:
		TNTB B 4 Bright A_StartSound("tnt/fire", CHAN_BODY);
		TNTB ABABAB 4 Bright;
		TNTB B 2 Bright A_NoBlocking;
		TNT1 A 0
		{
			A_Scream();
			A_Explode(160, 160);
			A_SpawnItemEx("SICBoom", 0, 0, 16, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
			A_SpawnItemEx("SICBoom", 0, 0, 40, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
		}
		TNT1 A 10;
		Stop;
	}
}

// A cold pizza slice from the party tables: heals like a stimpack.
class SICPizzaSlice : Stimpack replaces Stimpack
{
	Default
	{
		Inventory.Amount 15;
		Inventory.PickupMessage "Cold pizza slice! Still good.";
		Inventory.PickupSound "kitten/meow2";
	}
	States
	{
	Spawn:
		PZZP A -1;
		Stop;
	}
}
