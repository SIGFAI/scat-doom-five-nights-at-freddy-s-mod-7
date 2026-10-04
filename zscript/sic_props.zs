// Blocky decorations of the pizzeria and the meadow outside. All solid, like Minecraft blocks.

class SICPartyTable : Actor
{
	Default
	{
		Radius 30;
		Height 36;
		+SOLID
		Tag "Party table";
	}
	States
	{
	Spawn:
		MCTB A -1;
		Stop;
	}
}

class SICTree : Actor
{
	Default
	{
		Radius 18;
		Height 140;
		+SOLID
		Tag "Oak tree";
	}
	States
	{
	Spawn:
		MCTR A -1;
		Stop;
	}
}

class SICLampPost : Actor
{
	Default
	{
		Radius 8;
		Height 84;
		+SOLID
		Tag "Lamp";
	}
	States
	{
	Spawn:
		MCLP A -1 Bright;
		Stop;
	}
}

class SICChest : Actor
{
	Default
	{
		Radius 14;
		Height 30;
		+SOLID
		Tag "Chest";
	}
	States
	{
	Spawn:
		MCCH A -1;
		Stop;
	}
}

class SICGrassBlock : Actor
{
	Default
	{
		Radius 16;
		Height 32;
		+SOLID
	}
	States
	{
	Spawn:
		GRSB A -1;
		Stop;
	}
}

// The guard's desk in the office: camera monitors, the fan, the phone.
class SICSecurityDesk : Actor
{
	Default
	{
		Radius 34;
		Height 40;
		+SOLID
		Tag "Security desk";
	}
	States
	{
	Spawn:
		DESK A -1;
		Stop;
	}
}
